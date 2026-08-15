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

| 路 | 起点 → 终点 | 状态 |
| --- | --- | --- |
| [vni-ip-to-identity.md](vni-ip-to-identity.md) | CRD Pod/CEP VNI annotation → flow vni_id / BPF 身份解析 | ✅ |

## 待找路（候选清单）

- IP → identity（基线本身，供 VNI 路做对照）
- CNP → policy map（策略编译下发的完整路径）
- Service ClusterIP → backend（LB 下发路径，含 ❌ 启动拒绝）
- CEP → 全节点 VNI 传播（跨节点 identity 解析）
- 分片 VNI 作用域（fragment map 的 fail-closed 路）
- 装配自检路（TestAgentCell → Populate → 缺失类型/降级门禁）
