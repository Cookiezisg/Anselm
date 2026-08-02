---
id: WRK-092
type: working
status: active
owner: "@weilin"
created: 2026-08-01
reviewed: 2026-08-02
review-due: 2026-10-30
audience: [human, ai]
landed-into:
---

# WRK-092 · 验收战役日志

## 2026-08-02 18:05 · 第七批 TOOL-065 trigger_workflow 正式通过

- 首轮探索真实路径在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-174253` 冻结为红：托管模型把 `trigger_workflow.payload` 发成字符串，旧 `map[string]any` 边界拒绝后模型 retry；该路径保留为真实产品问题，不计绿。后续无 observer 的快速 exploratory run 只证明了回执，不承担 payload 证据，也在正式证据中明确排除。
- stop-and-fix：`backend/internal/app/tool/workflow/exec.go` 将参数收紧为 `toolapp.ObjectMap`，接受 native object 与精确 JSON object string，拒绝数组/数字/畸形字符串；同步 workflow 测试、领域文档和工具抽取清册。真实 App 复跑又发现 fast workflow 的 `run_terminal` 可能先于 tool receipt close 到达，Activity 永久停留 Running；`frontend/lib/features/chat/state/stage_director_provider.dart` 改为提前订阅 workflow terminal、按 flowrunId 缓冲并在 receipt close 后结算，补 `R-10` Flutter regression。
- formal-142 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-175457` 由新二进制、真实 App、真实受管网关、Computer Use、连续录屏、backend/frontend journal、三路 SSE witness 和 LLM tap 完成正式重跑。最终唯一 mutation 为一次 `trigger_workflow`，wire payload 是 JSON object string；flowrun `fr_363b14b855b3d924` REST 为 completed，trigger 节点保留 `amount=18240,currency=CNY`，observer 节点得到相同值。SSE 记录 `run_started`、observer tick 和同一 flowrun 的 `run_terminal`；App Activity 最终为 `Ran`，无 stale Running。
- 五通道收台：final `screen.mov`、`backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl` 均封存，LLM 响应全 200，backend/frontend 无未解释运行时红线；真实 DELETE 后 workflow/function/trigger、四个 conversation 均无 live 残留（其中一个 conversation 已先消失，DELETE=404 作为幂等清理事实保留），rig-down 已停止 backend/ssetap/llmtap/Flutter/recorder。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-175457/evidence/tool-065-formal-green-trigger-workflow.md`。
- 五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE。以正确 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 为准，账本从 360 增至 **365 judgments**；锚点刷新后通过，`gap-too-fast` 与 `discovery-collapse` 已按红绿证据复审并 ack，`alarms.py check` clean。Flutter 定向 19 项、Go workflow/loop 定向测试、`make -C docs verify` 与 `git diff --check` 通过；第七批从 **20 / 50** 推进至 **25 / 50**，下一前线 `TOOL-066 stage_workflow`，未到 50 格不跑统一长门禁、不提交。

## 2026-08-02 17:40 · 第七批 TOOL-064 capability_check_workflow 正式通过

- 首轮真实 App 发现两处产品缺陷：空 Go slice 在工具回执里变成 `null`，英文标题把单数写成 `1 warnings` / `1 problems`。stop-and-fix 后，后端稳定输出空数组，前端回执和展开 chip 走中英文单数/复数 i18n；定向 backend/loop/widget 测试通过。
- formal-141 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-173429` 真实重跑三条路径：正常 workflow 显示 `structurally runnable` 且 `problems:[]`/`warnings:[]`；悬空 trigger 显示 `1 problem` 并阻断 activation；undeclared output advisory 显示 `1 warning`，问题数组为空且不阻断 activation。
- 五通道通过：连续录屏、backend/frontend journal、三路 SSE 和 LLM tap 均归属于同一 conductor；SSE 恰有三次 canonical capability 调用，messages durable seq 单调至 44、notifications 至 5；无后端 panic/ERROR/WARN 或 Flutter runtime 红线。REST active lists 清空，fixture GET=404，SQLite 只留软删除审计行；rig-down 无残留进程。
- 正式绿证据：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-173429/evidence/tool-064-formal-green-capability.md`。五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本从 365 增至 370 judgments。集中写入五格触发 `gap-too-fast`，已写复审结论并 ack，`alarms.py check` clean。
- 第七批从 **15 / 50** 推进至 **20 / 50**；未到 50 格不跑统一长门禁、不提交。下一前线为 `TOOL-065 trigger_workflow`。

## 2026-08-02 17:20 · 第七批 TOOL-063 delete_workflow 静态危险等级修复后正式通过

- formal-140 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-171233` 继续同一真实夹具完成终验。模型在 LLM 线缆中仍自报 `danger:"safe"`，但静态 `DangerFloorer` 将有效危险等级提升为 `dangerous`；真实 App 逐帧停在 `Dangerous · Awaiting your approval`，没有被模型自报或 skill/approve-always 绕过。
- 获得本次临时夹具删除授权后，UI 只出现一次 `delete_workflow` 调用、一次 Allow、一次删除回执；最终文案明确主行不可恢复、没有 restore 操作，版本历史和 flowrun 仅作审计保留。
- 五通道交叉核验：Computer Use 终帧与连续 `screen.mov` 一致；backend journal 无 panic/ERROR/WARN；ssetap 记录一枚危险 interaction、一枚 resolved interaction 和一枚 `workflow.deleted`，messages durable seq 单调至 30、notifications 至 6；frontend console 无 Flutter/Dart/RenderFlex/Unhandled 红线；llmtap 只有一次 canonical `workflowId` 删除 tool call，所有网关响应成功。
- REST/关系真相：workflow GET=404 `WORKFLOW_NOT_FOUND`，versions GET=200 保留 v2/v1，trigger 清理前 `refCount=0/listening=false`，关系邻域为空；conversation 和 trigger 清理均 DELETE=204 后 GET=404，活动 fixture 列表为空。rig-check 五通道全绿，rig-down 停掉 Flutter/backend/ssetap/llmtap/recorder，五个 PID 均退出。
- 正式绿证据：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-171233/evidence/tool-063-formal-green-danger-floor.txt`。锚点复校通过，judge 前后 `alarms.py check` 均 clean；最终为 `clean (5 judgments on record)`，五级 `G1/F2/A5/C4/G2` 已落账，中央账本从 360 增至 365 judgments。
- 第七批从 **10 / 50** 推进至 **15 / 50**；未到 50 格不跑统一长门禁、不提交。下一前线为 `TOOL-064 capability_check_workflow`。

## 2026-08-02 05:27 · TOOL-063 delete_workflow 修复后等待不可逆人闸确认

- formal-136 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-045515` 首轮真实 App 暴露严重产品循环缺陷：一次 `delete_workflow` 获准并成功后，模型又重复发起同一危险 mutation，随后产生第二个人闸和失败卡。红证据已封存为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-045515/evidence/tool-063-formal-red-duplicate-mutation.txt`，不计绿。
- stop-and-fix：loop 增加 per-Run logical mutation ledger，只抑制同一回合内已经处理过的 dangerous/workdir-outside 重复调用；首个执行结果保留，后续重复调用落可解释 suppression result，不再二次审批或执行；补 loop 回归和 foundation 文档。随后真实 App 重跑证明 exact-once 已成立，但暴露第二个红点：模型在成功后声称「You can still recover the workflow if needed」。
- formal-137 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-050833` 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-050833/evidence/tool-063-formal-red-prose-placeholder.txt`；type-aware opaque redaction 修复后，formal-138 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-051526` 仍因错误恢复承诺冻结，证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-051526/evidence/tool-063-formal-red-recovery-promise.txt`。
- stop-and-fix：`delete_workflow` 描述明确主行 NOT restorable 且不存在 restore 操作，执行回执增加 `restorable:false`/`historyRetained:true`，chat critical rules 禁止模型从 soft-delete 推导恢复承诺；同步 workflow domain、tools extract，并通过 `go test -count=1 ./internal/app/tool/workflow ./internal/app/loop ./internal/app/chat` 与 `git diff --check`。
- formal-139 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-052255` 已重新起真实 onboarding、受管网关、五通道 conductor；真实 App 已完成关系查询和删除前说明，画面准确写明主行不可恢复、没有 restore operation，并停在 `Dangerous / Awaiting your approval`。补齐 v2 后 REST 证明 workflow active=v2、versions=[2,1]、trigger/ref relation 仍完整；rig-check 五通道全绿，backend/frontend/LLM/SSE 尚无未解释红线。
- 当前状态：该 fixture 的删除是不可逆动作，台架已收口但未点击 `Allow`，所以 `TOOL-063` 仍为 `·····`，不写 judge、不改中央账本；session 录屏/journal 保留，下一步是取得明确删除授权后从同一 fixture 完成五通道终验。第七批仍 **10 / 50**，不跑统一长门禁、不提交。

## 2026-08-02 04:53 · 第七批 TOOL-062 revert_workflow 正式通过

- formal-133 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-043458` 首轮真实 App 暴露 hosted model 将 `version` 发成字符串，旧执行边界拒绝后模型 retry；formal-134 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-044050` 在 decoder 修复后又暴露模型省略 `version`、先查 `get_workflow` 再 retry。两轮均冻结为红，不计绿。
- stop-and-fix：`revert_workflow` 执行边界接受 native positive integer 或 exact decimal integer string，浮点/布尔/数组/坏字符串继续拒绝；工具 schema/描述明确 `workflowId` 与 `version` 同一调用必填、禁止 inspect/retry、失败结果权威。补 Go 工具/loop 定向测试、workflow domain 文档和 tools extract。
- formal-135 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-044518` 通过真实 onboarding、受管网关、真实 App、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal 和连续录屏重跑。正向从 active v2 只调用一次 `revert_workflow`，wire 使用 `version:"1"`，UI 只有一张成功 `↩ v1` activity；负向只调用一次 version 999，精确显示 `workflow version not found`，无 retry、无 `get_workflow`。录屏 `257.141667s`，REST/SQLite 证明 active v1 且 v1/v2 历史保留，LLM response 全 200，frontend 无 runtime marker，backend 只有刻意负路径 WARN。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-044518/evidence/tool-062-formal-acceptance.txt`。
- fixture cleanup 已通过真实 REST 完成：两个 conversation 和 workflow 均 DELETE=204、GET=404，三类列表均为空；SQLite live conversation/workflow/trigger 为 0，tombstone 的 `deleted_at` 已写入，4 messages、12 message_blocks、2 workflow_versions、4 notifications 审计行保留；唯一 live workspace 未删除。cleanup rig-down 后无 server/ssetap/Flutter/recorder 孤儿。
- 锚点 `10/10` 重校准通过；五级裁决 `TOOL-062=G1/F2/A5/C4/G2` 写入 COVERAGE，中央账本从 355 增至 `360 judgments`。gap-too-fast/discovery-collapse 按红绿完整证据复审并 ack，`alarms.py check` 为 clean。第七批由 **5 / 50** 推进至 **10 / 50**，按批次纪律不跑统一长门禁、不提交，下一前线 `TOOL-063 delete_workflow`。

## 2026-08-02 04:32 · 第七批 TOOL-061 edit_workflow 正式通过

- 正向路径在真实 App、受管网关、Computer Use、三路 SSE witness、backend/frontend journal 和 LLM wire 上完成：既有 workflow 从 v1 编辑到 v2，描述、tags、trigger ref、changeReason 和 UI activity 与 REST/SQLite/SSE 一致。正向 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-041823`。
- 首轮探索性负向曾把 filesystem `Edit` 的 `file_path/old_string` 形状误发给 `edit_workflow`，造成一次 validation failure 和 retry；该红事实不计绿。stop-and-fix 强化 `edit_workflow` 描述/schema，明确它不是 filesystem Edit、`workflowId` 是实体 ID、`ops` 非空，并补 Go 回归；同时修复 New chat 清除 landing draft/附件的状态泄漏，Flutter 定向 22 项与 workflow/loop Go 定向测试通过。
- 修复后的正式负向从 clean landing 出发，对不存在的 `wf_missing_tool061` 只发一次合法 `edit_workflow`，UI 只有一张失败 activity，助手明确没有 search/create/retry/其它 mutation；正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-042438/evidence/tool-061-formal-acceptance.txt`。录屏、backend、三路 SSE、frontend、LLM 五通道文件均完整，前端唯一 error-like 启动文本是已知 Flutter runner foreground harness warning。
- fixture 已按真实 API 清理：conversation `cv_0c82ee3e7c62b0de`、workflow `wf_85ddbf59a68ba18b`、triggers `trg_698325b524506e16`/`trg_e79e9b41571591aa` 均 `DELETE=204` 后 `GET=404`；SQLite 审计行保留，live conversation/workflow/trigger 为 0，只有最后 workspace live，messages 无 in-flight。
- 锚点 `10/10` 重新校准；五级裁决 `TOOL-061=G1/F2/A5/C4/G2` 写入 COVERAGE，中央账本 `355 judgments`。gap-too-fast/discovery-collapse 因本次五格是同一已复核证据包的批处理落账而开启，已按正式正负证据重审并 ack，`alarms.py check` 为 clean。第七批 **5 / 50**，不跑统一长门禁、不提交，下一前线 `TOOL-062 revert_workflow`。

## 2026-08-02 04:04 · 第六批收口，第七批从 TOOL-061 开始

- 第六批 `TOOL-055` 至 `TOOL-060` 共 50 个单格已完成五级裁决；统一 `make verify`、完整 `make -C backend testend`、文档、锚点、警报、fixture 和进程审计全部通过，唯一提交为 `8e2c93e4`。
- 中央账本保持 `350 judgments`，`alarms.py check` 为 clean，goal API 与盘上协议均为 active。第七批计数重置为 **0 / 50**，下一前线 `TOOL-061 edit_workflow`；未到第 50 格不运行长门禁、不提交。

## 2026-08-02 03:47 · TOOL-060 漏元数据边界补强，长门禁仍待执行

- formal-129/130 已经证明，仅把 `description`、`tags`、`changeReason` 放进 hosted-model schema 不能阻断模型省略字段；formal-132 的 stringified metadata 正向证据证明兼容路径正确，但不覆盖漏字段风险。
- stop-and-fix：`create_workflow.ValidateInput` 在任何 mutation 前要求三个 metadata 键实际出现；无用户值必须明确传 `description:""`、`tags:[]`、`changeReason:""`。description/changeReason 的显式 `null`、tags 的显式 `null`/错误数组及非法类型均拒绝；精确 JSON 数组字符串兼容仍保留。新增 `WORKFLOW_DESCRIPTION_REQUIRED`、`WORKFLOW_TAGS_REQUIRED`、`WORKFLOW_CHANGE_REASON_REQUIRED` 并同步 error-codes、workflow domain、tools extract。
- 定向 `gofmt`、`go test -count=1 ./internal/app/tool/workflow ./internal/app/workflow ./internal/app/loop` 和 `git diff --check` 已通过。第六批仍为 **50 / 50**、中央账本 `350 judgments`、锚点有效、警报 clean；按纪律下一步执行统一长门禁，门禁通过后一次性提交，不启动 TOOL-061。
- fixture cleanup session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-040105` 使用真实 backend 的 DELETE API 清掉遗留 conversation `cv_54e1de6f05433171`：`DELETE=204`，随后 `GET=404 CONVERSATION_NOT_FOUND`，SQLite `deleted_at` 已写入，3 个 message blocks 按审计契约保留。全库 live 产品实体审计为 conversation/document/agent/function/handler/control/approval/workflow/trigger/MCP/attachment 均 `0`；唯一 live workspace 是产品要求保留的最后 workspace，未绕过 `CANNOT_DELETE_LAST_WORKSPACE`。cleanup rig-down 正常，无 backend/ssetap 残留。

## 2026-08-02 03:25 · 第六批 TOOL-060 create_workflow 正式通过并到达 50/50

- formal-128 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-025448` 首轮真实 App 冻结为红：模型先后把 `ops` 发成不兼容形状并重试，UI 留下失败活动；formal-129 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030431` 和 formal-130 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030934` 继续证明 metadata 槽位会被模型省略。三轮红证据保留，不计绿。
- stop-and-fix：workflow `create_workflow` 执行边界增加 `decodeWorkflowTags`，只接受原生 `[]string` 或精确 JSON 数组字符串，拒绝逗号分隔文本、对象和非字符串元素；保留公开 schema 的数组形状。同步更新 schema/工具描述、workflow 领域文档、tools 抽取清册，并补 native/stringified/malformed/metadata Execute 测试。`gofmt`、workflow/app/loop 定向 Go 测试和 `git diff --check` 通过。
- formal-131 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-031452` 真实 App 冻结为红：metadata 已进入 wire，但 generic argument decode 先因 `.tags` string→`[]string` 失败；无 workflow 落盘、无 retry。红证据为 `evidence/tool-060-formal-131-red-required-metadata-ops-error.txt`，function/trigger/conversation 已清理并 204→404。
- formal-132 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-032142` 以新二进制、全新 onboarding、真实受管 gateway、Computer Use、窗口录制、backend journal、三路 SSE witness 和 LLM tap 重跑。模型只调用一次 `create_workflow`，真实 wire 同时发出 stringified `ops`/`tags`；后端成功创建 `wf_c2d9dbcf972085a9` v1 inactive。REST 证明 description/tags/changeReason 原样、2 nodes/1 edge、concurrency serial；App 只有一张 `Created · v1 · Not activated` activity，没有 retry/get_workflow。backend/frontend 无未解释红线，LLM 请求响应全 200，rig-check 五通道全绿，四类资源 DELETE=204 后 GET=404，rig-down 正常。绿证据为 `evidence/tool-060-formal-132-green-stringified-metadata.txt`。
- 锚点校准通过；`judge.py` 五格 `TOOL-060=G1/F2/A5/C4/G2` 写入 COVERAGE，`✓✓✓✓✓`。gap-too-fast/discovery-collapse 在每轮裁决后均以 formal-131 红与 formal-132 绿的完整五通道证据复审并串行 ack，最终 `alarms.py check` 为 `clean (350 judgments on record)`。第六批由 **49 / 50** 收口为 **50 / 50**；按批次纪律现在执行统一长门禁，一次性门禁通过后提交，期间不启动 TOOL-061。

## 2026-08-02 02:53 · 第六批 TOOL-059 get_workflow 正式通过

- formal-127 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-024437` 使用真实 onboarding 建立 ready function、真实 cron trigger 和 trigger→action workflow。初始 test-only `trg_manual` ref 在正式正向前被替换为真实 cron source，形成 v2；REST capability-check 返回 `structurallyValid=true, resolved=true`。
- 正向真实 App 先验证 v1，再对 v2 只调用一次 `get_workflow`：App 展示 active version=2、lifecycleState=inactive、active=false、concurrency=replace、两个 node refs 和完整 `start_to_action` edge；点击 `Viewed workflow` 打开 workflow 实体信息，滚动后 edge 表完整可见。一次读取过早只看到异步结果表头，等待后 Computer Use 画面和 AX 树均完整，该中间帧不计红绿。
- 负向真实 App：不存在 ID 只调用一次，显示 `workflow not found`；空对象只调用一次，显示 `input validation failed: workflowId is required`；两条路径均无自动 retry、无伪造 graph。
- 五通道收台：录屏 `430.360000s`；SSE messages durable `1..58`、entities `1..2`、notifications `1..11` 单调；LLM observed response 24 个全 200；backend/frontend 无未解释运行时红线；REST workflow/versions/capability-check 与 tool result 一致。workflow、trigger、function、conversation DELETE=204 后列表为空、GET=404；rig-down 已收台。正式证据为 `evidence/tool-059-formal-127-green.txt`，v2、导航和负向终帧保留。
- 锚点有效，五级裁决 `TOOL-059=G1/F2/A5/C4/G2` 写入 COVERAGE；`gap-too-fast`/`discovery-collapse` 依据正式正负证据复审并串行 ack，最终 `alarms.py check` clean。本批由 **44 / 50** 推进至 **49 / 50**；未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-060 create_workflow`。

## 2026-08-02 02:42 · 第六批 TOOL-058 search_workflow 修复后正式通过

- formal-125 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-022906` 首轮真实 App 冻结为红：直接 `invoice` 查询返回 3 条，其中两个是弱语义邻居；结果卡缺少工具契约承诺的 `tags`、`lifecycleState`、`active`。红证据为 `evidence/tool-058-formal-125-red-search-fields.txt`，不计绿。
- stop-and-fix：`SearchWorkflow` 现在优先走 workflow 目录直接关键词匹配；只有无直接命中时才保留统一语义搜索，并对 semantic fallback hydrate 完整 workflow 字段。工具描述、抽取清册、COVERAGE 与 workflow 定向测试同步更新；公开统一搜索的语义召回不收紧。
- formal-126 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-023543` 用新二进制、真实 onboarding、受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。`invoice` 精确命中 1 条；随机 `zzqvulon_058_no_match` 返回 0；空 query 返回 3 条并逐行展示 name/tags/lifecycleState/active；点击 invoice 结果进入正确 Workflow 详情，展示 v1、inactive、描述、标签、精确 ID、1 node、No alerts。三次各只调用一次 `search_workflow`，无 retry/其它工具。
- 五通道：录屏 `317.481667s`；messages durable `1..38`、notifications durable `1..9` 单调；LLM observed response 全 200；backend/frontend 无未解释运行时红线；删除事件通过 notifications 流可见。conversation 与三个 workflow fixture DELETE=204，列表为空、GET=404；证据为 `evidence/tool-058-formal-126-green.txt`，录屏/完整 journals/导航截图均保留，rig-down 已收台。
- 锚点有效，五级裁决 `TOOL-058=G1/F2/A5/C4/G2` 写入 COVERAGE；`gap-too-fast`/`discovery-collapse` 依据 formal-125 红证据与 formal-126 五通道绿证据复审并串行 ack，最终 `alarms.py check` clean。本批由 **39 / 50** 推进至 **44 / 50**；未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-059 get_workflow`。

## 2026-08-02 02:23 · 第六批 TOOL-057 delete_approval 修复后正式通过

- fixture 已清理：formal-124 的 approval、workflow、trigger、conversation 均通过真实 DELETE=204 后 GET=404；versions endpoint 仍保留 v1/v2，这是软删除语义而不是遗留 fixture。formal session 与红绿证据目录保留，不删除审计证据。
- formal-123 `/private/tmp/anselm-rig-formal-123/sessions/20260802-020830` 首轮真实 App 冻结为红：UI 真实展示 `Dangerous · Awaiting your approval`，但批准后模型错误声称没有 gate，并误报“不可逆、所有版本移除”。红证据为 `evidence/tool-057-formal-123-red-gate-fact-and-delete-semantics.txt`，不计绿。
- stop-and-fix：增加 `messages.AttrHumanApproval`；`dispatchWithGate` 只有收到显式 approve/approve_always 才标记事实，tool result attrs 留下 `humanApproval=true`，`BlocksToAssistantLLM` 只向后续模型历史追加 `[Human approval granted before this tool executed.]`，可见 tool card 保持业务输出；补 loop gate 测试。`delete_approval` 描述、approval API/领域文档和 tools 清册同步改为软删主行、清关系、版本历史保留、需危险人闸。
- formal-124 `/private/tmp/anselm-rig-formal-124/sessions/20260802-021702` 使用新二进制、真实 App、受管网关、Computer Use、三路 SSE witness、LLM tap 和连续录屏重跑：真实 UI 只有一张 `Allowed` activity、`1 refs affected`，助手准确报告 gate 先展示并获批准；REST/SQLite 证明 approval GET=404、versions v1/v2 保留、关系清空，临时 capability-check 诚实报告引用缺失。messages durable `1..26`、notifications `1..11` 连续，entities 已连接，LLM observed responses 全 200，backend/frontend 无未解释红线；rig-down 已收台。
- 定向 `go test -count=1 ./internal/app/loop ./internal/app/tool/approval`、`gofmt`、`git diff --check`、`make -C docs verify` 均通过。锚点校准有效，五级裁决 `TOOL-057=G1/F2/A5/C4/G2` 写入 COVERAGE；中央账本从 330 增至 `335 judgments`，gap-too-fast/discovery-collapse 依据 formal-123 红证据与 formal-124 五通道绿证据复审并串行 ack，最终 `alarms.py check` clean。本批由 **34 / 50** 推进至 **39 / 50**；未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-058 search_workflow`。

## 2026-08-02 02:10 · 第六批 TOOL-056 revert_approval 修复后正式通过

- formal-121 `/private/tmp/anselm-rig-formal-121/sessions/20260802-015701` 首轮真实 App 冻结为红：托管模型将公开 schema 为 integer 的 `version` 发成字符串，后端返回 `cannot unmarshal string into Go struct field .version of type int`，App 出现失败 `Reverted approval … · failed` 活动，模型准备 retry；该路径不计绿。红证据为 `evidence/tool-056-formal-121-red-stringified-version.txt`，rig-down 后完整 journals 和 `screen.mov` 保留。
- stop-and-fix：`revert_approval` 公开 schema 继续保持 integer，工具边界增加 exact decimal integer string decoder；浮点、布尔、数组、零值和坏字符串仍拒绝。补 `approval_test.go` 的 native/stringified/malformed cases，更新工具描述和 `docs/references/backend/domains/approval.md`；`gofmt`、`go test -count=1 ./internal/app/tool/approval ./internal/app/loop`、`git diff --check` 通过。
- formal-122 `/private/tmp/anselm-rig-formal-122/sessions/20260802-020059` 使用新二进制、真实 onboarding、真实受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。REST fixture 先建 v1，再 HTTP edit 建 v2，active=v2。正向同一真实 App 对话只调用一次 `revert_approval`，wire 仍为 hosted-model stringified `version:"1"`，修复后无红卡、无 retry，UI 只有一张 `Reverted approval … · ↩ v1`，助手明确 v2 仍在 immutable history。
- 负向同一真实对话只调用一次 version 999，backend 返回 `approval form version not found`；UI 只有一张失败活动和诚实解释，明确 active v1 unchanged、no mutation，无 retry/第二工具。REST activeVersionId 为 v1，versions endpoint 恰有 v1/v2；SQLite 同样只有两版，未产生 v3。
- 五通道收台：`screen.mov` H.264 `2784x1808 / 100.383333s`；SSE 三流各连接一次，messages durable `1..29`、notifications `1..7` 唯一单调，entities 已连接但本切片无 durable entity 帧；LLM journal observed response 全 HTTP 200；backend 唯一 WARN 是刻意负向 version-not-found，无 panic/ERROR/FATAL；frontend runtime 与 AXTree marker scan clean。正负终帧已抽取并逐帧视觉复核，无裁切、重叠、残留 loading 或错误成功语义。
- cleanup：conversation `cv_d9f76af345371e53` 与 approval `apf_a71057c09f3b7f87` DELETE=204，随后 conversation/approval GET=404、列表为空；rig-down 已停止 Flutter、backend、ssetap、llmtap、recorder，session journals 保留。正式证据为 `evidence/tool-056-formal-122-green.txt`，正负终帧为 `evidence/frames/formal-122-positive-final.png` 与 `formal-122-negative-final.png`。
- 锚点重新校准后，五级裁决 `TOOL-056=G1/F2/A5/C4/G2` 写入 COVERAGE；中央账本从 325 增至 `330 judgments`，`gap-too-fast`/`discovery-collapse` 依据 formal-121 红证据与 formal-122 五通道证据逐项复审并串行 ack，最终 `alarms.py check` 为 clean。本批由 **29 / 50** 推进至 **34 / 50**；未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-057`。

## 2026-08-02 01:52 · 第六批 TOOL-055 edit_approval 修复后正式通过

- formal-117 `/private/tmp/anselm-rig-formal-117/sessions/20260802-011812` 首轮真实 App 冻结为红：托管模型省略全量替换字段，未形成可接受的完整 edit 请求；红证据为 `evidence/tool-055-formal-117-red-incomplete-edit.txt`，不计绿。formal-118 `/private/tmp/anselm-rig-formal-118/sessions/20260802-012450` 修复前重跑又冻结为红：字段齐全但省略非空 `changeReason`，后端拒绝前端仍错误地把意图当成可继续的成功形状；红证据为 `evidence/tool-055-formal-118-red-missing-change-reason.txt`，不计绿。
- stop-and-fix：`edit_approval` 的公开描述和 schema 明确全量 replacement 的 `approvalId`、`inputs`、`template`、`allowReason`、`timeout`、`timeoutBehavior`、`changeReason` 均为必需；执行前增加 native/精确 JSON 字符串 decoder 与非空 reason 校验，补 approval 生命周期测试、工具文档和领域文档。formal-119 `/private/tmp/anselm-rig-formal-119/sessions/20260802-012842` 的真实 App 观察继续发现产品语义缺陷：edit 失败显示 create/draft 文案，并渲染了 Approve/Reject 等可操作审批按钮；该路径不计绿，修复后补中心卡和 sidestage 的 Flutter regression。
- formal-120 `/private/tmp/anselm-rig-formal-120/sessions/20260802-013952` 用新二进制、真实 onboarding、真实受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。正向真实用户目的为一次完整编辑：只调用一次 `edit_approval`，active 从 v1 变 v2；App 只有一张成功 Updated/Edited activity，完整表单/输入类型/template/行为设置与 REST 真相一致。负向同一真实对话只调用一次空 `changeReason`，在 mutation 前拒绝；App 明确显示“编辑失败·上一版仍有效”和“没有可审批的预览·上一版仍有效”，保留精确 validation error，不再显示审批按钮。REST/SQLite 最终恰有 v1/v2、active=v2、无 v3；两个 turn 均无 retry，最终响应为 stop。
- 五通道收台：`screen.mov` H.264 `2784x1808 / 417.105000s`；SSE 三流均连接，messages durable `1..29`、entities `1..2`、notifications `1..6` 均唯一单调无 gap；LLM journal 的 observed responses 全 HTTP 200；backend 唯一 WARN 是刻意负向 `edit_approval: changeReason is required for a complete replacement`，无 panic/ERROR/FATAL。frontend 运行时 marker scan 无 `Unhandled exception`、`FlutterError`、`RenderFlex overflow`、`DartError` 等红线。
- 前端 journal 有 215 行 macOS `accessibility_bridge.cc` AXTree：这是 Computer Use 在 Flutter 动态语义树替换窗口读取 AX 的已知观察噪声，不被隐藏或冒充产品绿灯。formal-84 无 Computer Use 基线为零，formal-83/85 已确认同签名的观察时序来源；因此本 session 的严格 `rig-check` 只因该观察签名失败，正式证据明确记录此事实，产品运行时扫描和录屏审查仍干净。
- cleanup：conversation `cv_d45ec338335de6ae` 与 approval `apf_5ae23eff8e012998` DELETE=204，随后实体 GET=404、列表为空；rig-down 已停止 Flutter、backend、ssetap、llmtap、recorder，session journals 与录屏保留。正式证据为 `evidence/tool-055-formal-120-green.txt`，正负终帧为 `evidence/frames/formal-120-positive-final.png` 和 `formal-120-negative-final.png`。
- `make -C frontend gen`、`mise exec -- flutter test test/features/chat/ui/tool_card_control_approval_test.dart`（6/6）、`mise exec -- flutter test test/features/chat/ui/stages_w3_test.dart`（6/6）、`make -C frontend analyze` 和 `git diff --check` 通过。锚点重新校准后，五级裁决 `TOOL-055=G1/F2/A5/C4/G2` 写入 COVERAGE；中央账本从 320 增至 `325 judgments`，`gap-too-fast`/`discovery-collapse` 依据 formal-117/118/119 红证据与 formal-120 五通道证据逐项复审并串行 ack，最终 `alarms.py check` 为 clean。本批由 **24 / 50** 推进至 **29 / 50**；未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-056`。

## 2026-08-02 01:12 · 第六批 TOOL-054 create_approval 修复后正式通过

- formal-115 首轮真实 App + 受管网关冻结为红：托管模型将 `allowReason` 与 `inputs` 字符串化，后端首轮拒绝后 retry；App 留下失败活动与成功活动并存。红证据为 `/private/tmp/anselm-rig-formal-115/sessions/20260802-005845/evidence/tool-054-formal-115-red-stringified-scalars-and-retry.txt`，不计绿。
- stop-and-fix：approval create/edit 执行边界新增只接受 native 或精确 JSON 字符串的 bool/inputs decoder；inputs object 按字段名稳定排序，冲突/畸形形状在 mutation 前拒绝；公开 schema 仍为 boolean/array。补 decoder、生命周期测试、领域文档；`go test ./internal/app/tool/approval ./internal/app/loop`、gofmt、`make -C docs verify`、`git diff --check` 通过。
- formal-116 `/private/tmp/anselm-rig-formal-116/sessions/20260802-010803` 使用新二进制、真实 onboarding、真实受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。模型只调用一次 `create_approval`，无 search/retry/第二次 mutation；App 只显示一条 Created activity，完整结果包含 id/version/description、三个 typed inputs、template、allowReason=true、2h reject timeout 和 changeReason；wire/REST/UI 一致。
- 五通道：screen.mov `245.026667s / 2784x1808 / 60fps`；SSE messages durable `1..15` 并收到后续删除通知，三路连接完整；LLM 首个 tool call 后唯一 tool result，最终 `finish_reason=stop`；backend 无 WARN/ERROR/panic，frontend 只有正常 Flutter 启动/DevTools 行；fixture/conversation DELETE=204，列表清空且 GET=404。正式证据为 `evidence/tool-054-formal-116-green.txt`。
- 五级裁决 `TOOL-054=G1/F2/A5/C4/G2` 已写入 COVERAGE；中央账本从 315 增至 `320 judgments`，锚点有效，gap-too-fast/discovery-collapse 依据 formal-116 五通道证据复审并串行 ack，最终 `alarms.py check` clean。本批由 **19 / 50** 推进至 **24 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-055 edit_approval`。

## 2026-08-02 00:55 · 第六批 TOOL-053 get_approval 正式通过

- formal-114 `/private/tmp/anselm-rig-formal-114/sessions/20260802-004855` 使用 `RIG_SEED=0`、真实 onboarding、真实受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏完成正负两条只读目的。REST 建立 `apf_27df4981b64d9cc3`：三字段输入 `releaseName`/`riskScore`/`hasMigration`、完整 markdown template、`allowReason=true`、`timeout=2h`、`timeoutBehavior=reject`。
- 正向真实 App prompt 明确只调用一次 `get_approval`，wire 参数精确为 `{"approvalId":"apf_27df4981b64d9cc3"}`；App 只出现一张 `Viewed approval … · v1`，滚动后完整可见 id/name/description、输入表、template 和 Behavior Settings。负向只调用不存在的 `apf_0000000000000000` 一次，App 一张 `approval form not found` 失败卡和明确不编造详情的最终说明，无 search/retry/其它工具。
- 五通道：screen.mov `222.798333s / 2784x1808 / 60fps`；SSE 三流各 connect/disconnect 一次，messages durable `1..29`、notifications `1..5` 单调无 gap，entities 已连接但无 durable entity 帧（只读切片）；LLM 24 行中 16 条 response status=200，10 个 chat completion response 全 200；backend 无 ERROR/PANIC/FATAL，唯一 WARN 是刻意负路径 not-found；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception/AXTree，唯一匹配为已知 launch foreground 噪声。
- approval 与 conversation 均 DELETE=204，随后列表为空且实体 GET=404；删除事件作为 notifications durable 帧保留。录屏关键帧和完整 journals 均封存，rig-down 完成并停止所有自有进程。正式证据为 `evidence/tool-053-formal-114-green.txt`。
- 五级裁决 `TOOL-053=G1/F2/A5/C4/G2` 已写入 COVERAGE；中央账本从 310 增至 `315 judgments`，锚点有效，gap-too-fast/discovery-collapse 按 formal-114 五通道证据复审并串行 ack，最终 `alarms.py check` 为 clean。本批由 **14 / 50** 推进至 **19 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-054 create_approval`。

## 2026-08-02 00:42 · 第六批 TOOL-052 search_approval 正式通过

- formal-113 `/private/tmp/anselm-rig-formal-113/sessions/20260802-003731` 使用 `RIG_SEED=0`、真实 onboarding、真实受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏完成三条只读目的。REST 建立三个 approval fixture：`refund` 正向查询命中一条，随机 query `zzqvulon_113` 返回 0 条，空 query `{"query":""}` 返回三条完整列表。
- 正向结果卡可点击进入 Approval entity detail，完整 description、input、template、allow reason、timeout 与 on-timeout 均可见；wire 中三次 `search_approval` 各只执行一次，没有其它工具、retry、写动作。空查询在 App 中以可读表格呈现三条 name/description。
- 五通道：LLM status 22 条全 200；SSE messages durable `1..40`、notifications `1..7` 单调无重复，entities 已连接；backend 无 WARN/ERROR/panic/fatal，frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception marker，仅保留已知 launch foreground 噪声。录屏与终帧已逐帧复核。
- 三条 approval 与两条 conversation 均 DELETE=204，随后 approval/conversation 列表为空且各实体 GET=404；rig-down 完成并保留完整 session 与 journals。正式证据为 `evidence/tool-052-formal-113-green.txt`。
- 五级裁决 `TOOL-052=G1/F2/A5/C4/G2` 已写入 COVERAGE；中央账本从 305 增至 `310 judgments`，锚点有效，警报复审后 clean。本批由 **9 / 50** 推进至 **14 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-053 get_approval`。

## 2026-08-02 00:30 · 第六批 TOOL-051 delete_control 修复后正式通过

- formal-111 首轮真实 App + 受管网关冻结为红：hosted model 在同一用户意图中并行发出 `get_relations` 与空参 `get_control`，App 留下可见 validation error；随后 destructive delete 缺少可见 HumanLoop gate，并在删除后再次 fetch 已不存在的 control。红证据为 `/private/tmp/anselm-rig-formal-111/sessions/20260802-001430/evidence/tool-051-formal-111-red-missing-get-control-args.txt`，不计绿。
- stop-and-fix：`get_control` 工具描述与 schema 明确要求已有 `controlId`、禁止空对象并标注只读；`delete_control` 明确不可逆、必填 `controlId`、`dangerous` 与 HumanLoop approval 要求；补 control 契约测试与 control domain 文档。`gofmt`、定向 `go test ./internal/app/tool/control ./internal/app/loop`、`git diff --check` 通过。
- formal-112 `/private/tmp/anselm-rig-formal-112/sessions/20260802-002441` 使用新二进制、真实 onboarding、真实 App、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。REST fixture 建立 v1/v2 control、一个 equip 该 control 的 workflow 与 trigger。正向 prompt 明确先查关系、只调用一次 delete、等待确认、禁止 post-delete fetch；wire 先发精确 `get_relations`，再发一次带 `controlId` 和 `dangerous` 的 `delete_control`。
- App 逐帧显示 `Dangerous · Awaiting your approval` 红框，文案明确 destructive/irreversible、controlId 与 Deny/Always allow/Allow；Computer Use 批准后只显示一张 `Allowed` 删除活动、`1 refs affected` 与 dependent workflow chip，最终报告 `deleted=true`、`dependentCount=1`，无红卡、retry、重复 mutation 或 loading 残留。
- REST 真相：control GET=404；versions GET=200 且保留 v1/v2 不可变历史；workflow GET=200 仍保留历史 graph；capability-check 明确返回 `node "c": ref "ctl_..." not found`；反向 relations 查询为空。该行为符合当前软删除/append-only version 契约，而非误判为“物理删除全部版本”。
- 五通道：screen.mov `293.141667s / 2784x1808 / 60fps`，t214 为确认闸、t218/t223/t230 为批准后终态；SSE 共 235 帧，messages durable `1..24`、notifications `1..7` 单调无重复，entities 已连接；LLM chat completion request/response 全 200；backend 无 WARN/ERROR/panic/fatal；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception marker。正式绿证据为 `evidence/tool-051-formal-112-green.txt`，台架已收台且 journals 保留。
- 五级裁决 `TOOL-051=G1/F2/A5/C4/G2` 已由 `judge.py` 写入 COVERAGE；中央账本从 300 增至 `305 judgments`。锚点有效，gap-too-fast/discovery-collapse 每级按 formal-112 五通道证据复审并串行 ack，最终 `alarms.py check` 为 clean。本批由 **4 / 50** 推进至 **9 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-052 search_approval`。

## 2026-08-02 00:08 · 第六批 TOOL-050 revert_control 修复后正式通过

- formal-109 首轮真实 App + 受管网关冻结为红：hosted model 首次发送 `{"controlId":"ctl_b67cb2806950232e","version":"1"}`，旧执行边界按公开 integer schema 拒绝，App 显示可见失败 activity；模型随后 retry 为 native integer 并成功。该一用户意图的“先红再成功”不满足标准，红证据为 `/private/tmp/anselm-rig-formal-109/sessions/20260801-235559/evidence/tool-050-formal-109-red-stringified-version.txt`，不计绿。fixture control/conversation 已 DELETE=204 后 GET=404，录屏和红 journal 保留。
- stop-and-fix：`revert_control` 的公开 schema 仍是 integer，工具描述明确正整数和 hosted-model 兼容边界；执行层新增 exact decimal integer string 解码，浮点、布尔、数组和坏字符串拒绝。补 `control_test.go` 的 native/stringified/malformed cases，更新 control domain 文档；gofmt、定向 `go test ./internal/app/tool/control ./internal/app/loop`、`git diff --check` 通过。
- formal-110 `/private/tmp/anselm-rig-formal-110/sessions/20260802-000259` 使用新二进制、真实 onboarding、真实 App、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。REST fixture 先构造 v1(pass/review) 与 v2(pass/escalate/review)，active=v2。正向 Chat 只执行一次 `revert_control`，wire 仍为 stringified version `"1"`，修复后无红卡、无 retry，active pointer 移到 v1 `ctlv_c05fb8b13fd7b636`；UI 只有一张成功 `Reverted control … · ↩ v1` activity，正文明确 v2 保留在 history。
- 负向同一真实 App 会话只调用一次 version 999，backend 返回 `control logic version not found`，UI 只有一张失败 activity，准确说明 active v1 unchanged，无 retry/新版本。REST/SQLite 真相为 active v1、版本历史仍为 v1/v2；control 与 conversation DELETE=204 后 GET=404，session fixture 清零。
- 五通道：screen.mov `147.631667s / 2784x1808 / 60fps`；SSE messages durable `1..29`、notifications `1..7` 连续，entities 连接且无 durable 业务帧，三流各连接一次；LLM 五个 chat completion request/response 全 200；backend 仅预期 version-not-found WARN；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception runtime marker。正负终帧为 `evidence/tool-050-formal-110-positive.png`、`tool-050-formal-110-negative.png`。
- 五级裁决 `TOOL-050=G1/F2/A5/C4/G2` 已由 `judge.py` 写入 COVERAGE；中央账本从 295 增至 `300 judgments`。锚点有效，gap-too-fast/discovery-collapse 每级按 formal-110 五通道证据复审并串行 ack，最终 `alarms.py check` 为 clean。本批由 **3 / 50** 推进至 **4 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-051 delete_control`。

## 2026-08-01 23:51 · 第六批 TOOL-049 edit_control 修复后正式通过

- formal-107 首轮真实 App + 受管网关冻结为红：托管模型首次调用 `edit_control` 时省略 `changeReason`，后端因此写入 v2；模型随后注意到遗漏，再次调用并写入带 reason 的 v3。同一用户意图产生两次版本 mutation，且第一版没有审计理由。红证据为 `/private/tmp/anselm-rig-formal-107/sessions/20260801-233447/evidence/tool-049-formal-107-red-missing-change-reason.txt`，不计绿。描述不支持 description 更新不是本格缺陷，因 `edit_control` 的边界是完整 branch replacement。
- stop-and-fix：`edit_control` AI schema 将 `changeReason` 加入 required，工具描述要求非空审计解释；`ValidateInput` 与 `Execute` 在 decoder/service 之前拒绝缺失或空白值，返回 `CONTROL_CHANGE_REASON_REQUIRED`。补 control validation/round-trip/description 守卫测试，新增 error-code 与领域文档；定向 `go test ./internal/app/tool/control ./internal/app/loop`、gofmt、`git diff --check` 均通过。
- formal-108 `/private/tmp/anselm-rig-formal-108/sessions/20260801-234249` 用新二进制、真实 onboarding、真实 App、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。正向严格限制为一次 `edit_control`：wire 的 `branches` 是 JSON 字符串但每项使用正确 `port`，reason 精确为 `acceptance TOOL-049 final fix`；backend 创建 v2 `ctlv_34cbcddfc2f6d22a`，UI 只有一张成功 Updated/Edited activity 和完整 `pass`/`escalate`/`review` 有序分支表，没有第二次 mutation。
- 负向在同一真实 App 会话只发一次缺 `changeReason` 的 `edit_control`，backend 在写版本前返回 `input validation failed: changeReason is required`；UI 显示精确错误和 `Draft unsaved · truth is still the last version`，没有 retry，REST 真相仍是 v2、没有 v3。正负终帧和正式绿证据为 `evidence/tool-049-formal-108-positive.png`、`evidence/tool-049-formal-108-negative.png`、`evidence/tool-049-formal-108-green.txt`。
- 五通道：screen.mov `189.023333s / 2784x1808 / 60fps`；SSE messages durable `1..29`、entities `7..8`、notifications `16..21` 连续且三流各连接一次；LLM 五个 chat completion request/response 全 200；backend 只有刻意负路径 validation WARN，无 panic/error/fatal；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception runtime marker。cleanup 中 control/conversation DELETE=204 后 GET=404，列表无 fixture 残留，rig-down 无台架进程泄漏。
- 五级裁决 `TOOL-049=G1/F2/A5/C4/G2` 已由 `judge.py` 写入 COVERAGE；中央账本从 290 增至 `295 judgments`。锚点有效，gap-too-fast/discovery-collapse 每级按 formal-108 五通道证据复审并串行 ack，最终 `alarms.py check` 为 clean。本批由 **2 / 50** 推进至 **3 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-050 revert_control`。

## 2026-08-01 23:30 · 第六批 TOOL-048 create_control 修复后正式通过

- formal-104 首轮真实 App + 受管网关冻结为红：托管模型把 `branches` 发成 JSON 字符串，后端按公开数组 schema 拒绝；模型随后重试成功，但 UI 保留了失败 activity 和误导性的 `Draft unsaved · nothing was created`。红证据为 `/private/tmp/anselm-rig-formal-104/sessions/20260801-231012/evidence/tool-048-formal-104-red-branches-stringified.txt`，不计绿。
- formal-105 在第一轮修复后重跑，decoder 已接受字符串数组，但 hosted model 又把 branch 键发成 `name`；随后同一 assistant response 发出两枚完全相同的 create mutation，第一枚成功、第二枚 duplicate-name 失败，UI 出现两条红失败 activity。该轮红证据为 `/private/tmp/anselm-rig-formal-105/sessions/20260801-231611/evidence/tool-048-formal-105-red-branch-name-and-duplicate.txt`，不计绿。
- stop-and-fix：`control` 增加仅针对精确 JSON 数组字符串的窄 decoder；create/edit 的公开描述和 schema 明确 branch key 必须是 `port`、禁止 `name` 并给出完整形状；loop 在同一 assistant 批次按工具名+稳定参数抑制完全重复 mutation，第二调用返回 completed 的 suppressed 结果而非再次写入。补 control validation/execute、loop duplicate 守卫测试，更新 control domain 文档；定向 `go test ./internal/app/tool/control ./internal/app/loop`、gofmt、`git diff --check` 均通过。
- formal-106 `/private/tmp/anselm-rig-formal-106/sessions/20260801-232207` 用新二进制、真实 onboarding、真实 App、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。正向请求真实创建 `acceptance_control_fixture_106`：LLM wire 首个 create call 的 `branches` 为 JSON 字符串，但每项使用正确 `port`；backend 接受并返回 `ctl_a385d713822f5367`、active version `ctlv_fe1349dcbb94cd67`，App 只显示一个成功 `Created control` activity 和完整 `pass`→`review` 表，没有红色 retry/duplicate failure。正式负向在同一会话只尝试一次已存在名称，backend 返回 `control logic name already exists`；App 显示 `Draft unsaved · nothing was created`、红色错误和精确的 assistant 解释，无 retry/其它工具。
- 五通道：screen.mov `230.008333s / 2784x1808 / 60fps`；SSE messages durable `1..29`、entities `7..8`、notifications `16..20` 连续，三流均连接；LLM tap 记录 challenge/install/models 与 5 个 chat completion request/response，状态全 200；backend 只有刻意负路径 duplicate-name WARN，无 panic/ERROR/FATAL；frontend 无 Flutter/Dart/RenderFlex/Unhandled/AXTree 运行时红线。正负终帧为 `evidence/formal-106-positive.png` 与 `evidence/formal-106-last.png`，完整摘要为 `evidence/tool-048-formal-106-green.txt`。
- control 与 conversation DELETE=204，随后 GET=404，control 列表无 fixture 残留；rig-down 已封口并停止所有自有进程。五级裁决 `TOOL-048=G1/F2/A5/C4/G2` 已写入 COVERAGE；中央账本从 285 增至 `290 judgments`，锚点有效，`gap-too-fast`/`discovery-collapse` 每级按 formal-106 五通道及 formal-104/105 红证据复审并 ack，最终 `alarms.py check` clean。第六批由 **1 / 50** 推进到 **2 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-049 edit_control`。

## 2026-08-01 23:08 · 第六批 TOOL-047 get_control 正式通过

- formal-103 `/private/tmp/anselm-rig-formal-103/sessions/20260801-225639` 使用全新数据目录、真实 App、受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏完成 `get_control` 正向/负向切片。第一次仅 `set_value` 的无提交动作没有计入证据；改用真实 `type_text` 后 composer 正文、发送箭头和 Return 均真实落地。
- 正向真实链为 `search_control` 精确命中 `acceptance_control_fixture_103`，再用返回的 `ctl_8eb2f6633ab2434d` 调 `get_control`；UI 展示 control id/name/description、active version `ctlv_9774701ea7a27d4c`、version `1` 和 `high/low` 两条有序分支的 `when/emit`。负向经 REST 送入同一真实对话，只调用不存在的 `ctl_0000000000000000`，后端返回 `control logic not found`，App 显示失败工具卡和明确解释，没有任何写工具或 retry。
- 五通道已封存：screen.mov `415.278333s / 2784x1808 / 60fps`；SSE messages durable `1..39`、notifications `16..20` 连续，entities 已连接；LLM challenge/install/models 与真实 chat completion 全 200；backend 唯一 WARN 是刻意负向的 not-found，frontend 只有构建期 macOS 弃用警告，没有 Flutter/Dart/RenderFlex/Unhandled/AXTree 运行时红线。终帧已视觉复核，错误卡、markdown、侧栏和空 composer 无裁切/重叠/残留 loading。
- control fixture 与 conversation 均 DELETE=204，随后 GET 均 404，列表无 `acceptance_control_fixture_103` 残留；rig-down 后无 backend/tap/Flutter/recorder/llama 孤儿。证据文件为 `evidence/tool-047-formal-103-green.txt`。
- 五级裁决 `TOOL-047=G1/F2/A5/C4/G2` 已由 `judge.py` 写入 COVERAGE；中央账本从 280 增至 `285 judgments`，锚点有效。`gap-too-fast` 与 `discovery-collapse` 每次按 formal-103 证据重审并 ack，最终 `alarms.py check` 为 clean。第六批 **1 / 50**，按 P15 不跑统一长门禁、不提交；下一前线为 `TOOL-048 create_control`。

## 2026-08-01 22:20 · 第五批 TOOL-046 收尾与 AX 观察红线修复

- formal-98 与 formal-100 的真实 App 观察在流式动态语义树替换期间读取 AX state，产生 macOS `accessibility_bridge` AXTree 红线；两次均作为反证冻结，未判绿。formal-99 的无 Computer Use AX 读取基线为零，确认问题位于观察时机而非后端、SSE 或业务路径。
- stop-and-fix：streaming markdown 与 live tail 增加稳定外层 `Semantics` 节点并排除半成品子树语义，补 62 项定向 Flutter 测试；`rig-check.sh` 将 AXTree 错误与 Flutter/Dart/RenderFlex/Unhandled 红线同样拒绝，`testend/rig/README.md` 记录稳定态 AX 读取与连续录屏规则。
- formal-102 `/private/tmp/anselm-rig-formal-102/sessions/20260801-221506` 以真实 App、受管网关、Computer Use、独立三流 SSE tap 和 LLM tap 重跑 `search_control`。正向精确命中 `acceptance_control_fixture_102`，负向 `zzqvulon_102` 返回空集；录屏 `114.528333s / 2784x1808 / 60fps`，messages durable `1..28`、notifications `1..5`、entities 已连接无 gap，LLM 状态全 200，backend/frontend journal 无未解释红线，最终帧视觉复核通过。
- fixture control 与 conversation 均 DELETE=204，残留查询为零；formal-102 session 已收台且无进程泄漏。五级裁决 `TOOL-046=G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 `280 judgments`；`gap-too-fast` 与 `discovery-collapse` 按 formal-102 五通道证据重审并 ack，最终警报 clean。
- 第五批达到 **50 / 50**。按 P15，统一长门禁、完整 testend、专项回归、锚点/警报/工作树/进程/diff 审计均已通过，批次已提交 `90f51edd`；下一前线为 `TOOL-047`。

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

## 2026-08-02 22:16 · 第七批 TOOL-066 stage_workflow 正式收口

- formal-139、formal-140、formal-141 均作为真实 stop-and-fix 红证据保留，不计绿。首轮暴露 stage 回执只有 opaque ID；修复后真实 App 的历史 stage 卡片仍错误声称 awaiting next real trigger；再修复后旧二进制的安全 redactor 又把 Markdown 反引号 ID parenthetical 渲染成 `name (the referenced item)`。
- 修复内容：`Service.Stage` 返回已读取的 workflow snapshot，HTTP/LLM 结果包含真实 name、id、inactive lifecycle 和 `active=false`；前端卡片改成历史事实 `one-shot · auto-disarms`；redactor 只去掉名称后重复的 opaque entity ID parenthetical，独立 ID 仍替换为 `the referenced item`。后端/前端定向测试、`make -C docs verify`、`git diff --check` 通过。
- formal-142 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-220942` 使用真实 App、受管网关、Computer Use、窗口录屏、backend/frontend journal、三路 SSE witness 和 LLM tap。真实 App 只调用一次 stage，第一发真实 webhook `202 Accepted`，唯一 activation `fired=true/firingCount=1`，唯一 firing 建立 completed flowrun `fr_1398ab2d27f13cd2`；trigger 随即 `refCount=0/listening=false`，workflow 仍 inactive。第二发真实 webhook `404`，backend 记录路由注销，无第二 firing/flowrun。
- 五通道结果：`screen.mov` 已由 rig-down 封口 `281.433333s`；SSE 有唯一 `run_started → run_terminal(completed)` 且三流均连接、durable seq 单调；LLM install/models/chat 全 200 且 stage 只调用一次；backend/frontend 无未解释产品运行时红线，仅已知 macOS foreground launcher 噪声。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-220942/evidence/tool-066-formal-142-green-stage-workflow.md`。
- `judge.py` 五格 `G1/F2/A5/C4/G2` 已落账，中央账本 `370 judgments`；`gap-too-fast` 与 `discovery-collapse` 由 formal-142 的完整录屏、正负路径、前三场红证据和五通道证据复审后 ack，`alarms.py check` clean。第七批推进至 **30 / 50**，下一前线 `TOOL-067 activate_workflow`；未到 50 格不跑统一长门禁、不提交。

## 2026-08-02 22:34 · 第七批 TOOL-067 activate_workflow 正式收口

- formal-143、formal-144 均作为真实 stop-and-fix 红证据保留，不计绿。formal-143 暴露 activate 回执只有 opaque ID，最终话术无法确认目标；formal-144 在服务层返回真实名称后，又由流式 provider chunk 分界暴露跨 chunk parenthetical redaction 缺陷，最终出现 `name (the referenced item)`。
- 修复内容：`ActivateWorkflow` 返回 action-after 的 workflow name/id/lifecycle/active 快照，并将同类命名快照语义横扫到 `deactivate_workflow`/`kill_workflow`；redactor 对未闭合 parenthetical 做有界跨 chunk 暂存，并清理实体替换后残余 placeholder；补真实 Service/tool 与跨 chunk regression 测试，同步 backend/frontend/API/tool/chat 文档。
- formal-145 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-222906` 使用真实 App、真实受管网关、Computer Use、窗口录屏、backend/frontend journal、三路 SSE witness 和 LLM tap。App 严格只调用一次 activate，危险人闸按明确用户意图批准一次；最终画面确认真实 workflow `tool067-activate-continuous-final` 已 active 且持续 listening，无 placeholder、无 retry。
- 两次真实 webhook 均返回 `202 {"accepted":true}`：`probe=first` → `fr_6bca393151534731`，`probe=second` → `fr_86aa0c00e769386b`；两个 flowrun 均 completed，节点结果精确保留各自 body，trigger 仍 `listening=true/refCount=1`，workflow 仍 `active=true/lifecycleState=active`。
- 五通道收台：`rig-check` 收台前通过 D1/backend/ssetap/llmtap/Flutter/录屏自检；`screen.mov` 封口 `278.248333s`；SSE durable `messages 1..15`、`entities 1..4`、`notifications 1..4` 单调并捕获两次 `run_started → run_terminal`；LLM challenge/install/models/chat 全 200；backend 无意外 marker；frontend 仅已知 foreground launcher 噪声，无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线。证据为 `.../sessions/20260802-222906/evidence/tool-067-formal-145-green-activate-workflow.md`。
- `judge.py` 五格 `G1/F2/A5/C4/G2` 已落账，中央账本 `375 judgments`。`gap-too-fast` 与 `discovery-collapse` 按 formal-143/144 红证据、formal-145 录屏、双 webhook REST truth 和五通道 journal 完整复审并 ack，`alarms.py check` clean。第七批推进至 **35 / 50**，下一前线 `TOOL-068 deactivate_workflow`；未到 50 格不跑统一长门禁、不提交。

## 2026-08-02 23:48 · 第七批 TOOL-068 deactivate_workflow 正式收口

- 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-234036` 使用新二进制、真实 App、真实受管网关、Computer Use、连续窗口录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap。REST setup 先将 `wf_afab89684d8c5025` 置为 active；真实 App 随后发送一条明确请求，模型只调用一次 `deactivate_workflow`，参数为 `{"workflowId":"wf_afab89684d8c5025"}`，没有 `kill_workflow`。
- 工具回执为 `active=false`、`lifecycleState=inactive`、真实名称 `tool068-redaction-green-target`；notifications 的 `workflow.lifecycle_changed`、最终 REST GET 和 messages tool result 三方一致。最终画面显示 `Stopped listening … · offline` 以及可读的 `Deactivation confirmed`、真实 name、`lifecycleState: inactive`、`active: false`；没有 retry、没有错误卡、没有第二个 lifecycle 动作。终帧为 `evidence/tool-068-final-frame.jpg`，完整录屏封口 `439.891667s / 2784x1808 / 60fps`。
- 五通道收台：SSE 三流均连接，messages durable seq `1..38` 连续并包含 deactivate call/result/message close，notifications 捕获 active→inactive 两条 lifecycle 事实；`backend.log` 无 WARN/ERROR/panic/FATAL；`llm.jsonl` challenge/install/models/chat 观察响应全 200；`frontend.log` 无 FlutterError、DartError、RenderFlex 或 unhandled exception。
- 严格 `rig-check` 唯一失败是 frontend journal 中 177 条 `accessibility_bridge.cc ... Failed to update ui::AXTree`。该红线没有被隐藏：三秒静置后重新读取完整稳定 App，AXTree 数量仍为 177，且稳定态没有新增；按 `testend/rig/README.md` 的既有规则分流为 Computer Use 读取动态 macOS AX 树时的观察器/引擎交互噪声，流式期间以连续录屏取帧而不反复读 AX。完整审阅结论、计数和失败的 `rig-check` 输出均保留在正式证据摘要，不把它冒充为全绿。
- `judge.py` 在锚点有效、先验警报 clean 且证据文件/法条齐全后落账五格 `G1/F2/A5/C4/G2`，中央账本由 `375` 增至 **380 judgments**。新增的 `gap-too-fast` 与 `discovery-collapse` 经完整录屏、终帧、红线分流和五通道复审后写 note 并 ack，`alarms.py check` 最终 clean。第七批推进至 **40 / 50**，下一前线为 `TOOL-069 kill_workflow`；未到 50 格不跑统一长门禁、不提交。

## 2026-08-03 00:12 · 第七批 TOOL-069 kill_workflow 正式收口

- 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-235255` 使用新二进制、真实 App、真实受管网关、Computer Use、连续窗口录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap。目标 workflow `wf_95346c04c2a5fd5f` `tool069-kill-target` 先由真实 API 布置为 active，存在一个 approval-parked 在飞 run 和一个 queued firing；App 只调用一次 `kill_workflow`，没有 deactivate/delete/get 或 retry。真实危险人闸只批准一次，workflow 自身 approval 未被决策。
- 首轮真实 UI 观察发现审批胶囊先挂短 notice、再异步替换成长问题句时没有重测高度，`340x110` 壳体出现 `RenderFlex overflowed by 18 pixels`，按钮行被挤出。前线冻结，修复 `AnApprovalCapsule.didUpdateWidget` 在 question 变化时重测，并补异步长问题句 widget regression；`mise exec -- flutter test test/core/run/an_approval_capsule_test.dart` 9/9 通过。hot-restart 后真实 App 再次显示长问题句、Approve/Reject，无黄色条纹。修复前四条 overflow 日志原样保留。
- 正式结果为 `active=false`、`lifecycleState=inactive`、真实 name `tool069-kill-target`、`killed=1`；`fr_3fbbd32920fb144a` 为 cancelled/error=`killed by user`，`trf_0078980b8eafea0f` 为 shed，approval inbox 不再有目标 parked 行。最终帧 `evidence/tool-069-screen-final.jpg` 与 `tool-069-final-kill.jpeg` 已视觉检查，录屏封口 `996.078333s / 2784x1808 / 60fps`。
- 五通道：SSE 三流连接，durable `messages 1..15`、`entities 1..8`、`notifications 1..15`；关键消息为 kill call close seq 7、cancelled `run_terminal` seq 5、inactive lifecycle seq 11、authoritative tool result seq 10；LLM body `00006_v1_chat_completions.bin` 仅有一个实际 `kill_workflow` call，challenge/install/models/chat 响应全 200；backend 无产品 WARN/ERROR/panic/FATAL；frontend 只有修复前四条 overflow，hot-restart 后无新增 runtime 红线。
- 严格 `rig-check` 因历史修复前 overflow 按设计失败，证据没有将它冒充全绿；修复后真实帧、回归测试和五通道均通过。正式摘要为 `.../sessions/20260802-235255/evidence/tool-069-formal-green-kill-workflow.md`。临时 layout-probe workflow、trigger、approval 已通过真实 API 删除，删除/取消信号保留在 SSE journal；rig-down 已封口且进程清零。
- 锚点 10/10 重新校准后，`judge.py` 五格 `G1/F2/A5/C4/G2` 落账，中央账本由 `380` 增至 **385 judgments**。`gap-too-fast` 与 `discovery-collapse` 按完整 996 秒录屏、修复前红证据、修复后终帧、REST/SSE/LLM/backend/frontend 五通道复审并 ack，最终 `alarms.py check` clean。第七批推进至 **45 / 50**，下一前线为 `TOOL-070 get_flowrun`；未到 50 格不跑统一长门禁、不提交。
- 前端完整门禁首次在 `conversation_rail.dart` 的 `_newChat` 暴露两条 Riverpod protected API warning；将直接 `.state++` 收口为 `ChatLandingReset.bump()`，不改变 landing generation 语义。`conversation_rail_test.dart` 18 项通过，随后 `make -C frontend verify` 完成 `gen + analyze + 5168 tests` 全绿。

## 2026-08-03 03:44 · 第七批 TOOL-070 get_flowrun 正式收口

- formal-146 的第一轮真实大运行路径冻结为红：用户正文出现 `Run summary for the requested item`，并泄露 function pinned version 的 `fnv_...` opaque ID；红观察来自真实 Flutter App、SSE durable close 和 LLM/tool-result 交叉核对，不计入绿。
- stop-and-fix 在 `backend/internal/app/loop/redact.go` 增加 flowrun summary 与 pinned reference 的语义归一化、`fnv_` 跨 delta 整行缓冲和 durable close 二次 redaction；`redact_test.go` 增加完整 summary、pinned version、跨 chunk 和 close snapshot 守卫；`docs/references/backend/domains/chat.md` 同步规则。`go test ./internal/app/loop ./internal/app/tool/workflow ./internal/app/chat` 全绿。
- formal-147 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-033531` 用修复后二进制、真实 App、真实受管网关、Computer Use、连续录屏、backend/frontend journal、三路 SSE witness 和 LLM tap 重跑。真实用户请求只调用一次 `get_flowrun`；真实 run `fr_31606084bcee949b` 为 completed，REST 两页合计 91 个 completed 节点，UI 正确显示 80/91 capped projection 和 91 节点总数。最终录屏 `327.648333s`，证据为 `evidence/tool-070-formal-acceptance.md`。
- 五通道复核：messages durable `1..20`、notifications durable `1..2` 连续；可见 reasoning/text 无 `the requested item`、`the referenced item`、`fnv_`、`wfv_`、`apf_`、`apfv_` 或 `get_flowrun tool`；raw tool result 保留完整机器值；backend 无产品异常；frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线；LLM challenge/install/models/chat 全 200；REST/SSE/UI 三方一致。rig-check 收台前通过，rig-down 已封口并清零进程。
- 锚点 10/10 复核有效，`judge.py` 五格 `G1/F2/A5/C4/G2` 落账，中央账本由 `385` 增至 **390 judgments**。`gap-too-fast` 与 `discovery-collapse` 因五格写入过快打开，已根据完整录屏、前置红证据、修复后二次运行和五通道审查写 resolution 并 ack，`alarms.py check` clean。第七批达到 **50 / 50**；统一长门禁、完整 testend、工作树审计和提交现在解锁，下一前线为 `TOOL-071 search_flowruns`。
