# Round 0065 — 波次6：iterate + triage（AI 工作会话，原 askai 重做）

类型 / 目标：两个把"东西交给 AI 处理"的动作，本质都是**开一个一打开就携带背景的对话**。

- **iterate（迭代 · 面对实体）**：在 function/handler/agent/workflow/document 上「让 AI 改」。开个对话、把该实体 @-mention 进首条消息（mention 机制冻结注入其当前定义）、AI 读懂后调对应 `edit_*` 出 pending 版本。
- **triage（诊断 · 面对执行结果）**：在**任意一条执行记录**上「AI 诊断」。开个对话、把那条执行的详情渲进 system prompt、AI 分析根因 + 提 fix。**不只工作流**——function/handler/agent/flowrun 的执行都能诊断。

## 为什么这是简化（原 askai 442 行 → ~一个小服务）

原 askai = 106 行 spawner + 214 行 forge_context（5 个几乎复制的"把实体 dump 成 prompt"）+ 122 行 triage_context（flowrun dump）。两个 context-builder 是重复造轮子：

- **iterate 复用现有 @-mention**：mention 域注入的就是"function code / handler methods / workflow graph / agent config / doc markdown，发送时冻结"——正是 forge_context dump 的东西。5 个 resolver bootstrap 已注册。→ 删 214 行，换成 mention + **一句通用 steer**。
- **triage 复用现有执行详情读取**：各执行类型的"取详情"前端本就要用、早有（GetExecution / GetCall / GetExecutionDetail / GetRunWithNodes）。→ 渲染 = 取详情 + JSON dump（通用），**不写 per-type prose 模板**；按 **id 前缀分发**取对的那条。

对偶：iterate 借 @-mention，triage 借执行详情读取，**两边都不新写"整理成话"模板**。

## 形状

`app/aispawn` 小服务（~80 行，原 askai 重做、去掉两个 context-builder）：
- 端口（DIP，可 fake 测）：`ConversationStarter`（`CreateWithSystemPrompt`，convapp 满足）· `TurnSender`（`Send`，chatapp 满足）· `ExecutionRenderer`（`Render(execID)→string`，bootstrap 前缀分发适配器）。
- `Iterate(ctx, mentionType, entityID, request) → convID`：`spawn(systemPrompt=iterateSteer, firstMessage=request, mentions=[{type,id}])`。
- `Triage(ctx, execID, note) → convID`：`render := renderer.Render(execID)`；`spawn(systemPrompt=triageSteer+render, firstMessage=note?)`。
- `spawn`：`CreateWithSystemPrompt` + `Send` + 返 convID（首条消息空则只建对话）。

**ExecutionRenderer 适配器（bootstrap）**：按 execID 前缀分发——`fne_`→function.GetExecution · `hcl_`→handler.GetCall · `agx_`→agent.GetExecutionDetail · `fr_`→scheduler.GetRunWithNodes（run+节点）——取出后 JSON dump。新增类型 = 加一个前缀分支（`mcl_` mcp / `tfi_` trigger 留扩展，各需先补一个单条读取）。

**HTTP**：
- iterate：各实体现有 `:action` 分发口加 `:iterate`（`POST /functions/{id}:iterate` 等，body `{request}`）→ 202 `{conversationId}`。
- triage：统一入口 `POST /executions/{execId}:triage`（虚拟统一集合，前缀分发，body `{note?}`）→ 202 `{conversationId}`。

## 名字

弃 "askai"（像"问 AI 一个问题"，对不上"带状态开会话去改/诊断"）。动作动词 `:iterate`/`:triage` 保留（N5 已定、前端契约）。共享服务包 `aispawn`（spawn 一个 AI 对话；非"ask"味）——可改名。

## 分期

| 期 | 内容 | 状态 |
|---|---|---|
| **G1** | `aispawn` 服务（spawn + Iterate + Triage + 3 端口）+ 单测（fake 端口） | ✅ `d346737b` |
| **G2** | bootstrap：3 端口接真实现 + ExecutionRenderer 前缀分发适配器（4 类型）；HTTP 5×iterate + 1×triage | ✅ `7d52e26e` |
| 文档 | api.md（:iterate ×5 + :triage）+ contract #49 + lab。events 复用既有（开的就是普通对话、无新事件）；**DB 无变更**（普通 cv_ 对话） | ✅ 本提交 |

**R0065 全完成**（aispawn）：iterate 面对实体借 @-mention、triage 面对任意执行借详情读取。**波次6 全完成**（R0064 ask/danger + R0065 iterate/triage）。

## 扩展（用户「都做了吧」，已全做）

- **iterate 5→8 实体**：补 trigger/control/approval（各 +mention resolver + MentionType + :iterate case + bootstrap 注册）。mention 可 @ 类型 5→8。
- **triage 4→6 类型**：补 mcp 调用（`mcl_`，新增 mcp.GetCall：domain 接口/store/service/fake）+ trigger activation（`tra_`，复用现有 GetActivation——activation 动作日志「为什么没/触发」比内部 firing 更可诊断）。executionRenderer +mcp/trg 依赖 + 2 前缀分支。

**全覆盖**：iterate = 8 个有 mention resolver 的 forge 实体；triage = 6 类执行记录（function/handler/agent/flowrun/mcp-call/trigger-activation）。

## 不做（明确）

- 不碰 schema（开的是普通对话，复用现有 messages/conversation 表）。
- triage 不自动重跑（用户审 fix 后手动重试）。
