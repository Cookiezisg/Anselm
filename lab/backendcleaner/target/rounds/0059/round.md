# Round 0059 — contextmgr（波次 5 · M5.3 上下文压缩 · 波次 5 收官）

类型 / 目标：建 **contextmgr**——对话逼近模型 context window 时**自动压缩**，使长对话持续装得下。**生产侧**（消费侧 R0055 已 100% 接好：loop `BlocksToAssistantLLM` 丢弃 archived/compaction + 按 warm/cold 投影 tool_result；chat LoadHistory 前置 `<conversation_summary>`；`Block.ContextRole` 四档 + `conversation.Summary`/`SummaryCoversUpToSeq` 字段 + DDL 列全在）。波次 5 最后一块。

调研（三路并行 2026-06-09：当前接线 + 旧代码考古 + 行业 best practice）：
- **结论定调**：Forgify 草案（4 档 ContextRole + summary + 幂等水位线 + 非破坏性投影）**已对齐甚至领先业界**（Microsoft Agent Framework 压缩设计「像把 Forgify 独立重推一遍」；幂等水位线业界罕见，最接近 Roo Code `condenseParent`）。
- **两条铁律共识**：① 增量滚动摘要 + 保留最近 N 回合全文 = 标准核心；② **旧 tool_result 第一个砍**（Anthropic：「清旧 tool_result 是最安全最轻的压缩」）。
- **Claude Code 同款**：触发 ~高 80%、用**真实 provider usage**（非估算）、分层 gentle→aggressive（tool 截断 → 才 LLM 摘要兜底）。
- **别建**：forked-subagent 摘要器、微调摘要模型、对话 RAG、MemGPT 分页——单用户线性聊天全 overkill。
- 旧 backend 考古（850 行）骨架好（两级阈值 + 增量摘要 + 水位线 + 软标记）；**必废**：warm/cold 按 tool_result 新旧索引细分（已被用户 Q1 选「四档」保留为按新旧分档）、LLMResolver-nil、ForceCompact 独立端点（用户 Q2 选「仅自动」→ 不建端点）、虚拟 system message（改 compaction 块）、ContextRole 重复定义、per-conv 校准（改读真实 InputTokens）。

用户决策（2026-06-09）：
- **Q1 Tier 范围 = 四档 + warm**：生产侧也写 warm（旧大 tool_result 先 hot→warm 预览、更旧→cold 占位符）。
- **Q2 手动触发 = 仅自动**：不建 `/compact` REST 端点（回合收尾自动）。

设计要点：

1. **触发（精确，免估算器）**：读 LoadThread 末条 assistant 的真实 `InputTokens`（FinalizeMessage 已落盘）= 精确上下文大小。预算 `inputBudget = ContextWindow − MaxOutput`（来自 `llminfra.ModelInfo`，经 `WindowResolver.ContextBudget(provider, modelID)`，provider/modelID 取自末条 message）。触发条件 `lastInputTokens ≥ triggerRatio(0.80) × inputBudget`。window 未知（0）→ 跳过（不知预算不压，保守）。

2. **两步管线（gentle→aggressive）**：
   - **① demote 旧 tool_result（免 LLM，常就够）**：newest→oldest 遍历，**仅 tool_result 块**；保护：近 `recentTurns(4)` 个 message 的块、pinned（Attrs.pinned）、已 archived。tool_result 按新旧计数：最新 `recentTRHot(4)` 留 hot、接着 `warmZone(8)` 个 → **warm**、更旧 → **cold**。`UpdateBlocksContextRole` 批量写。**块粒度**（不动 tool_call，对仍配对：assistant{tool_call}+tool{投影 result}，`ToolCallID` 匹配）。
   - **gate**：用 `bytes/4` 估算 demote 后投影大小（hot 全文 / warm 200B / cold 标记 / archived 0 + summary）。`< 0.80×inputBudget` → 收工（不调 LLM）。
   - **② 增量摘要（仍超才做）**：取「水位 `SummaryCoversUpToSeq` 之后、非近期、非 pinned」的最旧连续 span = candidates；`ResolveUtility` 单次 LLM：`旧 summary + (水位, toSeq] 的 candidate 块内容（逐块截断 1500B）` → 新 summary。`SetSummary(id, newSummary, toSeq)`（toSeq = candidates 最大 seq）+ **archive 整 message 粒度**（candidate 所属 message 的**全部**块 → archived，保 tool 对原子：整回合一起消失，LoadHistory 跳过）+ 写 1 个 compaction 锚块（synthetic assistant message，content=摘要，type=compaction，UI 时间轴锚；loop 已会丢弃、不进 LLM）。

3. **触发点**：chat `processTask` 末（loop 完成、autoTitle 旁），**queue 内同步调**（detached ctx + best-effort 吞错非致命）——回合响应已流给用户，仅占该回合 queue 槽尾，**无竞态**（下条 send 在 queue 排队）。`Compactor==nil` 降级跳过。

4. **保留（永不压）**：`system_prompt`（must-follow 规则的家，**不进摘要**，每回合重发）、最近 `recentTurns` 回合全文 hot、summary、compaction 锚块、pinned。摘要保留：决策 / 未决项 / 用户偏好 / 文件·实体引用（防失忆重读）。

强化地基：
- `messages.Repository` += `UpdateBlocksContextRole(ctx, blockIDs []string, role string) error`（批量 update context_role；CHECK 已闭合四档）。
- `conversation.Service` += `SetSummary(ctx, id, summary string, coversUpToSeq int64)`（Get→改 Summary+SummaryCoversUpToSeq→Update→emit `compacted`；镜像 SetAutoTitle）。
- chat `LoadHistory` += `allBlocksDropped` 跳过（一个 message 的块全 archived/compaction → 跳过整条，不产空 assistant；修复潜在「空 assistant 进历史」）。

新包 `app/contextmgr`：
- `contextmgr.go`：Service + Deps + 端口（`ConversationSummary{GetSummary, SetSummary}` / `UtilityResolver{ResolveUtility→Bundle}` / `WindowResolver{ContextBudget(provider,modelID)→(window,maxOutput int)}` / `Notifier`）+ `MaybeCompact(ctx, conversationID) error` + Bundle 自包含。
- `pipeline.go`：demote + summarize 两步 + bytes/4 estimate + 候选选取 + 原子分组。
- `prompt.go`：摘要 system prompt（保留 bullet、按时序追加、分章节：用户请求/文件/工具/错误与修复/决策/下一步、上限 ~1500 tokens、输出完整更新后摘要）+ 块内容截断。

修改后完整逻辑：
- **domain/messages/messages.go**：Repository += UpdateBlocksContextRole。
- **infra/store/messages/messages.go**：UpdateBlocksContextRole 实现（WhereIn ids + update context_role + updated_at；workspace 自动过滤）。
- **app/conversation/conversation.go**：SetSummary。
- **app/chat/history.go**：allBlocksDropped 跳过。
- **app/chat/chat.go + runner.go**：Deps += Compactor 端口 + processTask 末调用。
- **app/contextmgr/**（新）：contextmgr.go / pipeline.go / prompt.go。

删除 / 合并：无（纯增）。

契约变更（→ contract-changes #41）：domains/compaction.md **重写为 as-built**（WHEN=真实 InputTokens vs 0.80×(window−maxOutput) / HOW=两步〔demote tool_result 四档 + 增量摘要 archive〕 / 持久化=summary+水位+软标记+compaction 锚块 / 触发=processTask 末同步 / 保留=system_prompt+近期+summary）；messages.md §6 Repository += UpdateBlocksContextRole + §4.1 LoadHistory allBlocksDropped；conversation.md SetSummary + summary/水位字段语义；database.md 无新列（summary/context_role 列 R0054 已在）；contract #41。**无新 REST**（仅自动，Q2）；**无新 error-code**（压缩失败 best-effort 吞错、非致命）。

新测试（全离线，fake LLM/真 messages store）：
- 触发：末条 InputTokens < 阈值 → 不压；≥ → 压。window=0 → 跳过。
- demote 四档：旧大 tool_result → 最新留 hot / 中段 warm / 最旧 cold；近 recentTurns 保护不动；pinned 不动；tool_call 不动（仅 tool_result）。
- gate：demote 后估算够 → 不调 LLM（summary 不变）。
- 增量摘要：仍超 → SetSummary（新 summary 含旧 + 新）+ 水位=toSeq + candidate 整 message archived + compaction 锚块落；摘要 prompt 喂「旧 summary + (水位,toSeq]」。
- 原子：archive 整 message（tool_call+tool_result 一起 archived，不拆对）。
- LoadHistory：全 archived 的 message + compaction message → 跳过（不产空 assistant）；summary 非空 → 前置。
- store UpdateBlocksContextRole 往返；conversation SetSummary 往返 + 不覆盖逻辑。

验证：gofmt / build ./... / vet / test 全绿（+1 包 app/contextmgr）。

是否更干净（自证）：① 触发用**真实 InputTokens**（FinalizeMessage 已落盘）免估算器/校准（旧 per-conv 校准砍）；② 两步管线先免 LLM 的 tool_result 投影（业界「先砍 tool_result」+ 常就够、省 LLM 调用/漂移）；③ 幂等水位线增量摘要（旧 summary + (水位,toSeq]，可重放防重复计费）；④ 原子性靠 message 粒度 archive + tool_result 粒度 demote（ParentBlockID 天然分组，绝不拆 tool 对）；⑤ 非破坏性（软标记 context_role，块行不删，D1 + UI 回滚）；⑥ compaction 锚块替旧「虚拟 system message skip-by-role」（更清晰）；⑦ 消费侧零改（R0055 已接），生产侧一包搞定。

遗留 / 下一步：**波次 5 收官**（conversation/attachment/chat/subagent/contextmgr 全 ✅）。warm 已按用户决策启用（生产侧写）。M7 装配：contextmgr Deps 注真（WindowResolver←provider ModelInfo / ConversationSummary←conversation.Service / UtilityResolver←model.ResolveUtility / Messages←store）+ chat 注入 Compactor。可选 V2：手动 `/compact` 端点、pinned UI、摘要 self-critique 二段、超大单体 tool 头尾截断（warm 的另一用法）。
