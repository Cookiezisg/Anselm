---
id: DOC-105
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-10
review-due: 2026-09-01
audience: [human, ai]
---
# Contextmgr — 对话上下文压缩 (Context Compaction)

> **核心地位**：对话逼近模型 context window 时**自动压缩**旧历史，使长对话持续装得下、并降低 context rot。生产侧引擎 `app/contextmgr`（M5.3）；消费侧（loop 投影 + chat LoadHistory）R0055 已接好。
>
> **本文 = R0059 as-built**。旧 DOC-105 的 **tiktoken 估算 / Calibrate 校准 / 4 个错误码 / CompactionEvent**已废（见 §6）——触发改用**真实落盘 InputTokens**，失败 best-effort 吞错、无错误码、无 REST（仅自动）。

---

## 1. 触发：真实 token，免估算器

回合收尾时（chat `processTask` 末，per-conversation queue 槽内同步、detached ctx、best-effort）：
- 读 `LoadThread` 末条 assistant 的 **`InputTokens`**（`FinalizeMessage` 已落盘）= provider 为该请求计费的完整上下文 = **精确当前大小**（无 tiktoken / 无 per-conv 校准）。
- 预算 `inputBudget = ContextWindow − MaxOutput`（取自 `llminfra.ModelInfo`，经 `WindowResolver.ContextBudget(provider, modelID)`；provider/modelID 取自该末条 message）。
- 触发：`InputTokens ≥ 0.80 × inputBudget`（0.80 在业界 75–90% 区间；20% 余量即压缩 headroom）。`window=0`（未知）→ 跳过（不知预算不压）。

---

## 2. 两步管线（gentle → aggressive）

业界铁律：**先砍旧 tool_result**（占 token 大头、很少再需原文），LLM 摘要兜底。

**① demote 旧 tool_result（免 LLM，常就够）**：newest→oldest 遍历，仅 tool_result 块；保护最近 `recentTurns(4)` 条 message + pinned + 已 archived。非保护 tool_result 按新旧：前 `recentTRHot(4)` 留 hot、接着 `warmZone(8)` 个 → **warm**（截断预览）、其余 → **cold**（占位符）。`UpdateBlocksContextRole` 批量写。tool_result 只随对话变长 hot→warm→cold 老化，**绝不升级**。

**gate**：用 `bytes/4` 估算 demote 后投影大小（hot 全文 / warm 200B / cold ~50B / archived 0 + summary）。`< 0.80 × inputBudget` → 收工、不调 LLM。

**② 增量摘要（仍超才做）**：取「水位 `SummaryCoversUpToSeq` 之后、非保护、非 pinned」最旧 span = candidates（**整 message 粒度**，保 `tool_call↔tool_result` 对原子）。单次 **Utility 模型**调用：`旧 summary + (水位, toSeq] 的 candidate 摘录（逐块截断 1500B）` → 新 summary（增量扩展、非重写）。

---

## 3. 持久化：水位线是真相源（崩溃安全）

写顺序（crash-safe）：
1. **`conversation.SetSummary(newSummary, newWatermark)`** — `Summary` + `SummaryCoversUpToSeq` 水位。**水位 = 「已并入 summary」的真相源**。emit `conversation.compacted {coversUpToSeq, summaryBytes}`。
2. `UpdateBlocksContextRole(candidates, archived)` — **best-effort** UI/backstop 标记。
3. `CreateMessage`(compaction 锚块) — best-effort UI 时间轴标记（type=compaction，短 marker；正文摘要在 conversation.summary）。

**为何水位是真相**：chat `LoadHistory` 丢弃 `seq ≤ SummaryCoversUpToSeq` 的块（`chatHost.unfolded`）。故步 1 写完即生效——步 2/3 崩溃也不会「摘要已更新但块仍计入」的重复计数。archived 标记降为 UI + 消费侧 backstop。**幂等**：重摘只覆盖 `(水位, toSeq]`，重跑同 `toSeq` 是 no-op。

**非破坏性**：`message_blocks` 行永不删（D1）；UI 上滚仍见原文，仅 LLM 生成时按水位 + ContextRole 过滤。

---

## 4. ContextRole 四档投影（消费侧，R0055 已接）

`Block.ContextRole` 投影块如何进 LLM 历史而**不改写**落库 Content（loop `BlocksToAssistantLLM` + chat LoadHistory）：

| 档 | LLM 见到 | 谁设置 |
|---|---|---|
| `hot` | 全文 | 默认（落盘）/ 最近回合 |
| `warm` | 前 200B 预览 + `…[truncated, N total]` | demote（中段 tool_result） |
| `cold` | `[<tool> output omitted (N bytes)]` 占位符 | demote（最旧 tool_result） |
| `archived` | 完全不在 prompt（内容并入 summary） | summarize（best-effort 标记；真相在水位） |

`type=compaction` 块 loop 永远丢弃；丢弃后变空的 assistant 回合 chat `LoadHistory` 整条跳过（`isEmptyAssistant`）。`conversation.summary` 非空时作 `<conversation_summary>` 前置（user 角色）。

---

## 5. 跨域集成

- **chat**：触发宿主（`processTask` 末同步、detached、best-effort，`Compactor` 端口 nil 降级）；消费（LoadHistory 前置 summary + 按水位丢弃）。
- **conversation**：`SetSummary` 写 summary + 水位（PATCH 不暴露）；存 `Summary`/`SummaryCoversUpToSeq` 列。
- **messages**：`UpdateBlocksContextRole` 批量改投影角色；`LoadThread` 供决策。
- **model**：Utility scenario 模型（摘要）+ ModelInfo 的 ContextWindow/MaxOutput（预算）。
- **loop**：按 ContextRole 投影 + 丢弃 archived/compaction。

---

## 6. 契约边界 / 废弃

- **无 error-code**：压缩失败（LLM 错 / 解析错 / 持久化错）一律 **best-effort 吞错、log warn、return**——非致命，下回合再查。**不冒泡 HTTP**。
- **无 REST**：仅自动（回合边界触发）；手动 `/compact` 端点延后（V2）。
- **DB**：无新表 / 无新列（`conversation.summary`/`summary_covers_up_to_seq` R0050 已在；`message_blocks.context_role` + `compaction` 块型 R0054 已在）。仅 `messages.Repository` += `UpdateBlocksContextRole`。
- **废（旧 DOC-105 幻想）**：~~tiktoken 估算 + Calibrate 校准~~（改用真实落盘 InputTokens）、~~`ErrCompactionFailed`/`ErrCalibrationMismatch`/`ErrSeqOverlap`/`ErrNoActiveModel` 4 错误码~~（best-effort 吞错、无码）、~~CompactionEvent (coversFromSeq/blocksArchived) eventlog 载体~~（改 `conversation.compacted` 通知 `{coversUpToSeq, summaryBytes}`）。

---

## 7. 装配（M7）+ 常数

`contextmgr.New(Deps{Messages, Conversations, Resolver, Windows})` → 注入 chat 的 `Compactor`（nil 降级）。常数：`triggerRatio=0.80` / `recentTurns=4` / `recentTRHot=4` / `warmZone=8` / `bytesPerToken=4` / `maxBlockExcerptBytes=1500`。摘要 prompt 保留：用户请求·文件/实体引用·决策·错误与修复·未决项/下一步·用户偏好（must-follow 规则在 system_prompt、不进摘要）。
