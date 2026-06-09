# Round 0056 — chat 外围（波次 5 · M5.2 chat 子轮 3/3）

类型 / 目标：给 R0055 的 chat 引擎补**对外可用面 + @ mention**——HTTP handler（Send 202 / ListMessages / CancelStream 204）+ `Service.Cancel` + **mention 整套**（注册表 + `<mentions>` 渲染 + freeze-on-send + 补 backend-new 缺失的 `workflow`/`agent` 两个 resolver）。这使 chat **端到端可用**（HTTP 发消息 → SSE 流式 → 历史 → 取消）+ @ 引用实体快照注入。

**诚实留 R0057**（chat 收尾）：**auto-title**（需 utility-model resolver + conversation 写 Title/AutoTitled 的跨模块改动）+ **conversation tokensUsed 富化** + **system-prompt-preview / export / llm-trace**（低价值 polish）。本轮聚焦「可用 + mention」，把重的 auto-title 与 polish 分出。

依赖扫描（R0056 接口已核实）：
- handler 范式：`Registrar.HandleFunc("METHOD /path/{id}")` + `responsehttpapi.{Success(w,StatusAccepted,body) 202 / Paged / NoContent 204 / FromDomainError}` + `decodeJSON`（照 conversation handler）。
- mention 范式：`mentiondomain.{MentionType, MentionInput{Type,ID}, Reference{Type,ID,Name,Content}, Resolver{Type(),Resolve(ctx,id)}}`；`document.AsMentionResolver()` 是范本（Type + Resolve→Reference{name, description+正文}）。backend-new 已有 document/function/handler 三个 resolver，**缺 workflow/agent**（旧 backend 有）。
- chat（R0055）：`Send`（加 Mentions 入参）、`SendInput`（R0055 预留）、`messages.Repository.ListMessages`（R0054，REST 历史）、convQueue.cancel（R0055 已存）。

设计要点：
1. **mention 注册表 + freeze-on-send（chat）**：Service 加 `mentionResolvers map[MentionType]Resolver` + `RegisterMentionResolver(r)`（M7 各域注册自己的 resolver）。`Send` 解析 `SendInput.Mentions` → 每个调对应 resolver 抓 `Reference` 快照 → 存进 `userMsg.Attrs["mentions"]`（**freeze-on-send**：发送瞬间定格内容，后续不再 re-resolve；resolver 缺失/失败 → stub `{name:"(unavailable)"}` 不阻断发送）。
2. **mention 渲染（chat LoadHistory）**：`userMessage` 从 `Attrs["mentions"]` 渲 `<mentions><mention type id name>{content}</mention></mentions>` 拼进 user 文本（freeze 的快照，非实时）。
3. **补 workflow/agent resolver**：`app/workflow/mention_resolver.go` + `app/agent/mention_resolver.go`——`AsMentionResolver()` 照 document（workflow: name + description；agent: name + description + prompt 摘要）。
4. **Service.Cancel**：`Cancel(ctx, convID) error`——取 queue、`q.cancel()`（触发当前回合 ctx Done，loop 流式中断 → WriteFinalize Detached 落 cancelled 终态）、drain `q.ch` 清积压。无 queue → 优雅 no-op（无在跑回合）。
5. **HTTP handler**（`transport/httpapi/handlers/chat.go`）：`ChatHandler{svc,log}` + New + Register：
   - `POST /api/v1/conversations/{id}/messages` → `Send` → **202** `{messageId}`。
   - `GET /api/v1/conversations/{id}/messages` → `ListMessages`（**N4** `?cursor&limit`）→ Paged。
   - `DELETE /api/v1/conversations/{id}/stream` → `Cancel` → **204**。

强化地基：无。

修改后完整逻辑：
- **app/chat/chat.go**：`SendInput` += `Mentions []MentionInput`；Service += `mentionResolvers` + New 初始化；`Send` 调 `resolveMentions` 存 Attrs。
- **app/chat/mention.go**（新）：`RegisterMentionResolver` + `resolveMentions`（freeze）+ `renderMentions`（渲染）+ `attrMentions` 键。
- **app/chat/history.go**：`userMessage` 拼 `renderMentions(m)`。
- **app/chat/chat.go**：`Cancel` 方法。
- **app/workflow/mention_resolver.go** + **app/agent/mention_resolver.go**（新）。
- **transport/httpapi/handlers/chat.go**（新）：3 端点。

契约变更（→ contract-changes #38）：api.md 加 chat 3 端点（POST messages 202 / GET messages / DELETE stream 204）；chat.md §8 Send 补 mention freeze + §9 端点表；relation/mention 文档补 workflow/agent resolver 上线。**无新 error-code**（EMPTY_CONTENT/STREAM_IN_PROGRESS 已在 §2.4）。

新测试（全离线）：
- mention freeze（Send 带 mention → fake resolver → Attrs 存快照）+ render（LoadHistory 渲 `<mentions>`）+ resolver 缺失降级 stub。
- Cancel（在跑回合 → cancel → 落 cancelled 终态）+ 无 queue 优雅 no-op。
- handler（Send 202 / List Paged / Cancel 204）经 httptest。
- workflow/agent resolver Type + Resolve→Reference。

验证：gofmt / build ./... / vet / test 全绿。

是否更干净（自证）：① mention freeze-on-send 对齐 R0023 契约（发送定格、不实时 re-resolve）；② resolver 经注册表 DIP（各域注册、chat 不 import 各域）；③ Cancel 复用 R0055 已存的 queue.cancel（无新机制）；④ handler 照 conversation 范式（202/204/Paged 一致）；⑤ 范围克制——auto-title 的 utility+conversation-write 跨模块改动分到 R0057，本轮纯 chat-app + 2 resolver + handler。

遗留 / 下一步：**R0057 chat 收尾**——auto-title（首回合 detached utility Generate + conversation SetAutoTitle + notify）+ conversation tokensUsed 富化 + system-prompt-preview / export / llm-trace。之后 **subagent**（贴 R0055 chatHost，递归子对话）、**contextmgr**（M5.3 压缩写 context_role）。
