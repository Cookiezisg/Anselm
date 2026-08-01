---
id: WRK-087
type: working
status: active
owner: "@weilin"
created: 2026-07-27
reviewed: 2026-08-02
review-due: 2026-10-30
audience: [human, ai]
landed-into:
---

# WRK-087 · 端到端全产品验收循环(acceptance loop)

> **历史基线摘要(2026-08-01):Day 0 已打通。conductor 亲自托管真实 App、Flutter console、屏幕录像、
> 后端、三路 SSE 与网关线缆,并在全新数据目录完成 onboarding → 受管开通 → 五通道自检 →
> 优雅收台的真机闭环。清册为 848 行 × 5 级 = 4240 格;锚点校准已冻结并接入 gate。
> 操作手册 [`testend/rig/README.md`](../../../testend/rig/README.md) 使任何 agent 不带对话记忆也能
> 操作全套台架。400+ 旅程扩写按 P12 推迟二期,一期直接按 COVERAGE 驻停清扫。Goal 已配置为
> active，Loop 执行协议见 [`LOOP.md`](LOOP.md)；首批 50/50 已通过统一长门禁、完整 testend、真实回放、
> 告警复核和工作树审计，并已提交 `b26f623e`；第二批已完成 50/50 个单格，`TOOL-003 Edit` 至
> `TOOL-012 todo_read` 已按真实五通道收尾；统一长门禁已全绿并完成审计。第三批已完成
> `TOOL-013 search_tools`、`TOOL-014 search_function`、`TOOL-015 get_function`、`TOOL-016 create_function`、`TOOL-017 edit_function`、`TOOL-018 revert_function`、`TOOL-019 delete_function`、`TOOL-020 update_function_meta`、`TOOL-021 run_function` 与 `TOOL-022 search_function_executions` 共 50/50 个单格；
> `TOOL-016` 首轮发现新建失败态误显示 edit 专属的“上一版”文案，修复为 create 专属的“尚未创建实体”，并补
> create/edit 对称 widget 回归；`TOOL-017` 又真实覆盖 v1→v2 版本编辑、非法代码拒绝和无 v3 副作用，edit 失败保留上一版真相。
> `TOOL-018` 又真实覆盖 v2→v1 指针回退、v999 不存在版本拒绝、无新版本副作用和历史保留；`TOOL-019` 首轮发现
> delete 的工具描述错误宣称“全版本删除”，冻结后修正为主行软删、不可变版本审计保留、sandbox 回收、后续动作 not-found，
> 并以真实成功/失败路径、SQLite、HTTP、五通道与 native-resolution 画面重跑。`TOOL-020` 首轮发现精确下划线意图在
> Computer Use 输入层丢失，以及 tags 错用字符串的 AI 引导问题；补充数组形状示例与禁止逗号字符串的 schema/描述后，
> 修复后二进制用真实成功/失败路径重跑。`TOOL-021` 首轮发现托管模型把显式版本和对象参数字符串化，修复执行边界后真实一次成功 v2、一次不存在 ID 拒绝、一次缺参数执行失败；`TOOL-022` 首轮发现分页 limit 被托管模型发成字符串，修复执行边界接受精确整数字符串并保留强类型公开 schema，随后真实覆盖分页、failed/version 筛选、空结果和非法 status；第三批已到 50/50，警报复审后 clean(150 judgments)，统一长门禁、完整 testend、专项回归和最终审计均已通过，并已提交 `eb1ee050`；第四批 `TOOL-023 get_function_execution`、`TOOL-024 search_handler`、`TOOL-025 get_handler`、`TOOL-026 create_handler`、`TOOL-027 edit_handler` 与 `TOOL-028 revert_handler` 已完成 30/50。`TOOL-027` 首轮真实会话暴露托管模型发送 `methodName`、`method` 加顶层字段和 camel-case op；冻结后在执行边界加入只针对已观测 hosted-model alias 的窄归一化，公开 schema 仍严格要求 `{op,name,patch}`，补守卫测试、同步工具描述与 handler 文档。`TOOL-028` 的前置真实会话又暴露 `kind:set_method`、`set_method_description` 等不规范 edit 形状以及 `version:"1"` 的标量字符串化；前置 edit 与回退切片分离，回退边界仅兼容精确整数字符串，非整数仍拒绝。最终 session `/private/tmp/anselm-rig-formal-20260801-46/sessions/20260801-132558` 用真实 REST fixture 建 v2，再由真实 App 单次回退到 v1并执行 version 999 负路径；screen.mov `258.636667s`、`2784x1808`，LLM 状态全 200，messages durable `1..91`、entities `7..8`、notifications `16..21` 无 gap，frontend 无 Flutter 红线，backend 仅预期 version-not-found WARN，SQLite/UI/REST/LLM wire 一致。五级裁决为 `G1/F2/A5/C4/G2`，警报复审后 clean(180 judgments)；下一前线为 `TOOL-029 delete_handler`。**
>
> **历史状态(截至 2026-08-02 00:55):** 第五批已完成 50/50 个单格并已提交 `90f51edd`；第六批当时
> **19 / 50**。`TOOL-047 get_control` 的 formal-103 已通过；`TOOL-048 create_control` 的 formal-104
> 首轮冻结为红：托管模型将 branches 发成 JSON 字符串且 UI 留下失败活动；formal-105 修复前重跑又暴露
> branch 键误用 `name` 以及同一 assistant 批次重复 mutation，均保留红证据、不计绿。前线随后修复
> stringified-array 窄兼容 decoder、`port` 精确契约提示和同批完全重复调用抑制，并通过定向 Go 测试。
> formal-106 使用真实 App + 受管网关 + Computer Use + 五通道台架重跑：正向首个真实 create_control
> wire 使用 JSON 字符串数组但每个 branch 为正确 `port`，后端接受并只产生一个成功实体；App 展示一张
> 完整 ordered branches 表，没有红色重试或 duplicate failure。负向同一真实会话只调用一次已存在名称，
> 后端明确返回 `control logic name already exists`，App 同时显示“Draft unsaved · nothing was created”
> 与精确错误解释，无 retry/其它工具。录屏 `230.008333s / 2784x1808 / 60fps`，messages durable `1..29`、
> entities `7..8`、notifications `16..20` 连续，LLM 五个 chat completion request/response 均 200，backend
> 只有刻意负路径 WARN，Flutter journal 无运行时红线。证据与正负终帧封存于
> `/private/tmp/anselm-rig-formal-106/sessions/20260801-232207/`；control fixture 与对话 DELETE=204 后
> GET=404，列表无残留。五级裁决 `G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 290 条；统计警报按
> formal-106 五通道证据复审并 ack 后 clean。`TOOL-049 edit_control` 的 formal-107 首轮冻结为红：同一用户
> 意图先生成缺少 `changeReason` 的 v2、再生成带 reason 的 v3，造成两次版本 mutation；formal-108 修复后真实
> App 正向只调用一次并创建 v2，负向缺 reason 在 mutation 前拒绝且没有 v3。formal-108 录屏
> `189.023333s / 2784x1808 / 60fps`，messages `1..29`、entities `7..8`、notifications `16..21` 连续，
> LLM 全 200，backend 只有刻意负路径 WARN，frontend 无运行时红线；证据与正负终帧封存于
> `/private/tmp/anselm-rig-formal-108/sessions/20260801-234249/`，fixture 与 conversation DELETE=204 后 GET=404。
> 五级裁决已写入 COVERAGE，中央账本 `295 judgments`，警报 clean。第六批未到 50 格，不跑统一长门禁、不提交；
> 下一前线为 `TOOL-051 delete_control`。
> `TOOL-050 revert_control` 的 formal-109 首轮冻结为红：托管模型将 integer version 发成字符串，UI 先显示失败卡，
> 随后 retry 成功；formal-110 修复后真实 App 正向只出现一张成功 `↩ v1` activity，负向不存在版本只出现一张
> 可解释失败卡且 active v1 不变。录屏 `147.631667s / 2784x1808 / 60fps`，messages durable `1..29`、
> notifications `1..7` 连续，entities 已连接，LLM 五个 chat completion request/response 全 200，backend 只有
> 刻意负路径 WARN，frontend 无运行时红线；证据与正负终帧封存于
> `/private/tmp/anselm-rig-formal-110/sessions/20260802-000259/`，fixture 与 conversation DELETE=204 后 GET=404。
> 五级裁决已写入 COVERAGE，中央账本 `300 judgments`，警报 clean。`TOOL-051 delete_control` 的 formal-111
> 首轮冻结为红：模型发出空参 `get_control`，destructive delete 缺少可见确认闸，且删除后再次 fetch 已不存在的
> control；红证据为 `/private/tmp/anselm-rig-formal-111/sessions/20260802-001430/evidence/tool-051-formal-111-red-missing-get-control-args.txt`，不计绿。
> stop-and-fix 将 `get_control` 的 `controlId` 必填/只读语义和 `delete_control` 的不可逆、必填 `controlId`、
> `dangerous`/HumanLoop approval 要求写入 schema/描述，并补契约测试与领域文档。formal-112
> `/private/tmp/anselm-rig-formal-112/sessions/20260802-002441` 真实正向先查关系、再只调用一次 delete；App
> 明确停在 `Dangerous · Awaiting your approval` 卡，批准后只有一张 `Allowed` 活动和 `1 refs affected`，无红卡、
> retry、重复 mutation 或 post-delete fetch。REST 证明实体 404、关系清空、版本 v1/v2 历史保留，workflow
> capability-check 明确报告缺失 control；screen.mov `293.141667s / 2784x1808 / 60fps`，messages durable
> `1..24`、notifications `1..7` 单调，entities 已连接，LLM 全 200，backend/frontend journal 无未解释红线。
> 正式证据为 `/private/tmp/anselm-rig-formal-112/sessions/20260802-002441/evidence/tool-051-formal-112-green.txt`。
> 五级裁决 `TOOL-051=G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 `305 judgments`，警报逐级复审并串行 ack
> 后 clean；第六批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-052 search_approval`。
> `TOOL-052 search_approval` 的 formal-113 使用三个 REST fixture 和真实 App 完成三条只读目的：`refund`
> 精确命中并从结果卡进入 Approval 详情看完整 description/template/rules；随机 query 返回明确 0 结果且无
> retry；空 query 返回 3 条并以 name/description 表格展示。wire 三次均各只调用一次 `search_approval`，SSE
> messages durable `1..40`、notifications `1..7` 单调，entities 已连接，LLM 状态全 200，backend 无 WARN/ERROR，
> frontend 无 Flutter runtime 红线；fixture 三条 approval 与两条 conversation 均 DELETE=204，列表清空且实体 GET=404。
> 正式证据为 `/private/tmp/anselm-rig-formal-113/sessions/20260802-003731/evidence/tool-052-formal-113-green.txt`。
> 五级裁决 `TOOL-052=G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 `310 judgments`，警报逐级复审并串行 ack
> 后 clean；第六批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-053 get_approval`。
> `TOOL-053 get_approval` 的 formal-114 使用真实 onboarding 和一个带三字段输入、完整 markdown template、allowReason、2h
> reject timeout 的 approval fixture，真实 App 正向只调用一次并逐层呈现 id/name/description、输入表、完整 template、Behavior Settings；
> 缺失 ID 负向只调用一次，显示明确 not-found 红卡和不编造详情的说明，无 retry。screen.mov `222.798333s / 2784x1808 / 60fps`，SSE
> messages durable `1..29`、notifications `1..5` 连续，entities 已连接，LLM chat completion 响应全 200，backend 仅刻意负路径 WARN，
> frontend 无 Flutter runtime 红线；approval/conversation DELETE=204 后列表为空、GET=404。证据为
> `/private/tmp/anselm-rig-formal-114/sessions/20260802-004855/evidence/tool-053-formal-114-green.txt`。
> `TOOL-054 create_approval` 的 formal-115 首轮冻结为红：托管模型将 `allowReason` 与 `inputs` 字符串化，后端首轮拒绝后模型 retry，真实 App 留下失败活动和成功活动并存；红证据为
> `/private/tmp/anselm-rig-formal-115/sessions/20260802-005845/evidence/tool-054-formal-115-red-stringified-scalars-and-retry.txt`，不计绿。stop-and-fix 在 approval 边界增加只接受 native 或精确 JSON 字符串的 bool/inputs decoder，inputs object 按 key 稳定排序，公开 schema 仍保持 boolean/array，并补定向 Go 测试与领域文档。
> formal-116 `/private/tmp/anselm-rig-formal-116/sessions/20260802-010803` 用新二进制、真实 onboarding、真实受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑：真实模型只发一次 `create_approval`，无 retry/search/第二次 mutation；App 只显示一张 Created activity 和完整表单结果，三个 typed inputs、template、allowReason、timeout、reject behavior、changeReason 均一致。
> 五通道已封存：screen.mov `245.026667s / 2784x1808 / 60fps`；SSE messages durable `1..15`，包含完成 close 与后续删除通知；LLM 首次 tool call 后下一轮带唯一 assistant call/tool result，最终 `finish_reason=stop`；backend/frontend 无未解释运行时红线。approval/conversation DELETE=204 后列表为空、GET=404。正式证据为 `/private/tmp/anselm-rig-formal-116/sessions/20260802-010803/evidence/tool-054-formal-116-green.txt`。
> 五级裁决 `TOOL-054=G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 `320 judgments`，警报复审并串行 ack 后 clean；第六批当前 **24 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-055 edit_approval`。
> **最新状态(2026-08-02 02:10):** 第六批当前 **34 / 50**，中央账本 `330 judgments`，锚点校准有效，
> 警报复审后 clean；`TOOL-055 edit_approval` 已完成 formal-117/118 红路径、formal-119 前端语义修复和
> formal-120 正负五通道重跑。formal-117 暴露托管模型省略全量替换字段，formal-118 暴露缺少
> `changeReason`；两轮红证据分别保留在 `/private/tmp/anselm-rig-formal-117/sessions/20260802-011812/evidence/tool-055-formal-117-red-incomplete-edit.txt`
> 与 `/private/tmp/anselm-rig-formal-118/sessions/20260802-012450/evidence/tool-055-formal-118-red-missing-change-reason.txt`。
> formal-119 的真实 App 观察发现 edit 失败错误复用 create/draft 文案并显示可操作审批按钮；修复后失败 edit
> 明确“上一版仍有效”，不再渲染审批预览或按钮，并补 targeted Flutter regression。
> formal-120 session `/private/tmp/anselm-rig-formal-120/sessions/20260802-013952` 由真实 App、受管网关、
> Computer Use、三路 SSE witness、LLM tap 和连续录屏完成：正向只调用一次 `edit_approval` 将 v1→v2；负向只调用一次
> 空 `changeReason`，mutation 前拒绝且无 v3、无 retry。录屏 `417.105000s / 2784x1808 / 60fps`；messages durable
> `1..29`、entities `1..2`、notifications `1..6` 连续，LLM observed responses 全 200，backend 只有刻意负向
> validation WARN，frontend 产品运行时 marker scan clean。严格 `rig-check` 仅因 215 行 Computer Use 读取动态
> macOS AX 树产生的已知 `accessibility_bridge.cc` 观察噪声失败；该事实未隐藏，并与 formal-84 无 Computer Use 基线及
> formal-83/85 同类观察证据一致。fixture/conversation DELETE=204 后 GET=404、列表清空，rig-down 已收台。
> 正式证据为 `/private/tmp/anselm-rig-formal-120/sessions/20260802-013952/evidence/tool-055-formal-120-green.txt`；
> 五级裁决 `G1/F2/A5/C4/G2` 已写入 COVERAGE，下一前线为 `TOOL-056`。
>
> `TOOL-056 revert_approval` 的 formal-121 首轮冻结为红：托管模型将 `version` 发成字符串，后端拒绝并让 App
> 出现失败活动后准备 retry；红证据为 `/private/tmp/anselm-rig-formal-121/sessions/20260802-015701/evidence/tool-056-formal-121-red-stringified-version.txt`，不计绿。
> stop-and-fix 在 approval 工具边界增加 exact decimal integer string 兼容，公开 schema 仍为 integer，浮点/布尔/数组/坏字符串继续拒绝，
> 并补 approval 测试、工具描述和领域文档。formal-122 `/private/tmp/anselm-rig-formal-122/sessions/20260802-020059` 真实正向只出现一张
> `Reverted approval · ↩ v1`，负向 version 999 只出现一张可解释失败卡且 active v1 不变；无 retry、无 v3。录屏
> `100.383333s / 2784x1808 / 60fps`，messages durable `1..29`、notifications `1..7` 连续，entities 已连接，LLM observed responses 全 200，
> backend 只有刻意负向 version-not-found WARN，frontend/AXTree marker scan clean。REST/SQLite/UI/wire 一致，fixture/conversation DELETE=204 后 GET=404、
> 列表清空，rig-down 已收台。正式证据为 `/private/tmp/anselm-rig-formal-122/sessions/20260802-020059/evidence/tool-056-formal-122-green.txt`；
> 五级裁决 `G1/F2/A5/C4/G2` 已写入 COVERAGE，警报复审后 clean；下一前线为 `TOOL-057`。
>
> **最新状态(2026-08-02 02:23):** 第六批当前 **39 / 50**，中央账本 `335 judgments`，锚点校准有效，警报复审后 clean；未到 50 格不跑统一长门禁、不提交。
> `TOOL-057 delete_approval` 的 formal-123 `/private/tmp/anselm-rig-formal-123/sessions/20260802-020830` 首轮冻结为红：真实 App 确实展示了 `Dangerous · Awaiting your approval`，但人批准后模型仍错误声称没有 gate，并把软删除误报成“不可逆、所有版本移除”。红证据为 `/private/tmp/anselm-rig-formal-123/sessions/20260802-020830/evidence/tool-057-formal-123-red-gate-fact-and-delete-semantics.txt`，不计绿。
> stop-and-fix 在工具结果属性中保留真实 `humanApproval` 事实，仅向后续 LLM history 注入 `[Human approval granted before this tool executed.]`，不污染可见 tool card；同时把工具描述、approval 领域/API 文档和抽取清册统一为“软删主行、清关系、版本历史保留、需危险人闸”，并补 loop/approval 测试。
> formal-124 `/private/tmp/anselm-rig-formal-124/sessions/20260802-021702` 使用新二进制、真实 onboarding、受管网关、Computer Use、三路 SSE witness、LLM tap 和连续录屏重跑：真实 UI 一张 `Allowed` activity、`1 refs affected`，助手准确说明 gate 已展示并批准后才执行；REST/SQLite 证明 approval GET=404、versions 仍有 v1/v2、关系清空，临时 capability-check 诚实报告悬空引用。messages durable `1..26`、notifications `1..11` 连续，entities 已连接，LLM observed responses 全 200，backend/frontend 无未解释运行时红线；主 fixture、workflow、trigger、conversation 均 DELETE=204 后 GET=404，rig-down 已收台，证据保留。
> 五级裁决 `TOOL-057=G1/F2/A5/C4/G2` 已写入 COVERAGE；`gap-too-fast`/`discovery-collapse` 依据红绿两轮证据复审并串行 ack，最终 `alarms.py check` 为 clean。下一前线为 `TOOL-058 search_workflow`。
>
> **最新状态(2026-08-02 02:42):** 第六批当前 **44 / 50**，中央账本 `340 judgments`，锚点校准有效，警报复审后 clean；未到 50 格不跑统一长门禁、不提交。
> `TOOL-058 search_workflow` 的 formal-125 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-022906` 首轮冻结为红：直接查询 `invoice` 返回 3 条，其中两个是弱语义邻居；结果卡只给 id/name/description/snippet，缺少工具契约承诺的 tags/lifecycleState/active。红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-022906/evidence/tool-058-formal-125-red-search-fields.txt`，不计绿。
> stop-and-fix 保留统一搜索在无直接命中时的语义召回，但让 workflow 目录的直接关键词命中优先；语义 fallback 对每个结果 hydrate 完整 workflow，结果统一返回 tags/lifecycleState/active，并补 workflow/search 定向测试、工具抽取清册和 COVERAGE 描述。
> formal-126 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-023543` 使用新二进制、真实 onboarding、受管网关、Computer Use、三路 SSE witness、LLM tap 和连续录屏重跑：`invoice` 精确命中 1 条且完整字段可见；随机 query `zzqvulon_058_no_match` 明确 0 条；空 query 列出 3 条且逐行展示 name/tags/lifecycleState/active；点击 invoice 结果正确进入 Workflow 详情，显示 v1、inactive、描述、标签、精确 ID、1 node、No alerts。三次各只调用一次 `search_workflow`，无 retry/其它工具。录屏 `317.481667s`，SSE messages durable `1..38`、notifications `1..9` 单调，LLM observed response 全 200，backend/frontend 无未解释红线；删除通知也被 SSE 观测。conversation 与三个 workflow fixture DELETE=204 后列表为空、GET=404，rig-down 已收台，证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-023543/evidence/tool-058-formal-126-green.txt`。
> 五级裁决 `TOOL-058=G1/F2/A5/C4/G2` 已写入 COVERAGE；`gap-too-fast`/`discovery-collapse` 依据 formal-125 红证据与 formal-126 五通道绿证据复审并串行 ack，最终 `alarms.py check` 为 clean。下一前线为 `TOOL-059 get_workflow`。
>
> **最新状态(2026-08-02 02:53):** 第六批当前 **49 / 50**，中央账本 `345 judgments`，锚点校准有效，警报复审后 clean；未到 50 格不跑统一长门禁、不提交。
> `TOOL-059 get_workflow` 的 formal-127 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-024437` 使用真实 onboarding 建立 function、cron trigger 与含 trigger→action edge 的 workflow。正向真实 App 先读 v1，再把无效的 test-only trigger ref 换成真实 cron source 生成 v2；最终只调用一次 get_workflow，完整展示 active version=2、lifecycleState=inactive、active=false、concurrency=replace、两个 node refs 和一条 edge。点击 `Viewed workflow` 能打开实体信息，滚动后 edge 表完整可见。缺失 ID 与空对象各只调用一次，分别显示 `workflow not found` 和 `workflowId is required`，无 retry/伪造。红/中间帧不计绿：一次未等待结果卡异步展开的 AX 读数只显示表头，等待后 Computer Use 画面与 AX 树均确认完整。
> 五通道已封存：录屏 `430.360000s`；SSE messages durable `1..58`、entities `1..2`、notifications `1..11` 单调，LLM observed response 全 200，backend/frontend 无未解释红线；REST/versions/capability-check 与最终 tool result 一致。workflow、trigger、function、conversation DELETE=204 后列表为空、GET=404，rig-down 已收台，正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-024437/evidence/tool-059-formal-127-green.txt`。
> 五级裁决 `TOOL-059=G1/F2/A5/C4/G2` 已写入 COVERAGE；`gap-too-fast`/`discovery-collapse` 依据 formal-127 正负五通道证据复审并串行 ack，最终 `alarms.py check` 为 clean。下一前线为 `TOOL-060 create_workflow`。
>
> **最新状态(2026-08-02 04:03):** 第六批已完成 **50 / 50**，中央账本 `350 judgments`，锚点校准有效，`alarms.py check` clean；因 formal-129/130 暴露的漏元数据风险又在 `ValidateInput` 增加了写库前存在性/类型门，并通过定向回归。随后按 fixture 审计清掉数据库中遗留的 acceptance conversation（DELETE=204→GET=404，SQLite `deleted_at` 对证）；全量 live 产品实体为零，唯一保留的是契约要求的最后一个 workspace。统一长门禁与一次性提交现在启动，门禁通过前不进入 `TOOL-061`。
> `TOOL-060 create_workflow` 的 formal-128 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-025448` 首轮红：模型将 `ops` 发成字符串且先后两次重试，前端留下两个失败活动；formal-129 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030431` 修复 ops 后暴露 metadata 槽位被模型静默省略；formal-130 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030934` 强化描述后仍暴露可选 metadata 被省略。三轮红证据均保留、不计绿。
> stop-and-fix 在 workflow 执行边界加入窄 `tags` decoder：原生字符串数组与精确 JSON 数组字符串均接受，逗号分隔文本、对象、非字符串元素拒绝；同时在 `ValidateInput` 写库前要求 `description`、`tags`、`changeReason` 三个键真实出现，空值只能分别用 `""`/`[]` 表达，显式 `null` 和错误类型拒绝。schema/工具描述、workflow 领域文档、错误码、抽取清册和 Go 守卫测试同步更新。
> formal-131 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-031452` 真实 App 重跑时 metadata 已到达但 `tags` 字符串在通用反序列化阶段失败，红证据为 `evidence/tool-060-formal-131-red-required-metadata-ops-error.txt`，没有 workflow 落盘且没有重试。
> formal-132 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-032142` 用新二进制、真实 onboarding、受管网关、Computer Use、三路 SSE witness、LLM tap 和连续录屏完成绿验证：模型只调用一次 `create_workflow`，真实 wire 同时使用 stringified `ops`/`tags`，后端成功创建 v1 inactive；REST 证明 description、tags、changeReason 逐字保存，graph 为 2 nodes/1 edge，UI 只有一张 `Created · v1 · Not activated` 活动卡，无 retry/get_workflow。backend/frontend 无未解释红线，四类资源 DELETE=204 后 GET=404，rig-down 正常。绿证据为 `evidence/tool-060-formal-132-green-stringified-metadata.txt`。
> 五级裁决 `TOOL-060=G1/F2/A5/C4/G2` 已写入 COVERAGE；gap/discovery 警报均以 formal-131 红与 formal-132 绿的完整五通道复审后串行 ack，最终 `alarms.py check` clean。下一前线为 `TOOL-061 edit_workflow`，但必须等本批统一长门禁与提交完成。
>
> **开工前提已满足**:另一团队的后端大改(BYOK 全目录 / 生成收归受管 / 音色 / 媒体子域 …)已并入
> `main`;本仓与隔壁 `Anselm-API-Serve` 均已对齐到各自最新 `main`。
>
> **本页是战役的唯一盘上真相**:对话记忆不是记录,任何会话中断/上下文压缩后,下一轮从本页 +
> 附属账本(Day 0 建)+ git 幂等续跑。战役期间**单一作者会话**(用户裁定,见 P11),施工在主树。

---

## §0 一句话与判据金字塔

**真实起 App、真实联通 Anselm 免费网关,以 Computer Use 逐帧驱动与观测,把产品的每一个角落
——真的全部——端到端测干净、修干净;遇到任何问题(含产品直觉级)停下修好再出发;
预期以一周为预算的连续 loop。**

每个被测点过**五级判据**,全过才算过:

1. **办成了吗**——用户目的达成(最高判据:不是步骤走完,是这件事真办成了)。
2. **真的吗**——五通道互证:UI 呈现 == SSE 帧 == DB 行 == 后端日志 == LLM 线缆,任何一对不一致即 bug。
3. **顺吗**——丝滑军规(跳变/闪/骨架/锚点漂移;录屏抽帧逐帧看)。
4. **美吗**——craft bar,对标 Linear/Things/Craft 级桌面手感;**看着不舒服就是 bug**,
   不需要「违反了哪条既有规范」作为立案理由(判决仍须援引法典或测量值,法不够就先立法)。
5. **一个新用户能自己走到这吗**——引导与可发现性。

## §1 拍板台账(证据分级:带原话 / 未被否决)

> 分级沿 WRK-082 §1 的教训:「带原话」= 引号内是用户对话原文;「未被否决」= 我提议、
> 用户未反对即入宪,效力相同、记录必须分开,随时可翻案。

**带原话(2026-07-27 讨论,按对话序)**:

| # | 决策 | 原话要点 |
|---|---|---|
| P1 | **战役本体**:真实起 App + 真实联通免费网关,Computer Use 监控每一帧,同时健康后端、SSE 流、前端 Terminal;每个问题停下修好再出发,细到打字跳变级 | 「真实起App,真实联通Anselm免费网关」「监控每一帧」「细致到你觉得这里打个字为什么有个跳变,这种问题我们都停下来修好再出发」 |
| P2 | **范围 = 产品真的全部**;难触发路径构造数据测 | 「你看代码发现这里有一个rag,OK那你就要测,即使这个rag是很难触发的,OK那我们构造数据测」 |
| P3 | **产品向修复直接修、无需过问** | 「你测试感觉这里用户等太久了不舒服,OK那你加对应提示。直接修改无需过问」 |
| P4 | **形态 = loop,一周为预期** | 「这个东西我的预期是一个loop,我们照着一周去跑」 |
| P5 | **product-driven 端到端**:判「用户目的达成没有」、跨域组合线在产品里通不通 | 「对话一下,是不是真的能达成用户的目的,比如说生图改图放workflow,这些东西在产品里通不通」 |
| P6 | **judge 标准 = craft 级**,视觉细节不合格即修 | 「Document里你滑一下,高亮一块内容。发现这个蓝色高亮不标准不好看,那就改,改成等高的舒服好看的」 |
| P7 | **两轮方案相乘**:全量清册的「面」×product-driven 五级判据的「深」,每格必填,无浅测点、无降级区 | 「我觉得我要的是我们这两轮说的东西乘起来」 |
| P8 | **网关侧临时去配额** | 「网关我会暂时做成没有配额的」 |
| P9 | **专用机器,24h 独占** | 「机器我单独给你配了一台电脑。这台电脑24小时都是你的,我不会打扰」 |
| P10 | **修复权限边界认可**(直接修 + 代拍台账,产品形状级决策才停下等拍)+ **前置工程认可**(台架与清册各投约一天) | 「产品边界我认。前置工程我也认」 |
| P11 | **单一作者连续施工,不换 agent;质量控制全靠机制**,用户不在场是默认假设;金标准取行业已知 | 「不同意换agent施工。我这边没办法老看你。我想这一切靠机制来控制。很多东西的金标准其实全行业都知道的」 |
| P12 | **旅程目录至少 400 条、非排列组合堆砌、对产品 100% 覆盖**——⏸ **用户 0728 裁定推迟到二期迭代,一期照现有 47 条旅程开跑**。原拍板:「Journey实在是太少太少了,产品的可能性非常多……至少400条,而且不是靠排列组合堆砌的……我希望能够做到对产品100%覆盖」;推迟原话:「那我们抛弃吧,我不想再浪费token了,journey的优化我后面放二期迭代」。**核验器 `testend/rig/check_journeys.py` 已在盘上并自证基线**(读 0%,因 47 条版无「扫」字段),二期照做法直接落:每条旅程带「扫」字段逐字认领清册行,脚本 diff 出未认领行,认领不动的进「幕后」段给理由。**一期不受阻**——清册 848 行仍是覆盖真相源,主循环按 COVERAGE 面矩阵驻停清扫,旅程只作路线 | 见左 |
| P13 | **对齐新 main 时整体清零我方代码差异**——两仓都拉到最新 `main`;`Anselm-API-Serve` 不允许有任何差异;本仓唯一允许的差异是 `docs/working/acceptance-loop/` 这套战役文档。据此撤下:台架三件套与两个 tap、测量脚本箱、gate/警报/核验器/生成器、`proxycore` 重构、后端 `ANSELM_PROOF_HOST`、`api.md` 四处 `[doc-fix]`(后三者原地已被新 main 的改动覆盖或作废) | 「我们这边不要有任何diff,抛弃我们所有其他的commit,对比最新main分支,API Serve不允许有差异,我们这边的差异是,我们这docs里加一下我们新的这个working」 |
| P14 | **P13 的撤下是误点,当日翻案:台架照原标准全量重落**——「标准不能变」;并新增一条硬要求:**台架必须做到任何 agent 都能用**(不依赖单一会话的记忆)——落为 [`testend/rig/README.md`](../../../testend/rig/README.md) 自足操作手册 | 「哦,我需要你给我把这些坐回来。标准不能变的。刚刚点错了……而且还有一个要求,哪个agent来都可以用」 |
| P15 | **以 50 个 COVERAGE 单格为一个施工批次**:单格仍逐个真实验证、发现即停修;累计到 50 格后统一跑门禁、完整 testend、警报复核并提交,不为赶批次降低质量 | 「门禁你也看到了,特别特别长,所以走完50个格子后,才开始统一搞一次门禁+提交」 |

**未被否决(我提议,用户未反对;翻案即改)**:

| # | 提议 | 要点 |
|---|---|---|
| N1 | **五通道观测**全部落盘 journal:帧(截图+录屏抽帧)/ 后端日志 / SSE tap(独立第四只眼)/ 前端 console / **LLM 线缆**(testend `harness.Recorder` 提升为台架常备件) | 「盯着看」过不了诚实律;第五通道是「不采信模型自述」唯一站得住的方式 |
| N2 | **二维矩阵双账**:面矩阵(清册行 × 五级判据列,格=裁决+证据指针,一行全列绿才算完)+ 旅程账(目的达成 **且** 沿途每站整列点亮才 ✅),互相引用、diff 出孤行与只路过未清扫的行 | 乘法的记账形 |
| N3 | **旅程走线 × 驻停清扫**:旅程给路线与产品语境;每到一站打开该面清册页穷尽掉(每状态/控件/边界/构造变体全过五级)才离站;无旅程经过的清册行写构造补线(仍以用户视角写) | 「带着房间清单的深度清扫,沿旅程路线走」 |
| N4 | **三压缩器**:原语级修复(修在 token/原语上,整列翻绿)· 同类横扫(发现一处即横扫同类面)· 现场立法(裁决沉淀成法,后面机械地审) | 乘法体量(万级格子)可行性的来源 |
| N5 | **控制系统六机制**(纯机制、零人力、单一作者,详见 §4):法典先行 / 判断降为测量 / 账本 gate / 锚点机械自校 / 统计警报 / 守卫+夜间门禁压舱 | 承诺的不是「不下滑」,是「下滑活不过一天且有纠偏程序」 |
| N6 | **旅程目录开跑前用户过目一次**——✅ 用户已过目并裁定现版太少；随后按 P12 明确把 400+ 扩写推迟二期，因此一期不再受此触点阻塞 | 唯一保留的用户触点已完成 |
| N7 | **完成判据 = 清册干涸(矩阵全绿),一周 = 预算非判据**;溢出诚实溢出在账上,绝不合并格子宣称测过 | 诚实律 |
| N8 | **AI 引导面也是产品面**:工具描述/system prompt 装配/模型跑偏时的兜底,判「产品聪明不聪明」,在直接修权限内,修完真对话复验 | AI 产品特有的一层 |
| N9 | **停与修分离**:停是义务(前线冻结、格子红着),修不必在同一口气里赶完 | stop-and-fix 的本义是前线不带病推进 |

## §2 战役形状:乘法模型

**旅程为「深」的载体、清册为「面」的保证,逐格相乘**:

- **旅程(Journey)**:一个真实用户带一个真实目的进来,端到端走完。预计 40–60 条主线 +
  死角补充线。示例密度(定稿在 JOURNEYS.md):生图迭代线(画→多轮改→嵌文档→@文档续聊→放 workflow
  日更)· 从零建自动化线(纯对话建 fn/agent/cron→真 fire→通知带图→`:iterate` 改→改坏 replay)·
  真实工作线(驻地挂真 git 仓、越界闸、worktree)· 长跑衰减线(100+ 回合、压缩后记忆、fork/retry/版本翻页)·
  吃进真世界线(PDF→笔记→fn 图表→嵌文档三保真)· 降级不失格线(断网/网关挂/key 失效/模态缺失,
  产品「诚实且体面」)。
- **清册(Coverage)**:从代码机械提取——113+ 工具注册表 / 28 REST 资源域 / 12 sidestage kind /
  7 block 型 / 5 图节点 kind / 4 trigger 源 / 5 overlap 策略 / 5 媒体产地 × 3 模态 × 6 渲染面 /
  13 设置面板 / 四海洋每屏每控件 / **i18n 键全集**(每个 key = 一个必须能到达的画面)/
  错误码按可浮上 UI 的类分层 / 难触发路径清单(RAG·压缩水位·410 重放·fork 重定基·envfix·
  配额边界·断网启动·install 自愈…每条带构造配方)。预估 600–1000 行。
- **乘法语义**:判据不因面偏僻而降级——错误态的措辞/排版/恢复路径/动效同样要过 craft 档;
  一站清完整列点亮,后续旅程再经过不重扫(被修复碰过的除外,触发回归重验)。

## §3 五通道台架(全部落盘,附自检)

| 通道 | 形态 | 答什么 |
|---|---|---|
| 帧 | Computer Use 截图 + `screencapture -v` 录交互段 → ffmpeg 抽帧 filmstrip | 跳变/闪/骨架/漂移——逐帧唯一取证方式 |
| 后端 | sidecar 日志全量 journal;场景收尾「零未解释 WARN/ERROR」+ DB 对证(`make -C backend seed` 的 probe env) | 执行的实际东西是否正确,以行为证 |
| SSE | 独立 tap(token+workspace 头连三条流,逐帧带时戳落 JSONL),不经前端 demux | seq 单调/durable·ephemeral 纪律/close 快照与 DB 一致 |
| 前端 | `flutter run` console 全量 journal;确认 FlutterError.onError/zone error 都汇到 console;任何红行 = issue | 隐藏前端报错 |
| LLM 线缆 | `harness.Recorder` 提升为台架常备件,provider base URL 指过它 | 模型这轮真收到了什么,逐字节,不采信模型自述 |

**台架自检**(F1 教训「先查夹具再报缺陷」):开工首事验台架自己——字体载齐、tap 真连上、
recorder 真在录;自检项常驻,台架变更后重跑。

## §4 控制系统(六机制,纯机制、单一作者)

1. **法典先行(CODEX)**:Day 0 把行业金标准一次性落成可执行法典——macOS HIG / RAIL·Doherty
   时延预算(<100ms 即时感、400ms 注意力阈、16.7ms/帧)/ WCAG 对比度 / 动效时长与 easing 标准区间 /
   Nielsen 错误信息十律 / 选区与文本渲染既知正确形,叠加仓内丝滑军规与 design token。每条法:
   ID + 尽可能机械的判定条件(px/ms/比率)+ 正反例。**裁决必须援引法条 ID 或测量值**,
   账本 lint 强制;援引不了 = 先立新法再判。
2. **判断降为测量**:能量的绝不用看——高亮等高(几何提取)/ 跳变(相邻帧像素 diff)/ 时延
   (操作时戳→首帧反馈差值)/ 对齐(包围盒对网格)/ 对比度(取色计算)/ 骨架时长(vs 160ms 闸)。
   每降一类,它永久退出「会下滑」的集合。眼睛只留给量不了的部分,且那部分也在「适用法律」。
3. **账本 gate**:标绿是脚本动作非文本编辑——校验证据文件真实非空、五通道 journal 齐、法条引用合法、
   该跑的测量脚本跑了且过、修复类格子附守卫测试;前置缺失,绿灯物理打不上。
4. **锚点机械自校**:Day 0 冻结一组锚点格子的裁决(含该过与该扣,craft 档为主);每次会话开工,
   harness 剥掉答案发盲判,脚本 diff 现判 vs 冻结判;不一致 → halt 标志、前线冻结,重读法典 +
   回审近期裁决,锚点全对才解锁。锚点永不更换、永不重判。
5. **统计警报**:夜间脚本算三条曲线,异常开警报单,警报未销则 gate 拒收新格子——通过速率异常偏高
   (橡皮章信号,该时段裁决入重审队列)/ 发现率骤降(更可能是判断失灵而非产品变干净)/
   裁决时戳间隔快得不像真看过录屏。
6. **守卫 + 夜间门禁压舱**:每修必带守卫测试;夜间全量 `make verify` + testend + 已修场景回归重放。
   机械部分不随状态波动。

**用户触点收敛到两点**:产品形状级拍板点(攒着,不阻塞的先代拍记入 §6 台账)+ 想看才看的周报。
系统按用户完全不看来设计(P11)。

## §5 Day 0 交付物清单(前置工程,约 1–2 天,全部入 git、全部过门禁)

1. 五通道台架 + 台架自检项(§3)。
2. 测量脚本箱(§4.2 各测量器)。
3. **CODEX.md** 法典(§4.1)。
4. **COVERAGE.md** 清册与面矩阵(§2;多 agent 机械提取 + 完备性批评家反向 diff)。
5. **JOURNEYS.md** 旅程目录(§2;开跑前用户过目一次,N6)。
6. 账本 gate 脚本(§4.3)。
7. 锚点集(§4.4)。
8. 警报脚本(§4.5)。
9. **[LOG.md](LOG.md)** 逐日日志 + 代拍台账(§6)。

证据(PNG/录屏/journal)落专机本地目录、不入 git,账上记指针;路径 Day 0 定稿后回填本节。

### 5.1 真机闭环(2026-08-01,当前实现)

在隔壁团队大改合并后的最新 `main` 上，以**全新数据目录**执行了一次完整闭环：`rig-up` 建并托管
五个进程组 → App 显示首次 onboarding → Computer Use 创建 `Rig Smoke` workspace → sidecar 经
本机 llmtap 完成 challenge/install/models(均 200)→ ssetap 在 workspace 出现后自动发现并接入
messages/entities/notifications 三流 → `rig-check` 五通道全绿 → `rig-down` 依次收 App、后端、SSE、
llmtap，最后以 SIGINT 封口录像。收台后无幸存进程，`screen.mov` 经 ffprobe 可读(78.02s)。

本轮不是“组件理论可用”，而是确认了以下真实边界：

- `screencapture -v` 录制中不会产生可读 MOV，故 L2 裁决只接受 **rig-down 后**已封口且 ffprobe
  可读的会话。
- onboarding 前没有 workspace；ssetap 必须常驻轮询并动态接管后续创建的每个 workspace，热切换
  也不得丢观察面。
- conductor 派生进程必须独立 session；普通后台子进程会随启动 shell 退出，造成“刚绿即死”。
- 透明代理只转发 `Flush` 不够；`ResponseController` 必须能 `Unwrap` 到 `Hijacker`，否则 SSE 正常而
  WebSocket 语音路径全部 500。真实 101 upgrade 已有守卫测试。
- Flutter runner 与 console、录像、后端和两类 tap 全部由同一 manifest 归属；外部手起 App 或旧
  sidecar 不算验收证据。

### 5.2 Day 0 当前状态(整体重述,2026-08-02)

| 交付物 | 当前真相 |
|---|---|
| 五通道 conductor | ✅ `rig-{up,check,down}.sh` 亲自托管 App、Flutter console、录像、后端、动态全 workspace SSE tap、LLM tap；D1 端口归属、受管 baseURL 接线、进程身份、journal 与三流连接持续自检。任一通道禁用时不得报验收绿 |
| 帧与 Computer Use | ✅ 屏幕权限、真实交互、MOV 封口、ffmpeg/ffprobe 全通；Computer Use 负责操作与现场截图，连续录像由 conductor 落盘 |
| SSE witness | ✅ `cmd/ssetap` 支持固定 workspace 与动态全 workspace；durable cursor 逐流续传，每帧带 workspace/stream/接收时戳 |
| LLM witness | ✅ `cmd/llmtap` 请求体与响应体逐调用留底；透明核同时保 SSE flush 与 WebSocket upgrade；device-proof 仍签真实受众，不放宽证明消费边界 |
| 测量脚本箱 | ✅ `cmd/measure` 提供 diff/regions/contrast/latency；diff 与 latency 支持 ROI，排除时钟、光标和无关动画；合成已知几何守卫绿 |
| CODEX | ✅ [WRK-088](CODEX.md) 八域 33 条法，裁决只能援引法条或测量值，法不够先立法 |
| COVERAGE | ✅ [WRK-089](COVERAGE.md) 已对齐新 main：工具 124 / 端点 257 / 面 114 / 边 353，共 **848 行 × 5 级 = 4240 格**；它是一期覆盖真相源 |
| JOURNEYS | ✅ [WRK-090](JOURNEYS.md) 现有 47 条只作一期路线；400+ 与逐行认领按用户 P12 推迟二期，不阻塞一期按 COVERAGE 驻停清扫 |
| 账本 gate | ✅ `judge.py` 校验证据文件、CODEX 法条、L2 六件五通道证据、三流连接、可读 MOV、开放警报和四小时锚点凭证；任一缺失物理拒收 pass |
| 锚点自校 | ✅ [WRK-091](ANCHORS.md) 冻结 10 个正反锚点；无答案答卷通过才签发绑定题集哈希的四小时凭证，题集变化或凭证过期自动锁 gate |
| 统计警报 | ✅ `alarms.py` 监控裁决过快、速率暴冲、发现率塌方；ack 必须写复审结论，且在出现新裁决前不会拿同一批历史原地复活；新证据到达后重新评估 |
| 操作手册 | ✅ `testend/rig/README.md` 自足描述起、检、停、校准、测量、裁决和警报，任何 agent 无需旧对话即可使用 |
| 产品主循环 | ✅ 已从第一条未裁决格启动；前置真实切片持续覆盖 onboarding、chat、composer、toc、log drawer、Read、Write、Edit、LS、Glob、Grep、Bash、BashOutput、KillShell、ask_user、todo_write、todo_read 以及 function 全生命周期。此前各工具切片中的产品语义、错误态和视觉问题均按 stop-and-fix 冻结、修复并真实重跑；第四批 TOOL-023 至 TOOL-032、第五批 TOOL-033 至 TOOL-046 已收尾并通过统一长门禁。formal-98/100 的 AXTree 红证据已冻结并推动稳定语义节点、定向测试与 rig-check 红线修复；formal-103 至 formal-132 已完成 control、approval、workflow search、workflow get 与 create_workflow 切片，所有正负路径均经真实 App、五通道和五级 gate。当前中央账本 350 judgments，锚点有效、警报 clean；第六批 **50 / 50**，统一长门禁与一次性提交待执行，下一前线 TOOL-061 暂不启动。 |

**当前执行状态（2026-08-02 00:08）。** `TOOL-050 revert_control` 正式 session 为 `/private/tmp/anselm-rig-formal-110/sessions/20260802-000259`。formal-109 首轮红证据确认 hosted model 首次发送 `version:"1"`，后端拒绝并在 App 留下失败 activity，随后模型 retry 成功；前线冻结后在 control 工具边界增加 exact decimal integer string 解码，公开 schema 仍保持 integer，浮点/布尔/数组/坏字符串继续拒绝，补 control 测试、工具描述和领域文档，定向 Go 测试通过。formal-110 正向真实只执行一次 `revert_control`，wire 的 stringified version 被接受，active pointer 从 v2 移到 v1 `ctlv_c05fb8b13fd7b636`，UI 只有一张成功 `Reverted control … · ↩ v1` activity，正文明确 v2 仍在 history；负向只执行一次 version 999，返回 `control logic version not found`，UI 只有一张失败卡且明确 active v1 unchanged，无 retry/新版本。screen.mov `147.631667s / 2784x1808 / 60fps`，SSE messages `1..29`、notifications `1..7` 连续，entities 已连接，LLM chat completion 全 200，backend 只有刻意负路径 WARN，frontend 无 runtime 红线；fixture/conversation DELETE=204 后 GET=404，台架已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央 300 judgments，锚点有效，警报最终 clean；第六批 4 / 50，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-051`。

**当前执行状态（2026-08-01 23:51）。** `TOOL-049 edit_control` 正式 session 为 `/private/tmp/anselm-rig-formal-108/sessions/20260801-234249`。formal-107 红证据确认同一用户意图被执行成缺 reason 的 v2 与带 reason 的 v3；前线冻结后将非空 `changeReason` 设为 AI schema 必填，并在 mutation 之前以 `CONTROL_CHANGE_REASON_REQUIRED` 拒绝缺失或空白值，补 control 测试与 error-code/领域文档，定向 `go test ./internal/app/tool/control ./internal/app/loop` 通过。formal-108 正向真实只执行一次 `edit_control`，wire 的 stringified branches 使用正确 `port`，reason 为 `acceptance TOOL-049 final fix`，后端创建 v2 `ctlv_34cbcddfc2f6d22a`，UI 只有一个成功 activity 和完整三分支表；负向只执行一次缺 reason 调用，后端返回 `input validation failed: changeReason is required`，UI 显示失败原因和 `Draft unsaved · truth is still the last version`，无 retry，REST active version 仍为 v2、没有 v3。screen.mov `189.023333s / 2784x1808 / 60fps`，SSE messages `1..29`、entities `7..8`、notifications `16..21` 连续，LLM chat completion 全 200，backend 只有刻意负路径 WARN，frontend 无 Flutter runtime 红线；fixture 与 conversation DELETE=204 后 GET=404，台架已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央 295 judgments，锚点有效，警报最终 clean；第六批 3 / 50，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-050`。

**当前执行状态（2026-08-01 23:30）。** `TOOL-048 create_control` 正式 session 为 `/private/tmp/anselm-rig-formal-106/sessions/20260801-232207`。formal-104 的托管模型字符串化 branches 和 formal-105 的 `name`/重复调用问题均先冻结为红并保留证据；修复后定向 `go test ./internal/app/tool/control ./internal/app/loop` 通过。formal-106 真实 App 正向只创建一个 `acceptance_control_fixture_106`，LLM wire 中 `branches` 是 JSON 字符串但 branch 使用正确 `port`，backend decoder 接受后返回 `ctl_a385d713822f5367`、active version `ctlv_fe1349dcbb94cd67`，UI 展示完整有序 `pass/review` 表且无红行；负向同一会话只尝试重复名称一次，返回 `control logic name already exists`，UI 明确显示未创建与错误解释，无 retry。录屏、五通道 journal、正负终帧和证据文件 `evidence/tool-048-formal-106-green.txt` 已封存；screen.mov `230.008333s / 2784x1808 / 60fps`，messages `1..29`、entities `7..8`、notifications `16..20` 连续，LLM chat completion request/response 全 200，backend 仅刻意负向 WARN，frontend 无运行时红线；fixture 与 conversation DELETE=204 后 GET=404，台架已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央 290 judgments，锚点有效，警报最终 clean；第六批已从 1 / 50 推进为 2 / 50，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-049`。

**当前执行状态（2026-08-01 18:16）。** `TOOL-036 search_agent` 已在正式 session `/private/tmp/anselm-rig-formal-20260801-78/sessions/20260801-181026` 完成正向名称命中、空 query 列全库和 identifier-shaped no-match 三条真实 App 路径；五通道证据、三张终帧和 fixture/对话清理事实均保留。该格尚未裁决，因为修复触及共享搜索语义原语，`search_function`、`search_handler` 等旧绿格必须先复验。Goal API 仍为 `blocked` 且不提供恢复操作；不创建重复 Goal、不谎报完成，盘上 `LOOP.md` 仍为 `active`，当前批次 **15 / 50**，下一动作是同类搜索复验。

**当前执行状态（2026-08-01 18:30）。** `TOOL-036 search_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`；共享 `ContentSearch` 影响的 `TOOL-014 search_function`、`TOOL-024 search_handler` 已由 formal session 79 对命中、空 query、identifier no-match 六条路径复验并恢复五级绿。formal-78/79 的五通道、录屏和终帧保留，三条统计警报复审并 ack 后为 `clean (230 judgments)`。本批新完成单格为 **16 / 50**（旧格复验不重复计数），未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-037 get_agent`；Goal API 仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal、不谎报完成。

**当前执行状态（2026-08-01 18:40）。** `TOOL-037 get_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`；formal-80 的严格正向最终字段表完整，负向不存在 ID 单次失败且无 retry，前置 setup 400、Bash 污染和中途未完成截图均不进入绿证据。五通道、视觉终帧、fixture/对话清理回执保留，警报复审并 ack 后为 `clean (235 judgments)`。本批新完成单格为 **17 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-038 create_agent`；Goal API 仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal、不谎报完成。

**当前执行状态（2026-08-01 19:10）。** `TOOL-038 create_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。formal-81 暴露首发 scoped SSE 竞态导致重复 user bubble，已修复普通 send 的 REST head reconcile，并通过 Flutter 37 项定向测试；formal-82 暴露显式 agent description 被托管模型漏发，已收紧工具契约、schema 描述、后端守卫测试和 agent 文档。formal-83 修复后正向 exact metadata 贯穿 LLM wire、entities、REST 和 UI，负向重复名只执行一次并显示可解释失败，无 retry/副作用；formal-84 无 Computer Use 基线确认 frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线，formal-83 动态 AXTree 行归类为观察器噪声。五通道、录屏、终帧、fixture/对话 DELETE→GET 404 和 SQLite `deleted_at` 均保留，警报复审并 ack 后 `clean (240 judgments)`。本批新完成单格为 **18 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-039 edit_agent`；Goal API 旧实例仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal。

**当前执行状态（2026-08-01 19:22）。** `TOOL-039 edit_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。前置冻结并修正 `get_agent` stale description、agent service 注释与领域文档，明确 LLM `edit_agent` partial merge、HTTP `:edit` full snapshot；定向 Go 测试与 docs verify 通过。formal-85 真实 onboarding + managed gateway + Computer Use 正向只改 agent prompt，UI 显示 v1→v2、version ID 和 preserved-fields 说明，REST activeVersion、mount-health `allHealthy=true`、skill/document/function relation 与 SQLite 只有 v1/v2 一致；负向不存在 ID 只执行一次，显示 `agent not found` 与 `Draft unsaved · truth is still the last version`，无 retry。LLM body 的历史 tool_calls 已经逐 body 复核为上下文回放，不是重复执行；backend 仅预期 not-found WARN。五通道录屏 `290.713333s`，LLM 7/9 全 200，SSE durable `messages 1..36`、`entities 1..4`、`notifications 1..15` 无 gap；frontend 除 Computer Use 诱发 AXTree bridge 噪声外无 Flutter/Dart/RenderFlex/Unhandled/Exception，formal-84 无 CU 基线已完成对照。所有 fixture 和 conversation DELETE=204→GET=404，进程已收台，警报复审并 ack 后 `clean (245 judgments)`。本批新完成单格为 **19 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-040 revert_agent`；Goal API 旧实例仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal。

**Day 0 已完成。** 主循环配置为从 COVERAGE 第一条未裁决格开始，遵守“台架先绿 → 锚点解锁 → 旅程走线
→ 到站清完整列 → 发现即冻结前线并修复 → 同类横扫 → judge 落账”的固定节拍；当前已完成
`EDGE-325`、`EDGE-326`、`SURF-003`、`SURF-010`、`SURF-011`、`SURF-012`、`SURF-013`、`SURF-014`、`TOOL-001`、`TOOL-002`、`TOOL-003`、`TOOL-004`、`TOOL-005`、`TOOL-006`、`TOOL-007`、`TOOL-008`、`TOOL-009`、`TOOL-010`、`TOOL-011`、`TOOL-012`、`TOOL-013`、`TOOL-014`、`TOOL-015`、`TOOL-016`、`TOOL-017`、`TOOL-018`、`TOOL-019`、`TOOL-020`、`TOOL-021`、`TOOL-022`、`TOOL-023`、`TOOL-024`、`TOOL-025`、`TOOL-026`、`TOOL-027`、`TOOL-028`、`TOOL-029`、`TOOL-030`、`TOOL-031`、`TOOL-032`、`TOOL-033`、`TOOL-034`、`TOOL-035`、`TOOL-036`、`TOOL-037`、`TOOL-038`、`TOOL-039`、`TOOL-040`、`TOOL-041`、`TOOL-042` 的五级裁决。首批 50/50 与第二批 50/50 均完成统一 `alarms.py check`、完整 testend、修复场景回归、工作树审计并提交；第三批已完成 **50 / 50**，`TOOL-022 search_function_executions` 已由真实 App + 五通道证据收尾，警报复审后 clean(150 judgments)，统一长门禁和最终审计均已通过并提交 `eb1ee050`；第四批已完成 **50 / 50**，`TOOL-023` 至 `TOOL-032` 均已过五级裁决，最新警报复审后 clean(200 judgments)，统一长门禁、完整 testend、修复场景回归、锚点/警报/进程/fixture/diff 审计均已通过；第五批当前 **30 / 50**，`TOOL-033` 至 `TOOL-042` 均已由正式五通道 session 收尾，最新警报复审后中央账本 clean(260 judgments)，formal-81/82、TOOL-039、TOOL-040、TOOL-041 和 TOOL-042 前置产品/契约问题均已修复并留存红证据，未到 50 格不运行统一长门禁，下一前线为 `TOOL-043`。

**当前执行状态（2026-08-01 21:13）。** `TOOL-043 invoke_agent` 的 formal-93 首轮红证据已保留：不存在 agent ID 的执行失败被右侧 Activity 错穿成实体编辑专用的 `Draft unsaved · truth is still the last version`，故冻结前线而未计绿。修复新增 `AnHonesty.failedRun`，按 create/edit/run 三类分流失败真相，补双语文案、W4 守卫测试和 frontend 文档；定向 `stages_w4_test.dart` 13/13 全绿。formal-94 以新二进制、真实 onboarding、真实受管网关和 Computer Use 完成正向 `search_agent → invoke_agent` 与负向不存在 ID 单次 invoke：正向结构化结果为 answer=4、confidence=1，负向只显示 `agent not found`，无 executionId、无 retry、无其它写操作；Activity 显示 `Run failed · inspect the error below`，不再出现 draft/version 误导。session `/private/tmp/anselm-rig-formal-94/sessions/20260801-210343` 的 screen.mov 为 `236.766667s / 2784x1808 / 60fps`；messages/entities/notifications durable 分别 `1..39`、`1..4`、`1..3`，LLM 20/20 状态响应全 200，backend 只有刻意负路径 WARN，frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线；REST、SQLite、UI、SSE 和 LLM wire 交叉一致。agent、conversation 均 DELETE=204→GET=404，成功 execution 保留，台架已收台无残留进程。五级裁决 `TOOL-043=G1/F2/A5/C4/G2` 已落账，锚点 10/10 通过，警报复审并 ack 后中央账本 clean(265 judgments)。Goal 与盘上 loop 均为 active；第五批 **35 / 50**，下一原子前线为 `TOOL-044 search_agent_executions`。

**当前执行状态（2026-08-01 21:40）。** `TOOL-044 search_agent_executions` 的 formal-95 首轮红证据已保留：Computer Use 输入污染导致越界生命周期操作；clean retry 又暴露列表携带完整 `transcript`、模型改写 opaque cursor 导致分页重叠。前线冻结后，列表裁剪 transcript，工具 description/schema 强化 cursor byte-for-byte 原样续传，补 store/tool 回归测试并同步 agent/API/extract 文档。formal-96 以新二进制真实重跑正向 2+1 无重叠分页与负向 `status=failed` 空结果，五通道、REST、SQLite、UI、SSE、LLM wire、backend/frontend journal 一致；录屏 `414.928333s / 2784x1808 / 60fps`，SSE durable `notifications 1..5`、`entities 1..12`、`messages 1..49` 连续，LLM 28 个状态响应全 200，fixture agent/conversation DELETE=204，台架已收台。五级裁决 `TOOL-044=G1/F2/A5/C4/G2` 已落账，锚点 10/10 通过，警报复审并 ack 后中央 clean(270 judgments)。Goal 与盘上 `LOOP.md` 均为 `active`；第五批 **40 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-045 get_agent_execution`。

**当前执行状态（2026-08-01 21:56）。** `TOOL-045 get_agent_execution` 的 formal-97 以新二进制、真实 onboarding、真实受管网关和 Computer Use 完成正向单条 detail 与负向不存在 ID。正向真实返回并在 App 报告完整顶层审计字段、input/output 和两条 transcript（reasoning→text）；对照 raw REST/LLM wire 后确认 off-chat loop block 的空 id/message/seq/status/零值时间是既定语义，前端 hydration 会为缺 id 生成稳定 `hblk_*`，不是字段被吞。负向只调用一次并显示 `agent execution not found`，无 retry/其它工具/写操作。screen.mov `286.645000s / 2784x1808 / 60fps`，SSE durable `notifications 1..3`、`entities 1..4`、`messages 1..28` 连续，LLM 18 个状态响应全 200，backend 仅预期 not-found WARN，frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线；fixture agent/conversation DELETE=204，台架已收台。五级裁决 `TOOL-045=G1/F2/A5/C4/G2` 已落账，锚点 10/10 通过，警报复审并 ack 后中央 clean(275 judgments)。Goal 与盘上 `LOOP.md` 均为 `active`；第五批 **45 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-046 search_control`。

## §6 施工中代拍台账(依据注明,用户可随时翻案)

| # | 代拍决策 | 依据 | 状态 |
|---|---|---|---|
| D1 | 台架自检增加「journal 归属验证」:服务端口持有者 PID == stdout 捕获对象 PID | §5.1 试用轮当场事故 | ✅ 立法,Day 0 实现 |
| D2 | 台架代码住 `testend/`:SSE tap 等 Go 观察者进 `testend/cmd/`(它本就是零 backend import、打纯 HTTP/SSE 的黑盒家),编排脚本进 `testend/rig/` | 复用既有模块与 harness 纪律,不为战役开新顶层目录 | ✅ Day 0 实现 |

## §7 施工序与完成判据

```
[前提] ✅ 另一团队后端大改已并入 main(0731),两仓已对齐
→ ✅ Day 0:五通道台架 + 清册 + 法典 + gate + 锚点 + 警报 + 操作手册全通
→ 主循环:旅程走线 × 驻停清扫,昼夜连轴(专机 24h,P9);
   交互扫面与门禁/testend/回归/数据预构造穿插
→ 收口:全量回归 sweep + 门禁全绿 + 本页收口重述 + landed-into + 归档
```

**完成判据 = 清册干涸(面矩阵全绿 + 旅程账全 ✅),一周 = 预算(N7)。**

## §8 风险与诚实台账

- **体量**:乘法格子万级;可行性押在三压缩器(N4)与测量脚本化上。头两天立法密集、进度看着慢,
  是曲线正常形状非失速。
- **真模型非确定性**:同一旅程两跑行为可异;判据锚在线缆证据与产品兜底(N8),区分「产品 bug」
  与「模型行为」,后者修引导面。
- **一周可能溢出**:长尾(错误码全类、全部难触发路径)可能出预算;诚实溢出在账上(N7)。
- **修复引入回归**:一周长跑里后面的修复可能踩坏前面的——守卫 + 夜间回归重放压舱(§4.6);
  被修复触碰的已绿格子重开重验(§2)。
- **环境依赖**:专机的 OS 权限(录屏/辅助功能)、网关无配额窗口期(P8)是外部前提,失效即前线冻结、
  记档等恢复。
