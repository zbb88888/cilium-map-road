# cilium10level

把 Cilium 按「十个面（plane）」拆开，逐面确认完备性，并重点核对 `(VNI, IP)` 状态表达是否在每个面落地。

- 源码基线：`/root/7/cilium`
- 设计文档基线：「The ten planes」十面清单

## 文档索引

| 文档 | 内容 |
| --- | --- |
| [docs/00-methodology.md](docs/00-methodology.md) | 做事思路：分层原则、读者/写者关系、图式约定、验收门禁 |
| [docs/01-planes-overview.md](docs/01-planes-overview.md) | 十面总览 + 每面文件梳理 + 层间交互图 + 层×组件矩阵 |
| [docs/02-polish-tracker.md](docs/02-polish-tracker.md) | 打磨追踪（逐层·逐个对象四项核对） |
| [docs/planes/01-control-plane.md](docs/planes/01-control-plane.md) | 第 1 面：控制面（对象模型 / 读者写者 / 承上启下 / VNI 完备性） |
| [docs/planes/02-cache-plane.md](docs/planes/02-cache-plane.md) | 第 2 面：缓存面（共享真相 / 读虚写实 / VNI fail-closed） |
| [docs/planes/03-datapath-plane.md](docs/planes/03-datapath-plane.md) | 第 3 面：转发面（cilium_ipcache_vni 权威 / cilium_lxc 非权威） |
| [docs/planes/04-observability-plane.md](docs/planes/04-observability-plane.md) | 第 4 面：切面（flow vni_id / 指标 vni 标签） |
| [docs/planes/05-policy-plane.md](docs/planes/05-policy-plane.md) | 第 5 面：策略面（identity 天然 VNI 化；CIDR/FQDN/L7 边界） |
| [docs/planes/06-conntrack-nat-plane.md](docs/planes/06-conntrack-nat-plane.md) | 第 6 面：CT/NAT（❌ 裸五元组，调度隔离+指标告警） |
| [docs/planes/07-service-lb-plane.md](docs/planes/07-service-lb-plane.md) | 第 7 面：服务/LB（❌ 裸 IP，启动即拒绝） |
| [docs/planes/08-encryption-egress-masq-plane.md](docs/planes/08-encryption-egress-masq-plane.md) | 第 8 面：加密/egress/masq（❌ 裸 IP，启动即拒绝） |
| [docs/planes/09-lifecycle-plane.md](docs/planes/09-lifecycle-plane.md) | 第 9 面：生命周期（流程性，状态迁移矩阵） |
| [docs/planes/10-assembly-plane.md](docs/planes/10-assembly-plane.md) | 第 10 面：装配面（hive 图，TestAgentCellNativeVPC 门禁） |

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

## 当前进度

- [x] 做事思路（方法论）
- [x] 十面文件梳理
- [x] 控制面逐面确认
- [x] 缓存面
- [x] 转发面
- [x] 切面（可观察性）
- [x] 策略面
- [x] 连接跟踪 / NAT 面
- [x] 服务 / 负载均衡面
- [x] 加密 / egress gateway / masquerade 面
- [x] 生命周期面
- [x] 装配面
