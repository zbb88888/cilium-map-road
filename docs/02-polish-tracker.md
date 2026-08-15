# 打磨追踪（逐层 · 逐个对象）

> 打磨定义：对每个面的**每个对象**做四项核对，逐项打勾，发现错误当场修正到对应 `docs/planes/*.md`。
>
> 四项核对：
> 1. **类型名**——真实存在吗？是 struct / interface / 包级函数 / 外部对象？
> 2. **方法/字段**——签名与源码一致吗？
> 3. **读/写边**——读者/写者关系完整、方向正确吗？（读虚、写实）
> 4. **VNI 状态**——引用的证据文件与结论一致吗？

## 1. 控制面 ✅

| 对象 | 类型名 | 方法/字段 | 读/写边 | VNI 状态 | 状态 |
| --- | --- | --- | --- | --- | --- |
| K8sWatcher | ✅ `pkg/k8s/watchers/watcher.go` struct | ✅ 已改为真实方法 | ✅ 补 `--> IPCache`/`--> NodeManager` | ✅ | 已打磨 |
| Endpoint | ✅ `pkg/endpoint/endpoint.go` | ✅ `Regenerate(regenMetadata)`、`SyncVNIFromPodAnnotation` | ✅ | ✅ | 已打磨 |
| EndpointManager | ✅ interface/struct | ✅ | ✅ | ✅ | 已打磨 |
| IPCache | ✅ `pkg/ipcache/ipcache.go` | ✅ | ✅ | ✅ | 已打磨 |
| IDManager | ✅ interface + IdentityManager | ✅ | ✅ | ✅ | 已打磨 |
| GlobalIdentity | ✅ 已从 `GlobalIdentityKey` 更名 | ✅ `GetKey()` | ✅ | ✅ | 已打磨 |
| IPAM | ✅ `pkg/ipam/types.go` | ✅ `AllocateIP/ReleaseIP` 真实签名 | ✅ | ✅ | 已打磨 |
| NodeManager | ✅ `pkg/node/manager/cell.go` interface | ✅ | ✅ | ✅ | 已打磨 |
| Daemon | ❌ 无此 struct（hive 化） | — | — | — | 已移除，改为文字说明 |
| podVNI/ciliumEndpointVNI | ✅ 包级自由函数 | — | — | ✅ | 已改为文字说明 |

## 2. 缓存面 ✅

| 对象 | 修正 | 状态 |
| --- | --- | --- |
| KVStoreSynchronizer | → `IPIdentitySynchronizer`（真实类型 `pkg/ipcache/kvstore.go`） | 已打磨 |
| HubbleObserver | → `EndpointResolver`（真实读者，经 `getters.IPGetter` 读 IPCache） | 已打磨 |
| CachingIdentityAllocator | 方法改为真实签名 `AllocateIdentity/Release`（去伪 `ForeachCache`） | 已打磨 |
| 其余对象 | 类型名/方法/读/写边已核对 | 已打磨 |

## 3. 转发面 ✅

| 对象 | 修正 | 状态 |
| --- | --- | --- |
| Loader | 确认为接口 `pkg/datapath/types/loader.go`，方法改 `ReloadDatapath`（去伪 `compileAndLoad`） | 已打磨 |
| EndpointRegenerator | → `Endpoint`（`Regenerate(regenMetadata)` 是 Endpoint 方法，`Regenerator` 是 fence 对象） | 已打磨 |
| BPFLXC | → `bpf_lxc`（BPF 程序，非 Go 对象，加注） | 已打磨 |
| 其余对象 | VniKey/Key/EndpointKey/BPFListener 已核对 | 已打磨 |

## 4. 切面 ✅

| 对象 | 修正 | 状态 |
| --- | --- | --- |
| MonitorAgent | 实际为接口 `monitor/agent.Agent`，加注 | 已打磨 |
| TraceNotifyParser/L7Parser | → `ThreeFourParser`/`SevenParser`（实际 `threefour.Parser`/`seven.Parser`） | 已打磨 |
| AccessLogRecord | → `LogRecord`（`pkg/proxy/accesslog`） | 已打磨 |
| FlowProto | → `Flow`（`api/v1/flow` 生成类型） | 已打磨 |
| MetricsContext | → `ContextOptions`（`pkg/hubble/metrics/api`） | 已打磨 |
| 其余对象 | 已核对 | 已打磨 |

## 5. 策略面 ✅

| 对象 | 修正 | 状态 |
| --- | --- | --- |
| Distillery | 无此类型 → `policyCache`（`pkg/policy/distillery.go`） | 已打磨 |
| MapState | → `mapState`（未导出，别名 `MapStateMap`） | 已打磨 |
| LabelsFilter | 是包（`labelsfilter.Filter`），非 struct，加注 | 已打磨 |
| GlobalIdentityKey | → `GlobalIdentity`（与前后面对齐） | 已打磨 |
| FQDNService | → `FQDNDataServer`（`pkg/fqdn/service/service.go`） | 已打磨 |
| AccessLogRecord | → `LogRecord`（`pkg/proxy/accesslog`） | 已打磨 |
| 其余对象 | 已核对 | 已打磨 |

## 6. 连接跟踪 / NAT 面 ✅

| 对象 | 修正 | 状态 |
| --- | --- | --- |
| CTGC | → `GC`（`pkg/maps/ctmap/gc`，方法 `Run(filter)`） | 已打磨 |
| BPFLXC | → `bpf_lxc`（与转发面对齐） | 已打磨 |
| 其余对象 | TupleKey4/CtKey4Global/NatKey4/CtEntry 已核对（裸五元组无 VNI） | 已打磨 |

## 7. 服务 / 负载均衡面 ✅

| 对象 | 修正 | 状态 |
| --- | --- | --- |
| LBWriter | 拆成 `Writer`（选 backend）+ `BPFOps`（写 BPF map，`pkg/loadbalancer/reconciler`） | 已打磨 |
| SocketLB | → `socketlb`（包，函数 `Enable`） | 已打磨 |
| BPFLXC | → `bpf_lxc`（对齐） | 已打磨 |
| 其余对象 | Service/Backend/Maglev 已核对 | 已打磨 |

## 8. 加密 / egress / masquerade 面 ✅

| 对象 | 修正 | 状态 |
| --- | --- | --- |
| IPSecManager | → `IPSecAgent`（实际 `ipsec.Agent`） | 已打磨 |
| EgressGatewayManager | → `EgressManager`（实际 `egressgateway.Manager`） | 已打磨 |
| BPFLXC | → `bpf_lxc`（对齐） | 已打磨 |
| 其余对象 | WireGuardAgent（`wireguard/agent.Agent`）/IPMasqAgent 已核对 | 已打磨 |

## 9. 生命周期面 ✅

| 对象 | 修正 | 状态 |
| --- | --- | --- |
| EndpointRestore | → `endpointRestorer`（`daemon/cmd/endpoint_restore.go`） | 已打磨 |
| IPCacheRestore | → `LocalIdentityRestorer`（`pkg/ipcache/restore`） | 已打磨 |
| DynamicLifecycle | 实际是 `dynamiclifecycle` cell + `DynamicFeature` stateDB 表 | 已打磨 |
| ControllerManager | → `Manager`（`pkg/controller/manager.go`） | 已打磨 |
| 其余对象 | 已核对 | 已打磨 |

## 10. 装配面 ✅

| 对象 | 修正 | 状态 |
| --- | --- | --- |
| TestAgentCell / TestAgentCellNativeVPC | 是测试函数（`daemon/cmd/cells_test.go`），非类型，加注 | 已打磨 |
| 其余对象 | Hive/Cell/Module/Agent 已核对 | 已打磨 |

## 全局打磨清单（方法论 §8）

> 逐层·逐个对象打磨已完成（1–10 面全部 ✅）。以下全局项待确认：

- [x] 术语统一：面/层/组件/对象/状态域 五词不混用（对象名已逐面对齐源码）
- [x] 每个 ❌ 面都有「为什么 + 如何检测」一段话（06/07/08 面）
- [ ] 层间图与层内图互链（每面两图已齐，交叉引用可再加强）
- [x] 每面结尾「承上启下一句话」可串成完整叙事
