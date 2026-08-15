# 路：observability pipeline（monitor 事件 → flow → metrics）

> 起点：转发面 monitor 事件（trace/drop/debug）+ L7 代理 accesslog。
> 终点：Hubble flow（含 `vni_id`）导出 + Prometheus 指标（含 vni 标签）。
> 定位：面 4（切面）的专用路，补齐切面只被 ip/vni 两条路「路过」而没有本面主路的缺口。

## 1. 完整路线

```mermaid
flowchart TD
    BPF[转发面 BPF 事件] -.->|读| MA[4 切面 MonitorAgent]
    MA -.->|读 trace/drop| P3[ThreeFourParser]
    L7[L7 accesslog] -.->|读 LogRecord| P7[SevenParser]
    P3 ..> ER[EndpointResolver]
    P7 ..> ER
    ER -.->|读 VNI-scoped 身份| IPC[2 缓存面 IPCache]
    P3 -->|写 flow| FLOW[Flow]
    P7 -->|写 flow| FLOW
    FLOW -.->|读 生成指标| CO[ContextOptions]
    CO -->|写 vni 标签| PROM[Prometheus]
    FLOW -.->|读 汇聚| RELAY[relay/server.Server]
    RELAY -->|写 gRPC 导出| OUT[Hubble 客户端]
```

## 2. 逐层对象与文件（地图坐标）

| 层 | 对象 | 动作 | 文件 |
| --- | --- | --- | --- |
| 3 转发面 | BPF 事件 | 产生 trace/drop/debug | `bpf/lib/{trace,drop,dbg}.h` |
| 4 切面 | `MonitorAgent` | 事件总线（订阅/分发） | `pkg/monitor/agent/agent.go` |
| 4 切面 | `ThreeFourParser` | trace notify → L3/L4 flow | `pkg/hubble/parser/threefour/parser.go` |
| 4 切面 | `SevenParser` | accesslog → L7 flow | `pkg/hubble/parser/seven/parser.go` |
| 4 切面 | `EndpointResolver` | 端点/identity 富化（VNI-scoped 查） | `pkg/hubble/parser/common/endpoint.go` |
| 2 缓存面 | `IPCache` | 供 VNI-scoped 身份/元数据 | `pkg/ipcache/ipcache.go` |
| 4 切面 | `Flow` | 输出契约（`Endpoint.vni_id`） | `api/v1/flow/flow.proto` |
| 4 切面 | `ContextOptions` | flow → vni 标签 | `pkg/hubble/metrics/api/context.go` |
| 4 切面 | `relay/server.Server` | 跨节点汇聚 | `pkg/hubble/relay/server/server.go` |

## 3. VNI 视角：vni_id 一路透传

- 端点富化时 `EndpointResolver` 从 identity 的 VNI label 派生 VNI → `GetK8sMetadataForVNI` 精确查。
- `Flow.Endpoint.vni_id` 携带 VNI，`relay/server.Server` 只透传不改写，跨节点也不丢。
- `ContextOptions` 把 `vni_id` 变成 `vni`/`source_vni`/`destination_vni` 标签，非 VPC 回落 ip。

## 4. 三个 fail-closed 点

| 场景 | 行为 |
| --- | --- |
| 裸 IP 富化遇到 VNI 重叠 | `EndpointResolver` 走 VNI-scoped 查，裸 IP 查 miss |
| L7 accesslog 无 VNIID | `LogRecord.EndpointInfo.VNIID=0`，富化退化为裸 IP（fail-closed 到 world） |
| metrics 未开 vni 上下文 | 两 VPC 序列会塌缩，需显式开 `source_vni/destination_vni` |

## 5. 基线 vs 增量

- **基线**：monitor → parser → flow（只有 IP/identity，无 vni）。
- **native-vpc 增量**：`Flow.Endpoint.vni_id` 字段 + `EndpointResolver` VNI-scoped 查 + `ContextOptions` vni 标签。

## 6. 地图坐标小结

这是面 4 的主路：把「转发面事件」一路加工成「可区分 VPC 的 flow/指标」。它与 `vni-ip-to-identity` 的切面段互为镜像（一条看身份解析，一条看事件管线）。
