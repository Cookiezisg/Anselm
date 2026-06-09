# Round 0057 — chat 收尾（波次 5 · M5.2 chat 子轮 4/4·收官）

类型 / 目标：补齐 R0050/R0055/R0056 累积的 chat 端 deferred——**auto-title**（首回合自动起标题）+ **system-prompt-preview 端点** + **usage（tokensUsed）端点**。**chat 模块完整收官**。

范围裁定（诚实）：
- **做**：auto-title（真 UX，R0055 owed）、`GET /system-prompt-preview`（R0050 owed）、`GET /usage`（R0050 「tokensUsed 富化」owed，**改实现为 chat 侧专用端点**避免 conversation→messages 耦合）。
- **砍**：`export` / `llm-trace`（旧 api.md 占位、从无明确需求；llm-trace ≈ ListMessages 的 provenance 投影前端可做、export 是格式化前端可做）——从 api.md 删占位（投机端点，反 YAGNI）。
- **延后（非 chat 域）**：model 目录 `vision`/`nativeDocs` flag（属 model/infra/llm 各 provider DescribeModels，与 chat 解耦；attachment caps 真值待 model 域补，现 M7 adapter 给保守默认）。

依赖扫描：
- conversation app（`repo` + `emit`）：加 `SetAutoTitle`（load → Title + AutoTitled → Update → emit `conversation.auto_titled`）；AutoTitled 不进 PATCH UpdateInput（R0050 定，chat 专写）。
- messages（R0054）：`Repository` += `SumTokens(convID) (in, out, err)`；store 聚合。
- llm：`Generate(ctx, client, req) (string, error)`（一次性非流式，web 摘要先例）；utility 链 `Resolve(ScenarioUtility, nil, picker)`（M7 adapter 实现 `ResolveUtility`）。

设计要点：
1. **ModelResolver 端口 += `ResolveUtility(ctx) (Bundle, error)`**（utility 场景，auto-title 用小模型；M7 adapter 做 `Resolve(ScenarioUtility,…)`）。
2. **Deps += `Titler ConversationTitler`**（`SetAutoTitle(ctx, convID, title)`，conversationapp.Service 满足）+ **`Notifier notification.Emitter`**（可选，nil 降级）。
3. **auto-title（detached + 首回合）**：`processTask` 跑完 loop 后，若 `conv.Title=="" && !conv.AutoTitled`（首回合）→ `s.wg.Add(1)` 起 goroutine：detached `context.Background()` + 10s timeout → `LoadThread` 取首 user + 首 assistant 文本 → `ResolveUtility` → `Generate`（System=「5-10 词标题、只输出标题」）→ 清洗（trim/去引号/截断）→ `Titler.SetAutoTitle` → `Notifier.Emit`。失败静默（best-effort，标题非关键路径）。
4. **`Service.SystemPromptPreview(ctx, convID) (string, error)`**：get conv → `buildSystemPrompt(ctx, conv)`（复用 R0055，不需 model）。
5. **`Service.Usage(ctx, convID) (in, out int, err)`**：`messages.SumTokens` 透传。
6. **handler 2 端点**：`GET /conversations/{id}/system-prompt-preview` → `{systemPrompt}`；`GET /conversations/{id}/usage` → `{inputTokens, outputTokens, totalTokens}`。

修改后完整逻辑：
- **domain/messages**：`Repository` += `SumTokens`。
- **infra/store/messages**：`SumTokens`（SELECT COALESCE(SUM(input_tokens)),SUM(output_tokens) FROM messages WHERE conversation_id=?，orm 自动 ws 过滤）。
- **app/conversation/conversation.go**：+ `SetAutoTitle`。
- **app/chat/chat.go**：`ModelResolver` += `ResolveUtility`；`Deps` += `Titler`/`Notifier`；`SystemPromptPreview` + `Usage`。
- **app/chat/autotitle.go**（新）：`maybeAutoTitle` + `autoTitle` goroutine。
- **app/chat/runner.go**：processTask 末尾触发 `maybeAutoTitle`。
- **handlers/chat.go**：+ 2 端点。

契约变更（→ contract-changes #39）：api.md `system-prompt-preview`/`usage` as-built + **删 export/llm-trace 占位**；chat.md 去 🔜R0057 标记（auto-title/preview/usage as-built）；database 无变（SumTokens 是查询）；**无新 error-code**。R0050 「tokensUsed 富化在 GET /{id}」→ 实现为 `GET /{id}/usage` 专用端点（解耦 conversation←messages），记为契约微调。

新测试（全离线）：
- auto-title：fake utility resolver + fake Titler，首回合后 SetAutoTitle 被调、标题非空、清洗对；非首回合（已 AutoTitled）不触发。
- SumTokens：2 回合 token 求和。
- SystemPromptPreview：含各 Section。
- handler usage / preview（可选 httptest）。

验证：gofmt / build ./... / vet / test 全绿。

是否更干净（自证）：① auto-title best-effort detached（标题非关键路径、失败不影响对话）；② usage 专用端点解耦 conversation←messages（不给 conversation 加 messages 依赖）；③ 砍 export/llm-trace 投机占位（YAGNI）；④ SystemPromptPreview 复用 buildSystemPrompt（零重复）；⑤ utility 经 ResolveUtility 端口（与 ResolveChat 对称、M7 注入）。

遗留 / 下一步：**chat 模块完整收官 🎉**（R0054 落盘 + R0055 引擎 + R0056 可用面/mention + R0057 收尾）。波次 5 剩 **subagent**（贴 R0055 chatHost，递归子对话，写父对话 messages + parentBlock 锚点、承袭父 model）、**contextmgr**（M5.3 压缩写 context_role + conversation.summary）。model 目录 vision/nativeDocs flag 待 model 域补（attachment caps 真值）。
