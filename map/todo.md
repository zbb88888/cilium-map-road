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

## P3：术语/编号一致性收尾 ✅

- [x] broken link 全量查无
- [x] 数字核对：十面索引 / 82 对象（30+5+6+8+7+5+6+4+5+6）/ 覆盖矩阵（层+组件）
- [x] operator/clustermesh/hubble-relay 对象读写边细化入账
