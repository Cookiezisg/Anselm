---
id: DOC-051
type: reference
status: active
owner: @weilin
created: 2026-07-08
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Chat 右岛：侧幕与触点台账——当前形态

> 侧幕是 Chat 中正在发生的工具、子智能体、workflow 与人在环活动的解释面；它不是第二份 transcript，也不持有 durable 真相。

## 1. 结构

```text
AnPanelHead
├── 身份：Activity + 关闭
├── 速览：有真实计数才显示
└── 内容
    ├── todo / 当前活动 / 委派
    └── 已落定触点：刚刚 / 早些时候 / 更早
```

只剩一个时间段时不显示组头；空段不渲染。todo、live 与委派层始终位于时间分组之前，不能被历史折叠隐藏。

## 2. 活动生命周期

- 工具帧先进入 transcript reducer，再投影为 `StageScene`；舞台组件只读取自己的 scene，不 watch 全局导演器状态。
- `StageDirector` 负责自动登台、换台、失败驻留和落定停拍，不拥有执行真相。
- 活性只由 `ToolCardPhase`、workflow durable run 状态和 interaction 状态派生；tool call 参数关帧不等于工具执行结束。
- 正常落定后停留短暂可读时间，再只收起由导演器自动打开的行；用户手动展开或正在阅读的行不被抢走。
- 失败驻留到用户清除或后续真实状态改变；不能把失败行永久标作 live。
- subagent epoch、冷启动与 410 后按数据库 transcript 重新接地，消除幽灵活动。

## 3. 身份与媒体

- 触点身份优先使用服务端稳定 item id；创建回执把临时 block key 迁移到 durable id。
- workflow 活动在 tool call 关闭后可继续由 flowrun id 驱动，直到 durable 终态。
- 媒体引用按 `MediaRef` 与附件行 `mime` 进入共享 `core/media` 卡族；侧幕不自行按 URL 或 receipt 猜类型。
- 工具舞台字段必须与后端 schema 同名；fixture 帧保持真实线缆形状。

## 4. 人在环

- danger、ask 与 approval 都使用同一 interaction broker。
- pending gate 自动展开并保持可操作；resolved 以服务端 first-wins 结果收口。
- 用户在行内交互只认领该行，不冻结后续舞台流水。
- interaction 是 ephemeral；重连后必须通过专用 REST 补拉 pending gate。

## 5. 关键不变量

1. 舞台不是执行状态源，DB/REST 行才是 durable 真相。
2. 一个 durable item 在台账中最多一行；key 迁移不能产生临时/正式双影。
3. 自动导演只能收自己自动打开的行。
4. live 与自动深跳所在时间组强制展开；用户普通展开不永久锁组。
5. tool_call close 只代表参数完整，tool_result/run terminal 才代表执行收口。
6. 任何多模态产物都复用共享媒体解析与查看器。

## 6. 验证入口

- 侧幕：`frontend/test/features/chat/ui/`
- 导演器与投影：`frontend/test/features/chat/model/`
- 工具卡与媒体：`frontend/test/features/chat/`、`frontend/test/core/media_*_test.dart`
- 线缆结构不变量：`sidestage_invariants_test.dart`
- 人眼验收：`make -C frontend demo`
