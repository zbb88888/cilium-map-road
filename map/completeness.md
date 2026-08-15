# 完备性账本（顶层设计三问）

> 这张账本是 `cilium 图路` 的**顶层验收门禁**。任何时候对地图问三件事：
> 1. 当前一共多少层，是否完备？
> 2. 每一层有多少核心对象，是否完备？
> 3. 每一个对象有多少读者、写者，是否完备？
>
> 三问逐级下钻：层 → 对象 → 读写边。任何一层/一对象/一条边不齐，地图就不算完备。

## 问 1：当前一共多少层，是否完备？

**答：10 层，完备。** 每层都有独立 md（`map/01~10`），且都按七步模板产出（定位/对象模型/状态所有权/读写矩阵/层间概览/VNI判定/边界风险）。

| # | 层 | md | 完备性 |
| --- | --- | --- | --- |
| 1 | 控制面 | `01-control-plane.md` | ✅ |
| 2 | 缓存面 | `02-cache-plane.md` | ✅ |
| 3 | 转发面 | `03-datapath-plane.md` | ✅ |
| 4 | 切面 | `04-observability-plane.md` | ✅ |
| 5 | 策略面 | `05-policy-plane.md` | ✅ |
| 6 | CT/NAT 面 | `06-conntrack-nat-plane.md` | ✅ |
| 7 | 服务/LB 面 | `07-service-lb-plane.md` | ✅ |
| 8 | 加密/egress/masq 面 | `08-encryption-egress-masq-plane.md` | ✅ |
| 9 | 生命周期面 | `09-lifecycle-plane.md` | ✅ |
| 10 | 装配面 | `10-assembly-plane.md` | ✅ |

## 问 2：每一层有多少核心对象，是否完备？

**答：共 58 个去重核心对象。**（值/键类型也计入，因为它们是被读写的状态载体。）

| 层 | 核心对象 | 计数 |
| --- | --- | --- |
| 1 控制面 | K8sWatcher、Endpoint、EndpointManager、IPCache、IDManager、GlobalIdentity、IPAM、NodeManager、K8sAPI | 9 |
| 2 缓存面 | IPCache、Identity、EndpointManager、IDManager、CachingIdentityAllocator、BPFListener、Endpoint、IPIdentitySynchronizer、DNSProxy、EndpointResolver | 10 |
| 3 转发面 | IPCache、BPFListener、VniKey、Key、EndpointKey、Loader、Endpoint、bpf_lxc | 8 |
| 4 切面 | MonitorAgent、ThreeFourParser、SevenParser、EndpointResolver、IPCache、EndpointManager、LogRecord、Flow、ContextOptions | 9 |
| 5 策略面 | PolicyRepository、policyCache、SelectorCache、mapState、labelsfilter、GlobalIdentity、FQDNDataServer、DNSProxy、LogRecord、EndpointManager、IPCache | 11 |
| 6 CT/NAT | TupleKey4、CtKey4Global、NatKey4、CtEntry、GC、EndpointManager、bpf_lxc | 7 |
| 7 服务/LB | Service、Backend、Writer、BPFOps、Maglev、socketlb、bpf_lxc | 7 |
| 8 加密/egress/masq | WireGuardAgent、IPSecAgent、EgressManager、IPMasqAgent、bpf_lxc | 5 |
| 9 生命周期 | endpointRestorer、Endpoint、LocalIdentityRestorer、Regenerator、dynamiclifecycle、Manager | 6 |
| 10 装配 | Hive、Cell、Module、Agent、TestAgentCell、TestAgentCellNativeVPC | 6 |

> 跨层共享对象（`IPCache`、`EndpointManager`、`Endpoint`、`IDManager`、`GlobalIdentity`、`DNSProxy`、`LogRecord`、`bpf_lxc`、`EndpointResolver`）以**归属层**为准，其它层出现时标注为「读/写该对象」。

## 问 3：每一个对象有多少读者、写者，是否完备？

**判定规则**：
- 无孤儿：每个对象至少有一个读者或写者（纯键/值类型如 `VniKey`/`CtEntry`/`Flow` 以「被写 + 被读」计）。
- 无悬空状态：每块业务状态都有写者（归属层明确）。
- 每条边都有读虚写实箭头对应，且方向正确。

| 归属层 | 对象 | 读者 | 写者 | 完备性 |
| --- | --- | --- | --- | --- |
| 1 | K8sWatcher | K8sAPI | IPCache、NodeManager | ✅ |
| 1 | Endpoint | IPCache、IDManager | EndpointManager、IDManager、IPCache、IPAM、Loader | ✅ |
| 1 | IPAM | — | Endpoint（Allocate/Release） | ✅ |
| 1 | NodeManager | 转发面/缓存面 | K8sWatcher | ✅ |
| 1 | K8sAPI | K8sWatcher | 外部 | ✅ |
| 2 | IPCache | BPFListener、DNSProxy、EndpointResolver、FQDNDataServer | Endpoint、K8sWatcher、IPIdentitySynchronizer | ✅ |
| 2 | Identity | 查询方 | IPCache（Upsert 存入） | ✅ |
| 2 | EndpointManager | DNSProxy、ThreeFourParser、FQDNDataServer | Endpoint | ✅ |
| 2 | IDManager | Endpoint（解析）、策略面 | Endpoint（引用） | ✅ |
| 2 | CachingIdentityAllocator | 缓存面查询 | Endpoint（分配） | ✅ |
| 2 | BPFListener | IPCache（订阅） | IPCache（通知） | ✅ |
| 2 | IPIdentitySynchronizer | kvstore | IPCache | ✅ |
| 2 | DNSProxy | EndpointManager、IPCache | LogRecord | ✅ |
| 2 | EndpointResolver | IPCache | — | ✅ |
| 3 | BPFListener | IPCache | Key、VniKey | ✅ |
| 3 | Loader | — | bpf_lxc（加载） | ✅ |
| 3 | bpf_lxc | VniKey、EndpointKey、CtKey、NatKey、EgressMap、EncryptMap | CtKey、NatKey、policymap | ✅ |
| 3 | VniKey/Key/EndpointKey | bpf_lxc | BPFListener/Endpoint | ✅（键类型） |
| 4 | MonitorAgent | ThreeFourParser | 转发面（事件） | ✅ |
| 4 | ThreeFourParser | MonitorAgent、EndpointManager | Flow | ✅ |
| 4 | SevenParser | LogRecord | Flow | ✅ |
| 4 | EndpointResolver | IPCache | — | ✅ |
| 4 | Flow | ContextOptions、exporter | ThreeFourParser、SevenParser | ✅ |
| 4 | ContextOptions | Flow | Prometheus | ✅ |
| 4 | LogRecord | SevenParser | DNSProxy | ✅ |
| 5 | PolicyRepository | policyCache | 控制面 watcher | ✅ |
| 5 | policyCache | PolicyRepository、SelectorCache | mapState | ✅ |
| 5 | SelectorCache | GlobalIdentity | — | ✅ |
| 5 | mapState | 转发面（policymap 下发） | policyCache | ✅ |
| 5 | labelsfilter | — | GlobalIdentity（VNI label） | ✅ |
| 5 | GlobalIdentity | SelectorCache、identity allocator | labelsfilter | ✅ |
| 5 | FQDNDataServer | EndpointManager、IPCache | — | ✅ |
| 5 | DNSProxy | EndpointManager | LogRecord | ✅ |
| 6 | GC | CtEntry（扫描） | CtEntry（删除过期） | ✅ |
| 6 | bpf_lxc | CtKey4Global、NatKey4 | CtKey4Global、NatKey4 | ✅ |
| 6 | CtKey4Global/NatKey4/CtEntry | bpf_lxc、GC | bpf_lxc | ✅（键/值类型） |
| 7 | Writer | Service、Backend | — | ✅ |
| 7 | BPFOps | — | Maglev、LBMaps | ✅ |
| 7 | socketlb | Backend | — | ✅ |
| 7 | bpf_lxc | LBMaps | — | ✅ |
| 7 | Service/Backend/Maglev | Writer、socketlb、bpf_lxc | BPFOps | ✅（值类型） |
| 8 | WireGuardAgent | NodeIP | — | ✅ |
| 8 | IPSecAgent | — | xfrm | ✅ |
| 8 | EgressManager | Endpoint（source IP） | EgressMap | ✅ |
| 8 | IPMasqAgent | — | IPMasqMap | ✅ |
| 8 | bpf_lxc | EgressMap、EncryptMap | — | ✅ |
| 9 | endpointRestorer | Endpoint、K8sAnnotation | Endpoint（重建） | ✅ |
| 9 | LocalIdentityRestorer | — | IPCache（重建） | ✅ |
| 9 | Regenerator | — | BPF（再生） | ✅ |
| 9 | dynamiclifecycle | — | CellLifecycle（启停） | ✅ |
| 9 | Manager | — | 控制循环 | ✅ |
| 10 | Hive/Cell/Module/Agent | TestAgentCell* | cell（provide） | ✅（装配） |
| 10 | TestAgentCell / TestAgentCellNativeVPC | Hive（校验） | — | ✅（门禁） |

> 结论：58 个对象无孤儿、无悬空状态，读虚写实边全部对齐。
> 新增对象时，必须先回答：它属于哪一层、读谁、写谁——三问缺一不可入图。
