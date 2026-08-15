# cilium 图路

把 Cilium 建成一张**完整的分层（分组件）架构地图**；每个特性，都从地图里找出一条「路」。

- 源码基线：`/root/7/cilium`
- 设计基线：「The ten planes」十面清单
- 核心校验：`(VNI, IP)` 状态表达是否在每个面落地

## 两个目录

| 目录 | 职责 |
| --- | --- |
| [`map/`](map/) | 全景图：十面、每面核心对象、读者/写者关系、层边界、顶层 CRD→核心对象 |
| [`road/`](road/) | 路：元素切面，把某个特性/对象跨层交互串成一条路 |

## 找路流程

拿到特性 → 在 `map/` 定位经过的层与对象 → 串跨层读写边（读虚写实）→ 写 `road/<feature>.md`。

已有路：
- [`road/vni-ip-to-identity.md`](road/vni-ip-to-identity.md)：VNI+IP → identity，如何叠加在 IP → identity 基线上。

## 十面清单（权威表）

| 面 | (VNI, IP) 状态 |
| --- | --- |
| 控制面 | VNI 化 ✅ |
| 缓存面 | VNI 化 ✅ |
| 转发面 | VNI 化 ✅（cilium_lxc 非权威） |
| 切面（可观察性） | VNI 化 ✅ |
| 策略面 | 经 identity 天然 VNI 化 ✅；CIDR/FQDN 与 L7 代理是边界 |
| 连接跟踪 / NAT 面 | ❌ 今天无法表达 (VNI,IP) —— 已文档化 + 运行时检测 |
| 服务 / 负载均衡面 | ❌ 按裸 IP —— 启动即拒绝 |
| 加密 / egress gateway / masquerade 面 | ❌ 按裸 IP —— 启动即拒绝 |
| 生命周期面（升级/重启/修复） | 流程性，已文档化 |
| 装配面（hive 依赖图） | 本轮发现 P0，已修 + 纳入验收门禁 |

## 地图入口

- 图例与找路规则：[`map/README.md`](map/README.md)
- 十面总览（层边界 + 顶层 CRD→核心对象 + 层间交互图 + 文件梳理）：[`map/00-overview.md`](map/00-overview.md)
- 完备性三问账本（层/对象/读写边）：[`map/completeness.md`](map/completeness.md)
- 逐面：`map/01-control-plane.md` … `map/10-assembly-plane.md`
