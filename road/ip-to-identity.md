# 路：IP → identity（基线）

> 起点：CRD `Pod/CEP` 的 IP（无 VNI）。
> 终点：转发面 `cilium_ipcache_v2` 按裸 IP 解析 identity；切面 flow 富化 identity。
> 定位：这是 `vni-ip-to-identity` 的**基线对照路**。VNI 路 = 本条路的每个 key 节点上把 `IP` 扩成 `(VNI, IP)`（等价于 vni=0 的退化路径）。

## 1. 完整路线

```mermaid
flowchart TD
    POD[Pod / CEP 的 IP] -.->|读 IP| CP[1 控制面<br/>K8sWatcher / Endpoint]
    CP -->|写 裸 IP key| CACHE[2 缓存面<br/>IPCache]
    CACHE -->|写 通知变更| DP[3 转发面<br/>BPFListener]
    DP -->|写 Key{IP,ClusterID}| V2[cilium_ipcache_v2<br/>裸 IP LPM trie]
    V2 -.->|读 ipcache_lookup4| LXC[bpf_lxc]
    LXC -->|写 identity 决策| POL[5 策略面 policymap]
    OBS[4 切面<br/>EndpointResolver] -.->|读 LookupSecIDByIP| CACHE
    OBS -->|写 flow| OUT[Hubble / metrics]
```

## 2. 逐层对象与文件（地图坐标）

| 层 | 对象 | 动作 | 文件 |
| --- | --- | --- | --- |
| 1 控制面 | `K8sWatcher` | 从 Pod/CEP 读 IP，写 ipcache（裸 IP key） | `pkg/k8s/watchers/{pod,cilium_endpoint}.go` |
| 1 控制面 | `Endpoint` | 经 `kvstoreSyncher` 写 ipcache（裸 IP） | `pkg/endpoint/policy.go` |
| 1 控制面 | `CachingIdentityAllocator` | labels → numeric identity（无 VNI label） | `pkg/identity/cache/allocator.go` |
| 2 缓存面 | `IPCache` | `ipToIdentityCache[ip] = Identity{ID,Source}` | `pkg/ipcache/ipcache.go` |
| 2 缓存面 | `Identity` | `{ID, Source}`（无 `Vni`） | `pkg/ipcache/ipcache.go` |
| 3 转发面 | `BPFListener` | `Vni=0` → 写 `cilium_ipcache_v2`（`Key`） | `pkg/datapath/ipcache/listener.go` |
| 3 转发面 | `Key` | `{Prefixlen, ClusterID, Family, IP}` | `pkg/maps/ipcache/ipcache.go` |
| 3 转发面 | `bpf_lxc` | `lookup_ip4_remote_endpoint` → `ipcache_lookup4(&cilium_ipcache_v2)` | `bpf/lib/eps.h`、`bpf/bpf_lxc.c` |
| 4 切面 | `EndpointResolver` | `LookupSecIDByIP(ip)` 裸 IP 查身份 | `pkg/hubble/parser/common/endpoint.go` |

## 3. 基线特征（与 VNI 路的对照点）

| 节点 | 基线（本条路） | VNI 路叠加 |
| --- | --- | --- |
| watcher 写 key | 裸 `ip` | `KeyWithVNI(ip, vni)` → `ip@vni:N` |
| ipcache key | `ipToIdentityCache[ip]` | `ipToIdentityCache[ip@vni:N]` + `ipToVNIKeys` |
| `Identity` | `{ID, Source}` | 加 `Vni` 字段 |
| BPF 下发 | 只写 `cilium_ipcache_v2` | `Vni≠0` 写 `cilium_ipcache_vni`（`VniKey`） |
| bpf 查找 | `ipcache_lookup4(v2)` | `ipcache_lookup4_vni(vni_map, vni)` |
| 切面查身份 | `LookupSecIDByIP(ip)` | `LookupSecIDByIPForVNI(ip, vni)` / `Unambiguous` |
| identity | labels 派生，无 VNI | 注入 `vni:io-cilium-native-vpc-vni` label |

## 4. 为什么这条基线是必先修的路

1. VNI 路的每一处增量都「叠加在基线节点上」，没有基线就无法判断增量是否漏改。
2. 基线本身是 vni=0 的退化路径：`KeyWithVNI(ip, 0) == ip`，所以两路共享同一代码骨架，只在 key 构造处分叉。
3. 找路时先走基线，再对基线每个节点问一句「这里要不要 VNI」，就是 VNI 路的完整推导过程。
