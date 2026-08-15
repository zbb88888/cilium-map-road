# 待完善点清单（按优先级）

> 用途：让「还差什么」显式化。每完成一项就勾掉并提交。

## P0：operator 组件无路覆盖 ✅

- [x] 铺 `road/operator-identity-gc.md`（identity 键、VNI 安全，operator 组件首条路）

## P1：clustermesh-apiserver / hubble-relay 组件对象未入账 ✅

- [x] clustermesh-apiserver：`KVStoreMesh`/`clustersHandler` 入账（map/01 §8）
- [x] hubble-relay：`relay/server.Server`/`healthServer` 入账（map/04 §9）
- [x] 账本 77→82 对象

## P2：层间图 ↔ 层内图互链（方法论 §8 唯一未勾项） ✅

- [x] 十个面文档各加「互链」尾节：对象模型 ↔ 层间概览 ↔ 经过本层的路 ↔ 账本/todo

## P2：面 4 切面路覆盖薄 ✅

- [x] 铺 `road/observability-pipeline.md`（monitor → parser → flow → metrics，面 4 主路）
- [x] 覆盖矩阵面 4 计数 2→3

## P3：operator 对象 reader/writer 粗粒度

- 现状：账本里 operator 19 对象只有粗粒度读写边（读 CRD/kvstore，写 CRD/心跳）。
- 动作：至少对 `identitygc.GC`/`endpointgc.GC`/`lbipam` 三个对象细化读者/写者。

## P3：road 覆盖矩阵缺「组件」维度 ✅

- [x] 新增独立「路 × 组件」矩阵（agent/operator/clustermesh-apiserver/hubble-relay 四组件全覆盖）
- [x] `map/00-overview.md` 层×组件矩阵刷新（82 对象 × 4 组件）
- [x] 铺 `road/clustermesh-kvstoremesh.md` 补齐 clustermesh-apiserver 零覆盖

## 新任务：逐层打磨对象读者/写者（源码级校验）

> 方法：对每层每个对象，grep 实际调用点，验证每条读/写边，修正错边、补缺边。

| 层 | 进度 | 本轮修正 |
| --- | --- | --- |
| 1 控制面 | ✅ | Endpoint 不写 IPAM（写者是 endpointRestorer/infra allocator）；Endpoint→IPCache 是经 IPIdentitySynchronizer 链式写；Endpoint 读 IPCache（DNS rules/named ports）；GlobalIdentity 写者= CachingIdentityAllocator（非 labelsfilter 直接写） |
| 2 缓存面 | ✅ | 边基本准确；澄清：ThreeFourParser 经 `payloadGetters`(EndpointGetter) 读 EndpointManager；policyCache 订阅 IDManager（`idmgr.Subscribe`） |
| 3 转发面 | ✅ | 补入 `Orchestrator` 对象；修正 Endpoint 不直接写 Loader，而是 Endpoint→Orchestrator→Loader（`e.orchestrator.ReloadDatapath`） |
| 4 切面 | ✅ | 补入 `LocalObserverServer`（observer）与 `Parser(Decoder)`；修正真实链 MonitorAgent→LocalObserverServer→Parser→ThreeFour/Seven（非 parser 直接读 MonitorAgent）；账本 85 对象 |
| 5 策略面 | ✅ | SelectorCache 读 identity cache(1)（非 GlobalIdentity 直接）；其余边准确 |
| 6 CT/NAT | ✅ | 边准确（GC 扫描+删除 CtEntry，bpf_lxc 读/写 ct/nat key） |
| 7 服务/LB | ✅ | 修正 BPFOps 是读 Maglev（GetLookupTable）非写；Maglev 纯计算；Service/Backend 写者= K8sWatcher（经 stateDB） |
| 8 加密/egress/masq | ✅ | EgressManager 读 Endpoint(Identity/labels) 非 source IP；其余准确 |
| 9 生命周期 | ✅ | 边准确（endpointRestorer/LocalIdentityRestorer/Regenerator/dynamiclifecycle/Manager） |
| 10 装配 | ✅ | 边准确（Hive/Cell/Module/Agent + TestAgentCell 门禁） |

## 里程碑巡检报告（v1.0）

- [x] 对象数一致：问2 求和 = 85 = 问3 结论（无 58/77/82/83 残留）
- [x] 链接：map/road/README 全部无 broken link
- [x] mermaid：所有文档 fence 平衡
- [x] 读写箭头：无「实线标读 / 虚线标写」违例
- [x] 覆盖矩阵：层 9+4+8+3+4+1+1+1+1+3=35；组件 11+2+1+1=15；已有路 13 条
- [x] 旧对象名残留：仅存在于「打磨修正」说明（有意保留的改名历史），无实际误用
