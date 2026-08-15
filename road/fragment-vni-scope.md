# 路：分片 VNI 作用域（fragment map fail-closed）

> 起点：bpf_lxc 分类一个分片数据报（已知 endpoint VNI）。
> 终点：`cilium_ipv4_frag_datagrams` 按 `{daddr, saddr, id, proto, vni}` 记录 L4 端口，供非首分片正确分类。
> 定位：CT/NAT 面唯一**部分 VNI 化**的结构——分片 key 加了 VNI，但只有 bpf_lxc 知道 VNI，跨程序靠 fail-closed 兜底。

## 1. 完整路线

```mermaid
flowchart TD
    PKT[分片数据报] -.->|读 五元组| LXC[3 转发面 bpf_lxc]
    LXC -->|写 frag key{vni=CONFIG}| FRAG[cilium_ipv4_frag_datagrams<br/>LRU map]
    FRAG -.->|读 L4 端口| LXC
    LXC -->|写 分类结果| POL[策略/CT 查找]
    OTHER[非 bpf_lxc 程序] -.->|写 frag key{vni=0}| FRAG
    OTHER -.->|读 miss| DROP[DROP_FRAG_NOT_FOUND fail-closed]
```

## 2. 逐层对象与文件（地图坐标）

| 层 | 对象 | 动作 | 文件 |
| --- | --- | --- | --- |
| 3 转发面 | `bpf_lxc` | `frag_scope_vni()` 填 VNI（`CONFIG(native_vpc_vni)`） | `bpf/lib/ipv4.h` |
| 3 转发面 | `struct ipv4_frag_id` | 键 `{daddr,saddr,id,proto,vni}`（`ENABLE_NATIVE_VPC` 时多 vni 字段） | `bpf/lib/ipv4.h` |
| 3 转发面 | `FragmentKey4NativeVPC` | Go 侧 key 布局对齐（多 4 字节 VNI） | `pkg/maps/fragmap/fragmap.go` |
| 3 转发面 | `cilium_ipv4_frag_datagrams` | LRU map，记录 `{sport,dport}` | `bpf/lib/ipv4.h`、`pkg/maps/fragmap` |

## 3. 为什么这是 CT/NAT 面唯一「部分 VNI 化」点

- CT/NAT 的 ctmap/nat map 仍是**裸五元组**（第 6 面 ❌）。
- 分片 map 是 CT/NAT 面里唯一被 VNI 化的结构：key 加了 `vni` 字段。
- 但**只有 bpf_lxc 知道 VNI**（per-endpoint 加载期配置），其它程序（host/overlay）写 `vni=0`，各自独立命名空间。

## 4. 两个 fail-closed 点

| 场景 | 行为 | 证据 |
| --- | --- | --- |
| 同一数据报的分片被不同程序分类 | 两个程序 vni 作用域不同 → 查不到 → `DROP_FRAG_NOT_FOUND` | `bpf/lib/ipv4.h`、`drop_reasons.h` |
| 不需要分片流量的部署 | `--enable-ipv4-fragment-tracking=false` → 非首分片直接 `DROP_FRAG_NOSUPPORT` | `Documentation/network/native-vpc.rst` |

> native-vpc 下「pod 路径只有 bpf_lxc」的前提（kube-ovn 拥有 host/tunnel datapath）保证跨程序分片不会发生。

## 5. 基线 vs 增量

| 节点 | 基线（无 native-vpc） | native-vpc 增量 |
| --- | --- | --- |
| frag key | `{daddr,saddr,id,proto}`（12 字节） | 加 `vni`（16 字节），`FragmentKey4NativeVPC` |
| map 布局选择 | `FragmentKey4` | `fragmentKey4()` 按 `EnableNativeVPC` 选布局 |
| bpf_lxc 填 VNI | 无 | `frag_scope_vni()=CONFIG(native_vpc_vni)` |
| 非 bpf_lxc 程序 | 无 | `vni=0`，独立命名空间 |

## 6. 地图坐标小结

这条路证明：即使一个面整体 ❌（CT/NAT），也可以**局部 VNI 化 + fail-closed**。这是后续修复 CT/NAT 面的模板——先找能加 VNI 作用域的键，加不了的用 drop/拒绝兜底。
