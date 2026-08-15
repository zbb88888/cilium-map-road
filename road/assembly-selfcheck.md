# 路：装配自检（TestAgentCell → Populate → 门禁）

> 起点：`daemon/cmd/cells_test.go` 的 `TestAgentCell` / `TestAgentCellNativeVPC`。
> 终点：`hive.New(Agent).Populate()` 成功 = 十面对象图可实例化。
> 定位：这是第 10 面（装配面）自己的路——不承载业务数据，承载**对象图正确性**。

## 1. 完整路线

```mermaid
flowchart TD
    T1[TestAgentCell 默认模式] -.->|读 装配| HIVE[hive.New(Agent)]
    T2[TestAgentCellNativeVPC 模式] -.->|读 装配| HIVE
    HIVE -->|写 Populate 实例化| GRAPH[十面 cell 依赖图]
    GRAPH -.->|读 校验| CHK{缺失类型 / 可选接口降级 / 条件门控}
    CHK -->|失败| FAIL[启动失败 missing type / 静默退化]
    CHK -->|通过| OK[对象图可启动]
```

## 2. 逐层对象与文件（地图坐标）

| 层 | 对象 | 动作 | 文件 |
| --- | --- | --- | --- |
| 10 装配 | `Agent`（cell.Module） | 组装 `Infrastructure + ControlPlane + datapath.Cell` | `daemon/cmd/cells.go` |
| 10 装配 | `Hive` | `Populate()` 实例化整图 | `pkg/hive/hive.go` |
| 10 装配 | `TestAgentCell` | 默认模式 Populate | `daemon/cmd/cells_test.go` |
| 10 装配 | `TestAgentCellNativeVPC` | native-vpc 模式 Populate | `daemon/cmd/cells_test.go` |
| 10 装配 | `TestNativeVPCRejectsBareIPKeyedFeatures` | 裸 IP 键特性启动拒绝测试 | `daemon/cmd/native_vpc_validation_test.go` |

## 3. 三个失败模式 + 对应门禁

| 失败模式 | 症状 | 门禁 |
| --- | --- | --- |
| 缺失类型 | 某 cell 构造参数无 provider → 整个 agent 启动失败（`missing type`） | `TestAgentCell` + `TestAgentCellNativeVPC` 双模式 Populate |
| 可选接口静默退化 | 生产类型不再实现 VNI-aware 接口 → 消费者无声退化为裸 IP 路径 | 编译期断言（`pkg/hubble/parser/cell`、`pkg/endpointmanager`） |
| 条件分支门控被跳过 | 门控写在条件分支里，某些配置不执行 | 门控无条件求值（如 identity-management-mode 检查） |

## 4. native-vpc 的增量（为什么需要第二张测试）

native-vpc 会**新增 provider/consumer**（VNI-scoped ipcache map、identity synchronizer 的 local-ipcache 适配器），
且多个消费者通过**可选接口**达到 VNI-aware。默认模式的 `TestAgentCell` 测不到这些，
因此加 `TestAgentCellNativeVPC`：开 `EnableNativeVPC` 后整图仍可 Populate。

## 5. 基线 vs 增量

| 节点 | 基线 | native-vpc 增量 |
| --- | --- | --- |
| 装配自检 | `TestAgentCell` | 加 `TestAgentCellNativeVPC` |
| 裸 IP 特性门禁 | 无 | `TestNativeVPCRejectsBareIPKeyedFeatures` |
| VNI-aware 接口 | 无 | 编译期断言防静默退化 |

## 6. 地图坐标小结

这条路是「元路」：它检查的不是数据流，而是**十面对象图本身能否立起来**。
以后每加一个 cell/对象，先问三问（归属层/读谁/写谁），再跑这两张 Populate 测试——这就是装配面的找路闭环。
