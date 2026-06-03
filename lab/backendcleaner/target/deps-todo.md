# 跨模块待办（从已重写模块移出、待目标模块建立的关注点）

> 重写某模块时，把不属于它的关注点移走后记在这里；到目标模块那一轮去建立或判定，确保不丢。

## 来自波次 0 · M0.1 第一轮（reqctx / idgen / pagination）

| 移出内容 | 原位置（问题） | 去向 | 备注 |
|---|---|---|---|
| model override ctx | `reqctx/modeloverride.go`（🔴 曾让 reqctx → `domain/model` 反向依赖） | model（M1.3） | `WithModelOverride`/`GetModelOverride`；在 model 模块重建其 ctx 透传 |
| agent state ctx | `reqctx/agentstate.go` | agent/loop（M2.2/M3.4） | `WithAgentState`/`GetAgentState` + `pkg/agentstate` 去留判定 |
| 对话/执行标识 ctx | `reqctx/agentrun.go` | chat/loop/eventlog（M2.2/M5.2） | conversationID·messageID·toolCallID·parentBlockID·subagentDepth；判定是否仍走 ctx 透传、放哪一层 |
| ID 前缀 → 实体类型 | `idgen/prefix.go` | relation/wikilink（M1.4） | `KindByPrefix`/`KindForID`（wikilink 解析才关心实体类型） |
| HTTP 分页解析 | `pagination`（曾 import `net/http` + `domain/errors`） | transport 框架（M0.7） | `Parse(*http.Request)` + `DefaultLimit`/`MaxLimit`；把 `pagination.ErrMalformedCursor` 映射到 `domain/errors.ErrInvalidRequest` |
