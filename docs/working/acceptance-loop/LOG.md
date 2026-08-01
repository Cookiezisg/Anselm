---
id: WRK-092
type: working
status: active
owner: "@weilin"
created: 2026-08-01
reviewed: 2026-08-01
review-due: 2026-10-30
audience: [human, ai]
landed-into:
---

# WRK-092 · 验收战役日志

## 2026-08-01 22:20 · 第五批 TOOL-046 收尾与 AX 观察红线修复

- formal-98 与 formal-100 的真实 App 观察在流式动态语义树替换期间读取 AX state，产生 macOS `accessibility_bridge` AXTree 红线；两次均作为反证冻结，未判绿。formal-99 的无 Computer Use AX 读取基线为零，确认问题位于观察时机而非后端、SSE 或业务路径。
- stop-and-fix：streaming markdown 与 live tail 增加稳定外层 `Semantics` 节点并排除半成品子树语义，补 62 项定向 Flutter 测试；`rig-check.sh` 将 AXTree 错误与 Flutter/Dart/RenderFlex/Unhandled 红线同样拒绝，`testend/rig/README.md` 记录稳定态 AX 读取与连续录屏规则。
- formal-102 `/private/tmp/anselm-rig-formal-102/sessions/20260801-221506` 以真实 App、受管网关、Computer Use、独立三流 SSE tap 和 LLM tap 重跑 `search_control`。正向精确命中 `acceptance_control_fixture_102`，负向 `zzqvulon_102` 返回空集；录屏 `114.528333s / 2784x1808 / 60fps`，messages durable `1..28`、notifications `1..5`、entities 已连接无 gap，LLM 状态全 200，backend/frontend journal 无未解释红线，最终帧视觉复核通过。
- fixture control 与 conversation 均 DELETE=204，残留查询为零；formal-102 session 已收台且无进程泄漏。五级裁决 `TOOL-046=G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 `280 judgments`；`gap-too-fast` 与 `discovery-collapse` 按 formal-102 五通道证据重审并 ack，最终警报 clean。
- 第五批达到 **50 / 50**。按 P15，下一步运行统一长门禁和工作树审计；门禁未全绿前不提交、不进入 `TOOL-047`。

## 2026-08-01 21:56 · TOOL-045 execution detail 正式通过

- formal-97 使用真实 App、受管网关和 Computer Use，对 REST 预构造的 `agx_071dc2aa5859c391` 只读调用 `get_agent_execution` 一次。正向报告包含 id/agent/version/model/key/provider/status/trigger/input/output/error/timing 以及两条 transcript（reasoning→text），raw REST、LLM wire、UI 一致。
- detail transcript 的 off-chat block 出现空 id/message/seq/status 与零值时间；前线审查 backend `messages.Block` 契约确认 loop 内存块只有落共享 `message_blocks` 时才分配这些字段，而 execution transcript 是自包含 block 内容，不应伪造元数据。frontend `hydrateTranscript` 对缺 id 生成稳定 `hblk_*`，轨迹不会丢失或孤儿化，故不改数据模型。
- 负向不存在 `agx_0000000000000000` 只调用一次，UI 显示 `agent execution not found`，无 retry/搜索/写工具。五通道 session `/private/tmp/anselm-rig-formal-97/sessions/20260801-214604`：screen.mov `286.645000s / 2784x1808 / 60fps`；SSE durable `notifications 1..3`、`entities 1..4`、`messages 1..28` 连续；LLM 18 个状态响应全 200；backend 仅预期 not-found WARN；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线。fixture agent/conversation DELETE=204，台架已收台，摘要为 `evidence/tool-045-formal-97-green.txt`。
- 五级裁决 `TOOL-045=G1/F2/A5/C4/G2` 已写入 COVERAGE。锚点 10/10 通过；`gap-too-fast`、`discovery-collapse` 以 formal-97 真实录屏/五通道复审后 ack，`alarms.py check` clean(275 judgments)。第五批从 **40 / 50** 推进至 **45 / 50**，不跑统一长门禁、不提交；下一前线 `TOOL-046 search_control`。Goal API 与 `LOOP.md` 均为 `active`。

## 2026-08-01 21:40 · TOOL-044 修复分页与瘦身后正式通过

- formal-95 首轮因 Computer Use `type_text` 丢失中文约束，模型越界建立/编辑/运行/删除临时 agent；该 session 作为 setup-contamination 红证据保留在 `/private/tmp/anselm-rig-formal-95/sessions/20260801-211951/evidence/tool-044-input-contamination-red.txt`，不计绿。clean retry 又发现列表携带完整 `transcript`，且模型把 opaque cursor 从 `...478Z` 改成 `...479Z`，第二页出现重复 ID；直接 REST 原 cursor 返回唯一第三条，确认分页 ORM 边界正确。红证据为 `/private/tmp/anselm-rig-formal-95/sessions/20260801-211951/evidence/tool-044-pagination-red.txt`。
- 前线冻结后，`ListExecutions` 裁剪列表 transcript，工具 description/schema 明确 `nextCursor` 必须逐字复制、禁止 decode/round/reconstruct；补 store 分页无重叠与列表瘦身测试，并同步 agent domain/API/extract 文档。定向 `go test ./internal/infra/store/agent ./internal/app/tool/agent` 全绿，`git diff --check` 通过。
- formal-96 `/private/tmp/anselm-rig-formal-96/sessions/20260801-213218` 使用新二进制、真实 onboarding、真实受管网关和 Computer Use 完成正向两页分页与负向 `status=failed` 空结果。正向页面为 2+1、ID 零重叠、最终无 cursor，三 execution 均 `ok/manual` 且 input 完整；列表没有 transcript。负向为 0 行、`hasMore=false`、无 cursor、`okCount=3/failedCount=0`，无错误或写动作。
- 五通道已封存：screen.mov `414.928333s / 2784x1808 / 60fps`；SSE durable `notifications 1..5`、`entities 1..12`、`messages 1..49` 连续；LLM 28 个状态响应全 200，wire 仅有 search_agent/search_agent_executions；backend 无 WARN/ERROR/PANIC/FATAL，frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线。fixture agent/conversation DELETE=204，台架已收台，完整摘要为 `evidence/tool-044-formal-96-green.txt`。
- 五级裁决 `TOOL-044=G1/F2/A5/C4/G2` 已由 `judge.py` 写入 COVERAGE。锚点 10/10 通过；`gap-too-fast`、`discovery-collapse` 依据 formal-96 完整录屏/五通道复审后 ack，`alarms.py check` clean(270 judgments)。第五批从 **35 / 50** 推进至 **40 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线 `TOOL-045 get_agent_execution`。Goal API 与 `LOOP.md` 均为 `active`。

## 2026-08-01 21:13 · TOOL-043 修复后正式通过

- formal-93 的正向 `invoke_agent` 已真实成功，负向不存在 agent ID 也只执行一次并准确显示 `agent not found`；Computer Use 逐帧复核发现右侧 Activity 错用了实体编辑专用文案 `Draft unsaved · truth is still the last version`，故冻结前线并保留红证据 `/private/tmp/anselm-rig-formal-93/sessions/20260801-205216/evidence/tool-043-red-activity-ribbon.txt`。
- 修复新增 `AnHonesty.failedRun`，按 `create_*`、`edit_*`、其它执行舞台三类失败语义分流；同步双语 i18n、`docs/references/frontend/features/chat.md` 和 `stages_w4_test.dart`，定向 W4 测试 13/13 通过。
- formal-94 session `/private/tmp/anselm-rig-formal-94/sessions/20260801-210343` 使用新二进制、真实 onboarding、真实受管网关和 Computer Use 完成正向 `search_agent → invoke_agent` 与负向不存在 ID 单次 invoke。正向结构化输出为 answer=4、confidence=1；负向无 executionId、无 retry、无其它写操作，Activity 显示 `Run failed · inspect the error below`，不再出现 draft/version 误导。
- 五通道证据已封存：screen.mov `236.766667s / 2784x1808 / 60fps`；SSE 三路 durable `messages 1..39`、`entities 1..4`、`notifications 1..3`；LLM 20/20 状态响应全 200；backend 只有刻意负路径 WARN，无 panic/fatal/error；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线；REST、SQLite、UI、SSE 与 LLM wire 交叉一致。正负终帧和完整摘要在 session evidence 内。
- agent、conversation 均已真实 DELETE=204 后 GET=404，成功 execution 历史保留；formal-94 收台后无 backend、tap、Flutter 或 recorder 残留进程。五级裁决 `TOOL-043=G1/F2/A5/C4/G2` 已落账，锚点 10/10 通过；警报复审并 ack 后中央账本 `clean (265 judgments)`。
- Goal API 与盘上 `LOOP.md` 均为 `active`；第五批从 **30 / 50** 推进至 **35 / 50**，未到 50 格不跑统一长门禁、不提交。下一前线为 `TOOL-044 search_agent_executions`。

## 2026-08-01 21:02 · TOOL-043 首轮红证据、执行失败丝带冻结

- formal-93 的正向 `invoke_agent` 已真实成功，负向不存在 agent ID 也只执行一次并准确显示 `agent not found`，但 Computer Use 逐帧复核发现右侧 Activity 仍显示实体编辑专用文案 `Draft unsaved · truth is still the last version`。执行调用没有 draft 或上一版实体，这会误导用户，故 `TOOL-043` 不进入裁决；红证据保存在 `/private/tmp/anselm-rig-formal-93/sessions/20260801-205216/evidence/tool-043-red-activity-ribbon.txt`，录像和五通道 journal 保留。
- 前线修复为三类失败真相：`create_*` 使用“尚未创建实体”，`edit_*` 使用“上一版仍是真相”，其余执行舞台使用新的 `运行失败 · 详情见下方错误`，不再暗示草稿/版本；同步双语 i18n、`docs/references/frontend/features/chat.md`，补 `stages_w4_test.dart` 执行失败守卫。W4 目标测试 13/13 通过。
- formal-93 的 agent、conversation 已 DELETE=204→GET=404，未复用旧 fixture。formal-94 将用新二进制重新 onboarding、正负执行并逐帧复核，成功后才写五级裁决；当前第五批仍 **30 / 50**，不跑统一长门禁、不提交。

## 2026-08-01 20:49 · TOOL-042 修复回声重叠后正式通过

- formal-91 的首发红证据保留：真实 App 短暂同时显示乐观 user bubble 与 durable user bubble，最终 SQLite 只有一条 user 消息，但该可见瞬态违反逐帧无跳变标准；formal-91 fixture 已在上一条日志中完成 DELETE=204→GET=404 清理，不计入绿格。
- 前线冻结后定位为 `ConversationTranscript.applyFrame` 在 REST hydration 已写入 terminal settled block 后，又把相同 durable prelude 送进 live reducer 的跨层幂等缺口。修复为已 settled 的 durable block id 直接跳过 prelude，保留非终态 live seed；新增 model 回归测试并同步 frontend 数据边界文档。定向 Flutter 测试 48/48 通过，`git diff --check` 通过。
- formal-92 使用新二进制、真实 onboarding、真实受管网关与 Computer Use 完成正负路径：正向严格为 `search_tools → search_agent → search_tools → update_agent_meta`，只执行一次并精确改 name/description/tags；负向只执行一次不存在 ID `ag_0000000000000000` 的 `update_agent_meta`，显示 `agent not found` 后停止，无 retry/其它副作用。
- 五通道证据 session `/private/tmp/anselm-rig-formal-92/sessions/20260801-203729` 已封存：screen.mov `415.496667s / 2784x1808 / 60fps`；SSE durable `messages 1..47`、`entities 1..4`、`notifications 1..7`；LLM 24 个状态响应全 200；backend 仅一条预期 not-found WARN，无 error/fatal/panic；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线；REST/SQLite、UI 与 LLM wire 一致。正负画面和五通道摘要均在 session evidence 内。
- formal-92 conversation、两个 agent、document、skill 均 DELETE=204 后 GET=404；成功 execution `agx_c4df44281575d3bf` 保留为 `ok/manual`，正式台架已 `rig-down` 且无残留进程。五级裁决 `TOOL-042=G1/F2/A5/C4/G2` 已通过 `judge.py` 写入 COVERAGE，中央账本从 255 增至 260。
- 裁决后 `alarms.py check` 按设计重新打开 `gap-too-fast` 与 `discovery-collapse`；已用 formal-92 完整录屏、负路径、五通道 journal、锚点校准和此前 formal-91 红证据复审并 ack，最终 `alarms.py check` clean(260 judgments)。Goal API 与盘上 `LOOP.md` 均为 `active`；第五批从 **25 / 50** 推进至 **30 / 50**，下一前线为 `TOOL-043`，未到 50 格不跑统一长门禁、不提交。

## 2026-08-01 20:34 · formal-91 收台、fixture 清理、恢复 Goal 后冻结 TOOL-042

- `formal-91` 的真实 App 路径暂不进入裁决：首发后 Computer Use 画面短暂同时出现乐观 user bubble 和 durable user bubble，流收尾后才收敛为一枚；SQLite 最终只有一条 user message 和一条 user block，因此不是持久重复，但仍违反“逐帧无跳变”的产品标准。红证据摘要为 `/private/tmp/anselm-rig-formal-91/sessions/20260801-202601/evidence/tool-042-formal-91-red-cleanup.txt`，`screen.mov` 已由 `rig-down.sh` 封口为 `402.378333s`。
- formal-91 fixture 已全部清理并交叉验证：conversation `cv_4f6bc3596c3ae4a4`、agents `ag_5b0eb02605dbe4c7`/`ag_9bc1bc7e30fe75a6`、document `doc_a0e653628e7417ec`、skill `acceptance-update-meta-skill-91` 均 DELETE=204 后 GET=404；`agent_execution agx_163c8f77fcfbb50` 仍保留为 `ok/manual` 历史。台架 `rig-check` 通过后已正常收台，无 formal-91 进程残留。
- Goal API 当前已恢复为 `active`，盘上 `LOOP.md` 仍为 `active`，没有创建重复 Goal；本批仍 **25 / 50**，下一前线仍为 `TOOL-042 update_agent_meta`。前线冻结，先修复首发回声的原子收敛，再用新二进制重跑，不把 fixture 清理或 formal-91 红证据计入绿格。

## 2026-08-01 20:09 · TOOL-041 delete_agent 收尾、两轮红证据修复后正式通过

- formal-88 不进入裁决：真实 App 的 hosted model 只收到旧的一行删除回执，随后臆造 4 条 removed edges；SQLite/关系 purge 真相只有 2 条 agent→document/skill 的 `equip` 边。前线冻结后在 `relation.Service` 增加双向 `ListTouching` 快照，在 `delete_agent` 增加权威 JSON 回执：`executionHistory=retained`、`removedRelationEdges` 精确列出删除前边、`removedRelationCount`；同步 `dependents` 结构与 agent 领域文档、Go 守卫测试，明确模型不得推断。
- formal-89 真实复跑确认后端回执已正确，但前端 `parseAgentDependents` 在结构化 JSON 没有 `dependents` 字段时错误回退 legacy regex，UI 显示虚假的“12 refs affected”。修复为任何可解码结构化回执都不再走旧 parser，补 Flutter widget/model 回归测试；formal-88/89 红证据和修复前画面均保留。
- formal-90 使用新二进制、真实 onboarding、managed gateway、Computer Use、连续录屏、Flutter console、三路 SSE witness、LLM tap 完成正式路径。fixture agent 预挂 document+skill，并先用 REST 建立一条成功 `agent_execution` 作为历史保留对照；真实用户消息最终只触发一次 `delete_agent`，危险动作经人闸批准。UI 删除卡无虚假依赖红块，最终报告精确复述结构化回执：`deleted=true`、`executionHistory=retained`、`removedRelationCount=2`、2 条 outbound `equip` 边，随后停止。
- 五通道：录屏 `screen.mov` 已封口，`365.840s / 2784x1808`；LLM chat 全 HTTP 200，wire 只有一次实际 delete call 与一次结构化 tool result；SSE durable `messages 1..13`、`entities 1..4`、`notifications 1..9` 连续；backend/frontend journal 无 panic/fatal/error/warn 红线。formal-90 的摘要、全量 journals、wire bodies/responses 和录屏保存在 `/private/tmp/anselm-rig-formal-90/sessions/20260801-195945/`。
- 清理已完成：document、skill、conversation 各 DELETE=204 后 GET=404；SQLite agent/document/conversation tombstone 已写入，agent execution `agx_2bba47195e6371af` 仍为 `ok/manual`，关系表 touching agent 为 0。正式五级裁决 `TOOL-041=G1/F2/A5/C4/G2` 已通过 `judge.py` 写入 COVERAGE，锚点校准通过；gap-too-fast 与 discovery-collapse 以 formal-88/89 红证据、formal-90 五通道和 cleanup 真相复审并 ack，`alarms.py check` 为 `clean (255 judgments)`。
- 第五批从 **20 / 50** 推进到 **25 / 50**。按协议未到 50 格，不运行统一长门禁、不提交；下一前线为 `TOOL-042 update_agent_meta`。Goal API 旧实例仍是不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，未创建重复 Goal。

## 2026-08-01 19:40 · TOOL-040 revert_agent 收尾

- formal-86 不进入裁决：真实 App 首轮出现两枚可见红卡，hosted model 先发 `get_agent({})`，再发 `revert_agent` 的 `version:"1"`；前者是模型漏填 required key，后者暴露 `revert_agent` 与已有 `revert_handler` 的执行边界不一致。前线冻结后将 `revert_agent` 改为公开 schema 仍为 integer、执行边界仅兼容精确整数字符串，强化 `agentId`/`version` 描述，补 `agent_test.go` 回归测试并同步 `docs/references/backend/domains/agent.md`。`go test ./internal/app/tool/agent ./internal/app/agent`、`make -C docs verify`、`git diff --check` 通过。
- formal-87 使用新二进制和真实 onboarding 创建 `Acceptance Revert Agent 87` workspace；REST setup 建立 `ag_3833aea31499eadd` 的 v1/v2，v1 prompt 与 v2 修改 prompt 的历史均保留。正向 Chat 只调用一次 `revert_agent`，wire 参数为 `{"agentId":"ag_3833aea31499eadd","version":"1"}`，执行成功回 v1 `agv_bcfc4c93c0dc2be6`，无红卡；随后一次 `get_agent` 准确回读 active v1 prompt、name、description、tags。负向只调用一次 version 999，UI/最终回答显示 `agent version not found`，无 retry 或其它工具。
- 五通道：screen.mov `208.695000s / 2784x1808 / 60fps`，终帧为 `evidence/frames/tool-040-positive.jpg`、`tool-040-negative.jpg`；LLM challenge/install/models/chat 全 HTTP 200，实际新调用为一次正向 revert、一次 get、一次负向 revert，后续 body 中重复的是历史上下文；SSE 329 行，messages durable `1..44` 无 gap；backend 234 行仅预期负路径 WARN、无 ERROR/PANIC/FATAL；frontend 17 行无 FlutterError/DartError/RenderFlex/Unhandled/SEVERE/Exception；REST/SQLite active v1、历史恰 v1/v2、mount-health healthy，relations=0。
- 清理：agent 与 conversation 均 DELETE=204、随后 GET=404；API 搜索无 acceptance 残留，SQLite 保留 deleted_at tombstone 与 v1/v2 审计版本，进程由 rig-down 收台且无 Anselm 台架残留。证据摘要为 `evidence/tool-040-revert-agent-session-summary.txt`。
- 五级裁决 `TOOL-040=G1/F2/A5/C4/G2` 已落账；gap-too-fast 与 discovery-collapse 用 formal-86 红证据、formal-87 五通道、录屏抽帧和 SQLite 真相复审并 ack，`alarms.py check` 为 `clean (250 judgments)`。第五批从 **19 / 50** 推进至 **20 / 50**，按协议不跑统一长门禁、不提交；下一前线为 `TOOL-041 delete_agent`。Goal API 旧实例仍不可恢复地 `blocked`，盘上 `LOOP.md` 保持 `active`。

## 2026-08-01 19:22 · TOOL-039 edit_agent 收尾

- 前置审查发现契约漂移：LLM `edit_agent` 已实现“只覆盖显式字段、显式空值才清除”，但 `get_agent` 描述仍写成全量替换，领域文档与 app 层注释也混淆 HTTP `:edit` 全量快照和工具层 partial merge。前线冻结后修正 `query.go`、agent service 注释、agent domain 文档，补 `TestGetAgent_DescriptionMatchesPartialEditContract`；`go test ./internal/app/tool/agent ./internal/app/agent`、`make -C docs verify`、`git diff --check` 全部通过。
- formal-85 真实 onboarding 创建 `Acceptance Edit Agent 85`，REST setup 构造 agent `ag_7d0db44aca4c2ece` 的 v1：skill `acceptance-edit-skill-85`、document `doc_232a942fd12cd220`、function `fn_1ebf9efeb71d5dad`（env ready）均挂载。正向 Chat 只让用户改 prompt；wire 的当前实际调用为 `get_agent` 后单次 `edit_agent`，返回 v2 `agv_fb08c7415f59a98c`。UI 显示 v1→v2、版本 ID 和 preserved-fields 说明；REST activeVersion、mount-health `allHealthy=true`、skill/document/function 三条 equip relation 与 SQLite v1/v2 完全一致，未产生 v3。
- 负向同一真实 App 对 `ag_0000000000000000` 只调用一次 `edit_agent`。UI 显示 `agent not found`、`Draft unsaved · truth is still the last version`，无 retry/search/create/delete。LLM tap 后审查发现 00008/00009 body 中历史 get/edit tool_calls 是完整上下文回放，不是再次执行；版本数为 2、backend 只有一条预期 not-found WARN，故不是重复写入。
- 五通道：screen.mov `290.713333s / 2784x1808 / 60fps`；LLM 7 request bodies、9 response records 全 HTTP 200；SSE 248 行，messages/entities/notifications durable 分别 `1..36`、`1..4`、`1..15`，无 gap；backend 425 行仅预期负路径 WARN，无 ERROR/PANIC/FATAL；frontend 无 FlutterError/DartError/RenderFlex/Unhandled/SEVERE/Exception/Lost connection，151 条 AXTree bridge 行与 formal-84 无 Computer Use 基线对照后归类为 Computer Use 动态 AX 查询噪声。正负终帧与摘要保存在 session `evidence/`。
- 清理：agent、skill、document、function、conversation 均真实 DELETE=204、GET=404；agent relations 归零，SQLite agent/function tombstone 已写入，API 命名扫描无 acceptance 残留；rig-down 后 backend、ssetap、llmtap、Flutter runner、recorder 无残留，证据保留。
- 五级裁决 `TOOL-039=G1/F2/A5/C4/G2` 已由 `judge.py` 落账。`gap-too-fast` 与 `discovery-collapse` 经五通道/红证据/基线复审后 ack，当前 `alarms.py check` 为 `clean (245 judgments)`。第五批从 **18 / 50** 推进至 **19 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-040 revert_agent`。Goal API 旧实例仍不可恢复地 `blocked`，盘上 `LOOP.md` 保持 `active`。

## 2026-08-01 19:10 · TOOL-038 create_agent 收尾

- formal-81 的首轮真实 App 路径发现新线程首发时 scoped SSE 尚未接上，乐观 user bubble 没有被 durable 回声收敛，画面出现重复问句；前线冻结后在 `conversation_stream_provider.dart` 增加普通 send 的窄 REST head reconcile，retry 保持同一 bubble 语义，Flutter model/provider 定向测试共 37 项通过。
- formal-82 发现用户明确提供 agent description 时托管模型漏发 `description`，创建成功但 REST description 为空；前线冻结后收紧 `create_agent` 的工具契约和 schema 描述，补 `agent_test.go` 与 agent 领域文档。该红 session 保留，不计绿。
- formal-83 修复后由真实 Flutter App、managed gateway、Computer Use、连续录屏、Flutter console、三路 SSE witness 和 LLM tap 完成正负路径。正向 exact name/description/system prompt 贯穿 wire、entities、REST 和 UI；负向重复名只发一次 `create_agent`，UI 显示 `agent name already exists` 与 `Draft unsaved · nothing was created`，无 retry/修改/运行。正向 agent 为 `ag_c99dd62a78f39e46`、版本 `agv_a595a4d3437161c6`，终帧与五通道摘要保存在该 session 的 `evidence/`。
- 五通道：screen.mov `271.741667s / 2784x1808`；LLM challenge/install/models 与 12 个 chat response 全 200；messages/entities/notifications durable 分别 `1..35`、`7..10`、`16..20`，各自一次连接且无 gap；backend 只有预期 duplicate-name WARN；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线。formal-84 无 Computer Use 的 49.608333s 基线 frontend journal 无 accessibility bridge 或 Flutter/Dart/RenderFlex/Unhandled 红线，formal-83 的动态 `AXTree` 行因此归类为观察器噪声，不修改产品。
- 清理：agent DELETE=204、GET=404，conversation DELETE=204、GET=404，SQLite `deleted_at` 已对证；rig-down 后 backend、ssetap、llmtap、Flutter runner、recorder 均无残留，证据 session 不删除。五级裁决 `G1/F2/A5/C4/G2` 已由 `judge.py` 落账，警报复审并 ack 后 `clean (240 judgments)`。
- 第五批从 **17 / 50** 推进至 **18 / 50**。按协议不跑统一长门禁、不提交；下一前线为 `TOOL-039 edit_agent`。Goal API 旧实例仍不可恢复地 `blocked`，盘上 `LOOP.md` 维持 `active`，不创建重复 Goal。

## 2026-08-01 18:40 · TOOL-037 get_agent 收尾

- 正式 session `/private/tmp/anselm-rig-formal-20260801-80/sessions/20260801-182748` 由真实 App + managed gateway + Computer Use 完成。前置无效 outputs setup 400、第一轮无副作用 Bash/中途未完成截图均保留为非裁决红证据；strict 正向只执行 `search_tools → search_agent → get_agent`，最终字段表完整展示顶层 meta 与 activeVersion 全字段，Composer 在 message_stop 后恢复输入态。
- 负向对不存在 `ag_0000000000000000` 只执行一次 `get_agent`，UI 显示 `agent not found`，无 retry/修改/运行。正负终帧 `evidence/tool-037-positive-final.png`、`tool-037-not-found.png` 已视觉复核；五通道摘要为 `evidence/tool-037-get-agent-session-summary.txt`。
- 五通道：screen.mov `318.590000s`；LLM challenge/install/models 与 28 个 chat completion response 全 200；messages durable `1..74`、notifications `16..26`，三路均连接；backend 仅预期 setup 400、业务 not-found WARN 和清理 404，frontend 无红线。fixture DELETE=204/GET=404，三个 acceptance 对话逐个 DELETE=204/GET=404，SQLite `deleted_at` 对证。
- 五级裁决 `TOOL-037=G1/F2/A5/C4/G2` 已由 `judge.py` 落账；三条统计警报复审并 ack 后 `clean (235 judgments)`。第五批新完成单格 **17 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-038 create_agent`。

## 2026-08-01 18:30 · TOOL-036 收尾、TOOL-014/024 共享搜索原语复验恢复

- `TOOL-014 search_function` 与 `TOOL-024 search_handler` 因共享 `ContentSearch` 修复先暂挂旧绿裁决；正式 session `/private/tmp/anselm-rig-formal-20260801-79/sessions/20260801-181753` 重新覆盖两者的命中、空 query、identifier-shaped no-match 六条路径。raw wire、UI 工具卡/表格、SQLite、三路 SSE、backend/frontend 和 343.531667 秒录屏一致，六张终帧已视觉复核，无新增产品缺陷。两格各恢复 `G1/F2/A5/C4/G2`。
- `TOOL-036 search_agent` 使用 formal session 78 的固定后真实三路径证据恢复 `G1/F2/A5/C4/G2`：命中、空 query、`zzqvulon_78` no-match 均无假阳性；formal-76 的 embedding 假阳性仍作为红证据保留。三格裁决全部由 `judge.py` 落账，非手改 COVERAGE。
- 裁决后 `alarms.py check` 打开 gap-too-fast/pass-burst/discovery-collapse；已分别以两 session 的录像时长、五通道证据、实际 identifier no-match 和旧红证据复审并 ack，最终 `clean (230 judgments)`。本批新完成单格只有 TOOL-036，累计 **16 / 50**；复验旧格不重复计数，未到 50 格，不跑统一长门禁、不提交。下一前线为 `TOOL-037 get_agent`。

## 2026-08-01 18:16 · TOOL-036 search_agent 正式三路径完成、共享搜索原语待复验

- 前一 session 77 只有 onboarding/fixture 生命周期，未裁决；本次固定修复后二次真实 App session `/private/tmp/anselm-rig-formal-20260801-78/sessions/20260801-181026` 才完成完整三路径。强制“只调用 search_agent、禁止其它工具”的提示被明确记录为台架约束红证据：lazy tool 必须先用 `search_tools` 激活，不能把不可能的提示当产品绿路径。
- 正向自然语言找名：模型先激活搜索、再单次 `search_agent`，UI `Searched agent … · 1 found`，正文准确返回 fixture 名称和描述；空 query 浏览：UI `Searched tools → Listed agent · 2 found`，表格列出 fixture 与预置报表助手；不相交标识符 `zzqvulon_78`：UI `Searched agent … · no matches`，正文明确 0 条，不编造实体。终帧分别为 `evidence/tool-036-positive.png`、`tool-036-empty.png`、`tool-036-no-match.png`；三帧已视觉复核，无布局跳变、等待失控或错误文案。
- 五通道：screen.mov `259.898333s`；LLM challenge/install/models 与 26 个 chat completion response 全 200；三路 SSE 各连接一次，messages 712 帧/durable `1..62` 连续，notifications 14 帧/durable `16..29` 连续，entities 无本切片业务帧但连接完整；backend 仅 200/201/202/204 和清理后的预期 404，无 panic/error/warn；frontend 无 Flutter/Dart/RenderFlex/Unhandled/SEVERE/Exception 红线。摘要：`evidence/tool-036-search-agent-session-summary.txt`。
- 收尾：fixture `ag_b1add33b041e7cb1` DELETE=204、GET=404、SQLite `deleted_at` 对证；四个 acceptance 对话同样 DELETE=204、GET=404，预置演示对话未删除；所有进程已由 `rig-down.sh` 收口，录像、journal、LLM bodies/responses 保留。
- **不立即裁决**：本格的修复触及共享 `ContentSearch` 语义原语；旧的 `search_function`、`search_handler` 等已绿格自动进入待复验队列。先做同类搜索的正向、空 query、identifier no-match 复验，再以完整证据一次性按 gate 落账。本批仍 **15 / 50**，不跑统一长门禁、不提交。

## 2026-08-01 18:07 · TOOL-036 固定修复 session 收台、fixture 清理与 Goal 恢复检查

- 固定修复后的 `search_agent` session `/private/tmp/anselm-rig-formal-20260801-77/sessions/20260801-180355` 已完成收台；`screen.mov` 为 `197.091667s`，后台 server、ssetap、llmtap、Flutter runner、window recorder 和 llama runtime 均无残留，五通道 journal 与录像完整保留。
- 通过真实 API 删除 fixture `ag_c60a92bcc799a856` (`acceptance_search_agent_fixture_77`)；DELETE 返回 `204`，随后同 workspace GET 返回 `404 AGENT_NOT_FOUND`，SQLite 主行 `deleted_at=2026-08-01 10:07:35.611655+00:00`。当前 workspace 没有未删除的 acceptance 对话；清理回执保存在该 session 的 `evidence/tool-036-cleanup.txt`。
- 该 session 尚未进入五级裁决：它用于承载 `TOOL-036 search_agent` 的修复后正式路径，需先补齐五通道摘要、审查旧搜索绿格因共享语义原语变更而产生的复验范围，再按 `judge.py` 落账；不能因 fixture 已删除就把它判绿。
- Goal API 当前仍是 `blocked` 且没有 `blocked → active` 操作；没有创建重复 Goal、没有伪造 `complete`。盘上 `LOOP.md` 保持 `status: active`，清理完成后继续 `TOOL-036` 的证据审查，当前第五批仍 **15 / 50**。

## 2026-08-01 17:58 · 第五批 TOOL-035 get_handler_call 收尾

- 产品目的：用户从 Chat 打开一条具体 handler call 的完整审计记录，能看到 method、status、input、output、elapsedMs 和 logs；不存在记录时要给出可理解失败且不自动 retry。
- 正式 session `/private/tmp/anselm-rig-formal-20260801-75/sessions/20260801-174951` 先由真实 onboarding 创建 `Acceptance 75` workspace，再以 REST 构造 handler `hd_4b36bca467a9af7f` 和一条成功 `trace` 调用 `hcl_47cfc89610c56086`。该调用的 output 为 `{"count":1,"ok":true}`，logs 含 `trace-call-start`，SQLite 只有这一条调用审计。
- 正向真实 Chat 只执行一次 `get_handler_call`，成功卡和最终报告均完整呈现字段与日志；负向真实 Chat 只执行一次不存在 ID `hcl_0000000000000000`，工具卡为 failed，最终报告为 `handler call not found` 并停止，无 retry/其它工具。正负终帧为 `evidence/tool-035-positive.png`、`evidence/tool-035-final.png`。
- 五通道事实：screen.mov `173.071667s`；LLM 16 个响应全 200；SSE 169 帧，messages/entities/notifications 各连接一次，durable 分别 `1..28`、`1..4`、`1..5`；frontend 无 Flutter/Dart/RenderFlex/Unhandled/SEVERE/Exception/AXTree 红线；backend 仅一条预期 not-found WARN；REST、SQLite、UI、LLM wire 一致。摘要为 `evidence/tool-035-get-handler-call-session-summary.txt`。
- 清理：handler DELETE=204 后 GET=404，conversation DELETE=204 后 GET=404；主行均写入 `deleted_at`，审计与全部证据 session 保留，无活跃 acceptance fixture。无代码缺陷，无修复提交。锚点校准通过，五级裁决 `G1/F2/A5/C4/G2` 已落账；`gap-too-fast`、`pass-burst`、`discovery-collapse` 均已写复审结论并 ack，`alarms.py check` 为 `clean (215 judgments)`。第五批当前 **15 / 50**，下一前线为 `TOOL-036`；未到 50 格，不跑统一长门禁、不提交。

## 2026-08-01 17:47 · 第五批 TOOL-034 search_handler_calls 收尾、标量兼容修复

- 前置 session `/private/tmp/anselm-rig-formal-20260801-72/sessions/20260801-172949` 不进入裁决：长提示让模型先执行辅助 todo 和多步 handler 操作，属于输入/场景污染；但其中的真实 REST/SQLite 数据真相、调用历史和完整五通道 journal 全部保留。session `/private/tmp/anselm-rig-formal-20260801-73/sessions/20260801-173722` 进一步暴露真实产品边界：托管模型首次把公开 integer 参数 `limit` 发为字符串 `"2"`，后端原实现返回类型错误，UI 出现可见红色失败卡，模型随后 retry；该 session 也只作红证据。
- 前线冻结后按 `search_function_executions` 的既有兼容先例修复 `backend/internal/app/tool/handler/call.go`：公开 schema 仍为 integer，但执行边界接受缺省/null、原生整数和精确十进制字符串，拒绝浮点、数组、布尔、非数字和非正值；同步 `handler_test.go`、`docs/references/backend/domains/handler.md` 和 `testend/rig/extracts/tools.md`。定向 handler/function Go 测试、`make -C docs verify` 和 `git diff --check` 均通过。
- 正式 session `/private/tmp/anselm-rig-formal-20260801-74/sessions/20260801-174220` 由真实 App、受管网关、Computer Use 连续录屏、Flutter console、三路 SSE witness、LLM wire 和后端 journal 共同观察。wire 首次仍为 `{"handlerId":"…","limit":"2"}`，但直接成功；UI 只显示一张成功卡，表格呈现最新 failed/次新 ok、`nextCursor`、`hasMore` 和全匹配集 `okCount:2/failedCount:1`，无 retry、红卡、跳变或布局问题。
- 收尾：backend 无未解释错误，frontend 无 Flutter/Dart/RenderFlex/Unhandled/SEVERE/Exception 红线，REST/SQLite 对证恰三条 setup 调用和正确分页聚合，三路 SSE durable 序列连续；fixture DELETE=204、GET=404，acceptance 对话 DELETE=204，证据 session 保留。五级裁决 `G1/F2/A5/C4/G2` 已落账；anchors 通过，`gap-too-fast` 与 `discovery-collapse` 已写复审说明并 ack，最终 `alarms.py check` 为 `clean (210 judgments)`。第五批当前 **10 / 50**，下一前线为 `TOOL-035 get_handler_call`；未到 50 格，不跑统一长门禁、不提交。

## 2026-08-01 17:26 · 第五批 TOOL-033 restart_handler 收尾、输入污染隔离

- 首个真实 App session `/private/tmp/anselm-rig-formal-20260801-70/sessions/20260801-171503` 不进入裁决：Computer Use 的 `type_text` 将中文用户约束丢失，只把 ASCII 关键词送入 LLM wire；模型因此额外调用了 3 次 `bump`、`edit_handler`、`update_handler_config`、代码 edit 和 `revert_handler`。画面、backend/SSE/frontend/LLM journal 全部保留在 `tool-033-scope-violation-summary.txt`，归类为台架输入污染红证据，不判作产品行为；污染 fixture 与对话随后已真实 DELETE 清理。
- 改用 wire 可核对的 ASCII 约束后，正式 session `/private/tmp/anselm-rig-formal-20260801-71/sessions/20260801-172125` 严格执行五步：`search_handler` 一次、`call_handler(bump)` 两次、`restart_handler` 一次、`get_handler` 一次；没有任何越界工具、retry 或 Bash/REST。restart 前后 count 均为 1；active v1、method 签名、envStatus=ready、runtimeState=running 均不变。最终抽帧 `evidence/tool-033-final.png` 显示五行工具表和六行断言表，结论不泄漏 opaque machine value。
- 五通道事实：screen.mov `177.958333s`；LLM 20 个响应全 HTTP 200，tool sequence 与 wire 一致；messages/entities/notifications durable 分别 `1..42`、`7..8`、`16..21` 连续无 gap；backend 无 WARN/ERROR/panic/fatal，frontend 无 Flutter/Dart/RenderFlex/Unhandled/SEVERE/Exception/AXTree 红线；SQLite 只有 v1 与两条成功 bump 调用审计。
- 收尾清理：fixture DELETE=204、GET=404；acceptance 对话 DELETE=204，SQLite 均写入 `deleted_at`；证据 session 未删除，seed 正式 handler 未修改。锚点校准通过；五级裁决 `G1/F2/A5/C4/G2` 已落账。统计警报因近尾裁决间隔和 fail 占比触发，已用正式正证据与输入污染红证据复审并 ack；`alarms.py check` 为 clean(205 judgments)。第五批当前 **5 / 50**，下一前线为 `TOOL-034 search_handler_calls`。

## 2026-08-01 17:15 · 旧台架 acceptance fixture 全量清理、循环恢复

- 对历史真实台架数据目录 `formal-33` 至 `formal-38` 逐目录启动隔离后端，使用真实 `DELETE /api/v1/handlers/{id}` 清理 7 个遗留 acceptance handler；每个目标随后用同 workspace `GET` 复核为 `404 HANDLER_NOT_FOUND`。SQLite 只保留不可变版本/调用审计，主行 `deleted_at` 已写入；证据 session、backend journal 和既有 COVERAGE 裁决未删除。
- 清理过程中首次 shell wrapper 把 zsh 保留变量 `status` 当作赋值目标，导致 wrapper 提前退出；`curl` 已实际完成的 DELETE 仍落盘，随后改用 `http_code` 重跑并对 34 号第二个目标补删。该脚本事故不作为产品证据，所有临时后端均由显式 `rig-down.sh` 收台。
- 全目录 SQLite 审计结果：活跃名称匹配 `acceptance|fixture` 的 handler 为 **0**；formal-33/34/35/36/37/38 的软删除计数分别为 `1/2/1/1/1/1`。端口 `8843–8848`、`8854–8858` 与 `anselm-server/ssetap/llmtap/Flutter/llama` 进程均无残留。正式 `order_desk` 未修改。
- Goal API 仍只提供“标记完成/标记阻塞”，没有既有 `blocked → active` 恢复操作；未创建重复 Goal、未谎报完成。持久执行协议 `LOOP.md` 仍为 `status: active`，fixture 清理完成后按 `TOOL-033 restart_handler` 继续下一前线。

## 2026-08-01 17:06 · 第四批 50/50 统一长门禁收口

- `make verify` 全绿：backend、frontend、docs、demo 均通过；修复后的 `backend/internal/app/loop` 守卫测试通过。
- 第一道完整黑盒在媒体 workflow 场景暴露真实回归：`TestWorkflowMedia_FunctionArtifactToVisionAgent` 与
  `TestWorkflowMedia_AgentNodeToAgentNode` 的 flowrun 节点结果收到 `<opaque value omitted>`，因新加的用户
  prose 脱敏越过了数据边界，导致 downstream 无法解析 `attachmentId`。前线冻结；`stream.go` 改为仅对普通
  chat prose 脱敏，带 flowrun 身份的 workflow agent 保留完整 MediaRef receipt，新增 chat/workflow 双向守卫。
  定向两个媒体场景通过，随后完整 `make -C backend testend` 通过（`294.982s`）。
- `cd testend && mise exec -- go test -count=1 -timeout 30m ./...` 全包通过：scenarios `337.102s`，cmd/measure、
  ssetap、fixtures/materialize、golden、harness、proxycore 均通过。第二次 `make verify` 也在文档同步后全绿。
- 收台事实：anchors `10/10`；`alarms.py check` 为 `clean (200 judgments on record)`；`git diff --check` 通过；
  无残留 `anselm-server`、llmtap、ssetap、Flutter runner、scenario test 或 llama-server 进程；临时 acceptance
  fixture 与对话此前均已由真实 DELETE + GET 404 对证，rig 状态目录无未清理 fixture 名称。下一前线为 `TOOL-033 restart_handler`，
  本批次现在一次性提交。

## 2026-08-01 16:22 · 第四批 TOOL-032 update_handler_meta 收尾、批次满 50/50

- 产品目的：真实用户从自然语言找到一个 handler，先观察常驻实例，再只修改 name/description/tags；active version、方法、环境和 resident memory 必须保持，随后不存在 ID 的拒绝要可解释且不重试。
- session `/private/tmp/anselm-rig-formal-20260801-69/sessions/20260801-161542` 由同一 conductor 托管真实 Flutter App、受管网关、Computer Use 连续录像、Flutter console、三路 SSE witness 和 LLM tap。真实路径只调用一次 `update_handler_meta`，前后 bump 得 count 1→2，v1、方法、env ready、创建/同步事实和 running resident 连续；负路径对不存在 ID 只调用一次，`handler not found`，未用 edit/restart/retry。完成 checklist 6/6，Activity 成功目标显示 `Ran ×2`。
- 五通道事实：screen.mov `298.946667s / 2784x1808 / 60fps`；LLM 21 个 response files 全 HTTP 200，19 个 request bodies；SSE 990 帧，messages/entities/notifications durable 分别 `1..116`、`7..8`、`16..21`，无 gap；frontend 无 Flutter/Dart/RenderFlex/Unhandled/SEVERE/Exception/AXTree 红线；backend 仅一条刻意 not-found WARN。抽帧 `evidence/frames/tool-032-220.jpg`、`tool-032-260.jpg`、`tool-032-295.jpg` 已复核，未发现视觉或交互缺陷；摘要为 `evidence/tool-032-update-handler-meta-session-summary.txt`。
- fixture `hd_c7594fb02098ddf8` 已 DELETE 后 GET 404，acceptance conversation 也已 DELETE 后 GET 404；证据 session 和审计 journal 保留。锚点复校通过，五级裁决 `G1/F2/A5/C4/G2` 已落账；两条统计警报已基于本次证据、失败 session 和锚点复审并 ack，当前 `alarms.py check` 为 clean(200 judgments)。
- 第四批达到 **50 / 50**。现在统一运行长门禁、完整 testend、已修场景回归、锚点/警报复核和工作树审计；全部通过前不提交。下一前线暂记 `TOOL-033 restart_handler`。

本页只记录**已经发生的日级事实与前线位置**，不复制 WRK-087 的规则。每日收台后追加一节；细粒度
格子结论只进 COVERAGE 与 `~/.anselm-rig/judgments.jsonl`，证据只放专机 session 目录。

## 2026-08-01 16:15 · 第四批 TOOL-031 update_handler_config 收尾

- 前置 session `/private/tmp/anselm-rig-formal-20260801-54/sessions/20260801-150710` 未进入裁决：Computer Use 在布局变化后误触语音入口，真实受管 ASR 握手返回 503，Composer 停在 `Finishing 00:00`。冻结后修复 `frontend/lib/features/chat/state/speech_input_provider.dart` 的握手失败收尾，新增 fake-channel 守卫，`flutter test` 通过 5/5；该 session 保留为红证据。
- 清理台架也发现 `RIG_LLMTAP=0` 在 `set -u` 下的空数组问题，已修复 `testend/rig/rig-up.sh` 并同步手册。session 65 的 fixture 因 init body 含字面 `\\n` 被判为 setup contamination，不作产品证据；session 67 因旧工具边界导致模型把 config 误送进 `call_handler`，不作绿证据。随后收紧 `call_handler` 描述和执行边界，补 handler 测试及领域/工具提取文档。
- 干净 session `/private/tmp/anselm-rig-formal-20260801-68/sessions/20260801-160415` 使用正确 fixture `hd_c6b5cbdd36c1aa92`，真实 App 先 inspect，再将 config 做 `warm→cool→default` 三次更新；每次 bootId 变化、prefix 保持，明确不存在 handler 的负路径只执行一次返回 `handler not found`，没有错误重试。最终文本不泄漏实体 ID、长整数或 ISO 时间戳，raw tool card 仍保留机器真值；视觉终帧见 `evidence/tool-031-final-clean.png`，五通道摘要见 `evidence/tool-031-final-clean-summary.txt`。
- 五通道事实：screen.mov `2784x1808 / 221.563333s`；LLM 26/26 状态 200；messages/entities/notifications durable 分别 `1..102`、`1..2`、`1..8`；frontend 无 Flutter/Dart/RenderFlex/Unhandled/SEVERE/Exception/AXTree 红线；backend 仅一条刻意 not-found WARN。fixture 删除后 GET 404，历史审计证据与 session 未删除，rig-down 进程组无残留。
- 锚点重新校准通过；`judge.py` 按 COVERAGE 真实 row key `update_handler_config` 写入五级 `G1/F2/A5/C4/G2`。统计警报因连续裁决动作过快和近尾 fail 占比偏低而打开，已用正负证据、锚点和失败 session 复审并分别 ack；当前 `alarms.py check` 为 clean(195 judgments)。
- 第四批从 **40 / 50** 推进至 **45 / 50**；未到 50 格，不运行统一长门禁、不提交。下一前线为 `TOOL-032 update_handler_meta`。Goal API 仍没有 `blocked → active` 操作，不创建重复 Goal、不谎报完成；盘上 `LOOP.md` 保持 active，继续按协议推进。

## 2026-08-01 15:25 · TOOL-031 前置失败、语音清理与台架自修

- session `/private/tmp/anselm-rig-formal-20260801-54/sessions/20260801-150710` 未进入 TOOL-031 裁决：Computer Use 在布局变化后点中了语音按钮，真实受管 ASR 握手返回 503，前端停在 `Finishing 00:00`，Composer 无法恢复。录屏 `screen.mov` 可读（`2784x1808 / 941.5s`），终帧与 backend/frontend 原始错误已保存在该 session 的 `evidence/`，此 session 只作红证据。
- 前线冻结后修复 `frontend/lib/features/chat/state/speech_input_provider.dart`：握手失败由 watcher 捕获，启动竞争期暂存错误，录音初始化收尾时以 `socketAlreadyClosed=true` 走统一失败清理，确保 Composer 解锁且不再等待已关闭音频 sink。新增真实 handshake-failure fake-channel 守卫；`mise exec -- flutter test test/features/chat/state/speech_input_provider_test.dart` 通过（5/5）。
- 为清理 TOOL-031 fixture 启动无 App 台架时暴露 `RIG_LLMTAP=0` 在 `set -u` 下展开空数组的问题；修复 `testend/rig/rig-up.sh` 的无 tap 分支并同步台架手册。修复后的 session `/private/tmp/anselm-rig-formal-20260801-55/sessions/20260801-152437` 仅用于清理，已正常收台。
- 通过真实 DELETE API 删除 `hd_e35443a1b63f72c9` (`acceptance_update_handler_config_fixture_54`)；GET 为 404，SQLite 对证 `deleted_at` 已写入、handler_versions=1、sandbox_envs=0、relations=0、handler_calls=0。临时 session 与进程均已收口。当前第四批仍 **40 / 50**，TOOL-031 未判绿，下一步是重建前端后的干净真实会话。
- Goal API 仍无 `blocked → active` 操作；不创建重复 Goal、不谎报完成，继续以本页、`LOOP.md`、`README.md` 和台架事实幂等推进。

## 2026-08-01 15:00 · TOOL-030 fixture 清理与 goal 恢复检查

- 按用户授权启动一次无 App 的清理台架 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-52`，只用于本地产品 API 清理，不作为验收 session；`RIG_APP=0` 导致 `rig-check` 的前端观察器项缺席是预期，不进入任何裁决。
- 通过真实 DELETE API 清理仍存活的 `acceptance_call_handler_fixture_51`。随后 GET 返回 `HANDLER_NOT_FOUND`；SQLite 对证主行 `deleted_at` 已写入、版本 1 行保留、sandbox 环境 0 行、关系边 0 行、三条 `handler_calls` 审计行保留，正式 handler `order_desk` 未受影响。
- 同步 DELETE 五个本轮专用 acceptance 对话。服务端语义为可恢复立碑：五个 `conversations.deleted_at` 均已写入，消息和五通道 session 证据未直接抹除；这是产品数据保留契约，不是清理失败。默认 `演示对话` 保留。
- `rig-down.sh` 已收台，进程组无残留。历史 screen/LLM/SSE/backend evidence 目录未删除，COVERAGE 裁决仍可复核。当前第四批仍为 **40 / 50**，下一前线 `TOOL-031 update_handler_config`。
- Goal API 仍只提供“标记完成/标记阻塞”，无法把既有 `blocked` 状态直接切回 active；未创建重复 goal，也未谎报完成。盘上 `LOOP.md` 仍为 active，按其协议继续执行。

## 2026-08-01 14:54 · 第四批 TOOL-030 call_handler 收尾

- 本切片的产品目的：证明 stateful handler 的常驻语义是用户可依赖的，而不是每次调用都隐式重建；同一方法连续调用必须保留状态，失败方法必须诚实落入调用审计且不被自动重试或伪装成成功。
- 最终 session `/private/tmp/anselm-rig-formal-20260801-51/sessions/20260801-144938` 由 conductor 托管真实 Flutter App、真实受管网关、Computer Use、连续窗口录像、Flutter console、三路 SSE witness 和 LLM tap。fixture `hd_3d0642336c9881b6` 只通过 REST 预先创建，版本 `hdv_5dc8f4027a7d323d`、环境 `hdenv_6173d28a1d4cc891` ready；方法 `bump` 递增 `self.count`，方法 `fail` 抛出刻意 `ValueError`。
- 真实 App 先只读搜索 handler，再按用户目的连续调用 `call_handler.bump` 两次，UI 结果 wrapper 明确为 `count: 1`、`count: 2`；随后只调用一次 `call_handler.fail`，UI 展示 ValueError 与失败日志，未执行 retry、edit、config、shell 或 REST。活动面显示 `Ran ×2 · Failed`，并明确 draft 未改变最后版本。
- REST 调用台账独立返回恰三行：同一 `instance_id` 的 bump success 两行与 fail failed 一行；SQLite 证明 handler 仍未删除、只有一个版本、环境仍 ready、meta 未变。失败 traceback 保留在调用审计，证明是业务失败而非前端吞错。
- 五通道收台：screen.mov H.264 `2784x1808 / 129.256667s / 60fps`；LLM 18/18 状态 HTTP 200、8 个 chat request body；SSE 三流各连接一次，messages/entities/notifications durable 分别 `1..46`、`1..2`、`1..5`，无 durable gap；frontend 无 FlutterError/DartError/RenderFlex/Unhandled/SEVERE；backend 无 panic/fatal/ERROR，仅一条刻意 `ValueError` 业务失败。
- 锚点重新盲测通过；五级裁决独立落账 `L1 G1`、`L2 F2`、`L3 A5`、`L4 C4`、`L5 G2`。三曲线开启后按 session 51 的完整五通道、终态截图和 REST/SQLite 账本复审并 ack，最终 `alarms.py check` 为 `clean (190 judgments on record)`。
- 第四批从 **35 / 50** 推进至 **40 / 50**；未到第四批 50 格，不运行统一长门禁、不提交。下一前线为 `TOOL-031 update_handler_config`。

## 2026-08-01 14:46 · 第四批 TOOL-029 delete_handler 收尾

- 本切片的产品目的：从真实 Chat 入口删除一个有两个版本、已准备环境的 stateful handler；删除后活动产品面应诚实消失，但不可变版本仍可审计，环境与关系清理要有可核对事实；不存在 ID 的失败不能伪装成成功或产生副作用。
- 前置真实会话 `/private/tmp/anselm-rig-formal-20260801-49/sessions/20260801-143154` 保留为红证据：旧二进制的正向 `delete_handler` 回执只有 `{"deleted":true,"id":"..."}`，模型只能把版本保留、环境清理和依赖上报当作工具文档推断，不能向用户提供直接回执。后端 SQLite/HTTP 仍证明 v1/v2 保留、活动主行软删、环境和关系行清理；该会话不用于判绿。
- 前线冻结后修复 `backend/internal/app/tool/handler/manage.go`：`delete_handler` 与 `delete_function` 对齐，回执加入 `retention.handler=soft_deleted`、`versions=retained_for_audit`、`sandbox=destroy_requested_best_effort`、`actions=not_found`，依赖存在时继续折入 `dependents/dependentCount/note`。`handler_test.go` 增加结构化回执守卫；`docs/references/backend/domains/handler.md` 与 `testend/rig/extracts/tools.md` 同步。此前已发现的前端错误动词也一并修复：失败卡片使用中英双语 `deleteFailedKind`，widget test 通过。
- 最终 session `/private/tmp/anselm-rig-formal-20260801-50/sessions/20260801-143835` 由 conductor 托管真实 Flutter App、真实受管网关、Computer Use、窗口录屏、Flutter console、三路 SSE tap 和 LLM tap；fixture `hd_ae18f91613773bad` 从 REST 先建 v1/v2，真实 App 正向只调用一次 `delete_handler`，画面展示 retention JSON、五行验证表和后续 `get_handler` not-found。SQLite 对证：主行有 `deleted_at`，v1/v2 保留且 env status ready，`sandbox_envs` 归属行 0、`relations` 归属行 0。
- 同一 session 的负路径经过产品危险人闸后只调用一次不存在 ID `hd_0000000000000000`；修复后的卡片是 `Delete handler failed · failed`，不是过去式成功标题，最终错误为 `handler not found`，报告确认实体、环境和关系均未改变。关键抽帧为 `evidence/tool-029-positive.png` 与 `evidence/tool-029-negative.png`，完整证据为 `evidence/tool-029-delete-handler-session-summary.txt`。
- 五通道收台：screen.mov H.264 `2784x1808 / 191.041667s / 60fps`；LLM 20/20 状态 HTTP 200、9 个 chat request body；SSE 三流各连接一次，messages/entities/notifications durable 分别 `1..51`、`1..4`、`1..12`，500 stream frames 无 durable gap；frontend 无 FlutterError/DartError/RenderFlex/Unhandled/SEVERE；backend 仅三条有因 WARN（删除后的读取、缺 handlerId 校验、刻意不存在 ID 删除）。
- 锚点重新盲测通过；五级裁决独立落账 `L1 G1`、`L2 F2`、`L3 A5`、`L4 C4`、`L5 G2`。三曲线开启 `gap-too-fast` 与 `discovery-collapse` 后，以完整五通道、正负抽帧和数据库证据复审并 ack，最终 `alarms.py check` 为 `clean (185 judgments on record)`。
- 第四批从 **30 / 50** 推进至 **35 / 50**；未到第四批 50 格，不运行统一长门禁、不提交。下一前线为 `TOOL-030`。

## 2026-08-01 13:35 · 第四批 TOOL-028 revert_handler 收尾

- 本切片的产品目的：把真实 stateful handler 从 active v2 回退到历史 v1，确认 v2 不被删除、resident 按 v1 重启且运行，另以 version 999 证明不存在版本拒绝不会改指针、铸版本或重启。
- session 42 `/private/tmp/anselm-rig-formal-20260801-42/sessions/20260801-131010` 首轮前置 edit 暴露 `op:"updateMethod"` + `methodName`；session 43 `/private/tmp/anselm-rig-formal-20260801-43/sessions/20260801-131437` 暴露 `kind:"set_method"`；session 44 `/private/tmp/anselm-rig-formal-20260801-44/sessions/20260801-131916` 暴露 `set_method_description`。三者均保留为红证据，未把“最终通过但中间失败/重试”判绿。
- 为已观测的前置模型形状补齐窄归一化和守卫测试：`build.go` 只接受 `updateMethod`、`method/methodName` 及完整 `kind:set_method` + 有限 MethodSpec 字段的确定性 alias，未知字段、空 patch 和近似拼写仍拒绝；`handler.md` 同步公开 canonical 形状与兼容边界。
- session 45 `/private/tmp/anselm-rig-formal-20260801-45/sessions/20260801-132148` 将 edit 前置问题隔离后，真实回退路径暴露 hosted model 发 `version:"1"`，严格 int 解码失败并发生一次模型重试。收台后修复 `manage.go`：公开 schema 不变，专用 decoder 接受 exact integer/string integer，拒绝小数、数组、布尔、文字和非正数；`handler_test.go` 补齐边界测试。
- 最终 session `/private/tmp/anselm-rig-formal-20260801-46/sessions/20260801-132558` 使用真实 HTTP canonical edit 端点构造 fixture：handler `hd_0500bfd2001381c0` 从 v1 建 v2 `hdv_9da340ed531c4f14`，`place` 描述为 `Revert fixture v2`，active v2/env ready；REST、SQLite、entities/notifications SSE 与 App 初态一致。
- 主路径在真实 App 中按名称找到 handler，实际只执行一次回退到 v1，再只读一次核验。UI 显示 `Reverted handler ... · ↩ v1`，表格/总结给出 active `hdv_1451ab39abfb137a`、version 1、v2 历史保留、env ready、runtime running、resident restarted yes；v1 的 place 不再有 v2 描述。录屏抽帧 `evidence/revert-handler-success.jpg`。
- 负路径在同一真实对话的新 user turn 中只执行一次 version 999；backend 原文和 UI 均为 `handler version not found`，无 retry/read/edit/restart。报告列出 active v1、无指针切换、无新版本、无重启；SQLite 最终只有 v1/v2、active 仍为 v1。录屏抽帧 `evidence/revert-handler-negative.jpg`。
- 五通道收台事实：screen.mov H.264 `2784x1808 / 258.636667s`；LLM 所有状态记录 HTTP 200；SSE messages 1208 帧/durable `1..91`、entities 5 帧/durable `7..8`、notifications 8 帧/durable `16..21`，三流各连接一次且无 gap；frontend 无 FlutterError/RenderFlex/DartError/Unhandled/Exception/AXTree；backend 仅一条有因的 version-not-found WARN。
- 产品审查：主路径报告的表格、版本 ID、环境/运行态和重启事实层级清楚；负路径红卡与下面的中文负向报告配对，明确“失败是正确结果”，没有把拒绝伪装成成功。连续录像中可见三张无副作用的 Bash echo 计划卡片，这是模型冗余动作而非业务错误，已记录但不阻断本格回退真相；后续 judge 仍以实际工具调用、五通道和产品结果为准。
- 锚点校准通过后，五级裁决独立落账：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。每次裁决后的 `gap-too-fast` 与 `discovery-collapse` 均使用对应成功/负路径证据复审并 ack，最终 `alarms.py check` 为 `clean (180 judgments on record)`。
- 第四批从 **25 / 50** 推进至 **30 / 50**；未到第四批 50 格，不运行统一长门禁、不提交。下一前线为 `TOOL-029 delete_handler`。

## 2026-08-01 13:07 · 第四批 TOOL-027 edit_handler 收尾

- 本切片的产品目的：在真实 App 中找到播种的 stateful handler `order_desk`，只通过一次 `edit_handler` 更新既有 `place` 方法的描述，确认新版本生效、resident 重启、环境健康，并用不存在 method 的负路径确认拒绝无副作用。
- 前两次固定台架会话 `/private/tmp/anselm-rig-formal-20260801-39/sessions/20260801-124803` 与 `/private/tmp/anselm-rig-formal-40/sessions/20260801-125520` 保留为红证据，分别暴露托管模型发送 `methodName`，以及发送 `method` 加顶层 `description`。两者都没有判绿；前线冻结。
- 直接修复 `backend/internal/app/tool/handler/build.go`：公开 `edit_handler` 描述和参数 schema 明确规范 `{op:"update_method",name,patch}`；执行边界仅对已知 hosted-model alias (`method`/`methodName` + 顶层 method fields) 做确定性归一化，未知字段、空 method、无 patch 和错误类型仍拒绝。补 `handler_test.go` 的规范形状、alias 修复、未知/畸形形状拒绝测试，并同步 `docs/references/backend/domains/handler.md`。
- 修复后二进制真实会话 `/private/tmp/anselm-rig-formal-20260801-41/sessions/20260801-125948` 由同一 conductor 托管真实 Flutter App、受管网关、Computer Use、连续窗口录像、Flutter console、三路 SSE witness 和 LLM tap；证据摘要为 `evidence/tool-027-edit-handler-session-summary.txt`。
- 成功路径只调用一次 `edit_handler`，wire 目标为 `hd_433206676aad6bc0`，单一 update op 更新 `place` 描述。UI 报告 version 2 from version 1、env ready、runtime running from stopped、restarted yes；SQLite 证明 active `hdv_9d072606077924bf`，恰有 v1/v2，v2 描述准确，未混入其它 op。
- 负路径只调用一次 `edit_handler`，目标 `does_not_exist`；backend 原文为 `invalid build op (op=update_method; reason=update_method: method "does_not_exist" not found)`，UI 报告 failed 且 truth remains last version；SQLite 仍只有 v1/v2、active 仍是 v2、无 v3。两张关键画面分别为 `evidence/edit-handler-success.png` 与 `evidence/edit-handler-rejected-missing-method.png`。
- 五通道收台事实：screen.mov H.264 `2784x1808 / 160.443333s`；LLM tap 26 个状态全 HTTP 200；SSE journal 记录 messages 648 帧/durable `1..57`、entities 5 帧/durable `7..8`、notifications 9 帧/durable `16..22`，三流无 durable gap；frontend 无 FlutterError/RenderFlex/DartError/Unhandled/Exception/AXTree；backend 只有刻意负路径 WARN，无 panic/fatal。
- targeted handler tests 通过：`mise exec -C backend -- go test -count=1 ./internal/app/tool/handler/... ./internal/app/handler/...`。录屏、LLM body/response、SSE、后端、前端和 SQLite 证据均保留；完整证据摘要已写入 session 目录。
- 锚点校准通过后，五级裁决独立落账：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。每次裁决后的 `gap-too-fast` 与 `discovery-collapse` 均按本次五通道证据复审并 ack，最终 `alarms.py check` 为 `clean (175 judgments on record)`。
- 第四批从 **20 / 50** 推进至 **25 / 50**；未到第四批 50 格，不运行统一长门禁、不提交。下一前线为 `TOOL-028 revert_handler`。

## 2026-08-01 12:05 · 第四批 TOOL-025 get_handler 收尾

- 固定真实会话 `/private/tmp/anselm-rig-formal-20260801-32/sessions/20260801-115554` 由同一 conductor
  托管真实 Flutter App、受管网关、Computer Use、连续录像、Flutter console、三路 SSE witness 与 LLM tap；
  证据摘要为 `evidence/tool-025-get-handler-session-summary.txt`。
- 正常用户目的路径先用 `search_handler` 搜索 `order desk`，得到 `hd_fff4fb4ab53677f3`，再只调用一次 `get_handler`。
  UI 显示 `Viewed handler order_desk · v1`，完整详情含 ID/name/description/tags/activeVersionId/时间、v1 的 place 与
  cancel 方法、空 inputs、streaming=false、`return {"ok": True}` 方法体、init args schema=null、configState=ready、
  runtimeState=stopped；解释说明首次调用会自动启动常驻实例。
- 负向路径只调用 `get_handler(hd_0000000000000000)` 一次，工具卡片和正文均为 `handler not found`，没有 retry。
  另有一条刻意受限的名称误作 ID 红反证：第一次 `get_handler(order_desk)` 失败后模型搜索到了真实 ID，但该路径不作绿证据；
  正常用户旅程已证明名称发现→ID详情链自然可走，不需要代码修复。
- 五通道收台事实：`screen.mov` 为 H.264 `2880x1800 / 302.100000s` 且 ffprobe 可读；frontend.log 无
  `Unhandled exception`、`FlutterError`、`Lost connection to device` 或未解释 Error；backend 只有两条有因的 not-found WARN，无
  panic/FATAL/未解释 ERROR；LLM tap 11 个 chat-completion request body、11 个 response body，22 个 status 观察全 HTTP 200；
  sse journal 744 条，三流各连接一次且 0 gaps，messages durable `1..61`、notifications `16..19` 单调，entities 已连接且无读操作 durable 变更。
- SQLite 与 wire 对账：handler 主行 `hd_fff4fb4ab53677f3` 与 active version `hdv_5fcf68c48ffdc95d` 与详情一致；正常回合
  的 search→get 参数和 full JSON 结果一致，负向回合参数为 `hd_0000000000000000`、结果为 `handler not found`；所有消息 completed，
  没有 handler/version 写入。
- 产品审查结论：详情页的基本信息、方法代码块、状态表和错误卡片均逐帧检查，层级、滚动和错误边界清晰；新用户可以从名称自然
  搜索到完整详情，本切片无功能、真相、交互、文案或视觉缺陷。
- 五级裁决已独立落账：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；每次裁决后的两项统计警报均以完整录屏、正常/红反证、
  SQLite、SSE、LLM 与后端日志复审并 ack。最终 `alarms.py check` 为 `clean (165 judgments on record)`。
- 第四批从 **10 / 50** 推进至 **15 / 50**；未到 50 格，不运行统一长门禁、不提交。下一前线为 `TOOL-026 create_handler`。

## 2026-08-01 11:55 · 第四批 TOOL-024 search_handler 收尾

- 固定真实会话 `/private/tmp/anselm-rig-formal-20260801-31/sessions/20260801-114544` 由同一 conductor
  托管真实 Flutter App、受管网关、Computer Use、连续录像、Flutter console、三路 SSE witness 与 LLM tap；
  证据摘要为 `evidence/tool-024-search-handler-session-summary.txt`。
- 使用 seed 的真实 handler `hd_553209acf70a2470 / order_desk / 订单台`，完成三条产品路径：名称 query `order` 命中
  1 条；不传 query 的空查询列出全部 1 条；随机 query `zzznonexistentacceptance` 返回 count 0、空列表且不重试。
  每条路径都只执行一次 `search_handler`；第一次按懒加载协议先出现一次 `search_tools`，之后的工具名、参数和结果均为
  canonical wire。UI 分别呈现 `Searched handler · 1 found`、`Listed handler · 1 found` 和明确 `no matches` 空态。
- 五通道收台事实：`screen.mov` 为 H.264 `2880x1800 / 264.113333s` 且 ffprobe 可读；frontend.log 无
  `Unhandled exception`、`FlutterError`、`Lost connection to device` 或未解释 Error；backend 无 WARN/ERROR/panic/FATAL；
  LLM tap 记录 8 个 chat-completion request body、8 个 response body，16 个 status 观察全为 HTTP 200；sse journal 265 条，
  三流各连接一次且 0 gaps，messages durable `1..48`、notifications `16..17` 单调，entities 已连接但无读操作 durable 变更。
- SQLite 与 wire 对账：三条 user/assistant 回合均 `completed`；message_blocks 中三次 `search_handler` 参数分别为
  `{"query":"order"}`、`{}`、`{"query":"zzznonexistentacceptance"}`，工具结果分别为 count 1、count 1、count 0；
  handler 主行仍为 seed 数据，读工具没有制造 handler mutation 或 handler-call 审计行。
- 产品审查结论：用户能从自然语言入口发现 lazy tool，成功结果字段完整，空查询与 no-match 都可解释且没有悬挂 composer；
  命中、全列出、无命中三张画面逐帧检查未发现功能、真相、交互、文案或视觉缺陷，本切片无需代码修复。
- 五级裁决已独立落账：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；每次裁决后的 `gap-too-fast` 与
  `discovery-collapse` 均用完整录屏、三态截图、SQLite、SSE、LLM 与后端日志复审并 ack。最终 `alarms.py check` 为
  `clean (160 judgments on record)`。
- 第四批从 **5 / 50** 推进至 **10 / 50**；未到 50 格，不运行统一长门禁、不提交。下一前线为 `TOOL-025 get_handler`。

## 2026-08-01 11:43 · 第四批 TOOL-023 get_function_execution 收尾

- 固定真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-113505` 由同一 conductor
  托管真实 Flutter App、受管网关、Computer Use、连续录像、Flutter console、三路 SSE witness 与 LLM tap；
  证据摘要为 `evidence/tool-023-get-function-execution-session-summary.txt`。
- 成功路径只调用 `get_function_execution` 一次，真实取回 `fne_6f78754411a72538` 的完整执行记录：function/version、
  status、triggeredBy、input/output、error、logs、elapsedMs、startedAt/endedAt、conversation/message/toolCall 等字段
  与 SQLite、UI、LLM wire 互证一致。失败路径只调用 `fne_0000000000000000` 一次，UI 明确显示 `function execution not found`、
  请求 ID 与 “No retry performed.”，SQLite 无该行，无重试和副作用。截图分别为
  `evidence/get-function-execution-success.jpg` 与 `evidence/get-function-execution-not-found.jpg`。
- 五通道收台事实：`screen.mov` 为 H.264 `2880x1800 / 159.710000s` 且 ffprobe 可读；frontend.log 无
  `Unhandled exception`、`FlutterError`、`Lost connection to device`；backend 仅一条刻意 not-found WARN，无 panic/FATAL/未解释
  ERROR；LLM 6 个请求体、7 个响应体及 14 个 status 记录全 HTTP 200；sse journal 共 370 条、6 次连接、0 gaps，
  messages durable `1..28`、notifications `1..4` 单调，entities 保持连接；真实 SQLite execution 行记录 `status=ok`、
  `elapsed_ms=61`，不存在 ID 查询计数为 0。
- 产品审查结论：成功详情层级完整、错误路径停止重试且没有孤儿 composer；逐帧检查未发现功能、真相、交互、文案或视觉缺陷，
  本切片无需代码修复。
- 五级裁决已独立落账：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；每次裁决后的 `gap-too-fast` 与
  `discovery-collapse` 均用完整录屏、成功/负向画面和五通道证据复审并 ack。最终 `alarms.py check` 为
  `clean (155 judgments on record)`。
- 第四批从 **0 / 50** 推进至 **5 / 50**；未到 50 格，不运行统一长门禁、不提交。下一前线为 `TOOL-024 search_handler`。

## 2026-08-01 10:45 · 第三批 TOOL-022 search_function_executions 收尾与 50/50 边界

- 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103528` 不用于判绿：分页查询中托管模型把 `limit` 发成 JSON 字符串，严格执行边界返回 bad-args；模型随后用数字重试并完成路径，但该真实误用按 H2 视为产品/工具契约反证，前线冻结。
- 直接修复 `backend/internal/app/tool/function/run.go`：`search_function_executions` 公开 schema 继续声明 integer，边界接受精确整数字符串以兼容真实托管模型，同时拒绝数组、小数和非数字字符串；描述和参数说明写清“优先 JSON integer、字符串仅作精确整数兼容”。`function_test.go` 增加描述、接受字符串和拒绝非整数测试；`gofmt` 与 function/tool targeted tests 通过。
- 固定会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103839` 由同一 conductor 托管真实 Flutter App、受管网关、Computer Use、连续录像、三路 SSE witness、Flutter console 与 LLM tap。真实覆盖：分页两页与 cursor 原样续接；`status=failed` 聚合和行；`versionId` 精确筛选；不存在 function 的干净 `No records` 空态；非法 `status=running` 的允许值错误态。证据图为 `evidence/search-executions-paging.png`、`search-executions-version-filter.png`、`search-executions-empty.png`、`search-executions-invalid-status.png`，完整摘要为 `evidence/tool-022-search-function-executions-session-summary.txt`。
- 五通道收台：screen.mov H.264 `2880x1800 / 420.495000s` 且 ffprobe 可读；backend 只有刻意 invalid-status WARN，无 panic/fatal/未解释 ERROR；frontend 只有已知 macOS IMK/foreground 噪声；LLM 15 个 chat-completion 状态响应全 200，修复后无 limit 解码 retry；messages durable `1..81`、notifications `1..8` 单调，entities 保持连接，sse journal 无 gap；rig-check 在收台前通过，收台无幸存进程。
- 裁决：`judge.py` 五格独立落账 `TOOL-022 search_function_executions`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。每次裁决后的 `gap-too-fast` 与 `discovery-collapse` 均用本次红/固定会话、录屏、五通道 journal 与截图复审并 ack，最终 `alarms.py check` 为 `clean (150 judgments)`。
- 第三批从 **45 / 50** 达到 **50 / 50**。按 P15 现在进入统一收台后的 `alarms.py check`、完整 `make verify`、完整 `go test ./...`、已修场景回归、完整 testend、工作树审计和提交；门禁完成前不进入 `TOOL-023`，不提交。

## 2026-08-01 11:09 · 第三批统一长门禁收口

- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check`：`clean (150 judgments on record)`；10 个锚点重新校准通过，四小时 judge 凭证有效。
- `make verify` 全绿：backend、frontend 四组 Flutter 测试、docs、demo 均通过；随后 `mise exec -C backend -- go test ./...` 全包通过。
- `make -C backend testend` 的完整黑盒 scenarios 通过（`280.955s`）；`cd testend && mise exec -- go test -count=1 -timeout 30m ./...` 全模块通过（scenarios `325.407s`，并覆盖 cmd/measure、cmd/ssetap、fixtures、golden、harness、proxycore）；已修 webhook 崩溃恢复专项通过（`11.167s`）。
- 收尾审计通过：docs lint 只有既有的 21 个非同名 DTO mirror 跳过提示；`git diff --check` 通过；testend 残留进程、`:8742`、`:8788` listener 均为空；`test_judge` 与 rig 脚本语法检查通过。
- 第三批统一长门禁已完成，当前只剩工作树最终审计和一次性提交；下一前线仍冻结在 `TOOL-023`，不在本批次记录中提前推进。

## 2026-08-01 11:15 · 第三批提交与第四批前线固定

- 最终工作树审计通过后，第三批以 `eb1ee050 test(acceptance): close third 50-cell gate` 一次提交；提交后 `git status --short` 为空，`:8742`、`:8788` 无 listener，testend 无残留进程。
- 第四批计数重置为 **0 / 50**，不重判已绿单格；下一前线从 COVERAGE 第一条未裁决项 `TOOL-023 get_function_execution` 开始。

## 2026-08-01 10:04 · 第三批 TOOL-020 update_function_meta 真实工具切片与 stop-and-fix

- 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-094939` 不用于判绿：正向路径中 Computer Use `type_text` 吞掉字面下划线，模型写出连字符而非用户要求的精确名称；负向路径中模型先把 `tags` 数组错序列化为字符串，收到后端拒绝后才重试。两项都是真实产品/AI 引导反证，前线冻结。
- 直接修复 `backend/internal/app/tool/function/lifecycle.go`：`update_function_meta` 的描述和参数 schema 增加完整 JSON 对象示例，明确 `tags` 必须是字符串数组，禁止逗号字符串；`function_test.go` 增加描述契约测试。另修复 `testend/rig/rig-up.sh`，每个 session 初始化 `evidence/` 目录，并同步 `testend/rig/README.md`，避免首次截图转换把证据目录写成普通文件。
- 修复后二进制会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-095616` 由真实 App、受管网关、Computer Use、Flutter console、连续录像、三路 SSE witness 与 LLM tap 托管。正向 fixture `fn_d197bf1543a1e7f4` 的 meta 精确更新为 `acceptance_meta_visual_retry_v3`、`Meta update patched schema fixture`、`[acceptance, meta, visual]`；`update_function_meta` 恰一次，v1、active version、代码、env 与 restart 均未改变。SQLite 与 HTTP 一致。
- 负向只传 name 给不存在的 `fn_0000000000000000`，工具激活后调用恰一次；UI 显示干净 `function not found`，无 function/version/sandbox 副作用。证据图为 `evidence/update-function-meta-fixed-hit.png` 与 `evidence/update-function-meta-fixed-failed.png`，完整摘要为 `evidence/tool-020-update-function-meta-session-summary.txt`。
- 五通道：screen.mov H.264 `2880x1800 / 268.930000s`；backend 只有一条刻意 not-found WARN，无 panic/fatal/ERROR；frontend 仅已知 macOS IMK/foreground 噪声；LLM 24 个响应全 200，修复 session 无 serialization retry；messages/notifications durable `1..73`、`1..5` 单调，entities 已连接；rig-check 在收台前通过，anchors 校准通过。
- 裁决：`judge.py` 五格独立落账 `TOOL-020 update_function_meta`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。每次裁决后的 `gap-too-fast` 与 `discovery-collapse` 均以本次正负画面、录屏、五通道 journal、SQLite/HTTP 结果复审并 ack，最终 `alarms.py check` 为 `clean (140 judgments)`。
- 第三批从 **35 / 50** 推进至 **40 / 50**；下一前线为 `TOOL-021`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE、LOOP 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 10:26 · 第三批 TOOL-021 run_function 真实工具切片与 stop-and-fix

- 首轮会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-100648` 暴露两项真实问题：不存在 ID 的提示因模型把零串写错而重复调用；显式版本被实际 wire 成 `"version":"2"`，后端严格 decoder 拒绝，模型随后省略版本重试。第二轮 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-101400` 在工具描述/schema 已明确 integer 后仍复现字符串化 `version`，同时 `args` 也被字符串化；两轮均只作红灯反证，不用于判绿。
- 前线冻结后修复 `backend/internal/app/tool/function/run.go`：公开 schema 仍声明 integer/object，执行边界接受与 attachment 工具一致的精确整数字符串和字符串化对象；数组、小数、非数字字符串仍拒绝。描述同步改为“优先数字，兼容精确整数字符串”，并补 `function_test.go` 的接受/拒绝形状测试。`gofmt` 与 `go test ./internal/app/function/... ./internal/app/tool/function/...` 通过。
- 固定会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-101832` 重新由同一 conductor 托管真实 App、受管网关、Computer Use、Flutter console、连续录像、三路 SSE witness 与 LLM tap。显式 v2 只发一次，wire 的字符串化 `args`/`version` 被边界正确解码，结果为 `MIXED CASE`，SQLite execution `fne_6f78754411a72538` 钉住 `fnv_e526b409693ea039`；不存在 `fn_deadbeefdeadbeef` 只发一次、干净返回 `function not found` 且无 execution；已有 echo function 缺 `text` 只发一次，`ok=false`、`failed`、TypeError 和 5 行日志真实呈现。
- 旧会话中一次 Computer Use 坐标误点到 Recents 而非 New chat，导致上下文污染；不用于绿证据。随后真正点击 `New chat`，重新获得独立的 not-found 与 execution-failed 终态画面，证据为 `evidence/run-function-explicit-v2.png`、`evidence/run-function-not-found-final.png`、`evidence/run-function-execution-failed-final.png`，完整摘要为 `evidence/tool-021-run-function-session-summary.txt`。
- 五通道：screen.mov H.264 `2880x1800 / 468.141667s`；backend 仅两条预期 not-found WARN，无 panic/error/fatal；frontend 仅已知 macOS IMK 噪声；LLM 15 个响应全 200，且 wire 留存了真实字符串化字段；messages/entities/notifications durable 分别 `1..75`、`1..4`、`1..6` 单调，三流持续连接；收台无幸存进程。
- 裁决：`judge.py` 五格独立落账 `TOOL-021 run_function`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。每次裁决后的 `gap-too-fast` 与 `discovery-collapse` 均以本 session 的正负画面、录屏、五通道 journal、SQLite/LLM wire 复审并 ack，最终 `alarms.py check` 为 `clean (145 judgments)`。
- 第三批从 **40 / 50** 推进至 **45 / 50**；下一前线为 `TOOL-022 search_function_executions`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE、LOOP 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 09:42 · 第三批 TOOL-019 delete_function 真实工具切片与 stop-and-fix

- 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-092832` 发现工具描述与持久化设计不一致：产品报告声称删除了全部 function 版本，但代码/数据库的设计是软删主行、不可变版本历史 append-only 保留供审计。该会话作为反证保留，不用于判绿；前线冻结。
- 直接修复 `backend/internal/app/tool/function/lifecycle.go`：描述和返回结构明确 `function=soft_deleted`、`versions=retained_for_audit`、`sandbox=destroy_requested_best_effort`、`actions=not_found`；补 `function_test.go`，并同步 `docs/references/backend/api.md`。工具摘要与 COVERAGE 原始提取物同步为 retention truth。
- 修复后会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-093503` 由同一 conductor 托管真实 App、受管网关、Computer Use、Flutter console、连续录像、三路 SSE witness 与 LLM tap。正向 disposable function 为 `fn_cd3e4c341e12871a`，v1 `fnv_975a0bc158414e28`，sandbox `fnenv_8e9272035daf5708`；删除调用恰一次，UI 准确展示软删、版本审计保留、sandbox 回收、动作 not-found。SQLite 证明 deleted_at 已写、版本行仍在、sandbox 行和目录已清；HTTP 证明主实体 404、versions 仍 200 可审计。
- 负向新会话路径只请求不存在的 `fn_0000000000000000`，`delete_function` 激活后调用恰一次；UI 显示干净的 `function not found`，无实体、sandbox 或其它写操作副作用。证据图为 `evidence/delete-function-fixed-hit.png` 与 `evidence/delete-function-fixed-failed.png`，完整摘要为 `evidence/tool-019-delete-function-session-summary.txt`。
- 五通道：screen.mov H.264 `2880x1800 / 466.838333s`；backend 仅两条预期 WARN（fixture 的错误 ops 重试、刻意 not-found），无 panic/fatal/ERROR；frontend 仅已知 macOS IMK/foreground 噪声；LLM 22 个状态响应全 200；messages/entities/notifications durable `1..64`、`1..4`、`1..9` 单调；rig-check 在收台前通过。
- 裁决：`judge.py` 五格独立落账 `TOOL-019 delete_function`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。每次裁决后的 `gap-too-fast` 与 `discovery-collapse` 均用本次正负画面、录屏、五通道 journal、SQLite/HTTP 结果复审并 ack，最终 `alarms.py check` 为 `clean (135 judgments)`。
- 第三批从 **30 / 50** 推进至 **35 / 50**；下一前线为 `TOOL-020 update_function_meta`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE、LOOP 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 09:25 · 第三批 TOOL-018 revert_function 真实工具切片与 stop-and-fix

- 正向真实会话从同一 `acceptance_create_visual_retry` 的 v2 回退到 v1。UI 展示 Previous v2、Target v1、Resulting v1、active version ID `fnv_16dc4e226e8e9007`、ready env 和恢复后的 echo code；v2 保留在 history，未产生 v3。
- 负向真实会话请求不存在的 v999。后端两次真实 `revert_function` 均明确返回 `function version not found`；模型随后调用只读 `get_function`，核验 active 仍为 v1、时间戳未变、无新版本且 active pointer 未修改。额外失败重试是模型工具编排事实，写入证据，不伪装成单次调用；它没有造成数据副作用。
- 五通道：会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-091433` 的 screen.mov H.264 `2880x1800 / 490.781667s`；backend 只有两条刻意 v999 失败 WARN，无 panic/fatal/ERROR；frontend 仅已知 macOS IMK/foreground 平台噪声；LLM 2 个 proof challenge 与 26 个 chat completion 状态全 200；messages durable `1..86`、notifications `1..5` 单调无 gap/regression，entities 保持连接。成功/失败原生画面证据为 `evidence/revert-function-hit.png` 与 `evidence/revert-function-failed.png`。
- SQLite 复核：`fn_d739a28d0bcdf21b` 的 active pointer 为 v1，history 恰有 v1/v2，无 v3；v1/v2 environment 均 ready。完整摘要为 `evidence/tool-018-revert-function-session-summary.txt`。
- 裁决：Go function service/tool 单测通过；`judge.py` 五格独立落账 `TOOL-018 revert_function`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。五次统计警报均以本 session 的正负截图、录屏、五通道 journal 和 SQLite 结论复审并 ack，最终 `alarms.py check` 为 `clean (130 judgments)`。
- 第三批从 **25 / 50** 推进至 **30 / 50**；下一前线为 `TOOL-019 delete_function`。未到 50 格不跑统一长门禁、不提交；本批证据、COVERAGE、LOOP 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 09:12 · 第三批 TOOL-017 edit_function 真实工具切片与 stop-and-fix

- 正向真实会话编辑既有 `acceptance_create_visual_retry`：从 v1 变更描述与代码为 v2，输入/输出、Python 3.12、无依赖保持不变；产品卡片展示 Previous 1、New 2、Version ID `fnv_e526b409693ea039`、env ready，Activity 显示 Edited。
- 负向同一实体提交 `this is not valid Python`。后端在版本构建前返回 `function code invalid (reason=code must declare at least one top-level def)`；失败卡片保留 edit 专属 `Draft unsaved · truth is still the last version`，随后模型额外调用只读 `get_function` 核验 v2，SQLite 证明无 v3、active 指针和 v2 代码不变。该额外只读调用按实际证据记录，不包装成纯 edit 单工具路径。
- 五通道：会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-090605` 的 screen.mov H.264 `2880x1800 / 206.015000s`；backend 只有一条刻意非法代码 WARN，无 panic/fatal/ERROR；frontend 仅已知 IMK 平台噪声；LLM 20 个状态响应全 200；messages/entities/notifications durable seq 分别 `1..67`、`1..6`、`1..7`，各自唯一且单调。证据图为 `evidence/edit-function-hit.png` 与 `evidence/edit-function-failed.png`。
- 裁决：anchors 校准通过；`judge.py` 五格独立落账 `TOOL-017 edit_function`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；五次统计警报均以本 session 证据复审并 ack，最终 `alarms.py check` 为 `clean (125 judgments)`。完整证据摘要：`evidence/tool-017-edit-function-session-summary.txt`。
- 第三批从 **20 / 50** 推进至 **25 / 50**；下一前线为 `TOOL-018 revert_function`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 09:01 · 第三批 TOOL-016 create_function 真实工具切片与 stop-and-fix

- 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-084640` 发现 create 失败路径复用了 edit 的诚实丝带文案 `Draft unsaved · truth is still the last version`；新建不存在“上一版”，这是产品事实错误。该会话不用于判绿，前线冻结。
- 直接修复：`frontend/lib/core/ui/an_honesty_ribbon.dart` 新增 `AnHonesty.failedCreate` 及中英文 `ribbonFailedCreate`；`frontend/lib/features/chat/ui/stage_panel.dart` 仅对 `create_*` 使用“尚未创建实体”，`edit_*` 继续使用“上一版”；`stages_w4_test.dart` 增加 create/edit 对称 widget 回归。`dart run slang` 生成成功，`flutter test test/features/chat/ui/stages_w4_test.dart` 全部 12 项通过。
- 修复后真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-085503` 由同一 conductor 托管真实 App、受管网关、Computer Use、Flutter console、录像、三路 SSE witness 与 LLM tap。正向调用五个 ops 创建 `acceptance_create_visual_retry` (`fn_d739a28d0bcdf21b`, v1, env ready)，展开卡片显示真实两行 Python 代码，Activity 显示 `1 touched / Created`；负向只给一个 `set_meta`，后端返回 `function code invalid (reason=code is required)`，Activity 显示 Failed，create ribbon 显示 `Draft unsaved · nothing was created`。
- 数据与五通道：SQLite 只有成功 function/version，失败名无 `functions`/`function_versions` 行；screen.mov H.264 `2880x1800 / 188.273333s`，证据图为 `evidence/create-function-hit.png` 与 `evidence/create-function-failed.png`；backend 只有一条刻意触发的业务 WARN，无 panic/fatal/ERROR；frontend 仅已知 IMK 平台噪声；LLM 18 个状态响应全 200；messages/entities/notifications durable seq 分别 `1..51`、`1..6`、`1..7`，各自唯一且单调。
- 裁决：anchors 校准通过；`judge.py` 五格独立落账 `TOOL-016 create_function`：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；五次统计警报均以本 session 证据复审并 ack，最终 `alarms.py check` 为 `clean (120 judgments)`。完整证据摘要：`evidence/tool-016-create-function-session-summary.txt`。
- 第三批从 **15 / 50** 推进至 **20 / 50**；下一前线为 `TOOL-017 edit_function`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 08:44 · 第三批 TOOL-015 get_function 真实工具切片与 stop-and-fix

- 首轮会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-083052` 真实覆盖了正向完整活跃版本和不存在 ID。发现 not-found 工具卡的错误行显示 `get_function: functionapp.Get: function not found`，把内部 Go 调用路径暴露给用户；该会话和其截图全部标为反证，不用于判绿。
- 前线冻结后直接修复 `backend/internal/app/loop/tools.go`：ValidateInput 与 Execute 失败的 `errMsg` 统一走 `llmErrText`，保留操作日志的结构化信息但不把 Go wrapper 路径写进持久化 tool-result；新增 `TestExecuteTool_UserErrorMessageIsClean`，`mise exec -C backend -- go test ./internal/app/loop` 通过。
- 修复后会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-083704` 重新由 conductor 启动真实 App、受管网关、Flutter console、连续录像、三路 SSE witness 与 LLM tap。正向真实呈现代码、输入/输出、空依赖、Python 3.12、环境 ID、ready、同步时间和版本更新时间；负向真实调用 `fn_0000000000000000`，错误卡片只显示 `function not found`，且明确没有副作用。
- 五通道：`screen.mov` H.264 2880x1800、`189.096667s` 可读；backend 无 panic/fatal/ERROR，仅有一条预期的 not-found 业务 WARN；frontend 仅已知 `IMKCFRunLoopWakeUpReliable` 平台噪声；LLM 18 个状态响应全 200；SSE 三路各连接一次，messages durable `1..43`、notifications `1..4` 单调，entities 连接正常但本切片无 durable 事件。
- 证据：`evidence/get-function-hit.png`、`evidence/get-function-not-found.png`、`evidence/tool-015-get-function-session-summary.txt`。anchors 复核通过；`judge.py` 独立落账 `TOOL-015 get_function` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。统计警报均以复审结论 ack，最终 `alarms.py check` 为 `clean (115 judgments)`。
- 第三批从 **10 / 50** 推进至 **15 / 50**；下一前线为 `TOOL-016 create_function`。未到 50 格不跑统一长门禁、不提交；本批代码、测试、COVERAGE 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 · Day 0 收口

- 前线：Day 0 完成；下一步从 COVERAGE 第一条未裁决格开始一期主循环。
- 基线：`main@b47fe0cb`；清册 848 行、4240 格；47 条旅程只作一期路线，400+ 扩写推迟二期。
- 台架：真实 App + Flutter console + 屏幕录像 + sidecar + 动态全 workspace SSE + LLM wire 全由
  conductor 托管；全新数据完成 onboarding、受管开通与五通道自检，收台后无幸存进程。
- 证据：隔离冒烟 session `/tmp/anselm-rig-smoke-2/sessions/`；最终会话 MOV 78.02s、ffprobe 可读；
  challenge/install/models 均穿 llmtap 返回 200，三路 SSE 均建立连接。
- 台架修复：动态 workspace 接管、detached 进程组、Flutter console 入 manifest、录像正确封口、
  WebSocket Hijacker 透明转发、measure ROI、L2 五通道物理门禁、警报 ack 水位、锚点四小时解锁。
- 产品发现：受管额度面直接显示原始十亿整数与 ISO reset 时间，已纳入锚点 A05；主循环到设置面
  时按 stop-and-fix 修复，不在 Day 0 台架施工中夹带产品改动。
- 配置：持久 Goal 已创建并保持 active；Loop 执行协议见 [`LOOP.md`](LOOP.md)。本日志记录的是
  Day 0 收口和配置完成，第一次正式唤醒前不宣称任何产品覆盖格已完成。
- 批次策略：按用户 P15，首批为 `0 / 50` 个 COVERAGE 单格裁决；单格证据与 stop-and-fix 不变，
  第 50 格后统一运行长门禁、完整 testend、警报复核和 git commit。

## 2026-08-01 · Goal/Loop 配置恢复

- 持久 Goal 经系统核对仍为 `active`；本次没有创建第二个 Goal，避免双前线和重复施工。
- Loop 协议经系统核对仍为 `active`，已幂等重新装载；50 格批次门禁、逐格 stop-and-fix 和不降标准规则保持不变。
- 当前批次计数保持 `35 / 50`，下一前线保持 `SURF-014 chat/log-drawer`；本次只恢复配置，不推进 App 操作或 COVERAGE 裁决。

## 2026-08-01 · 首个产品切片发现与修复进行中

- 首轮真实 App + 受管网关会话发现：主聊天回复完整落库，但 auto-title 请求在 10 秒预算内只收到
  `reasoning_content`，没有正文，故对话 REST 保持 `title:""/autoTitled:false`，UI 永远显示 `New chat`。
- 五通道证据：请求体 `/tmp/anselm-rig-formal-20260801-2/sessions/20260801-011544/llm-bodies/00005_v1_chat_completions.bin`；
  真实响应 `/tmp/anselm-rig-formal-20260801-2/sessions/20260801-011544/llm-responses/00005_v1_chat_completions.bin`；
  SSE durable seq 1–8 与 UI/REST 均证明主回合完成，响应体尾部证明标题预算到期时仍在 thinking。
- 前线冻结：已直接改 `backend/internal/app/chat/autotitle.go`，utility 标题失败、超时、无正文或未配置时
  回落到首条用户请求的本地可读标题；新增 reasoning-only 守卫测试。待单测、编译和新台架逐帧复验后，
  才允许继续本切片或写 COVERAGE 裁决。

## 2026-08-01 · 首个产品切片复验完成

- 新台架会话：`/tmp/anselm-rig-formal-20260801-3/sessions/20260801-012108`；真实 App、真实受管网关、
  Computer Use 录像和五通道均已收台封存，`screen.mov` 128.975s 且 ffprobe 可读。
- 修复复验：utility 真实响应再次只有 reasoning；后端记录 `using local fallback`，首条用户请求生成标题。
  UI、SQLite、REST、notifications SSE 的标题一致；主助手回复和三路 SSE durable close 均完成。
- 逐帧结果：抽查 onboarding、Shell 过渡、流式中间态、完成态；未发现已有内容漂移、composer 被遮挡、
  视口抢夺、骨架闪现或完成后仍停留 `New chat`。前端仅有已分类的 macOS runner/platform 噪声，无 Dart/Flutter
  异常；后端无未解释 WARN/ERROR/panic/fatal。
- 本切片已通过 `judge.py` 独立登记 `EDGE-325 空工作区名册`、`EDGE-326 首启创建过渡`、`SURF-003
  shell/workspace-onboarding`、`SURF-010 chat/landing`、`SURF-011 chat/transcript` 各五格；每格均有
  独立法条与证据指针。`SURF-012 chat/composer` 尚未因未走过附件、mention、工作目录、git 和流式输入而裁决。
  证据目录：`/tmp/anselm-rig-formal-20260801-3/evidence/`；裁决 journal：
  `/tmp/anselm-rig-formal-20260801-3/judgments.jsonl`。
- 批次前线：`25 / 50`；尚未运行长门禁、完整 testend、警报复核或提交，继续留在同一批次。

## 2026-08-01 · composer 模态焦点缺陷修复与真实复验

- 缺陷：真实会话 `/tmp/anselm-rig-formal-20260801-4/sessions/20260801-013602` 中，从驻地菜单打开「新建分支」后，
  对话框没有取得键盘焦点；直接输入的 `acceptance-ui-probe` 落进了背后的 composer。前线冻结，未判 composer 或 git 格。
- 根因：`AnMenu` 在 action 前关闭 `AnPopover`，而 popover 退场动画结束时才把焦点归还原触发器，后者覆盖了新模态的
  初始焦点；命名模态单靠 `autofocus` 也不足以对抗 `RawDialogRoute` scope 时序。
- 修复：`AnPopoverController.closeAndWait()` 以退场动画和焦点归还为完成边界；普通 `AnMenuItem` 先跨过该边界再执行
  action，`keepOpen` 保持原语义；`anPanelRoute` 不再先抢内容字段焦点；`ChatGitNameDialog` 持有自己的 `FocusNode` 并在首帧后显式请求。
- 守卫：`chat_work_dir_button_test.dart` 增加「打开命名模态后 EditableText 必须 hasFocus 且输入落入该 controller」断言；
  `flutter test` 运行 `chat_work_dir_button_test.dart`、`an_menu_test.dart`、`an_dialog_test.dart`，48 项全绿。
- 真实复验：新会话 `/tmp/anselm-rig-formal-20260801-4/sessions/20260801-015325` 重新启动真实 App；Computer Use 直接输入
  `acceptance-ui-probe` 后 AX 明确报告 focused element 为模态 text field，截图显示光标与文本均在字段内；点击 Cancel 后 composer 未被污染。
  证据：`/tmp/anselm-rig-formal-20260801-4/evidence/git-dialog-focus-fixed.png`、`git-dialog-focus-fixed-ax.txt`、
  `git-dialog-focus-fixed.txt`。
- 通道：后端无 WARN/ERROR/panic/fatal；SSE 与 conductor 均存活；Flutter journal 仅保留 macOS runner/IMK 与
  accessibility bridge 平台噪声，未发现 Dart exception。该噪声继续作为前端台架观察项，不拿它冒充产品绿灯。
- 批次前线：仍为 `25 / 50`；本修复未新增 COVERAGE 裁决，继续沿 `SURF-012` 完整切片推进。

## 2026-08-01 · composer 完整切片收尾与 mention 真实复验

- 新台架会话：`/tmp/anselm-rig-formal-20260801-4/sessions/20260801-015325`；由同一 conductor 托管真实 App、
  Flutter console、屏幕录像、后端、动态全 workspace SSE tap 与 LLM tap；收台后 `screen.mov` 已封口，
  `ffprobe` 时长 `1201.320000s`，五通道 journal 均存在。
- 附件路径：从 composer 附件菜单进入原生文件选择器，选取 `anselm-acceptance-attachment.txt`，看到 `TXT · 91 B`
  预览 chip，发送后助手准确回读文件名和原句；附件完成态截图/AX 证据在
  `/tmp/anselm-rig-formal-20260801-4/evidence/composer-attachment-final.*`。
- mention 路径：先用后端创建最小 function fixture `mention-fixture-fn`，再从 composer 输入 `@mention`；候选面板正确出现，
  选择后变成蓝色 `@mention-fixture-fn` 药丸，发送后 messages SSE 写入用户消息和 `mentioned` touchpoint，LLM wire
  收到函数摘要，助手随后通过 `get_function` 回读并正确回答。候选/完成态证据在
  `/tmp/anselm-rig-formal-20260801-4/evidence/composer-mention-{candidate,final}.*`。
- 工作目录与 git 路径：隔离临时仓库中真实创建并切换分支，菜单显示仓库路径、分支和 clean 状态；随后在同一会话发送
  `pwd` 核验请求，助手返回 `/private/tmp/anselm-acceptance-git-fixture`，证明驻地状态、git 动作和聊天上下文连续。
- 数据核对：SSE durable seq 单调，`function.created`、`mentioned` touchpoint、`get_function` tool call/result、
  assistant close 均在 journal；后端无未解释 WARN/ERROR/panic/fatal。Flutter journal 有 1091 条 macOS
  `accessibility_bridge` AXTree 平台红行及一条 foreground/IMK 平台行，没有 Dart/Flutter framework exception；该噪声
  明确留作台架观察项，本轮 `SURF-012` L2 只援引 F2，不用 F3 冒充 console 零红行。
- `judge.py` 已独立落账 `SURF-012 chat/composer` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；
  批次从 `25 / 50` 推进到 **30 / 50**。下一前线为 `SURF-013 chat/toc`，未到 50 格不跑批次长门禁、不提交。

## 2026-08-01 · chat/toc 全量 keyset 分页与深跳复验

- 新台架会话：`/tmp/anselm-rig-formal-20260801-5/sessions/20260801-021909`；真实 App、受管网关、Computer Use
  录屏、后端、三路 SSE tap、LLM tap 均由同一 conductor 托管，收台后 `screen.mov` 封口时长 `937.505s`。
- 构造数据：通过真实 composer 逐轮发送 `TOC fixture turn 001` 至 `turn 051`，每轮重新读取 AX、等待助手终态再发下一轮；首轮
  误触发 `ask_user`，在 UI 内回答后正常收尾。后端 `GET /anchors?limit=50` 返回第一页 50 条 `hasMore=true`，续页 2 条
  `hasMore=false`；场次条 AX 全量包含最新 `turn 051`、最早 `turn 001` 与折叠的 10 operations 行，证明 provider 循环拉完
  keyset 页而非停在第一文页。
- 逐帧路径：打开 Scenes 后场次条呈 newest-first 时间线；点击最早 `turn 001` 整扇替换 transcript 窗并显示 `Jump to present`；
  点击中段 `turn 027` 同样以目标为中心深跳；点击回到现场恢复最新 `turn 051`，未出现历史拼接、视口抢夺或假终态。
- 五通道：SSE journal 2550 行且三流均有 connect；LLM journal 192 行、128 个状态记录全为 200；后端无 panic/FATAL/WARN/ERROR；
  Flutter journal 只有 macOS foreground/IMK 平台行，无 Dart/Flutter framework exception。完整证据在
  `/tmp/anselm-rig-formal-20260801-5/evidence/`，包括 `toc-full-list.png`、`toc-mid-jump.png`、`toc-jump-present.png`、
  对应 AX 文本和 session summary。
- `judge.py` 已独立落账 `SURF-013 chat/toc` 五格：L1 `G1`、L2 `F2`、L3 `B2`、L4 `C4`、L5 `G2`；批次从 `30 / 50`
  推进到 **35 / 50**。下一前线为 `SURF-014 chat/log-drawer`，未到 50 格不跑批次长门禁、不提交。

## 2026-08-01 · SURF-014 日志抽屉 stop-and-fix 与真实复验

- 前置冻结：旧会话 `/tmp/anselm-rig-formal-20260801-7/sessions/20260801-024012` 在长失败日志展开/滚动时出现重复的
  `accessibility_bridge.cc` AXTree 红行；同时红色失败摘要被中间日志行占满，用户看不到尾部的真实 traceback。该格未判绿。
- 修复：`frontend/lib/features/chat/ui/tool_card_exec.dart` 将 `ExecutionResult.errorMsg` 与 tool-result 独立 `error` 字段
  合并到同一条 20 行 head+tail 摘要路径；`frontend/lib/features/chat/ui/tool_card_catalog.dart` 将 `run_function`
  标为 `ownsError`，底盘不再重复追加无界原文；`frontend/test/features/chat/ui/tool_card_exec_test.dart` 新增硬错误单次呈现
  与长失败尾部保留守卫。目标 Flutter widget suite 21 项全绿，`git diff --check` 全绿。
- 修复后真实会话：`/tmp/anselm-rig-formal-20260801-8/sessions/20260801-030652` 由 conductor 托管真实 App、受管网关、
  Computer Use、屏幕录制、后端、三路 SSE tap 和 LLM tap；真实完成成功函数日志、长失败函数日志、MCP 失败 dossier、stderr
  抽屉展开和 Copy→Copied。画面证据在 `/tmp/anselm-rig-formal-20260801-8/evidence/`，包含四组 PNG/AX 文本及
  `surf-014-session-summary.txt`。
- 五通道收台结果：`frontend.log` 无 Flutter/Dart/AXTree/RenderFlex 错误；`backend.log` 无 WARN/ERROR/panic/FATAL；LLM
  journal 42 条记录中的 28 个 HTTP 响应全为 200；entities/messages/notifications 三流分别记录 8/66/11 个 durable 帧，
  各流序列单调、无回退；`screen.mov` 时长 `469.55s`，六件 L2 journal 均真实存在且可读。
- `judge.py` 已独立落账 `SURF-014 chat/log-drawer` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；批次从 `35 / 50`
  推进到 **40 / 50**。下一格从 COVERAGE 当前首个未裁决项读取；未到 50 格不跑批次长门禁、不提交。

## 2026-08-01 · TOOL-001 Read 真实工具切片

- 新台架会话：`/tmp/anselm-rig-formal-20260801-9/sessions/20260801-032022`；真实 App、受管网关、Computer Use、屏幕录像、
  后端、三路 SSE tap 和 LLM tap 由同一 conductor 托管。
- 构造数据：在真实 workspace 驻地 `/tmp/anselm-read-fixture-9` 创建 notes.txt、paged.txt、嵌套文件和干扰文件；真实对话中
  调用 Read 默认整读与 `offset=2 limit=2`，画面准确展示四行编号、分页行 `2–3+` 和截断语义；随后验证不存在文件的人话错误，以及
  `/etc/hosts` 越界请求被安全 guard 拒绝并在 UI 呈现原因。
- 五通道收台：`frontend.log` 无 Flutter/Dart/AXTree/RenderFlex 错误；`backend.log` 无 WARN/ERROR/panic/FATAL；LLM journal
  27 条记录中的 18 个 HTTP 响应全为 200；notifications/messages/entities 均连接，观察到 durable 2/46/0 帧，所有观察到的
  stream seq 单调无回退；`screen.mov` 时长 `203.135s`。证据在 `/tmp/anselm-rig-formal-20260801-9/evidence/`，包括
  `read-tool-final.png`、AX 文本和 `tool-001-read-session-summary.txt`。
- `judge.py` 已独立落账 `TOOL-001 Read` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；批次从 `40 / 50` 推进到 **45 / 50**。
  下一前线为 `TOOL-002 Write`；未到 50 格不跑批次长门禁、不提交。

## 2026-08-01 · TOOL-002 Write 真实工具切片与 stop-and-fix

- 新台架会话：`/tmp/anselm-rig-formal-20260801-12/sessions/20260801-033935`；真实 App、受管网关、Computer Use、屏幕录像、
  后端、三路 SSE tap 和 LLM tap 由同一 conductor 托管，收台后 `screen.mov` 时长 `220.8s`，六件 L2 journal 均真实存在且可读。
- 构造数据：驻地 `/tmp/anselm-write-fixture-12` 中的 `existing.txt` 预置为 `ORIGINAL_CONTENT`。真实请求要求只调用一次 Write
  覆盖而不先 Read；SSE/持久事实确认实际只有 1 次 Write、0 次 Read，后端安全闸拒绝覆盖，磁盘内容保持不变。
- 首轮真实缺陷：后端按契约以 `tool_result status=completed + refusal string` 返回安全拒绝；前端虽已有红色 `fsErrorReceipt`，但主行仍
  渲染成功动词 `Wrote existing.txt · read first`，造成“红色拒绝旁的假成功语义”。前线冻结，未把首轮当成产品通过。
- 修复：`ToolCardSpec` 增加失败动词通道；文件系统拒绝由 `fsErrorKind` 触发 `resultFailed` 重分类；`ChatToolCard` 对 payload failure
  使用 `failedVerb`，因此画面改为 `Write failed existing.txt · read first`。新增 completed-refusal widget 守卫；Flutter 正确测试链
  `tool_card_write_test.dart`、`chat_tool_card_test.dart`、`tool_card_family_test.dart` 共 23 项全绿，`dart format` 通过。
- 修复后逐帧复验：证据 `/tmp/anselm-rig-formal-20260801-12/evidence/write-refusal-fixed.png`、AX 文本和
  `tool-002-write-session-summary.txt`；画面没有 `Wrote`，拒绝散文清楚可见；SSE 各流 durable seq 单调（notifications 1–2、
  messages 1–14），LLM tap 状态全 200，backend/frontend 无 WARN/ERROR/panic/FlutterError/RenderFlex/Unhandled Exception。
- `judge.py` 已独立落账 `TOOL-002 Write` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；批次从 `45 / 50` 推进到 **50 / 50**。
  按 P15 现在进入统一 `alarms.py check`、完整门禁、完整 testend、修复场景回归、工作树审计和提交；门禁未完成前不提交。

## 2026-08-01 · 首批长门禁 stop-and-fix

- 批次达到 `50 / 50` 后先运行 `alarms.py check`。历史裁决的时间间隔过快与发现率塌方两条警报均经过证据审计后写入复核结论并销账；销账后警报检查干净，未绕过 gate。
- `make verify` 首轮真实暴露两类回归：`AnNodeGantt` 在 150px 宽度的标签列加间距超过可用行宽并产生多个 RenderFlex overflow；`AnMenu` 将普通命令绑定到不稳定的退场动画 Future，造成 PanelHead、Workflow Editor 与 Scheduler 的动作在固定帧窗口内不执行。
- 修复：Gantt 标签列通过 `LayoutBuilder` 在窄宽度让出轨道空间，极窄态隐藏不可容纳的标签内容，并把窄屏测试升级为“无任何异常”守卫；菜单改为先发起退场、同一事件循环执行用户命令，`AnPopover` 仅在浮层仍持焦时恢复触发器焦点，Dialog 焦点不被抢回。
- 快速回归：Gantt 3 项、PanelHead、Workflow Editor add-node、Scheduler kill-confirm、AnMenu WCAG 焦点用例均通过。随后完整 `make verify` 通过：backend、frontend 全量（core/group2/group3）、docs、demo 全绿。
- 当前状态：长门禁已通过，正在进入完整 `make -C backend testend`、修复场景回归和工作树审计；仍未提交。
- 完整黑盒 `make -C backend testend` 通过（scenarios `319.533s`）；根级 `cd testend && mise exec -- go test -count=1 ./...` 通过（scenarios `323.535s`，同时覆盖 cmd/golden/harness/proxycore）。
- `alarms.py check` 再次确认 `clean (50 judgments on record)`；`git diff --check` 与 `python3 -m py_compile testend/rig/*.py` 通过。
- 文档同步后的最终 `make verify` 再次全绿：backend、frontend 全量、docs、demo；当前长门禁与 testend 均收口，进入工作树审计和提交。

## 2026-08-01 · 修复场景真实 App 回放

- 回放会话：`/tmp/anselm-rig-formal-20260801-13/sessions/20260801-042830`。使用最新构建真实启动 Flutter App，受管网关经 llmtap 接线，ssetap 动态接入 workspace 的三路 SSE，屏幕录像和前端 console 均由同一 conductor 托管；收台录像 `168.430s`，无残留进程。
- 真实路径一：Settings → Models & keys → Dialogue → Change → Anselm Auto。逐帧确认菜单展开、选项文本完整、选择后菜单收起，未出现焦点丢失或 action 延迟；证据 `evidence/model-menu-open.png` 与 `model-menu-closed.png`。
- 真实路径二：构造 `Gantt visual probe` workflow 后进入 Entities → Workflow → Overview，确认真实 Gantt 节点卡片、连线、右侧 run terminal 和左侧实体导航均稳定；证据 `evidence/gantt-real.png`。
- 五通道：llmtap 记录的 8 个响应全为 HTTP 200；backend journal 无 WARN/ERROR/panic；frontend journal 无 Dart/Flutter/RenderFlex/Unhandled Exception，唯一 `error messaging the mach port for IMKCFRunLoopWakeUpReliable` 为已知 macOS 输入法平台噪声；三路 SSE 均真实连接但本回放未触发 durable 业务帧，不能将其记作业务流覆盖。
- 该回放只作为已修场景回归证据，不新增 COVERAGE 格子；当前批次 50/50，全部长门禁和真实回放均通过，下一步仅剩最终工作树审计与提交。

## 2026-08-01 · 第二批 TOOL-003 Edit 真实工具切片

- 台架会话：`/tmp/anselm-rig-formal-20260801-14/sessions/20260801-044210`；真实 App、受管网关、Computer Use、屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。`rig-check` 起始与收台前均五通道全绿，收台录像 `screen.mov` 时长 `260.076667s` 且 ffprobe 可读，无残留进程。
- 构造数据：真实对话挂载 `/tmp/anselm-edit-fixture-14`，包含 `target.txt`、`other.txt` 和 `nested/child.txt`。成功路径由真实 composer 发起，LLM 线缆和 messages SSE 均证明执行顺序为 `Read(target.txt) → Edit(old=beta,new=BETA) → Read(target.txt)`；UI 显示 `Edited target.txt · 1 replaced`，最终代码块为 `alpha / BETA / gamma`。
- 负路径：同一对话要求替换不存在的 `delta`。真实模型先 `Read`，然后明确拒绝，不调用 `Edit`、`Write` 或其他变更工具；UI 展示原因和当前文件内容。磁盘核对确认三个夹具文件只有目标文件发生预期替换。
- 五通道收台：`llm.jsonl` 20 个 HTTP 响应全为 200，`sse.jsonl` messages durable seq 1..38 且包含两条路径的工具调用/结果，notifications seq 16、entities 流已连接；`backend.log` 无 WARN/ERROR/panic/FATAL；`frontend.log` 无 Flutter/Dart/AXTree/RenderFlex/Unhandled Exception；关键画面为 `evidence/edit-tool-final.jpeg` 与 `evidence/edit-tool-no-match.jpeg`，完整摘要为 `evidence/tool-003-edit-session-summary.txt`。
- `judge.py` 用正确批次 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3`、已通过锚点校准的 `anchor-answers.json` 独立落账 `TOOL-003 Edit` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。批次从 `0 / 50` 推进到 **5 / 50**。
- 裁决后统计警报曾按机制打开 `gap-too-fast` 和 `discovery-collapse`；复审确认五格均在完整证据观看、收台和磁盘核对后才落账，且负路径真实发现了只读拒绝保护，遂分别写入复审 note 并 ack。最终 `alarms.py check` 为 `clean (55 judgments on record)`。注意：一次未导出的 `RIG_HOME` 曾误写默认账本，已完整隔离到 `~/.anselm-rig/misrouted-edit-20260801-0448.judgments.jsonl`，批次账本无污染。
- 当前前线：第二批 **5 / 50**；下一格为 `TOOL-004 LS`，未到第二批 50 格不跑统一长门禁、不提交。
- 台架机制 stop-and-fix：一次错误的未导出 `RIG_HOME` 重放暴露 `judge.py` 对相同裁决会重复追加 COVERAGE 证据指针的幂等缺口。已修复为相同 `(family,item,level,verdict,law,evidence)` 重跑 no-op，新增 `testend/rig/test_judge.py` 守卫并验证真实 TOOL-003 重放不增加 journal 行、不重复证据。此修复只影响裁判系统，不改变产品格计数；下一格仍为 `TOOL-004 LS`。

## 2026-08-01 · Goal/Loop 配置恢复

- 用户暂停后要求恢复 Goal 与 Loop；Codex 状态核对为唯一持久 Goal `active`，未创建副本，未启用并行 agent。
- 旧的 `TOOL-004 LS` 实时会话 `/tmp/anselm-rig-formal-20260801-16/sessions/20260801-045350` 已运行 `rig-check` 后收台；五通道在收台前均在线，录像时长 `331.833333s`，证据与 journals 保留，但该会话不写入 COVERAGE 裁决。
- 恢复点固定为第二批 `5 / 50`，下一前线仍为 `TOOL-004 LS`；50 格前不跑统一长门禁、不提交。后续每次唤醒先读本页、`README.md`、`LOOP.md` 和当前 git 状态，再检查是否存在 live rig，保持单一作者、单一台架、逐格 stop-and-fix。

## 2026-08-01 · 第二批 TOOL-004 LS 真实工具切片与 stop-and-fix

- 台架会话：`/tmp/anselm-rig-formal-20260801-17/sessions/20260801-050302`；当前前端代码在全新五通道台架中真实构建并启动，受管网关经 `llmtap` 接线，`ssetap` 动态接入三路 SSE，Computer Use 与连续屏幕录像由同一 conductor 托管；收台前 `rig-check` 五通道全绿，`screen.mov` 时长 `213.276667s` 且 ffprobe 可读。
- 构造数据：真实对话驻地 `/tmp/anselm-ls-fixture-17`，包含 `.hidden.txt`、`a.txt`、`b.txt`、空目录 `empty-dir`、`nested/deep.txt` 与 `nested/deeper/file.txt`。第一条真实请求只用 LS 列当前目录，正确返回 5 个直接条目；第二条请求按序只用 LS 查询 `nested`、缺失目录和文件 `a.txt`。
- 真实首轮发现的产品缺陷：LS 对 `Directory not found` 与 `Not a directory` 这种 completed tool_result 虽然正文是错误，折叠卡标题仍显示成功动词 `Listed`，造成红色事实旁的假成功语义。前线冻结，未把首轮当成通过。
- 修复：`lsResultFailed` 以 LS 成功 listing header 的结构契约判定失败；`_search` 支持失败动词/结果重分类；新增双语 `listFailed` 和 `tool_card_fs_search_test.dart` 的 parser/widget 守卫。修复后失败卡片自动展开原始错误正文并显示 `List failed … · failed`，正常卡片仍显示 `Listed … · 5 items`。
- 真实逐帧复验：成功画面确认目录优先、隐藏文件和空目录可见、`nested/deep.txt` 不越层；错误画面确认两个失败卡均不再显示 `Listed`，正文分别为缺失目录与提示使用 Read。证据为 `evidence/ls-success.jpeg`、`evidence/ls-errors.jpeg` 和完整录像；摘要为 `evidence/tool-004-ls-session-summary.txt`。
- 五通道收台：`backend.log` 无 WARN/ERROR/panic/FATAL；`frontend.log` 无 Flutter/Dart/AXTree/RenderFlex/Unhandled Exception，仅有已知 `IMKCFRunLoopWakeUpReliable` macOS 平台噪声；`llm.jsonl` 18 个 HTTP 响应全 200；`sse.jsonl` 三流均连接，messages durable seq `1..40` 单调，notifications durable seq `16`，entities 已连接；磁盘夹具只读且未改变。
- 录屏环境诚实标注：桌面级 `screen.mov` 中间捕获到其他进程的 Apple Music 权限弹窗，不属于 Anselm、未被操作，也未用于产品判断；Computer Use 取得的 Anselm 窗口截图没有被遮挡。该环境污染保留在摘要中，不伪装成产品绿证据。
- `judge.py` 用正确批次 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3`、四小时锚点凭证和独立证据落账 `TOOL-004 LS` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`；批次从 `5 / 50` 推进到 **10 / 50**。裁决后 `gap-too-fast` 与 `discovery-collapse` 按机制打开，证据逐项复审并 ack，最终 `alarms.py check` 为 `clean (60 judgments on record)`。
- 当前前线：第二批 **10 / 50**；下一格为 `TOOL-005 Glob`，未到第二批 50 格不跑统一长门禁、不提交。


## 2026-08-01 · 第二批 TOOL-005 Glob 真实工具切片与 stop-and-fix

- 台架会话：`/tmp/anselm-rig-formal-20260801-19/sessions/20260801-051557`；真实 App、受管网关、Computer Use、屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。收台后 `screen.mov` 时长 `171.003333s` 且 ffprobe 可读，三路 SSE 均真实连接。
- 构造数据：`/tmp/anselm-glob-fixture-18` 包含根级 `app.go`、`src/other.go`、`src/nested/deep.go`、非 Go 文本和标准噪声目录 `.git`、`node_modules`；真实对话要求递归 `**/*.go`，并检查空结果、`limit=2` 截断、缺失根和文件根边界。
- 首轮真实发现的产品缺陷：后端实现确实跳过标准噪声目录，但 Glob 的工具 description/schema 没有把这个用户可观察契约说清，模型无法确认 `.git` 与 `node_modules` 是否被主动排除。前线冻结，未将首轮当成通过。
- 修复：`backend/internal/app/tool/search/glob.go` 补齐递归噪声目录说明及显式根例外，`glob_test.go` 增加描述契约守卫；前端新增 `globResultFailed`，将非 JSON、缺失根和非目录等错误 payload 重分类为 `Glob failed` 并自动展开，补齐双语 i18n 与 widget 测试。
- 修复后真实逐帧复验：成功路径返回 3 个 Go 文件，模型明确复述递归噪声目录策略；`*.rs` 显示合法空结果；`limit=2` 显示 2 行且总数 3、截断语义清楚；缺失根和文件根均显示红色 `Glob failed "*.go" · failed` 与可读错误正文。关键画面：`evidence/glob-success.jpeg`、`evidence/glob-boundaries.jpeg`；完整摘要：`evidence/tool-005-glob-session-summary.txt`。
- 五通道收台：`backend.log` 无 WARN/ERROR/panic/FATAL；`frontend.log` 无 Flutter/Dart/AXTree/RenderFlex/Unhandled Exception，仅已知 macOS IMK 平台噪声；LLM journal 20 个 HTTP 响应全为 200；`sse.jsonl` 共 617 行，messages durable seq 单调、notifications/entities 均曾连接；录屏可读。桌面录像没有被用于掩盖或替代 Anselm 窗口证据。
- `judge.py` 在正确 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3`、锚点凭证有效且警报先验干净的条件下，独立落账 `TOOL-005 Glob` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。第二批从 `10 / 50` 推进至 **15 / 50**；同一命令重放保持幂等 no-op。
- 裁决后 `alarms.py check` 按机制打开 `gap-too-fast` 与 `discovery-collapse`；复审确认本次真实包含负路径、首轮冻结和修复后重跑，逐项查看五通道证据后写入复核说明并 ack，最终为 `clean (65 judgments on record)`。
- 当前前线：第二批 **15 / 50**；下一格为 `TOOL-006 Grep`。未到第二批 50 格不跑统一长门禁、不提交。

## 2026-08-01 · 第二批 TOOL-006 Grep 真实工具切片与 stop-and-fix

- 最终台架会话：`/tmp/anselm-rig-formal-20260801-22/sessions/20260801-054044`；真实 App、受管网关、Computer Use、屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。收台前 `rig-check` 五通道全绿，`rig-down` 封口 `screen.mov` 时长 `269.225000s`，所有进程均正常结束。
- 构造数据：`/tmp/anselm-grep-fixture-20` 包含 README、Go、文本、多行匹配、`.git`、`node_modules`、空结果和可触发错误的路径。真实路径覆盖 `content`、`files_with_matches`、`count`、`multiline=true`、`head_limit=1` 截断、合法 no-match、非法正则 `[`、缺失根目录；递归结果不泄漏 `.git` 或 `node_modules`。
- 首轮真实发现并冻结：ripgrep 路径未显式排除 `node_modules`；content 模式把 context/path 物理行错误计入匹配数；缺失根和路径安全错误在 UI 中仍像成功搜索；非法正则触发 rg fallback WARN。未用首轮证据裁绿。
- 修复：`grep_rg.go` 显式排除六类噪声目录并在启动 rg 前预校验正则；`grep.go`/schema 补齐多行参数和噪声目录契约；`tool_card_fs_search.dart` 按模式计算语义 receipt、识别失败前缀并统一错误卡片；`tool_card_catalog.dart`、双语 i18n 与 widget 守卫同步更新。前两次台架中一次复杂提示误触发未知 `multiline` 工具，最终复验改用 Grep-only 明确指令并确认真实调用 `multiline=true`，最终 backend 无该告警。
- 修复后逐帧复验：content 显示 5 个语义匹配而非上下文物理行；files 模式显示 3 个文件；count 模式聚合每文件计数；多行模式命中 `src/multiline.txt`；截断显示 `1+ files` 并解释下限；空结果显示 `no matches`；非法正则和缺失根分别显示红色 `Search failed` 及原始错误正文。
- 五通道收台：`backend.log` 无 WARN/ERROR/panic/fatal；`frontend.log` 仅已知 macOS IMK/foreground 平台噪声，无 Dart/Flutter/AXTree/RenderFlex/Unhandled Exception；`llm.jsonl` 28 个 HTTP 响应全为 200；`sse.jsonl` 三流均连接，messages durable seq `1..70`、notifications durable seq `1..2` 连续，entities 已连接；证据摘要为 `evidence/tool-006-grep-session-summary.txt`，完整录屏已封存。
- `judge.py` 在锚点校准通过、警报先验干净的 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3` 下独立落账 `TOOL-006 Grep` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。裁决后两条统计警报按机制打开；逐项复审真实负路径、冻结修复、五通道和证据后写入 ack，最终 `alarms.py check` 为 `clean (70 judgments on record)`。
- 第二批从 **15 / 50** 推进至 **20 / 50**；当前前线为下一未裁决格 `TOOL-007 Bash`。未到第二批 50 格不跑统一长门禁、不提交。完整证据清单与早期废弃台架说明见 `/tmp/anselm-rig-formal-20260801-22/sessions/20260801-054044/evidence/tool-006-grep-session-summary.txt`。

## 2026-08-01 · 第二批 TOOL-007 Bash 真实工具切片与 stop-and-fix

- 最终台架会话：`/tmp/anselm-rig-formal-20260801-23/sessions/20260801-055042`；真实 App、受管网关、Computer Use、屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。收台前 `rig-check` 五通道全绿，`rig-down` 封口 `screen.mov` 时长 `580.875000s`，所有台架进程均正常结束。
- 构造数据：`/tmp/anselm-bash-fixture-23` 中的 `fixture.txt` 与 `other.txt` 用于驻地验证。真实覆盖前台 stdout+stderr 合流与非零退出、危险命令审批拒绝、100ms 超时、后台启动与 BashOutput 轮询、KillShell 中途终止、原生目录选择器挂载驻地、驻地移失后的拒绝、不回落后端 cwd，以及 270000 字节输出封顶。
- 关键产品判断：大输出通过 `tool_result` 256KiB 总封顶后，Bash footer 可能被通用封顶截掉；UI 明确显示截断 marker，并把回执降为 `exit unknown` warn，而不是猜成功/失败。该状态诚实且可解释，提示用户收窄命令；不是缺陷，不改代码。
- 逐帧结果：前台卡片显示合并输出和 `exit 3`；危险命令先出现审批面，deny 后显示 Safety refusal 且没有执行；超时显示 `timed out after 100ms` 和 `exit -1`；后台显示可复制 `bsh_…`、轮询结果 `bg-start/bg-done` 与 exited code 0；KillShell 后 `should-not-appear` 未出现；驻地相对 `pwd`/`ls -1` 正确命中 fixture；驻地失效明确拒绝并不静默改跑 `/` 或 sidecar 目录。
- 五通道收台：`backend.log` 无 WARN/ERROR/panic/fatal；`frontend.log` 仅已知 macOS IMK/foreground 平台噪声，无 Dart/Flutter/AXTree/RenderFlex/Unhandled Exception；`llm.jsonl` 48 个 HTTP 响应全为 200；`sse.jsonl` 三流均连接，messages durable seq `1..138`、notifications durable seq `1..6` 连续，entities 已连接；证据 JPEG 覆盖前台、拒绝、超时、后台、终止、驻地、失效驻地和封顶。
- `judge.py` 在锚点校准通过、警报先验干净的 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3` 下独立落账 `TOOL-007 Bash` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。裁决后两条统计警报按机制打开；复审真实负路径、封顶诚实语义、进程清理和五通道证据后写入 ack，最终 `alarms.py check` 为 `clean (75 judgments on record)`。
- 第二批从 **20 / 50** 推进至 **25 / 50**；当前前线为下一未裁决格 `TOOL-008 BashOutput`。未到第二批 50 格不跑统一长门禁、不提交。完整证据摘要见 `/tmp/anselm-rig-formal-20260801-23/sessions/20260801-055042/evidence/tool-007-bash-session-summary.txt`。

## 2026-08-01 · 第二批 TOOL-008 BashOutput 真实工具切片与 stop-and-fix

- 最终台架会话：`/tmp/anselm-rig-formal-20260801-24/sessions/20260801-060449`；真实 App、受管网关、Computer Use、屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。收台后 `screen.mov` 时长 `548.728333s`，五通道进程正常结束。
- 构造数据：沿用真实后台 shell `echo KEEPONE; echo DROPTWO; sleep 8; echo KEEPTHREE`，用 BashOutput 分别覆盖无过滤增量读取、`KEEP` regex 过滤、无新输出、最终 exited 状态；随后刻意请求不存在的 `bash_id` 和非法 regex，验证错误路径。
- 逐帧产品结果：正常卡片只展示本次新增输出，不重复已消费行；过滤卡片展示 `KEEPTHREE` 和 `exited (code 0)`；无新输出明确说明已消费完并保留最终状态。缺失 bash_id 显示 `session not found`、红色错误回执和原始错误；非法 regex 在工具输入校验层拒绝，显示红色 failed 行、`Error` 标签、完整 `missing closing ]` 原文和可展开 raw result。没有把错误伪装成空成功轮询。
- 五通道收台：`backend.log` 唯一 WARN 是这次刻意触发的非法 regex 输入校验拒绝，已与 UI、LLM wire 和证据摘要逐字互证；除此之外无 WARN/ERROR/panic/fatal。`frontend.log` 仅已知 macOS foreground/IMK 平台噪声，无 Dart/Flutter/AXTree/RenderFlex/Unhandled Exception；`llm.jsonl` 36 个 HTTP 响应全 200；`sse.jsonl` messages durable seq `1..90`、notifications `1..2` 单调，entities 持续连接。关键画面为 `evidence/bashoutput-missing.jpeg` 与 `evidence/bashoutput-invalid-regex.jpeg`，摘要为 `evidence/tool-008-bashoutput-session-summary.txt`。
- `judge.py` 在锚点校准通过、警报先验干净的 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3` 下独立落账 `TOOL-008 BashOutput` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。五级证据分别指向摘要、录屏和两张真实画面；无代码缺陷需要 stop-and-fix。
- 裁决后 `gap-too-fast` 与 `discovery-collapse` 按机制打开；复审确认五级裁决是在完整录屏和五通道证据观看后落账，且负路径真实触发并清晰呈现，遂写入复审 note 并 ack；最终 `alarms.py check` 为 `clean (80 judgments on record)`。
- 第二批从 **25 / 50** 推进至 **30 / 50**；当前前线为下一未裁决格 `TOOL-009 KillShell`。未到第二批 50 格不跑统一长门禁、不提交。完整证据摘要见 `/tmp/anselm-rig-formal-20260801-24/sessions/20260801-060449/evidence/tool-008-bashoutput-session-summary.txt`。

## 2026-08-01 · 第二批 TOOL-009 KillShell 真实工具切片与 stop-and-fix

- 初始真实会话 `/tmp/anselm-rig-formal-20260801-25/sessions/20260801-061721` 先验证了后台启动、KillShell 终止和重复调用，但逐帧审查发现重复调用的主行显示 `Terminated … · session not found`，与后端幂等事实冲突；该会话不直接判绿。一次提示词中的分号还被 Computer Use 输入吞掉，形成了立即退出的 malformed `sleep 30 echo SHOULDNOTAPPEAR`，明确排除出终止成功证据。
- 前线冻结并修复共享产品语义：`tool_receipts.dart` 增加结果驱动的 `killShellTerminalVerb`；KillShell 三种正常 `err=nil` 结果分别显示 `Terminated`、`already finished`、`already stopped`，删去重复橙色 not-found 回执，精确 wire 结果仍保留在可展开 body。补齐英/中文 i18n 生成物、receipt/parser 测试和 widget 三态守卫；`flutter analyze` 无问题，相关测试全绿。
- 修复后新建真实会话：`/tmp/anselm-rig-formal-20260801-26/sessions/20260801-062334`。真实后台 `sleep 30` 立即经 KillShell 返回 `Killed background shell bsh_9f260ea1079737e9.`，UI 主行显示 `Terminated`；对已移除会话和 fabricated `bshghost` 的重复/未知调用显示 `already stopped`，原始 `Background shell process not found` 仍可读，且不再制造错误警告。证据为 `evidence/killshell-terminated.jpeg`、`evidence/killshell-already-stopped.jpeg`，完整摘要为 `evidence/tool-009-killshell-session-summary.txt`。
- 五通道收台：`screen.mov` 时长 `248.060000s`；`backend.log` 无 WARN/ERROR/panic/fatal；`frontend.log` 仅已知 macOS foreground/IMK 平台噪声，无 Dart/Flutter/AXTree/RenderFlex/Unhandled Exception；`llm.jsonl` 32 个 HTTP 响应全 200；`sse.jsonl` messages durable seq `1..76`、notifications `1..2` 单调，entities 持续连接。
- `judge.py` 在锚点校准通过、警报先验干净的 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3` 下独立落账 `TOOL-009 KillShell` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。裁决后两条统计警报经逐帧、修复记录、目标测试和五通道证据复审后 ack；最终 `alarms.py check` 为 `clean (85 judgments on record)`。
- 第二批从 **30 / 50** 推进至 **35 / 50**；当前前线为下一未裁决格 `TOOL-010 ask_user`。未到第二批 50 格不跑统一长门禁、不提交。

## 2026-08-01 · 第二批 TOOL-010 ask_user 真实工具切片与产品收尾

- 最终台架会话：`/tmp/anselm-rig-formal-20260801-27/sessions/20260801-063212`；真实 Flutter App、受管 Anselm 网关、Computer Use、连续屏幕录像、后端、三路 SSE tap 和 LLM tap 均由同一 conductor 托管。收台前 `rig-check` 五通道全绿，`rig-down` 封口 `screen.mov` 时长 `256.490000s`，所有进程正常结束。
- 产品路径一：模型只调用一次 `ask_user` 并停在等待态，UI 展示清晰问题、`blue`/`green` 选项、文本框、`Don't answer` 与 `Send`；选择 `blue` 后状态诚实显示 Answered，模型只恢复一次并正常收尾。等待卡片层级、橙色等待边界、选项按钮和 composer 空闲状态逐帧检查，无视觉阻断问题。
- 产品路径二：模型只调用一次 `ask_user` 询问是否继续迁移，选择 `Don't answer` 后状态显示 Skipped，不伪造 yes/no 决策；模型只恢复一次，给出可重述或不继续的诚实后续并正常收尾。
- 没有发现需要 stop-and-fix 的产品或代码缺陷；截图 `evidence/askuser-pending.jpeg`、`evidence/askuser-answered.jpeg`、`evidence/askuser-skipped.jpeg` 与完整摘要 `evidence/tool-010-ask-user-session-summary.txt` 已封存。
- 五通道收台：`backend.log` 无 WARN/ERROR/panic/fatal；`frontend.log` 仅已知 macOS foreground/IMK 平台噪声，无 Dart/Flutter/AXTree/RenderFlex/Unhandled Exception；`llm.jsonl` 16 个 HTTP 响应全为 200；`sse.jsonl` messages durable seq `1..28`、notifications `1..2` 单调，entities 持续连接；LLM wire 可见 ask_user 调用与两个恢复回合。
- `judge.py` 在锚点校准通过、警报先验干净的 `RIG_HOME=/tmp/anselm-rig-formal-20260801-3` 下独立落账 `TOOL-010 ask_user` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。裁决后 `gap-too-fast` 与 `discovery-collapse` 按机制打开；复审确认完整录像、三张状态图、五通道 journal 和正/负路径均真实存在，写入复审 note 后 ack，最终 `alarms.py check` 为 `clean (90 judgments on record)`。
- 第二批从 **35 / 50** 推进至 **40 / 50**；当前前线为下一未裁决格 `TOOL-011 todo_write`。未到第二批 50 格不跑统一长门禁、不提交。

## 2026-08-01 · 第二批 TOOL-012 todo_read 与批次边界

- `TOOL-012 todo_read` 使用已收台的真实会话 `/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406` 作为独立覆盖项：前一条路径读回 1 个 completed + 2 个 pending，后一条路径在 3 个全部 completed 后读回完整清单；两次均明确禁止写操作，第二次没有生成旧的未完成任务提醒。
- `judge.py` 独立落账 `TOOL-012 todo_read` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。L1/L2 使用 `tool-012-todo-read-session-summary.txt`，L3 使用完整 `screen.mov`，L4/L5 使用 `todo-completed.jpeg`；没有把 `todo_write` 的判定理由当作本项证据。
- 本会话五通道收台：录屏 `176.260000s`；backend 无 WARN/ERROR/panic/fatal；frontend 仅已知 macOS foreground/IMK 平台噪声；LLM 26 个响应全 200；messages durable seq `1..64`、notifications `1..2` 单调，entities 已连接；证据摘要和截图已封存。
- 裁决后 `gap-too-fast`、`pass-burst`、`discovery-collapse` 三条统计警报按机制打开；逐项复审真实录像、负路径、五通道 journals 与锚点校准后 ack，最终 `alarms.py check` 为 `clean (100 judgments on record)`。
- 第二批从 **40 / 50** 达到 **50 / 50**；统一长门禁现在开始：`alarms.py check`、完整 `make verify`、完整 `go test ./...`、已修场景回归、testend、工作树审计和提交。门禁完成前不进入 `TOOL-013 search_tools`，不提交。

## 2026-08-01 07:17 · Goal/Loop 恢复

- 用户暂停后重新启用 Goal/Loop；Codex 盘上仍只有一个持久 `active` Goal，未创建副本，未启用并行 agent。
- 执行计划恢复为：第二批已完成 **50 / 50**，继续完成统一长门禁；门禁包含 `alarms.py check`、完整 `make verify`、完整 `go test ./...`、已修场景回归、完整 testend、工作树审计，全部通过后才一次性提交。
- 当前前线保持不变：门禁未全绿前不提交、不推进 `TOOL-013 search_tools`；本次恢复不改变任何产品判定或批次计数。

## 2026-08-01 07:48 · 第二批统一长门禁收口与 durable webhook ACK 修复

- 第二批已达到 **50 / 50**。按 `LOOP.md` 只在批次边界运行统一长门禁；没有把批次中的快速守卫测试冒充完整门禁。
- 首次执行 `make -C backend testend` 暴露真实失败：`TestTrigger_WebhookFiringSurvivesRestartBeforeDrain` 在 webhook 返回 `202` 后立即 `Kill9 → Restart`，durable firing 未能在 30 秒内出现。该失败稳定复现，证明不是 flaky test，也不是应该放宽的时序。
- 根因是产品/API 语义错误：`backend/internal/infra/trigger/webhook/webhook.go` 在 `go` 协程里调用 report，HTTP `202` 早于 Activation/Firing 持久化完成；硬崩溃可以丢掉用户已经收到“接受成功”的事件。
- stop-and-fix：`ReportFunc` 改为返回 `error`；`onReport`/`fanOut` 传播 AppendActivation、AppendFiring、RequeueMissedFiring 的真实错误；webhook 同步等待 durable audit/inbox 写入，成功才返回 `202`，失败返回 `503`；cron/fsnotify/sensor 的后台路径记录 report 错误。新增 `TestDispatch_DoesNotAcknowledgeBeforeReportReturns`，并同步 `docs/references/backend/api.md` 与 `docs/references/backend/domains/trigger.md` 的契约。
- 修复后专项回归：
  - `cd testend && mise exec -- go test -count=1 -timeout 10m -run '^TestTrigger_WebhookFiringSurvivesRestartBeforeDrain$' ./scenarios`：通过，约 `11.824s`。
  - `make -C backend testend`：通过，场景组约 `273.863s`。
  - `cd testend && mise exec -- go test -count=1 ./...`：通过，场景组约 `327.572s`。
  - `make verify`：backend、frontend、docs、demo 全部通过。
- 台架控制面最终复核：`RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/anchors.py check /private/tmp/anselm-rig-formal-20260801-3/anchor-answers.json` 通过 10 个锚点；同一 RIG_HOME 的 `alarms.py check` 为 `clean (100 judgments on record)`。默认 `~/.anselm-rig` 的空 journal 是一次未选台架上下文的空壳，未被用作本批次证据，也没有把它冒充成 100 条裁决。
- `git diff --check` 通过；本记录与代码/契约同步，最终工作树审计通过后已提交 `906c9971`。下一前线为 `TOOL-013 search_tools`，不在本批次门禁记录中提前裁决。

## 2026-08-01 08:10 · 第三批 TOOL-013 search_tools 真实工具切片与 stop-and-fix

- 首轮真实台架会话：`/private/tmp/anselm-rig-formal-20260801-29/sessions/20260801-075126`。真实 App、受管
  Anselm gateway、Computer Use、屏幕录像、backend journal、三路独立 SSE tap、LLM wire tap 均在线。
  现场要求模型先用 `search_tools` 找到只读 function search，再激活并调用 `search_function`；后端真实回执是
  `loaded_tools[{name,purpose}]`，但前端只识别旧的 `tools[{description,parameters}]`，成功结果错误地显示原始
  JSON，未达到可读产品状态，前线冻结，未使用该会话裁绿。
- 同一首轮还发现 transcript 的 lazy builder 在 `childCount` 与 builder 回调之间共享可变 `t.pending`，流式
  reconciliation 清空列表后触发 `RangeError(length): Invalid value: Valid value range is empty: 0`
  （`chat_transcript.dart:438`）。这也是产品台架红线，未降级为“偶发平台噪声”。
- stop-and-fix：`tool_card_memory_web.dart` 增加 `loaded_tools` 与旧 fixture 的兼容解析，命中卡片改为可读的
  工具名称/用途/下一请求 schema 状态，不再倾倒原始 JSON；`chat_transcript.dart` 在每次 build 取不可变
  pending 快照，`chat_transcript_test.dart` 增加 reconciliation 竞态回归测试；对应 widget 测试与 `flutter analyze`
  均通过。
- 修复后二次全新真实会话：`/private/tmp/anselm-rig-formal-20260801-29/sessions/20260801-080221`。
  命中路径显示 `Searched tools "search function read-only" · 5 tools`，展开可读命中卡片并在下一模型请求中
  实际调用 `search_function`；无命中路径使用 `zzz_nonexistent_acceptance_capability_9c31`，显示清晰的
  `No match`，没有误调用其它工具。关键画面为 `evidence/search-tools-hit-card.png` 与
  `evidence/search-tools-no-match.png`，完整五通道摘要为 `evidence/tool-013-search-tools-session-summary.txt`。
- 五通道收台：`screen.mov` `155.068333s` 且可读；backend 无 WARN/ERROR/panic/fatal；frontend 无
  FlutterError、RenderFlex、DartError、AXTree 或 unhandled 错误，仅已知 macOS foreground/IMK 平台噪声；
  LLM 14 个响应全 HTTP 200。LLM wire 的 `00002` 仅提供 `search_tools`，`00003` 下一请求同时提供
  `search_function`，并真实完成命中与无命中两条调用链。SSE 共 243 条记录，messages durable seq `1..36`、
  notifications durable seq `1..2` 单调，entities 已连接。
- 正确台架 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 的锚点校准通过，先验警报 clean；随后
  `judge.py` 独立落账 `TOOL-013 search_tools` 五格：L1 `G1`、L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。
  统计警报按机制打开 `gap-too-fast` 与 `discovery-collapse`；逐项重审完整录像、首轮红线与修复记录、命中/无命中
  截图、LLM/SSE/backend/frontend 五通道后写入复审 note 并 ack，最终 `alarms.py check` 为
  `clean (105 judgments on record)`。
- 第三批从 **0 / 50** 推进至 **5 / 50**；下一前线为 `TOOL-014 search_function`。未到第三批 50 格不跑统一
  长门禁、不提交；本批代码、测试、COVERAGE 与本日志留在工作树，待第三批边界统一收口。

## 2026-08-01 08:22 · 第三批 TOOL-014 search_function 真实工具切片

- 台架先查出一次旧数据目录的受管 key 仍指向上一轮 `:8815`，而本轮 llmtap 在 `:8788`；该 session 被
  `rig-check` 的 channel-5 wiring 物理拒收并收台，未用于产品裁决。随后使用全新数据目录和全新注册流程重启：
  `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-081207`，`rig-check` 五通道全绿。
- onboarding 创建真实 workspace `Acceptance Tool Search` 后，通过本地真实 API 构造最小 ready fixture
  `acceptance_search_probe`（`fn_d9eb9300387ec1c8`），描述和 tags 覆盖 acceptance/search/fixture。fixture
  只负责构造检索前置数据，所有验收判断仍通过真实 App 对话完成。
- 首轮 Computer Use 输入错误地把两个草稿拼成一条消息；该控制事故没有被掩盖，明确从验收证据中排除。它之后
  重新开干净对话，逐帧覆盖：`acceptance` 命中；空 query 列出全部 function；`FIXTURE` 大写 query 通过
  tag 的大小写不敏感匹配；`zzznonexistentacceptance9c31` 明确 no-match。命中卡片/表格显示真实 `fn_` id、
  name、description，no-match 显示 name/description/tags 均无匹配；整个操作保持只读。
- 五通道收台：`screen.mov` `506.090000s` 可读；backend 无 WARN/ERROR/panic/fatal；frontend 无 FlutterError、
  RenderFlex、DartError、AXTree 或 unhandled exception，仅已知 macOS foreground/IMK 平台噪声；LLM chat 48
  个响应全 HTTP 200，challenge/install/models 也全 200；messages durable seq `1..128`、entities `1..2`、
  notifications `1..15` 均单调；关键画面为 `evidence/search-function-hit.png` 和
  `evidence/search-function-no-match.png`，完整摘要为 `evidence/tool-014-search-function-session-summary.txt`。
- 正确台架锚点校准通过、警报先验 clean；`judge.py` 独立落账 `TOOL-014 search_function` 五格：L1 `G1`、
  L2 `F2`、L3 `A5`、L4 `C4`、L5 `G2`。裁决后 `gap-too-fast` 与 `discovery-collapse` 打开，逐项复审
  506 秒录屏、负路径、首轮排除说明、两张截图和五通道 journal 后写入 note 并 ack，最终 `alarms.py check`
  为 `clean (110 judgments on record)`。
- 第三批从 **5 / 50** 推进至 **10 / 50**；下一前线为 `TOOL-015 get_function`。未到第三批 50 格不跑统一
  长门禁、不提交。
## 2026-08-01 12:43 · 第四批 TOOL-026 create_handler 真实工具切片与 stop-and-fix

- 首轮真实窗口绑定台架会话：`/private/tmp/anselm-rig-formal-20260801-38/sessions/20260801-123643`。`rig-check`
  在收台前确认五通道物理在线：backend PID 与 `:8742` 归属、ssetap 三流连接、llmtap 接线、Flutter runner 和
  `screencapture -v -l 9726` 的 Anselm 窗口录像。录像不再把外部桌面弹窗当作产品证据。
- 产品成功路径：真实 App 对话一次调用 `create_handler`，`set_meta → add_method` 创建
  `acceptance_handler_minimal_probe`；LLM wire 中 `ops` 是合法 JSON-encoded array string，后端返回
  `hd_4b7c8c7338fa5724` / v1 / `envStatus=ready` / `opsApplied=2`；SQLite 与 UI 回执一致。
- 产品拒绝路径：新对话一次调用只带 `set_meta` 的 `create_handler`，后端返回
  `handler class code invalid (reason=a handler needs at least one method)`；UI 明确显示 failed 与
  `Draft unsaved · nothing was created`。模型没有重试 create，随后一次 `search_handler` 仅作只读核实；SQLite
  没有 `acceptance_handler_invalid_probe_minimal`，没有负向副作用。
- 首轮问题不是被掩盖而是冻结修复：托管模型将 Parameters 声明的 array 发为 JSON-encoded array string。
  `backend/internal/app/tool/handler/build.go` 新增 create/edit 共用 `decodeHandlerOps`/`parseHandlerOps`，接受
  原生 array 与精确字符串化 array，拒绝 malformed string/object/scalar；`handler_test.go` 补齐边界测试。
  同步修复窗口录像台架：`rig-up.sh` 等窗口再录像，`rig-check.sh` 拒绝全桌面 evidence。
- 五通道收台：`screen.mov` `256.185000s`、`2784x1808`；`backend.log` 仅一条刻意拒绝 WARN、无 ERROR/panic/fatal；
  `sse.jsonl` 585 帧，messages durable `1..53`、entities `7..12`、notifications `16..22` 连续；`frontend.log`
  仅已知 macOS IMK/foreground 噪声，无 FlutterError/RenderFlex/DartError/AXTree/unhandled；`llm.jsonl` challenge/
  install/models/chat 共 24 个响应全 200，9 个 chat request/response 均留档。证据摘要、成功/拒绝截图和抽帧已封存于
  `.../evidence/`。
- `judge.py` 在锚点校准通过且先验警报 clean 后独立落账 `TOOL-026 create_handler` 五格：L1 `G1`、L2 `F2`、
  L3 `A5`、L4 `C4`、L5 `G2`。每格后 `gap-too-fast` 与 `discovery-collapse` 按本格正/负证据复审并 ack，最终
  `alarms.py check` 为 `clean (170 judgments on record)`。
- 第四批从 **15 / 50** 推进至 **20 / 50**；下一前线为 `TOOL-027 edit_handler`。未到第四批 50 格不跑统一长门禁、
  不提交。
