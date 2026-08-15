# 路：VNI + IP → identity

> 起点：CRD `Pod/CEP` 的 `ovn.kubernetes.io/tunnel_key`（VNI）annotation + IP。
> 终点：转发面 `cilium_ipcache_vni` 按 `(VNI, IP)` 解析 identity；切面 `Flow.vni_id` 富化。
> 一句话：**在原有「IP→identity」基线的每个节点上，把 key 从裸 IP 扩成 `(VNI, IP)`，并在无法确定 VNI 处 fail-closed。**

## 1. 基线：IP → identity（原实现）

```mermaid
flowchart TD
    POD[Pod / CEP 的 IP] -.->|读| CP[1 控制面<br/>K8sWatcher / Endpoint]
    CP -->|写 裸 IP key| CACHE[2 缓存面<br/>IPCache]
    CACHE -->|写 通知变更| DP[3 转发面<br/>BPFListener]
    DP -->|写 Key{IP,ClusterID}| V2[cilium_ipcache_v2<br/>裸 IP LPM trie]
    V2 -.->|读 identity 解析| LXC[bpf_lxc]
    OBS[4 切面] -.->|读 裸 IP 身份| CACHE
```

基线特征：key = 裸 IP（`ipcache.Key`）；查身份走 `LookupSecIDByIP`；BPF 侧只有一个 `cilium_ipcache_v2`。

## 2. VNI 增量：在基线每个节点上叠加

| 层 | 基线对象/文件 | VNI 增量（叠加点） |
| --- | --- | --- |
| 控制面 | `pkg/endpoint/endpoint.go` 只有 IP | 加 `Endpoint.VNIID` + `SyncVNIFromPodAnnotation`；`pkg/nativevpc.VNIFromPod` 统一决策 |
| 控制面 | `pkg/endpoint/id` 只有 `ipv4:/ipv6:` | 加 `vni-ipv4:<vni>:<ip>` / `vni-ipv6` 标识 |
| 控制面 | identity 由 k8s labels 派生 | 注入 `vni:io-cilium-native-vpc-vni=<vni>` identity label（`pkg/labels` + `pkg/identity/key`） |
| 控制面 | watcher 写裸 IP | `podVNI()/ciliumEndpointVNI()` 提取 VNI → `ipcache.KeyWithVNI(ip, vni)`；CEP transform 保留 VNI annotation |
| 缓存面 | `IPCache` 裸 IP key | `KeyWithVNI` → `ip@vni:<vni>`；`Identity.Vni` 字段；`ipToVNIKeys` 反查；`LookupSecIDByIPForVNI`(key-exact) + `LookupSecIDByIPUnambiguous`(fail-closed) |
| 缓存面 | `EndpointManager` 裸 IP 索引 | `LookupIPWithVNI` / `LookupIPUnambiguous` / `LookupIPAnyVNI` |
| 缓存面 | kvstore 裸 IP | `IPIdentityPair.Vni` + scoped key |
| 转发面 | `BPFListener` 只写 v2 map | 按 `Vni≠0` 路由到 `cilium_ipcache_vni`；`VniKey` 与 `struct ipcache_vni_key` 布局对齐 |
| 转发面 | `bpf_lxc` 只查 v2 | `CONFIG(native_vpc_vni)`；`ipcache_lookup4_vni/6_vni` 查 `cilium_ipcache_vni` |
| 切面 | flow 只有 IP/identity | `Flow.Endpoint.vni_id` + `IPCacheNotification.vni`；`EndpointResolver` 从 identity VNI label 派生 VNI → `GetK8sMetadataForVNI` |

## 3. 完整路线：VNI + IP → identity

```mermaid
flowchart TD
    POD[Pod/CEP<br/>tunnel_key annotation + IP] -.->|读 VNI+IP| CP[1 控制面<br/>Endpoint.VNIID / K8sWatcher]
    CP -->|写 ip@vni:N| CACHE[2 缓存面<br/>IPCache KeyWithVNI]
    CACHE -->|写 通知（带 Vni）| DP[3 转发面<br/>BPFListener]
    DP -->|写 VniKey{VNI,IP}| VNIMAP[cilium_ipcache_vni<br/>VNI+IP LPM trie]
    VNIMAP -.->|读 ipcache_lookup4_vni| LXC[bpf_lxc<br/>CONFIG native_vpc_vni]
    LXC -->|写 identity 决策| POL[策略面 policymap]
    OBS[4 切面<br/>EndpointResolver] -.->|读 GetK8sMetadataForVNI| CACHE
    OBS -->|写 flow.vni_id| OUT[Hubble / metrics]
```

## 4. 关键 fail-closed 点

| 场景 | 对象 | 行为 |
| --- | --- | --- |
| 同 IP 多 VNI，裸 IP 读 | `IPCache.LookupSecIDByIPUnambiguous` | miss，不猜 VNI |
| 同 IP 多 VNI，endpoint 读 | `EndpointManager.LookupIPUnambiguous` | miss |
| DNS 回包归属 | `DNSProxy.LookupEndpointByIP` | 多 VNI 时 miss |
| 跨程序分片 | `bpf_lxc` vs 其它程序 | VNI 作用域不同 → `DROP_FRAG_NOT_FOUND` |
| 无 VNI 的 IP key 写 | `ipcache.Upsert` | native-vpc 下拒绝（文档化约束） |

## 5. 地图坐标（这条路经过的对象与文件）

| 层 | 对象 | 文件 |
| --- | --- | --- |
| 1 控制面 | `Endpoint`、`K8sWatcher`、`podVNI/ceiliumEndpointVNI` | `pkg/endpoint/endpoint.go`、`pkg/k8s/watchers/{pod,cilium_endpoint}.go`、`pkg/nativevpc` |
| 2 缓存面 | `IPCache`、`Identity`、`EndpointManager`、`IPIdentitySynchronizer` | `pkg/ipcache/{ipcache,kvstore}.go`、`pkg/endpointmanager/manager.go` |
| 3 转发面 | `BPFListener`、`VniKey`、`bpf_lxc` | `pkg/datapath/ipcache/listener.go`、`pkg/maps/ipcache/ipcache.go`、`bpf/lib/eps.h`、`bpf/bpf_lxc.c` |
| 4 切面 | `EndpointResolver`、`Flow`、`LogRecord` | `pkg/hubble/parser/common/endpoint.go`、`api/v1/flow/flow.proto`、`pkg/proxy/accesslog/record.go` |
| 5 策略面 | `GlobalIdentity`（VNI label） | `pkg/labels/labels.go`、`pkg/identity/key/global_identity.go`、`pkg/labelsfilter/filter.go` |
