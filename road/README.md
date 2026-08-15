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

## 待找路（按优先级）

| 优先级 | 路 | 为什么排这个优先级 |
| --- | --- | --- |
| P1 | CNP → policy map | identity 链的终点执行，策略面 ✅ 的落地验证 |
| P1 | CEP → 全节点 VNI 传播 | 缓存面跨节点，VNI 路的横向分支 |
| P2 | Service ClusterIP → backend | ❌ 服务面，含启动拒绝门禁 |
| P2 | 分片 VNI 作用域 | fragment map fail-closed，CT/NAT 面唯一部分 VNI 化点 |
| P3 | 装配自检路 | TestAgentCell → Populate → 缺失类型/降级门禁 |
