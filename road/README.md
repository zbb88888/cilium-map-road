# cilium 图路 · 路（road）

> 每一条路 = 一个特性 / 一个对象在完整地图上的跨层切面交互。
> 从 `map/` 找路，写到 `road/` 存路。

## 找路方法

1. **定起点/终点**：这个特性从哪个顶层 API 进来，最终落到哪个内核/导出产物。
2. **在地图上定位经过的层**：对照 `map/00-overview.md` 的「顶层 API → 各层核心对象」表。
3. **逐层串读写边**：每层对象读谁、写谁，用读虚写实箭头画出。
4. **标出基线 vs 增量**：原实现是什么（基线），本特性在哪些对象/文件上叠加了什么（增量）。
5. **写地图坐标**：末了列出经过的层/对象/源码文件，方便回查。

## 已有路

| 优先级 | 路 | 起点 → 终点 | 状态 |
| --- | --- | --- | --- |
| P0 | [ip-to-identity.md](ip-to-identity.md) | Pod/CEP IP → flow 富化（基线） | ✅ |
| P0 | [vni-ip-to-identity.md](vni-ip-to-identity.md) | CRD VNI annotation → flow vni_id / BPF 身份解析 | ✅ |
| P1 | [cnp-to-policymap.md](cnp-to-policymap.md) | CNP/CCNP → policymap（策略编译下发） | ✅ |
| P1 | [cep-vni-propagation.md](cep-vni-propagation.md) | CEP VNI annotation → 全节点 ip@vni:N（跨节点 VNI 传播） | ✅ |
| P2 | [service-clusterip-to-backend.md](service-clusterip-to-backend.md) | Service ClusterIP → backend（❌ 启动拒绝+数据面绕过） | ✅ |
| P2 | [fragment-vni-scope.md](fragment-vni-scope.md) | 分片 VNI 作用域（frag key 加 vni + fail-closed） | ✅ |
| P3 | [assembly-selfcheck.md](assembly-selfcheck.md) | 装配自检（TestAgentCell → Populate → 门禁） | ✅ |
| 验证 | [mutual-auth.md](mutual-auth.md) | Mutual Auth（非 VNI 特性的找路验证） | ✅ |
| 补缺 | [encryption-egress-rejection.md](encryption-egress-rejection.md) | 加密/egress/masq 拒绝（面 8 ❌ 门禁） | ✅ |
| 补缺 | [endpoint-restore.md](endpoint-restore.md) | endpoint 恢复（VNI 序列化+重读，面 9） | ✅ |
| 组件 | [operator-identity-gc.md](operator-identity-gc.md) | operator identity GC（组件首条路，identity 键安全） | ✅ |
| 补缺 | [observability-pipeline.md](observability-pipeline.md) | monitor 事件 → flow → metrics（面 4 主路） | ✅ |

## 覆盖矩阵（路 × 层）

| 路 \ 层 | 1控 | 2缓 | 3转 | 4切 | 5策 | 6CT | 7LB | 8密 | 9命 | 10装 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ip-to-identity | ✅ | ✅ | ✅ | ✅ | ✅ | | | | | |
| vni-ip-to-identity | ✅ | ✅ | ✅ | ✅ | ✅ | | | | | |
| cnp-to-policymap | ✅ | | ✅ | | ✅ | | | | | |
| cep-vni-propagation | ✅ | ✅ | ✅ | | | | | | | |
| service-clusterip-to-backend | ✅ | | ✅ | | | | ✅ | | | |
| fragment-vni-scope | | | ✅ | | | ✅ | | | | |
| assembly-selfcheck | | | | | | | | | | ✅ |
| mutual-auth | ✅ | | ✅ | | ✅ | | | | | ✅ |
| encryption-egress-rejection | ✅ | | | | | | | ✅ | | ✅ |
| endpoint-restore | ✅ | ✅ | ✅ | | | | | | ✅ | |
| operator-identity-gc | ✅ | | | | | | | | | |
| observability-pipeline | | | | ✅ | | | | | | |
| **覆盖计数** | 9 | 4 | 8 | 3 | 4 | 1 | 1 | 1 | 1 | 3 |

> 十面全部有路覆盖。**组件维度**：agent（绝大多数路）、operator（operator-identity-gc）、clustermesh/hubble-relay（尚待补，见 map/todo）。

## 待找路

> 当前无待找路。新特性到来时，回到 `map/` 找路、回到三问校验、落到 `road/` 存路。
