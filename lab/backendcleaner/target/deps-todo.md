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

## 来自波次 0 · M0.1（userpath 判定删除 R0004）

`userpath` 整包删除（多用户文件分桶 + 历史迁移，新架构不存在）。其能力与连带清理：

| 移出内容 | 原位置（问题） | 去向 | 备注 |
|---|---|---|---|
| app 资源文件根布局 | `userpath.UserHome` → `~/.forgify/users/<uid>/` | workspace（M1.1） | 重定 `~/.forgify/` 下 mcp.json/skills/settings.json/catalog 布局；**删 users/local-user 层**；是否按 workspace 分桶由 workspace 物理模型定 |
| 历史迁移 | `userpath.MigrateLegacy`（迁 mcp.json/skills/.catalog.json/settings.json） | 删，无去向 | 项目未上线 + 无数据保留 → 无 legacy 可迁 |
| cmd/server 装配残留 | `main.go`：`legacyDefaultUserDir="local-user"`、`MigrateLegacy` 调用、"切换 user/V1.5 按 user 重建"注释 | cmd/server（M7.1） | 全删；`SetUserID(ctx,"local-user")`→ boot workspace；mcp/skill/settings 路径改走 M1.1 布局；清 `V1.2 §3` 注释 |
