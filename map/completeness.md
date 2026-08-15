# 完备性账本（顶层设计三问）

> 这张账本是 `cilium 图路` 的**顶层验收门禁**。任何时候对地图问三件事：
> 1. 当前一共多少层，是否完备？
> 2. 每一层有多少核心对象，是否完备？
> 3. 每一个对象有多少读者、写者，是否完备？
>
> 三问逐级下钻：层 → 对象 → 读写边。任何一层/一对象/一条边不齐，地图就不算完备。
> 归属规则：**谁写状态，谁就是归属层**；跨层对象只在本表出现一次（归属层），其它层以「读/写」引用它。

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

**答：共 85 个去重核心对象，按归属层归位。**（层 1 跨 agent/operator/clustermesh，层 4 跨 agent/hubble-relay）

| 层 | 核心对象（归属本层） | 计数 |
| --- | --- | --- |
| 1 控制面 | agent 侧：K8sWatcher、Endpoint、IPAM、NodeManager、CachingIdentityAllocator、GlobalIdentity、labelsfilter、K8sAPI(外部)（8）；operator 侧：identitygc、ciliumidentity、ciliumendpointslice、endpointgc、endpointslicegc、unmanagedpods、policyderivative、lbipam、nodeipam、gatewayapi、ingress、bgp、cmoperator、endpointslicesync、mcsapi、networkpolicy、secretsync、ztunnel、ciliumenvoyconfig（19）；clustermesh-apiserver 侧：KVStoreMesh、clustersHandler、clustermesh.Cell/kvstoremesh.Cell（3） | 30 |
| 2 缓存面 | IPCache、Identity、EndpointManager、IDManager、IPIdentitySynchronizer | 5 |
| 3 转发面 | BPFListener、Orchestrator、Loader、bpf_lxc、VniKey、Key、EndpointKey | 7 |
| 4 切面 | agent 侧：MonitorAgent、LocalObserverServer、Parser(Decoder)、ThreeFourParser、SevenParser、EndpointResolver、Flow、ContextOptions（8）；hubble-relay 侧：relay/server.Server、healthServer（2） | 10 |
| 5 策略面 | PolicyRepository、policyCache、SelectorCache、mapState、FQDNDataServer、DNSProxy、LogRecord | 7 |
| 6 CT/NAT | TupleKey4、CtKey4Global、NatKey4、CtEntry、GC | 5 |
| 7 服务/LB | Service、Backend、Writer、BPFOps、Maglev、socketlb | 6 |
| 8 加密/egress/masq | WireGuardAgent、IPSecAgent、EgressManager、IPMasqAgent | 4 |
| 9 生命周期 | endpointRestorer、LocalIdentityRestorer、Regenerator、dynamiclifecycle、Manager | 5 |
| 10 装配 | Hive、Cell、Module、Agent、TestAgentCell、TestAgentCellNativeVPC | 6 |

> 归属澄清（本轮修正）：`CachingIdentityAllocator`/`GlobalIdentity`/`labelsfilter` 属**控制面**（identity 分配与派生），
> 策略面只**读**其结果；`DNSProxy`/`LogRecord` 属**策略面**（L7 代理/accesslog），切面只读 LogRecord；
> `EndpointResolver` 属**切面**（hubble parser），缓存面只被读。

## 问 3：每一个对象有多少读者、写者，是否完备？

**判定规则**：无孤儿对象（每个对象至少有一读者或写者）；无悬空状态（每块状态有写者）；读虚写实边齐全且方向正确。
括号内数字 = 该读者/写者所在归属层。

| 归属层 | 对象 | 读者 | 写者 | 完备性 |
| --- | --- | --- | --- | --- |
| 1 | K8sWatcher | K8sAPI | IPCache(2)、NodeManager(1) | ✅ |
| 1 | Endpoint | IPCache(2)（DNS rules/named ports）、IDManager(2) | EndpointManager(2)（经 AddEndpoint）、IDManager(2)（Add/Remove）、IPCache(2)（经 IPIdentitySynchronizer）、Orchestrator(3)（Regenerate） | ✅ |
| 1 | IPAM | 控制面查询 | endpointRestorer(9)（restore 分配/释放）、infra allocator/CNI handler（daemon） | ✅ |
| 1 | NodeManager | 转发面/缓存面 | K8sWatcher | ✅ |
| 1 | CachingIdentityAllocator | 缓存面查询、策略面 | Endpoint（AllocateIdentity） | ✅ |
| 1 | GlobalIdentity | SelectorCache(5) | CachingIdentityAllocator（GetCIDKeyFromLabels 构造，经 labelsfilter.Filter 注入 VNI label） | ✅ |
| 1 | labelsfilter | CachingIdentityAllocator（调 Filter） | —（纯函数变换） | ✅ |
| 1 | K8sAPI | K8sWatcher | 外部 | ✅ |
| 2 | IPCache | BPFListener(3)、DNSProxy(5)、EndpointResolver(4)、FQDNDataServer(5) | Endpoint(1)、K8sWatcher(1)、IPIdentitySynchronizer(2) | ✅ |
| 2 | Identity | 查询方 | IPCache（Upsert 存入） | ✅ |
| 2 | EndpointManager | DNSProxy(5)、ThreeFourParser(4)、FQDNDataServer(5) | Endpoint(1) | ✅ |
| 2 | IDManager | Endpoint(1)、策略面 | Endpoint(1) | ✅ |
| 2 | IPIdentitySynchronizer | kvstore | IPCache | ✅ |
| 3 | BPFListener | IPCache(2) | Key、VniKey | ✅ |
| 3 | Orchestrator | — | Loader（调用 ReloadDatapath） | ✅ |
| 3 | Loader | — | bpf_lxc（加载） | ✅ |
| 3 | bpf_lxc | VniKey、EndpointKey、CtKey(6)、NatKey(6)、LBMaps(7)、EgressMap(8)、EncryptMap(8) | CtKey(6)、NatKey(6)、policymap(5) | ✅ |
| 3 | VniKey/Key/EndpointKey | bpf_lxc | BPFListener/Endpoint | ✅（键类型） |
| 4 | MonitorAgent | LocalObserverServer（订阅） | 转发面（事件） | ✅ |
| 4 | LocalObserverServer | MonitorAgent | Parser(Decoder)（调 Decode） | ✅ |
| 4 | Parser(Decoder) | LocalObserverServer（被调） | ThreeFourParser、SevenParser（分派） | ✅ |
| 4 | ThreeFourParser | EndpointManager(2)（经 EndpointGetter） | Flow | ✅ |
| 4 | SevenParser | LogRecord(5) | Flow | ✅ |
| 4 | EndpointResolver | IPCache(2) | — | ✅ |
| 4 | Flow | ContextOptions、exporter | ThreeFourParser、SevenParser | ✅ |
| 4 | ContextOptions | Flow | Prometheus | ✅ |
| 5 | PolicyRepository | policyCache | 控制面 watcher | ✅ |
| 5 | policyCache | PolicyRepository、SelectorCache | mapState | ✅ |
| 5 | SelectorCache | identity cache(1)（identity allocator 提供） | — | ✅ |
| 5 | mapState | 转发面（policymap 下发） | policyCache | ✅ |
| 5 | FQDNDataServer | EndpointManager(2)、IPCache(2) | — | ✅ |
| 5 | DNSProxy | EndpointManager(2)、IPCache(2) | LogRecord | ✅ |
| 5 | LogRecord | SevenParser(4) | DNSProxy、Envoy | ✅ |
| 6 | GC | CtEntry（扫描） | CtEntry（删除过期） | ✅ |
| 6 | TupleKey4/CtKey4Global/NatKey4/CtEntry | bpf_lxc(3)、GC | bpf_lxc(3) | ✅（键/值类型） |
| 7 | Writer | Service、Backend | — | ✅ |
| 7 | BPFOps | Maglev（GetLookupTable） | LBMaps | ✅ |
| 7 | socketlb | Backend | — | ✅ |
| 7 | Service/Backend | Writer、socketlb、bpf_lxc(3) | K8sWatcher（service/endpoints watcher，经 stateDB） | ✅（值类型） |
| 7 | Maglev | BPFOps（GetLookupTable） | —（纯计算） | ✅ |
| 8 | WireGuardAgent | NodeIP | — | ✅ |
| 8 | IPSecAgent | — | xfrm | ✅ |
| 8 | EgressManager | Endpoint(1)（Identity/labels/epDataStore） | EgressMap（policyMap4/6） | ✅ |
| 8 | IPMasqAgent | — | IPMasqMap | ✅ |
| 9 | endpointRestorer | Endpoint(1)、K8sAnnotation | Endpoint(1)（重建） | ✅ |
| 9 | LocalIdentityRestorer | — | IPCache(2)（重建） | ✅ |
| 9 | Regenerator | — | BPF（再生） | ✅ |
| 9 | dynamiclifecycle | — | CellLifecycle（启停） | ✅ |
| 9 | Manager | — | 控制循环 | ✅ |
| 10 | Hive/Cell/Module/Agent | TestAgentCell* | cell（provide） | ✅（装配） |
| 10 | TestAgentCell / TestAgentCellNativeVPC | Hive（校验） | — | ✅（门禁） |

### operator / clustermesh / hubble-relay 侧对象（粗粒度读写边）

| 归属层 | 对象 | 读者 | 写者 | 完备性 |
| --- | --- | --- | --- | --- |
| 1 | identitygc.GC | CiliumIdentity/CEP/CES、kvstore 心跳 | CiliumIdentity（删除）/ kvstore | ✅（identity 键安全） |
| 1 | ciliumidentity | pod/ns labels | CiliumIdentity（派生） | ❌ 启动即拒（不知 VNI） |
| 1 | ciliumendpointslice | CEP | CES | ❌ 启动即拒（无法携带 VNI） |
| 1 | endpointgc.GC | CEP | CEP（删除） | ✅（CEP 带 VNI annotation） |
| 1 | lbipam / nodeipam | Service/Node | LB/Node IP 分配 | ✅（集群级键） |
| 1 | KVStoreMesh | 本地 kvstore、远程 client | 本地 kvstore 镜像 | ✅（集群级键透传） |
| 4 | relay/server.Server | 各节点 Hubble flow | gRPC 导出 | ✅（vni_id 透传） |

> 结论：85 个对象无孤儿、无悬空状态，读虚写实边全部对齐。
> 新增对象时，必须先回答：它属于哪一层、读谁、写谁——三问缺一不可入图。
