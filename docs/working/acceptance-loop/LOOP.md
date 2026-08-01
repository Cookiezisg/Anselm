---
id: WRK-093
type: working
status: active
owner: "@weilin"
created: 2026-08-01
reviewed: 2026-08-01
review-due: 2026-10-30
audience: [human, ai]
landed-into:
---

# WRK-093 · 验收循环执行协议

本页是持久 Goal 的执行协议。Goal 保存不可变的最终目标与完成定义；本页规定每次 loop 唤醒时只做
什么；`README.md`、`LOG.md`、`COVERAGE.md`、`JOURNEYS.md`、`CODEX.md`、`ANCHORS.md` 和
`testend/rig/README.md` 保存规则、前线、证据账和台架操作事实。三者不互相复制长清单。

## 批次边界

`BATCH_SIZE = 50`，单位是 COVERAGE 中的**单格裁决**，不是旅程数量，也不是“看起来测过”的页面数。
每一格仍必须独立具备真实用户路径、五通道证据、适用法条/测量值和产品判断；发现问题仍在当格立即
冻结、修复、复验和同类横扫，不能把缺陷拖到批次末尾。只有累计完成第 50 格后，才统一执行一次：
收台封存录像、`alarms.py check`、完整 `make verify`、完整 `go test ./...`、已修场景回归、工作树
审计和 git commit。批次中允许运行针对单个修复的快速守卫测试，但不重复执行这套长门禁。

批次计数写入 `LOG.md`。跨上下文恢复先读取批次计数；若上一次在批次中途结束，继续同一批，不重置
计数、不提前提交。第一批可以包含当前已完成但尚未提交的 Day 0 台架与协议建设，提交时一并固化。

## 当前前线（2026-08-01 22:20）

第五批已达到 **50 / 50**：`TOOL-033` 至 `TOOL-046` 均完成五级真实裁决，中央账本为 `280 judgments`，锚点校准有效，警报复审后 clean。最后一格 `TOOL-046 search_control` 使用 formal-102：真实 App 命中 `acceptance_control_fixture_102`，负路径 `zzqvulon_102` 返回空集；三路 SSE 均连接且 `messages 1..28`、`notifications 1..5` 连续，LLM 状态全 200，前后端无未解释红线，录屏 `114.528333s / 2784x1808 / 60fps` 已封口。formal-98/100 的 AXTree 观察红证据保留并已促成稳定语义节点、定向测试和 rig-check 红线修复；formal-102 的证据文件为 `/private/tmp/anselm-rig-formal-102/sessions/20260801-221506/evidence/tool-046-formal-102-green.txt`。fixture 已 DELETE=204 并复核清零。统一长门禁、完整 testend、专项回归、锚点/警报/工作树/进程/diff 审计均已通过，并已提交 `90f51edd`；下一前线为 `TOOL-047`。

## 唤醒协议

每次 loop 必须按以下顺序执行：

1. 读取 [README.md](README.md) 与 [LOG.md](LOG.md)，取得当前前线、开放问题和上次收台位置；再只读
   本轮相关的 COVERAGE、JOURNEYS、CODEX 和台架手册。
2. 运行 `rig-check.sh` 和锚点校准。台架或锚点不绿时，只修台架/裁判系统，不评价产品。
3. 选择一个**最小但完整的产品切片**：一个真实用户目的，或一条旅程中的一个独立站点。切片必须
   能从用户入口走到可验证结果；不按“本轮多盖多少格”倒推范围。
4. 真实启动 App、真实连接受管网关，用 Computer Use 操作；同步观察帧、后端、三路 SSE、Flutter
   console 和 LLM wire。录制操作前、中、后的完整区间，不能只截成功终态。
5. 在该切片驻停清扫适用的正常、空、加载、错误、边界、窄窗、双语、reduced motion 和难触发
   路径。产品目的未达成，或视觉上任何一点不舒服，切片保持未完成。
6. 一旦发现问题，冻结前线并直接修复。修复必须带守卫测试和同步文档；随后逐帧重跑原路径，并
   横扫同类组件/状态，确认修复不是单点补丁后才能解冻。
7. 只能通过 `judge.py` 更新 COVERAGE。pass/fail 必须有真实证据与 CODEX 法条或测量值；不能用
   一次模糊证据批量覆盖不同状态，不能手改格子。
8. 每个切片收尾将证据 session、修复、未决红格和当前批次计数写进 `LOG.md`。达到第 50 个单格时，
   才运行 `alarms.py check`、收台、`make verify`、完整 testend、已修场景回归并提交；批次中只跑
   与当前修复直接相关的快速守卫测试。
9. 没有外部阻塞时立刻选择下一个切片；遇到需要用户拍板的产品形状问题，按 §6 记录并继续不依赖
   该决定的前线。不得用假设把它判绿。

## 反退化护栏

- 一次 loop 只能推进一个最小完整切片，不以时间或 token 预算驱动吞吐。
- 上一轮仍有 live rig/session 时，不得另起第二套台架；先检查并接管/收尾已有会话。
- 锚点凭证过期、警报开放、五通道缺失、前端红行、后端未解释错误或证据不完整时，禁止新增
  `pass`。
- 每次上下文恢复都从盘上文件和当前 git 状态恢复；不信任对话记忆中的“已经测过”。
- 后续修复触及已绿的原语、组件、token、路由或数据结构时，相关旧裁决自动回到待复验队列。
- 质量标准恒定：边角、错误态、降级态与主路径同样要求达到 craft bar。

## 停止条件

Loop 只有在 Goal 的完成定义全部满足时才能停止并将 Goal 标记 `complete`。单轮结束、当天结束、
上下文耗尽、速度变慢或某个区域暂时困难，都不是完成条件。若同一外部阻塞连续三次阻止有意义进展，
只能按 Goal 机制标记 blocked，并在 `LOG.md` 写清楚阻塞证据；不能用“暂时不测”伪装完成。

## 当前配置状态

2026-08-01 21:56 (+0800)：`TOOL-045 get_agent_execution` formal-97 真实 App + 受管网关 + Computer Use 完成正向单条 detail 与负向不存在 ID。正向完整显示顶层审计字段、input/output 和两条 transcript；raw REST/LLM wire/UI 一致，off-chat loop block 的空 id/message/seq/status/零值时间由 `messages.Block` 的“落共享 message store 才分配元数据”契约解释，前端 hydration 以 `hblk_*` 兜底，不伪造字段。负向只调用一次并显示 `agent execution not found`，无 retry/其它工具/写操作。session screen.mov `286.645000s / 2784x1808 / 60fps`，SSE durable `notifications 1..3`、`entities 1..4`、`messages 1..28` 连续，LLM 18 个状态 200，backend 仅预期 not-found WARN，frontend 无红线；fixture agent/conversation DELETE=204，台架已收台。`TOOL-045=G1/F2/A5/C4/G2` 已落账，锚点 10/10 通过，警报复审并 ack 后中央 clean(275 judgments)。Goal API 与盘上协议均为 `active`；第五批 **45 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-046 search_control`。

2026-08-01 21:40 (+0800)：`TOOL-044 search_agent_executions` 的 formal-95 两轮红证据已保留：首轮 Computer Use 输入污染造成越界生命周期操作；clean retry 暴露列表携带完整 transcript、模型改写 opaque cursor 导致分页重叠。前线修复为列表裁剪 transcript、工具/schema 强化 cursor byte-for-byte 契约，并补 store/tool 回归测试与同步文档。formal-96 真实 App + 受管网关 + Computer Use 完成正向 2+1 无重叠分页和负向 `status=failed` 空结果，五通道一致：screen.mov `414.928333s / 2784x1808 / 60fps`，SSE durable `notifications 1..5`、`entities 1..12`、`messages 1..49` 连续，LLM 28 个状态响应全 200，frontend 无红线，backend 无 WARN/ERROR/PANIC/FATAL；fixture agent/conversation DELETE=204，台架已收台。`TOOL-044=G1/F2/A5/C4/G2` 已落账，锚点 10/10 通过，警报复审并 ack 后中央 clean(270 judgments)。Goal API 与盘上协议均为 `active`；第五批 **40 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-045 get_agent_execution`。

2026-08-01 21:13 (+0800)：`TOOL-043 invoke_agent` 已完成红证据冻结、修复、新二进制真实复验和五级裁决。formal-93 暴露执行失败误用实体编辑 draft/version 丝带；已新增 `AnHonesty.failedRun`，按 create/edit/run 分流并同步双语文案、W4 守卫测试和 frontend 文档，定向测试 13/13 通过。formal-94 真实 App + 受管网关 + Computer Use 完成正向 `search_agent → invoke_agent` 和负向不存在 ID 单次 invoke：结构化结果 answer=4、confidence=1；负向准确显示 `agent not found`，无 executionId、无 retry、无其它写操作，Activity 显示 `Run failed · inspect the error below`。session screen.mov `236.766667s / 2784x1808 / 60fps`，三路 durable `messages 1..39`、`entities 1..4`、`notifications 1..3`，LLM 20/20 状态 200，backend 仅刻意负路径 WARN，frontend 无红线；REST/SQLite/UI/SSE/LLM wire 一致。agent、conversation 已 DELETE=204→GET=404，成功 execution 保留，台架已收台无残留进程。`TOOL-043=G1/F2/A5/C4/G2` 已落账；锚点 10/10 通过，警报复审并 ack 后中央账本 clean(265 judgments)。Goal API 与盘上协议均为 `active`；第五批 **35 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-044 search_agent_executions`。

2026-08-01 20:49 (+0800)：`TOOL-042 update_agent_meta` 已完成前线冻结、修复和新二进制复验。formal-91 的乐观 user bubble/durable prelude 瞬态重叠保留为红证据；修复 `ConversationTranscript.applyFrame` 的 REST hydration/prelude 跨层幂等，并补 model 回归测试后，定向 Flutter 48 项测试全绿。formal-92 真实 App + 受管网关 + Computer Use 正向只执行一次精确元数据更新，负向不存在 ID 只执行一次并显示 `agent not found`，逐帧无重复气泡、无 retry；session screen.mov `415.496667s`，三路 durable `messages 1..47`、`entities 1..4`、`notifications 1..7`，LLM 24/24 状态 200，backend 仅预期负路径 WARN，frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线，REST/SQLite/LLM wire 一致。所有 fixture DELETE=204→GET=404，execution 历史保留，进程已清零。五级裁决 `G1/F2/A5/C4/G2` 已由 `judge.py` 落账；中央账本 260 条，锚点通过，gap-too-fast/discovery-collapse 经本 session 复审并 ack 后 `alarms.py check` clean。Goal API 与盘上协议均为 `active`。第五批推进至 **30 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-043`。

2026-08-01 19:22 (+0800)：`TOOL-039 edit_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。formal-85 先修正并锁定工具/文档契约：LLM `edit_agent` 是 partial merge，HTTP `:edit` 才是 full snapshot；定向 agent/tool 测试与 docs verify 通过。真实 onboarding 创建隔离 workspace，再由 REST 构造带 skill、knowledge document、function mount 的 v1；真实 App 正向只改 prompt，UI 显示 v1→v2、version id 和“其它字段已保留”，REST activeVersion、mount-health、三条 equip relation 与 SQLite 只有 v1/v2 一致。负向不存在 ID 只执行一次 edit_agent，显示 `agent not found`、`Draft unsaved · truth is still the last version`，无 retry；逐 body 复原确认后续请求里的历史 tool_calls 是上下文回放，非重复执行。五通道：录屏 `290.713333s / 2784x1808 / 60fps`，LLM 7 request bodies/9 responses 全 200，SSE durable `messages 1..36`、`entities 1..4`、`notifications 1..15` 无 gap，backend 仅预期 not-found WARN，frontend 除 Computer Use 诱发 AXTree bridge 噪声外无 Flutter/Dart/RenderFlex/Unhandled/Exception；formal-84 无 CU 基线已对照确认噪声来源。agent/skill/document/function/conversation 均 DELETE=204→GET=404，关系归零，进程组已收台。警报复审并 ack 后 `clean (245 judgments)`。本批新单格 **19 / 50**，不跑统一长门禁、不提交；下一前线 `TOOL-040 revert_agent`。

2026-08-01 19:10 (+0800)：`TOOL-038 create_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。formal-81 先发现真实产品缺陷：首轮发送时 scoped SSE 尚未接上，乐观 user bubble 未被 durable 回声收敛，画面出现重复问句；已在普通 send 增加窄 REST head reconcile，并用 retry 参数保持重生成的同 bubble 语义，Flutter 37 项定向测试通过。formal-82 又发现用户明确提供 agent description 时托管模型漏发 `description`，造成创建成功但 REST 元数据为空；已收紧 `create_agent` 工具契约、schema 描述、后端守卫测试和领域文档。formal-83 修复后由真实 App + managed gateway + Computer Use 完成正负路径：正向 exact description/name/prompt 写入 wire、entities、REST 与 UI 一致；负向重复名只执行一次 `create_agent` 并显示可解释失败，无 retry/副作用。formal-84 无 Computer Use 的基线 session 中 frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线；formal-83 动态 AX 查询期间出现的 `AXTree` bridge 行经基线对照归类为观察器诱发噪声，不作为 App 红线。五通道、录屏、终帧、fixture/对话 DELETE=204→GET=404 和 SQLite `deleted_at` 均保留，警报复审并 ack 后 `clean (240 judgments)`。本批新单格 **18 / 50**，不跑统一长门禁、不提交；下一前线 `TOOL-039 edit_agent`。

2026-08-01 18:40 (+0800)：`TOOL-037 get_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。formal-80 严格正向最终字段表完整，负向不存在 ID 单次失败且无 retry；前置 setup 400、Bash 污染和中途未完成截图均未进入绿证据。五通道、视觉终帧和清理回执保留，警报复审后 `clean (235 judgments)`。本批新单格 **17 / 50**，不跑统一长门禁、不提交；下一前线 `TOOL-038 create_agent`。

2026-08-01 18:30 (+0800)：`TOOL-036 search_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`；共享 `ContentSearch` 影响的旧绿格 `TOOL-014 search_function`、`TOOL-024 search_handler` 已用正式 session `/private/tmp/anselm-rig-formal-20260801-79/sessions/20260801-181753` 复验命中/空 query/identifier no-match 六条路径并恢复五级绿。formal-78/79 的五通道、录屏和终帧均保留；统计警报复审并 ack 后 `clean (230 judgments)`。本批新单格累计 **16 / 50**（旧格复验不重复计数），不跑统一长门禁、不提交；下一前线 `TOOL-037 get_agent`。

2026-08-01 18:16 (+0800)：`TOOL-036 search_agent` 已在正式 session `/private/tmp/anselm-rig-formal-20260801-78/sessions/20260801-181026` 完成真实三路径，但尚未裁决。正向名称命中、空 query 列全库、identifier-shaped `zzqvulon_78` 0 命中均由 UI、LLM wire、三路 SSE、backend/frontend journal 和 SQLite/REST 清理事实交叉验证；录屏 `259.898333s`，五通道摘要与三张终帧已保留。修复触及共享 `ContentSearch`，所以 `search_function`、`search_handler` 等旧搜索绿格先进入待复验，不能直接 judge TOOL-036。本批仍 **15 / 50**，不跑统一长门禁、不提交。

2026-08-01 18:07 (+0800)：固定修复后的 `TOOL-036 search_agent` session `/private/tmp/anselm-rig-formal-20260801-77/sessions/20260801-180355` 已收台，录屏为 `197.091667s`，五通道 journal 和证据保留；fixture `ag_c60a92bcc799a856` 已由真实 DELETE=204、GET=404 和 SQLite `deleted_at` 三重对证，后台进程组无残留。本 session 仍**未裁决**：它包含共享搜索语义原语的修复后正式路径，必须先完成摘要和旧搜索绿格复验范围审查，不能把清理动作当作产品验收。Goal API 仍为不可恢复的 `blocked`，没有创建重复 Goal 或伪造完成；盘上执行协议保持 active。本批仍 **15 / 50**，不跑统一长门禁、不提交，继续 TOOL-036。

2026-08-01 17:58 (+0800)：第五批从 **10 / 50** 推进至 **15 / 50**。`TOOL-035 get_handler_call` 正向在真实 App 中单次读取 `hcl_47cfc89610c56086`，完整显示 method/status/input/output/elapsedMs/logs（含 `trace-call-start`）；负向对不存在 `hcl_0000000000000000` 单次失败，UI 显示 `handler call not found`，无 retry 或其它工具。正式 session `/private/tmp/anselm-rig-formal-20260801-75/sessions/20260801-174951` 的录屏为 `173.071667s`，LLM 16 个响应全 200，三路 SSE durable 序列 `messages 1..28`、`entities 1..4`、`notifications 1..5` 连续，frontend 无红线，backend 仅预期负路径 WARN，SQLite/REST/UI/LLM wire 一致；fixture 与 acceptance 对话已 DELETE=204、GET=404，证据保留。五级裁决 `G1/F2/A5/C4/G2` 已落账，锚点通过，三条警报复审并 ack 后 `clean (215 judgments)`。本批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-036`。

2026-08-01 17:47 (+0800)：第五批从 **5 / 50** 推进至 **10 / 50**。`TOOL-034 search_handler_calls` 的 session 72 因长提示中的辅助步骤污染、session 73 因托管模型将 `limit` 发成 `"2"` 而触发后端类型错误，均保留为红证据；前线冻结后按既有执行边界先例接受精确十进制字符串，补守卫测试与领域/工具文档。正式五通道 session `/private/tmp/anselm-rig-formal-20260801-74/sessions/20260801-174220` 首次调用即接受 wire 上的 `limit:"2"`，没有红色失败卡或 retry；UI、REST、SQLite、LLM wire、三路 SSE、backend 和 frontend 日志交叉一致，分页回执与全匹配集聚合均可见，抽帧未发现视觉缺陷。fixture 与 acceptance 对话已真实 DELETE，GET 404/`deleted_at` 对证；五级裁决 `G1/F2/A5/C4/G2` 已落账，锚点通过，警报复审并 ack 后 `clean (210 judgments)`。本批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-035 get_handler_call`。

2026-08-01 17:26 (+0800)：第五批当前完成 **5 / 50**。`TOOL-033 restart_handler` 在正式 session `/private/tmp/anselm-rig-formal-20260801-71/sessions/20260801-172125` 由真实 App 严格执行 `search_handler → call_handler(bump) → restart_handler → call_handler(bump) → get_handler`，两次 count 均为 1，active v1、method、envStatus=ready、runtimeState=running 保持不变；LLM 20 个响应全 200，messages/entities/notifications durable `1..42`、`7..8`、`16..21` 无 gap，backend/frontend 无未解释错误，最终画面含工具序列表与六行断言表。前置 session 70 因 `type_text` 丢失中文约束而越界，保留为 setup-contamination 红证据，未计入裁决；正式 fixture 与对话已真实 DELETE，GET 404/SQLite `deleted_at` 对证。五级裁决 `G1/F2/A5/C4/G2` 已落账；警报复审后 `clean (205 judgments)`。本批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-034 search_handler_calls`。

2026-08-01 17:06 (+0800)：第四批已完成 **50 / 50**。`TOOL-032 update_handler_meta` 真实验证自然语言找 handler、初次 bump 得 count 1、只改 name/description/tags、版本/env/方法/驻留实例不变，二次 bump 得 count 2；不存在 ID 只执行一次并返回 `handler not found`，未用 edit/restart/retry。session `/private/tmp/anselm-rig-formal-20260801-69/sessions/20260801-161542` 的 screen.mov 为 `298.946667s / 2784x1808 / 60fps`，LLM 21 个响应全 200，messages/entities/notifications durable `1..116`、`7..8`、`16..21` 连续，frontend 无 Flutter 红线，backend 仅一条刻意 not-found WARN；fixture 与 acceptance 对话已 DELETE 并分别 GET 404，抽帧 `evidence/frames/tool-032-220.jpg`、`tool-032-260.jpg`、`tool-032-295.jpg` 逐帧复核无视觉缺陷。统一长门禁发现 workflow agent 的 MediaRef receipt 被 prose 脱敏误伤，已修复为 workflow 数据保留、chat prose 脱敏，并通过 loop 守卫与两个媒体 workflow 定向回归。`make verify`、backend 全量 Go 测试、`make -C backend testend`、testend 全包、锚点、警报、diff、fixture 和进程审计均通过；`alarms.py check` 为 clean(200 judgments)。本批次现在一次性提交，下一前线为 `TOOL-033 restart_handler`。

2026-08-01 16:15 (+0800)：第四批当前完成 **45 / 50**。`TOOL-031 update_handler_config` 的前置 session 54 暴露受管 ASR 握手失败后 Composer 停在 `Finishing 00:00`，已修复 `speech_input_provider.dart` 并通过 5/5 守卫测试；session 67 又暴露旧工具描述让模型把 init config 错送进 `call_handler`，已冻结并修复描述、执行边界、handler 测试和领域/提取文档。干净 session `/private/tmp/anselm-rig-formal-20260801-68/sessions/20260801-160415` 真实完成 `warm→cool→default` 三次配置更新，每次 bootId 变化、prefix 保持；不存在 handler 的负路径只执行一次并返回 `handler not found`，无重试。fixture `hd_c6b5cbdd36c1aa92` 已由真实 DELETE API 删除，GET 404，历史审计证据保留。screen.mov `221.563333s / 2784x1808`，LLM 26/26 状态 200，messages/entities/notifications durable `1..102`、`1..2`、`1..8` 连续，frontend 无 Flutter 红线，backend 只有一条刻意 not-found WARN；最终文本无机器 ID/时间戳，tool card 保留原始真值。五级裁决 `G1/F2/A5/C4/G2` 已落账；锚点复校后两条统计警报已写复审结论并 ack，`alarms.py check` 为 clean(195 judgments)。下一前线为 `TOOL-032 update_handler_meta`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 14:46 (+0800)：第四批当前完成 **35 / 50**。`TOOL-029 delete_handler` 首轮真实会话发现两个产品/契约问题：工具回执只有 `{id,deleted}`，没有承诺的 retention 真相；失败卡片把不存在 ID 的失败说成过去式“已删除”。前线冻结后修复 `manage.go` 返回结构化 `retention`（handler soft_deleted、versions retained_for_audit、sandbox destroy_requested_best_effort、actions not_found），补 `handler_test.go`、handler domain/tool/COVERAGE 文档，并在中英 locale 和 widget test 中改为 `deleteFailedKind`。最终 session `/private/tmp/anselm-rig-formal-20260801-50/sessions/20260801-143835` 使用新 fixture `hd_ae18f91613773bad`，真实 App 正向只调用一次 delete_handler，UI 展示 retention、五项验证和后续 get_handler not-found；SQLite 证明 deleted_at、v1/v2 保留、环境 0 行、关系 0 行。负路径在同一真实 App 中经过危险调用人闸后只调用一次不存在 ID，卡片显示 `Delete handler failed · failed`，最终报告为 `handler not found` 且无副作用。screen.mov `191.041667s`、`2784x1808`、60fps；LLM 20/20 状态 200；SSE messages/entities/notifications durable `1..51`、`1..4`、`1..12` 连续，500 stream frames、三流各连接一次；frontend 无 Flutter/Dart/RenderFlex/Unhandled/SEVERE，backend 仅三条可解释负路径 WARN。五级裁决 `G1/F2/A5/C4/G2` 已落账；警报两条因同批复核而开，均以正负抽帧、五通道 journal 与数据库证据复审后 ack，`alarms.py check` 为 `clean (185 judgments on record)`。下一前线为 `TOOL-030`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 13:35 (+0800)：第四批当前完成 **30 / 50**。`TOOL-028 revert_handler` 的 session 42–45 作为红证据保留：前置 edit 依次暴露 `updateMethod`、`kind:set_method`、`set_method_description` 等不规范形状；将 edit 前置与回退切片分离后，session 45 又真实暴露 hosted model 把 `version` 发成字符串。修复 `backend/internal/app/tool/handler/manage.go` 的专用参数边界：公开 schema 仍为 integer，仅接受精确十进制整数串，并以测试拒绝小数、数组、布尔、文字和非正数；同步 handler 领域文档。最终 session `/private/tmp/anselm-rig-formal-20260801-46/sessions/20260801-132558` 由规范 REST fixture 先建立 v2，再由真实 App 单次回退到 v1，另执行一次 version 999 负路径；主路径 active v2→v1、v2 历史保留、env ready、runtime running、resident restarted，负路径精确 `handler version not found` 且无指针/版本/重启副作用。录屏 `258.636667s`、`2784x1808`，LLM 全状态 200，messages/entities/notifications durable `1..91`、`7..8`、`16..21` 连续，frontend 无 Flutter 红线，backend 仅预期拒绝 WARN，SQLite/REST/UI/LLM wire 一致。五级裁决 `G1/F2/A5/C4/G2` 已落账，警报复审后 `clean (180 judgments on record)`。下一前线为 `TOOL-029 delete_handler`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 13:07 (+0800)：第四批当前完成 **25 / 50**。`TOOL-027 edit_handler` 的前两次真实会话作为红证据保留：托管模型先发 `methodName`，再发 `method` 加顶层字段，均与公开 `{op,name,patch}` 契约不一致；前线冻结后，在执行边界加入仅针对该已知 hosted-model alias 的窄归一化，公开 schema 保持严格，补齐 handler 守卫测试、工具描述和领域文档。修复后的真实窗口绑定会话 `/private/tmp/anselm-rig-formal-20260801-41/sessions/20260801-125948` 覆盖成功路径（精确生成 v2、更新 `place` 描述、env ready、resident 从 stopped 重启为 running）和负路径（不存在 method 被拒绝、无 v3、active 仍为 v2）；screen.mov `160.443333s`、`2784x1808`，LLM 26 个状态全 200，messages/entities/notifications durable `1..57`、`7..8`、`16..22` 连续无 gap，frontend 无 Flutter 红线，backend 仅预期拒绝 WARN，SQLite/UI/LLM wire 一致。五级裁决 `G1/F2/A5/C4/G2` 已落账，警报复审后 `clean (175 judgments on record)`。下一前线为 `TOOL-028 revert_handler`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 12:43 (+0800)：第四批当前完成 **20 / 50**。`TOOL-026 create_handler` 在真实窗口绑定台架
`/private/tmp/anselm-rig-formal-20260801-38/sessions/20260801-123643` 收尾：首轮发现 hosted model 把
声明为 array 的 `ops` 发成 JSON-encoded array string，冻结并修复 create/edit 共用解码边界、补守卫测试和同步
工具描述；修复后一次成功创建 `acceptance_handler_minimal_probe`（2 ops、v1、env ready），一次缺 method
拒绝（后端原文 + UI `Draft unsaved · nothing was created`），无 create 重试、SQLite 无负向实体。录屏
`256.185000s`、`2784x1808`，LLM challenge/install/models/chat 共 24 个响应全 200，messages durable `1..53`、
entities `7..12`、notifications `16..22` 无 gap，frontend 无 Flutter 红线，backend 仅刻意业务拒绝 WARN；五级
裁决 `G1/F2/A5/C4/G2` 已落账，警报复审后 `clean (170 judgments on record)`。下一前线为 `TOOL-027 edit_handler`。
未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 12:05 (+0800)：第四批当前完成 **15 / 50**。`TOOL-025 get_handler` 已由固定真实会话
`/private/tmp/anselm-rig-formal-20260801-32/sessions/20260801-115554` 收尾：正常名称→搜索→ID→详情链返回完整
active version、方法体、configState/runtimeState；显式不存在 ID 只调用一次并显示 `handler not found`，另保留
名称误作 ID 的红反证。screen.mov `302.100000s` 可读，LLM 11 个 chat 请求/响应全 200，messages durable `1..61`、
notifications `16..19` 单调无 gap，entities 保持连接，Flutter console 无异常，backend 仅两条刻意 not-found WARN。
五级裁决 `G1/F2/A5/C4/G2` 均已落账；警报复审后 `alarms.py check` 为 `clean (165 judgments on record)`。
未发现代码或产品缺陷，未改代码；下一前线为 `TOOL-026 create_handler`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 11:55 (+0800)：第四批当前完成 **10 / 50**。`TOOL-024 search_handler` 已由固定真实会话
`/private/tmp/anselm-rig-formal-20260801-31/sessions/20260801-114544` 收尾：名称命中、空 query 全列出、
随机 no-match 三态均由真实 App + 受管网关完成，工具调用次数、参数和结果与 SQLite/LLM wire 一致；screen.mov
`264.113333s` 可读，LLM 8 个 chat 请求/响应全 200，messages durable `1..48`、notifications `16..17` 单调无 gap，
entities 保持连接，Flutter console 无异常，backend 无 WARN/ERROR。五级裁决 `G1/F2/A5/C4/G2` 均已落账；
警报复审后 `alarms.py check` 为 `clean (160 judgments on record)`。未发现代码或产品缺陷，未改代码；下一前线为
`TOOL-025 get_handler`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 11:43 (+0800)：第四批当前完成 **5 / 50**。`TOOL-023 get_function_execution` 已由固定真实会话
`/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-113505` 收尾：成功路径取回完整执行记录，
不存在 ID 路径只调用一次并展示明确失败、未重试；screen.mov `159.710000s` 可读，LLM `6` 个请求体与 `7`
个响应体状态均为 200，messages durable `1..28`、notifications `1..4` 单调无 gap，entities 保持连接，
Flutter console 无异常，backend 仅刻意 `function execution not found` WARN。五级裁决 `G1/F2/A5/C4/G2`
均已落账；两次警报复审均完成，`alarms.py check` 为 `clean (155 judgments on record)`。未发现代码或产品缺陷，
未改代码；下一前线为 `TOOL-024 search_handler`。未到第四批 50 格，不跑统一长门禁、不提交。

2026-08-01 11:15 (+0800)：第三批 `50 / 50` 已完成统一长门禁、完整 testend、专项回归、警报/锚点/diff/进程审计并提交 `eb1ee050`。第四批从 `0 / 50` 开始，下一前线为 `TOOL-023 get_function_execution`；继续遵守单作者、真实五通道、逐格 stop-and-fix，未到下一批 50 格不跑统一长门禁、不提交。

2026-08-01 11:09 (+0800)：第三批已完成 **50 / 50**。`TOOL-022 search_function_executions` 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103528` 暴露托管模型把分页 `limit` 发成字符串，严格 decoder 首次拒绝；按 stop-and-fix 修复 `search_function_executions` 执行边界，公开 schema 仍为 integer，同时兼容精确整数字符串并拒绝小数/数组/非数字字符串。固定会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-103839` 真实覆盖分页、failed/version 筛选、空结果和非法 status，screen.mov `420.495000s` 可读，backend 仅刻意 invalid-status WARN，frontend 仅已知 macOS 噪声，LLM chat-completion 状态响应全 200，messages/notifications durable `1..81`/`1..8` 单调，entities 保持连接；五级证据已落账，警报复审并 ack 后 `clean (150 judgments)`。之后统一长门禁全部通过：`make verify`、backend `go test ./...`、`make -C backend testend`、testend 全包、webhook 崩溃恢复专项、docs lint、anchors、alarms、diff 与进程泄漏审计均为绿。当前只剩最终工作树审计与本批次一次性提交，完成前不进入 `TOOL-023`。

2026-08-01 10:26 (+0800)：第三批当前完成 **45 / 50**。`TOOL-021 run_function` 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-100648` 暴露模型实际把显式版本发成字符串、并在不存在 ID 场景写错零串；第二轮在 schema 已明确 integer 后仍复现字符串化字段。按 stop-and-fix 修复执行边界，公开 schema 保持强类型但兼容精确整数字符串和字符串化对象；固定会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-101832` 真实一次成功执行 v2、一次不存在 ID 拒绝、一次缺参数执行失败，screen.mov `468.141667s`、2880x1800，backend 仅预期 WARN，frontend 仅已知 macOS 噪声，LLM 15 个响应全 200，messages/entities/notifications durable `1..75`、`1..4`、`1..6` 单调；五级证据已落账，警报复审并 ack 后 `clean (145 judgments)`。下一前线为 `TOOL-022 search_function_executions`；第三批未到 50 格，不跑统一长门禁、不提交。

2026-08-01 10:04 (+0800)：第三批当前完成 **40 / 50**。`TOOL-020 update_function_meta` 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-094939` 发现两项需冻结的问题：Computer Use `type_text` 吞掉字面下划线，导致模型把精确名称意图变成连字符；不存在 ID 的负路径中，模型把 `tags` 数组先序列化成字符串后才重试。修复工具描述和参数 schema，明确 JSON 对象示例、`tags` 必须为字符串数组且禁止逗号字符串；同时让 `rig-up` 初始化 `session/evidence/`，避免证据目录被首次截图转换误写成普通文件。修复后二进制会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-095616` 真实覆盖精确下划线 meta 更新和只传 name 的不存在 ID 拒绝：只一次 meta 调用、v1/代码/active version/env 不变、无 restart；错误路径干净 `function not found` 且无副作用。screen.mov `268.930000s`、2880x1800；backend 一条预期 WARN，LLM 24 个响应全 200，messages/notifications durable `1..73`/`1..5` 单调，entities 连接正常，frontend 仅已知 macOS 噪声。五级证据已落账，警报复审并 ack 后 `clean (140 judgments)`；下一前线为 `TOOL-021`。第三批尚未到 50 格，不跑统一长门禁、不提交。

2026-08-01 09:42 (+0800)：第三批当前完成 **35 / 50**。`TOOL-019 delete_function` 首轮真实会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-092832` 暴露了工具描述与持久化设计的契约冲突：主行是软删、不可变版本历史按设计保留，但旧报告错误声称“全版本删除”；该会话只作为反证保留，未判绿。修复 `backend/internal/app/tool/function/lifecycle.go` 的描述与返回结构、补工具测试并同步 API 文档后，在 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-093503` 由真实 App + 受管网关重跑：主行软删、版本审计保留、sandbox 回收、后续动作 not-found；成功与不存在 ID 失败路径均无错误副作用。修复会话 screen.mov 为 `466.838333s`、2880x1800；backend 两条预期 WARN（fixture 一次错误 ops 重试、一次刻意 not-found），LLM 22 个响应全 200，messages/entities/notifications durable 分别 `1..64`、`1..4`、`1..9` 单调，frontend 仅已知 macOS 平台噪声；SQLite 与 HTTP 交叉核对一致。五级证据已落账，五次警报均基于本次正负画面、录屏、五通道 journal、SQLite/HTTP 结果复审并 ack，最终 `clean (135 judgments)`。提取物与 COVERAGE 摘要已同步为 retention truth；下一前线为 `TOOL-020 update_function_meta`。第三批尚未到 50 格，不跑统一长门禁、不提交。

2026-08-01 09:25 (+0800)：第三批当前完成 **30 / 50**。`TOOL-018 revert_function` 真实覆盖既有 function 从 v2 回退到 v1 的成功路径，以及不存在 v999 的失败路径。成功路径证明 active pointer 从 v2→v1、无新版本、v2 仍在历史且环境 ready；失败路径两次业务拒绝均为 `function version not found`，随后真实 `get_function` 核验 active 仍为 v1，SQLite 无 v3、无指针副作用。会话 `/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-091433` 的 screen.mov 为 `490.781667s`、2880x1800；messages durable `1..86`、notifications `1..5` 单调无 gap/regression，entities 保持连接，LLM 2 个 challenge 与 26 个 chat 响应全 200，frontend 仅已知 macOS IMK 噪声，backend 仅两条刻意失败 WARN。五级证据已落账，五次警报均用该 session 复审并 ack，最终 `clean (130 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-019 delete_function`。

2026-08-01 09:12 (+0800)：第三批当前完成 **25 / 50**。`TOOL-017 edit_function` 真实覆盖 v1→v2 成功版本、代码 diff、env ready 与非法代码拒绝；模型为确认失败后真相额外调用了只读 `get_function`，日志如实保留，未发生其他写操作。最终会话
`/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-090605` 的 SQLite 只有 v1/v2 且 active 指向 v2，无 v3；screen.mov `206.015000s`，三路 durable seq 分别 `1..67`、`1..6`、`1..7` 单调唯一，LLM 20 个状态响应全 200，frontend 仅已知 macOS 平台噪声；五级证据已落账，警报复审后 `clean (125 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-018 revert_function`。

2026-08-01 09:01 (+0800)：第三批当前完成 **20 / 50**。`TOOL-016 create_function` 首轮真实新建失败路径发现 create 误用 edit 专属“上一版”诚实丝带；前线冻结后新增 `failedCreate` 双语文案、按 `create_*` 分流并补 create/edit 对称 widget 回归。最终会话
`/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-085503` 真实覆盖五操作成功创建与缺 `set_code` 的后端校验失败；SQLite 证明失败名无实体副作用，screen.mov `188.273333s`，三路 durable seq 分别 `1..51`、`1..6`、`1..7` 单调唯一，LLM 18 个状态响应全 200，frontend 仅已知 macOS 平台噪声；五级证据已落账，警报复审后 `clean (120 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-017 edit_function`。

2026-08-01 08:52 (+0800)：用户重新启用 Goal/Loop。已核对盘上只有一个 `active` Goal，未创建副本、未启用并行 agent；现有真实台架仍在运行，未另起第二套。执行协议恢复为单作者、单切片、五通道、发现即停修、每 50 个 COVERAGE 单格统一门禁并提交；当前批次仍为 **15 / 50**，不提前跑长门禁、不提交，接管前线 `TOOL-016 create_function`。

2026-08-01 08:44 (+0800)：第三批当前完成 **15 / 50**。`TOOL-015 get_function` 首轮真实 not-found 路径发现用户错误卡片泄漏
`functionapp.Get:` 内部 Go 路径；前线冻结后修复 `executeTool` 的用户错误出口并补回归测试，最终会话
`/private/tmp/anselm-rig-formal-20260801-30/sessions/20260801-083704` 重新覆盖完整活跃版本、环境 ready、
不存在 ID 的 clean error。录屏 `189.096667s`，三路 SSE 均连接，messages durable `1..43`、notifications `1..4` 单调，
entities 连接正常，LLM 18 个状态响应全 200，frontend 仅已知 macOS 平台噪声；首轮缺陷会话不用于判绿。
修复后的五级证据已落账，警报复审后 `clean (115 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为
`TOOL-016 create_function`。

2026-08-01 08:22 (+0800)：第三批当前完成 **10 / 50**。`TOOL-014 search_function` 在全新 workspace 中先构造
ready 的 `acceptance_search_probe` fixture，再以真实 App/gateway 覆盖 acceptance 命中、空 query、`FIXTURE`
大写 tag 命中和 zzznonexistent no-match；完整录屏 `506.090000s`，backend 无异常，frontend 仅已知 macOS 平台
噪声，LLM chat 48 个响应全 200，三路 SSE durable seq 单调。首轮 Computer Use 草稿拼接被排除，干净对话重新
执行；五级证据已落账，警报复审后 `clean (110 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为
`TOOL-015 get_function`。

2026-08-01 08:10 (+0800)：第三批当前完成 **5 / 50**。`TOOL-013 search_tools` 首轮真实 App/gateway 会话发现
`loaded_tools` 命中回执与前端旧 schema 不匹配、以及 transcript pending lazy builder 竞态；已停下修复，补齐
前端兼容、不可变快照和回归测试。第二次全新真实会话 `/private/tmp/anselm-rig-formal-20260801-29/sessions/20260801-080221`
覆盖命中与无命中路径，`rig-check` 五通道全绿，screen.mov `155.068333s`，backend 无未解释错误，LLM 14 个响应全 200，
messages durable seq `1..36`、notifications durable seq `1..2` 单调；`judge.py` 五格已落账，警报复审后
`clean (105 judgments)`。第三批尚未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-014 search_function`。

2026-08-01 07:48 (+0800)：第二批已完成 `50 / 50`。统一长门禁全部通过：正确台架 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 的 `alarms.py check` 为 `clean (100 judgments on record)`，锚点 10 题复核通过，`make verify`、完整 `testend` 模块测试、完整场景组和已修 webhook 崩溃恢复回归均为绿。下一前线为 `TOOL-013 search_tools`，提交本批次后继续逐格运行。

2026-08-01 07:17 (+0800)：用户暂停后重新启用 Goal/Loop。盘上唯一持久 Goal 仍为 `active`，未创建副本；本轮继续由单一作者执行，不启用并行 agent。执行计划已恢复为：第二批 `50 / 50` 的统一长门禁 → 全部通过后一次性提交 → 从 `TOOL-013 search_tools` 继续；门禁未全绿前不提交、不推进下一格。

2026-08-01 06:50 (+0800)：Goal/Loop 已恢复并完成真实续跑；已核对 Codex Goal 仍为唯一 `active` 实例，未创建副本；未启用任何并行 agent。`TOOL-004 LS`、`TOOL-005 Glob`、`TOOL-006 Grep`、`TOOL-007 Bash`、`TOOL-008 BashOutput`、`TOOL-009 KillShell`、`TOOL-010 ask_user`、`TOOL-011 todo_write` 与 `TOOL-012 todo_read` 台架均已按协议收台并完成五级裁决，证据保留；第二批已到 `50 / 50`，统一长门禁正在执行，下一前线为 `TOOL-013 search_tools`。

最新续跑事实：`TOOL-011 todo_write` 与 `TOOL-012 todo_read` 共用真实台架 `/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406`，覆盖部分清单读回、全部完成、零开放项后的真实 readback 与提醒抑制；五通道收台无未解释错误，警报复审后 `clean (100 judgments)`。第二批已到 `50 / 50`，现在执行统一长门禁，门禁通过前不提交。

2026-08-01：持久 Goal 已确认仍为 `active`（未创建副本）；Loop 协议已幂等重新装载；50 格批次策略保持不变。首批已计数
`50 / 50` 并提交 `b26f623e`；第二批当前计数为 `50 / 50`，已完成真实 `TOOL-003 Edit`、`TOOL-004 LS`、`TOOL-005 Glob`、`TOOL-006 Grep`、`TOOL-007 Bash`、`TOOL-008 BashOutput`、`TOOL-009 KillShell`、`TOOL-010 ask_user`、`TOOL-011 todo_write` 与 `TOOL-012 todo_read` 五级独立裁决；统一长门禁、完整 testend、已修场景回归、工作树审计和提交待执行。此前真实 onboarding→聊天→composer→场次条→日志抽屉→Read→Write 工具切片中 `EDGE-325`、`EDGE-326`、`SURF-003`、
`SURF-010`、`SURF-011`、`SURF-012`、`SURF-013`、`SURF-014`、`TOOL-001`、`TOOL-002` 的五级独立裁决。`SURF-012` 曾发现菜单打开命名模态后焦点被
退场菜单覆盖，已在共享 `AnPopover`/`AnMenu` 生命周期修复并由真实 App 复验；本批次长门禁又发现菜单命令等待动画 Future 导致 widget 行为延迟、以及窄 Gantt 行的 RenderFlex 溢出，均已修复并由完整 `make verify` 复验；随后完成流式输入、附件预览与读取、
实体 mention 候选/药丸/上下文注入、工作目录、git 分支与工作目录聊天连续性。完整 testend、根级 `go test ./...` 和警报复核也已通过；`SURF-013` 真实构造 51 个用户回合，
证明场次条第一页 50 条、第二页 2 条，场次条同时可见最新与最早锚点；turn 001 与 turn 027 深跳、`Jump to present`
回到现场均已逐帧复验。`SURF-014` 首轮发现长失败日志摘要失焦且伴随 AXTree 红行，已冻结并修复；修复后真实会话
`/tmp/anselm-rig-formal-20260801-8/sessions/20260801-030652` 复验成功/失败函数、MCP dossier、stderr 抽屉和 Copy→Copied，
前端、后端、LLM tap 与三路 SSE 均通过五通道检查。随后 `TOOL-001 Read` 真实覆盖整读、分页、缺失文件和越界保护，
`/tmp/anselm-rig-formal-20260801-9/sessions/20260801-032022` 五通道无红线。`TOOL-002 Write` 会话
`/tmp/anselm-rig-formal-20260801-12/sessions/20260801-033935` 首轮冻结了 completed 拒绝结果仍显示成功动词的真实缺陷；修复后
`Write failed existing.txt · read first` 与磁盘未改、SSE 仅 Write 无 Read、五通道无红线均已复验。`TOOL-003 Edit` 会话
`/tmp/anselm-rig-formal-20260801-14/sessions/20260801-044210` 完成 Read→Edit→Read 精确替换和无匹配只读拒绝；五通道、磁盘真相和两张关键画面均已复核。`TOOL-004 LS` 会话 `/tmp/anselm-rig-formal-20260801-17/sessions/20260801-050302` 真实覆盖直接列举、隐藏文件、空目录、嵌套非递归、缺失路径和非目录错误；首轮发现失败结果仍显示成功动词，修复 `lsResultFailed`/`listFailed` 后真实错误卡片显示 `List failed … · failed` 并自动展开正文，messages durable seq 1..40 单调，LLM 18 个响应全 200，录像 `213.276667s` 可读，`TOOL-005 Glob` 会话 `/tmp/anselm-rig-formal-20260801-19/sessions/20260801-051557` 首轮发现递归噪声目录契约未被模型理解，冻结后补齐后端 description/schema、前端失败重分类与守卫测试；修复后真实复验成功、空结果、截断、缺失根和非目录边界，screen.mov 可读，backend/frontend 无未解释错误，LLM 20 个响应全 200，三路 SSE 均连接且 messages durable seq 单调。`TOOL-006 Grep` 会话 `/tmp/anselm-rig-formal-20260801-22/sessions/20260801-054044` 首轮发现噪声目录泄漏、语义计数错误、错误态误报和非法正则 WARN，修复后真实覆盖 content/files/count/multiline/truncation/no-match/invalid-regex/missing-root，录屏 `269.225000s` 可读，backend 无 WARN/ERROR/panic/fatal，LLM 28 个响应全 200，messages durable seq 1..70、notifications durable seq 1..2 连续，三流均连接。`TOOL-008 BashOutput` 会话 `/tmp/anselm-rig-formal-20260801-24/sessions/20260801-060449` 又真实覆盖增量读取、regex 过滤、无新输出、缺失 bash_id 与非法 regex，录屏 `548.728333s` 可读，LLM 36 个响应全 200；`TOOL-009 KillShell` 会话 `/tmp/anselm-rig-formal-20260801-26/sessions/20260801-062334` 首轮发现重复终止语义冲突并完成共享卡片修复后重跑，LLM 32 个响应全 200、messages durable seq 1..76、notifications durable seq 1..2 连续；`TOOL-010 ask_user` 会话 `/tmp/anselm-rig-formal-20260801-27/sessions/20260801-063212` 真实覆盖等待态、选项回答和 `Don't answer` 跳过态，LLM 16 个响应全 200、messages durable seq 1..28、notifications durable seq 1..2 连续；`TOOL-011 todo_write` 与 `TOOL-012 todo_read` 会话 `/tmp/anselm-rig-formal-20260801-28/sessions/20260801-064406` 真实覆盖部分清单读回、全部完成与零开放项提醒抑制，LLM 26 个响应全 200、messages durable seq 1..64、notifications durable seq 1..2 连续；第二批十格工具切片的统计警报均经证据复审后销账，最终 `alarms.py check` 为 clean(100 judgments)。第二批达到 `50 / 50`，统一长门禁进行中，下一前线为 `TOOL-013 search_tools`。
