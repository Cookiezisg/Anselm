# 评审顺序 —— 设计评审序

> **设计评审序，非依赖写序。** 先立横切尺子 → 啃标准化最吃紧/冗余最可能藏处（执行体）→ 图/引擎/挂载/对话 → 服务/地基 → 装配收尾。
> 每模块走 PLAYBOOK 循环：研究 → 列 findings + 确认/记 standards → **用户裁决** → 修 + 文档 → 下一模块。

## Full coverage 铁律
`internal/` 共 **130 个 Go 包**，covering 前必须**全有归属**：评审项 / 折叠进某项 / 显式豁免。逐包对账见 `inventory.md §对账`。

**折叠规则**：一个实体评审项吃掉它整组包——`domain/X` + `app/X` + `infra/store/X` + `app/tool/X`（forge 工具）。紧耦合 infra 并入对应实体：`infra/handler`→handler · `infra/mcp`→mcp · `infra/sandbox`→sandbox · `infra/trigger/*`(4 listeners)→trigger · `infra/fs/{blob→attachment, skill→skill, memory→memory}`。内置工具组 `app/tool/{filesystem,search,shell,web,ask,toolset}` → P7 `tool`。

---

## P0 已评审 ✅
**errors** → STD-1（错误处理）；F-1（todo 违 S20）/ F-2（websearch 待查）

## P1 标准层（先立实体都要对照的横切尺子）
**orm** · **reqctx**(+agentstate)

## P2 执行体 🎯（标准化主战场——3 个相似实体形状是否一套标准）
**function** · **handler** · **agent**
> 拷问：versioning / CRUD / forge / run 面 / env / relation 边——一套标准，还是各搞各的？

## P3 图节点 + 编排 + 引擎
**trigger** · **control** · **approval** · **workflow**（编排者，放其节点之后）· **flowrun** · **scheduler**

## P4 挂载 / 协议
**skill**（注意与执行体的 parity）· **mcp** · **document**

## P5 对话运行时
**conversation** · **chat** · **messages** · **attachment** · **memory** · **todo**（修 F-1）· **subagent**

## P6 横切服务 + AI 会话 + 其余 app
**catalog** · **relation** · **mention** · **model** · **apikey** · **websearch**（定 F-2）· **notification** · **workspace** · **sandbox** · **aispawn** · **humanloop** · **contextmgr** · **envfix** · **entitystream**

## P7 地基剩余 + transport
**cel** · **crypto** · **stream** · **loop** · **tool** · **llm** · **db** · **pkg-utils**（9 微包）· **transport**

## P8 装配与生命周期（收尾，最懂全局时评）
**bootstrap**（DI 装配根 + App Boot/Serve/优雅关停）

## 显式豁免（不评审、不成篇）
`infra/logger`（zap 薄封装，无设计面）

---

## 备注
- 索引文件（api/database/events/error-codes）**增量长大**：每评一个模块就把它的端点/表/码/事件追加进对应索引——到 P8 自然成全集。
- **契约 N 系列**（命名 / `:run`·`:call`·`:invoke`·`:trigger` / 强制分页 / Envelope / S15 ID 前缀）= 活尺子、非独立阶段：实体评审中边查边记 STD，末尾交叉核对。
- changelog.md：随实际 dev 追加，不回填历史。
