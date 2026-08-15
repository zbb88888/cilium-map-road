# 三轴架构（在十面基础上的升级）

> 十面是「扁平展开」；三轴是「立体视图」。三者正交，任何一个对象都能定位到 `(阶段, 特性域, 横切)`。
> 十面的 `map/01~10` 仍作为逐面详细文档保留；本文件是三轴的入口与落位矩阵。

## 1. 三轴定义

| 轴 | 含义 | 取值 | 对应十面 |
| --- | --- | --- | --- |
| **轴1 阶段** | 数据流「走到哪」 | 控制 → 缓存 → 转发 → 观察 | 1 控制面 / 2 缓存面 / 3 转发面 / 4 切面 |
| **轴2 特性域** | 处理「什么业务」 | 身份/认证 / 策略 / 服务LB / CT-NAT / 加密egress / 节点拓扑 / IPAM | 5 策略面 / 6 CT-NAT / 7 服务LB / 8 加密egress（+身份/认证、节点拓扑、IPAM） |
| **轴3 横切** | 贯穿所有阶段/域 | 生命周期 / 装配 / 健康 / 状态存储 / CNI接口 | 9 生命周期 / 10 装配（+健康/状态存储/CNI） |

> 关键：**轴2 特性域不是和轴1 并列的层，而是正交的切面**——每个特性域都有自己的控制/缓存/转发/观察四段。
> 十面里 5~8 被「提升为面」，是因为它们跨阶段足够重；三轴视图把它们还原成「特性域 × 阶段」的矩阵。

## 2. 十面 → 三轴映射

| 十面 | 轴1 阶段 | 轴2 特性域 | 轴3 横切 |
| --- | --- | --- | --- |
| 1 控制面 | 控制 | —（各域的控制段） | — |
| 2 缓存面 | 缓存 | —（各域的缓存段） | — |
| 3 转发面 | 转发 | —（各域的执行段） | — |
| 4 切面 | 观察 | —（各域的观察段） | — |
| 5 策略面 | — | 策略 | — |
| 6 CT/NAT 面 | — | CT-NAT | — |
| 7 服务/LB 面 | — | 服务LB | — |
| 8 加密/egress/masq 面 | — | 加密egress | — |
| 9 生命周期面 | — | — | 生命周期 |
| 10 装配面 | — | — | 装配 |

## 3. 特性域 × 阶段 落位矩阵（核心对象）

> 单元格 = 该特性域在该阶段的归属对象（按「谁写状态」落位）。

| 特性域 | 控制 | 缓存 | 转发 | 观察 |
| --- | --- | --- | --- | --- |
| **身份/认证**（主链） | `CachingIdentityAllocator`、`GlobalIdentity`、`labelsfilter`、`Endpoint`、`AuthManager`、`mutualAuthHandler` | `IPCache`、`EndpointManager`、`IDManager`、`Identity` | `BPFListener`、`VniKey`、`cilium_ipcache_vni`、`bpf_lxc`、`cilium_auth_map` | `EndpointResolver`、`Flow.vni_id` |
| **策略** | `policyWatcher`、`PolicyRepository` | `SelectorCache`、`policyCache` | `mapState`→`policymap` | policy verdict 事件 |
| **服务LB** | `K8sWatcher`(service/endpoints) | `Service`/`Backend`(stateDB) | `Writer`、`BPFOps`、`cilium_lb*` | `ContextOptions`(vni 标签，前端富化) |
| **CT-NAT** | — | ct/nat map（用户态 GC 侧） | `bpf_lxc` ct/nat lookup、`GC` | drop/trace 事件 |
| **加密egress** | `EgressManager`（配置） | — | `EgressMap`/`IPMasqMap`/xfrm/WG peer | — |
| **节点/拓扑** | `NodeDiscovery`、`NodeManager`、`LocalNodeStore` | node manager cache、stateDB tables（`Device`/`NodeAddress`/`RouteMTU`） | `cilium_node_map`、neighbor、route/device | node metrics |
| **IPAM** | `IPAM`（allocator/multipool/podippool）、`node_manager` | — | — | IPAM metrics |

## 4. 横切关注点（轴3）

| 横切 | 核心对象 | 现状 |
| --- | --- | --- |
| 生命周期 | `endpointRestorer`、`LocalIdentityRestorer`、`Regenerator`、`dynamiclifecycle` | 十面 9 |
| 装配 | `Hive`、`Cell`、`Module`、`Agent` | 十面 10 |
| 健康/就绪 | `health`、`healthz`、`status`、connectivity probe | 已并入（折叠在 4 切面） |
| 状态存储 | kvstore、stateDB、CRD storage、restore | 已并入（散在 2/9） |
| CNI 接口 | CNI chaining、cgroup manager、netns、endpoint 创建 | 已并入（折叠在 1 控制） |

## 5. 候选「第 11+ 面」已并入三轴

| 候选面 | 三轴归宿 |
| --- | --- |
| 身份/认证面 | ✅ 已并入 轴2「身份/认证」特性域（含 auth/mTLS/Spire） |
| 节点/拓扑面 | ✅ 已并入 轴2「节点/拓扑」特性域 |
| IPAM/地址管理面 | ✅ 已并入 轴2「IPAM」特性域 |
| 健康/就绪面 | ✅ 已并入 轴3「健康/就绪」横切 |
| 状态存储面 | ✅ 已并入 轴3「状态存储」横切 |
| 运行时/CNI 接口面 | ✅ 已并入 轴3「CNI 接口」横切 |

## 6. 用法

- **找路**：先定特性域（轴2）→ 沿阶段（轴1）串控制→缓存→转发→观察 → 途中标横切（轴3）。
- **三问校验**：层（阶段/域）→ 对象（矩阵单元格）→ 读写边（矩阵内与跨矩阵边）。
- **VNI 核对**：VNI 语义落在「身份」主链上（identity/ipcache/ipcache_vni/vni_id），其它特性域只问「键是什么」。
