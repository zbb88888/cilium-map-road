# 待完善点清单（按优先级）

> 用途：让「还差什么」显式化。每完成一项就勾掉并提交。

## P0：operator 组件无路覆盖 ✅

- [x] 铺 `road/operator-identity-gc.md`（identity 键、VNI 安全，operator 组件首条路）

## P1：clustermesh-apiserver / hubble-relay 组件对象未入账

- 现状：`map/00-overview.md` 的层×组件矩阵列了这两个组件，但 77 对象账本里没有它们的对象。
- 动作：补 `KVStoreMesh`/`clustersHandler`（clustermesh-apiserver）、relay server（hubble-relay）入账，至少标注归属层与粗粒度读写边。

## P2：层间图 ↔ 层内图互链（方法论 §8 唯一未勾项）

- 现状：每面有「层间概览」和「对象模型」两张图，但没互相引用。
- 动作：每面加一句「本面对象模型 ↔ 层间概览」交叉引用；`map/README` 十面索引加 road 反链。

## P2：面 4 切面路覆盖薄

- 现状：只有 ip/vni 两条路路过切面，没有「monitor 事件 → parser → flow → metrics」的专用切面路。
- 动作：铺 `road/observability-pipeline.md`。

## P3：operator 对象 reader/writer 粗粒度

- 现状：账本里 operator 19 对象只有粗粒度读写边（读 CRD/kvstore，写 CRD/心跳）。
- 动作：至少对 `identitygc.GC`/`endpointgc.GC`/`lbipam` 三个对象细化读者/写者。

## P3：road 覆盖矩阵缺「组件」维度

- 现状：矩阵是路×层，看不出 operator/clustermesh 是否被路覆盖。
- 动作：矩阵加一行「组件覆盖」（agent/operator/clustermesh/hubble-relay）。

## P3：术语/编号一致性收尾

- 现状：broken link 已查无；但三处数字（十面索引 / 77 对象 / 覆盖矩阵）需再核对一次。
- 动作：收尾核对 + 提交。
