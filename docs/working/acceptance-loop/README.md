---
id: WRK-087
type: working
status: active
owner: "@weilin"
created: 2026-07-27
reviewed: 2026-08-10
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
> **上一状态(2026-08-02 04:04):** 第六批已完成 **50 / 50**，中央账本 `350 judgments`，锚点校准有效，`alarms.py check` clean；因 formal-129/130 暴露的漏元数据风险又在 `ValidateInput` 增加了写库前存在性/类型门，并通过定向回归。随后按 fixture 审计清掉数据库中遗留的 acceptance conversation（DELETE=204→GET=404，SQLite `deleted_at` 对证）；全量 live 产品实体为零，唯一保留的是契约要求的最后一个 workspace。统一 `make verify`、完整 `testend`、文档、锚点、警报、进程和工作树审计均通过，批次已提交 `8e2c93e4`。第七批从 **0 / 50** 开始，下一前线为 `TOOL-061 edit_workflow`。
> `TOOL-060 create_workflow` 的 formal-128 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-025448` 首轮红：模型将 `ops` 发成字符串且先后两次重试，前端留下两个失败活动；formal-129 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030431` 修复 ops 后暴露 metadata 槽位被模型静默省略；formal-130 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030934` 强化描述后仍暴露可选 metadata 被省略。三轮红证据均保留、不计绿。
> stop-and-fix 在 workflow 执行边界加入窄 `tags` decoder：原生字符串数组与精确 JSON 数组字符串均接受，逗号分隔文本、对象、非字符串元素拒绝；同时在 `ValidateInput` 写库前要求 `description`、`tags`、`changeReason` 三个键真实出现，空值只能分别用 `""`/`[]` 表达，显式 `null` 和错误类型拒绝。schema/工具描述、workflow 领域文档、错误码、抽取清册和 Go 守卫测试同步更新。
> formal-131 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-031452` 真实 App 重跑时 metadata 已到达但 `tags` 字符串在通用反序列化阶段失败，红证据为 `evidence/tool-060-formal-131-red-required-metadata-ops-error.txt`，没有 workflow 落盘且没有重试。
> formal-132 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-032142` 用新二进制、真实 onboarding、受管网关、Computer Use、三路 SSE witness、LLM tap 和连续录屏完成绿验证：模型只调用一次 `create_workflow`，真实 wire 同时使用 stringified `ops`/`tags`，后端成功创建 v1 inactive；REST 证明 description、tags、changeReason 逐字保存，graph 为 2 nodes/1 edge，UI 只有一张 `Created · v1 · Not activated` 活动卡，无 retry/get_workflow。backend/frontend 无未解释红线，四类资源 DELETE=204 后 GET=404，rig-down 正常。绿证据为 `evidence/tool-060-formal-132-green-stringified-metadata.txt`。
> **最新状态(2026-08-02 04:53):** 第七批当前 **10 / 50**，中央账本 `360 judgments`；锚点已重新校准，`alarms.py check` 在 formal-062 复审后 clean，未到第 50 格不跑统一长门禁、不提交。
> `TOOL-061 edit_workflow` 正向用户目的与缺失 workflow 失败边界均已用真实 App、受管网关、Computer Use、三路 SSE、backend/frontend journal 和 LLM wire 复核。正向证据来自 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-041823`；正式负向证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-042438/evidence/tool-061-formal-acceptance.txt`，只发一次合法 `edit_workflow`，只出现一张失败活动，无 retry、search、create 或 mutation。
> stop-and-fix 已修复 workflow `edit_workflow` 与文件系统 `Edit` 的工具描述/schema 碰撞，并补了 Go 工具描述回归；同时修复 New chat 清理 landing draft/附件的前端状态泄漏，Flutter 定向测试 22 项、workflow/loop Go 定向测试均通过。探索性错误调用保留为红事实，不计绿。
> `TOOL-062 revert_workflow` 的早期 formal-133 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-043458` 暴露 hosted model 将 version 发成字符串而首轮失败后 retry；formal-134 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-044050` 又暴露模型省略 version、先查 `get_workflow` 再 retry。两轮红证据均不计绿。stop-and-fix 在执行边界加入 native/exact-decimal-string decoder，并强化同一调用双必填、不得 inspect/retry、失败结果权威的工具描述/schema、Go 测试和 workflow 文档。
> formal-135 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-044518` 用真实 App、受管网关、Computer Use、三路 SSE、LLM wire、backend/frontend journal 完成正负五通道重跑：正向一次 stringified version `"1"` 成功回退 v2→v1；负向一次 version `999` 精确失败，无 retry、无 `get_workflow`。REST/SQLite 证明 active v1、v1/v2 两条历史保留；screen.mov `257.141667s`，前端无 runtime marker，后端仅刻意 not-found WARN。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-044518/evidence/tool-062-formal-acceptance.txt`。
> fixture 已按真实 API 清理：conversation `cv_45de987450a07cff`/`cv_d76f4c06c1b1556e` 与 workflow `wf_de4c9d5fd9192998` 均 `DELETE=204` 后 `GET=404`，三类列表均为空；SQLite 仅剩最后一个 live workspace，conversation/workflow live 行为零，messages/message_blocks/workflow_versions/notifications 审计行保留。下一前线为 `TOOL-063 delete_workflow`。
> 五级裁决 `TOOL-060=G1/F2/A5/C4/G2`、`TOOL-061=G1/F2/A5/C4/G2` 与 `TOOL-062=G1/F2/A5/C4/G2` 均已写入 COVERAGE；本批 gap/discovery 警报按证据重审并销账，当前账本为 `360 judgments`，可继续接受新 pass。
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

### 5.2 Day 0 当前状态(整体重述,2026-08-10 EP-174 已完成,批次二十九 50/50)

**当前前线（2026-08-10，清册 EP-174 已完成，批次二十九由 49→50/50；单格五级裁决、根门禁、独立完整 testend、警报复核、残留进程审计和提交均已通过，批次二十九已关闭；下一原子前线为 EP-175，批次三十从 0/50 开始）。**
EP-174 `GET /api/v1/sandbox/disk-usage` 验证的是用户在 Settings → Sandbox / Storage 看到机器级沙箱占用的完整产品目的：两个入口必须显示同一真实 manifest projection；loading、error、settled-empty 不能互相伪装；设置海洋常驻挂载时重新进入也必须刷新；删除环境后 REST、SQLite、前端投影与 SSE 必须有可解释的收敛关系。

首轮真实 App/REST 冻结为红：REST 已返回 `totalBytes=475033055` 且 `ep174_disk_probe` env manifest 存在，但 Sandbox 和 Storage 都显示 `0 B`，切换面板和重新进入设置也没有修复。红证据保留在 `/private/tmp/anselm-rig-ep174-20260810/sessions/20260810-053705/evidence/EP-174-red-stale-disk.png` 及其 session。stop-and-fix 严格解析非负整数 `totalBytes`（合法零仍保留），两个面板共用 `AnLastGood` 的 loading/error+Retry/data 三态，并在 Sandbox/Storage 进入和 Settings 重入时失效全机 provider；同步补 Flutter fixture/widget 回归、testend 精确 manifest-sum 断言和 backend/frontend reference 文档。修复没有把错误或空机伪装成 `0 B`。

最终真实 session `/private/tmp/anselm-rig-ep174-20260810/sessions/20260810-055332` 使用真实 Flutter macOS App、Computer Use、真实受管 Anselm gateway wiring、独立三路 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 197.005000s` 封口录屏。Sandbox 真实显示 `453.0 MB` 与 `ep174_disk_probe`；Storage 显示同一数值；切换和离开/重入 Settings 后不再回到红态。确认删除 env 后 Sandbox 显示 `No environments`，REST/SQLite 精确从 `475033055` 收敛到 `475002591`，delta=`30464` bytes，正好等于 env manifest；因为 delta 小于一位小数的显示阈值，Storage 仍诚实显示 `453.0 MB`，不是 stale provider。之后通过 API cleanup session `/private/tmp/anselm-rig-ep174-cleanup-20260810/sessions/20260810-060148` 删除临时 Function，DELETE=`204`、后续 GET=`404 FUNCTION_NOT_FOUND`、function env list 为空；没有直接改 SQLite。

五通道封口：`rig-check` 收台前五通道全绿，messages/entities/notifications 三流连接并 clean EOF；删除产生的 `sandbox.env_deleted` 是 notifications stream 的 frame-only `Broadcast` reconciliation echo，不是 notifications inbox durable row，REST/SQLite 仍是删除真相；本只读/删除路径没有伪造 message/entity 业务帧。managed challenge/install/models 穿过 llmtap，确定性 settings 路径没有伪造模型 completion；backend journal 无 WARN/ERROR/panic/FATAL，frontend 除已知 launcher foreground 噪声外无 Flutter/Dart/layout/Unhandled 红线。证据集中在 fixed session 内 `EP-174-final-green.md`、`EP-174-rest-db-sse.md`、`EP-174-frontend-terminal-review.md`、`EP-174-llm-summary.txt`、`EP-174-latency.txt`、五张视觉帧和录屏，红 session 与 cleanup session 保留。

逐帧/测量证据只记录能证明的事实：两次 REST exact byte projection 与 `30464` delta 已重算，UI 的 `453.0 MB` 不被错误解读为没有刷新；稳定帧没有 blank/loading/error 伪装。正式裁决写入 `G1 / F2 / measure:sandbox-disk-refresh / C4 / G2`，`COVERAGE EP-174=✓✓✓✓✓`；formal ledger `1560→1565 judgments`。每次写账触发的 `gap-too-fast`/`discovery-collapse` 都按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-174-sandbox-disk-usage-ledger-reaudit.md` 独立复审并逐条 ack；anchors=`10/10`，未修改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (1565 judgments)`；`gen_coverage.py --check`=`848 rows / 306 carried judgments / 0 tombstones`。

本轮代码与文档落点为 `frontend/lib/features/settings/{data/settings_repository.dart,ui/panels/{sandbox_panel.dart,storage_panel.dart},ui/settings_ocean.dart}`、中英文 i18n 及生成文件、`frontend/test/features/settings/{s5_sandbox_test.dart,s5_storage_limits_test.dart}`、`testend/scenarios/{platform_test.go,platform_r4_test.go}` 和 `docs/references/{backend/api.md,backend/foundation/sandbox.md,frontend/features/settings.md}`；工作证据与 formal ledger 均保留在 `/private/tmp`，不把录屏或临时数据带进仓库。根 `make verify` 第二轮全绿；完整 testend 第二、三轮全绿，第三轮 JSON 为 `356` 个 pass、`0` 个 fail；第一次 `287.787s` 异常保留在 `EP-174-batch29-gate.md`，未复现且未被删除。批次二十九 **50/50 已关闭**，提交为 `ad64c505`；下一原子前线为 EP-175 `GET /api/v1/sandbox/bootstrap-status`，批次三十从 **0/50** 开始。P12 旅程 400+ 继续按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。

### 5.2 历史状态快照（EP-154，批次二十八 35/50）

**历史前线（2026-08-09，清册 EP-154 已完成，批次二十八当时 35/50；按用户裁定未到 50 格，不跑批次统一长门禁、完整 testend 或提交）。**
EP-154 `POST /api/v1/conversations/{id}/messages` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只得到一个 `202`，而是让用户在真实 Composer 中只附一张图也能完成一个完整回合：user 行先落库并回声，assistant 流式行打开并闭合，模型真实看见图片并返回可读答案；随后同一真实对话显式命中 `inspect_media`，在代理图超过受管网关 3 MiB 解码预算时诚实回退原图，不把上游 400 暴露给用户。

最终 session 为 `/private/tmp/anselm-rig-ep154-20260809/sessions/20260809-195358`，`screen.mov` 已由 rig-down 封口可读（`2784x1808 / 60fps / 432.191667s`），稳定终帧为 `accepted-frame.png`。Computer Use 真实走过附件菜单、macOS 文件选择器、`Preparing media...`、原图缩略图、发送、助手完成态以及第二轮 `inspect_media` 工具调用；最终 UI 有完整结构化表格、历史背景、操作行和可用 Composer，没有红色工具失败、死 spinner、重复错误、布局跳变或隐藏 CTA。

本场首个真实附件 session 曾抓到一条真实红线，保留在 `/private/tmp/anselm-rig-ep154-20260809/sessions/20260809-194419`：1,111,731-byte JPEG 的 model-default PNG proxy 为 5,238,623 bytes，网关返回 `BAD_REQUEST media exceeds the per-request decoded size limit`。stop-and-fix 将预算依据改为最终 staging bytes；受管图片 proxy 超预算但原图可交付时回退原图，`inspect_media` 同样使用该规则，proxy 与原图都不可交付时返回结构化 budget-degraded 说明而不是发出必败请求。定向 `internal/app/attachment`、`internal/app/tool/attachment`、`internal/bootstrap` Go tests 已通过。

五通道正式证据为 session 内 `evidence/EP-154-final-green.md`，SSE 汇总、DB 真相、LLM wire、前端终端复核和清理回执分别为 `EP-154-sse-summary.txt`、`EP-154-db-final.txt`、`EP-154-llm-summary.txt`、`EP-154-frontend-terminal-review.md` 与 `EP-154-fixture-cleanup.md`。三路 SSE 均物理连接；messages durable `seq=1..24` 单调，完整记录 attachment-only user echo、assistant close、`inspect_media` tool_call/tool_result 和最终 `message close`；notifications 观测到 conversation 创建与自动标题，entities 连接正常。SQLite 中四条 message 和九条 block 全为 `completed`，无 pending/streaming/error/cancelled 残留；工具结果含 `width=2560,height=1970` 与“proxy 超预算、改检原图”note。

backend journal 无应用 WARN/ERROR/panic/FATAL；frontend 只有已知 runner 启动器 `Failed to foreground app; open returned 1`，随后 Flutter resident 正常且无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device 红线，启动器噪声被单独归类并保留。llmtap 的 challenge/install/models、两次图片 staging、primary chat、nested vision 和外层收尾均为 HTTP `200/201`，无 4xx/5xx 或 `BAD_REQUEST`。发送动作到首个可见反馈的 `testend/cmd/measure latency` 为 `100.0ms`，满足 CODEX A1；稳定终帧人工复核通过产品视觉标准。收台后 Flutter、后端、ssetap、llmtap、recorder、llama runtime 和监听均归零。

本场账本写入前 anchors=`10/10`，`alarms.py check`=`clean (1460 judgments)`；五级裁决 `G1/F2/A1/C4/G2` 已写入，中央账本由 `1460→1465 judgments`，`COVERAGE EP-154=✓✓✓✓✓`。写账后按机制打开 `gap-too-fast` 与 `discovery-collapse`；独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-154-messages-ledger-reaudit.md`，确认红线、修复链、五通道原始 journal、视觉测量和最终帧齐全后逐条 ack，未修改阈值、算法、法典、锚点或账本规则；最终 `alarms.py check`=`clean (1465 judgments)`。P12 旅程 400+ 继续按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。
当时下一原子前线为 EP-155 `GET /api/v1/conversations/{id}/messages`；批次二十八由 **30→35/50**，未到 50 格不跑统一门禁、不提交。

### 5.2 历史状态快照（EP-153，批次二十八 30/50）

**历史前线（2026-08-09，清册 EP-153 已完成，批次二十八当时 30/50；按用户裁定未到 50 格，不跑批次统一长门禁、完整 testend 或提交）。**
EP-153 `POST /api/v1/conversations/{id}/workdir:add-worktree` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只执行一次 `git worktree add`，而是让用户在当前对话中发现并理解“平行工作树”这一能力，看到它会创建在仓库旁、绑定 `wt/<name>` 分支、把对话迁移到新的真实工作目录；冲突、非法名称和复用既有分支时都给出可行动结果，而不是接管或污染用户已有目录。

EP-153 真实 session 为 `/private/tmp/anselm-rig-ep153-20260809/sessions/20260809-190946`，`screen.mov` 已由 rig-down 封口可读（`2784x1808 / 60fps / 512.488333s`）。Computer Use 在真实 App 中打开 workdir 菜单，先看到当前 `Branch main`、`No uncommitted changes`、本地分支和既有 worktree；初始菜单较长，真实滚动后 Git 操作区和 `Open a worktree…` 可见，随后打开对话框。对话框明确说明平行 checkout、`wt/<name>` 命名、对话会迁移以及不会自动 commit/push；真实输入 `session` 并确认后，App、REST projection、外部 Git 和当前对话 residency 一致变为 `/private/tmp/ep153-repo.ZkdbHn-session` / `wt/session`。第二次用同一真实菜单和 REST 创建 `reopen`，成功复用预先存在但未被 checkout 的 `wt/reopen` 分支，App 刷新为 `/private/tmp/ep153-repo.ZkdbHn-reopen`；Worktrees 区正确列出其他工作树且不把当前项重复列入。两次 Composer 均经真实受管 gateway 精确返回 `EP153-ACK`、`EP153-REOPEN-ACK`。

REST/SQLite/fixture 交叉证据固定在该 session evidence：首次创建返回 200，路径为仓库旁的平面 sibling，branch=`wt/session`、`dirty=false`，外部 `git worktree list` 与 UI projection 一致；`taken` 冲突返回 409 `CONVERSATION_WORKTREE_EXISTS` 并给出具体阻挡路径 `/private/tmp/ep153-repo.ZkdbHn-taken`，碰撞目录 `SENTINEL.txt` 的 SHA-256 前后保持 `70e85898d13a5318b2a0c59dad361eb2d9cd5be94208b5b16a3e1c21cc31c4cb`。`../escape`、`/absolute`、`nested/deep`、`..`、`-b` 均返回 422 `CONVERSATION_INVALID_WORKTREE_NAME`；复用 `reopen` 返回 200 并新建 sibling worktree，不接管碰撞目录、不改变 main HEAD。第二次 residency 变化在已有 transcript 后落下恰好一个 `kind=workdir` marker；第一次空线程迁移不伪造 marker。最终 REST 与 SQLite 都保留七条消息块、marker、当前 workdir 和两次精确回复。

五通道正式证据为 `/private/tmp/anselm-rig-ep153-20260809/sessions/20260809-190946/evidence/EP-153-final-green.md`，SSE 汇总、DB 真相、前端统计、AX/终端复核和清理回执分别为同 session 的 `evidence/EP-153-sse-summary.txt`、`evidence/EP-153-db-final.txt`、`evidence/EP-153-frontend-stats.txt`、`evidence/frontend-terminal-review.md` 与 `evidence/EP-153-fixture-cleanup.md`。三路 SSE 均物理连接，messages 共 29 条记录、16 条 durable、max seq=`16`，notifications 共 6 条记录、4 条 durable、max seq=`4`，entities 已连接且本旅程无 durable entity event；llmtap proof/install/models/chat 全部 HTTP 200。backend journal 无应用 WARN/ERROR/panic/FATAL；frontend 只有启动器 `Failed to foreground app; open returned 1` 一行，随后 Flutter resident 正常、无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device/panic/fatal，独立终端复核在 8 秒 idle 内零增长；该启动器噪声被单独归类，没有从证据中静默删除。收台后 Flutter、后端、ssetap、llmtap、recorder 和 8902/8903 监听均归零。

本场账本写入前，统计检查按机制打开 `gap-too-fast` 与 `discovery-collapse`；独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-153-conversations-add-worktree-ledger-reaudit.md`，anchors=`10/10` 后逐条 ack，写入前 `alarms.py check`=`clean (1455 judgments)`。五级裁决 `G1/F2/A1/C4/G2` 已写入，中央账本由 `1455→1460 judgments`，`COVERAGE EP-153=✓✓✓✓✓`。写账后统计警报按新 evidenceThrough 再次打开，第二次独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-153-post-judgment-alarm-reaudit.md`，anchors 仍为 `10/10`，逐条 ack 后最终 `alarms.py check`=`clean (1460 judgments)`；没有手改阈值、算法、法典、锚点或账本规则。定向 Go conversation/gitinfo/httpapi handler tests、Flutter workdir menu tests（23 项）、`gen_coverage --check`（848 rows / 285 carried / 0 tombstones）、`git diff --check`、`make -C docs verify` 已通过。所有 EP-153 临时 fixture 与隔离数据已在证据封存和裁决后按用户授权通过 `/usr/bin/trash` 移入 Trash，session 证据保留。P12 旅程 400+ 继续按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。
下一原子前线为 EP-154 `POST /api/v1/conversations/{id}/messages`；批次二十八由 **25→30/50**，未到 50 格不跑统一门禁、不提交。

### 5.2 历史状态快照（EP-146，批次二十七 45/50）

**历史前线（2026-08-09，清册 EP-146 已完成，批次二十七当时 45/50；未到 50 格，不跑统一长门禁、不提交）。**
EP-146 `DELETE /api/v1/conversations/{id}` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、三路独立 SSE witness、
frontend console 和 llmtap 的五级验收。产品目的不是只返回一个 `204`，而是让用户能明确删除当前对话，删除后从 rail 和所有详情入口消失；其消息审计仍按 D1 保留，关系与触点不留下幽灵边，生成中的回合被安全取消，删除后应用仍能继续工作。

正式 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-160637`，由 conductor 归属 backend、SSE tap、LLM tap、Flutter runner 和录屏，`screen.mov` 已封口可读（`2784x1808 / 60fps / 678.315s`）。真实 App 从 More actions 打开确认对话框，确认后目标 `EP146 DELETE target` 立即从 rail 消失并回到可用空 composer；同一测试通过受管 gateway 发送带 function mention 和附件的消息，真实回复精确为 `EP146-ACK`。REST/SQLite 交叉证明删除头为 `deleted_at` 软删，GET/list/messages 均为 `404/不出现`，消息与 blocks 仍保留，relations 与 conversation_touchpoints 均清零；附件和 function fixture 不被错误级联删除。

关系路径又用真实 fork 验证：源对话到 fork 的 `create` relation 在删除 fork 后双向查询均为空，fork 头软删而消息审计仍在。随后真实受管长回合 `EP146 in-flight delete` 在 `isGenerating=true` 时从 App 删除，assistant 终态为 `cancelled`，取消后的部分 durable 文本不丢失；删除后新建 `EP146 post-delete health` 并得到精确 `EP146-POST-OK`，证明取消没有毒化 conversation queue 或后端。重复删除、missing id、跨 workspace、普通/生成中状态和删除后详情入口均纳入矩阵。

五通道证据包括非空 `manifest.json`、`backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl` 和上述已封口录屏；三路 SSE durable 序列均连续，notifications 观测到 `conversation.deleted`，messages 观测到取消回合的 assistant block/message close；llmtap 的 challenge、install、models、两次 chat completion 均为 `200`，真实请求体和上游响应均留存。backend/frontend 没有 panic、FATAL、未处理 Flutter/Dart/RenderFlex/overflow 红线；取消瞬间唯一的 `incremental block persistence failed: context canceled` 已逐行复核为可选增量写入与删除取消竞态，detached finalizer 随后成功完整落盘，故保留为可解释的预期取消噪声，不隐藏也不改阈值。启动包装器的已知 `Failed to foreground app; open returned 1` 仍单独分类。

正式绿证据为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-160637/evidence/EP-146-final-green.md`，独立账本复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-146-conversations-delete-ledger-reaudit.md`；裁决 `G1/F2/A1/C4/G2` 已写入，账本由 `1420→1425 judgments`，
`COVERAGE EP-146=✓✓✓✓✓`，anchors `10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按独立复审逐项 ack，原阈值、算法、法典和锚点未变，最终 `alarms.py check`=`clean (1425 judgments on record)`。

定向 conversation/chat/store/relation/touchpoint/httpapi 验证、`python3 testend/rig/gen_coverage.py --check`（848 rows / 278 carried judgments / 0 tombstones）、`make -C docs verify`、
`git diff --check` 均通过。EP-146 临时数据目录按用户授权通过 `/usr/bin/trash` 移入 Trash，formal session、录屏、journals、红绿证据和账本保留；P12 旅程 400+ 仍按用户裁定推迟二期，一期以 COVERAGE 矩阵为覆盖真相。批次二十七由 **40→45/50**；未到 50 格不跑统一长门禁、不提交。
下一原子前线为 EP-147。

### 5.2 历史状态快照（EP-142，批次二十七 25/50）

EP-142 `POST /api/v1/conversations` 的五级验收、REST 边界、真实 App 创建/首条消息/自动标题、五通道证据、fixture Trash、账本 `1400→1405` 和警报复审已在
`LOG.md` 及其 session evidence 中封存；本快照保留其当时前线，当前推进以本节 EP-144 整体重述为准。

### 5.2 历史状态快照（EP-141，批次二十七 20/50）

**历史前线（2026-08-09，清册 EP-141 已完成，批次二十七当时 20/50；未到 50 格，不跑统一长门禁、不提交）。**
EP-141 `POST /api/v1/documents/{id}:iterate` 已按完整产品目的完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、
三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只返回一个 `202`，而是让用户能从 Library 文档行的 More actions 找到 `Edit with AI`，
进入带当前文档 mention 的持久 Chat 对话，用自然语言提出精确修改，并看到真实文档被修改；标题、description、tags、Promise heading 和子页必须保持不变，
空请求、坏输入、目标不存在和缺 workspace 必须给出真实错误且不产生幽灵 conversation。

EP-141 的独立 REST/SQLite/SSE 矩阵固定在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-131242` 的
`evidence/EP-141-rest-boundary-matrix.jsonl`：有效请求真实返回 `202` 并创建 conversation，模型随后真实调用 `read_document` 和 `edit_document`；空/空白请求为
`400 EMPTY_ITERATE_REQUEST`，请求类型/坏 JSON 为 `400 INVALID_REQUEST`，缺文档为 `404 DOCUMENT_NOT_FOUND`，缺 workspace 为 `401 UNAUTH_NO_WORKSPACE`，所有负向
均无幽灵文档或 conversation 行。REST 有效编辑只改变目标正文首句，子页、description 和 tags 与 SQLite/REST 真相一致。

首轮产品走查发现后端 endpoint 已存在，但 Library 行菜单没有 affordance，用户无法发现能力；stop-and-fix 增加 `LibraryRepository.iterateDocument` 的 live 请求、
fixture 同语义、行级 `Edit with AI` 菜单、中文/英文文案、精确 Dio wire test、真实 widget journey test 和 Library reference 文档。真实 App 通过
Library → More actions → Edit with AI 进入 Chat，自动种下 `Help me edit “Product Brief UI” with AI.`；随后提出具体句子修改，模型只编辑目标 id，
Activity 显示 `1 touched / Edited`，回到 Library 后正文、标题、description、tags、Promise heading、Path、size 和 outline 均正确。菜单终帧含 Rename、Duplicate、
Edit with AI、Delete；中途 `Untitled` 是返回 Library 后尚未选择文档的正常空选区，不是数据丢失，之后两帧稳定终态逐像素一致。

最终真实 App session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-131242` 的 backend D1 为 `:8742`/PID `48325`，ssetap PID `48339`，
llmtap `:8788`/PID `48301`，Flutter runner `48341`，窗口 recorder `48961`；rig-down 后进程组和监听端口归零。录像封口为 H.264 `2784x1808 / 60fps /
409.856667s`，messages/entities/notifications 三流均连接；backend 无应用 `WARN/ERROR/panic/FATAL`，frontend 无 Dart/Flutter/Unhandled/RenderFlex/overflow 红线。
Flutter runner 的一次 `Failed to foreground app; open returned 1` 发生在启动阶段，随后 App 正常 resident，已作为 runner 提示而非产品错误记录。llmtap wire 确认真实
gateway readiness、文档 mention、精确编辑请求、工具调用和最终确认一致。

封口证据为 session 内 `evidence/EP-141-document-iterate-final-green.md`，临时 fixture 清理回执为同 session 的 `evidence/EP-141-fixture-cleanup.md`，
独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-141-document-iterate-ledger-reaudit.md`；临时数据已按用户授权移入 macOS Trash，
正式 session、录像、journal、矩阵和证据均保留。最终稳定画面 `395→405` 经 `measure compare` 为 `changedFrac=0, pass=true`。

正式账本由 `1395→1400 judgments`，五级法条为 `G1/F2/A1/C4/G2`，`COVERAGE EP-141=✓✓✓✓✓`；anchors `10/10`。写账后 `gap-too-fast` 与
`discovery-collapse` 按原阈值打开，独立复审确认真实 409 秒录像、五通道 journal、正负向 REST 矩阵、stop-and-fix 证据、视觉测量和定向测试齐全后 ack，未修改
阈值、算法、法典或锚点；最终 `alarms.py check`=`clean (1400 judgments on record)`，`gen_coverage.py --check`=`848 rows / 273 carried / 0 tombstones`。
P12 旅程 400+ 扩写仍按用户裁定推迟二期，一期以 COVERAGE 矩阵为覆盖真相。

定向 Flutter Library/repository `57` tests、backend `aispawn/document/httpapi` 选择性回归、testend document iterate contract、`git diff --check`、
`anchors.py check`、`alarms.py check` 和 `gen_coverage.py --check` 均通过。批次二十七由 **15→20/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-142
`POST /api/v1/conversations`。

### 5.2 历史状态快照（EP-140，批次二十七 15/50）

**历史前线（2026-08-09，清册 EP-140 已完成，批次二十七当时 15/50；未到 50 格，不跑统一长门禁、不提交）。**
EP-140 `POST /api/v1/documents/{id}:duplicate` 已按完整产品目的完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、
三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只返回一个 `201`，而是让用户能从 Library 的行级 More actions 找到 Duplicate，
得到一棵拥有新 ID、正确父子关系和路径的完整副本，保留正文/描述/标签/wikilink 出边，并在复制后立即打开新根，不用猜副本去了哪里；空 body/`parentId:null`
按源同级放置并自动根名去重，显式 `parentId` 放到指定父级，坏输入、缺源、缺父和缺 workspace 必须给出真实错误且不产生幽灵成功。

EP-140 的独立 REST/SQLite/SSE 矩阵固定在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-124218`：覆盖根级同级复制、显式父级、空 body、
`{parentId:null}`、嵌套源、显式后代父级，以及 missing source/parent、空父、坏 JSON、unknown field、缺/错 workspace；成功响应均为 `201`，负向为预期的
`404/422/400/401`。结构证据确认每个节点都是新 ID，`parentId/path/position` 正确重映射，正文、description、tags 和深层孙节点完整保留；关系证据确认
复制出的 wikilink 出边使用新 relation ID。接口真实边界也写明：逐节点写入，不宣称跨整棵子树原子。

为避免测试环境撒谎，fixture repository 的 duplicate 从浅复制改为与 live service 同语义的 BFS 深拷贝：新 ID、根名去重、目标父级、路径、位置和全部 metadata
均覆盖；backend tests 增加显式父级、metadata、子孙和 wikilink relation 回归。API 与 Library reference 同步记录 `201`、空父语义、深拷贝字段和非原子边界。
这轮没有发现 live backend duplicate 的产品源代码红；真正修复的是测试 fixture 与线上契约不一致这一测试基础设施缺陷。

最终真实 App session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-124808` 从干净 fixture 起步。Computer Use 通过 More actions → Duplicate 创建
`Duplicate Source 2`，新根自动打开；再进入 `Child One` 和 `Grandchild`，逐页确认 body、description、tags、breadcrumb、Path、size、modified 和层级均正确。
侧栏树即时出现完整复制子树，画面无路径滞后、裁剪、光标跳变或未解释布局红线；notifications 只收到该 UI duplicate 的一个 durable
`document.created`（seq=1）。

最终五通道 session 的 backend D1 为 `:8895`/PID `44395`，ssetap PID `44412`，llmtap `:8795`/PID `44369`，Flutter runner `44414`，窗口 recorder `44811`；
rig-down 后录像封口为 H.264 `2784x1808 / 60fps / 458.446667s`，监听端口和进程均归零。messages/entities/notifications 三流均连接，backend 无
`WARN/ERROR/panic/FATAL`，frontend 无 `Unhandled exception/FlutterError/Lost connection/RenderFlex/overflow`；确定性 duplicate 不虚构 LLM completion，gateway
challenge/install/models 的真实 wire 证据保留在 setup session `.../124107`。

封口证据为 session 内 `evidence/EP-140-document-duplicate-final-green.md`，fixture 清理回执为同 session 的 `evidence/EP-140-fixture-cleanup.md`，独立账本复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-140-document-duplicate-ledger-reaudit.md`；临时数据已按用户授权提交 macOS Trash，正式 session、录像、journal、
矩阵和证据均保留。

正式账本由 `1390→1395 judgments`，五级法条为 `G1/F2/A1/C4/G2`，`COVERAGE EP-140=✓✓✓✓✓`；anchors `10/10`。写账后 `gap-too-fast` 与
`discovery-collapse` 按原阈值打开，独立复审确认最终 458 秒录像、五通道 journal、负向 REST 矩阵和逐页 Computer Use 证据齐全后 ack，未修改阈值、算法、法典
或锚点；最终 `alarms.py check`=`clean (1395 judgments on record)`，`gen_coverage.py --check`=`848 rows / 272 carried / 0 tombstones`。P12 旅程 400+
扩写仍按用户裁定推迟二期，一期以 COVERAGE 矩阵为覆盖真相。

定向 backend document/handler/store Go tests、Library + live-metrics Flutter `60` tests、fixture `dart format`、`gofmt`、`make -C docs verify`、
`gen_coverage.py --check` 和 `git diff --check` 均通过。批次二十七当前由 **10→15/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-141
`POST /api/v1/documents/{id}:iterate`。

### 5.2 历史状态快照（EP-139，批次二十七 10/50）

**历史前线（2026-08-09，清册 EP-139 已完成，批次二十七当时 10/50；未到 50 格，不跑统一长门禁、不提交）。**
EP-139 `POST /api/v1/documents/{id}:move` 已按完整产品目的完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、
三路独立 SSE witness、frontend console 和 llmtap 的五级验收。产品目的不是只返回一个 `200`，而是让用户能在 Library 里把文档移到根级或嵌套父级、
在同级上下缘重排、保留整棵后代子树，并且不重新选择页面就能从树、面包屑、正文和右岛 Path/Modified 看懂最终位置；非法位置、自落、成环和越界必须在
mutation 前拒绝，重复同槽移动必须是真 no-op。

首轮真实红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-115232` 发现负数/过大 position 被静默接受并发布移动，红证据
`evidence/EP-139-document-move-red-negative-position.md` 永久保留、不计绿。stop-and-fix 增加 `DOCUMENT_INVALID_POSITION`，将显式位置收紧为目标同级
插入下标 `0..N`（含末位），校验在任何写入/发布前完成；随后又补出同父同解析位置的 no-op 守卫，保持 `updatedAt`、顺序和 SSE 不变。后端补充 invalid/no-op
单测，Document domain/API/error/events/endpoints 文档同步。

固定版本又在真实拖拽中抓到右岛 Path 比树和面包屑落后一拍；修复后 Inspector 从最新 tree row 取结构元数据、正文 provider 继续冻结保光标，并补 Library widget
regression。五通道重跑进一步抓到 Inspector `Modified` 把编辑器首次载入的 live seed 时间当成持久修改时间；修复为 seed 只提供字数/大小，真实编辑才可乐观提供本地时间，
且后端较晚持久时间优先；补 `documentInspectorUpdatedAt` 守卫和文档说明。这个问题也已在最终真实画面中确认不再出现。

最终 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-122441` 使用新 binary 从既有 EP-139 树开始。Computer Use 真实操作：选中
`Source Section`，拖到 `EP139 Beta` 根级，再拖回 `Destination Section`；两次均同时看到侧栏层级、面包屑、正文、右岛 Path 一致，最终 Path 为
`/EP139 Beta/Destination Section/Source Section`，`Deep Context` 仍挂在其下，正文 `## Source`、tags 和 description 未变，Modified 与持久时间显示为
`12:26`。另以 REST 重跑显式 `position:0` 与省略 position 的 append no-op，`updatedAt`、path、position 和通知数均不变。

独立 REST/SQLite/SSE 矩阵覆盖根↔嵌套、显式 0、inclusive end position、同父重排、nil parent、nil position append、后代 path/content/tags 保留，以及负数/越界/
浮点/布尔/数组/字符串 position、自落、成环、missing parent/document、坏 JSON、缺/错 workspace、unknown action。最终 SQLite/REST 同真：
`doc_1942443aabe8b4eb.parent_id=doc_b16767da037811f4`、`position=0`、path 为最终深路径。

最终 session 的 backend D1 为 `:8894`/PID `38988`，ssetap PID `39015`，llmtap `:8829`/PID `38951`，Flutter runner PID `39023`，窗口 recorder PID `39524`；
`rig-check` 在操作前、操作中、收台前均五通道全绿，rig-down 后进程组和监听端口归零。录屏 `176.760000s / 2784x1808 / 60fps`；SSE 三流均连接，
notifications durable 只有真实两条 `document.moved` 且 seq `[1,2]` 单调；backend 250 行无应用 WARN/ERROR/panic/FATAL，frontend 18 行无 Flutter/Dart/overflow/
Unhandled 红线；llmtap 记录 readiness，确定性 move 不虚构 completion。封口证据为 session 内 `evidence/EP-139-document-move-final-green.md`，独立账本复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-139-document-move-ledger-reaudit.md`，稳定画面抽帧也保留在 session evidence。

正式账本由 `1385→1390 judgments`，五级法条为 `G1/F2/A5/C4/G2`，`COVERAGE EP-139=✓✓✓✓✓`；anchors `10/10`。写账后 `gap-too-fast` 与
`discovery-collapse` 均按原阈值真实打开，独立复审确认红证据、修复链、五通道原始 journal 和最终帧齐全后 ack，未修改阈值、算法、法典或锚点；最终
`alarms.py check`=`clean (1390 judgments on record)`，`gen_coverage.py --check`=`848 rows / 271 carried / 0 tombstones`。P12 旅程 400+ 扩写仍按用户裁定
推迟二期，一期以 COVERAGE 矩阵为覆盖真相。

定向 backend document/handler/store Go tests、Library + live-metrics Flutter `59` tests、`gofmt`、`make -C docs verify` 和 `git diff --check` 均通过。
批次二十七当前由 **5→10/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-140 `POST /api/v1/documents/{id}:duplicate`。

### 5.2 历史状态快照（EP-138，批次二十七 5/50）

**历史前线（2026-08-09，清册 EP-138 已完成，批次二十七当时 5/50；未到 50 格，不跑统一长门禁、不提交）。**
EP-138 `DELETE /api/v1/documents/{id}` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、backend journal、
三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是只得到一个 `204`，而是让用户能从 Library 找到删除入口、理解级联后果、
先取消不产生副作用，确认后整棵子树消失；另一个视图删除打开页或祖先时，当前编辑器不能继续伪装成可写，必须回到干净草稿并明确说出页面已删除。

固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-112205` 从真实 onboarding 起步。首轮构造树覆盖根、子、双孙、兄弟和 link
关系；真实 App 打开根页，More actions 显示 Rename/Duplicate/Delete，确认框显示 `Delete this page?` 及
`“EP138 Delete Root” and everything nested inside it will be removed.`；先点 Cancel，选中页、正文、树和 inspector 均保持不变，再确认 Delete，
页面从 rail 消失、右侧详情卸载、中心回到 `Untitled` 空白草稿。此路径没有产品源代码红，不把确认框或 204 单独冒充完整通过。

独立 REST/SQLite/SSE 矩阵确认 DELETE 的真实语义：根、子、双孙、兄弟全部 `GET=404 DOCUMENT_NOT_FOUND`，重复删除和未知 id 均 `404`；软删主行
保留 tombstone，子树共享删除时刻，live relation count 为 `0`；删除后用相同名字重新创建得到新的 `201`。跨 workspace 目标文档在其自身 workspace
读为 `200`，从当前 workspace 删除为 `404`，没有跨隔离删写。打开子页后外部删除祖先，经过权威 tree resync 触发 `This page was deleted`，14 个 120ms
采样从第 2 帧开始观察到提示，随后回到空白草稿；这不是静默跳转。

正式绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-112205/evidence/EP-138-document-delete-final-green.md`，
AXTree 独立复核为同 session 的 `evidence/frontend-ax-review.md`，统计警报独立复核为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-138-document-delete-ledger-reaudit.md`，清理回执为同 session 的
`evidence/EP-138-fixture-cleanup.md`。原始 fixture 构造时有两次 shell JSON 传参错误，均只产生 `422`、无幽灵写入，按台架问题分类，没有伪造产品红。

五通道收台：backend D1 归属到 `:8892`（PID `28732`），无应用 WARN/ERROR/panic/fatal/exception；ssetap 独立连接
messages/entities/notifications，三流均有连接记录，notifications durable seq `1..18` 单调且包含 created/deleted 与
`relation.dependency_broken`；channel 5 真实 upstream 为 `https://api.anselm.website`，challenge/install/models 全 HTTP `200`，本确定性 DELETE
不虚构 completion；Flutter console 无 Dart/Flutter/RenderFlex/overflow/unhandled/concurrent-modification/lost-device 红线。日志中的固定格式
macOS Flutter AXTree stale-node 行只在 `frontend-ax-review.md` 中按既有 tooling 规则复核，最后静置 3 秒不再增长；未知 AX 形状仍 fail-closed。
窗口录屏已封口为 H.264 `1025.690000s`，进程组归零。

正式账本由 `1380→1385 judgments`，五级法条为 `G1/F2/A5/C4/G2`，`COVERAGE EP-138=✓✓✓✓✓`；anchors `10/10`，两条统计警报按原阈值触发后
独立复审并 ack，最终 `alarms.py check` 为 `clean (1385 judgments on record)`；阈值、算法、法典和锚点均未改。`gen_coverage.py --check` 为
`848 rows / 270 carried / 0 tombstones`。`check_journeys.py` 仍按 P12 裁定报告一期路线未认领清册行；400+ 路线扩写是二期工作，一期主循环以
COVERAGE 矩阵为覆盖真相，不以此阻塞。

EP-138 无产品源代码修复，仅执行 backend/frontend/database/REST/SSE/Computer Use 五级验收。正式批次二十七从 **0→5/50**，未到 50 格不跑统一长门禁、
不提交；下一原子前线为 EP-139 `POST /api/v1/documents/{id}:move`。

### 历史状态快照（EP-125，批次二十五 40/50）

EP-125 `GET /api/v1/mcp-servers/{name}/stderr` 已完成真实 stdio MCP bounded-tail 验收：300 条长噪声不撑爆详情页，终帧显示
`show 4269 earlier lines` 与最新 marker，REST `data.size=262144` 命中 256 KiB 上限，unknown server 为 `404`。固定绿 session
为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-061239`，录屏 `375.708333s / 2784x1808 / 60fps`，正式账本
`1315→1320`，证据与清理回执均保留；当前前线以 EP-126 整体重述为准。

### 历史状态快照（EP-119，批次二十五 10/50）

**当前前线（2026-08-09，清册 EP-119 已完成，批次二十五 10/50）。**
EP-119 `DELETE /api/v1/skills/{name}/files/{path...}` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、
窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是只得到一个
`204`，而是用户在 Library 删除附属文件后，确认语义、文件树、当前预览、后端真相和 SSE 事件全部收口；嵌套路径可删，
`SKILL.md` 清单受保护，重复删除和跨客户端竞态必须给出可理解的下一步。

首轮真实 App 竞态路径冻结为红：REST 先删除 `references/keep.md` 后，App 仍显示旧预览和幽灵文件行；用户再点击删除收到
`404 SKILL_FILE_NOT_FOUND`，旧 UI 只显示泛化的 `Action failed`，没有刷新也没有离开失效预览。stop-and-fix 在
`_SkillFilesGroup._deleteFile` 为所有 API 失败刷新文件树；对 `SKILL_FILE_NOT_FOUND` 回到 skill 概览并显示“文件已被删除、
列表已刷新”，其他失败显示带路径的重试文案。新增错误常量、中英文文案和 stale-delete widget 回归后，用最终 binary
重跑正负路径。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-043659` 完成真实 onboarding、受管免费档
provision、附属文件和嵌套文件删除、取消确认、`SKILL.md` manifest 保护、重复删除及外部先删竞态。最终真实列表只有
`SKILL.md`（164 bytes）和 `scripts/run.py`（39 bytes）；终帧 `evidence/EP-119-final.png` 显示 skill 概览、`2 files`、
无幽灵行，完整审计证据为该 session 下的 `evidence/EP-119-skill-file-delete-final-green.md`。

五通道收台：录屏 `364.575000s`；backend D1 归属到 `:8864`，创建 `201`、两次 App 删除 `204`、manifest 保护 `400`、
竞态/重复删除 `404`、最终列表 `200`，无应用 panic/FATAL/ERROR/WARN；SSE 三流均连接，notifications durable seq `1..8`
单调并覆盖 create、seed、两个 App delete 和竞态 delete；frontend 无 Dart/FlutterError/RenderFlex/overflow/Unhandled/
lost-device 红线，AX 观察确认框、失效提示和最终文件树一致。managed gateway challenge/install/models 全 `200`，本格是
确定性文件路径，不伪造模型 completion。

正式账本由 `1285→1290 judgments`，五级法条为 `G1/F2/A1/C4/G2`，anchors `10/10`，`COVERAGE EP-119=✓✓✓✓✓`；独立
账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-119-skill-file-delete-ledger-reaudit.md`。集中写账打开的
`gap-too-fast` 与 `discovery-collapse` 已按原阈值独立复审并 ack，最终 `alarms.py check`=`clean (1290 judgments on record)`，
未改阈值、算法、法典或锚点。临时数据目录按用户授权以 `trash` 清理，记录在
`sessions/20260809-043659/evidence/EP-119-fixture-cleanup.md`；正式 session、录屏、journals 和账本保留。

批次二十五由 **0→10/50**。本批未满 50 格，不跑统一长门禁、不提交；下一原子前线为 EP-120
`GET /api/v1/mcp-servers`。

### 历史状态快照（EP-116，批次二十四 45/50）

EP-116 `GET /api/v1/skills/{name}/files` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道验收。真实
Library 显示 `Files 3`、`SKILL.md`、`references/live.md`、`references/seed.md`，公开响应不泄漏 provenance sidecar；未知
skill 为 `404`，缺 workspace 为 `401`，删除专用 skill 后 `204→404` 且 App 诚实回到 `Untitled`。固定绿 session 为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-022720`，正式账本 `1270→1275 judgments`，`COVERAGE EP-116`
`✓✓✓✓✓`，独立复审后 alarms clean。批次当时 **45/50**；当前前线以 EP-117 整体重述为准。

### 历史状态快照（EP-115，批次二十四 40/50）

**历史前线（2026-08-09，清册 EP-115 已完成，批次二十四 40/50）。**
EP-115 `POST /api/v1/skills:install` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、窗口录屏、
backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是返回一个 `200`，而是
用户从 source 预览后只安装新的合法 skill，Library、正文、文件树、provenance、信任门与后端实际写入保持同一真相；
已有 skill 的 no-force 重放不覆盖，force 才能完整替换。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-021859` 中，真实 App 从预览选择
`ep115-new`，已有 `ep115-existing` 显示 installed 且不可选，`broken-one` 显示解析失败且不可选；安装后 rail 出现
新 skill，中心显示正文、2 个文件、allowed-tools、provenance 和 `Pre-approval pending`。REST 进一步证明 no-force
existing 为明确 `skipped`、force 返回 `installed` 并把 existing 切到 v2 正文和 replacement 文件；坏候选和新 skill 重放
均只 skip。删除专用实体后 REST `204→404`，App 收到 durable delete 并清掉当前选中详情，回到 `Untitled`。

五通道收台：录屏 `246.440000s / 2784x1808 / 60fps`；backend 无 panic/fatal/error，三条 expected skip WARN 已逐项解释；
SSE durable seq `16..20` 单调，只有 setup create、App create、force update 和 cleanup deletes；frontend 无 Dart/Flutter/
RenderFlex/Unhandled/overflow 红线；managed gateway challenge/install/models 全 `200`。正式账本由 `1265→1270 judgments`，
五级法条为 `G1/F2/A5/C4/G2`，anchors `10/10`，`COVERAGE EP-115=✓✓✓✓✓`，`gen_coverage.py --check`=`848 rows / 247 carried / 0 tombstones`。
集中写账警报已按独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-115-skill-install-ledger-reaudit.md`
ack，最终 `alarms.py check`=`clean (1270 judgments on record)`；未改阈值、算法、法典或锚点。

source fixture/runtime 已按用户授权删除；formal session、录屏、backend/frontend/SSE/LLM journals、截图、REST 回执和证据
均保留。该格使批次二十四达到 **40/50**；当前前线以 EP-116 整体重述为准。

### 历史状态快照（EP-114，批次二十四 35/50）

**历史前线（2026-08-09，清册 EP-114 已完成，批次二十四 35/50）。**
EP-114 `POST /api/v1/skills:inspect-source` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、
窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是返回一个
`200`，而是用户在安装前能看见所有候选、失败原因、已有 skill、allowed-tools 与实际选择状态；已有 skill 不能被画成
可执行的重复安装，inspect 也不能悄悄写入工作区。

首轮真实 EP-114 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-015806` 冻结为红：已有
`commit-helper` 在 UI 中带 `installed` 标记却被默认选中，后端 no-force install 实际只会返回 `skipped`，用户选择与
实际动作不一致。stop-and-fix 将默认选择收窄为 `installable && !alreadyExists`，已有项仍可见但开关禁用，并增加
“已在库中”明确文案与 widget 回归测试。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-020745` 使用真实 source fixture 重跑：
`bad name`、`broken-front` 的失败原因可读且不可选；`commit-helper` 显示 installed、关闭且不可选；新的
`valid-preview` 默认选中，`Read/Grep/run_function` 在安装动作前可见。取消新候选后 `Install selected` 变为禁用，
再选回恢复可用；点击 Cancel 后 skill 列表仍只有两个 seeded skill，未产生写入或生命周期帧。正式证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-114-skill-inspect-final-green.md`，首轮红证据保留。

五通道收台：录屏 `182.816667s / 2784x1808`；backend inspect 为 `200` 且无应用红线；SSE 三流均连接，本只读路径
无伪造业务帧；frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow 红线，仅已审计的 macOS foreground 启动噪声；LLM
bootstrap challenge/install/models 全 `200`。正式账本由 `1260→1265 judgments`，五级法条为 `G1/F2/A5/C4/G2`，anchors
`10/10`，`COVERAGE EP-114=✓✓✓✓✓`，`gen_coverage.py --check`=`848 rows / 246 carried / 0 tombstones`。
集中写账打开的 `gap-too-fast`/`discovery-collapse` 已按独立复审
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-114-skill-inspect-ledger-reaudit.md` ack，最终
`alarms.py check`=`clean (1265 judgments on record)`；未改阈值、算法、法典或锚点。

source fixture/runtime 已按用户授权删除；formal session、录屏、backend/frontend/SSE/LLM journals、截图、红绿证据和
账本均保留。批次二十四当前 **35/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-115
`POST /api/v1/skills:install`。

### 历史状态快照（EP-113，批次二十四 30/50）

**当前前线（2026-08-09，清册 EP-113 已完成，批次二十四 30/50）。**
EP-113 `POST /api/v1/skills/{name}:approve-tools` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、
窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是返回一个
`200`，而是第三方 Skill 的 allowed-tools 信任门必须由用户明确打开，首次授权只产生一次真实生命周期更新；重复点击、
网络重试或直接重放公开 API 都必须幂等，不伪造第二次 `skill.updated`，同时来源、文件树、正文、provenance 和 App
投影保持同一真相。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-013940` 冻结为红：App 首次授权后
正确产生 `seq=17 skill.updated`，但重复调用同一公开 API 虽然 REST 状态没有变化，SSE 又产生了 `seq=18 skill.updated`。
这是数据/产品生命周期假信号，停止推进。修复 `backend/internal/app/skill/install.go`：`toolsApproved` 已为 `true` 时
只读当前实体，不写 provenance、不刷新 `updatedAt`、不发通知；新增 `TestApproveTools_IsIdempotentAfterApproval`，并
保留安装/更新单事件回归和后端 Skill 文档契约。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-014829` 重新从真实 source fixture 安装
`trust-gate`，App 待授权帧显示 3 files、文件树、`Read`/`Grep` 和 `Pre-approval pending`；点击后变为
`Pre-approval active`、`Provenance 0`，重复静态帧稳定。首次 App 授权只产生 `seq=17 skill.updated`；随后直接重放
公开 API 返回 `200`，`updatedAt` 和 `toolsApproved` 前后完全一致，SSE 没有第二个更新事件。未知 Skill 和用户本地
Skill 均按 `422 SKILL_NOT_INSTALLED` 失败，不能越过信任门。最终录屏 `189.115000s / 2784x1808`，正式绿证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-113-skill-approve-final-green.md`，红证据和独立账本复审均保留。

定向验证：`mise exec -- go test ./internal/app/skill`、`mise exec -- go test -race ./internal/app/skill`、
`git diff --check` 全部通过；anchors `10/10`，正式账本由 `1255→1260 judgments`，五级法条为 `G1/F2/A5/C4/G2`，
`gen_coverage.py --check`=`848 rows / 245 carried / 0 tombstones`，EP-113=`✓✓✓✓✓`。两条集中写账警报的独立
复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-113-skill-approve-ledger-reaudit.md`，已按原阈值
ack，最终 `alarms.py check`=`clean (1260 judgments on record)`，未改阈值、算法、法典或锚点。

本轮 source fixture/runtime 已按用户授权删除；formal session、录屏、backend/frontend/SSE/LLM journals、红绿证据和
账本均保留。批次二十四当前 **30/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-114
`POST /api/v1/skills:inspect-source`。

### 5.2 历史状态快照（EP-112，批次二十四 25/50）

**历史前线（2026-08-09，清册 EP-112 已完成，批次二十四 25/50）。**
EP-112 `POST /api/v1/skills/{name}:update` 已完成真实 Flutter App、真实受管 Anselm gateway、Computer Use、
窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。产品目的不是收到
一个 `200`，而是上游 skill 更新后，中心正文、文件树、描述、provenance、allowed-tools 信任状态、通知和失败保护
必须是同一代真相；本地改动非 force 时要阻断并明确说明，force 更新也不能静默丢掉未改变的信任配置。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-011139` 冻结为红：后端 metadata、
文件树和 provenance 已到 v2，但中心 native editor 仍显示 v1 正文和已删除的 guide，且通知重复发出
`skill.created` + `skill.updated`。这是真实数据代际矛盾，不计绿。stop-and-fix 重置实际正文变化时的内部
native editor generation，同时保留页面滚动/大纲壳并阻断旧实例延迟保存反写；安装/更新落地改为一次操作只发
一个正确的 lifecycle event，并补 Go/Flutter 回归和 frontend library 文档。

固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-012412` 重新从 v1 走到 v2：App 的
中心正文、描述与右侧文件树一起切到 v2，3 文件收敛为 2 文件，`Read` pre-approval 保持；本地编辑
`scripts/check.py` 后非 force 路径返回 `SKILL_LOCALLY_MODIFIED` 并指出文件，App 显示明确的 Force update 闸，
确认后恢复 v2 且不重置 `Read`。录屏 `405.186667s / 2784x1808`，证据含 v1/v2、漂移确认框和 force 后终帧。
五通道分别证明 UI 代际一致、update/读取 HTTP 200、SSE 只有对应 `skill.updated`、Flutter console 无运行时红线、
真实 managed gateway bootstrap 全 200；正式绿证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-final-green.md`，首轮红证据仍保留。

定向验证：`mise exec -- go test ./internal/app/skill`、`mise exec -- go test -race ./internal/app/skill`、
`cd frontend && mise exec -- flutter test test/features/library/library_test.dart`、`make -C docs verify`、
`git diff --check` 全部通过；统一长门禁和提交按批次协议刻意未执行。正式账本由 `1250→1255 judgments`，五级法条
为 `G1/F2/A5/C4/G2`；anchors `10/10`，`alarms.py check`=`clean (1255 judgments on record)`，
`gen_coverage.py --check`=`848 rows / 244 carried / 0 tombstones`，EP-112=`✓✓✓✓✓`。两条集中写账警报的独立
复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-ledger-reaudit.md`，未改阈值、
算法、法典或锚点。

本轮本地 source fixture 和运行时数据已按用户授权删除；formal session、录像、backend/frontend/SSE/LLM journals、
红绿证据和账本均保留。当时批次二十四为 **25/50**，未到 50 格不跑统一长门禁、不提交；随后前线进入
EP-113 `POST /api/v1/skills/{name}:approve-tools`。

### 5.2 历史状态快照（EP-111，批次二十四 20/50）

**当前前线（2026-08-09，清册 EP-111 已完成，批次二十四 20/50）。**
EP-111 `POST /api/v1/skills/{name}:activate` 已完成真实 Flutter App、真实受管 Anselm gateway、
Computer Use、窗口录屏、backend journal、三路独立 SSE witness、frontend console 和 LLM wire 的五级验收。
用户目的不是收到一个工具卡，而是激活 skill 后，精确参数能到达正确的 skill/fork 边界，歧义不扩搜，
读取范围不越界，父回合不会在隔离 fork 返回后继续执行工具，最终结果仍能被用户理解并继续操作。

最终主 session `/private/tmp/anselm-rig-ep111-skill-activate-20260808/sessions/20260809-005230` 使用正确
的持久化 tap wiring (`8877`)；`rig-check` 五通道全绿。Computer Use 输入
`["the ep111-fork skill file"]` 后，实时画面显示一张 `Activated skill ep111-fork` 卡和一份明确的中文
歧义说明：没有绝对路径、没有挂载工作目录，不能定位目标，且没有扩大搜索范围；loading、终态和静态保持期间
没有可见布局、文字或输入跳变。录屏 `156.808333s / 2784x1808 / 60fps`，三流连接到同一 workspace，
messages durable seq `1..41` 单调，managed proof/chat HTTP 成功，frontend 无 Flutter/Dart 应用红线。

实现层已将 fork Explore 约束从提示语提升为确定性边界：无 workdir 时只允许 Skill 参数给出的精确绝对
`Read`，有 workdir 时所有 `Read/LS/Glob/Grep` 都必须在挂载根内；越界返回真实 tool error，不再以成功文本
诱导模型重试。fork 成功后以 run-local `TurnControl` 移除父回合全部工具 schema，跳过 AutoActivator；若模型
仍发 tool call，loop 不查找、不执行，写入 `toolsDisabled` tool result 并以 `TURN_TOOLS_DISABLED` 终止。
未知 fork agent 在 create/replace 阶段早拒 `422 SKILL_FORK_AGENT_TYPE_INVALID`，旧坏清单仍在 active-skill
预授权前 fail-closed；失败 fork 不污染 active skill。精确绝对路径的正向 session
`/private/tmp/anselm-rig-ep111-skill-activate-20260808/sessions/20260809-003714` 证明一次 `Read` 后直接
进入父回合文本收尾；对抗 session `004327` 证明空工具集下的晚发 `get_skill` 被硬拦。

旧 prompt-only 红证据与旧 tap 接线失败均保留在盘上；它们分别证明“只靠提示不够”和“台架自检必须阻断错误
数据”。`004327` 的 ReplayKit 动态录屏曾出现短暂重影，但实时 Computer Use 画面和新正确接线的
`005230` 录屏未复现，已诚实登记为观测器待加完整性 guard，不用它冒充产品绿证据。正式账本由 `1245→1250`
条裁决，五级法条为 `G1/F2/A5/C4/G2`；anchors `10/10`，formal alarms clean，COVERAGE 为
`848 rows / 247 carried / 0 tombstones`。按批次协议，批次二十四仍 **20/50**，未到 50 格不跑统一长门禁、
不提交；下一原子前线为 COVERAGE 的下一行。
EP-111 临时 fixture 已按用户授权清理：`ep111-inline` 与 `ep111-fork` 均
`DELETE=204→GET=404`，列表只剩 seeded skills，filesystem 目录和 relations 均为零；清理证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-111-fixture-cleanup.md`。本轮还修复了 formal
`anchor-check.json` 指向已删除答卷的问题：恢复冻结答案表并重新校准 10/10，未改锚点集、法条或阈值。

### 5.2 历史状态快照（EP-110，批次二十四 15/50）

**当前前线（2026-08-08，清册 EP-110 已完成，批次二十四 15/50）。**
EP-110 `DELETE /api/v1/skills/{name}` 已按“用户删除 skill 后，整棵文件树、绑定关系、Library 选中态、REST、SSE 和 workspace 隔离必须同时收口，结果必须可理解且可继续排错”的产品目的完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。

真实路径构造 `ep110-delete-tree`：`SKILL.md` 加 `references/notes.md`、`scripts/check.py` 共 3 个文件，并绑定 seeded `greet` function。Library 中真实打开后，中心显示正文，右岛显示 `3 files · 1 bindings`、文件树、`Bindings greet` 和完整 Properties；从行尾 actions 打开删除确认，看到 `Delete this skill?` 与明确的不可逆对象说明，按用户授权确认后，rail 移除 fixture，中心回到空的 `Untitled`，没有残留详情或属性。

删除后的数据真相逐层核对：skill GET 与 files GET 均为 `404 SKILL_NOT_FOUND`，列表只剩 `commit-helper` 与 `deploy-helper`，文件系统整目录消失，`skill → function` 的 `equip` relation 为空。负向矩阵覆盖缺 workspace=`401 UNAUTH_NO_WORKSPACE`、非法名=`400 SKILL_INVALID_NAME`、未知/重复目标=`404 SKILL_NOT_FOUND` 和跨 workspace=`404 SKILL_NOT_FOUND`；不是只验证一次 `204`。

最终 session `/private/tmp/anselm-rig-ep110-skill-delete-20260808/sessions/20260808-231300` 录屏 `217.530000s` 可读；三路 SSE 均连接，notifications durable seq `16..19` 单调并包含 `skill.created`、两次捆绑文件更新和 `skill.deleted`；backend/frontend 无应用红线。主 workspace 的真实 Anselm gateway challenge/install/models 均经 `llmtap :8876` 返回 `200`。隔离 workspace 创建后立即删除导致的 install cancellation 被记录为预期生命周期取消，不计为网关成功或失败。完整证据为 `/private/tmp/anselm-rig-ep110-skill-delete-20260808/sessions/20260808-231300/evidence/EP-110-final-green.md`，正式副本和独立告警复审分别为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-110-skill-delete-final-green.md` 与 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-110-approval-ledger-reaudit.md`。

本格无新的产品源代码变更；EP-109 的 free-tier workspace-delete race 修复仍由 Go targeted/race tests 覆盖。定向验证：`mise exec -- go test ./internal/app/skill ./internal/app/relation ./internal/transport/httpapi/handlers`、`mise exec -- go test -race ./internal/app/freetier`、`flutter test test/features/library/deleted_page_eviction_test.dart test/features/library/library_test.dart test/features/library/skill_tree_preview_test.dart`（57 tests）全部通过；`gofmt`、`git diff --check` 通过。正式 `judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1240→1245 judgments` 写入五格，EP-110=`✓✓✓✓✓`；anchors `10/10`，正式 `gap-too-fast`/`discovery-collapse` 经独立证据复审后 ack，`alarms.py check`=`clean (1245 judgments on record)`，未改阈值、算法、法典或锚点；`gen_coverage.py --check`=`848 rows / 242 carried / 0 tombstones`。一次无 `RIG_HOME` 前缀的默认账本误路由已明确排除，正式账本只认显式 formal 根。

批次二十四当前 **15/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-111 `POST /api/v1/skills/{name}:activate`。

### 5.2 历史状态快照（EP-107，批次二十三 50/50）

**当前前线（2026-08-08，清册 EP-107 已完成，批次二十三 50/50）。**
EP-107 `POST /api/v1/skills` 已按“用户用自然语言在真实 Chat 中创建一个可用 skill；HTTP、工具 schema、持久化、SSE、Library 和删除后的 UI 真相必须一致；每个可见结果都要可理解、可继续使用”的产品目的完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。

本格严格执行 stop-and-fix。首轮真实 Chat 发现 `create_skill` schema 遗漏 `userInvocable`：用户明确要求 `true`，工具无法发出该字段，REST frontmatter 也确认缺失。修复 `backend/internal/app/tool/skill/crud.go` 的严格 bool 解码、映射和 schema/description，补 `crud_test.go` 并同步 skill domain 文档。修复后的真实 Chat 回归在 session `/private/tmp/anselm-rig-ep107-skill-create-rerun-20260808/sessions/20260808-215429` 创建 `ep107-chat-notes-v2`，REST/LLM wire/UI 均确认 `userInvocable:true`、`disableModelInvocation:true`、`allowedTools:["Read"]`，Library Properties 显示 `Model can invoke Off` 与 `User-invocable On`。

回归继续发现第二个真实产品红：从 REST/agent 路径删除当前选中的 skill 后，Library rail 已消失，但中心详情仍展示已删除正文和属性。修复 `frontend/lib/features/library/ui/library_ocean.dart` 的“曾见过且已消失”选中态驱逐逻辑，补中英文文案、生成字符串和 `deleted_page_eviction_test.dart`。最终真实 session `/private/tmp/anselm-rig-ep107-skill-create-rerun2-20260808/sessions/20260808-215933` 创建并选中 `ep107-delete-live2` 后执行 DELETE `204`；约 350ms 后真实 App rail 移除、中心回到 `Untitled`、显示 `This skill was deleted`，不存在残留正文/Properties。随后 GET 为 `404 SKILL_NOT_FOUND`，workspace 中 `ep107-*` 计数为 `0`，notifications durable seq `19` 为 `skill.deleted`。

五通道封口：最终 `rig-check.sh` 五通道全绿，`rig-down.sh` 正常收台并以 ffprobe 封片 `259.116667s`；backend/frontend/llmtap/ssetap 无 panic、FATAL、未解释 WARN/ERROR、Flutter/Dart/RenderFlex/Unhandled 红线；三路 SSE 均连接，删除 durable signal 可见；LLM tap 真实指向 `https://api.anselm.website`，Chat 回归完成真实 challenge/install/models 和 chat completions。最终证据为 session `evidence/EP-107-skill-create-final-green.md`，红证据为 formal `EP-107-user-invocable-red.md`，删除残留红绿因果链也保留在同一最终证据。

本地验证：`mise exec -- go test ./internal/app/tool/skill -count=1` 通过；`mise exec -- flutter test test/features/library/deleted_page_eviction_test.dart test/features/library/library_test.dart` 通过（51 tests）；`gen_coverage.py --check` 为 `848 rows / 239 carried / 0 tombstones`；anchors `10/10`。正式账本使用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`，按 `G1/F2/A5/C4/G2` 从 `1225→1230 judgments` 写入五级裁决，EP-107=`✓✓✓✓✓`；独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-107-skill-create-ledger-reaudit.md`。集中写账打开的 `gap-too-fast`/`discovery-collapse` 已由独立红绿证据、五通道、anchors 复核后 ack，未改阈值、算法、法典或锚点，最终 `alarms.py check`=`clean (1230 judgments on record)`。

批次二十三已达到 **50/50**。下一动作不是启动 EP-108，而是按协议执行一次统一长门禁：封存本批、完整 `make verify`、完整 `go test ./...`、已修场景回归、工作树审计和提交；只有长门禁全绿并提交后，下一 loop 才把 EP-108 `GET /api/v1/skills/{name}` 设为前线。

### 5.2 历史状态快照（EP-102，批次二十三 25/50）

**历史前线（2026-08-08，清册 EP-102 已完成，批次二十三 25/50）。**
EP-102 `POST /api/v1/approvals/{id}:revert` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。首轮点击版本动作暴露真实 Flutter `Concurrent modification during iteration`；stop-and-fix 将 selection region focus handoff 延后一个 frame 并加脱离守卫，补 6/6 回归测试。固定 session `/private/tmp/anselm-rig-ep102-approval-revert-fixed-20260808/sessions/20260808-202631` 重跑 v2→v1、外部 REST resync 和 UI 再回退，Overview/Versions/Activity/REST/SQLite/SSE 一致，未知 `999→404`、字符串版本 `"1"→400`。录屏 `304.298333s`，五通道无应用红线，cleanup `204→404` 且列表为空；正式账本 `1200→1205`，anchors `10/10`，独立复审和 alarms clean，清册 `848/234/0`。完整红绿证据与修复记录保留在上述 session；本状态只作历史追溯，当前前线以 EP-103 为准。

**历史前线（2026-08-08，清册 EP-101 已完成，批次二十三 20/50）。**
EP-101 `POST /api/v1/approvals/{id}:edit` 已按“完整替换而非部分 patch”的产品目的完成真实 App、真实受管
Anselm gateway、Computer Use 和五通道验收。用户目标是从 Approval 的 `Edit with AI` 入口新增
`refundReason:string`、精确替换模板，同时保留未改变的 `allowReason=true`、`timeout=4h` 和
`timeoutBehavior=reject`；最终必须一次完整工具调用成功，不能让用户看到校验失败后再 retry。

首轮真实 session `/private/tmp/anselm-rig-ep101-approval-edit-20260808/sessions/20260808-193907`
冻结为产品红：模型遗漏未改变的 `allowReason`，后端正确拒绝不完整 snapshot，App 出现红色工具结果、
`No approval preview · previous version remains active` 和 retry 后成功的混合旅程。红证据永久保留，
不计绿。stop-and-fix 没有放宽后端契约，而是强化 `edit_approval` 的 description/schema：模型必须先读
当前 Approval，再复制所有 required fields，包括未改变的布尔值；补齐工具契约测试并同步
`docs/references/backend/domains/approval.md`。

固定真实 session `/private/tmp/anselm-rig-ep101-approval-edit-fixed-20260808/sessions/20260808-195118`
在同一台架上重跑：最终一次 `edit_approval` 产生 v3，输入为 `customer:string`、`amount:number`、
`refundReason:string`，模板精确为
`Please review {{ input.customer }}'s refund request for {{ input.amount }}. Reason: {{ input.refundReason }}. Approve?`
，并保留 `allowReason=true`、`4h`、`reject`。终帧显示完整用户请求、单张成功工具卡、齐全字段表、
一致的助手总结和 `EP101 Refund Review Edited ×2` 活动计数；没有红卡、裁切、loading 残留、视口跳变
或重复 mutation。Computer Use 的中文 `type_text` 会丢失部分中文字符，故最终精确意图用 ASCII 等价
请求在正常 composer 中重走；中文输入层的限制没有被伪装成产品通过。

五通道封口：录屏已由 `rig-down.sh` 封片为 `213M / 797.218333s`；backend journal 无
`WARN|ERROR|panic|fatal`，frontend journal 无 `error|exception|assert|stack trace|unhandled`；
独立 ssetap 记录最终 messages durable close `seq=56/59/63/64`、notifications `seq=20 approval.edited`
且无错误帧；REST active v3、SSE close 快照、LLM wire 完整参数和 UI 字段逐项一致。最终证据为
`/private/tmp/anselm-rig-ep101-approval-edit-fixed-20260808/sessions/20260808-195118/evidence/EP-101-approval-edit-final-green.md`，
红证据与清理证据同目录/首轮 session 保留。用户已授权的临时 Approval 清理完成：DELETE `204`，随后
GET `404 APPROVAL_NOT_FOUND`，列表为空，SSE 只记录一条 `approval.deleted`。

正式账本已用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 按 `G1/F2/A5/C4/G2` 从
`1195→1200 judgments` 写入五级裁决；锚点 `10/10`，正式独立复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-101-approval-edit-ledger-reaudit.md`，
`alarms.py check`=`clean (1200 judgments on record)`，`gen_coverage.py --check`=`848 rows / 233 carried / 0 tombstones`。
曾有一份未带正式 `RIG_HOME` 的默认账本副本，按错路由审计保留，工作记录与 COVERAGE 只认 formal ledger。
本格代码修复的定向 Go tests、gofmt 和 `git diff --check` 已通过；批次二十三当前 **20/50**，未到
50 格不跑统一长门禁、不提交。下一原子前线为 EP-102 `POST /api/v1/approvals/{id}:revert`。

### 5.2 历史状态快照（EP-100，批次二十三 15/50）

**当前前线（2026-08-08，清册 EP-100 已完成，批次二十三 15/50）。**
EP-100 `DELETE /api/v1/approvals/{id}` 已按完整产品目的完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。用户目的不是“收到一个 204”，而是从活动目录移除 Approval、清理关系边、保留不可变版本审计，并让受影响 workflow 保持可见、可定位、可修复，且 workspace 隔离和重复删除边界诚实。

固定真实 session `/private/tmp/anselm-rig-ep100-approval-delete-20260808/sessions/20260808-192034` 使用主 workspace
`ws_63cd621a13771254`，Approval `apf_28ec4b33b61dd4ed` 已有 v1/v2/v3，workflow `wf_e221c04926eff830` 通过一条 approval 节点引用它。真实 App 打开 Approval 详情、More actions、删除确认框并在用户已授权删除验收夹具后确认；Approval 从 rail/Parts 消失，选中详情回到 Overview，关系图删除 Approval 边但保留 workflow/trigger，Notifications 明确显示删除和 `1 reference dangling`，workflow graph/editor 保留原始 dangling ref 而不静默重绑。

REST 矩阵覆盖主删除 `204`、删除后单读 `404 APPROVAL_NOT_FOUND`、列表消失、三条 immutable versions 与 v1 历史仍可读、workflow 图仍在、capability check 的明确 missing-ref 问题、关系图清边、重复/未知删除 `404`、缺 workspace `401`、cross-owner `404` 和删除后同名新建 `201`。SQLite 证明软删主行带 `deleted_at`、三条版本保留且没有指向已删 Approval 的关系行；`resolved=true` 的含义按契约是 resolver 已接线并完成尝试，runnable 仍由 `problems` 判定。

Computer Use 逐帧检查确认删除确认文案、rail/Parts 收敛、通知详情、workflow Overview 和 graph inspector 没有裁切、重叠、loading 残留、错误重绑或输入/视口跳变。没有发现需要 stop-and-fix 的产品或代码红；删除确认的“从 active catalog 移除且不可恢复”与 soft-delete/version-history 契约一致。

五通道对证：录屏封片 `494.890000s`；backend journal 652 行无应用 WARN/ERROR/panic/FATAL；frontend journal 18 行只有已知 launcher `Failed to foreground app; open returned 1`，无 Dart/Flutter/RenderFlex/Unhandled/runtime error；独立 ssetap 的 messages/entities/notifications 三流均连接，主 notifications durable seq `16..24` 单调并包含 `approval.deleted` 与聚合 `relation.dependency_broken`；LLM tap 真实接线到 `https://api.anselm.website`，challenge/install/models 全部 HTTP 200。rig-check 操作前后全绿，rig-down 正常收台。

用户已授权并完成独立 fixture cleanup：cleanup session `/private/tmp/anselm-rig-ep100-cleanup-20260808/sessions/20260808-192941` 删除依赖 workflow、trigger 和 auxiliary workspace，DELETE 全部 `204`、精确 GET 全部 `404`；主 workspace、seeded graph 和 EP-100 证据/journal/录像保留。清理证据为 `EP-100-fixture-cleanup.md`，最终绿证据为 `EP-100-approval-delete-final-green.md`。

独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-100-approval-delete-ledger-reaudit.md`。
`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1190→1195 judgments`，`COVERAGE EP-100=✓✓✓✓✓`，anchors=10/10；集中写账打开的 `gap-too-fast`/`discovery-collapse` 已由红绿证据、真实录屏、五通道、REST/SQLite 负向矩阵和 cleanup 独立复审后 ack，没有修改阈值、算法、法典或锚点。正式 `alarms.py check`=`clean (1195)`，`gen_coverage.py --check`=`848 rows / 232 carried / 0 tombstones`。

本格无产品源代码变更；已完成 anchors check、alarms check、coverage check 和 `git diff --check`。pytest 不在当前 Python 环境中安装，未把缺失工具伪报为通过；相关既有 Go 回归此前已通过。批次二十三当前 **15/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-101 `POST /api/v1/approvals/{id}:edit`。

### 5.2 历史状态快照（EP-098，批次二十三 5/50）

EP-098 `GET /api/v1/approvals/{id}` 首轮发现悬空 `active_version_id` 会被旧二进制伪装成缺少 `activeVersion`；stop-and-fix 已将 Approval/Control/Function/Handler/Agent/Workflow 六个同类单读服务统一为 fail-closed。真实固定 session `/private/tmp/anselm-rig-ep098-approval-get-fixed-20260808/sessions/20260808-185307` 完成正常、空/悬空 pointer、未知 ID、缺 workspace、cross-workspace 和 UI Overview/Versions 验收，录屏 `292.263333s`，backend/frontend/SSE/LLM 五通道无未解释红线。正式账本 `1180→1185`、anchors `10/10`、清册 `848/230/0`；cleanup 已按授权完成。代码、测试和契约证据随本批次继续保留。

### 5.2 历史状态快照（EP-097，批次二十二 50/50）

EP-097 的完整五通道收口、统一长门禁和提交记录保留如下；当前恢复不得把批次计数回退到二十二。

### 5.2 历史状态快照（EP-096，批次二十二 45/50）

**当前前线（2026-08-08，清册 EP-096 已完成，批次二十二 45/50）。**
EP-096 `POST /api/v1/approvals` 已按完整产品目的完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。
用户目的不是“API 返回 201”，而是用户用自然语言描述一个带输入类型、理由、超时和超时处置的审批表单后，产品必须一次创建正确，
并在对话、Activity 和审批预览中给出一致、可理解、可继续使用的结果。

首轮真实 App 冻结出产品红：受管模型把 `2h` 编码成精确整数秒字符串 `"7200"`。旧工具边界先返回
`invalid timeout duration or missing/invalid timeoutBehavior`，随后模型重试并成功创建；因此同一屏同时出现失败工具行、
`Draft unsaved · nothing was created` 和成功创建卡片。这不是可接受的“模型自我修正”，因为用户无法判断是否有重复或半成品。
红证据永久保留于
`/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-175421/evidence/EP-096-approval-create-red.md`。

前线冻结后 stop-and-fix：在 approval tool 解码边界增加精确整数秒字符串/整数兼容归一化（`7200`→`2h`），但公开
HTTP/domain duration 契约仍严格拒绝零、负数、无单位小数、坏 JSON 和错误形状；补 tool create execution、正负解码与
domain/handler 守卫测试，并同步 approval domain 文档。定向 Go tests 全部通过：
`go test ./internal/app/tool/approval ./internal/app/approval ./internal/domain/approval ./internal/transport/httpapi/handlers`。

最终真实 session `/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-180647` 使用 workspace
`ws_14972f564f66a37d`，由同一 conductor 托管真实 Flutter App、Computer Use、`28438` 窗口 `132.026667s` 录像、
backend/frontend journals、三路独立 SSE witness、真实 gateway 和 LLM tap。用户实际输入要求创建
`ep096-refund-review-fixed`，声明 `amount:number`、`customer:string`，允许 reason，`2h` 后 reject。
最终画面正文明确创建成功，工具卡为 `Created approval … · v1`，Activity 只有一条 Created，展开的审批预览完整显示
prompt、两项输入类型、`2h`、`auto-rejects after 2h`、`note allowed` 及 Approve/Reject；无失败行、Draft unsaved、
矛盾文案、裁切、重叠、loading 残留或输入跳变。

五通道对证：backend journal 无 WARN/ERROR/panic/tool execute failed；frontend console 只有已知 launcher
`Failed to foreground app; open returned 1`，无 Dart/Flutter/RenderFlex/Unhandled runtime error；SSE durable frame 记录
唯一 `create_approval` open/close、`approval.created` 和 touchpoint，durable seq 单调；LLM journal 全部 upstream response
为 200，真实工具参数仍为 `"timeout":"7200"`，证明修复覆盖真实托管形状而非手写请求。最终 HTTP 与 SQLite 同时证明
`apf_c07e5096237e71db` 的 active `v1` 为 `timeout=2h`、`timeout_behavior=reject`、inputs 为 amount/customer，
`7200` 未泄漏到持久层、HTTP 或 UI。正式绿证据为
`/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-180647/evidence/EP-096-approval-create-final-green.md`。

用户已授权并完成本轮 fixture cleanup：临时 sidecar session
`/private/tmp/anselm-rig-ep096-cleanup-20260808/sessions/20260808-181438` 通过 API 删除三条审批和三条验收对话，
六次 DELETE 均 `204`，随后六个 exact GET 均 `404`，审批列表不再出现 `ep096-*`。SQLite 三条审批主行保留非空
`deleted_at`，三条 v1 immutable version rows 保留 `2h/reject`；红绿证据、LLM/SSE/backend/frontend journals 与录像均未删。
清理证据为
`/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-180647/evidence/EP-096-fixture-cleanup.md`。

独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-096-approval-create-ledger-reaudit.md`。
`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1170→1175 judgments`，`COVERAGE EP-096=✓✓✓✓✓`，anchors=10/10；集中写账
打开的 `gap-too-fast`/`discovery-collapse` 已依据红证据、修复测试、第二次真实 session、负向边界和五通道复审后 ack，
没有修改阈值、算法、法典或锚点。正确 formal home 下 `alarms.py check`=`clean (1175)`，`gen_coverage.py --check`=
`848 rows / 228 carried / 0 tombstones`。

批次二十二当前 **45/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-089/EP-090/EP-091/EP-092/EP-093/EP-094/
EP-095/EP-096 的代码、测试、契约文档、红绿证据、清理记录和 COVERAGE ledger 留在当前工作树，随批次二十二第 50 格
统一提交。下一原子前线为 EP-097 `GET /api/v1/approvals`。

### 5.2 历史状态快照（EP-092，批次二十二 25/50）

EP-092 `POST /api/v1/controls/{id}:revert` 已按完整产品目的完成真实 App、受管 gateway、Computer Use 和五通道
验收：只移动 Control active pointer 到 v1，保留 name/description、不铸造新版本且保留 v2 历史。真实模型只调用一次
`revert_control`；最终画面显示 v1 的 score input、ordered routes 和两侧 emit，无裁切、重叠或 loading 残留。
固定 session `/private/tmp/anselm-rig-ep092-control-revert-20260808/sessions/20260808-162625`，录屏
`474.791667s / 2784x1808 / 60fps`；HTTP 矩阵覆盖 v2/v1 成功回退及 zero/unknown 版本 404，SQLite/REST/UI/SSE
一致，cleanup 后 App 收敛到 `0 entities, 0 relations`。账本 `1150→1155`，COVERAGE 五级全绿，anchors=10/10，
`alarms.py check`=`clean (1155)`，清册 `848/224/0`；错误 shell quoting 只作为无副作用 harness 证据保留。

### 5.2 历史状态快照（EP-091，批次二十二 20/50）

**历史前线（2026-08-08，清册 EP-091 已完成，批次二十二 20/50）。**
EP-091 `POST /api/v1/controls/{id}:edit` 已按完整产品目的完成验收：用户在真实 App 中表达「只改变
Control 的一个路由条件」时，未提及的输入声明、port、emit 和 catch-all 都保留；托管模型的等值 JSON
数组编码可以正常执行；显式清空仍有明确语义；坏输入在 mutation 前大声失败。最终真实画面显示 active v5、
`score:number`、approve `input.score >= 0.96`、review default 和两侧 `emit: decision`。

首轮真实 AI 编辑发现两层产品红并冻结前线。第一层是托管模型把 `inputs`/`branches` 作为精确 JSON 数组
字符串传入，旧工具边界按原生数组解码并失败；第二层更严重：旧 `edit_control` 把省略的可选 `inputs` 当成
空值，模型只想把阈值从 `0.90` 调到 `0.95`，却生成了 `inputs:null` 的 v3，破坏了原有 `score` 输入声明。
这不是可接受的重试噪声，而是局部编辑造成的数据丢失。红证据永久保留于
`/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-160105/evidence/EP-091-control-edit-red-inputs-erased.md`。

stop-and-fix 同时修复 AI、领域服务和 HTTP 边界：`decodeControlInputs` 接受原生数组与精确 JSON 数组字符串，
仍拒绝 malformed/object/non-array；`edit_control` 以字段 presence 区分「省略=保留 active declaration」与
「显式 []=清空」；HTTP `:edit` 遵守同一语义，并在坏输入时先返回 `INVALID_REQUEST`，不做部分 mutation。服务层
增加 `PreserveInputsIfOmitted` 保护，补充 stringified、malformed、service-level 与 tool-level 回归测试；
Control API/domain 文档同步说明契约。

固定 session `/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-161138` 由同一 conductor
托管真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness、managed gateway
和 LLM tap；录屏 `388.893333s / 2784x1808`。先将旧红状态恢复到 v2，真实 App 的 Edit with AI 创建 v4，真实
LLM wire `00006_v1_chat_completions.bin` 证实托管模型传入 stringified inputs，v4 保留 score 声明并把阈值改为
0.95。随后 HTTP 省略 inputs 创建 v5，仍保留 score 声明；HTTP `inputs:"not json"` 返回 400 且 GET 证明 v5
未被污染。最终 Computer Use 逐帧确认 v5 详情无裁切、重叠、跳变或残留 loading。

REST/SQLite/SSE/UI/LLM 对证：`control-v4.json` 与 `http/omit-inputs.json` 均含 `score:number`；malformed HTTP
证据为 `http/malformed-inputs.json`。三路 SSE 均连接，messages durable seq `1..35`、notifications durable
seq `1..5` 严格单调，entities 完成连接；backend 494 行无 WARN/ERROR/FATAL/panic/tool execute failed，frontend
18 行无 Flutter/Dart/RenderFlex/Unhandled 红线；challenge 与 5 次真实 chat completion 全 HTTP 200。`rig-check.sh`
收台前确认 backend/ssetap/llmtap/Flutter runner/recorder 均归属本 session，`rig-down.sh` 后无残留进程。

正式绿证据为
`/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-161138/evidence/EP-091-control-edit-final-green.md`；
独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-091-control-edit-ledger-reaudit.md`。
`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1145→1150 judgments`，`COVERAGE EP-091=✓✓✓✓✓`，anchors=10/10。
集中写账触发的 `gap-too-fast`/`discovery-collapse` 已按独立复审记录 ack，未改阈值、算法、法典或锚点；
`alarms.py check`=`clean (1150)`，`gen_coverage.py --check`=`848 rows / 223 carried / 0 tombstones`。

批次二十二当前 **20/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-089/EP-090/EP-091 的代码、测试、
契约文档、红绿证据、工作记录和 COVERAGE ledger 留在当前工作树，随批次二十二第 50 格统一提交。下一原子前线为
EP-092 `POST /api/v1/controls/{id}:revert`。

### 5.2 历史状态快照（EP-090，批次二十二 15/50）

**历史前线（2026-08-08，清册 EP-090 已完成，批次二十二 15/50）。**
EP-090 `DELETE /api/v1/controls/{id}` 已按完整产品目的完成验收：用户删除 Control 后，真实 App 的
Entities rail、Parts 计数和关系图都收敛到 REST/数据库事实；被删实体消失，仍存活的 workflow 保留，历史版本
保留，悬空引用由 capability-check 明确显示，重复删除和未知 ID 给出可解释 404。固定切片同时删除同类
Approval 以验证关系依赖通知的对称语义；Approval 自身的 coverage 单格仍由 EP-100 管理，不在本格重复计数。

首轮真实 session 发现产品红：Control/Approval DELETE、关系查询和 REST `/relgraph` 已正确更新，但 Overview
的关系图只在挂载时读取一次；等待约 `2.5s` 后仍显示 `8 entities, 6 relations`，保留已删除实体的 ghost nodes。
前线冻结。修复将 `EntityRepository` 增加 workspace-wide durable `relationSignals()`，不把 relation 变化错误
裁剪成七种 rail `EntityKind`；Live 实现只消费 durable notification，ephemeral frame 不触发耐久快照刷新。
`relGraphProvider` 同时监听 relation pulse 与 lifecycle resync，并以 `300ms` 合并删除及聚合依赖通知，避免中间
拓扑闪现和重复请求。Fixture、provider 和三项专门测试同步；Flutter 定向 15 项全通过。

红证据永久保留于
`/private/tmp/anselm-rig-ep090-control-delete-20260808/sessions/20260808-152528/evidence/EP-090-control-delete-red.md`。
固定 session `/private/tmp/anselm-rig-ep090-control-delete-fixed-20260808/sessions/20260808-153741` 由同一
conductor 托管真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness、
managed gateway 和 LLM tap；录屏 `98.700000s / 2784x1808 / 60fps`。新 fixture 创建后真实 App 从 `6/4`
收敛到 `14 entities, 10 relations`；连续删除后从 REST 的 `12/8` 收敛到相同的 `12 entities, 8 relations`，
两类 rail 行消失、Parts 回到 0，剩余 workflow/trigger/function 节点保留。

REST/SQLite/SSE/UI 对证：Control/Approval delete 均 `204`，exact GET 与重复 DELETE 均 `404`；Control/Approval
版本历史仍保留；relations 清除被删实体 equip 边；capability-check 返回 `structurallyValid:true,
resolved:true` 并列出悬空 control/approval 引用。notifications durable seq `1..8` 严格连续，依次包含两类
created、workflow created、两类 deleted 及各自 `relation.dependency_broken`；backend 195 行无 panic/FATAL/ERROR
或未解释 WARN，frontend 18 行无 Flutter runtime 红线，固定 session 三流各连接且 rig-check/rig-down 干净收台。
本确定性 REST/UI 切片没有伪造 LLM completion，llmtap 只记录真实 ready/wiring；challenge/install/models 仍由台架
真实接线验证。

正式绿证据为
`/private/tmp/anselm-rig-ep090-control-delete-fixed-20260808/sessions/20260808-153741/evidence/EP-090-control-delete-final-green.md`，
首轮红证据同目录见上；独立账本复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-090-control-delete-ledger-reaudit.md`。
`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1140→1145 judgments`，`COVERAGE EP-090=✓✓✓✓✓`，anchors=10/10。
集中写账触发的 `gap-too-fast`/`discovery-collapse` 已依据独立复审记录 ack，未改阈值、算法、法典或锚点；
`alarms.py check`=`clean (1145)`，`gen_coverage.py --check`=`848 rows / 222 carried / 0 tombstones`。

批次二十二当时 **15/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-091。

### 5.2 历史状态快照（EP-089，批次二十二 10/50）
EP-089 `PATCH /api/v1/controls/{id}` 已按完整产品目的完成验收：真实用户修改 Control metadata 后，
列表和详情准确反映 name/description；metadata patch 不铸造新版本；空 patch 或等值 patch 可安全重试，
不会刷新时间戳、写盘或制造生命周期事件。真实 App 详情逐帧显示 `EP089 Control Patched`、description、
opaque ID、v1、更新时间、两个 input 和两个 ordered routing branch。

首轮真实 session 发现产品红：空 `PATCH {}` 返回 200 但仍产生 `control.updated` durable notification，并因 ORM
Save 总刷新而改变 `updatedAt`。按 stop-and-fix 冻结并修复 Control UpdateMeta；同类 Approval 一并修复。现在
两者均在实际字段发生变化时才 Save/publish，空 patch/等值 patch 直接返回当前实体；API/domain 文档与 app
层 recording-notifier 回归测试已同步。红证据永久保留于
`/private/tmp/anselm-rig-ep089-control-patch-20260808/sessions/20260808-150028/evidence/EP-089-control-patch-red.md`。

固定 session `/private/tmp/anselm-rig-ep089-control-patch-fixed-20260808/sessions/20260808-151021` 由同一
conductor 托管真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness、
managed gateway 和 LLM tap；录屏 `401.523333s / 2784x1808 / 60fps`。Control 与 Approval 的实际 patch、空
patch、等值 patch、错误边界、删除 cleanup 均已走通。notifications durable seq `1..6` 严格为两类实体的
created/实际 updated/deleted；no-op 没有幽灵帧。删除后真实 App Overview 的 Control/Approval rail 无残留、Parts
为 0、关系图为 0 entities/0 relations，空态引导完整。

REST/SQLite/SSE/UI/LLM 对证：Control no-op 的 `updatedAt` 为
`2026-08-08T07:15:17.41525Z` 前后一致，Approval no-op 的 `updatedAt` 为
`2026-08-08T07:15:17.640948Z` 前后一致；实际变化各只发一条 updated。空名/未知字段/未知 id/缺 workspace
header 均按预期返回 422/400/404/401；DELETE=204 后 exact GET=404、live lists=0、workspace 保留。backend
511 行无应用 WARN/ERROR/panic/FATAL，frontend 19 行无 Flutter runtime 红线，managed challenge/install/models
全 200，三路 SSE 连接且无 gap，rig-check/rig-down 干净收台。

正式证据为
`/private/tmp/anselm-rig-ep089-control-patch-fixed-20260808/sessions/20260808-151021/evidence/EP-089-control-patch-final-green.md`，
独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-089-control-patch-ledger-reaudit.md`；
`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1135→1140 judgments`，`COVERAGE EP-089=✓✓✓✓✓`，anchors=10/10。
两条集中写账警报经独立重读红绿 session、REST、SSE、backend/frontend/LLM、UI 和单元测试后 ack，未改阈值、
算法、法典或锚点；`alarms.py check`=`clean (1140)`，`gen_coverage.py --check`=`848 rows / 221 carried / 0 tombstones`。

批次二十二当前 **10/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-089 的代码、测试、契约文档、红绿
证据、工作记录和 COVERAGE ledger 留在当前工作树，随批次二十二第 50 格统一提交。下一原子前线为 EP-090。

### 5.2 历史状态快照（EP-086，批次二十一 45/50）

**历史前线（2026-08-08 13:35，清册 EP-086 已完成，批次二十一 45/50）。**
EP-086 `POST /api/v1/controls` 已按完整产品目的完成验收：用户可以创建带有输入 schema、条件分支、
all-else 默认分支和 emit 映射的 Control，并在实体详情中读懂版本、输入类型、路由条件和输出；非法
输入在落库前明确拒绝，重复名称保持冲突语义，删除后列表、详情、关系和 UI 都诚实收敛。

首轮真实 session `/private/tmp/anselm-rig-ep086-control-20260808/sessions/20260808-132051` 发现
unknown input type `money` 被错误接受并渲染，冻结为产品红；stop-and-fix 增加 schema 输入校验和
`CONTROL_INVALID_INPUTS`，create/edit 均在持久化前拒绝未知类型、重复字段名等错误，并补 domain/app
回归。修复后 fresh session `/private/tmp/anselm-rig-ep086-control-20260808-fixed/sessions/20260808-132726`
重跑通过：空名、空分支、缺 catchall、非法 CEL、未知类型、重复字段名均为可解释 422；合法 control
为 201，重复名称为 409。修复证据和首轮红证据均永久保留。

最终 session 由同一 conductor 托管真实 Flutter App、Computer Use、录屏、frontend/backend journal、
三路独立 SSE witness、managed gateway 和 LLM tap；录屏 `166.691667s`，rig-check/rig-down 通过并
干净收台。notifications/entities/messages 三流均连接，control.created/deleted durable frame 与
REST/SQLite 对齐；challenge/install/models 全 200；backend/frontend 无未解释应用红线。实体详情逐帧
显示 `amount: number`、`region: string`、三条路由分支、默认分支和 emit keys，清理后回到空 Overview。
所有临时 control 均 DELETE=204 → GET=404，workspace GET=200；SQLite 保留 tombstone、v1 版本和通知，
relations=0，不误删 seeded 数据。

正式证据为 `/private/tmp/anselm-rig-ep086-control-20260808-fixed/sessions/20260808-132726/evidence/EP-086-control-real-session.md`，
独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-086-control-ledger-reaudit.md`。
anchors=10/10；`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本 `1120→1125 judgments`，
`COVERAGE EP-086=✓✓✓✓✓`。集中写账警报以复审证据 ack，阈值、算法、法典和锚点未改，
`alarms.py check`=`clean (1125)`；`gen_coverage.py --check`=`848 rows / 218 carried / 0 tombstones`。

批次二十一当时累计 **45/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-086 的
`CONTROL_INVALID_INPUTS` 代码、测试、API/domain 文档、五通道证据和 COVERAGE ledger 随批次二十一第 50 格
统一提交；下一原子前线为 EP-087 `GET /api/v1/controls`。

### 5.2 历史状态快照（EP-085，批次二十一 40/50）

**当前前线（2026-08-08，清册 EP-085 已完成，批次二十一 40/50）。**
EP-085 ANY /api/v1/webhooks/{triggerId}/{path...} 已按完整产品目的完成验收：外部系统可以在不带
Anselm bearer/workspace header 的情况下访问 catch-all webhook，按 HMAC 或 plain secret 正确认证，
让绑定 workflow 真实执行；用户能从 Trigger 详情发现挂载 URL 和认证载体，在同一详情页看到
Last fired、Activity 与 Dispatch 的真实回声；改 path 后旧地址立即 404、新地址立即 202，详情页
同步展示新 URL。重复网络请求保留 Activation 审计但不重复建 Firing/run，满足可追溯与幂等两端。

本轮使用 fresh data directory 和真实 onboarding 建立 workspace，创建并激活 HMAC webhook pipeline、
plain-secret webhook pipeline 以及真实 Python Function action。真实 Computer Use 矩阵覆盖 wrong method、
bad/missing/wrong auth、valid JSON、同 body retry、不同 JSON、纯文本 body、header/query secret、
path edit 前后；UI 逐步核对了 URL/Copy、签名算法和自定义 header、Listening、Last fired、Activity、
Dispatch，以及 plain-secret 的 X-Webhook-Secret header or ?token= query 引导。首轮真实路径发现
外部 fire 后打开的 Overview 仍显示 Last fired: never，stop-and-fix 为 fire signal 触发 REST truth
refresh 并失效 observability projection；第二轮又发现 plain-secret 详情缺少认证载体说明，补上双语
引导且不渲染 secret，最终 session 重跑通过。两处红证据和修复后绿证据均保留，未把仪器错误或正确
的 dedup 语义误报为产品红。

正式 session 为 /private/tmp/anselm-rig-ep085-webhook-20260808-final/sessions/20260808-125703，
证据为其 evidence/EP-085-webhook-real-session.md，独立账本复审为
/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-085-webhook-ledger-reaudit.md；同一 conductor
托管真实 Flutter App、窗口录制、backend/frontend journal、三路独立 SSE witness、managed gateway
wiring 和 LLM tap。录屏 539.071667s；rig-check、rig-down 通过且进程/监听器全部收台。SSE
独立 witness 连接 notifications/entities/messages，durable seq 分别 1..10、1..12 无 gap；
backend/frontend 无未解释应用红线；challenge/install/models 全 HTTP 200，确定性 webhook slice
没有伪造 LLM completion。SQLite 对证 HMAC 为 5 Activation / 4 Firing / 4 completed Flowrun，
duplicate dedup group 为 0，plain-secret 为 2 Activation / 1 Firing。全部 fixture 均
DELETE=204 → GET=404，三类 live 列表为空，workspace 保持 GET=200；录屏、journal、数据库和
抽帧证据全部保留。

anchors=10/10；judge.py 按 G1/F2/A5/C4/G2 将正式账本 1115→1120 judgments，
COVERAGE EP-085=✓✓✓✓✓。集中写账打开的 gap-too-fast 与 discovery-collapse 已以独立
复审证据逐项 ack，阈值、算法、法典和锚点未改，alarms.py check=clean (1120)。清册重生检查
保持 848 rows / 217 carried / 0 tombstones。

批次二十一当前累计 **40/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-085 的 trigger
detail fire-refresh、plain-secret discoverability、实体契约/i18n/文档和 COVERAGE ledger 均留在当前
工作树，随批次二十一第 50 格统一提交。下一原子前线为 EP-086 POST /api/v1/controls。

### 5.2 历史状态快照（EP-084，批次二十一 35/50）

**历史前线（2026-08-08 12:38，清册 EP-084 已完成，批次二十一 35/50）。**
EP-084 `GET /api/v1/trigger-schedule` 已按完整产品目的完成验收：用户在真实 Scheduler Overview
可以看到未来 cron 时间线，知道下一次自动化属于哪个 workflow，区分正常、暂停、无人引用和没有可预测
下一次触发的来源，理解时间线被封顶时发生了什么，并从已有运行的时间格进入正确的 run/operations
表面。真实 API、SQLite、SSE、Flutter 画面和五通道终端日志对同一批调度事实给出一致结论。

本轮真实 App 使用 fresh data directory，先通过真实 onboarding 建立 workspace，再通过当前 LLM tap
连通 managed Anselm gateway。夹具包含每分钟 dense cron、每小时 sparse cron、paused cron、无 workflow
的 unreferenced cron 和 webhook。真实 dense cron 连续产生 9 条 `fire → run_started → run →
run_terminal(completed)` 链；Overview 的 25 小时矩阵显示成功格，点格进入 workflow run/operations
表面；hover card 显示小时内的时间、来源、耗时，并对隐藏的两条成功记录给出 `2 more all succeeded`。
paused lane 保留在原位并显示 `Paused`，没有伪造 `nextFireAt`；webhook 和无人引用 cron 没有伪造未来点；
`More is scheduled inside this window than the track can show.` 独立说明未来截断。清理后 durable delete
通知驱动 App 收敛到 `No automation yet`，无幽灵泳道。

本轮没有发现需要 stop-and-fix 的产品缺陷：真实视觉帧没有裁切改变语义、重叠、死 spinner、错误未来预测、
不解释的跳变或机器 ID 泄露；长名称使用有界省略，AX tree 保留完整标签，时间/状态在未来句和 hover card
中保持最高优先级。EP-084 的 setup-only 红 session 因复用数据库残留旧 gateway wiring，被 `rig-check`
正确拒绝并单独保留，不计产品红；随后用 fresh data 重跑，不把仪器问题伪装成产品结论。

正式证据为 `/private/tmp/anselm-rig-ep084-schedule-20260808-retry/sessions/20260808-122252/evidence/EP-084-schedule-real-session.md`，
独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-084-trigger-schedule-ledger-reaudit.md`；
同一 conductor 托管真实 Flutter App、Computer Use、窗口录像、backend/frontend journal、三路独立 SSE
witness、managed gateway wiring 和 LLM tap。封口录屏 `667.105000s`，`rig-check`、`rig-down` 通过且 owned
process/listener 全部收台；视觉帧保留 Overview、hover card 和清理后的空状态。

五通道对证：SSE witness 共 73 条 JSONL，entities 44 条、durable seq `1..20`，notifications 29 条、
durable seq `1..27`；backend 无 panic/WARN/ERROR/FATAL 应用红线，frontend 无 Dart/FlutterError/RenderFlex/
Unhandled/lost-device/assertion 红线，LLM challenge/install/models 全 200。唯一 frontend 输出是已知
Flutter runner `Failed to foreground app; open returned 1`，随后 App 正常构建并全程可观测；确定性 workflow
正确没有伪造 completion。10 个临时 fixture 均 `DELETE=204` 后 `GET=404`，workspace 仍 `200`，session、
journal 和录屏全部保留。

定向黑盒 `TestTriggerSchedule_(Timeline|TruncatesHonestly)` 通过，Scheduler KPI/Overview Flutter 回归
共 65 项通过。anchors=`10/10`；`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1110→1115 judgments`，
`COVERAGE EP-084=✓✓✓✓✓`；集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已用独立复审证据逐项
ack，阈值、算法、法典和锚点未改，`alarms.py check`=`clean (1115)`。清册为
`gen_coverage.py --check`=`848 rows / 216 carried / 0 tombstones`。

批次二十一当时累计 **35/50**，尚未达到 50 格，因此不运行统一长门禁、不提交。EP-079/EP-081 修复、
activation 修复、EP-083 workflow 名称修复、EP-084 本轮文档和 COVERAGE ledger 均留在当前工作树，随
批次二十一第 50 格统一提交。当时下一原子前线为 EP-085 ANY /api/v1/webhooks/{triggerId}/{path...}。

### 5.2 历史状态快照（EP-077，批次二十 47/50）

**当前前线（2026-08-08 07:56，清册 EP-077 已完成，批次二十 47/50）。**
`POST /api/v1/triggers/{id}:pause` 已按完整产品目的完成验收：用户从真实 Entities rail 的
More actions 选择 Pause 后，Trigger 在原详情页进入 `Paused`，源头 listener 注销但 workflow
引用保留；Fire 保留空间位置但 inert，直接 REST `:fire` 以 `422 TRIGGER_PAUSED` 大声拒绝。用户
随后从同一处 Resume，listener 按当前 config 重新注册，详情回到 `Listening`，恢复后的 sensor
source 真实产生 activation→firing→flowrun 并完成。暂停开关、运行投影和 SSE 状态帧没有分叉。

最终 session `/private/tmp/anselm-rig-ep077-pause-20260808/sessions/20260808-074937` 由同一
conductor 托管真实 Flutter App、Computer Use、窗口录像、backend journal、三路独立 SSE witness、
真实 managed gateway wiring 和 LLM tap；运行中 `rig-check` 五通道通过，`rig-down` 后 owned
process/listener 全部收台，录屏 `207.725000s / 2784x1808 / 60fps`。关键帧为
`evidence/trigger-paused-final.png` 与 `evidence/trigger-resumed-final.png`。

REST/SQLite/SSE/UI 对证：暂停读模型为 `paused=true/listening=false/refCount=1`；暂停期间
`:fire=422 TRIGGER_PAUSED`，activation/firing/flowrun 数保持不变。Resume 后读模型为
`paused=false/listening=true/refCount=1`，sensor 新建 activation=`tra_217e69d5737b4a0c`、
firing=`trf_e1ce88be0f712109`、flowrun=`fr_6aeac3da976cacbb`，flowrun REST/SQLite=`completed`。
SSE 三流均连接；entities 记录同一 trigger scope 的 `status {paused:true}` 与
`status {paused:false}`，随后同一 workflow 的 `fire`、`run_started(seq=3)`、
`run_terminal(completed,seq=4)`，durable 序列单调，ephemeral 帧没有被冒充耐久状态。

frontend/backend/LLM 行数为 `32/254/1`；backend 无 panic/FATAL/WARN/ERROR，frontend 无
Flutter/Dart/RenderFlex/Unhandled/assertion 红线，AXTree 报错已由同 session 的
`evidence/frontend-ax-review.md` 复核为 Computer Use 观察器噪声；deterministic workflow 的
LLM tap 只有 ready，不冒充 completion。三次 shell/台架问题（`path` 覆盖 PATH、zsh 未给
`$ID:resume` 加花括号、首次 rig-check 缺 AX review）均已正确重跑并记录为仪器问题，不计产品红。

正式红/绿/独立复审证据分别为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-077-trigger-pause-red.md`、
`EP-077-trigger-pause-green.md`、`EP-077-trigger-pause-ledger-reaudit.md`。anchors `10/10`；
`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1070→1075 judgments`，`COVERAGE EP-077=✓✓✓✓✓`；
集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按独立复审 ack，阈值、算法、法典和
锚点未改，`alarms.py check`=`clean (1075)`，`gen_coverage.py --check`=`848 rows / 209 carried / 0 tombstones`。
定向 Go/Flutter/Dart analyze、录像封口、收台和 `git diff --check` 通过。

批次二十当前 **47/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-078
`POST /api/v1/triggers/{id}:resume`。

### 5.2 历史状态快照（EP-076，批次二十 42/50）

**历史前线（2026-08-08 07:44，清册 EP-076 已完成，批次二十 42/50）。**
`POST /api/v1/triggers/{id}:fire` 已按完整产品目的完成验收：用户在真实 Trigger 详情点击 Fire 后，
立即得到动作反馈；Dispatch 允许短暂显示 durable `pending`，但在同一页面通过有界 REST 重读自动收敛到
真实的 `started` disposition 和 flowrun；Activation、Firing、Flowrun、SSE 和 SQLite 的 ID/状态链
可以互相追溯。暂停时详情徽标显示 `Paused`，Fire 保留空间位置但 inert，并明确提示先 Resume；后端
`TRIGGER_PAUSED` 仍是最终防线。

首轮真实 session `/private/tmp/anselm-rig-ep076-fire-20260808/sessions/20260808-071716` 冻结了三条
真实红：暂停态曾显示 `Idle` 且 Fire 仍可点；手动 fire 的 `{manual:true}` 被错误 fixture graph
送进需要 `start.name` 的 action，run `fr_9e3ae7722a140bef` 诚实失败；Dispatch 首次读到 `pending`
后不再重读，workflow 已 terminal 但 UI 留在旧状态。红证据与录屏永久保留，不计绿。

stop-and-fix 直接修复了暂停态 header、i18n 和 trigger widget regression；将 disposable workflow
改成无参数 `sync_inventory` action，使手动 fire 的 payload 与 graph 契约相容；`FiringListNotifier`
在当前页仍有 pending 时每 500ms 重读同一 REST 页并按 id 替换行，进入终态立即停止，瞬时失败保持
last-known-good 后按 pending 条件重试；fixture 支持行级更新，新增 pending→started widget regression。
同步 frontend entities 文档和本过程证据。

最终 session `/private/tmp/anselm-rig-ep076-fire-20260808/sessions/20260808-073336` 由同一 conductor
托管真实 Flutter App、Computer Use、窗口录像、backend journal、三路独立 SSE witness、真实 managed
gateway wiring 和 LLM tap；运行中 `rig-check` 五通道通过，`rig-down` 后 owned process/listener
全部收台，录屏 `434.098333s`。关键帧为 `dispatch-after-fire.png`、`dispatch-settled.png`、
`trigger-paused-final.png`、`trigger-resumed-final.png`。

REST/SQLite/SSE/UI 对证：主路径 `:fire=202`，activation=`tra_1d399eb2587378fc`，
`fired=true/firingCount=1/payload={manual:true}`；firing=`trf_789d0baf6b1f6162` 为
`started` 且关联 flowrun=`fr_957497ee81dcfba7`；flowrun REST/SQLite terminal=`completed`，
capability-check=`200 {structurallyValid:true,resolved:true}`。SSE 三流均连接，entities durable
seq `1..10` 单调无重无倒退，主 Fire 为 ephemeral frame，随后同一 flowrun 收到
`run_started(seq=3)` 与 `run_terminal(completed,seq=4)`；deterministic graph 的 LLM tap 只有
ready，不冒充 completion。

暂停负向同一 session 真实得到 `paused=true/listening=false`，Computer Use 画面为 `Paused` + inert
Fire，直接 `:fire=422 TRIGGER_PAUSED` 且无新增 activation/firing/flowrun；随后用正确的
`${endpoint}:resume` 恢复为 `paused=false/listening=true`。一次不带花括号的 zsh endpoint 拼接
404 被单独记录为仪器错误，不计产品红。

backend journal `524` 行、frontend `18` 行、SSE `32` 行、LLM `1` 行；修正版无应用级
WARN/ERROR/panic/FATAL 或 Flutter/Dart/RenderFlex/Unhandled/assertion 红线，唯一平台噪声为已知
Flutter runner `Failed to foreground app; open returned 1`。定向 Dart analyze、12 项 trigger widget
tests、trigger/handler/store Go tests 和 `git diff --check` 通过。

正式红/绿/独立复审证据分别为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-076-trigger-fire-red.md`、
`EP-076-trigger-fire-green.md`、`EP-076-trigger-fire-ledger-reaudit.md`。锚点 `10/10`；`judge.py`
按 `G1/F2/A5/C4/G2` 将账本 `1065→1070 judgments`，`COVERAGE EP-076=✓✓✓✓✓`；集中写账触发的
`gap-too-fast` 与 `discovery-collapse` 已按独立复审 ack，阈值、算法、法典和锚点未改，
`alarms.py check`=`clean (1070)`，`gen_coverage.py --check`=`848 rows / 208 carried / 0 tombstones`。

批次二十当前 **42/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-077
`POST /api/v1/triggers/{id}:pause`。

### 5.2 历史状态快照（EP-075，批次二十 41/50）

**当前前线（2026-08-08 07:10，清册 EP-075 已完成，批次二十 41/50）。**
`DELETE /api/v1/triggers/{id}` 已按完整产品目的完成验收：用户从真实 Entities rail 删除一个正在监听且被
workflow 使用的 trigger 时，确认框先说明会停止 listener、哪些 workflow 会悬空以及后续需要修复；确认后
实体从 rail/detail/关系图收敛，后端 soft-delete、关系清边、审计保留和 durable notification 均与 UI 一致。

首轮真实红 session `/private/tmp/anselm-rig-ep075-delete-20260808/sessions/20260808-065336` 抓到 generic
`Delete this entity?` 只说移出 active catalog，没有解释 `Listening: Yes / Listeners: 1` 或
`ep072fix-listening-workflow` 的依赖后果；红帧永久保留，未计绿。stop-and-fix 在 `EntityRail` 删除确认前
fresh 读取已有 `GET /api/v1/relgraph`，列出入向 `equip/link` 使用者，listener 热时给出停止监听文案，
关系读取失败则 fail-closed；同步中英文 i18n、30 项 widget regression、实体文档。审计同时修正
`docs/references/backend/events.md` 中与当前 durable trigger lifecycle notification 矛盾的旧句。

最终 session `/private/tmp/anselm-rig-ep075-delete-20260808/sessions/20260808-070205` 由同一 conductor
托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、
真实 managed gateway wiring 和 LLM tap，录屏 `308.340000s / 2784x1808 / 60fps`。真实画面先打开
`ep072fix-sensor-4-repaired` detail，看到 `Listening: Yes / Listeners: 1`，再在 Delete 确认框中看到
`ep072fix-listening-workflow`、停止 listener 和 repair 后果；点击已授权 Delete 后回到 Overview，Trigger
rail `24→23`、Parts `24→23`、关系图 `10→8`，通知托盘显示 trigger deleted 与 dangling dependency 两条记录。
绿帧为 `ep075-delete-confirm-green.png`、`ep075-after-delete-green.png`、`ep075-notifications-green.png`。

REST/SQLite/SSE 对证：DELETE=`204`，后续 trigger GET=`404 TRIGGER_NOT_FOUND`，trigger list=`23` 且 deleted id
缺席；relgraph=`8` 条边且 deleted id 缺席；SQLite 保留 tombstone `deleted_at`、5 条 activation、5 条 firing，
删除后新增 activation/firing 均为 0；引用 workflow 仍保留但 capability-check 诚实返回
`structurallyValid=true,resolved=true` 与缺失 trigger problem。独立 ssetap 三流均连接，entities durable `1..2`、
notifications `1..2` 单调，关键帧为 `trigger.deleted` 与 `relation.dependency_broken`；LLM tap 有 ready 回执，
本确定性删除路径没有伪造模型 completion。

五通道封口：backend 无应用 WARN/ERROR/panic/FATAL；frontend 仅 2 条固定 Flutter macOS AXTree observer churn，
已在 session `frontend-ax-review.md` 标记 `tooling-ax-tree/reviewed`，静置 10 秒不增长且没有 Dart/FlutterError/
RenderFlex/overflow/Unhandled/lost-device；rig-check 在动态操作后通过，rig-down 后 owned process groups 归零。
锚点 `10/10`；`judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，账本 `1060→1065 judgments`，`COVERAGE EP-075=✓✓✓✓✓`。
集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已依据独立复审、红绿证据、五通道 journal 和锚点 ack；
阈值、算法、法典和锚点未改，`alarms.py check`=`clean (1065)`；`gen_coverage.py --check`=`848 rows / 207 carried / 0 tombstones`。
定向 Dart analyze、实体 rail 30 项 Flutter 测试、trigger/relation/http handler Go 测试和 `git diff --check` 通过。

批次二十当前 **41/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-076
`POST /api/v1/triggers/{id}:fire`。

### 5.2 历史状态快照（EP-070，批次二十 20/50）

EP-070 `POST /api/v1/flowruns/{id}/approvals/{node}:decide` 已完成真实 App、受管 gateway、
Computer Use 和五通道验收。用户能从 Scheduler Overview 或顶部 approval capsule 理解真实
生产审批、填写理由、批准/拒绝，并看到 inbox、运行计数、下游节点和 run history 收敛；非法
decision、未知字段、重复决策和并发 first-wins 均有诚实边界，拒绝不会执行 publish。

正式 session `/private/tmp/anselm-rig-ep070-approval-decision-20260808/sessions/20260808-043003`
录屏 `788.638333s / 2784x1808 / 60fps`，五通道完整且 `rig-check`/`rig-down` 通过。修正版
webhook fixture capability-check 为 `structurallyValid=true, resolved=true`，旧 test-only
`trg_manual` 仅保留 setup 红证据；旧错误 fixture 已按授权软删除，修正版 fixture 未删除。
四条正负/竞态路径、REST/SQLite/UI/SSE/LLM 交叉证据、逐帧产品检查和五级 `G1/F2/A5/C4/G2`
裁决均已封存于现有 EP-070 evidence；账本 `1035→1040`，`COVERAGE EP-070=✓✓✓✓✓`，
anchors `10/10`，`alarms.py check`=`clean (1040)`。批次二十当时 20/50，下一前线为 EP-071。

### 5.2 历史状态快照（EP-069，批次二十 15/50）

**历史快照（2026-08-08 04:26，清册 EP-069 已完成，批次二十 15/50）。** `GET /api/v1/flowrun-matrix` 已按完整产品目的完成验收：Scheduler 的矩阵真实呈现同一 workflow 的 completed、failed、running/awaiting-approval 和 sparse/not-reached 四种语义；用户点击红格可进入精确失败 dossier，点击等待列可进入 Gantt/approval 视图，Failed/Waiting/All 筛选与矩阵列保持一致。Computer Use 逐帧检查没有裁切、溢出、跳变、死 spinner 或不符合直觉的 CTA。

正式固定 session `/private/tmp/anselm-rig-ep069-flowrun-matrix-fixed-20260808/sessions/20260808-041832` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和真实 managed gateway wiring；录屏 `293.975000s`，最终 journal 为 backend/frontend/SSE/LLM=`402/18/18/1`，`rig-check` 五通道通过，`rig-down` 后 owned process groups 与监听端口均归零。矩阵 REST/SQLite 对证覆盖 newest-first 顺序、known/ghost 混合、all-ghost 空结果、重复 ID 去重、blank-only `400 INVALID_REQUEST`、51-ID `422 FLOWRUN_MATRIX_TOO_MANY_IDS`，running 行省略 elapsed、终态行展示 elapsed；SQLite 的 run/node rows 与 UI 每个状态一致。

首轮真实清理发现一个真实产品缺陷：REST 已空且 notifications 流已收到 durable `workflow.deleted` 后，scheduler rail 仍保留已删 workflow。前线冻结并 stop-and-fix：`scheduler_rail_provider` 增加 durable workflow lifecycle notification 订阅和 300ms refetch debounce，补回归测试；固定 session 清理后真实 UI 收敛到 `No automation yet`，没有 stale row。夹具签名错误则被保留为后端可解释的 setup failure evidence，不误判为产品红。两轮 fixture 均按授权精确清理，live entities 为空、tombstone/version/run/node 审计保留、seeded entities 未动。

正式证据 `/private/tmp/anselm-rig-ep069-flowrun-matrix-fixed-20260808/sessions/20260808-041832/evidence/EP-069-flowrun-matrix-real-session.md`，独立 ledger 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-069-flowrun-matrix-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 写入五格，账本 `1030→1035 judgments`，COVERAGE `EP-069=✓✓✓✓✓`，anchors `10/10`；集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按独立复审证据 ack，`alarms.py check`=`clean (1035)`，阈值、算法、法典和锚点未改。scheduler matrix/home、rail provider 定向 Flutter 测试，scheduler/store Go 测试和 `TestFlowrunMatrix_Grid` 均通过。

批次二十当前 **15/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-070 `POST /api/v1/flowruns/{id}/approvals/{node}:decide`。

### 5.2 历史状态快照（EP-068，批次二十 10/50）

**当前前线（2026-08-08 04:02，清册 EP-068 已完成，批次二十 10/50）。** `GET /api/v1/flowrun-stats` 已按完整产品目的完成验收：Scheduler 从同一统计投影与同一 schedule lane 诚实呈现运行、失败、审批等待、错过刻度和 workflow 健康。真实用户看到 `Running 1`、`Waiting 1`、`Failed · 24h 2`、`Next fire in <1m`；真实 cron 停机跨刻度重启后继续看到 `Missed · 24h 2`，lane 的无障碍描述同步为 `2 missed`，没有把 missed 伪装成 run 或静默吞掉。

正式 session `/private/tmp/anselm-rig-ep068-flowrun-stats-fixed-20260808/sessions/20260808-035335` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管 gateway wiring；录屏 `214.181667s / 2784x1808 / 60fps`，窗口 `26612`。真实路径覆盖：健康审批与连续失败 workflow → Scheduler Overview → 创建真实 minutely cron → 停机跨 `03:52` 刻度 → 同一数据目录重启 → Overview missed KPI/lane → workflow 详情的 cron runs、矩阵、成功率、平均耗时 → parked approval 收口。

REST 边界全部真实取证：主批查 totals `running=1/completedSince=5/failedSince=2/parkedNodes=1/missed=0`，byWorkflow 保留请求顺序与 ghost zero row；future/倒挂窗只清空窗内 landed aggregates，不抹掉 live running/parked 或 consecutive failures；`recentN=99` clamp，重复/空 ID 去重；51 个 ID 为 `422 FLOWRUN_STATS_TOO_MANY_IDS`；坏 since/until 为 `FLOWRUN_STATS_INVALID_SINCE`/`FLOWRUN_STATS_INVALID_UNTIL`。重启后的最终统计为 `completedSince=6/missed=2`，两条 missed firing 均无 `flowrunId` 且日期落在真实停机刻度。

REST/SQLite/SSE/UI 对证一致：SQLite `trigger_firings` 保留 `2 missed + 3 started`，四条 EP-068 手工 run 的 approval/health/failure 状态与 8 个 node rows 一致；删除后的六个 fixture 行保留 `deleted_at` tombstone。entities durable seq 观察到 cron `run_started/run_terminal` 和 approval terminal，notifications durable `1..6` 观察到 cleanup；messages、entities、notifications 三流均连接。backend/frontend/SSE/LLM=`356/18/29/1`，应用级 panic/FATAL/WARN/ERROR、Flutter/Dart/RenderFlex/Unhandled/assertion 均为零；deterministic graph 无 LLM 节点，tap 只有 readiness 而无 completion 是正确边界。

正式证据 `/private/tmp/anselm-rig-ep068-flowrun-stats-fixed-20260808/sessions/20260808-035335/evidence/EP-068-flowrun-stats-real-session.md`，ledger 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-068-flowrun-stats-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 写入五格，账本 `1025→1030 judgments`，COVERAGE `EP-068=✓✓✓✓✓`，anchors `10/10`；集中写账按原机制打开两条统计警报，已用独立复审证据 ack，最终 `alarms.py check`=`clean (1030)`，阈值、算法、法典和锚点均未调整。scheduler unit、`TestFlowrunStats_BatchProjection`、`TestTrigger_MisfireMissedAccounting` 均通过。

按用户删除授权，先将 parked run `fr_ff847dc5b94e0737` 决策为 `completed/decision=no`，再对 3 workflow、1 approval、1 trigger、1 function 执行精确 DELETE `204×6`、随后 GET `404×6`；搜索列表为空，tombstone、version、run/node/firing 审计保留，seeded entities 未动。批次二十当前 **10/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-069 `GET /api/v1/flowrun-matrix`。

### 5.2 历史状态快照（EP-067，批次二十 5/50）

**历史前线（2026-08-08 03:42，清册 EP-067 已完成，批次二十 5/50）。** `GET /api/v1/flowrun-inbox` 已按完整产品目的完成验收：真实用户在 Scheduler 和通知托盘都能找到停在 approval 的 run，看到流程名、`Awaiting approval`、节点名、渲染问题、明确倒计时和 Approve/Reject；批准、带理由拒绝、非法请求和终态重复决策都各自给出诚实结果，决策后收件箱和 Scheduler 空态立即收敛，没有孤立的 `human`、死卡或无限 spinner。

正式 session `/private/tmp/anselm-rig-ep067-flowrun-inbox-20260808/sessions/20260808-033401` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管 gateway wiring；录屏 `205.191667s / 2784x1808 / 60fps`，窗口 `26563`。真实 UI 路径覆盖 `Scheduler Overview → Waiting on you → Approve`、通知按钮 → `Needs you` → `+ Reason` → Reject，以及最后的 `No approvals waiting on you.` / `Nothing is running right now.` 空态。初始旧 session 曾发现 approval capsule 的真实 `RenderFlex overflowed by 18 pixels`，已 stop-and-fix 为异步问题高度测量 + 内容溢出保护；生成代码、静态分析和回归测试均通过，最终 session 前端日志没有该红线。

REST/SQLite/SSE 对证一致：`fr_30b3f4d1e090ee0d` 经真实 App Approve 后为 `completed`、human result=`decision=yes`；`fr_68dae31075077ccd` 经通知托盘带理由 Reject 后为 `completed`、human result=`decision=no` 且 reason=`需要业务方再确认`；`fr_86ea343f844bfb69` 的非法 `maybe` 返回 `422 FLOWRUN_INVALID_DECISION`、未知字段返回 `400 INVALID_REQUEST`，parked 行在两次拒绝后仍留在 inbox，随后正常拒绝并收口；重复决策返回 `422`。最终 `GET /api/v1/flowrun-inbox` 为 `{parked:[]}`，三条 run 各只有一个 `run_terminal(completed)`。

SSE witness 三流均真实连接：entities durable seq `1..6` 连续，notifications durable seq `1..3` 连续，parked/decision 行按契约为 ephemeral `seq=0`；messages 流在本 deterministic workflow 中没有业务帧，但连接已被 witness 记录。backend `330` 行、frontend `17` 行、SSE `19` 行、LLM `1` 行；backend 无 panic/FATAL/WARN/ERROR，frontend 无 Flutter/Dart/RenderFlex/Unhandled/assertion 红线。LLM tap 已在线并承接 `https://api.anselm.website`；本 graph 没有 LLM 节点，故 `ready` 后无 completion 请求是正确边界，不把 tap 就绪冒充模型产出。

正式证据 `/private/tmp/anselm-rig-ep067-flowrun-inbox-20260808/sessions/20260808-033401/evidence/EP-067-flowrun-inbox-real-session.md`，ledger 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-067-flowrun-inbox-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 写入五格，账本 `1020→1025 judgments`，COVERAGE `EP-067=✓✓✓✓✓`，anchors `10/10`；集中写账按原机制打开 `gap-too-fast` 与 `discovery-collapse`，已用独立复审证据 ack，最终 `alarms.py check`=`clean (1025)`，阈值、算法、法典和锚点均未调整。

按用户删除授权，workflow `wf_079bd3e516258373` 与 approval `apf_415cdf697e7fee9a` 精确 DELETE `204×2`、随后 GET `404×2`、搜索列表为空；tombstone、workflow version、三条 flowrun/node 审计保留，fixture relations=0，seeded entities 未动。前端 targeted tests `81` 项全绿，`flutter analyze` 无问题，`git diff --check` 和 `gen_coverage.py --check`=`848 rows / 199 carried / 0 tombstones` 通过。批次二十当前 **5/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-068 `GET /api/v1/flowrun-stats`。

### 5.2 历史状态快照（EP-065，批次十九 45/50）

**历史前线（2026-08-08 02:20，清册 EP-065 已完成，批次十九 45/50）。** `POST /api/v1/flowruns/{id}:replay` 已按完整产品目的完成验收：真实用户可以在 Scheduler 打开失败 run，先看到失败节点、完整 traceback 和明确的“重跑 1 个失败节点、复用 2 个已完成结果”确认，再在同一个 run dossier 里看到 `Replay #1`、四个节点全部完成、finish 输出和 Overview 的 `Failed · 24h 0`；已完成 run 再次 replay 则明确返回 `FLOWRUN_NOT_REPLAYABLE`，不会制造第二次执行。

正式 session `/private/tmp/anselm-rig-ep065-flowrun-replay-fixed-20260808/sessions/20260808-021122` 使用真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管 Anselm gateway；录屏 `147.960000s / 2784x1808 / 60fps`。正式 fixture 使用真实 webhook `trg_4fc6464cb69089fe`，graph 为 `webhook → function → flaky handler → finish function`；capability-check 返回 `structurallyValid=true`、`resolved=true`、无 problems/warnings。早先使用测试专用 `trg_manual` 的探索 session 因 capability-check 明确显示悬空引用，已排除，不计入绿裁决。

REST/SQLite/产品数据事实一致：UI run `fr_d2f77da1dbc075a0` 首次为 failed（start/stable completed、flaky failed、finish 未运行），确认后同 run `Replay #1`、四节点 completed；独立 REST run `fr_6d2e339a29ced1fe` 的 `POST /flowruns` 为 `201`，`POST /flowruns/{id}:replay` 为 `202`，结果 `flaky.n=2`、`finish.final=2`，第二次 replay 为 `422 FLOWRUN_NOT_REPLAYABLE`。每个 run 的审计均只有 stable 一次成功、finish 一次成功、handler 一次失败加一次成功，completed nodes 被复用而非重跑；原始失败 JSON 可由 `json.loads` 解析且无控制字符。

五通道已封存：backend journal `296` 行、frontend journal `18` 行、SSE journal `48` 行、LLM journal `10` 行；notifications durable seq `16..32`、entities durable seq `7..18` 单调，失败 terminal、replay 活动、成功 terminal 和 workflow attention 事件均已观察。真实 gateway challenge/install/models 全部 HTTP 200；backend 无 panic/FATAL/WARN/ERROR，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线。Computer Use 逐帧检查失败 dossier、确认框、成功 finish inspector 和最终 Overview，未发现裁切、旧失败 CTA、重复活动、无解释 spinner、布局跳变或视觉缺陷；本格无需产品源代码修复。

正式证据为 `/private/tmp/anselm-rig-ep065-flowrun-replay-fixed-20260808/sessions/20260808-021122/evidence/EP-065-flowrun-replay-final-green.md`，API probe 为同目录 `EP-065-flowrun-replay-api-probes.md`，cleanup 为 `/private/tmp/anselm-rig-ep065-cleanup-fixed-20260808/sessions/20260808-021437/evidence/EP-065-flowrun-replay-cleanup.md`。按 `G1/F2/A5/C4/G2` 写入五格，账本 `1010→1015 judgments`，COVERAGE `EP-065=✓✓✓✓✓`，anchors `10/10`，两条批量写账警报经 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-065-flowrun-replay-ledger-reaudit.md` 独立复审并 ack，`alarms.py check` clean(1015)，清册 `848 rows / 197 carried / 0 tombstones`。阈值、三曲线算法和锚点均未调整。

按用户删除授权，独立无 App/no-LLM cleanup 已对 workflow、webhook trigger、handler 和两个 function 精确执行 DELETE `204×5`、后续 GET `404×5`；五条 tombstone、immutable version history、两条 replayed flowrun 及节点/执行审计保留，fixture relations=0，seeded entities 未动。批次十九当时 **45/50**；EP-066 已接续完成并达到 50/50，统一长门禁转由当前前线执行，下一原子前线为 EP-067 `GET /api/v1/flowrun-inbox`。

### 5.2 历史状态快照（EP-064，批次十九 40/50）

**当前前线（2026-08-08 01:53，清册 EP-064 已完成，批次十九 40/50）。** `GET /api/v1/flowruns/{id}/activity` 已按完整产品目的完成验收：真实用户可以在 Scheduler 打开一个完成的 run，看到从 function、handler、agent 到 MCP 的完整 Gantt 活动链，逐节点查看真实 output、排队/执行时长和 execution log；API 以四张执行审计表的真实数据聚合成稳定的 keyset 活动页，空 run、坏游标、非法 limit、幽灵 run 都有诚实边界，不把空结果伪装成错误或把错误伪装成空页。

本格最终真实 session `/private/tmp/anselm-rig-ep064-flowrun-activity-20260808b/sessions/20260808-014240` 使用新 binary、独立数据目录、真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。录屏封口 `475.320000s / 2784x1808`，绑定 Anselm window id `26407`；真实 App 路径为 `Scheduler → ep064-flowrun-activity-four-kinds → completed run → Gantt → agent/MCP Inspector`。画面显示 `Done`、`9.8s`、`queued 0ms`、`ran 9.7s`、`v3 · pinned version`、`5 nodes · Completed 5`，Gantt 中 agent 的真实长执行条与其余短活动按时间比例呈现，节点 output 和 execution log ID 均可达。

REST/SQLite/产品数据事实一致：真实 run `fr_c322e8cac2176f65` 的 activity 按开始时间升序返回四行：`function/fne_a501a1ac92d4c1ec/29ms`、`handler/hcl_ab1653e281c4ac88/0ms`、`agent/agx_2de12b89655ef061/9707ms`、`mcp/mcl_bcb44fd8172592d5/3ms`，每行 `readyAt ≤ startedAt` 且 `status=ok`。`limit=2` 两页无重复、无缺口；trigger-only run `fr_5e645bb73e54d5fa` 返回 `data=[]`；malformed cursor、`limit=0`、unknown run 分别为 `MALFORMED_CURSOR`、`INVALID_REQUEST`、`FLOWRUN_NOT_FOUND`。SQLite 对证同一 run 有 `5` 个 node、四张执行表各 `1` 行；API probe 在 session evidence 的 `EP-064-flowrun-activity-api-probes.json`。

五通道已封存：backend journal `623` 行、frontend journal `17` 行、SSE journal `118` 行、LLM journal `16` 行；entities durable seq 到 `14`、notifications durable seq 到 `22`，run 的 agent/MCP node signal 与 `run_terminal(completed)` 均被观察到且各 stream 单独单调。真实 gateway challenge/install/models 和 `/v1/chat/completions` 全部 HTTP 200，LLM body/response 分别为 `519/26302` bytes；frontend/backend 无 Flutter、Dart、RenderFlex、Unhandled、panic、WARN/ERROR 应用红线。`rig-check.sh` 收台前五通道通过，`rig-down.sh` 后 owned process groups 归零，录屏可读。

本格没有产品源代码修复；第一次 cleanup 命令因 zsh 变量错误只请求了 `/api/v1/` 并全部 404，没有状态改变，随后逐条绝对 URL 重跑成功，属于验收仪器错误，不计产品红。正式证据为 `/private/tmp/anselm-rig-ep064-flowrun-activity-20260808b/sessions/20260808-014240/evidence/EP-064-flowrun-activity-real-session.md`，清理证据为 `/private/tmp/anselm-rig-ep064-cleanup-20260808/sessions/20260808-015120/evidence/EP-064-flowrun-activity-cleanup.md`。

正式绿证据按 `G1/F2/A5/C4/G2` 写入五格，账本 `1005→1010 judgments`，COVERAGE `EP-064=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` 在 gap-too-fast 与 discovery-collapse 独立复核 ack 后为 clean(1010)，清册 `848 rows / 196 carried / 0 tombstones`。两条警报只记录连续写账与本格完整复核，不修改 25 秒阈值、通过速率、发现率算法。

按用户删除授权，独立无 App/no-LLM cleanup `/private/tmp/anselm-rig-ep064-cleanup-20260808/sessions/20260808-015120` 已精确删除本格两个 workflow、trigger、MCP server：DELETE `204×4`，exact GET `404×4`；真实 run、5 条节点和四张执行审计行仍保留，seeded function/handler/agent 未动，deleted tombstone 与 fixture relations=0 已由 SQLite 核对。批次十九当前 **40/50**，未到 50 不跑统一长门禁、不提交；下一原子前线为 EP-065 `POST /api/v1/flowruns/{id}:replay`。

### 5.2 历史状态快照（EP-063，批次十九 35/50）

**当前前线（2026-08-08 01:37，清册 EP-063 已完成，批次十九 35/50）。** `GET /api/v1/flowruns/{id}` 已按完整产品目的完成验收：用户可以从 Scheduler 找到一个真实完成的 run，看到稳定的 run 头、`26 nodes · Completed 26`、分页节点列表，展开剩余节点并打开单节点 Inspector 查看 output 和 execution log；REST 的有界 `{flowrun,nodes,nextCursor}`、同 run keyset continuation、错误语义和 workspace 隔离均与产品画面一致，没有把无界节点历史一次性倾倒到首屏。

本格最终真实 session `/private/tmp/anselm-rig-ep063-flowrun-get-20260808/sessions/20260808-012500` 使用新 binary、独立数据目录、真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。录屏封口 `438.676667s / 2784x1808`，绑定 Anselm window id `26377`，终帧为 `evidence/EP-063-final-frame.png`。真实 App 路径为 `Scheduler → ep063-flowrun-node-pagination → completed run → Show remaining 14 → node25`；画面显示 Manual、Done、pinned version、26/26 completed，node25 Inspector 显示 output `{"ok":true}` 与 Completed execution log。

REST/SQLite/产品数据事实一致：fixture workflow `wf_75f1ef981c05df4b` 生成 run `fr_4174d512cfc9b9ea`，用 `limit=10` 得到 `10+10+6` 三页，节点顺序 `node25..node16`、`node15..node06`、`node05..node01,start`，26 个唯一节点全部 completed，三页 header 都指向同一 run。负向矩阵覆盖 unknown run、malformed cursor、`limit=0`、`limit=51` clamp 和有效 run 的 cross-workspace lookup，分别得到 `FLOWRUN_NOT_FOUND`、`MALFORMED_CURSOR`、`INVALID_REQUEST`、有界 200 和隔离 404；API 原始结果在 session evidence 的 `EP-063-flowrun-get-api-probes.json`，分页原始页和汇总在 rig 根目录。

五通道已封存：backend journal `590` 行、frontend journal `18` 行、SSE journal `124` 行、LLM journal `16` 行；entities durable seq `7..60` 连续单调 54 个，notifications durable seq `16..19` 连续单调 4 个，前端/backend 无未解释应用红线，受管网关 challenge/install/models 全部 HTTP 200。SSE 序列按 stream 独立核对，不把不同 stream 的同数值 seq 误判为重复；本格是 deterministic function workflow，不伪造 chat completion。`rig-check.sh` 收台前五通道通过，`rig-down.sh` 后进程组归零，录屏可读。

本格没有产品源代码修复；首轮 shell 清理循环只因变量名拼写错误在发出 DELETE 前退出，随后显式 URL 重跑并取得正确结果，属于验收仪器命令错误，不计产品红。最终证据为 `/private/tmp/anselm-rig-ep063-flowrun-get-20260808/sessions/20260808-012500/evidence/EP-063-flowrun-get-real-session.md`，API probe 为同目录 `EP-063-flowrun-get-api-probes.json`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-063-flowrun-get-ledger-reaudit.md`。

正式绿证据按 `G1/F2/A5/C4/G2` 写入五格，账本 `1000→1005 judgments`，COVERAGE `EP-063=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` 在 gap-too-fast 独立复审 ack 后为 clean(1005)，清册 `848 rows / 195 carried / 0 tombstones`。复审确认五次写账是同一封口证据的机械登记，不修改 25 秒阈值、通过速率、发现率算法。

按用户删除授权，独立无 App/no-LLM cleanup `/private/tmp/anselm-rig-ep063-cleanup-20260808/sessions/20260808-013308` 已精确删除本格 workflow、function 和隔离验证 workspace：DELETE `204×3`，exact GET `404×3`，主 workspace GET `200`；SQLite 保留 1 条 flowrun、26 条 node、25 条 function execution、各 1 条版本和三条 tombstone，fixture relations=0。清理证据为同 cleanup session 的 `evidence/EP-063-flowrun-get-cleanup.md`。批次十九当前 **35/50**，未到 50 不跑统一长门禁、不提交；下一原子前线为 EP-064 `GET /api/v1/flowruns/{id}/activity`。

### 5.2 历史状态快照（EP-062，批次十九 30/50）

**历史前线（2026-08-08 01:22，清册 EP-062 已完成，批次十九 30/50）。** `POST /api/v1/flowruns` 已按完整产品目的完成验收：用户可以从 Workflow debugger 触发一次手动 run，明确看到 Done、节点完成数、耗时和输出，再通过 `Open run →` 进入 Scheduler durable run inspector；API 侧支持单 trigger 自动选择、多 trigger 显式 `entryNode`，非法入口、未知 workflow、未知字段和 malformed JSON 都 fail-loud，不会静默跑错图或伪造成功。

本格最终真实 session `/private/tmp/anselm-rig-ep062-flowrun-start-20260808/sessions/20260808-005702` 使用新 binary、独立数据目录、真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。录屏封口 `1293.626667s`，绑定 Anselm window id `26340`，终帧为 `evidence/EP-062-final-frame.png`。真实 App 路径为 `Entities → ep062-manual-run → workflow debugger → Trigger → Open run → Scheduler inspector`；最终画面显示 `Manual · 01:12`、`Done`、`107ms · queued 0ms · ran 102ms · v2 · pinned version`，graph 为 `start → echo`，节点为 `Completed 2`，右侧输出为 `accepted: true / source: ui`。

REST/SQLite/产品数据事实一致：单 trigger 正向 run `fr_0f741423bace74b4` 完成并回显 `api-single-fixed`；multi trigger 显式选择 `t2` 的 `fr_764f18dec3c769b1` 只执行 `t2 → b` 并回显 `api-t2-fixed`；真实 UI run `fr_8e32ab2d25642afb` 完成且 pin 到 workflow v2/function v3；同语义 workflow debugger API probe `fr_d7ea4365f1097af6` 也完成。负向矩阵覆盖无 `entryNode` 的多入口、ghost 入口、action 入口、未知字段、缺失/未知 workflow、malformed JSON，分别得到 `FLOWRUN_INVALID_ENTRY`、`INVALID_REQUEST` 或 `WORKFLOW_NOT_FOUND`；完整输入和结果在 `EP-062-flowrun-start-api-probes.json`。

五通道已封存：backend journal `1582` 行、frontend journal `20` 行、SSE journal `87` 行、LLM journal `10` 行；SSE 当前 session `55` 个 durable frame，真实 UI run 的 entities seq `37/39/40` 分别对应 `run_started/function close/run_terminal(completed)`，ephemeral node frame 保持 seq `0`。frontend 无 Flutter/Dart/RenderFlex/overflow/lost-device/unhandled application red line，backend 无 panic/FATAL/ERROR/WARN；受管网关 challenge/install/models 均 HTTP 200，本 workflow 为 function-only，未伪造 chat completion。`rig-check.sh` 收台前五通道通过，`rig-down.sh` 后 owned process groups 归零，录屏经 ffprobe 可读。

本格保留并明确排除两类非产品红观察：最初 shell 写入的 function v1 含字面量 `\\n`，造成 SyntaxError，已用真实 function edit 修复并由 v2/v3 成功 run 证明；Computer Use 对自定义 `AnCodeEditor` 的 `set_value` 只改变 AX 层、未触发 Flutter `onInput`，随后用 Example/empty payload 真实走通 UI，不把工具限制伪报成产品 bug。本格没有产品源代码修复，证据文件、API JSON、UI AX 树和 SQLite 交叉检查均已保存。

正式绿证据为 `/private/tmp/anselm-rig-ep062-flowrun-start-20260808/sessions/20260808-005702/evidence/EP-062-flowrun-start-real-session.md`，API 证据为同目录 `EP-062-flowrun-start-api-probes.json`，最终帧为 `EP-062-final-frame.png`；账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-062-flowrun-start-ledger-reaudit.md`。按 `G1/F2/A5/C4/G2` 写入五格，正式账本 `995→1000 judgments`，COVERAGE `EP-062=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1000)，清册 `848 rows / 194 carried / 0 tombstones`。集中写账触发的 `gap-too-fast` 已由独立复审销账，25 秒阈值、通过速率和发现率算法未改。

按用户删除授权，独立无 App/no-LLM cleanup `/private/tmp/anselm-rig-ep062-cleanup-20260808/sessions/20260808-011934` 已精确删除本格 2 workflow、1 function：DELETE `204×3`，后续 exact GET `404×3`，live workflow list 为空，seeded `greet`、`sync_inventory` 未动；SQLite 保留 2 个 workflow tombstone、1 个 function tombstone、3 个 workflow versions、8 个 flowruns、8 个 function executions，fixture relations=0。清理证据为同 cleanup session 的 `evidence/EP-062-flowrun-start-cleanup.md`。批次十九当时 **30/50**，未到 50 格未跑统一长门禁、不提交；EP-063 已在上方完成。

### 5.2 历史状态快照（EP-061，批次十九 25/50）

**历史前线（2026-08-08 00:54，清册 EP-061 已完成，批次十九 25/50）。** `GET /api/v1/flowruns` 已按完整产品目的完成验收：用户既可以在 Workflow detail 的 Runs cockpit 以 keyset 继续加载历史，也可以在 Scheduler 以 offset 页码浏览完整工作区历史；两种分页共享同一过滤语义，cursor 与 offset 同时出现、非法 offset/status/origin/RFC3339 时间、未知 workflow/trigger 组合都明确失败或诚实返回空集，不会静默切页或伪造状态。

本格最终真实 session `/private/tmp/anselm-rig-ep061-flowruns-20260808/sessions/20260808-003250` 使用新 binary、独立数据目录、真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。录屏封口 `630.583333s / 2784x1808 / 60fps`，终帧为同目录 `evidence/EP-061-final-frame.jpg`。真实 App 路径覆盖 `Entities → ep061-list-workflow → Runs` 的 keyset `20→28`、`Scheduler → ep061-list-workflow` 的 offset `29` 行和第 1/2/3 页、Manual/Webhook 来源筛选、失败 workflow 的 traceback/Replay/AI triage inspector，以及 approval workflow 的 Waiting/Running/Cancelled 状态、approval inspector 和 Cancel run。

REST/SQLite/产品数据事实一致：主列表 workflow 真实产生 `29` 条完成历史（28 manual + 1 webhook）；工作区验收 fixture 的最终历史为 `34` 条，其中 `30 completed / 2 failed / 2 cancelled`，来源为 `31 manual / 3 webhook`。API 探针验证 cursor 与 offset 页无重叠且顺序均为 `(startedAt,id) DESC`，offset 与 cursor 内容一致；`startedAfter`/`startedBefore` 和 completed 时间窗符合左闭右开；failed/running/cancelled/completed 桶、未知复合筛选及所有非法输入均与 handler/store 契约一致。Scheduler 过滤后的页数和空态可解释，失败详情的完整 traceback 在右侧 dossier 可读；approval CTA 在 inspector 下方可达，没有截断、死 loading、状态错配或视觉跳变。

五通道已封存：backend journal `915` 行、frontend journal `17` 行、SSE journal `111` 行（`107` 个 stream frame）、LLM journal `10` 行。notifications durable seq `16..37`、entities durable seq `7..77` 均严格单调；messages stream 已连接且 deterministic workflow 不虚构 durable mutation。frontend 无 Flutter/Dart/RenderFlex/overflow/lost-device/unhandled application red line，backend 无 panic/FATAL/ERROR/WARN；受管网关 challenge/install/models 均 HTTP 200，本格没有 LLM node，故不伪造 completion。`rig-check.sh` 收台前五通道通过，`rig-down.sh` 后 owned process groups 归零。

正式绿证据为 `/private/tmp/anselm-rig-ep061-flowruns-20260808/sessions/20260808-003250/evidence/EP-061-flowruns-real-session.md`，API 证据为同目录 `EP-061-flowruns-api-probes.json`，SSE 汇总为 `EP-061-sse-summary.json`；账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-061-flowruns-ledger-reaudit.md`。按 `G1/F2/A5/C4/G2` 写入五格，正式账本 `990→995 judgments`，COVERAGE `EP-061=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(995)，清册 `848 rows / 193 carried / 0 tombstones`。集中写账触发的 `gap-too-fast` 已由独立复审销账，25 秒阈值、通过速率和发现率算法未改；本格没有产品源代码修复，针对性 Go/Flutter 测试、diff check 和 coverage check 均通过。

按用户删除授权，独立无 App cleanup `/private/tmp/anselm-rig-ep061-cleanup-20260808/sessions/20260808-004956` 已精确删除本格 5 workflow、5 trigger、1 approval、1 deliberate-failure function：全部 DELETE `204`，后续精确 GET `404`，`ep061-` live lists 为空；approval 的 parked fixture 先经 `:kill` 收束，避免残留 draining。SQLite 真相为 workflow tombstones `5`、trigger tombstones `5`、approval/function tombstone 各 `1`、fixture relations `0`，但保留 `34` flowruns、`8` workflow versions、`4` trigger firings；seeded `greet`、`sync_inventory` 和 `演示工作台` 未动。清理证据为同 cleanup session 的 `evidence/EP-061-flowruns-cleanup.md`。批次十九当前 **25/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-062。

### 5.2 历史状态快照（EP-060，批次十九 20/50）

**当前前线（2026-08-08 00:27，清册 EP-060 已完成，批次十九 20/50）。** `GET /api/v1/workflows/{id}/versions/{version}` 已按完整产品目的完成验收：用户可以从 Entities 找到 workflow、进入 Versions tab 看见可读的版本图；REST 的数字版本号和 opaque 版本 ID 都只返回路径 `{id}` 所属 workflow 的 immutable graph，跨父 ID、未知数字、0、负数和未知 opaque ID 都统一给出明确的 `WORKFLOW_VERSION_NOT_FOUND`，不会把另一 workflow 的图渲染到当前上下文。

本格首轮真实 session `/private/tmp/anselm-rig-ep060-workflow-version-20260808/sessions/20260808-001344` 复现并冻结了真实产品红线：workflow A 的 `wfv_9ae3d6a00dc235c5` 经 workflow B 的 URL 仍返回 `200`，响应 `workflowId` 却是 A；数字版本边界当时已正确 404。红证据 `/private/tmp/anselm-rig-ep060-workflow-version-20260808/sessions/20260808-001344/evidence/EP-060-workflow-version-red.md` 永久保留，不计绿。stop-and-fix 新增 `GetVersionForWorkflow(workflowID,versionID)` 父级查询：store 用 `workflow_id + id`，app 保持 `graphParsed` 解码，HTTP opaque 分支不再调用执行器所用的全局 pinned `GetVersion`；同步补 store/app/handler 回归和 workflow/API 文档。既有 scheduler 全局 pinned 读取未改变。

修复后的最终真实 session `/private/tmp/anselm-rig-ep060-workflow-version-fixed-20260808/sessions/20260808-001940` 使用新 binary、独立数据目录、真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。真实 App 路径为 `Entities → Workflow → ep060-fixed-workflow-a → Versions`：header 显示 `v2 / inactive / serial`，Versions 首行自动展开，显示 `v1 → v2`、真实 change reason、`+0 -0` 和完整 trigger graph JSON；v1 仍可见，最终帧没有代码裁切、重叠、死 loading、错误 workflow 名或右岛遮挡。录屏封口 `106.916667s / 2784x1808 / 60fps`，最终帧为同目录 `evidence/EP-060-final-frame.jpg`。

REST/SQLite 事实一致：A `/versions/2` 与 A `/versions/wfv_3312be856281502c` 均 `200`、`workflowId=A`、含 `graphParsed`；B 读取 A opaque ID、B `/versions/2`、A `/versions/0`、`-1`、`999`、`unknown` 均为 `404 WORKFLOW_VERSION_NOT_FOUND`。backend 无 panic/FATAL/ERROR/WARN 或未解释应用错误；frontend 无 `Unhandled exception`、`FlutterError`、RenderFlex/overflow、lost-device 或 Dart error；SSE 三流连接，notifications durable `16,17,18` 严格单调，read-only Versions 路径没有伪造 message/entity durable mutation；LLM tap 的真实 challenge/install/models 均 `200`，本格不虚构 chat completion。`rig-check` 收台前五通道全绿，`rig-down` 后 owned process groups 归零。

独立 cleanup `/private/tmp/anselm-rig-ep060-cleanup-20260808/sessions/20260808-002310` 已按用户授权软删两 workflow 与两 trigger：DELETE `204×4`，后续四个 GET `404`，live workflow/trigger lists 为空；SQLite 保留两条 workflow `deleted_at`、3 条 immutable `workflow_versions`、两条 trigger tombstone，fixture relations=0，seeded `演示对话` 仍唯一对话，cleanup 收台无残留。正式绿证据为 `/private/tmp/anselm-rig-ep060-workflow-version-fixed-20260808/sessions/20260808-001940/evidence/EP-060-workflow-version-final-green.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-060-workflow-version-ledger-reaudit.md`。五级裁决由 `judge.py` 按 `G1/F2/A5/C4/G2` 写入，正式账本 `985→990 judgments`，COVERAGE `EP-060=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(990)，清册 `848 rows / 192 carried / 0 tombstones`。集中写账触发的 `gap-too-fast` 已依据独立复审 ack，25 秒阈值、通过速率与发现率算法未改。批次十九当前 **20/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-061 `GET /api/v1/flowruns`。

### 5.2 历史状态快照（EP-059，批次十九 15/50）

**历史前线（2026-08-08 00:07，清册 EP-059 已完成，批次十九 15/50）。** `GET /api/v1/workflows/{id}/versions` 已按完整产品目的完成验收：真实用户从 Entities 找到 workflow，打开详情的 Versions tab，在 20 条边界看到明确的 `Load more`，加载后得到完整 v22 到 v1 历史；首个版本自动展开、差异可读、分页追加不重复，完成后不留下死的 Load more 控件。

EP-059 专用真实台架 `/private/tmp/anselm-rig-ep059-workflow-versions-20260808/sessions/20260807-235745` 使用独立数据目录和端口，由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。fixture workflow `wf_e6a23f5c4c1e6ad0` 由 trigger `trg_dc40065b733c5085` 驱动，创建后通过 21 次真实 `:edit` 形成 v1..v22；版本页首屏显示 v22..v3，点击 `Load more` 后补齐 v2、v1。最终录像封口 `251.178333s / 2784x1808 / 60fps`，尾帧回看显示 v15..v1，右侧 workflow 面板稳定，无红卡、截断或死控件。

REST/SQLite/UI 事实一致：REST `limit=20` 第一页严格为 `22..3`，`hasMore=true` 且返回 opaque cursor；用该 cursor 的第二页严格为 `2..1`，`hasMore=false`；按数字 `22` 和 opaque version ID 单读都指向 v22。`limit=0` 返回 `400 INVALID_REQUEST`，坏 cursor 返回 `400 MALFORMED_CURSOR`；SQLite 保留全部 22 个 `workflow_versions` 行。构造 fixture 时曾因 zsh 将未加括号的 `$WF:edit` 解释成参数展开而得到错误路由，已改为 URL 编码冒号；这是台架脚本插值失误，不是产品路径，未计作产品红证据。

五通道事实一致：backend 无 panic/FATAL/未解释应用错误；frontend 只有正常 `Dart VM Service` 启动行，无 `Unhandled exception`、`FlutterError`、RenderFlex/overflow/lost-device；SSE 三流均连接，notifications durable `16..37` 严格单调无 gap，messages/entities 在本只读旅程中没有新增 durable 帧；LLM tap 记录真实 challenge/install/models 握手，本格不虚构 chat completion。`rig-check` 收台前五通道全绿，`rig-down` 后 owned process groups 归零，`screen.mov` 经 ffprobe 可读。

正式绿证据 `/private/tmp/anselm-rig-ep059-workflow-versions-20260808/sessions/20260807-235745/evidence/EP-059-workflow-versions-final-green.md`，最终帧同目录 `EP-059-final-frame.jpg`；账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-059-ledger-alarm-reaudit.md`。五级裁决由 `judge.py` 按 `G1/F2/A5/C4/G2` 写入，正式账本 `980→985 judgments`，COVERAGE `EP-059=✓✓✓✓✓`，清册检查为 `848 rows / 191 carried / 0 tombstones`。集中写账打开的 `gap-too-fast` 已由独立录屏、五通道、REST/SQLite、SSE 与最终帧复审后 ack；25 秒阈值、通过速率和发现率算法均未改，`alarms.py check` clean(985)，anchors `10/10`。

按用户删除授权，独立无 App cleanup `/private/tmp/anselm-rig-ep059-cleanup-20260808/sessions/20260808-000634` 已将本格 workflow、trigger 软删：DELETE `204×2`，后续 GET `404×2`，live workflow/trigger 列表为空；SQLite 主行保留 `deleted_at`，22 个版本行保留，fixture relations=0，seeded `演示对话` 未动，收台无残留。批次十九当前 **15/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-060。

### 5.2 历史状态快照（EP-058，批次十九 10/50）

**历史前线（2026-08-07 23:52，清册 EP-058 已完成，批次十九 10/50）。** `POST /api/v1/workflows/{id}:iterate` 已按完整产品目的完成验收：真实用户从 Workflow 行选择 `Edit with AI` 后进入持久 AI 编辑对话，能用自然语言要求修改图，AI 会读取被提及的 workflow、trigger、relations 和 agent，再产生一笔可核对的新 workflow version；空请求和不存在目标都给出明确错误，不创建幽灵 conversation。

EP-058 首轮真实 session `/private/tmp/anselm-rig-ep058-workflow-iterate-20260807/sessions/20260807-230750` 暴露 hosted model 的 `get_trigger`/workflow ops 形状问题和可见失败活动；fixed2 `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed2-20260807/sessions/20260807-232114` 又暴露重复 trigger 调用与原始错误重复展示；fixed3 `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed3-20260807/sessions/20260807-233252` 证明即使 mention 带唯一 trigger ID，模型仍可能首轮发空参 `get_trigger`。三条红链全部保留，不计绿。stop-and-fix 只加入已观测 alias 的窄兼容、唯一证据 trigger ID 修复、canonical `op`/hosted `type` 归一化，以及成功 activity 清理同目标旧失败 stage projection； durable transcript 仍保留真实失败事实，失败实体读取不再重复渲染原始错误。

最终真实 session `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed4-20260807/sessions/20260807-233816` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 Anselm gateway LLM tap。第一次交互输入没有真正进入 answer 槽，产生 `Empty answer`，该观察被保留且不计绿；随后以明确英文意图重新提交，模型只完成一次真实 `edit_workflow`：workflow `wf_3180aae05499c1f9` 从 v1 变为 v2，图为 `entry(trg_0dee30ab43f0ecfa) → summarize(agent ag_87bc026f0b6d1c7c)`。App 最终显示 `Edited`、v2 和三条成功 Activity，没有红卡、retry 或重复 mutation；录屏封口 `571.585000s / 2784x1808 / 60fps`。

五通道事实一致：backend 无 panic/FATAL/ERROR/未解释应用告警；frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled 红线，只有已知 macOS IMK runner 环境行；SSE 三流全连接，durable `messages 1..94`、`entities 7..8`、`notifications 16..19` 单调无 gap，ephemeral delta 保持 `seq=0`；LLM wire 真实 chat responses 全 200，最后一笔 body 与 UI/REST 图完全一致。REST 对证 v2 graph、built-in conversation 和 inactive 状态；负向 whitespace 返回 `400 EMPTY_ITERATE_REQUEST`，missing workflow 返回 `404 WORKFLOW_NOT_FOUND`，两者前后 conversation 数不变。

本格 targeted Go tests、相关 Flutter tests、`flutter analyze`、`git diff --check` 全绿；`rig-check` 收台前五通道全绿。五级裁决已由 `judge.py` 按 `G1/F2/A5/C4/G2` 写入，正式账本 `975→980 judgments`，COVERAGE `EP-058=✓✓✓✓✓`，清册检查为 `848 rows / 190 carried / 0 tombstones`。集中写账打开的 `gap-too-fast` 已以独立复审证据 ack，25 秒阈值与三曲线算法未改，`alarms.py check` clean(980)，anchors 重新校准为 `10/10`。

证据：最终绿证据 `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed4-20260807/sessions/20260807-233816/evidence/EP-058-workflow-iterate-final-green.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-058-ledger-alarm-reaudit.md`。按用户删除授权，独立无 App cleanup `/private/tmp/anselm-rig-ep058-cleanup-20260807/sessions/20260807-235013` 已将本格 conversation、workflow、trigger 软删：DELETE `204×3`，后续 GET `404×3`，live workflow/trigger 列表为空，SQLite 保留 2 个 workflow version、4 条 message、42 个 block，fixture relations=0，seeded `演示对话` 未动，收台无残留。批次十九当前 **10/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-059 `GET /api/v1/workflows/{id}/versions`。

### 5.2 历史状态快照（EP-056，批次十八 50/50）

**历史前线（2026-08-07，清册 EP-056 已完成，批次十八 50/50）。** `POST /api/v1/workflows/{id}:revert` 已按完整产品目的完成验收：用户在 Workflow 的 Versions 页面能看懂版本差异、明确选择历史版本并看到 active 指针切换；回退不删除版本历史、不制造新版本，非法版本号必须给出明确错误。

最终真实 session `/private/tmp/anselm-rig-ep056-workflow-revert-20260807/sessions/20260807-214211` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三条独立 SSE witness、LLM tap 和受管网关。真实 UI 从 v3 依次打开 More actions → Set active，先切到 v2、再切到 v1；每次 header、绿色 active marker 和版本历史立即一致，v3 的 diff 仍可读，未出现跳变、遮挡、截断或把历史版本从界面抹掉。最终录屏 `338.140000s / 2784x1808 / 60fps`，关键帧为 `EP-056-final-v2-active.jpg` 与 `EP-056-final-v1-active.jpg`。

REST/SQLite/SSE 交叉一致：两次真实 UI revert 均返回 `200`；version `999` 与 `0` 均返回 `404 WORKFLOW_VERSION_NOT_FOUND`；最终 active version 为 `wfv_1da2f4946f7dee62`（v1），v1/v2/v3 三行版本历史完整保留，未产生 v4。notifications durable seq `16..20` 单调记录 workflow created/edited/reverted，三流连接和收台无 gap；LLM tap 记录真实 challenge/install/models readiness，不为确定性 revert 伪造模型 completion。

五通道封口：backend journal `459` 行无 panic/FATAL/WARN/ERROR；frontend journal `76` 行仅有已审阅的固定 AXTree tooling pattern，没有 Dart/FlutterError/RenderFlex/overflow/Unhandled/lost-device 运行期红线；ssetap 的 `messages/entities/notifications` 三流均连接并正常 EOF；窗口录制可由 ffprobe 读取，`rig-check` 通过，`rig-down` 后 owned process groups 归零。正式绿证据为 `/private/tmp/anselm-rig-ep056-workflow-revert-20260807/sessions/20260807-214211/evidence/EP-056-workflow-revert-final-green.md`，ledger/alarm 独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-056-workflow-revert-ledger-alarm-reaudit.md`；正式账本 `965→970` 按 `G1/F2/A1/C4/G2` 写入五格绿，anchors `10/10`，`alarms.py check` clean(970)，`gen_coverage.py --check` 为 `848 rows / 188 carried / 0 tombstones`，阈值和算法未改。

统一批次门禁已在 50/50 后一次完成：`make verify` 的 backend/frontend/docs/demo 全绿；backend `mise exec -- go test -count=1 -timeout 20m ./...` 全绿；本批修复涉及的前端定向回归 `79` 项与 `flutter analyze` 全绿；独立黑盒 `make -C backend testend` 全绿（`testend/scenarios 298.841s`）。证据与源码均通过 `git diff --check`、gofmt/仓库格式门禁，未放宽任何警报或裁决阈值。

证据封存后按用户授权用独立无 App cleanup session `/private/tmp/anselm-rig-ep056-cleanup-20260807/sessions/20260807-220655` 删除专用 workflow/trigger：workflow 首次 DELETE `204`、幂等重试 `404`，trigger DELETE `204`，后续对象 GET 均 `404`；SQLite 保留 workflow 的 3 个版本，软删除主行、执行/节点历史保留，fixture relations 为 0，cleanup backend 无红线，收台后无残留进程。批次十八由 **45/50→50/50**；该批收口后的下一原子前线为 EP-057，现已在批次十九第 5 格完成。

### 5.2 历史状态快照（EP-055，批次十八 45/50）

EP-055 `POST /api/v1/workflows/{id}:edit` 首轮暴露旧 viewport 未 fit 和全屏编辑器缺少错误 notice host 两个产品问题；stop-and-fix 后，pristine viewport 会在结构变更后 fit，用户主动变换的 viewport 保持，全屏 graph/editor 路由可见结构化 `WORKFLOW_INVALID_GRAPH`。最终真实 session `/private/tmp/anselm-rig-ep055-workflow-edit-20260807/sessions/20260807-212105` 完成合法保存与 invalid graph 反馈，REST/SQLite/SSE、前端运行期和清理证据均已封存；账本 `955→960` 红、`960→965` 绿，COVERAGE `EP-055=✓✓✓✓✓`，cleanup `/private/tmp/anselm-rig-ep055-cleanup-20260807/sessions/20260807-213318` 无残留。

### 5.2 历史状态快照（EP-050，批次十八 20/50）

**历史前线（2026-08-07，清册 EP-050 已完成，批次十八 20/50）。** `POST /api/v1/workflows/{id}:trigger` 已按完整产品目的完成验收：真实用户从 Scheduler workflow 详情页发现 `Run now`，点击后获得即时执行反馈，能在 Matrix、Runs 和旗舰详情继续追踪同一 run；手动执行不改变 workflow 的 `Inactive` 生命周期，也不伪装成触发器真实 fire。空 body 与带 payload 的手动执行都能收口，错误 payload 被明确拒绝且不会制造幽灵 run。

正式 session `/private/tmp/anselm-rig-ep050-workflow-trigger-20260807/sessions/20260807-180921` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三条独立 SSE witness、LLM tap 和受管网关。真实 App 从 Scheduler Overview 进入 `ep050-manual-run`，页面可见 `Inactive`、`Run now`、最近 7 天统计、Matrix、Runs 与 Triggers；点击 `Run now` 后 toast 显示 `Run started · fr_e87daec34cb74b0a`，统计变为 `Success 100%`，出现绿色 `Manual · 18:12`。第二次合法 payload 执行后 UI 实时出现第二条绿色 `Manual · 18:15`，打开运行详情显示 `Done`、`Completed`、`0ms`、v1 pinned version、一个 completed trigger 节点；最终帧无截断、重叠、空白错误态或遮挡关键操作。

后端/数据真相交叉一致：两次成功请求均为 `202`，flowrun 分别为 `fr_e87daec34cb74b0a` 与 `fr_58e12b1ffac09e2e`；两条 flowrun 均 `status=completed`、`origin=manual`、pin 到 `wfv_fa4de7baee6d78fe`。第二次 `start` trigger 节点结果在 REST 与 SQLite 均原样保留 `{"count":2,"message":"EP050 payload","nested":{"ok":true}}`。触发器仍显示 `never fired`，workflow 仍 inactive。错误请求 `{"payload":"not-an-object"}` 返回 `400 INVALID_REQUEST`，随后列表仍恰有两条 run。

五通道已经封口：录屏 `427.206667s / 2784x1808 / 60fps`；backend `549` 行无应用 panic/WARN/ERROR；SSE `notifications/entities/messages` 三流均连接，entities durable seq `1..4` 严格记录两次 `run_started→run_terminal(completed)`，收台以 EOF 正常断开；frontend `17` 行没有 Dart、FlutterError、RenderFlex、overflow、Unhandled、lost-device 或运行期应用红线，唯一的启动阶段 Flutter runner `Failed to foreground app; open returned 1` 已在 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-frontend-runtime-review.md` 独立归因并保留；LLM tap 只有 readiness，因为本路径是确定性 trigger 节点，不虚构模型 completion。

正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-workflow-trigger-final-green.md`，独立警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-ledger-alarm-reaudit.md`，最终 UI 帧为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-workflow-trigger-final-frame.png`；anchors 重新校验 `10/10` 后按 `G1/F2/A5/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 **910→915 judgments**。五格写入触发的 `gap-too-fast`/`discovery-collapse` 已逐项复审并 ack，25 秒间隔阈值、5% discovery floor 与算法均未修改，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 182 carried / 0 tombstones`。

EP-050 没有源代码修复；真实 session 在交互前 `rig-check` 通过，`rig-down` 后 Flutter/backend/ssetap/llmtap/recorder 进程组归零。批次十八当前 **20/50**；按既定规则未到 50 格不运行统一长门禁、不提交。下一原子前线为 `EP-051 POST /api/v1/workflows/{id}:stage`，本批累计到 50 格后再统一收台、跑完整门禁、审计并提交。

### 5.2 历史状态快照（EP-048，批次十八 10/50）

**当前前线（2026-08-07，清册 EP-048 已完成，批次十八 10/50）。** `PATCH /api/v1/workflows/{id}` 已按完整产品目的完成验收：
真实用户从 Workflow 详情的 Run governance 卡直接编辑并发策略，不需要绕到 API；下拉内五种策略均有完整可读的运行语义，选择后通过既有 meta PATCH 收口，
不创建新版本，失败路径仍由统一错误提示和后端重读负责。wire 值与人类文案明确分离：`buffer_one` 在界面显示为 `Keep latest`，而不是把机器枚举直接丢给用户。

首轮真实 session `/private/tmp/anselm-rig-ep048-workflow-patch-20260807/sessions/20260807-171935` 冻结为红：详情治理卡只有静态 `Concurrency: serial`，
AX 树没有按钮/下拉，用户只能用直接 PATCH 验证后端能力；红证据与录屏永久保留。第一修复 session
`/private/tmp/anselm-rig-ep048-workflow-patch-fix-20260807/sessions/20260807-172937` 已能真实选择策略，但视觉复核发现菜单提示在实际宽度下被省略号截断，仍不计绿。
stop-and-fix 将五条解释压缩到完整可读的短句，并同步中英文 i18n、生成字符串、fixture widget regression 与实体 feature 文档。

最终 session `/private/tmp/anselm-rig-ep048-workflow-patch-fix-20260807/sessions/20260807-173308` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、
frontend console、backend journal、三条独立 SSE witness、LLM tap 和受管网关。真实 App 从 `Entities → Workflow → ep048-workflow-patch` 进入详情，
打开治理卡下拉后完整显示 `Serial / Queue each trigger`、`Skip while running / Drop while running`、`Keep latest / Keep newest pending`、
`Replace current / Cancel current run`、`Run in parallel / Overlap runs`；选择 `Keep latest` 后详情稳定回显该策略，`v1`、图、生命周期、告警和右侧运行面板均无跳变、
裁切、重叠或错误红面。

真实后端记录 `PATCH /api/v1/workflows/wf_a51ce934d1b4c9e1` 为 `200`，随后详情 GET 为 `200`；SSE notifications 收到 durable `workflow.updated` 帧，
seq 单调。SQLite 独立证明最终 wire 值为 `buffer_one`、`active_version_id=wfv_9520bac4b77eae9c` 且版本数仍为 `1`；并发策略改变没有版本 bump。
未知实体负边界与初始直接 PATCH 探针均保留在 session evidence，不将后端能力误当作产品入口证据。

五通道已经封口：最终录屏由 `rig-down` 封存，`backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl` 与 manifest 齐全；启动时 `rig-check` 证明五通道物理归属，
收台后 Flutter/backend/ssetap/llmtap/recorder 进程组全部归零。backend 无应用 `panic/FATAL/ERROR/WARN`，frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled 红线；
启动器的已知 foreground 返回值已单独解释，不冒充 Flutter 错误。此项不触发模型调用，LLM tap 只记录 ready，不伪造 completion 证据。

正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-048-workflow-patch-final-green.md`，红证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-048-red-no-concurrency-affordance.md`，独立警报复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-048-ledger-alarm-reaudit.md`；anchors 重新校验 `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，
正式账本 **900→905 judgments**。五格写入触发的 `gap-too-fast`/`discovery-collapse` 已依红绿分离、完整录屏、五通道 journals、REST/SQLite 和 targeted regression 独立复审并 ack；
25 秒间隔阈值、5% discovery floor 与算法均未修改，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 180 carried / 0 tombstones`。

本格变更已通过 `make gen`、`mise exec -- flutter test test/features/entities/ui/detail/workflow_overview_test.dart`（11 tests）、目标文件 `flutter analyze`、
`go test ./internal/app/workflow ./internal/transport/httpapi/handlers` 与 `git diff --check`。批次十八当前 **10/50**；按既定规则未到 50 格不运行统一长门禁、不提交。
下一原子前线为 `EP-049 DELETE /api/v1/workflows/{id}`，本批累计到 50 格后再统一收台、跑完整门禁、审计并提交。

### 5.2 历史状态快照（EP-045，批次十七 45/50）

**当前前线（2026-08-07，清册 EP-045 已完成，批次十七 45/50）。** `POST /api/v1/workflows` 已按完整产品目的完成验收：
用户在真实 Chat 中提出“复用既有 trigger 创建工作流”的意图后，模型先找到正确 trigger，再以一次 mutation 创建 v1；
workflow 只有一个 trigger 节点、保持 inactive、元数据完整，UI、REST、SQLite、SSE 与受管网关 wire 一致，且不留下失败卡或 retry。

本格首轮红 session `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-152351` 暴露两类台架/产品问题：
Computer Use `type_text` 丢失下划线和部分标点，导致原始输入不能作为绿证据；模型随后把 `nodeId/triggerId` 发成不受支持的
扁平形状并自修。该输入保真问题与产品红证据永久保留，不计绿。

输入修正后第二个红 session `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-153602` 证明产品契约仍有
缺口：模型发出精确的 `nodes`/`edges` 图快照而不是 op 数组，后端正确拒绝，模型重试成功，但真实 UI 留下了
`create_workflow Failed` 与 `Draft unsaved · nothing was created` 红卡。该 session 也永久保留，不计绿。

stop-and-fix 增加了两层受限兼容并同步契约：`add_node` 只接受不冲突的
`nodeId → node.id`、`triggerId → node.ref`（仅 `kind=trigger`）；执行边界另接受顶层同时含 `nodes` 与 `edges` 数组的精确
图快照，将已观察的 `type/triggerId` 确定性映射为 `kind/ref` 并展开为 `add_node`，边展开为 `add_edge`。未知键、缺数组、
规范/别名冲突、非 trigger 使用 `triggerId` 和任意其它对象仍 fail-closed。`create_workflow` schema 改为明确描述规范嵌套
node/edge 形状；补 decoder、Execute、冲突拒绝和字符串化快照回归测试，并同步 workflow domain 与 tools 清册。

最终真实绿 session `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-154617` 由 conductor 托管真实 Flutter App、
Computer Use、窗口录制、frontend console、backend journal、三条独立 SSE witness、LLM tap 和真实受管网关完成。AX 在提交前确认
完整用户消息；模型执行一次 trigger search 和一次 `create_workflow`，没有 `tool execute failed`、没有 retry。稳定态 UI 只显示
`Created`：结果表有 `Name`、`Description`、`Tags`、复用的 `Trigger`、`Inactive (deactivated)` 和 `Version 1`，Activity 只有一条
成功触点，无红卡、裁切、重叠或空 draft。

后端最终事实：workflow `wf_64daa9eefc827154`、version `wfv_78be24cae05bd43f`/v1、`active=false`、`lifecycleState=inactive`；
graph 唯一节点为 `{id:"start",kind:"trigger",ref:"trg_f3b9a6e64e4a68e9}`，edges 为空；trigger `trg_f3b9a6e64e4a68e9`
只出现一次。五通道封口：screen `111.591667s / 2784x1808 / 60fps`；backend 无应用 WARN/ERROR/panic；messages/entities/notifications
三流均连接并有对应 tool/build/`workflow.created`/touchpoint；frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow 应用红线，仅保留
已知 macOS IMK host 噪声；LLM wire 的 proof/chat 请求均经 `https://api.anselm.website`，`rig-check` 通过、`rig-down` 封口且进程归零。

正式证据 `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-154617/evidence/EP-045-workflow-create-final-green.md`，
红证据为同目录的 `EP-045-workflow-create-red.md` 与 `EP-045-workflow-create-red-graph-snapshot.md`；独立复审
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-045-workflow-create-ledger-reaudit.md`。anchors `10/10` 后按 `G1/F2/A1/C4/G2`
写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 **885→890 judgments**；两条统计警报按独立复审 ack，阈值与算法未修改，
`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 177 carried / 0 tombstones`。

批次十七当前 **45/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为
`EP-046 GET /api/v1/workflows`。

### 5.2 历史状态快照（EP-043，批次十七 35/50）

**历史前线（2026-08-07，清册 EP-043 已完成，批次十七 35/50）。** `GET /api/v1/agents/{id}/executions`
已按完整产品目的完成验收：用户能在 Agent Logs 里看到完整执行历史、聚合计数和可展开的输入/输出/provider/model；
从 REST 或其它表面新增的真实执行会在已打开的 Logs 中自动出现，不能要求用户手动刷新，也不能让 Logs 与右侧运行台互相矛盾。

EP-043 首个真实负路径 session `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-143107`
发现未知父 Agent 被错误返回为 `200` 空历史；修复后 session `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-143520`
又捕到真实产品红线：外部新增 18 次执行后右侧运行台已显示 `21 total runs`，但已打开的 Logs 仍停在 `3 Done / 0 Failed`。
两套红证据永久保留，不计入绿判。

本格立即 stop-and-fix：Agent `SearchExecutions` 先校验父实体，未知父返回 `404 AGENT_NOT_FOUND`；`LogListNotifier` 订阅可执行
实体 scope 的 durable `FrameClose`，只把帧当作重取提示，按当前已加载窗口重读 REST 台账与 aggregates，保留仍在窗口内的展开行，
瞬时失败保留最近可信快照，并避开与 keyset load-more 的游标竞态。同步补 app/store/provider 回归测试及 API/domain/frontend 文档。

修复后的真实绿 session `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-144741` 验证：初始 UI 同屏
为 `21 Done / 0 Failed` 与 `21 total runs`；从 REST 真实执行输入 `number=42` 后，不点击刷新，Logs 自动变为 `22 Done`，右岛同步
变为 `22 total runs · last ok 3.6s`，最新行置顶并展开显示真实 execution ID、输入 `42`、输出 `1764`、provider `anselm`、model
`anselm-auto` 和 `Use this input`。REST 分页为 `20+2`、无重叠、aggregates `22/22/0`；`status=failed` 为空但聚合诚实，
非法 status 为 `422 AGENT_EXECUTION_INVALID_STATUS`，未知父为 `404 AGENT_NOT_FOUND`。

五通道封口：录屏 `183.773333s / 2784x1808 / 60fps`；backend `254` 行无应用 WARN/ERROR/panic/fatal 或 4xx/5xx；独立 SSE witness
三流均连接，Agent scope 真实收到 `open → seq=0 delta → durable close`；frontend `18` 行无 Dart/Flutter/RenderFlex/Unhandled/
overflow 应用红线，仅保留 raw journal 中已知的 macOS Flutter launcher foreground 噪声；LLM tap 真实绑定 `https://api.anselm.website`，
proof/chat 均 HTTP 200。`rig-check` 五通道通过，`rig-down` 封口、录屏可读且进程归零。

正式证据 `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-144741/evidence/EP-043-agent-executions-final-green.md`，
独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-043-agent-executions-ledger-reaudit.md`；anchors `10/10` 后按
`G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `875→880 judgments`。`gap-too-fast`/`discovery-collapse` 已依据红绿分离、
五通道 journal、REST/SQLite 与独立复审逐条 ack，阈值与算法未修改；`alarms.py check` clean，`gen_coverage.py --check` 为
`848 rows / 175 carried / 0 tombstones`。

批次十七当前 **35/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为
`EP-044 GET /api/v1/agent-executions/{id}`。

### 5.2 历史状态快照（EP-042，批次十七 30/50）

**当前前线（2026-08-07，清册 EP-042 已完成，批次十七 30/50）。** `GET /api/v1/agents/{id}/versions/{version}`
已按完整产品目的完成验收：用户从真实 Agent 的 Versions 面板读取数字版本或 opaque `agv_` 版本 ID 时，
只能看到该 Agent 自己的版本；跨父版本和不存在的父 Agent 都必须明确拒绝，不能把另一 Agent 的代码伪装成当前版本。

EP-042 首个真实负路径 session `/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-141645`
发现了真实数据边界缺陷：opaque 版本 ID 走了全局查找，错误地让另一 Agent 的 v4 以及未知父 Agent 返回 `200`。
本格立即 stop-and-fix：Agent domain/repository 增加 parent-scoped opaque lookup，app 层先校验父 Agent，数字和 opaque
路径统一使用父级边界；补 store/app 回归测试，并同步 API/domain 文档。红 session 永久保留，不计入绿判。

修复后的真实 session `/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-142043` 验证：
自有数字 v4、opaque v4、自有数字 v1 均为 `200`；跨父数字/opaque v4 均为 `404 AGENT_VERSION_NOT_FOUND`；未知父
数字/opaque 均为 `404 AGENT_NOT_FOUND`；自有未知数字/opaque 均为 `404 AGENT_VERSION_NOT_FOUND`。SQLite 对证 active v4、
版本严格为 `[4,3,2,1]`。Computer Use 逐帧看到 v4→v3、v3→v2 diff，v1 的完整 prompt 与 earliest version，画面无裁切、
重叠、stale row、loading 残留或错误归属。

五通道封口：录屏 `129.010000s / 2784x1808 / 60fps`；backend `196` 行无 panic/fatal/error/warn 红线；独立 SSE witness
三流均连接并正常断开，本只读 GET 无 durable mutation frame；frontend `18` 行无 Dart/Flutter/RenderFlex/Unhandled/
overflow/失联红线；LLM tap 真实绑定 `https://api.anselm.website`，本确定性只读路径只有 ready、没有虚构 completion。
`rig-check` 五通道通过，`rig-down` 后进程归零，红绿 session、日志和关键帧均保留。

正式证据 `/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-142043/evidence/EP-042-agent-version-detail-final-green.md`，
独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-042-agent-version-detail-ledger-reaudit.md`；anchors `10/10` 后按
`G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `870→875 judgments`。集中写账触发的
`gap-too-fast`/`discovery-collapse` 已依据红绿分离、五通道日志、REST/SQLite 交叉证据逐条 ack，阈值与算法未修改，
`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 174 carried judgments / 0 tombstones`。

批次十七当前 **30/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为
`EP-043 GET /api/v1/agents/{id}/executions`。

### 5.2 历史状态快照（EP-041，批次十七 25/50）

**历史前线（2026-08-07，清册 EP-041 已完成，批次十七 25/50）。** `GET /api/v1/agents/{id}/versions`
已按完整产品目的完成验收：用户从真实 Agent 详情进入 `Versions`，能辨认 active v4、按新到旧阅读
v3/v2/v1，展开可读的 v3→v4 与 v2→v3 diff，并把 v1 明确识别为 earliest version；分页、数字版本号、
opaque `agv_` 版本号与不存在边界均返回诚实结果，不把不存在的 Agent 伪装成空历史。

EP-041 首个正确接线的 session `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140230`
发现真实契约缺陷：未知父 Agent 的版本列表返回 `200 {data:[],hasMore:false}`，会把“实体不存在”误导成“实体存在但没有历史”。
本格立即 stop-and-fix：`agentapp.Service.ListVersions` 先 workspace-scoped 查 Agent 主实体，再进入版本分页；补充已知/未知父实体回归测试，
并同步 API/domain 文档。前一条接线错误的 `8806` session `/private/tmp/anselm-rig-ep041-agent-versions-20260807/sessions/20260807-140126`
和上述缺陷红 session 均保留，未混入绿证据；新 binary 在 `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140622`
重新跑完整路径。

正路径 REST 真实返回分页 `[4,3] hasMore=true`、游标页 `[2,1] hasMore=false`，数字/opaque v4 均 200；数字 999、未知 opaque 版本均为
`404 AGENT_VERSION_NOT_FOUND`，未知父 Agent 为修复后的 `404 AGENT_NOT_FOUND`。SQLite 同时确认 active pointer 为 v4、版本严格为 `[4,3,2,1]`，无 v5
或 mutation。Computer Use 逐帧复核 Versions：v4/v3 diff、v1 earliest version 与完整 prompt 均可读，右岛稳定，无裁切、重复、stale row、
loading 残留或错误卡。

五通道封口：绿 session 录屏 `256.180000s / 2784x1808 / 60fps`；backend `320` 行无 panic/fatal/error/warn 红线；独立 SSE witness 三流均连接、
正常断开且本只读 GET 不产生伪造 durable mutation frame；frontend `18` 行无 Dart/Flutter/RenderFlex/Unhandled/overflow/失联红线；LLM tap 真实绑定
`https://api.anselm.website`，本确定性只读路径没有虚构 completion。`rig-check` 五通道全部通过，`rig-down` 后进程归零，绿/红 session、日志和关键帧均保留。

正式证据 `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140622/evidence/EP-041-agent-versions-final-green.md`，
独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-041-agent-versions-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入
`COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `865→870 judgments`。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已用独立复审、红绿分离和五通道日志
ack，阈值与算法未修改，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 173 carried judgments / 0 tombstones`。

批次十七当前 **25/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为
`EP-042 GET /api/v1/agents/{id}/versions/{version}`。

### 5.2 历史状态快照（EP-039，批次十七 20/50）

**历史前线（2026-08-07，清册 EP-039 已完成，批次十七 20/50）。** `POST /api/v1/agents/{id}:iterate`
已按完整产品目的完成验收：用户从 Agent 行菜单进入 `Edit with AI` 后得到可识别的新对话；seed 会话自动
命名并读取当前 Agent 配置，用户的后续要求只产生一次规范 `edit_agent` mutation，新版本立即 active，
Versions 显示可读 diff，修改后的 Agent 立即可执行，不产生重复 mutation、retry 或幻影会话。

真实 session `/private/tmp/anselm-rig-ep039-agent-iterate-20260807/sessions/20260807-134539` 由同一
conductor 托管真实 App、Computer Use、窗口录像、backend、三路独立 SSE witness、frontend console 和
受管网关 tap。真实对话 `cv_3438427f7e802314` 从 `Edit with AI` 开始，标题为
`Help me edit “EP036 Invoice Agent” with AI`；助手先展示 v3 的 name/description/prompt/mount/inputs/
outputs/knowledge，再按用户要求只新增 EP039 receipt 句子，铸造 v4
`agv_1890517a41cdc11b`，并在 UI 中显示 unchanged-fields 表和 `1 touched`。Versions 显示 `v3 → v4`
红绿 diff，v1/v2/v3 历史仍可读；随后真实 invoke 使用同一 Function mount 得到结构化
`{"receipt":"EP039","total":0}`。

负路径空请求只发一次，返回 `400 EMPTY_ITERATE_REQUEST`；未知 Agent 只发一次，返回 `404 AGENT_NOT_FOUND`。
两条负路径前后 conversation 数都为 1，Agent 版本严格为 `[4,3,2,1]`，没有 v5、retry、部分写入或幻影
会话。五通道封口：录屏 `301.048333s / 2784x1808 / 60fps`，三张关键帧保存在 session evidence；backend
`422` 行无 panic/fatal/error/warn 红线；SSE 三流连接且 notifications durable `1..3`、messages `1..35`、
entities `1..10` 连续无 gap；frontend `20` 行无 Dart/Flutter/RenderFlex/Unhandled/overflow/失联红线，
仅有已审计的 macOS launcher/IMK 平台噪声；LLM tap 真实连到 `https://api.anselm.website`，8 次真实
completion 响应均为 HTTP 200；REST、SQLite、UI、SSE 和 wire 对 v4、对话标题和最新 execution
`agx_c7ec1079661121` 一致，`rig-check`/`rig-down` 均封口且无残留。

正式证据 `/private/tmp/anselm-rig-ep039-agent-iterate-20260807/sessions/20260807-134539/evidence/EP-039-agent-iterate-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-039-agent-iterate-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `860→865 judgments`。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已依据独立复审和五通道证据 ack，阈值与算法未修改，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 172 carried judgments / 0 tombstones`。

清册机械核对显示 `EP-040 GET /api/v1/agents/{id}/mount-health` 已在 2026-08-06 完成正式五级裁决，
账本已有 `G1/F2/A1/C4/G2`、COVERAGE 为 `✓✓✓✓✓`，其证据与独立复核均存在；本轮不重复写账或重跑。
批次十七当前 **20/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为
`EP-041 GET /api/v1/agents/{id}/versions`。

### 5.2 历史状态快照（EP-038，批次十七 15/50）

**历史前线（2026-08-07，清册 EP-038 已完成，批次十七 15/50）。** `POST /api/v1/agents/{id}:edit`
已按完整产品目的完成验收：用户对 Agent 提交一次全量 Config snapshot 后，新版本立即成为 active，原有
Function mount、inputs、outputs 和其它配置不会静默丢失；真实 App 收到 lifecycle signal 后能重取详情，
Versions 能展示 `v2 → v3` 的红绿 diff、active 标记和历史，右岛清掉旧版本瞬态 Trace/Result 但保留 Recent。

真实 session `/private/tmp/anselm-rig-ep038-agent-edit-20260807/sessions/20260807-133427` 由同一
conductor 托管真实 App、Computer Use、窗口录像、backend、三路独立 SSE witness、frontend console 和
受管网关 tap。正确的全量请求只铸造 v3 `agv_76bde4aaf3c188ea`，prompt 含明确的 EP038 marker，mount、
inputs/outputs 和 `changeReason` 均保留；UI Overview 显示 `All mounts healthy`，Versions 显示 `+1 -1`
和 `v2 → v3`，v2/v1 历史仍可读。唯一的 `/agents/dit` 404 是台架 shell 插值错误，发生在有效 mutation
之前且没有产生版本变更，已在正式证据中明确排除，不冒充产品路径。

负路径对含未知字段 `wat` 的请求只发一次，返回仓内统一的 `400 INVALID_REQUEST`；之后 REST、SQLite、
Versions 和 active pointer 均仍是 v3，版本严格为 `[3,2,1]`，没有 v4、retry 或部分写入。五通道封口：
录屏 `150.373333s / 2784x1808 / 60fps`，三张关键帧保存在 session evidence；backend `231` 行无
panic/fatal/error/warn；SSE 三流连接且 notifications 仅有正路径 durable `seq=1 agent.edited`，无 gap
和负路径 mutation；frontend `18` 行无 Dart/Flutter/RenderFlex/Unhandled/overflow/失联红线；LLM tap
真实连到 `https://api.anselm.website`，本确定性 REST 格不需要 completion，未虚构模型证据；REST、SQLite、
UI、SSE 和 wire 对版本结果一致，`rig-check`/`rig-down` 均封口且无残留。

正式证据 `/private/tmp/anselm-rig-ep038-agent-edit-20260807/sessions/20260807-133427/evidence/EP-038-agent-edit-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-038-agent-edit-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `855→860 judgments`。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已由独立复审 ack，阈值与算法未修改，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 171 carried judgments / 0 tombstones`。

批次十七历史位置 **15/50**；下一原子前线已由 EP-039 接续。

### 5.2 历史状态快照（EP-037，批次十七 10/50）

**历史前线（2026-08-07，清册 EP-037 已完成，批次十七 10/50）。** `POST /api/v1/agents/{id}:revert`
已按完整产品目的完成验收：用户可以在真实 Agent 详情的 Versions 中辨认 v1/v2、看到 diff 和 active
标记，切换 active 指针；切换后不把旧版本的 Trace/Result 冒充为新版本产出，同时保留 Recent 审计历史。

真实 session `/private/tmp/anselm-rig-ep037-agent-revert-20260807/sessions/20260807-132025` 先通过
REST 构造带明确 v2 diff 的 fixture，再由 Computer Use 在真实 App 中完成 v2→v1；随后在 v2 active 下用
受管网关执行 `subtotal=100,tax=10` 得到 `total=110`，再在结果可见时切回 v1。最终画面显示 v1 active、
v2 历史仍在、Recent 保留最新 9.9s 运行，但右岛没有旧 v2 Trace/Result 残留。故障边界用真实 HTTP
`version=999` 只调用一次，返回 `404 AGENT_VERSION_NOT_FOUND`，active v1 不变且没有 v3/重试。

五通道封口：录屏 `427.071667s / 2784x1808 / 60fps`，关键帧保存于 session evidence；backend `546`
行无 panic/fatal/error/warn；SSE 三流全连接，notifications durable `1..4`、本次 entities `1..10` 单调无 gap，
seq=0 delta 仍为 ephemeral；LLM tap 连接真实 `https://api.anselm.website`，proof/chat 状态均为 200；
SQLite、REST、UI、SSE 和 wire 对 `total=110` 与最终 active v1 一致。frontend 仅有固定格式的 AXTree
旧节点观察器噪声，session-scoped `frontend-ax-review.md` 记录了三秒静置不增长和无 Dart/Flutter/
RenderFlex/Unhandled/overflow 红线；未知格式仍保持 fail-closed。`rig-check` 复核通过，`rig-down` 封口且无残留。

正式证据 `/private/tmp/anselm-rig-ep037-agent-revert-20260807/sessions/20260807-132025/evidence/EP-037-agent-revert-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-037-agent-revert-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `850→855 judgments`。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已由独立复审 ack，阈值未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 170 carried judgments / 0 tombstones`。

批次十七历史位置 **10/50**；下一原子前线已由 EP-038 接续。

### 5.2 历史状态快照（EP-036，批次十七 5/50）

**历史前线（2026-08-07，清册 EP-036 已完成，批次十七 5/50）。** `POST /api/v1/agents/{id}:invoke`
已按完整产品目的完成验收：用户从真实 Agent 详情进入 Invoke，立即看到取消/等待反馈，运行结束后
看到 mounted Function 的工具 trace 与最终 JSON；当另一入口在旧结果仍可见时落下一笔新执行，右岛
会切换到新的 observed run，Recent、trace、Result 不会把旧结果和新执行混在一起。

首轮真实 session 暴露了产品缺陷：外部调用的 trace 已进入右岛，但旧本地结果卡与 Recent 计数仍留在
面板中。stop-and-fix 在 `run_terminal_controller.dart` 增加 durable close 后的账本重取，并在 settled
面板观察到新的顶层 run 时重置旧树、从执行账本收口终态；同步补齐 controller 回归测试和实体面板
文档。最终 session `/private/tmp/anselm-rig-ep036-agent-invoke-20260807/sessions/20260807-131105`
用真实 Flutter App、Computer Use、窗口录像、backend、三路独立 SSE witness、frontend console 和
受管网关 LLM tap 重跑：UI 示例 `0+0` 先完成；随后 REST `400+60` 返回 `total=460`，右岛只呈现
新执行的 `total=460`，Recent 计数从 8 到 9。

五通道封口：录屏 `177.275000s / 2784x1808 / 60fps`，四个关键帧保存在 session evidence；backend
`240` 行无 panic/fatal/error/warn；frontend `17` 行无 Flutter/Dart/RenderFlex/Unhandled 红线；SSE
三流全连接，entities 最终观察运行 durable seq `11..20` 单调无 gap；LLM tap 的 `400/60` 请求和
`460` 流式响应均为 HTTP 200；SQLite 最新执行 `agx_faf49cf4a927835b` 为 `ok / 460 / 8432ms`。
UI、REST、SQLite、SSE、LLM wire 五处真值一致，录像经 `ffprobe` 可读，rig-down 后无残留进程。

正式证据 `/private/tmp/anselm-rig-ep036-agent-invoke-20260807/sessions/20260807-131105/evidence/EP-036-agent-invoke-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-036-agent-invoke-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 `845→850 judgments`。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已复审并 ack，阈值未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 169 carried judgments / 0 tombstones`。

批次十七当前 **5/50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为 `EP-037 POST /api/v1/agents/{id}:revert`；本格明确未覆盖“另一个本地运行仍在飞时并发外部调用”，该边界留给后续 edge 路径，不冒充本格已验证。

### 5.2 历史状态快照（EP-035，批次十六 50/50，统一门禁已通过）

**当前前线（2026-08-07，清册 EP-035 已完成，批次十六 50/50）。** `DELETE /api/v1/agents/{id}` 已按完整产品目的完成验收：真实用户从 Agent 详情的 More actions 进入删除，看到明确的不可逆确认，确认后 Agent 从 active catalog 消失，详情选区回到可用 Overview，关系清空，版本审计仍可读；重复删除不重复清边或发事件。上一格清册 EP-040 的临时错号已保留在历史记录，本段严格使用 `COVERAGE.md` 的机械编号。

真实 session `/private/tmp/anselm-rig-ep035-agent-delete-20260807/sessions/20260807-114742` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录屏、backend、三路独立 SSE witness、frontend console 与受管网关 LLM tap。删除前 `EP034 Meta Edited` 有一条真实 equip 关系，用户确认后 DELETE 返回 204；画面最终回到 Overview，Agent count=46，目标行消失，右侧没有旧详情或空白选中态，关系图为 `0 entities, 0 relations`。此前 Cancel-only preflight 与错误 llmtap 归属的失败尝试均保留在各自 session，不混入绿证据。

逐帧复核保留了一个真实中间状态：右岛首次挂载的标准 `AnCountUp` 在约 0.5 秒内从 0 揭示到 46，期间 rail 的权威徽标已是 46；这不是 DB 计数跳变，最终卡片、REST 和 SQLite 均为 46。该段按 CODEX B1/B3 作为新内容首次出现的有界动效审查，抽帧与判定写在 session evidence，没有只留终帧。

五通道封口：录屏 `325.161667s / 2784x1808 / 60fps`；backend `411` 行无 panic/FATAL/WARN/ERROR，含 relation purge 与 DELETE=204；SSE 三流全连接，notifications durable seq 1 为 `agent.deleted`，messages/entities 本确定性删除路径无 mutation frame，不虚构事件且无 gap/error；frontend `26` 行仅有两条已复核的标准数字节点 AXTree bridge 观测器噪声，未知 AXTree 形状和 Dart/Flutter/RenderFlex/overflow/Unhandled/失联仍硬失败；LLM tap 记录真实受管网关 ready，本格不需要 completion 不虚构模型证据。`rig-check.sh` 操作前通过，`rig-down.sh` 封口录屏且无残留。

正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-035-agent-delete-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-035-agent-delete-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 **840→845 judgments**。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已由独立复审 ack，阈值与算法未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 168 carried judgments / 0 tombstones`。

批次十六现已 **50/50**，统一收台已完成并通过：根目录 `make verify` 全绿（含 backend 完整 `go test ./...`、frontend、docs、demo），完整 testend `mise exec -- go test -count=1 -timeout 20m ./...` 全绿，`make -C backend testend` 全绿；Agent/实体后端专项与 Flutter 实体专项全绿，`gofmt`、`git diff --check`、`gen_coverage.py --check`、`alarms.py check` 全绿，验收台架进程组归零。工作树审计无未解释文件，已按 WRK-093/P15 将本批次代码、测试与工作记录一并固化；下一原子前线为 `EP-036`，不把门禁结果降级成“仅专项通过”。

### 5.2 历史状态快照（EP-032，批次十六 30/50）

**当前前线（2026-08-06，EP-032 已完成，批次十六 30/50）。** `GET /api/v1/agents` 已按完整产品目的完成验收：真实 App 首屏 Agent rail 与 Overview 都显示精确总数 45，真实逐字输入 `alpha` 显示 2，五次真实 Backspace 恢复 45，滚动加载 20/20/5 三页后计数仍为 45，45 个名称无重复。首轮真实 App session `/private/tmp/anselm-rig-ep032-agent-list-input-20260806/sessions/20260806-162636` 抓到真实产品缺陷：UI 把已加载行数 40 当成总数，翻页后跳成 45，冻结为红并保留；不是分页可接受副作用。

stop-and-fix 不改变 N4 JSON body，后端七类实体列表增加 `X-Anselm-Total-Count` 精确过滤总数响应头；前端 `Page.total`、EntityListState、rail badge 和 Overview cards 消费该元数据。代码级复审又补上 durable created/deleted/edited lifecycle 的总数刷新，避免实时增删改后徽标落后于 DB；fixture、ApiClient、实体列表、Overview、rail 和 signal 回归均已补齐。中间 session `/private/tmp/anselm-rig-ep032-agent-list-count-fixed-20260806/sessions/20260806-164204` 因复用数据里的受管 key 仍指向旧 `8805` 而新 tap 为 `8807`，被 D1/channel-5 门禁拒绝报绿，不混入最终证据；最终 session `/private/tmp/anselm-rig-ep032-agent-list-count-fixed-20260806/sessions/20260806-165306` 换用既有 key 端口并由最新 binary 重跑通过。

五通道封口：录屏 `72.431667s / 2784x1808 / 60fps`，终帧 `/private/tmp/anselm-rig-ep032-agent-list-count-fixed-20260806/sessions/20260806-165306/evidence/ep032-final-frame.png`；backend `162` 行、frontend `19` 行、SSE `8` 行、LLM witness `1` 行，应用级 panic/fatal/error/warn/Flutter/Dart/RenderFlex/Unhandled 红线均为零；三路 SSE 全连接并正常 EOF 收台，channel 5 经受管网关 tap，LLM completion 对只读列表不需要且未虚构。REST header 为 `45/2/1/0`，body 无 `total`；SQLite live Agent 为 `45`，REST/SQLite/UI/SSE/wire 与收台进程清零互证。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-032-agent-list-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-032-agent-list-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，正式账本 **820→825 judgments**，COVERAGE `EP-032=✓✓✓✓✓`，两条统计警报按独立复审 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 164 carried judgments / 0 tombstones`。批次十六当前 **25→30 / 50**；未满 50 格，不运行统一长门禁、不提交，下一原子前线为 `EP-033 GET /api/v1/agents/{id}`。

### 5.2 历史状态快照（EP-031，批次十六 25/50）

**当前前线（2026-08-06，EP-031 已完成，批次十六 25/50）。** `POST /api/v1/agents` 已按完整产品目的完成验收：用户从真实 Chat 创建 Agent 后，能得到一个 identity、完整 Config 快照和 v1，名称、描述、tags、prompt 在 UI、REST、SQLite、SSE 与 LLM wire 上一致。首轮真实 App session `/private/tmp/anselm-rig-ep031-agent-create-20260806/sessions/20260806-154305` 抓到真实产品缺陷：托管模型把 `tags` 发成精确 JSON 数组字符串，旧执行边界按 `[]string` 解码失败，App 显示 `Create agent failed` 与 `Draft unsaved · nothing was created`，冻结为红并保留；中间修复 session `/private/tmp/anselm-rig-ep031-agent-create-fixed-20260806/sessions/20260806-155712` 又抓到流式脱敏残留句尾 `)`，继续冻结，不计绿。

stop-and-fix 在 `create_agent` 执行边界加入窄兼容：接受原生 `[]string` 和精确 JSON 数组字符串，拒绝逗号 prose、非字符串数组和非数组值；同时让 `id`/`identifier` 括号的流式分片保持完整，最终整段移除。补 hosted-model shape、非法 tags、完整流式 chunk 边界回归测试与工具说明。最终真实 session `/private/tmp/anselm-rig-ep031-agent-create-final-20260806/sessions/20260806-160242` 由新 binary、真实 App、Computer Use、录屏、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关重跑：首次 create 成功，只产生 `ag_e093c9019b049a4e` 的 v1，最终文案为 `Agent created successfully: EP031 Planner with tags [acceptance, planner].`；模型追加的一次安全 `get_agent` 读取无副作用、无重复 create，明确保留在证据中。

五通道封口：录屏 `157.588333s / 2784x1808 / 60fps`，终帧为 `/private/tmp/anselm-rig-ep031-agent-create-final-20260806/sessions/20260806-160242/evidence/ep031-final-frame.png`；backend `255` 行无应用级 panic/fatal/error/warn；三路 SSE 均连接、无 error，messages durable `1..22`、notifications `1..5` 单调，entities 本切片无 mutation frame 不虚构事件；frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，仅 macOS foreground/IMK 宿主噪声；LLM challenge/install/models/chat completion 全 `200`。REST `201/200/400/401/401/204`、SQLite、UI、SSE 与 wire 互证，收台无残留。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-031-agent-create-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-031-agent-create-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，正式账本 **815→820 judgments**，COVERAGE `EP-031=✓✓✓✓✓`，两条统计警报按独立复审 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 163 carried judgments / 0 tombstones`。批次十六当前 **20→25 / 50**；未满 50 格，不运行统一长门禁、不提交，下一原子前线为 `EP-032 GET /api/v1/agents`。

### 5.2 历史状态快照（EP-030，批次十六 20/50）

EP-030 的完整红绿证据、五级裁决和批次状态保留如下：`GET /api/v1/handler-calls/{id}` 首轮真实 App 抓到前端未请求或呈现后端已有的 `logs`，stop-and-fix 增加详情懒加载与 UI 展示；最终失败行显示 logs/traceback、成功行显示 logs/output。正式证据、独立复审、五通道日志和 `810→815` 账本记录仍以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-030-handler-call-final-green.md` 与 `EP-030-handler-call-ledger-reaudit.md` 为准；以上 EP-031 状态为当前恢复真相。

### 5.2 历史状态快照（EP-029，批次十六 15/50）

EP-029 的完整红绿证据、五级裁决和批次状态保留如下：`GET /api/v1/handlers/{id}/calls` 首轮固定版真实 session 抓到未知 Handler 的 `data.calls=null`，stop-and-fix 在共享 `response.Paged` 边界递归规范化嵌套 nil slice；修复后分页、筛选、aggregates、空列表和 Handler Logs 路径均通过。正式证据、独立复审、五通道日志和 `805→810` 账本记录仍以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-029-handler-calls-final-green.md` 与 `EP-029-handler-calls-ledger-reaudit.md` 为准；以上 EP-030 状态为当前恢复真相。

### 5.2 历史状态快照（EP-028，批次十六 10/50）

EP-028 的完整红绿证据、五级裁决和批次状态保留如下：`DELETE /api/v1/handlers/{id}/config` 修复前真实 session `/private/tmp/anselm-rig-ep028-handler-config-20260806/sessions/20260806-143909` 抓到重复通知；修复 changed 保护后在 `/private/tmp/anselm-rig-ep028-handler-config-20260806/sessions/20260806-144550` 重跑，最终清 config、停 resident、清空后调用 422、未知 Handler 404、重复 DELETE 204/no-op。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-028-handler-config-clear-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-028-handler-config-clear-ledger-reaudit.md`；账本 `800→805 judgments`，COVERAGE `EP-028=✓✓✓✓✓`，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 160 carried judgments / 0 tombstones`。批次十六由 `5→10/50`，下一原子当时为 EP-029。

### 5.2 历史状态快照（EP-027，批次十六 5/50）

**状态修订。** EP-027 `PUT /api/v1/handlers/{id}/config` 已完成 JSON Merge Patch、实例重启、敏感键保留、可选键删除/默认值回落和真实 Chat `update_handler_config` 产品路径。固定 session `/private/tmp/anselm-rig-ep027-handler-config-20260806/sessions/20260806-142114` 录屏 `583.983333s / 2784x1808`；backend `598` 行无应用红线，三流 durable `messages 1..66 / entities 7..8 / notifications 16..30` 单调，严格 Chat 只出现 update 工具；REST/SQLite/UI/secret scan 一致。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-027-handler-config-update-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-027-handler-config-update-ledger-reaudit.md`；anchors `10/10` 后账本 **795→800 judgments**，COVERAGE `EP-027=✓✓✓✓✓`，alarms clean，gen coverage 为 `848 rows / 159 carried judgments / 0 tombstones`。早期 `...dball` 台架 URL 错误和探索性 Chat 越界调用均保留并排除，严格重跑通过；批次十六由 **0→5 / 50**，下一原子为 EP-028。

### 5.2 历史状态快照（EP-026，批次十五 50/50）

**当前前线（2026-08-06，EP-026 已完成，批次十五 50/50）。** `GET /api/v1/handlers/{id}/config` 已按真实配置、未配置、敏感值掩码和未知 Handler 四条边界完成验收。真实 session `/private/tmp/anselm-rig-ep026-handler-config-20260806/sessions/20260806-134441` 由 conductor 托管新 binary、真实 Flutter App、Computer Use、录屏、frontend console、backend journal、三路独立 SSE witness、LLM tap 与受管网关：已配置 Handler 返回 `200`、`configState=ready`、`api_key=********`、region/retries 原值；未配置 Handler 返回 `config=null`、`configState=unconfigured`、`missingConfig=[api_key]`；未知 ID 返回 `404 HANDLER_NOT_FOUND`。App 逐帧显示 configured 的 ready/masked schema 与 unconfigured 的 stopped/missing api_key 状态，无 secret 泄漏、裁切、重叠或视觉跳变。首个配置 PUT 探针因测试命令漏写显式 `-X PUT` 得到 `405`，确认是台架构造错误；补正后产品 PUT 为 `204`，不计产品红，也不降低门禁标准。

五通道封口：录屏 `245.513333s`、`2784x1808`；backend journal 356 行且无 panic/WARN/ERROR，messages/entities/notifications 三流均连接并分别记录预期 durable 帧，LLM challenge/install/models 全 `200`（该确定性 GET 路径没有 completion，不冒充模型证据），frontend journal 无 Flutter/Dart/RenderFlex/Unhandled 应用红线；REST、SQLite、UI、SSE 和敏感值扫描一致，收台无残留。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-026-handler-config-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-026-handler-config-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，正式账本 **790→795 judgments**，COVERAGE `EP-026=✓✓✓✓✓`，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 158 carried judgments / 0 tombstones`。批次十五由 **45→50 / 50**；统一长门禁已通过：anchors/alarms clean、根目录 `make verify` 全绿、`make -C backend testend` `305.314s` 全绿、`testend` 全包 `359.770s` 全绿、Handler 后端专项与实体详情 Flutter `7/7` 通过、gofmt/diff clean，testend 进程组归零；批次已提交 `6ffc44bb`，下一原子前线为 `EP-027 PUT /api/v1/handlers/{id}/config`。

### 5.2 历史状态快照（EP-025，批次十五 45/50）

以下保留 EP-025 当时的完整状态重述；当前执行以前述 EP-026 状态、LOG 最新条目和 COVERAGE 当前行作为真相。

**当前前线（2026-08-06，EP-025 已完成，批次十五 45/50）。** `GET /api/v1/handlers/{id}/versions/{version}` 首轮真实 App 路径冻结为红：A Handler 接受了 B Handler 的 opaque `hdv_...` 版本 ID 并返回 B 的代码，跨父数据泄漏且用户会被错误版本误导。stop-and-fix 增加 parent-scoped repository lookup，数字版本与 opaque 版本详情继续保持同一父 Handler 边界，并补 store/app/transport/black-box 回归与 Handler domain 文档。固定 session `/private/tmp/anselm-rig-ep025-handler-version-get-fixed-20260806/sessions/20260806-133348` 使用新 binary、真实 App、Computer Use、受管网关和五通道台架重跑：A 数字 v1 与自有 opaque ID 均 200，A 读取 B opaque ID、未知数字和未知 opaque 均为 404 `HANDLER_VERSION_NOT_FOUND`，B 自有 opaque ID 仍 200；Versions 画面显示正确 owner 的 `v1 · stopped`、`ready`、active 标识、真实 source/change reason 和完整代码，无错归属、裁切或视觉跳变。首轮红 session `/private/tmp/anselm-rig-ep025-handler-version-get-20260806/sessions/20260806-132936` 永久保留，固定录屏 186.876667s/30MB；backend 无 WARN/ERROR/panic，三路 SSE durable seq 单调，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，受管网关 bootstrap 全 200。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-025-handler-version-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-025-handler-version-ledger-reaudit.md`；anchors 10/10 后按 G1/F2/A1/C4/G2 写入五级裁决，正式账本 785→790 judgments，COVERAGE EP-025=✓✓✓✓✓，alarms.py check clean，gen_coverage.py --check 为 848 rows / 157 carried judgments / 0 tombstones。批次十五由 40→45 / 50；未满 50 格不跑统一长门禁、不提交，下一原子前线为 EP-026 GET /api/v1/handlers/{id}/config。

### 5.2 历史状态快照（EP-024，批次十五 40/50）

以下段落仅保留 EP-024 的当时状态，当前恢复以前一段 EP-025 整体重述、LOG 最新条目和 COVERAGE 当前行作为真相。

**历史前线（2026-08-06，EP-024 已完成，批次十五 40/50）。** `GET /api/v1/handlers/{id}/versions` 已在真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成 22 个真实 Handler 版本的分页、续页、展开和滚动检查。首屏显示 v22→v3 共 20 条，`Load more` 只追加 v2、v1 一次并在终页消失；active v22、最新 diff 与 v1 `earliest version` 均正确，最早版本代码卡可完整滚入视口，无裁切、重叠或异常跳变。REST cursor 续页为 20+2 且无重叠，`limit=0/abc` 为 400 `INVALID_REQUEST`，坏 cursor 为 400 `MALFORMED_CURSOR`；未知父实体按现有集合读取语义返回空集合，单实体读取仍走 not-found。SQLite 证明唯一 fixture 有 22 个 distinct versions、1..22、active=v22、全部环境 ready。真实 session `/private/tmp/anselm-rig-ep024-handler-versions-20260806/sessions/20260806-131758` 录屏 398.341667s/90MB；三路 SSE 全连接且 durable seq 单调，backend 无 WARN/ERROR/panic，frontend 仅已知 macOS 调试宿主噪声、无 Flutter/Dart/RenderFlex/Unhandled 红线，受管网关 challenge/install/models 全 200。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-024-handler-versions-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-024-handler-versions-ledger-reaudit.md`；anchors 10/10 后按 G1/F2/A1/C4/G2 写入五级裁决，正式账本 780→785 judgments，COVERAGE EP-024=✓✓✓✓✓，alarms.py check clean，gen_coverage.py --check 为 848 rows / 156 carried judgments / 0 tombstones。批次十五由 35→40 / 50；未满 50 格不跑统一长门禁、不提交，下一原子前线为 EP-025。

### 5.2 历史状态快照（EP-023，批次十五 35/50）

以下段落仅保留 EP-023 的当时状态，当前恢复以前一段 EP-024 整体重述、LOG 最新条目和 COVERAGE 当前行作为真相。

**当前前线（2026-08-06，EP-023 已完成，批次十五 35/50）。** POST /api/v1/handlers/{id}:iterate 已在真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成 Handler actions → Edit with AI → ask-user → AI edit → v2 完整产品旅程。首轮真实路径暴露 legacy set_methods 被归一为既有 status 的 add_method，后端真实拒绝 method "status" already exists；红 session /private/tmp/anselm-rig-ep023-handler-iterate-20260806/sessions/20260806-124805 与证据永久保留。stop-and-fix 让 edit normalization 读取 active method 名称：既有方法转 update_method，新方法才转 add_method，并强化 edit_handler 描述、补 TestNormalizeHandlerOpsForEdit_SplitsLegacyMethodListByActiveNames。固定 session /private/tmp/anselm-rig-ep023-handler-iterate-fixed-20260806/sessions/20260806-130116 重新由 conductor 托管真实 App、窗口录制、frontend console、backend journal、三路独立 SSE witness 和 LLM tap；最终模型仅发一个 canonical update_method，App 显示 Updated handler · v2、最终说明和 Activity 1 touched，SQLite/REST active 指针为 v2，消息块保留 inspection/ask-user/edit/result 全链。录屏 400.173333s，三路 durable frame 单调且 close 快照与数据库一致，受管网关 challenge/install/models 与 chat completions 全 200，固定路径没有应用级 WARN/ERROR/panic 或 Flutter/Dart/RenderFlex/Unhandled 红线；已知 macOS runner/IMK host 噪声按 fail-closed 规则单独隔离。正式证据 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-023-handler-iterate-final-green.md，session 细节与红证据分别在固定/首轮 session evidence，独立账本复审 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-023-handler-iterate-ledger-reaudit.md；五级裁决 G1/F2/A1/C4/G2 使正式账本 775→780 judgments，anchors 10/10，gap-too-fast/discovery-collapse 按原阈值独立复审并 ack，alarms.py check clean，gen_coverage.py --check 为 848 rows / 155 carried judgments / 0 tombstones。批次十五由 30→35 / 50；未满 50 格不跑统一长门禁、不提交，下一原子前线为 EP-024。

### 5.2 历史状态快照（EP-022，批次十五 30/50）

以下段落仅保留 EP-022 的当时状态，当前恢复以前一段 EP-023 整体重述、LOG 最新条目和 COVERAGE 当前行作为真相。

**当前前线（2026-08-06，EP-022 已完成，批次十五 30/50）。** `POST /api/v1/handlers/{id}:edit` 已在真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成成功与非法 method 编辑路径。真实 Handler `hd_f3d9a96f278672d0` 从 v1 `hdv_98ffb76322048024` 开始，首个真实 Call 让 App 从 `v1 · stopped` 正确刷新为 `v1 · running`；随后 HTTP `:edit` 用 canonical `update_method` 铸造 v2 `hdv_6ff081d3ae49ebf6`，环境 ready 并重启 resident。App 同步显示 `v2 · running`、`ready`、新代码，旧 v1 结果被清掉而 durable Recent 保留；随后真实 Call 返回 `{"edited":true,"revision":"v2"}`，Recent 增至 2。非法 `does_not_exist` 编辑返回 `422 HANDLER_OP_INVALID` 并给出具体 method 缺失原因，版本列表仍只有 v1/v2、active v2、无 v3/调用副作用。最终 session `/private/tmp/anselm-rig-ep022-handler-edit-20260806/sessions/20260806-123828` 录屏 `191.498333s / 2784x1808 / 60fps`；REST/SQLite 对证两次调用钉住不同 resident instance，SSE 三流全连接且 durable seq 无 gap，受管网关 challenge/install/models 全 200，backend/frontend 无未解释应用红线，收台无 conductor 残留。Flutter 启动器唯一 `Failed to foreground app; open returned 1` 已在证据中按“App 随后 resident 且 Computer Use 全部成功”的仪器噪声单独复核，未知错误仍按 fail-closed。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-022-handler-edit-final-green.md`，session 细节证据 `.../evidence/EP-022-handler-edit-green.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-022-handler-edit-ledger-reaudit.md`；五级裁决 `G1/F2/A1/C4/G2` 使正式账本 **770→775 judgments**，anchors `10/10`，两条统计警报按原阈值独立复审并 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 154 carried judgments / 0 tombstones`。批次十五由 **25→30 / 50**；未满 50 格不跑统一长门禁、不提交，下一原子前线为 `EP-023`。

**历史快照（EP-021，批次十五 25/50）。** `POST /api/v1/handlers/{id}:revert` 已完成版本回退成功与非法版本失败路径；首轮真实回退暴露 v1 标题下残留 v2 结果的产品真相红线，stop-and-fix 后 active version 变化会清掉瞬时结果并保留 durable Recent。最终 session `/private/tmp/anselm-rig-ep021-handler-revert-fixed-20260806/sessions/20260806-122413` 显示 v1 running/ready、旧结果消失，随后 v1 Call 成功；REST/SQLite、SSE、录屏、五通道和 10/10 controller tests 已在前一条状态日志中交叉证明，账本为 770，警报 clean。该段仅供追溯，当前恢复以前述 EP-022 状态为准。

**历史快照（EP-020，批次十五 20/50）。** `POST /api/v1/handlers/{id}:restart` 已在最终新构建的真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成成功与失败两条产品路径。首轮成功路径暴露真实产品缺陷：第一次 Handler `:call` 成功并已惰性拉起 resident instance，REST/SQLite 已是 `runtimeState=running`，但实体详情仍停在 `v1 · stopped`；stop-and-fix 在 Handler call 收尾后重新读取 server-owned detail，避免 UI 留在过期运行态。最终 session `/private/tmp/anselm-rig-ep020-handler-restart-fixed-20260806/sessions/20260806-120431` 真实显示首次 Call 后 `v1 · running`、`ready`、`Done`，Restart instance 原地完成且不铸新版本，第二次 Call 的 Recent 由 1 增至 2；REST/SQLite 证明两次调用均成功、同一 active version `hdv_b075d14eefb8e00f`、两次 resident instance ID 分别为 `hdi_51fd8207eeaa0161` 与 `hdi_da984cee7bc1fdf`。负路径用真实未配置必填 `token` 的 Handler 执行 Restart，UI 明确显示 `Handler “ep020_restart_blocked” restart failed · View`，后端返回 `422 HANDLER_CONFIG_INCOMPLETE`，没有伪造实例或调用审计。录屏 `200.308333s / 2784x1808 / 60fps`；SSE notifications durable `handler.restarted ok:true` 为 seq 16，失败为 seq 20..22，连接与收台无 gap；backend/frontend/LLM tap 五通道均归属于同一 manifest，受管网关 challenge/install/models 全 HTTP 200，frontend 的 AXTree bridge churn 已独立标注为 macOS Flutter 调试仪器噪声且未发现 Dart/Flutter/Unhandled/overflow 红线，收台无残留进程。正式证据为 `/private/tmp/anselm-rig-ep020-handler-restart-fixed-20260806/sessions/20260806-120431/evidence/EP-020-handler-restart-green.md`，账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-020-handler-restart-ledger-reaudit.md`；定向 controller 测试 `9/9`、目标 `flutter analyze` 通过，正式账本 **760→765 judgments**，两条统计警报按原阈值独立复审并 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 152 carried judgments / 0 tombstones`。批次十五由 **15→20 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-021`。

**当前前线（2026-08-06，EP-019 已完成，批次十五 15/50）。** `POST /api/v1/handlers/{id}:call` 已在新构建的真实 App、受管 Anselm 网关、Computer Use 和五通道台架上完成成功/失败两条真实路径：成功右岛显示 `Done`、handler stdout、结构化结果和最近调用；失败显示 `Failed`、`HANDLER_CLIENT_CALL_FAILED`、用户 stdout，并将后端 `details.error` 与 Python traceback 以真实换行展示。首轮失败路径发现右岛丢弃结构化 details，第二轮又发现 JSON 转义让 traceback 难读；两次均 stop-and-fix 后用最终 binary 重跑，最终录屏 `/private/tmp/anselm-rig-ep019-handler-call-final-20260806/sessions/20260806-114857/screen.mov` 为 `176.410000s / 2784x1808 / 60fps`。REST/SQLite 证明同一 resident instance、v1 不升版、`1 ok/1 failed` 调用审计、logs/error/traceback 全部落真；SSE entities `open/delta/close` 与 backend 200/502 对齐，LLM challenge/install/models 全 200，frontend/backend 无未解释应用红线，收台无残留进程。正式证据为 `EP-019-green.md`，账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-019-handler-call-ledger-reaudit.md`；正式账本 **760 judgments**，anchors `10/10`，两条警报按原阈值独立复审并 ack，`alarms.py check` clean。批次十五由 **10→15 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-020 POST /api/v1/handlers/{id}:restart`。以下 EP-018 之前的状态段仅作历史快照，以上整体重述为准。

**当前前线（2026-08-06，批次十五进行中）。** 第九批 `TOOL-081..090`、第十批 `TOOL-091..100`、第十一批 `TOOL-101..110` 和第十二批 `TOOL-111..120` 均已完成 **50 / 50** 并提交；`TOOL-121 generate_video`、`TOOL-122 edit_image`、`TOOL-123 animate_image`、`TOOL-124 enroll_voice`、`EP-001 POST /api/v1/functions`、`EP-002 GET /api/v1/functions`、`EP-003 GET /api/v1/functions/{id}`、`EP-004 PATCH /api/v1/functions/{id}`、`EP-005 DELETE /api/v1/functions/{id}`、`EP-006 POST /api/v1/functions/{id}:run`、`EP-007 POST /api/v1/functions/{id}:revert`、`EP-008 POST /api/v1/functions/{id}:edit`、`EP-009 POST /api/v1/functions/{id}:iterate`、`EP-010 GET /api/v1/functions/{id}/versions`、`EP-011 GET /api/v1/functions/{id}/versions/{version}`、`EP-012 GET /api/v1/functions/{id}/executions`、`EP-013 GET /api/v1/function-executions/{id}`、`EP-014 POST /api/v1/handlers`、`EP-015 GET /api/v1/handlers`、`EP-016 GET /api/v1/handlers/{id}`、`EP-017 PATCH /api/v1/handlers/{id}` 与 `EP-018 DELETE /api/v1/handlers/{id}` 均已完成 `G1/F2/A5/C4/G2`，COVERAGE 当前这些 EP 行均为 `✓✓✓✓✓`。正式账本 `/private/tmp/anselm-rig-formal-20260801-3` 为 **755 judgments**，anchors `10/10`；EP-018 的真实删除 session 验证了取消不变、确认文案、详情回 Overview、204→404、版本历史保留、env 回收和 `sandbox.env_deleted`→`handler.deleted` 的五通道一致性；EP-018 写账触发的两条统计警报按原阈值以独立复审记录 ack，`alarms.py check` clean。批次十三和批次十四均已完成 **50 / 50** 并通过此前的统一长门禁、完整 testend、警报复核和工作树审计；批次十五当前 **10 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-019 POST /api/v1/handlers/{id}:call`。默认 `~/.anselm-rig` 中历史错路由记录只作审计，不作为本战役水位。

`EP-016 GET /api/v1/handlers/{id}` 的真实 App session `/private/tmp/anselm-rig-ep016-handler-get-20260806/sessions/20260806-100548` 验证了 Handler 详情的完整用户目的：Computer Use 画面同时显示名称、v1、stopped、unconfigured、description、activeVersion、Python 3.12、必填 sensitive `api_key`、默认 `region`、`ping` 方法和 source；REST/SQLite 交叉证明 active version、configState、runtimeState、missingConfig、schema 和未知 ID 404 一致。封口录像 `292.240000s / 2784x1808 / 60fps`、稳定截图、messages/entities/notifications 三路 SSE（durable entities `7..8`、notifications `16..20`，无 gap）、backend journal、frontend console、LLM tap 均来自同一 manifest；清理 DELETE=204 后 GET=404，SQLite 仅保留软删 handler/version 审计且 env 已回收。正式证据为 `evidence/EP-016-green.md`，独立警报复审为 `evidence/EP-016-alarm-reaudit.md`；五级裁决已将账本 **735→740 judgments**，批次十四由 **45→50 / 50**。

`EP-017 PATCH /api/v1/handlers/{id}` 的首轮真实 App 画面冻结为红：Handler Overview 只有只读 description，完全没有 tags 入口，用户无法完成“维护 Handler 元数据”的目的。stop-and-fix 将 Handler 元数据接入与 Function/Workflow 一致的 `AnKv` 编辑面：description 支持空值起编辑，tags 支持 Add/remove；PATCH 成功或失败后都重读 canonical detail，`HANDLER_INVALID_NAME` 映射为具体本地化错误。首轮绿 session `/private/tmp/anselm-rig-ep017-handler-patch-20260806/sessions/20260806-105636` 证明了该 surface，但随后同类复查发现 description/tags 保存失败仍错误复用“名称保存失败”文案；stop-and-fix 已补齐 `metaSaveFailed` 双语文案，并同步 Function/Workflow 的同类 catch/invalidate 路径。新 binary 的最终真实 Computer Use session `/private/tmp/anselm-rig-ep017-handler-patch-20260806/sessions/20260806-111449` 从空 description/tags 开始真实键盘输入并 Enter 提交，Escape 收束 tag editor；最终画面显示 `rechecked metadata`、`recheck-tag`、`v1 · running`、`ready`，无跳变、错误卡或假重启。REST/SQLite 证明最终 meta、单一 `hdv_...` v1、resident `bump` 可继续执行；负路径保留非法名称 400 `HANDLER_INVALID_NAME` 与未知 ID 404。新录屏 `159.730000s / 2784x1808 / 60fps`；三路 SSE 已连接，notifications durable `1..3` 单调无 gap，frontend 无未解释 Flutter 红线，llmtap 通过受管网关线缆；最终证据为 `sessions/20260806-111449/evidence/EP-017-recheck-green.md`，独立警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-017-recheck-ledger-reaudit.md`。五级裁决已将账本 **745→750 judgments**，批次十五仍为 **5 / 50**；未满 50 格不跑统一长门禁、不提交，下一原子前线为 `EP-018 DELETE /api/v1/handlers/{id}`。

`EP-007 POST /api/v1/functions/{id}:revert` 的真实产品 session `/private/tmp/anselm-rig-ep007-functions-20260806/sessions/20260806-060152` 完成 v2→v1 回退：Computer Use 在 Versions 面板的 `Set active` 菜单执行真实回退，UI 保留 v1/v2 历史、顶部 active 状态和右侧运行结果均切到 v1；REST 带参数执行返回 `rest-v1`/`version=v1`，非法 v99 返回 `FUNCTION_VERSION_NOT_FOUND` 且 active pointer 不变。SQLite 的 active/version/execution/notification 真相与 notifications 的 `function.reverted` durable 帧一致；三路 SSE、backend、frontend console、LLM tap 和录屏均由同一 manifest 归属。清理 session 真实 DELETE=204、GET=404、live list 为空，SQLite soft-delete 与 `function.deleted` 也对齐。Computer Use `set_value` 绕过编辑器回调、坐标输入造成的中间非法 JSON 被明确排除在绿证据外并记入仪器限制；未发现产品代码红线。正式证据为 `evidence/EP-007-function-revert.md`，警报复审为 `evidence/EP-007-ledger-alarm-reaudit.md`。

`EP-008 POST /api/v1/functions/{id}:edit` 的真实 App session `/private/tmp/anselm-rig-ep008-functions-20260806-fixed3/sessions/20260806-064400` 完成按名称定位已有 Function、只改返回版本标记 v1→v2、保留 value、只调用一次 `edit_function` 的用户目的；最终 UI 只有一张 `Updated function · v2` 活动卡，环境为 ready，助手正文无 opaque Version ID 或 `the requested item`/`the referenced item` 占位，也没有错误卡。五通道证据齐全：录屏 `174.058333s / 2784x1808 / 60fps`；messages/entities/notifications durable seq 分别 `1..42`、`1..8`、`1..9` 单调；LLM tap 20 个响应全 HTTP 200；backend/frontend 无未解释应用红线；REST/SQLite 证明恰有 v1/v2 两个版本、active 为 v2、v1 未变、执行数为 0。空 ops 返回 200 且只重建 env、不铸 v3；畸形 `ops` 在修复后返回 422 `FUNCTION_OP_INVALID` 并在 mutation 前保持真相不变。首轮真实 App 的 Version ID 占位泄漏与 fixed2 的畸形 ops 500 红证据均保留，分别修复了跨 chunk 脱敏和 `ParseOps` 结构化错误映射，补测试与领域文档后以 fixed3 新 binary 重跑。正式证据为 `evidence/EP-008-green.md`，警报复审为 `evidence/EP-008-ledger-alarm-reaudit.md`；Function 与内置 conversation 已真实 DELETE=204 清理。该格已完成五级裁决，下一格为 `EP-009`。

`EP-009 POST /api/v1/functions/{id}:iterate` 的真实 App session `/private/tmp/anselm-rig-ep009-functions-20260806-fixed3/sessions/20260806-070454` 先保留了 generic opening/title 的红证据，再在 fixed3 新 binary 上完成 stop-and-fix 后重跑：Entities rail 选中真实 Function，`Edit with AI` 发出包含 Function 名称的非空请求，chat rail/header 均显示可识别标题，助手读取同一个 Function 并进入可继续编辑的 composer；没有 retry、第二个 conversation 或隐藏 mutation。修复将前端固定请求改为带实体名的本地化文案，后端同时拒绝空白请求并补 whitespace regression；REST/SQLite 证明 mention snapshot、touchpoint、tool call/result 和 conversation title 一致，未知 Function、空/空白请求和 malformed JSON 均在建会话前拒绝。
五通道证据齐全：录屏 `408.985000s / 2784x1808 / 60fps`；messages/entities/notifications durable seq 分别 `1..18`、`1..2`、`1..8` 单调，ephemeral delta 为 seq `0`；LLM tap 12 个响应全 HTTP 200；backend 无 panic/FATAL/WARN/ERROR，frontend 无 Dart/Flutter/runtime 红线。唯一重复的精确 `accessibility_bridge.cc` AXTree 旧节点提示由 session-scoped `evidence/frontend-ax-review.md` 明示为 Computer Use tooling noise，未知 AX 格式仍硬失败；清理已验证 Function 与 conversation DELETE=204、GET=404。正式证据为 `evidence/EP-009-green.md`，账本复审为 `evidence/EP-009-ledger-alarm-reaudit.md`；五级裁决已将正式账本由 **700→705 judgments**，COVERAGE `EP-009=✓✓✓✓✓`，批次十四由 **10→15 / 50**，下一原子前线为 `EP-010 GET /api/v1/functions/{id}/versions`。

`EP-010 GET /api/v1/functions/{id}/versions` 的真实 App session `/private/tmp/anselm-rig-ep010-functions-20260806/sessions/20260806-072203` 构造 21 个真实版本，验证 Versions 页面首屏 20 条 `v21→v2`、cursor 续页唯一返回 v1、active 标识、真实 change reason、代码 diff 和最早版本展开。Computer Use 逐帧确认 v21 默认展开显示 `v20 → v21`、`+1 −1`，加载更多后 v1 显示 `v1 · earliest version` 与完整代码；没有裁切、错位或不可解释状态跳变。REST 首页/续页与 UI 完全一致，`limit=0/abc` 返回 `INVALID_REQUEST`，坏 cursor 返回 `MALFORMED_CURSOR`；删除后主实体 404、列表移除，版本历史按 API 审计约定保留。
五通道证据为 `evidence/EP-010-green.md`、三张稳定截图和封口 `screen.mov`：录像 `456.258333s / 2784x1808 / 60fps`；messages/entities/notifications 三流各连接，entities durable `1..42`、notifications durable `1..85` 单调，entities delta 保持 seq `0`；backend 无 panic/FATAL/WARN/ERROR，frontend 无 Flutter/Dart/Unhandled/连接错误；llmtap 真实记录 proof challenge、install、models 全 HTTP 200，本旅程没有模型调用，未将 recorder ready 冒充 completion。正式账本由 **705→710 judgments**，`EP-010=✓✓✓✓✓`；独立警报复审为 `evidence/EP-010-ledger-alarm-reaudit.md`，anchors `10/10`，`alarms.py check` clean。批次十四由 **15→20 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-011 GET /api/v1/functions/{id}/versions/{version}`。

`EP-011 GET /api/v1/functions/{id}/versions/{version}` 首轮真实 App session `/private/tmp/anselm-rig-ep011-functions-20260806/sessions/20260806-073520` 发现并冻结跨父 opaque version ID 泄漏：A 读取 B 的版本 ID 错误返回 B；代码审查同时发现显式版本执行也缺少 function parent 约束。stop-and-fix 增加 parent-scoped repository lookup，并让 opaque 版本详情和 `:run` 共用该边界；补 store/app/transport/black-box 回归与 API/domain 文档。fixed session `/private/tmp/anselm-rig-ep011-functions-20260806-fixed/sessions/20260806-074225` 用新 workspace 和 A/B fixture 重跑：真实 Flutter Versions 页面显示 v2 active、真实 change reason、`+1 −1` diff，v1 可展开并显示 `earliest version` 与完整旧代码；无错归属、截断或视觉跳变。
五通道交叉核验：A 的 v1/v2 数字版本、自有 v2 opaque ID、B 自有 opaque ID 均 200；A 读取 B opaque ID 与未知 ID 均为 404 `FUNCTION_VERSION_NOT_FOUND`；A 显式 v1 run 返回 owner A。清理 DELETE A/B=204，随后 GET=404；SQLite 保留 2 条 soft-deleted function、3 条版本和 1 条执行审计。录屏 `284.375s / 2784x1808 / 60fps`，messages/entities/notifications 各连接一次，entities durable `1..6`、notifications `1..14` 单调且 delta=0；backend/frontend 无未解释应用红线；llmtap proof/install/models 全 HTTP 200，本 deterministic 路径没有 completion，未把 ready 冒充模型调用。正式证据为 `evidence/EP-011-green.md`，账本复审为 `evidence/EP-011-ledger-alarm-reaudit.md`；正式账本 **710→715 judgments**，批次十四由 **20→25 / 50**，下一原子前线为 `EP-012 GET /api/v1/functions/{id}/executions`。

`EP-012 GET /api/v1/functions/{id}/executions` 的首轮真实 App session `/private/tmp/anselm-rig-ep012-functions-20260806/sessions/20260806-075245` 冻结为红：真实 Function 产生 22 条执行（18 success、4 failed），REST aggregates 已是 `18/4`，但 Overview 只显示最近 5 条推导出的 `5 today`，而 Logs 行把 UTC 时间直接显示给本地用户，分别造成总量错误和时间跳变。stop-and-fix 将执行聚合补成 `totalCount` 并贯通 function/handler/agent/mcp store、domain、API contract 和前端 snapshot；时间格式统一转本地时区；同步双语文案、生成物、回归测试与 API/domain 文档。
修复后的真实 App session `/private/tmp/anselm-rig-ep012-functions-20260806-fixed/sessions/20260806-080821` 重跑同一产品目的：Overview 显示 `22 total runs`，Logs 显示 `18 Done`/`4 Failed` 与本地 `2026-08-06 08:10`，失败行展开后可见 execution ID、触发方式、版本、输入、错误、耗时和本地时间，Load more 后 22 行全部可达，无错误卡、重复活动或视觉跳变。五通道封口为 `screen.mov` `258.726667s / 2784x1808 / 60fps`、SSE 三流已连接且 durable seq 单调（entities `1..46`，notifications `1..5`，messages 本路径无 durable 消息）、llmtap 10 条 bootstrap/proof/install/models 记录、backend/frontend 无 panic/FATAL/WARN/ERROR/Flutter/Dart/Unhandled 红线；SQLite 保留 22 条执行审计，Function DELETE=204 后 GET=404，live function 为零。正式证据为 `evidence/EP-012-green.md`，警报复审为 `evidence/EP-012-ledger-alarm-reaudit.md`；正式账本 **715→720 judgments**，批次十四由 **25→30 / 50**。列表接口按契约不带每条 execution 的 `logs`，当前 UI 尚未调用单次详情接口补取该字段；这是 EP-013 的明确前线，不把“聚合与分页已正确”冒充为“单次详情已完成”。下一原子前线为 `EP-013 GET /api/v1/function-executions/{id}`。
修复后的真实 App session `/private/tmp/anselm-rig-ep012-functions-20260806-fixed/sessions/20260806-080821` 重跑同一产品目的：Overview 显示 `22 total runs`，Logs 显示 `18 Done`/`4 Failed` 与本地 `2026-08-06 08:10`，失败行展开后可见 execution ID、触发方式、版本、输入、错误、耗时和本地时间，Load more 后 22 行全部可达，无错误卡、重复活动或视觉跳变。五通道封口为 `screen.mov` `258.726667s / 2784x1808 / 60fps`、SSE 三流已连接且 durable seq 单调（entities `1..46`，notifications `1..5`，messages 本路径无 durable 消息）、llmtap 10 条 bootstrap/proof/install/models 记录、backend/frontend 无 panic/FATAL/WARN/ERROR/Flutter/Dart/Unhandled 红线；SQLite 保留 22 条执行审计，Function DELETE=204 后 GET=404，live function 为零。正式证据为 `evidence/EP-012-green.md`，警报复审为 `evidence/EP-012-ledger-alarm-reaudit.md`；正式账本 **715→720 judgments**，批次十四由 **25→30 / 50**。列表接口按契约不带每条 execution 的 `logs`，前端详情懒加载路径留给下一格。

`EP-013 GET /api/v1/function-executions/{id}` 的真实 App session `/private/tmp/anselm-rig-ep013-functions-20260806/sessions/20260806-082436` 完成单执行详情闭环：列表真实返回 2 条与 `1 ok/1 failed` aggregates 且不带 logs；展开 Function 的 Logs 行后，前端调用单详情 GET，成功执行显示 input/output/logs/elapsed/time，失败执行显示 traceback 与 logs；未知 execution ID 返回 404 `FUNCTION_EXECUTION_NOT_FOUND`。这是对 EP-012 明确边界的 stop-and-fix：轻列表不膨胀，详情不再空白或假成功。五通道封口为 `screen.mov` `346.728333s / 2784x1808`，SSE 三流连接并记录 run/error/delete 帧，llmtap proof/install/models 全 200，frontend 无 Flutter/Dart/Unhandled/AXTree 红线，backend 无 panic/FATAL；两个临时 Function DELETE=204 后 live list 为空，SQLite `live_functions=0/deleted_functions=2/execution_rows=2`。正式证据为 `evidence/EP-013-green.md`，账本复审为 `evidence/EP-013-ledger-alarm-reaudit.md`；正式账本 **720→725 judgments**，批次十四由 **30→35 / 50**。下一原子前线为 `EP-014 POST /api/v1/handlers`。

`EP-014 POST /api/v1/handlers` 的真实 App session `/private/tmp/anselm-rig-ep014-handlers-20260806-compat9/sessions/20260806-093450` 先经历多轮红证据：托管模型返回的 legacy Handler op 形状并非单一 canonical 协议，必须在后端做有限、可审计的兼容翻译，不能把 Function 的 `set_code` 语义误当 Handler 成功。compat8 绿路径又暴露一个产品视觉红线：助手正文脱敏后把不可用的 ID 表格行替换为空行，Flutter 表格因此隐藏了真正的 `ping` 方法；stop-and-fix 改为物理移除该行，并补 durable close 与流式路径回归，compat9 新 binary 才重新判绿。
最终 Computer Use 画面明确显示 `Handler ep014compat 已创建完成`、名称、Python 3.12、`ping` 无输入且返回 `{pong: true}`、Init 参数无、版本 v1；没有 opaque ID、空表格断行、retry 或错误卡。真实 REST/SQLite 交叉核验为 create `201`、GET 的 env/config ready 且 runtime stopped、未知字段 `400 INVALID_REQUEST`、真实 `:call` 返回 `pong=true`、calls 聚合 `1 ok/0 failed`，清理 DELETE `204` 后 live GET `404`；版本、env 和调用审计按约保留。五通道封口录屏 `189.793333s` 可读，SSE 三流 durable seq 单调且无 gap，llmtap 全 HTTP 200，backend/frontend 无未解释应用红线。正式证据为 `evidence/EP-014-green.md`，警报复审为 `evidence/EP-014-alarm-reaudit.md`；正式账本 **725→730 judgments**，批次十四由 **35→40 / 50**，`anchors 10/10` 与 `alarms.py check clean` 均已复核。未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-015 GET /api/v1/handlers`。

`EP-015 GET /api/v1/handlers` 的主真实 App session `/private/tmp/anselm-rig-ep015-handlers-20260806/sessions/20260806-094604` 构造 44 个真实 Handler 加 seed 行，验证 Entities rail 的 `20+20+5` cursor 续页、最终 45 行、顺序无重漏和 `order_desk` 边界；Computer Use 真实输入 `ep015-handler-3` 得到 10 条 `39→30`，独立空输入 session `/private/tmp/anselm-rig-ep015-handlers-20260806/sessions/20260806-095453` 真实输入 `ep015-no-such-handler` 显示明确的 `No entities match your search.`，没有把空态伪装成加载失败。REST 同时验证 `20+20+5`、search、empty、`limit=0` 的 `400 INVALID_REQUEST`；清理 DELETE 44 个临时行均为 204、搜索为空、已删 GET=404。SQLite 最终 `handlers_total=45/live=1/ep015_deleted=44`，44 个版本保留，临时 env 已回收。五通道证据包括三流独立连接、主 session entities `7..94` / notifications `16..147` 无 gap、LLM bootstrap 全 200、backend/frontend 无未解释应用红线和三份 ffprobe 可读录屏；`set_value` 造成的隐藏输入串接被单独归类为 Computer Use 仪器限制，不进入绿判。正式证据为 `evidence/EP-015-green.md`，空态补证为 `evidence/EP-015-empty-search.md`，警报复审为 `evidence/EP-015-alarm-reaudit.md`；正式账本 **730→735 judgments**，批次十四由 **40→45 / 50**。未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-016 GET /api/v1/handlers/{id}`。

邻仓 `/Users/sunweilin/Developer/Anselm-API-Serve` 的 I2V 修复提交 `0d06f6e58615fec2fd04e3c15d16aea2edaf4aef` 已经生产 CI/CD 成功部署：CI `31029509745`、deploy `31029785594` 均全绿，公网 `healthz` 返回 `200 {"status":"ok"}`，未带设备证明的 `/v1/models` 返回预期 `401 DEVICE_PROOF_REQUIRED`。部署只证明服务可用，不替代产品验收；真实受管网关随后明示 I2V 能力，才启动本次 App 轮次。

`EP-004 PATCH /api/v1/functions/{id}` 在真实 App 中完成无效名称拒绝、有效名称保存、刷新后 canonical truth 与 fixture 恢复。旧实现把后端 `400 FUNCTION_INVALID_NAME` 静默当成成功并退出编辑态；stop-and-fix 让 inline editor 只在异步 PATCH 成功后退出，失败保留 draft、保持编辑态，并用完整可读的本地化规则提示 `Lowercase; a-z 0-9 - _; 1–64.`。真实 session `/private/tmp/anselm-rig-ep004-functions-20260806/sessions/20260806-044310` 记录了 UI 红/绿/恢复路径：无效 PATCH `400`、有效 PATCH `200`、恢复 PATCH `200`；notifications durable seq `1..2` 与侧栏/详情最终名称一致。独立台架校准 session `/private/tmp/anselm-rig-ep004-functions-20260806/sessions/20260806-044956` 由同一 conductor 启动真实 backend、三路 SSE witness、Flutter runner 与 LLM tap，`llm.jsonl` 的 `event=ready` 真实证明 recorder 已在线并绑定 `https://api.anselm.website`；该 deterministic journey 没有模型调用，因此不伪造 request/response。五级正式证据为 `sessions/20260806-044956/evidence/ep-004-functions-patch-formal.md`，账本警报复审为 `ep-004-ledger-reaudit.md`。
`EP-005 DELETE /api/v1/functions/{id}` 在真实 App 中先发现并修复确认文案红线：旧文案只说实体会被移除，没有说明不可撤销；修复为双语 active-catalog removal + irreversible consequence，并由真实绿 session `/private/tmp/anselm-rig-ep005-functions-20260806/sessions/20260806-050031` 重跑。Computer Use 通过实体 rail 的 More actions 打开确认框并只确认一次；录屏 `209.958333s / 2784x1808 / 60fps`，固定确认帧与删除后 Overview 帧已封存。后端 DELETE `204`，REST 回读 `404 FUNCTION_NOT_FOUND`、搜索为空、live list 44 条不含目标；SQLite 保留 `deleted_at` 与 v1 审计，环境、执行记录和关系边清除。notifications durable seq `1..2` 严格为 `sandbox.env_deleted` → `function.deleted`，三路 SSE 已连接，backend 无应用 WARN/ERROR/panic/FATAL；frontend 仅两条静态、5 秒不增长的已知 macOS AXTree 观察器噪声，无 Flutter/Dart/RenderFlex/Unhandled 红线；deterministic 删除路径的 LLM tap 只记录真实 upstream recorder `ready`，不冒充模型调用。正式证据为 `evidence/EP-005-formal-acceptance.md`，警报复审为 `evidence/ep-005-ledger-alarm-reaudit.md`。第一次未 export `RIG_HOME` 的五格误写默认账本已保留审计并清警，正式账本只用显式根重放；下一原子前线为 `EP-006`。
`EP-005 DELETE /api/v1/functions/{id}` 在真实 App 中先发现并修复确认文案红线：旧文案只说实体会被移除，没有说明不可撤销；修复为双语 active-catalog removal + irreversible consequence，并由真实绿 session `/private/tmp/anselm-rig-ep005-functions-20260806/sessions/20260806-050031` 重跑。Computer Use 通过实体 rail 的 More actions 打开确认框并只确认一次；录屏 `209.958333s / 2784x1808 / 60fps`，固定确认帧与删除后 Overview 帧已封存。后端 DELETE `204`，REST 回读 `404 FUNCTION_NOT_FOUND`、搜索为空、live list 44 条不含目标；SQLite 保留 `deleted_at` 与 v1 审计，环境、执行记录和关系边清除。notifications durable seq `1..2` 严格为 `sandbox.env_deleted` → `function.deleted`，三路 SSE 已连接，backend 无应用 WARN/ERROR/panic/FATAL；frontend 仅两条静态、5 秒不增长的已知 macOS AXTree 观察器噪声，无 Flutter/Dart/RenderFlex/Unhandled 红线；deterministic 删除路径的 LLM tap 只记录真实 upstream recorder `ready`，不冒充模型调用。正式证据为 `evidence/EP-005-formal-acceptance.md`，警报复审为 `evidence/ep-005-ledger-alarm-reaudit.md`。第一次未 export `RIG_HOME` 的五格误写默认账本已保留审计并清警，正式账本只用显式根重放。

`EP-006 POST /api/v1/functions/{id}:run` 的真实 App session `/private/tmp/anselm-rig-ep006-functions-20260806/sessions/20260806-053154` 完成合法 JSON 正向执行和非法 JSON 负向路径。正向通过 Example → Run 两次真实执行，UI 显示 `Done`、`73ms` 和 `{count:0, kind:"args", value:""}`；REST、SQLite 与后端日志均为同一 active version 的两条 `ok/manual` 执行。负向由可见编辑器输入 `A` 触发，画面显示 `Payload must be valid JSON.`、Run 置灰，点击不增加 Recent 执行数。528.990000s 录屏、三路 SSE 连接、frontend console、LLM tap、REST/SQLite 和 backend journal 均已封存；ready env 的同步 Function run 不发布实体/消息帧，SSE journal 的零帧是预期且无断连。临时 Function 随后由真实 API `DELETE=204` 清理，GET `404`、搜索为空。正式证据为 `evidence/EP-006-real-app.md`，警报复审为 `evidence/EP-006-ledger-alarm-reaudit.md`；五级裁决已写入 COVERAGE，中央账本 `685→690`，正式警报最终 clean；该格已在批次十三收口。

`EP-002 GET /api/v1/functions` 的最终五通道 session 为 `/private/tmp/anselm-rig-ep002-functions-20260806/sessions/20260806-034541`。在真实 App 和真实受管网关上构造 45 个真实 Function fixture，逐页验证 `20+20+5`、cursor continuation、filtered search、非法 limit 和上限 limit；Entities rail 真实加载 20→40→45 条，匹配查询显示结果。前置观察发现 no-match 搜索会变成没有解释的空白 rail，stop-and-fix 增加本地化 `No entities match your search.`，保留普通空 workspace 的完整结构；定向 frontend tests `41/41`、`make -C frontend gen`、Dart format 与 diff check 通过。最终会话还完成一次真实网关 chat，回复 `pagination witness ready.`；录屏 `151.576667s`，backend 无未解释应用错误，三路 SSE durable seq 单调，frontend console 无 Flutter/Dart/RenderFlex/Unhandled 红线，LLM tap 完成响应全为 HTTP 200。完整证据为 `sessions/20260806-034541/evidence/ep-002-functions-green.md`，账本复审为 `sessions/20260806-034541/evidence/ep-002-ledger-reaudit.md`。

EP-002 的产品修复落在 `frontend/lib/core/ui/an_sidebar_list.dart`、`frontend/lib/features/entities/ui/entity_rail.dart`、双语 i18n、定向测试和 `docs/references/frontend/features/entities.md`；这是同一覆盖格内的 stop-and-fix，不额外虚增 COVERAGE 数量。EP-003 没有发现需要施工的产品或代码红线；其成功/404 raw response、详情终帧和五通道 journal 已封存于 `/private/tmp/anselm-rig-ep003-functions-20260806/sessions/20260806-035647/evidence/`，复审证据为 `ep-003-ledger-reaudit.md`。以下 `TOOL-123` 及其后的旧段落均为历史过程快照；恢复执行只以上述整体重述、`LOOP.md`、`LOG.md` 最新条目和 COVERAGE 当前行作为真相。

`TOOL-123` 的真实 App 用户路径在 session `/private/tmp/anselm-rig-tool123-live-20260806/sessions/20260806-020305` 完整通过：生成蓝色帆船静态图 → 用户批准危险 `animate_image` → 网关提交/轮询/媒体上传 → 保存 5 秒 MP4 → 展开、播放到 `0:05 / 0:05`、重播、全屏、退出全屏。源附件 `att_88a52e72d00ccc1f` 与视频附件 `att_5863a6340ae60b18` 的 receipt、SQLite、UI 和 LLM 线缆一致；首帧独立测量 `changedFrac=0.1009`，`measure compare` 通过，构图保持帆船左侧与右侧开阔水面。

本次五通道证据为 `sessions/20260806-020305/evidence/tool-123-animate-image-formal-20260806.md`：647.886667 秒可读窗口录屏；backend 无未解释 WARN/ERROR；三路 SSE 均连接，messages durable `1..38`、notifications `1..2` 分流单调，ephemeral delta 保持 seq `0`；LLM tap 记录 I2V `202`、轮询 `200`、媒体上传 `201`、最终对话 `200`；frontend 无 Flutter/Dart/AXTree/RenderFlex/Unhandled/Exception 红线。上一 session `/private/tmp/anselm-rig-tool123-live-20260806/sessions/20260806-015946` 的 AXTree 红证据保留，不被改判绿；修复后的 loading/error/retry 状态由 34 项媒体定向测试和 `flutter analyze` 锁定。

五级写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以独立复审文件 `sessions/20260806-020305/evidence/tool-123-ledger-alarm-reaudit.md` 逐项复核并 ack；警报阈值未放宽，其含义是账本批写和“单格全绿不代表全产品全绿”。此前一次未 export `RIG_HOME` 的 L1 误写到默认旧账本，已保留原始审计、销账并切回正式账本重放；默认旧账本不作为本战役水位。该段为上一格收口，下一轮从 `EP-001 POST /api/v1/functions` 继续，50 格统一长门禁仍后置。

`TOOL-124 enroll_voice` 的真实 App 用户路径在 session `/private/tmp/anselm-rig-tool124-live-20260806/sessions/20260806-022721` 完整通过：生成短参考音频 → 解释持久音色身份与有限库存 → 危险 `enroll_voice` 人闸批准 → 真实网关登记 → 使用登记音色再次生成语音 → Settings 读取音色库存并确认 1/2 槽位 → 用本地音色行 ID 删除 → GET 库存回到空集/2 个可用槽。参考音频 `att_353b3737368b9dbf` 的 WAV 为 157484 bytes、3.280000s，复用音频 `att_e06c667a3db58ac3` 为 169004 bytes、3.520000s；网关音色句柄 `vce_23b241a4e1789dd687ab954eef2dc39d` 与本地行 `vce_b905053ec7c7c2eb` 的创建、使用和删除边界均有证据。五通道正式证据为 `sessions/20260806-022721/evidence/tool-124-enroll-voice-formal-20260806.md`：587.738333 秒可读窗口录屏，messages durable `1..52`、notifications `1..2` 单调，entities 流已连接，ephemeral delta 保持 seq `0`；LLM tap 记录两次 speech `200`、voice create `200`、媒体上传 `200/201`、删除 `204`，backend/frontend 无未解释 runtime 红线。Computer Use 输入层对中文字符的丢失被保留为仪器限制而非产品红线；英文主路径正常完成。

TOOL-124 首轮还暴露了 Settings 将音色 GET 失败伪装成“没有音色”的真相问题；stop-and-fix 改为明确错误状态与 `Retry`，补 `voices_card_test.dart` 6/6、fixture failure hook、双语文案与 settings 文档规则，`flutter analyze` 与定向媒体/设置回归通过。五级写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以独立复审文件 `sessions/20260806-022721/evidence/tool-124-ledger-alarm-reaudit.md` 串行 ack，阈值未放宽，最终 `alarms.py check` 为 clean(655)。

`EP-001 POST /api/v1/functions` 的前置真实 App 会话连续发现三条产品/契约红线并逐条停修：托管模型把外层 `ops` 发成 JSON 字符串、把 `set_inputs/set_outputs` 发成不兼容的嵌套字段形状，以及成功正文把 ID 行渲染成 `the requested item` 占位符。三份红证据分别保留在 `/private/tmp/anselm-rig-ep001-live-20260806/sessions/20260806-024539/evidence/ep-001-formal-red-stringified-ops-retry.md`、`/private/tmp/anselm-rig-ep001-green-20260806/sessions/20260806-025504/evidence/ep-001-formal-red-placeholder-id-table.md` 和 `/private/tmp/anselm-rig-ep001-green2-20260806/sessions/20260806-030108/evidence/ep-001-formal-red-nested-schema-retry.md`；均未计绿。

stop-and-fix 在 `create_function/edit_function` 执行边界增加窄兼容：只还原合法 JSON 数组字符串、无歧义字段 map 和完整覆盖 properties 的 JSON-Schema；公开 schema 仍保持 canonical flat array，CSV/prose/歧义/不完整 required 继续拒绝。同步工具描述、function domain/API 文档和 Go 回归。另修复 opaque ID 在 `Field | Value` 表格中变成坏占位的问题：精确 ID 只在相邻可展开、可复制的 `Created function · v1` 工具卡出现，用户正文不再留下假值。

正式绿 session `/private/tmp/anselm-rig-ep001-green3-20260806/sessions/20260806-030648` 由同一 manifest 托管真实 App、Flutter console、录屏、backend、三路 SSE witness 和 LLM tap：只调用一次 `create_function`，SQLite 只有一个函数/v1，环境 `ready`，持久化 tool call 已规范化，SSE 三流 durable seq 单调，LLM/HTTP 全 200，录屏 `337.441667s`，收台无残留进程。前端除已知 macOS 输入法 mach-port 系统噪声外无 Flutter/Dart/RenderFlex/Unhandled 红线；正式证据为 `sessions/20260806-030648/evidence/ep-001-formal-green-provider-shapes.md`，警报复审为 `sessions/20260806-030648/evidence/ep-001-ledger-alarm-reaudit.md`。五级裁决已写入 COVERAGE，批次十三由 **20 / 50** 推进至 **25 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-002 GET /api/v1/functions`。

随后代码审查发现一个必须在进入下一格前清除的审计问题：通用 provider 参数归一化被错误记成 `get_flowrun` 专属原因，且 `edit_function` 对畸形 `ops` 的校验拖到了执行阶段。stop-and-fix 已补上通用审计原因、edit 写前校验与回归测试；最终代码 session `/private/tmp/anselm-rig-ep001-auditfix-20260806/sessions/20260806-032244` 重新走真实 App、真实受管网关和五通道，provider wire 的外层 `ops` 为字符串，SQLite/SSE 已规范化为四项 native ops，`argumentRepair` 为 `provider arguments normalized by tool boundary`，函数 `ready`，真实执行 `100 °C → 212 °F`，录屏 `200.358333s` 可读，三流 durable seq 单调，LLM 全 200，backend/frontend 无未解释应用红线。最终证据为 `evidence/ep-001-audit-fix-green.md`，账本复审为 `evidence/ep-001-auditfix-ledger-reaudit.md`；五级重验证使正式账本 **660→665 judgments**，不增加覆盖格，警报最终 clean。

`TOOL-122` 的五格均使用正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-050103` 及证据 `evidence/TOOL-122.md`：真实 App 完成一次生图→改图，来源与改后附件分离，改图结果保留原构图并将红色圆形精确改为蓝色；用户目的达成，五通道数据一致，交互过程无几何跳变，图像卡的比例、来源关系和事实展示达到可发布标准，新用户能发现并完成路径，无第二次生成、无 retry。两条统计警报已用独立复审证据 `evidence/tool-122-ledger-alarm-reaudit.md` 串行 ack，最终 `alarms.py check` 为 clean。

`TOOL-119 generate_image` 首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-024832` 暴露助手正文把媒体回执行脱敏成 `**Attachment ID:** the requested item`；随后 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-025906` 与 `20260805-030147` 又捕获流式 SSE 中间帧泄露 `Attachment ID` 标签和反引号半截。stop-and-fix 将媒体语义标签行从通用脱敏中窄化处理，并让流式 redactor 跨 provider chunk 暂存整行；Go 回归覆盖实际 `att_…` 值边界，真实正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-031323` 已证明 user-facing SSE delta/close 无 `Attachment ID`、`attachmentId`、`att_` 或坏占位。

同一前线的产品复核又发现 `generate_image` 工具卡丢弃 receipt 的 `width/height`，导致 landscape/portrait 在附件行返回前先占方形版面。stop-and-fix 将 filename、mime、sizeBytes、width/height、source 全量作为 `AnMediaRef` 提示传入统一媒体卡，新增 delayed-meta widget guard；真实 landscape 路径最终显示真实 `1344×768` 图像、文件名和大小，composer 正常收口。正式证据为 `sessions/20260805-031323/evidence/TOOL-119.md`，警报复审为 `tool-119-ledger-alarm-reaudit.md`；anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已落账，最终 `alarms.py check` 为 `clean (630 judgments)`。本格使批次十二推进到 **45 / 50**；未到 50 格前不跑统一长门禁、不提交。

`TOOL-120 generate_speech` 首次真实复验前冻结两条产品红线：生成语音收据的 filename/sizeBytes/durationMs 被前端丢弃，附件行在途时没有保留已知事实；元数据失败直接显示裸 `att_`，在途通用文件骨架落地后还会跳成音频卡。stop-and-fix 补齐收据解析和音频卡状态：收据先供稳定文件名、大小、精确时长，附件行到达后覆盖；在途保持音频几何与 loading 文案；失败显示可重试人话，播放失败/离线/缺失分别走统一状态。正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-032851` 真实完成 onboarding、一次受管 `/audio/speech`、展开音频卡、播放 lease、Range 播放与自然收尾；画面显示 `generated-20260804-193020.wav · WAV · 123.8 KB · 0:03`，播放中为 Pause、结束后回到可重播 Play。录屏 `180.128333s`；messages durable `1..14`、notifications `1..2` 单调；SQLite 附件 `audio/wav`、`126764` bytes，blob 为 24kHz mono PCM WAV；LLM wire 一次 speech request/response、一次 `generate_speech` tool call，backend/frontend 无未解释红线。正式证据为 `sessions/20260805-032851/evidence/TOOL-120.md`，警报复审为 `tool-120-ledger-alarm-reaudit.md`；anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已落账，最终 `alarms.py check` 为 `clean (635 judgments)`。本格使批次十二达到 **50 / 50**；统一长门禁、完整 testend、工作树审计均已通过，已提交 `91cdd51c`，下一原子前线为 `TOOL-121 generate_video`，尚未开始。

`TOOL-121 generate_video` 首次正式路径完成真实 onboarding、受管网关、Computer Use、窗口录屏、三路独立 SSE witness、LLM tap、backend/frontend journal 和隔离清理。首轮 landscape 成功后，产品复核发现前端丢弃 receipt 的 filename/sizeBytes，且视频在附件行迟到时默认 16:9，portrait/square 可能发生首帧几何跳变；前线冻结并补齐 `AnMediaRef` 的 filename/size/aspect hints、portrait/square/landscape 占位比例、native controller 实际几何覆盖和 delayed-meta widget guard。定向 Flutter 21 项、analyze、Go generate/llm tests 和 diff check 通过。

`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-040847` 用新 binary 真实重跑 portrait：danger card 在批准前阻断；批准后只调用一次视频生成，UI 显示 `Generating video…`、经过 `running…` 和 `generated in 1m43s, downloading…`，最终保存 `generated-20260804-201201.mp4 · video/mp4 · 4.6 MB · 5s`。实际 blob 为 H.264/AAC `720×1280`、`5.038005s`、`4825115` bytes；播放自然结束后 AX 显示 `0:05 / 0:05`、`Replay`、`Fullscreen`，画面为真实灯塔帧。messages durable `1..16`、notifications `1..2` 无 gap，entities 已连接；LLM 为一次 `POST /videos/generations` 202、十次成功轮询和后续 chat completions，无 retry/第二次生成；backend/frontend 无未解释红线，录屏 `378.828333s`。用户确认后 cleanup DELETE=204、GET=404、列表为空，唯一 workspace 与正式 session 保留。正式证据 `sessions/20260805-040847/evidence/TOOL-121.md`，警报复审 `tool-121-ledger-alarm-reaudit.md`；anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `635→640 judgments`，最终 `alarms.py check` 为 `clean (640 judgments)`。批次十三推进到 **5 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `TOOL-122 edit_image`。

`TOOL-113 list_conversations` 首轮正式复验 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-220707` 冻结为红：raw provider 与 durable close 的三条 RFC3339 时间正确，但中间 SSE 曾把 `Alpha planning` 的 `lastMessageAt` 改成 `the recorded time`；同时发现普通词尾 `ge` 被 partial `get_flowrun` matcher 误判。红 session 保留、不计绿。stop-and-fix 收紧 token-boundary，并让带 `lastMessageAt` 的表格在无换行尾行、空目标列和孤立 `|` 行期间整体暂存；补真实 provider wire chunk regression，并同步 chat domain 法条。

修复后二次正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-221418` 使用新 binary、真实 macOS App、真实受管 gateway、Computer Use 和五通道台架：真实对话只调用三次 `list_conversations`，逐 cursor 取回 Gamma/Alpha/Beta 三页；中间 text delta 与 durable close 均无占位，最终 UI 表格逐字显示三条 `lastMessageAt`，稳定态 AX/截图无裁切、重叠或布局红线。`screen.mov` 已封口 `162.765s / 2784x1808 / 60fps`；messages durable `1..20` 单调；backend/frontend 无未解释红线；LLM wire 全 200。正式证据为 `evidence/TOOL-113.md`，复审为 `evidence/tool-113-ledger-alarm-reaudit.md`；锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，`alarms.py check` 为 `clean (600 judgments)`。

`TOOL-114 manage_conversation` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-222259` 以真实 App 完成 rename、pin、unpin、archive、当前对话自动 unarchive、显式 unarchive 六条产品路径；空标题负路径只调用一次，服务端返回 `rename requires a non-empty title`，标题不变、没有 fallback 或 retry。稳定 Computer Use 画面和录屏中的失败卡完整可读，通知顺序与 UI/工具结果一致；`screen.mov` 封口 `411.743333s / 2784x1808 / 60fps`，messages durable `1..96`、notifications `1..6` 单调，三路 SSE 均连接，LLM chat responses 全 200，frontend 无运行时红线，backend 只有预期业务校验 WARN。正式证据为 `evidence/TOOL-114.md`，复审为 `evidence/tool-114-ledger-alarm-reaudit.md`；锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，最终 `alarms.py check` 为 `clean (605 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。

`TOOL-115 search_blocks` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-232754` 使用新 binary、真实 macOS App、真实受管 gateway、Computer Use、217.091667s 窗口录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap。正向全 kind 检索一次返回 9 条真实 block；指定 handler 筛选一次返回 3 条；无匹配一次返回可行动建议；空 query 一次显示明确校验失败且无 retry/mutation。首轮真实复验发现摘要泄漏 opaque ref、跨 SSE chunk 占位符闪现和 hosted model 字符串化 `kinds`/`limit`；stop-and-fix 增加换行前缓冲、search_blocks 摘要归一化和严格兼容解码，并强化“不先做 unfiltered preliminary call”的工具契约。修复后二次复验中工具卡保留精确 ref，助手表格不泄露机器标识，UI、SQLite、tool result、SSE 和 LLM wire 一致；frontend 无运行时红线，backend 只有预期空 query WARN，LLM chat responses 全 200。正式证据为 `evidence/TOOL-115.md`，警报复审为 `evidence/tool-115-ledger-alarm-reaudit.md`；锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，最终 `alarms.py check` 为 `clean (610 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。

`TOOL-116 get_relations` 首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-014547` 冻结为红：关系表的 `起点 (from)` 端点名称后泄露 `(fromId: deploy-helper)`，中间 SSE delta 也曾露出裸关系占位符；该 session 不计绿。stop-and-fix 让关系表按 `起点/终点/端点名称` 识别端点列，只展示 kind 与人名；机器字段、关系 ID、时间戳和裸占位符在 delta 与 durable close 都先暂存并完整脱敏，精确 ref 只留在相邻 tool card、tool result 和 LLM 审计线缆；新增真实 hosted-model 形态回归测试并同步 chat domain 法条。修复后二次正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-015059` 使用新 binary、真实 App、真实受管 gateway、Computer Use 和五通道台架，真实请求只调用一次 `get_relations`，最终画面显示 `技能 deploy-helper → 函数 greet` 与 `精确 ref 见关系卡`；assistant-only SSE delta/reasoning/close 禁词扫描为空，`rig-check.sh` 五观察器通过后由 `rig-down.sh` 封口，frontend/backend 无 runtime 红线，LLM 状态全 200。正式证据为 `evidence/TOOL-116.md`，警报复审为 `evidence/tool-116-ledger-alarm-reaudit.md`；锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，最终 `alarms.py check` 为 `clean (615 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。

`TOOL-117 WebFetch` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-020051` 使用新 binary、真实 macOS App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和窗口录屏。正向 RFC 9110 local fetch 从 `Fetching...` 收口为 486 字 grounded 摘要；`example.com` 在 local 模式诚实显示 `JS page` 与 127 字 shell 降级，在 Chat 设置切换 `Jina proxy` 后同页真实返回 133 字正文并准确回答 `Example Domain`。loopback 请求被明确拒绝，无网络副作用。录屏 `336.700000s / 2784x1808 / 60fps`，SQLite 最终 `web_fetch_mode=jina`，messages durable `1..62`、notifications `1..2` 单调，四条 WebFetch tool-result close、LLM 28 个 HTTP response 全 200，backend/frontend 无未解释 runtime 红线；正式证据为 `evidence/TOOL-117.md`，警报复审为 `evidence/tool-117-ledger-alarm-reaudit.md`。锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，最终 `alarms.py check` 为 `clean (620 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。
`TOOL-117 WebFetch` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-020051` 使用新 binary、真实 macOS App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和窗口录屏。正向 RFC 9110 local fetch 从 `Fetching...` 收口为 486 字 grounded 摘要；`example.com` 在 local 模式诚实显示 `JS page` 与 127 字 shell 降级，在 Chat 设置切换 `Jina proxy` 后同页真实返回 133 字正文并准确回答 `Example Domain`。loopback 请求被明确拒绝，无网络副作用。录屏 `336.700000s / 2784x1808 / 60fps`，SQLite 最终 `web_fetch_mode=jina`，messages durable `1..62`、notifications `1..2` 单调，四条 WebFetch tool-result close、LLM 28 个 HTTP response 全 200，backend/frontend 无未解释 runtime 红线；正式证据为 `evidence/TOOL-117.md`，警报复审为 `tool-117-ledger-alarm-reaudit.md`。锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，最终 `alarms.py check` 为 `clean (620 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。

`TOOL-118 WebSearch` 首轮正向真实 App 路径冻结为红：托管模型把公开 schema 的 `limit` 发成字符串，后端正确拒绝后出现可见 validation failure 和 retry；stop-and-fix 将 schema 收紧为 integer，同时在执行边界接受原生整数与精确十进制字符串，浮点/任意字符串/数组/布尔继续拒绝，并补 Go 回归。修复后的正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-023835` 以新 binary、真实 App、真实受管 gateway、Computer Use、三路 SSE witness、LLM tap 和窗口录屏完成成功与 401 失败两条路径；成功只调用一次 WebSearch，返回 Alpha/Beta 两条有序结果、`2+ hits` 与 `truncated:true`，失败只调用一次且显示 provider 401，无 retry。抽帧又发现助手复述的长错误代码块横向裁切；stop-and-fix 让 Markdown 围栏代码默认 `wrap:true`，并钉住只读宽度基准，补 40 项 Flutter 回归。最终失败帧 `frames/frame-195.jpg` 已完整折成两行，`authentication failed` 与 JSON 全可读；正向 settled 帧为 `frames/frame-135.jpg`。五通道：screen.mov `244.275000s / 2784x1808 / 60fps`，messages durable `1..40`、notifications `1..4` 单调且 0 gap，LLM body 对两条路径均恰一条 WebSearch、backend 仅预期 401 WARN、frontend 无异常；证据 `evidence/TOOL-118.md`，警报复审 `evidence/tool-118-ledger-alarm-reaudit.md`，anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已落账，最终 `alarms.py check` 为 `clean (625 judgments)`。以下均为历史快照；批次未到 50 格，不跑统一长门禁、不提交。

**历史快照（2026-08-04，TOOL-113 之前）。** 第九批 `TOOL-081..090` 已完成 **50 / 50** 并提交 `32b33499`；第十批 `TOOL-091..100` 已完成 **50 / 50** 并提交 `553fa150`；第十一批 `TOOL-101..110` 已完成 **50 / 50**，统一长门禁、`make verify`、锚点校准和警报复核均通过，已提交 `de146b72`。当时正式账本为 **595 judgments**，本批为 **10 / 50**，下一原子前线为 `TOOL-113 list_conversations`。该段仅供追溯，当前前线以上方整体重述为准。

`TOOL-112 search_conversations` 首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-205354` 冻结为红：新 workspace 的后台免费档 hook 与首条 Chat 消息发生竞态，UI 出现 `LLM_RESOLVE_ERROR · no model configured for scenario`；该 session 保留、不计绿。stop-and-fix 增加同 workspace provisioning single-flight，并让桌面 onboarding 在释放 Chat 前调用既有 `POST /freetier:provision` 做前台就绪检查；同时把 FTS snippet 窗口从 16 token 收紧证据不足的缺陷修为有界 64 token，并加精确连字符查询回归。

修复后二次正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-210040` 从空数据目录启动真实 macOS App、真实受管 gateway、Computer Use 和五通道台架：workspace 创建后前台 provision 等到受管 key/default model 可见，Chat 首发无模型错误；源对话写入 `ORBITAL-112-FIX4` 并改名 `Launch plan notes`，新对话真实调用 `search_conversations` 返回 1 个 message hit。展开卡片逐帧可见完整高亮、`matchedChunks=2`、可复制 `messageId` 芯片；点击命中行深跳到目标 assistant message，画面与 SQLite/REST 一致。`rig-check.sh`、`rig-down.sh` 均通过；`backend.log`/`frontend.log` 无未解释 runtime 红线，`sse.jsonl` 三流连接且 durable close 序列一致，`llm.jsonl` 含真实受管 wire 与完整 tool result。正式证据为 `evidence/TOOL-112.md`；锚点 `10/10`，`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按红 session、修复后二次绿 session、五通道证据和校准结果书面 ack，最终 `alarms.py check` 为 `clean (595 judgments)`。本批未到 50 格，不跑统一长门禁、不提交。

`TOOL-109 run_skill_script` 正式绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-184737`，录屏已封口。首轮重跑确认 lazy 目录行已经暴露 `run_skill_script(name, script; optional: args, stdin, timeoutSec)`，并明确 `name` 是 skill slug、`script` 是相对路径；真实正向路径只产生一次成功调用，参数、stdin、沙箱 stdout 与最终 `OK` 一致。缺失脚本和 `.sh` 扩展名两条负向路径各只产生一次失败调用，无 retry；后端 WARN 是预期业务失败，非未处理异常。五通道 `rig-check` 全绿，frontend 无 Flutter/AX/Unhandled 红线，SSE 与 LLM wire 均证明三条对话各只有一个 `run_skill_script` 调用。正式证据为 `evidence/TOOL-109.md`，警报重审为 `evidence/tool-109-ledger-alarm-reaudit.md`；`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，锚点 10/10，`alarms.py check` 为 `clean (580 judgments)`。下方内容均为历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。第十一批未到 50 格前不跑统一长门禁、不提交。

`TOOL-110 Subagent` 正式绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-190256`，录屏已封口。真实正向路径只调用一次 `Subagent(Explore)`，子运行读取真实 `CLAUDE.md` 并返回首个标题，UI 只出现一次 `Spawned subagent · Explore`，嵌套轨迹归在父卡下；非法 `subagent_type=Nope` 路径只产生一次校验错误，UI 改为 `Subagent validation failed · not started`，明确没有启动子代理，不显示 `get_subagent_trace` 回放提示。前置红线是失败卡误称“已派子代理”并虚构轨迹，已修复 `failedVerb`、未启动体文案、错误重复回答和中英文 i18n，并补 widget regression；修复后正负路径重跑通过。SSE 正向恰有 1 个 `subagent:true` 子消息、负向为 0；backend 只有预期校验 WARN，frontend Flutter/AX/Unhandled 红线为 0，LLM wire 全 200，`rig-check` 五通道全绿。正式证据为 `evidence/TOOL-110.md`，警报重审为 `evidence/tool-110-ledger-alarm-reaudit.md`；`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，锚点 10/10，`alarms.py check` 为 `clean (585 judgments)`。本批已到 50 / 50，完成长门禁和提交后才进入 `TOOL-111`。
`TOOL-110 Subagent` 正式绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-190256`，录屏已封口。真实正向路径只调用一次 `Subagent(Explore)`，子运行读取真实 `CLAUDE.md` 并返回首个标题，UI 只出现一次 `Spawned subagent · Explore`，嵌套轨迹归在父卡下；非法 `subagent_type=Nope` 路径只产生一次校验错误，UI 改为 `Subagent validation failed · not started`，明确没有启动子代理，不显示 `get_subagent_trace` 回放提示。前置红线是失败卡误称“已派子代理”并虚构轨迹，已修复 `failedVerb`、未启动体文案、错误重复回答和中英文 i18n，并补 widget regression；修复后正负路径重跑通过。SSE 正向恰有 1 个 `subagent:true` 子消息、负向为 0；backend 只有预期校验 WARN，frontend Flutter/AX/Unhandled 红线为 0，LLM wire 全 200，`rig-check` 五通道全绿。正式证据为 `evidence/TOOL-110.md`，警报重审为 `evidence/tool-110-ledger-alarm-reaudit.md`；`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，锚点 10/10，`alarms.py check` 为 `clean (585 judgments)`。随后完整 `make testend` 发现并冻结了一个旧验收剧本问题：`install_mcp_server` 的 danger gate 未被场景处理，导致回合正确停在 `streaming`；场景已改为逐次断言并批准两道人闸，定向场景与完整 testend 均通过，MCP 领域文档同步说明该安全边界。本批完成长门禁、最终验证、审计并提交 `de146b72`，下一原子前线为 `TOOL-111 get_subagent_trace`。

上段为当前事实；下方内容均为历史快照。恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。

`TOOL-108 delete_skill` 正式绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-180135`，录屏 `564.176667s`。真实 App 先验证模型自报 `danger=safe` 被静态危险下限挡住，再验证不存在目标经过 HumanLoop Deny 后终局且不重试，最后在用户明确确认后 Allow 删除 fixture；UI 只有一次危险闸、一次 `Deleted` activity 和成功反馈。目标目录已消失，列表不再出现目标，单项 REST 返回 `SKILL_NOT_FOUND`；SSE 有一次 `skill.deleted`、一次 `deleted` touchpoint 和一次成功 tool_result，LLM wire 只有一次 mutation，backend/frontend/录屏一致。`rig-check` 五通道全绿，台架已收台；正式证据为 `evidence/tool-108-formal-180135-green.md`，警报重审为 `evidence/tool-108-ledger-alarm-reaudit.md`。`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE 行为 `✓✓✓✓✓`，`alarms.py check` 为 `clean (575 judgments)`。下方内容均为历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。第十一批未到 50 格前不跑统一长门禁、不提交。

`TOOL-107 edit_skill` 的正式绿 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-175428`，录屏 `130.763333s`。成功路径真实读取 `deploy-helper` 后只做一次完整覆盖，UI/Activity 只有一条 `Edited`，正文与完整元数据可见，文件真相已核对；失败路径真实编辑不存在的 `missing-skill-107`，只出现一张 `Failed`，错误原文为 `skill not found`，右侧明确显示 `Draft unsaved · truth is still the last version`，没有创建残留。SSE、LLM wire、backend journal、SQLite/文件系统和画面一致，`rig-check` 五通道全绿；frontend 只有已知 foreground 诊断，无 Flutter exception。

本格先后冻结四条红线且全部排除出账本：Computer Use 换行误提交；`AnInteractive` 布局阶段同步 `setState`；托管模型把 `disableModelInvocation:false` 字符串化导致合法 edit 首次失败并重试；缺失 skill 的终局错误重复执行导致两张红卡。stop-and-fix 已分别完成 post-frame hover flush 与回归测试、`decodeSkillBool` 精确字符串兼容、`EditSkill.HaltOnRepeat` 终局抑制，并同步 backend/frontend 领域文档。红证据保留在 `173117`、`173358`、`174614`、`175039` 四个 session 的 `evidence/` 下。

`judge.py` 已以 `G1/F2/A5/C4/G2` 写入 `TOOL-107` 五格，COVERAGE 行为 `✓✓✓✓✓`；锚点 10/10 校准通过，写账触发的 `gap-too-fast` 与 `discovery-collapse` 已依据四条红证据、正式绿 session、五通道日志、回归测试和 `evidence/tool-107-ledger-alarm-reaudit.md` 复审并 ack，当前 `alarms.py check` 为 `clean (570 judgments)`。下方内容均为历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。第十一批未到 50 格前不跑统一长门禁、不提交。

`TOOL-104 activate_skill` 首轮红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-164045` 暴露托管模型把公开 schema 的 `arguments: array<string>` 编成 JSON 数组字符串：后端正确拒绝了旧形状，真实 App 出现失败卡，模型随后重复用原生数组重试；红证据保留，不计绿。stop-and-fix 增加窄兼容层，只接受原生字符串数组或**精确 JSON 数组编码字符串**，普通字符串、数字、对象、混合数组和非法编码继续拒绝；同步单测与 skill 领域文档。

正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-164732` 使用新 binary、真实 Flutter App、真实受管 gateway、Computer Use 和五通道台架重跑。LLM wire 实际仍发字符串化数组，但只执行一次；App 只有一张成功 `Activated skill activation-104` 卡，`$1`/`$ARGUMENTS` 正确替换为 `design`/`design review`，没有失败重试卡；SSE、SQLite、backend/frontend journal 与画面一致，后端无 WARN/ERROR，录屏 `198.910000s / 2784x1808 / 60fps`。正式证据 `evidence/tool-104-formal-164732-green.md`。

`TOOL-103 get_mcp_call` 首轮红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-163003` 暴露托管模型连续把 opaque `callId` 从真实记录的 `...bfa41` 抄成 `...bba41`：后端正确返回 `mcp call not found`，App 正确渲染红色失败卷宗，没有伪造成功；红证据 `evidence/tool-103-red-opaque-id-copy.md` 保留，不计绿。正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-163620` 使用真实 Context7 历史记录，按原样读取单条成功调用：App 卡片显示 `Completed · 2.0s`、工具 chip 和完整卷宗，SQLite 为 `status=ok / triggered_by=chat / elapsed_ms=1990`，SSE 含 exact argument 与 tool-result close，LLM wire 未改写，backend 无 WARN/ERROR，Flutter runner 无 Dart/Unhandled 红线。录屏 `72.616667s / 2784x1808 / 60fps`，正式证据 `evidence/tool-103-formal-163620-green.md`。

`TOOL-102 search_mcp_calls` 首轮真实红 session `20260804-160132` 冻结了托管模型把 `limit` 发成字符串时的可见失败卡与自动重复查询；stop-and-fix 让执行层接受原生整数与精确十进制字符串，浮点、数组、布尔、对象和非整数文本继续拒绝，并把 schema 描述与现有 handler/activation 先例同步。正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-161720` 从 fresh onboarding 和真实 Context7 安装开始：两次真实 `resolve-library-id`（合法 Flutter 查询与空业务参数）、一次有界 `search_mcp_calls(limit=1)`、一次 `nextCursor` 翻页；App 卡片、SQLite、SSE、LLM wire、backend/frontend journal 一致，翻页从 `hasMore=true` 正确收口为 `false`，无失败重试卡。业务文本 `Library name is required` 的 MCP `IsError=false` 仍诚实记录为 `status=ok`，没有由产品猜测擅自重分类。五通道 `rig-check` 收台前全绿；正式证据 `evidence/tool-102-formal-161720-green.md`，警报复审 `tool-102-ledger-alarm-reaudit.md`。

`judge.py` 已以 `G1/F2/A5/C4/G2` 写入 `TOOL-104` 五格，COVERAGE 行为 `✓✓✓✓✓`；锚点继续有效，五格写入触发的 `gap-too-fast` 与 `discovery-collapse` 已依据真实参数形状红案、正式绿 session、五通道原始日志、SQLite/LLM 线材、录屏和复审说明 ack，`alarms.py check` 为 `clean (555 judgments)`。下方第十批及更早段落是历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。

`TOOL-105 get_skill` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-165430` 完成 existing 与 missing 两条真实路径。existing 只调用一次 `get_skill(deploy-helper)`，结构化 card 显示 skill identity、description/context/source、allowed-tools chips 和完整 Markdown body；展开 `raw result` 后可核对未过滤的 opaque allowed-tool、workspace dir、ISO `updatedAt`、完整 frontmatter/body。助手 prose 的机器值脱敏是全局安全法条，不放开；missing `missing-skill-105` 只产生一张红失败 card 和一个预期 backend execute-failed WARN，无 retry/activate/create/edit。录屏 `276.158333s / 2784x1808 / 60fps`，五通道证据 `evidence/tool-105-formal-165430-green.md`。

`judge.py` 已以 `G1/F2/A5/C4/G2` 写入 `TOOL-105` 五格，COVERAGE 行为 `✓✓✓✓✓`；`gap-too-fast`、`pass-burst` 与 `discovery-collapse` 已依据真实负路径、raw-result 展开和五通道复审说明 ack，`alarms.py check` 为 `clean (560 judgments)`。下方第十批及更早段落是历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。

`TOOL-106 create_skill` 的前置真实 session `20260804-170849` 捕获托管模型把 `allowedTools`/`arguments` 编成 JSON 数组字符串，旧执行层拒绝后模型重复调用；`20260804-171251` 又暴露可选元数据被模型省略；`20260804-171503` 暴露冲突时 Activity rail 错把成功动词与 failed 并列。三份红证据均保留且不计绿。stop-and-fix 增加共享的精确数组字符串兼容解码与完整工具描述，并让中心卡/侧幕失败态都只使用明确失败语义；Go/Flutter 定向守卫测试和领域文档同步。

正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-171941` 使用新 binary、真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和 `333.665000s` 录屏。成功路径只创建一次 `release-notes-106e`，卡片逐字段展示完整元数据与正文，Activity 只有一条 `Created`；重名路径只调用一次，中心显示 `Create skill failed` 与真实 `skill name already exists`，侧幕只显示 `Failed` 和 `Draft unsaved · nothing was created`，没有 retry、第二条 mutation 或矛盾成功卡。五通道、SSE/SQLite/LLM wire/UI 一致；backend 仅有预期重名 WARN，Flutter 无异常红线。正式证据 `evidence/tool-106-formal-171941-green.md`。

`judge.py` 已以 `G1/F2/A5/C4/G2` 写入 `TOOL-106` 五格，COVERAGE 行为 `✓✓✓✓✓`；锚点因超过 4 小时被 gate 拒绝后已重新完成 10/10 校准，五格写入后的 `gap-too-fast` 与 `discovery-collapse` 已依据正负路径、三份红证据、五通道 session 和锚点复审并 ack，复审说明为 `evidence/tool-106-ledger-alarm-reaudit.md`，当前 `alarms.py check` 为 `clean (565 judgments)`。下方第十批及更早段落是历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。

TOOL-101 经过三次真实红冻结后才接受第四次绿：`152538` 暴露 prose 只有无信息量的 `the recorded time` 且结构化 MCP 卡缺 `connectedAt`；`153910` 暴露 label/value 形状未被第一版规则覆盖；`154256` 暴露 Markdown `**Connected at:**` 跨 provider chunk 后仍泄漏 vague placeholder。三份红证据均保留，均未写账；stop-and-fix 保留 raw ISO 脱敏边界，新增 label/value、Markdown 表格和跨 chunk 语义处理，结构化卡显示本地化连接时间，并让 Unix long-lived cleanup 在外部进程组竞态时幂等回退到 direct child。

正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-155203` 从 fresh onboarding、真实 Context7 安装和用户 Allow 开始；外部终止 MCP 进程组后成功完成一次 reconnect，第二次 reconnect 不重复执行，未知名称只生成一张明确失败卡且不重试。最终 App 卡片显示 `connected`、2 个 tool chips 和 `Connected at · 2026-08-04 15:54`，正文明确指向 MCP status card。五通道封口：window recording `203.746667s`；SSE messages durable `1..37`、notifications `1..6` 单调，entities 捕获 `disconnected → connecting → ready`；LLM tap 观察到的 upstream responses 全 HTTP 200；backend 仅有预期 unknown-server WARN，无 panic/FATAL/cleanup 权限警告；frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线；`rig-check` 收台前五通道均通过。证据为 `evidence/tool-101-formal-155203-green.md`，账本复审为 `tool-101-ledger-alarm-reaudit.md`。

`judge.py` 已以 `G1/F2/A5/C4/G2` 写入 `TOOL-101` 五格，COVERAGE 行为 `✓✓✓✓✓`；锚点 10/10 已重校，五格写入触发的 `gap-too-fast` 与 `discovery-collapse` 已依据三份红证据、正式绿 session、五通道原始日志、修复回归和复审文件 ack，`alarms.py check` 为 `clean (540 judgments)`。下方第十批及更早段落是历史快照；恢复执行时以上述整体重述、`LOG.md` 最新条目和 COVERAGE 当前行作为唯一前线。

`TOOL-098` formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-100552` 使用全新数据目录、真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和 `385.805000s / 2784x1808 / 60fps` 录屏完成三条路径：`query="database query"` 返回 4 个 installable server；不可命中 query 返回 0，并在 UI 给出扩大 query/单词/无 query/能力描述四类恢复建议；无 query 返回 96 个 installable server，卡片显示 `first 30 of 96`，点击后进入有界 JSON tree，不静默丢剩余目录。query 结果的真实卡片逐 server 显示 full name、description、runtime 和 required-env 数量，模型正文补充精确 env 名称与 required/optional 状态。

修复后 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-104247` 用新 binary 重跑同一无 env 路径：`tool_call danger:"dangerous" → interaction → resolved(Deny) → tool_result`，没有安装执行或半安装行；UI 的危险闸文案与 canonical summary 完整，Deny 后助手准确说明 env 未知、没有伪造 `ENTRA_CLIENT_ID`。录屏 `88.993333s / 2784x1808 / 60fps`，五通道和 `rig-check` 全绿；证据 `evidence/tool-099-formal-104247-red-deny-gate.md` 只证明恢复后的负路径，不计 `TOOL-099` 绿格。

`TOOL-099` success formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-142537` 的 action-time `Allow` 确实完成了真实 `context7` 安装，修复后的卡片显示 `Allowed · connected · 2 tools`，并完成一次动态工具发现与 `resolve-library-id` 调用；但 cleanup 中 `uninstall_mcp_server` 在没有 interaction 的情况下执行，错误名称后模型又重试一次。屏幕录制 `297.000000s / 2784x1808 / 60fps`、五通道 journals、SSE `messages 1..58`、MCP row/tool list 与后端日志均保留，红证据 `evidence/tool-099-formal-143238-red-uninstall-no-gate-retry.md`；台架已收台。卸载 floor/alias stop-and-fix 已完成，下一步必须从新 binary 重跑一次受 gate 保护的 uninstall，确认失败名不重试、Allow/Deny 语义正确、最终 UI 不出现矛盾卡片，随后才能写 TOOL-099 五级判决。

Computer Use 逐帧复核没有发现裁剪、死链、表头错位或不可行动空态；五通道一致：SSE 三流连接，messages durable `1..48`、notifications `1..6` 单调唯一；LLM wire 三个 chat body 各只有一次 marketplace call（另有预期 lazy `search_tools`），所有 HTTP 200；backend/frontend redline 扫描为空，`rig-check` 五观察器全绿。一次 30 秒 Computer Use 观察器超时已重置 kernel 并重新取得最终 AX/画面，记录为仪器事件而非产品红。正式证据为 `evidence/tool-098-formal-100552-green.md`，前端生态回归 `24/24` 通过。

五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，`TOOL-098` 行为 `✓✓✓✓✓`；中央账本由 520 增至 **525 judgments**。五格写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 anchors `10/10`、三条正负/边界路径、正式录屏、五通道 raw journal 和 `evidence/tool-098-ledger-alarm-reaudit.md` 完成重审并 ack，正式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 alarms.py check` 为 `clean (525 judgments)`。验收 conversations 已真实 DELETE=204、列表为空；正式 evidence/journal/录像保留，`gen_coverage.py` 重建仍为 **848 rows × 5 = 4240 cells**。

`TOOL-097` 首轮 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-094444` 冻结为红：后端和 LLM wire 已返回完整模型配置，但真实 App 的 durable tool card 只有模型数量和名称 chip，key 健康、脱敏值、端点、默认 key 关联及能力边界不可检查；红证据 `evidence/tool-097-formal-094444-red-thin-card.md` 保留、不计绿。stop-and-fix 只改前端 projection boundary：`modelConfigBody` 增加默认角色/模型与安全 key display name、API key 的 provider/masked/status、端点、bounded available-model capability table 和 native option chips；绝不渲染 `apiKeyId` 或密文，并同步中英文 i18n 与 widget privacy regression。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-095429` 使用修复后二进制、真实 onboarding workspace、真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和最终 `173.423333s / 2784x1808 / 60fps` 录屏重跑。最终展开卡片直接显示六个默认角色的 `anselm-auto · Anselm Free`、key `Anselm Free / anselm / ins_ab0...82c6 / ok`、endpoint、model `anselm-auto / anselm / 1M / 16.4k / image · video` 和 native option；没有 raw JSON、`apiKeyId`、布局剪裁或未解释跳变。SSE 三流各连接一次，messages durable `1..14`、notifications `1..2`，只有一次 tool call/result；LLM wire、REST、SQLite、UI 一致，backend/frontend 红线为空，`rig-check` 五观察器全绿。

五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，`TOOL-097` 行为 `✓✓✓✓✓`；中央账本由 515 增至 **520 judgments**。五格写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 anchors `10/10`、红证据、修复测试、正式绿 session 和 `evidence/tool-097-ledger-alarm-reaudit.md` 完成重审并 ack，正式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 alarms.py check` 为 `clean (520 judgments)`。验收 conversation 已真实 DELETE=204、列表为空，正式 journals/录像/evidence 保留；`gen_coverage.py` 重建为 **848 rows × 5 = 4240 cells**。

`TOOL-096` 首轮 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-195946` 冻结为红：真实 App 要求一次 `forget_memory` 删除已存在 memory，SSE 的 tool call 为 `danger:"cautious"`，没有 `Dangerous · Awaiting your approval`，随后直接产生 `Forgot memory …` 并真实删除。红证据为 `evidence/tool-096-formal-195946-red-missing-danger-floor.md`，不计绿。stop-and-fix 为 `ForgetMemory.MinimumDanger() = DangerDangerous`、准确 canonical gate summary、破坏性工具总测试、loop gate summary 测试、memory 领域文档与工具清册同步。

修复后的 deny formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-200420` 使用真实 Flutter App、真实受管 gateway、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal 和 `214.911667s / 2784x1808 / 60fps` 窗口录屏，证明 existing-memory 与 missing-memory 两条路径都停在准确 approval，Deny 无副作用。随后正式 green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-093819` 在用户 action-time 授权后完成 Allow：画面先显示不可逆/无恢复 approval，批准后显示 `Forgot`；REST memory list 为空、目标 GET=404。第二个新对话再次批准同一调用后显示中性 `Already gone`，工具返回 `not found (already gone?)`，没有第二条 `memory.deleted` 通知。绿证据为 `evidence/tool-096-formal-093819-green.md`，账本复审为 `tool-096-ledger-alarm-reaudit.md`。

五通道交叉证据已封存：`rig-check` 在录制期间通过全部五个物理观察器，录屏 `114.498333s / 2784x1808 / 60fps`；SSE 两个 conversation 各只有一次 `forget_memory`，每次均为 `tool_call → interaction → resolved → tool_result`，真实删除只产生一次 `memory.deleted`，durable messages 到 seq 28；LLM wire、REST、UI 和 backend journal 一致；frontend/backend 红线扫描无 panic/fatal/error/warn/exception/Flutter runtime marker。anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，行状态为 `✓✓✓✓✓`。五格写账触发的 `gap-too-fast` 与 `discovery-collapse` 已依据红证据、修复链、正式 session 和复审记录 ack；正式 `export RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3; alarms.py check` 为 `clean (515 judgments)`。真实验收 conversation 已 DELETE=204、列表为空，memory 已 404；正式 evidence/journal/审计行保留。`gen_coverage.py` 重建仍为 **848 rows**。

`TOOL-095 write_memory` formal green session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-194919` 使用全新数据目录、真实 Flutter App、真实受管 gateway、Computer Use 逐帧观察、三路独立 SSE witness、LLM tap、backend/frontend journal；录屏 `211.295000s / 2784x1808 / 60fps`。三条路径均通过：一次 exact create 落为 `source=ai,pinned=false`；一次更新真实用户置顶记忆，description/body 改变但 `source=user,pinned=true` 保留；一次非法 slug 原样送达后权威拒绝、不归一化、不创建。UI 成功卡可展开显示 AI/source、description、正文，失败卡明确红色 `Not saved` 与 slug 规则，无 raw JSON、重复 mutation 或布局溢出。

五通道交叉证据完整：SSE 三流已连接，messages durable `1..42`、notifications `1..9` 连续；create `write_memory seq 7 → result seq 9`、update `seq 21 → 23`、invalid `seq 35 → 37`，每条路径只调用一次；LLM wire `24` 个状态条目全为 200，pinned system projection 在更新前后分别携带 V1/V2 且 source=user；backend/frontend journal 无 panic/fatal/error/warn/exception/Flutter runtime 红线。正式证据为 `sessions/20260803-194919/evidence/tool-095-formal-194919-green.md`。

五级裁决 `TOOL-095=G1/F2/A5/C4/G2` 已写入 COVERAGE，`TOOL-095` 行为 `✓✓✓✓✓`。五格写账后按机制触发的 `gap-too-fast`、`pass-burst` 与 `discovery-collapse` 已依据正式 session、逐格复审记录 `tool-095-ledger-alarm-reaudit.md`、anchors 10/10 和五通道原始 journal ack；正式 `export RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3; alarms.py check` 为 `clean (510 judgments)`。正式 fixture 的三条 conversation 与两个 memory 已通过真实 API `DELETE=204`、列表为空清理；唯一 workspace 因最后 workspace 不可删除约束保留，正式证据和审计行不删除。

`TOOL-088 edit_document` 首轮至第七轮真实观察冻结七条红：reasoning placeholder 泄漏；tags 被发成 JSON 字符串后失败；同一用户意图被拆成两次 edit；重复 search 进入失败循环；hosted provider 对 tags 做双重编码；失败 search 后没有稳健恢复；以及 provider 将 `search_documents` 发成 filesystem-shaped `path/pattern` 参数。七份红证据均保留、不计绿。

stop-and-fix 修复 loop 的 per-Run tool ledger（成功 safe call 只抑制重复、不结束回合；失败 safe call 可重试；危险/越界调用仍按保护规则停回合），增加 `search_documents` 的窄兼容层（仅把 provider 的非空 `path/pattern` 当文档库 query，绝不读 filesystem；空形状返回有界文档页），增加 `edit_document.tags` 对一层 JSON 编码数组的精确兼容解码，并收紧 prompt/schema 为单一 canonical edit、完整 search 后逐字使用 opaque `doc_` ID。同步 loop/document/chat 测试、领域/API 文档与工具抽取清册；定向 Go tests、docs verify 和 diff check 通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-155506` 使用新二进制、真实 Flutter App、真实受管 gateway、真实 onboarding、Computer Use、140.740000s 窗口录屏、backend/frontend journals、三路独立 SSE witness 和 LLM tap 重跑。用户目的真实完成：root `/Release Atlas Final` 被完整编辑，description/body/tags 与意图一致，child 自动继承新路径；wire 只有一次成功 `search_documents`、一次成功 `edit_document`、一次成功 child search，无 retry/失败活动/重复 mutation。SQLite/REST、tool result、UI 与五通道交叉一致；messages durable `1..27`、notifications `1..5` 连续，LLM 响应全 200，backend/frontend 错误扫描 clean。正式证据为 `evidence/tool-088-formal-155506-green-edit-document.md`，五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-089 move_document` 首轮 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-162904` 冻结为红：真实 App 在 true-cycle 拒绝后把同一 document/parent pair 重复发起，且 UI 将 terminal duplicate 渲染成误导性的第二张 `Not run` 卡。红证据保留、不计绿。stop-and-fix 增加不改变 S18 五方法接口的 `RepeatTerminaler` 可选终态标记；per-Run ledger 区分安全失败可重试、保护调用停回合和 terminal cycle rejection；前端只隐藏 terminal duplicate 噪声但保留 durable/SSE/audit 证据。同步 move 工具描述/schema、后端/前端领域文档、工具抽取清册、本地 Go/Flutter 回归测试和中英文案。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-164319` 使用修复后二进制、真实 onboarding、真实 Flutter App、真实受管 gateway、Computer Use、546.920000s 封口录屏、backend/frontend journals、三路独立 SSE witness 和 LLM tap 重跑。正向路径一次将 `Source Section` 移入 destination position 0，一次移回 root position 2 并只读 destination 一次；负向路径一次将其移入自身 descendant，后端 terminal reject、无 mutation，UI 只显示一张清楚的红色 `Move rejected`。SQLite 的 seq `3/4`、`9/10`、`12/13`、`18/19`、最终 parent/position/path 与 UI/tool result/wire 一致；SSE 452 frames、61 durable、无 gap，LLM 全 200，backend/frontend 无未解释红线。正式证据为 `evidence/tool-089-formal-164319-green.md`，账本复审为 `tool-089-ledger-alarm-reaudit.md`；五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-090 delete_document` 首轮 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-170003` 冻结为红：真实 App 的后端 not-found 软失败与最终 prose 都正确，但工具卡仍显示 `Deleted document doc_missing_delete_090`，并保留成功软删注记。修复为 completed payload 的 not-found 重分类：失败动词、琥珀原始证据、自动展开且不显示成功注记；同步前端回归、Document/Chat 文档和工具清册。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-170748` 使用新二进制、真实 onboarding、真实 Flutter App、真实受管 gateway、Computer Use、234.611667s 封口录屏和五通道台架重跑。正向一次 exact search + 一次 delete，root/child/deep 三行同一 tombstone 时间、Standalone 活文档不受影响；负向一次 fabricated missing ID 无 mutation，工具卡显示 `Delete document failed` 和原始 not-found warning；Library 只投影 Standalone。SQLite/REST/UI/tool result/LLM wire 一致；SSE 298 frames、messages durable `1..36`、notifications `1..7` 单调、无 gap，LLM 全 200，backend/frontend 无未解释红线。正式证据为 `evidence/tool-090-formal-170748-green.md`，红证据为 `tool-090-formal-170003-red-not-found.md`，账本复审为 `tool-090-ledger-alarm-reaudit.md`；五级 `G1/F2/A5/C4/G2` 已落账，警报复审后 `clean (485 judgments)`。

统一长门禁首轮由 `testend/scenarios/TestContractDocsAtt_DocumentChildrenDuplicateMove` 捕获旧断言：测试仍要求 `/documents?parentId` 一次返回 55 个子节点，而现行实现与 `api.md` 已是默认 50、opaque cursor 分页；未修改生产语义，修正 testend 为 50+5 续页、无重复、顺序和非法 cursor 断言，并补 `/documents/tree` 整树投影断言。定向回归及随后完整 `mise exec -- go test ./...`（testend，`scenarios 319.089s`）、根目录 `make verify`（backend/frontend/docs/demo）、backend `go test ./...`、锚点 10/10、警报和 `git diff --check` 全部通过。第九批已到 **50 / 50**，统一长门禁已绿，当前工作树审计并提交；下一原子前线为 `TOOL-091 list_attachments`。

`TOOL-081 search_activations` 首轮正式观察冻结三条真实红：模型把 `firingCount` 解释成 trigger 历史累计值；把 `payload.manual=true` 误说成 sensor CEL 阈值通过；修复后 hosted model 以字符串发送 `firedOnly`/`limit`，后端类型拒绝并在 App 留下失败活动与 retry。三份红证据分别保留于 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-112217/evidence/tool-081-formal-112217-red-firingcount-semantics.txt`、`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-112933/evidence/tool-081-formal-112933-red-manual-threshold-causality.txt`、`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-113423/evidence/tool-081-formal-113423-red-hosted-scalar-retry.txt`，均不计绿。

stop-and-fix 在 `activations.go` 增加逐行 `firingCount`/`payload.manual` 语义、严格的 exact bool/decimal scalar string 兼容解码；错误形状仍拒绝。同步 trigger 工具测试、API/domain 文档和抽取清册，`go test ./internal/app/tool/trigger ./internal/app/loop` 与 `git diff --check` 通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-113825` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、314.906667s 窗口录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap 重跑。最终 UI 清楚说明 per-activation fan-out、manual bypass 与 false CEL probe；最终请求序列只有 `search_triggers → search_activations`，无失败请求/retry，五路证据一致，LLM chat/proof 响应全 200，SSE durable seq 单调无重复，backend/frontend 无未解释红线。一次 Computer Use wrapper 超时被单独归类为观察器仪器事件，重启 kernel 后重新取得最终帧，不计产品红。五级 `G1/F2/A5/C4/G2` 已落账。

fixture 收口使用独立本地 API 清理 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-114620`：workflow、trigger、function 和 4 条 acceptance conversation 均 DELETE=204，随后 GET=404、列表为空；SQLite 保留软删审计行及 57 条 activation/1 条 firing。台架进程全部收台，无残留。

`TOOL-083 search_firings` 首轮 formal-138 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-115803` 冻结为红：hosted model 把 `limit` 发成字符串，后端拒绝，App 留下失败活动与 retry。formal-139 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-120111` 在 decoder 修复后又暴露模型把 `pattern` 发给 firing inbox，缺失必填 opaque `triggerId`，再次留下失败活动与 retry；两份红证据均保留不计绿。stop-and-fix 增加 exact decimal `limit` 窄兼容，并在 description/schema/validation 明确必须逐字复制 `triggerId`、先 `search_triggers` 再查询，拒绝 name/pattern/placeholder；同步测试、API 文档与抽取清册。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-120402` 使用新二进制真实复验：三条有效查询均成功，结果为 no-status 1、started 1、skipped 0；空集被解释为合法 no-match。最终 screen.mov `141.861667s`，SSE messages durable `1..39`、notifications `1..2` 单调唯一，LLM 全 200，backend/frontend 无未解释红线；同批重复只读调用由 loop 幂等抑制，无重复 repository 访问。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-120402/evidence/tool-083-formal-120402-green.txt`，五级已落账；三条统计警报经红绿证据重审并 ack，复审说明为 `tool-083-ledger-alarm-reaudit.txt`；TOOL-084 已接续完成，下一前线为 `TOOL-085`。

`TOOL-084 search_documents` 先后冻结四条真实红：filesystem `path/pattern` 形状误投到文档搜索；显式分页返回 cursor 但 schema 没有 cursor；assistant 在同一 tool-call 消息中先流出用户可见答案，导致重复 Page 3；混合搜索的 semantic-only recall 引入无关文档。formal 红证据保留于 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-121222/`、`121822/`、`122316/`、`123034/`、`123622/` 的 `evidence/` 下，均不计绿。

stop-and-fix 收紧 `search_documents` 的文档库语义、`query/limit/cursor` 契约和首调用即携带显式 limit 的规则；补充结果 metadata hydration、精确 cursor 续页、tool-call 消息不得带用户答案的 loop 提示，并让文档关键词搜索显式走 lexical-only，保留 RAG/omni 的 hybrid 行为。同步 Go 测试、chat prompt 测试、文档和工具抽取清册；`go test ./internal/app/chat ./internal/app/tool/document ./internal/app/search`、`make -C docs verify`、`git diff --check` 均通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-124129` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、连续录屏和五通道台架完成：首调用即 `limit=1`，后续两页使用精确 cursor `eyJoIjoiY2UxNGM5MjM4NzRkIiwibyI6MX0` 与 `eyJoIjoiY2UxNGM5MjM4NzRkIiwibyI6Mn0`，总计 3 条目标文档，无 `Noisy Field Notes` 语义误命中；最终 UI 只有一份答案、无失败卡/retry/重复 Page 3。录屏 `187.523333s`，SSE durable seq `1..48` 连续，LLM wire 与 REST/SQLite 交叉一致，backend/frontend 无未解释错误；fixture 清理为 DELETE=204、GET=404、列表为空。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-124129/evidence/tool-084-formal-124129-green-search-documents.txt`，账本复审为 `tool-084-ledger-alarm-reaudit.txt`，五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-085 list_documents` 首轮正式空目录路径在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-130911` 冻结为红：根列表成功后，真实受管网关在旧共享传输的 60 秒响应头预算内没有返回下一步响应，UI 最终显示 `LLM_STREAM_ERROR`，用户拿不到已知的空结果。红证据 `evidence/tool-085-formal-130911-red-empty-folder-header-timeout.md` 保留且不计绿。

stop-and-fix 将共享 LLM 建连响应头预算从 60 秒提高到 120 秒，仅覆盖受管网关冷路由/上游唤醒；`ChatTurnSec`、流式 idle 和 `LLMStreamMaxSec` 保持原边界。补充 `TestNewHTTPClient_SeparatesSetupAndStreamingBudgets`、Chat domain 预算说明，并通过 `go test ./internal/infra/llm`、`git diff --check` 和 docs verify。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-132312` 重新走真实 onboarding、工作区夹具、Flutter App、受管 gateway、Computer Use、窗口录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap。HTTP 夹具证明 Large Collection 的 120 个直接子节点按 `40/40/40` 三页、游标和 `0..119` 顺序完整返回；真实 App 强制 `limit=40` 后执行根列表与三页 cursor，最终 UI 明示 `complete: true`、`hasMore: false`、总数 120、首尾位置 0/119；独立空目录路径显示 `Listed document · empty`，助手回答 zero documents，无失败卡/retry。LLM wire 与 REST 逐字一致，所有响应 200；SSE 三流均连接，两个 conversation 的 durable seq 分别连续 `1..36`、`37..54`；backend/frontend 错误扫描 clean，录屏 `418.840000s` 可读。正式证据为 `evidence/tool-085-formal-132312-green-list-documents.md`，统计复审为 `tool-085-ledger-alarm-reaudit.md`，五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-086 read_document` 的首轮真实文档阅读冻结两条产品红：formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-133944` 中前端把 query-required 的空参数误呈为 `Listed document · failed`，且 hosted model 把 filesystem 的 `path/pattern` 形状投给 `search_documents`；formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-134623` 中模型把文档名称/路径误当作 `read_document.id`，产生一次可见 not-found，再搜索重试。两份红证据分别保留于 `evidence/tool-086-formal-133944-red-search-card-and-model-shape.md` 与 `evidence/tool-086-formal-134623-red-opaque-id-guidance.md`，均不计绿。

stop-and-fix 将 `search_documents` 固定为 query-required search channel，空 query 不再伪装成 list；前端补 `entity_search_verb_test.dart`，并同步 Chat 文档。随后将 `read_document` 的 description/schema 明确收紧为必须逐字复制 `search_documents`/`list_documents` 返回的 opaque `doc_` ID，禁止名称或路径，补 Go contract test 与 document domain 文档；`gofmt`、`go test ./internal/app/tool/document`、Flutter entity-search 定向测试和 `git diff --check` 通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-135027` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、连续录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap 重跑。真实线缆严格为 `search_documents(query)` → `search_tools` → `read_document(id=doc_0628e58b2f3d8c1d)`，没有路径误读、失败卡或 retry；最终画面完整展示文档 path、description、tags、全部标题、中文注记和最终句，视觉布局清楚。REST/SQLite 与 tool result 逐字一致，messages durable seq `1..27` 连续，三流均连接，LLM 响应全 200，backend/frontend 错误扫描 clean；仅保留已知稳定的 Computer Use AXTree observer noise，不计产品红。录屏封口 `159.260000s / 2784x1808 / 60fps`，正式证据为 `evidence/tool-086-formal-135027-green-read-document.md`，账本复审为 `tool-086-ledger-alarm-reaudit.md`，五级 `G1/F2/A5/C4/G2` 已落账。

独立 cleanup session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-135432` 通过本地 API 删除本轮 root/child document 与 acceptance conversation，DELETE 均为 204，随后 GET 均为 404，documents/conversations 列表为空；cleanup 台架已收台，正式 green session 与两份 red session 原样保留。

本次 `gap-too-fast` 与 `discovery-collapse` 不是删除或静默放行：五格脚本动作完成后均依据红 session、绿 session、五通道和夹具事实复审并 ack，红证据仍在盘上；`alarms.py check` 最终 clean。第九批推进到 **30 / 50**，下一前线 `TOOL-087 create_document`，未到第 50 格不跑统一长门禁、不提交。

`TOOL-087 create_document` 的 formal-140938、142906、143806、144710 先后冻结为红：分别发现 placeholder ID 进入用户表格、首次 create 漏掉必填 name、先造空根再删除/编辑且同名子文档重复 mutation、以及用户明确提供的 description/tags 被模型静默漏传。四份红证据均保留、不计绿。stop-and-fix 先修 system prompt 与 loop redactor，再把 create_document 的 LLM schema 收紧为每次必传 name/description/content/tags；未提供后三者必须显式传空字符串/空数组，用户值必须同一 canonical call 原样带上；补 Go loop/chat/document 回归、工具抽取清册与 document domain 文档。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-145421` 使用新二进制、全新数据目录、真实 Flutter App、真实受管 gateway、Computer Use、窗口录屏、backend/frontend journal、三路 SSE witness 和 LLM tap 重跑。真实用户目的完成：root `/Release Atlas` 与 child `/Release Atlas/Ship Checklist` 正确写入，root description 为 `A durable release brief`、tags 为 `release/acceptance/notes`，child description 为 `Release gates to run`，child `parentId` 精确指向 root；最终 UI 只显示两项 Created、无 retry/delete/edit/duplicate/failure，路径和嵌套关系清楚。SSE messages/entities/notifications durable 分别为 `1..26`、`1..4`、`1..4` 连续唯一；LLM wire 两次实际 create 均带齐必填字段且全 HTTP 200；REST/SQLite、tool result、UI 一致，backend/frontend 红线扫描 clean，录屏 `282.973333s`。正式证据为 `evidence/tool-087-formal-145421-green-create-document.md`。

台架已收台，所有五通道 journals 与 screen.mov 保留。锚点校准后，`judge.py` 以最终证据写入 `TOOL-087=G1/F2/A5/C4/G2` 五格，中央账本由 465 增至 **470 judgments**；`gap-too-fast` 与 `discovery-collapse` 因批量裁决节奏开启，已按锚点重校、四份真实红证据、最终绿证据和五通道复审后 ack，`alarms.py check` 最终为 `clean (470 judgments)`。第九批推进到 **35 / 50**，下一前线 `TOOL-088 edit_document`，未到 50 格不跑统一长门禁、不提交。

`TOOL-079 delete_trigger` 首轮正式观察先冻结为红：真实 Computer Use 打开并关闭模型 Popover 后，前端 console 出现 105 行 `Failed to update ui::AXTree, error: 149 will not be in the tree and is not the new root`，画面虽未立即破碎，但 macOS 可访问性树已退化，不能把它归类为“无害日志”。stop-and-fix 在 `frontend/lib/core/ui/an_popover.dart` 为常驻 `OverlayPortal` 增加稳定的 `Semantics(container:true, explicitChildNodes:true)` 外边界，补 `an_menu_test.dart` 回归，并同步 chat feature/testend 文档；`flutter test` 14/14、`frontend/make verify` 5174 项、`docs/make verify`、相关 Go 测试和 `git diff --check` 全部通过。

负向 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-073913` 证明真实危险 gate 的 Deny 不执行 mutation：trigger 主行仍在、没有 deleted touchpoint，UI 明确显示拒绝。正向 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-101120` 使用修复后二进制、真实 Flutter App、真实受管 gateway、Computer Use 和连续录屏完成 Allow：gate 文案具体说明主行不可恢复、listener 停止、关系影响与历史保留；UI 只出现一次 `delete_trigger` 和一次 Allow，最终显示 `Deleted trigger ... · deleted`。SQLite/REST 证明主行以 `deleted_at` 保留审计、正常读取不可见、activation/firing 为 0、created/deleted 两条 touchpoint 成对存在；LLM wire 恰有一次 canonical delete call，SSE durable messages `1..13` 连续，backend/frontend 无未解释运行时红线，录屏封口为 `838.035000s / 2784x1808 / 60fps`。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-101120/evidence/tool-079-formal-green-delete-trigger.txt`；五级 `G1/F2/A5/C4/G2` 已落账，当前中央账本为 425 judgments。

`TOOL-080 fire_trigger` 首轮真实暂停负向冻结为红：助手把暂停清除动作错误指向 `edit_trigger`，而该工具不能恢复 paused 状态；红证据保留在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-103209/evidence/tool-080-red-paused-wrong-resume-guidance.txt`，不计绿。stop-and-fix 在 `FireTrigger` 工具描述、trigger 领域文档和抽取清册中明确 `TRIGGER_PAUSED`、`edit_trigger` 不可 resume、正确路径为 Resume control 或 `POST /api/v1/triggers/{id}:resume`，并补工具描述守卫测试；`go test -count=1 ./internal/app/tool/trigger ./internal/app/loop` 通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-104036` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、窗口录像、backend/frontend journal、三路独立 SSE witness 和 LLM tap 重跑：active trigger 的正向请求只调用一次 `fire_trigger`，得到 activation `tra_77b6353d19b9ba70`、固定 payload `{manual:true}`、一个 workflow fan-out 和 flowrun `fr_1dfce2fbff3f084b`；暂停负向只调用一次并展示真实错误与正确 Resume/:resume 指引，无 retry、无 `trigger_workflow`、无新 mutation。SQLite/REST 交叉证明恰有一个 activation、一个 firing 和一个 completed flowrun，负向没有第二组行。screen.mov `223.748333s / 2784x1808 / 60fps`，SSE 三流连接/断开无 gap/error，messages durable 至 54、entities 至 2、notifications 至 4，LLM tap 所有响应 200，backend 只有预期 paused WARN，frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-104036/evidence/tool-080-formal-green-fire-trigger.txt`；fixture 随后通过真实 DELETE=204 清理，GET=404，审计行保留。五级 `G1/F2/A5/C4/G2` 已落账，中央账本由 425 增至 430 judgments。

**第八批统一收口（2026-08-03 11:12）。** 根 `make verify` 的 backend/frontend/docs/demo 四子门禁全部通过；显式 `mise exec -- go test ./...` 全部通过；`git diff --check` 和 `alarms.py check` clean。第一次完整 `make testend` 暴露 `TestContractChat_TouchpointSelfReportAndNameBorrow` 在 120 秒内未 terminal：原因是本批把 `delete_function` 提升为不可绕过 dangerous floor，而旧黑盒用例没有批准两道人闸。没有放宽产品安全标准；修复 testend 用例按真实交互依次 resolve 两个 delete gate，定向场景 6.456s 通过，第二次完整 testend `310.401s` 通过。收台后无 `anselm-testend`/`llama-server` 残留进程；本批只剩工作树审计与选择性提交。

`TOOL-077` 的 formal-132 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-062539` 首轮真实 webhook 路径冻结为红：助手正文将 `/api/v1/webhooks/{triggerId}/{path}` 中的 opaque trigger id 脱敏成不可用的 `the requested item`，用户无法复制可工作的 endpoint。formal-133 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-063222` 的 sensor 路径又暴露 hosted model 把 `config.output` 发成对象 map，后端连续拒绝两次后才成功，失败重试污染了用户回合。formal-134 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-063932` 的 fsnotify 路径冻结为红：模型第一次把 `config` 发成字符串，后端正确拒绝，但 Flutter trigger 专用卡直接把字符串强转为 Map，真实 App 出现 `Something went wrong`，`frontend.log` 连续记录 `type 'String' is not a subtype of type 'Map<dynamic, dynamic>?'`。三份红证据均保留且不计绿。

stop-and-fix 分三处完成：`backend/internal/app/loop/redact.go` 让 webhook endpoint 整行保留可用性语义，同时不把机器 id 放进助手正文；`backend/internal/app/tool/trigger/build.go` 将自然语言 sensor output map 稳定规范化为 CEL object literal，并补 Go 守卫测试和 trigger 领域文档；`frontend/lib/features/chat/ui/tool_card_trigger.dart` 对坏 `config`/`events` 形状做安全降级，失败卡继续显示后端真实错误且不回显敏感参数，并补 Flutter widget 回归。`go test ./internal/app/loop`、`go test ./internal/app/tool/trigger`、trigger 定向 Flutter test、Dart analyze 与 `git diff --check` 均通过。

绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-064904` 使用新二进制、真实 onboarding、真实受管 gateway、Computer Use、窗口录像、backend/frontend journal、三路 SSE witness 和 LLM tap 完成四种 source kind：sensor `acceptance_077_sensor_final`（真实搜索 function 后创建，5s、`payload.total > 10000`、输出 total/healthy）；cron `*/5 * * * *`（next fire 可见）；webhook `acceptance-077-hook-final`（精确可复制 POST endpoint 只在工具卡出现）；fsnotify（绝对路径、create+modify、`*.json`）。所有创建均一次成功，工具卡展开字段与产品目的相符，没有 `Something went wrong` 或 Flutter runtime 红线。

五通道交叉核对：screen.mov `297.055000s`；`rig-check` 运行中确认五通道归属和在线；SSE 共 778 帧，messages durable 尾段 `102..116` 单调，entities/notifications 生命周期帧完整；backend 无 WARN/ERROR/panic/FATAL/tool failure，REST 与 SQLite 交叉证明四条 trigger 的 config、outputs、`paused=false`、`listening=false`；frontend 无 FlutterError/未处理异常/渲染错误；LLM bodies 全部经过透明 tap，四条自然语言路径和 sensor 搜索→创建链完整。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-064904/evidence/tool-077-formal-135-green-four-trigger-kinds.txt`。五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，`gap-too-fast` 因五格批量写账被复审并 ack，最终 `alarms.py check` clean。

`TOOL-078 edit_trigger` 的 formal-136 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-065903` 首轮真实 App 冻结为红：托管模型把 `create_trigger.config` 发成 JSON 字符串，后端拒绝并留下失败活动卡，随后 retry 才创建成功；这不是可接受的“模型自己修好了”，因为用户已经看见错误历史。前线冻结后在 `backend/internal/app/tool/trigger/build.go` 增加 create/edit 对称的严格对象解码：原生 object 与精确 JSON 编码 object string 均接受，数组、标量、普通文本、坏 JSON 均拒绝；edit 同时复用 sensor output map→CEL 稳定归一化。补充 trigger Go 回归测试、工具描述、领域文档和清册同步。

formal-137 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-070531` 使用新二进制、真实 onboarding、真实受管 gateway、Computer Use、窗口录像、backend/frontend journal、三路 SSE witness 和 LLM tap 重跑：先创建 `acceptance_078_cron`（`*/10 * * * *`），再一次 edit 改名、描述和表达式到 `*/15`，最后真实验证兼容说明路径并更新到 `*/20`。最终 SQLite 只有一条 trigger，`acceptance_078_cron_renamed`、`Edit acceptance trigger`、`{"expression":"*/20 * * * *"}`、`paused=0` 完整一致；画面只有成功 Created/Edited 活动，没有失败卡、retry 或 Settling 残留，工具卡、活动岛和助手正文一致。模型最后一次虽在 reasoning 中声称要发字符串，LLM wire 仍实际发 native object，这是 schema 约束下的模型编码观察，不冒充字符串路径成功；formal-136 的真实红证据和新 decoder 单测仍保留。

五通道交叉核对：screen.mov `222.758333s` 且 ffprobe 可读；`rig-check` 在运行中确认五通道归属；SSE 共 432 帧，notifications durable `1..2`、messages durable `1..59` 单调唯一，三流均有 `tap=connect`；backend 无 WARN/ERROR/panic/FATAL，health/最终 REST GET 全 200；frontend 无 FlutterError/DartError/RenderFlex/Unhandled/SEVERE/Exception/Lost connection；LLM tap 36 条 journal、10 个 request body、24 个有状态响应全 200。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-070531/evidence/tool-078-formal-137-green-edit-trigger.txt`。五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，批量写账触发的 `gap-too-fast` 已以本 session 完整复核说明 ack，最终 `alarms.py check` clean。

formal-130 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-060503` 首轮真实 Flutter App + 受管网关 + Computer Use 暴露产品红点：`get_trigger` 成功后，助手正文把真实 `trg_...` 内部 ID 复述给用户。红证据 `tool-076-formal-130-red-trigger-id-leak.txt` 保留且未计绿。根因是 `backend/internal/app/loop/redact.go` 的 opaque ID 前缀族只覆盖历史 `tr_`，没有覆盖当前 trigger 的 `trg_`。

stop-and-fix 在所有实体 ID 相关的直接/流式 redaction 族加入 `trg`，并补 `redact_test.go` 的直接路径与 provider chunk 拆分回归；`docs/references/backend/domains/chat.md` 同步当前前缀契约。`mise exec -- go test -count=1 ./internal/app/loop` 通过，rig-up 重新编译新二进制后才重跑，未复用红 binary。

绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-061313` 使用真实 onboarding 创建 `TOOL-076 Trigger Observatory Fixed`，真实受管 gateway、Computer Use、窗口录屏、backend/frontend journal、三路 SSE witness 和 LLM tap 全部接线。fixture 为无监听 cron（`refCount=0/listening=false`）和 active workflow 监听的 webhook（配置路径 `acceptance-076-fixed`、`refCount=1/listening=true`）。三条真实 App 路径均只调用一次 `get_trigger`：live webhook 正确显示 webhook/path/paused=false/refCount=1/listener=true；pause 后正确显示 paused=true/refCount=1/listener=false；全零不存在 ID 路径诚实显示 not found 且不 retry。三条助手正文均不含 `trg_`，精确值只保留在相邻 tool card/审计线缆。

五通道交叉核对：录屏封口 `361.345000s`；messages durable `1..44`、notifications `1..8` 连续无 gap；entities 已连接；LLM challenge/install/models 与 6 个 chat completion 响应全 HTTP 200，业务 tool call 恰为 3 次 `get_trigger`；backend 无 panic/FATAL/未解释错误，唯一 WARN 是刻意不存在 ID 的 `trigger not found`；frontend 无 `Unhandled exception`、`FlutterError`、`Lost connection` 或断言红线，启动器既有 `open returned 1` 已单独标注；assistant durable close 扫描无 `trg_`/其它实体 ID 泄露。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-061313/evidence/tool-076-formal-131-green-trigger-get.txt`，五级 `G1/F2/A5/C4/G2` 已落账；本次 gap-too-fast/discovery-collapse 因同一真实证据包逐级写账而开启，均带复核说明 ack，最终 `alarms.py check` 为 clean。

（TOOL-074 的完整当前记录见 `LOG.md`；本节上方已整体重述最新前线。）

（旧批次状态，当前值以上方整体重述为准。）

| 交付物 | 当前真相 |
|---|---|
| 五通道 conductor | ✅ `rig-{up,check,down}.sh` 亲自托管 App、Flutter console、录像、后端、动态全 workspace SSE tap、LLM tap；D1 端口归属、受管 baseURL 接线、进程身份、journal 与三流连接持续自检。任一通道禁用时不得报验收绿 |
| 帧与 Computer Use | ✅ 屏幕权限、真实交互、MOV 封口、ffmpeg/ffprobe 全通；Computer Use 负责操作与现场截图，连续录像由 conductor 落盘 |
| SSE witness | ✅ `cmd/ssetap` 支持固定 workspace 与动态全 workspace；durable cursor 逐流续传，每帧带 workspace/stream/接收时戳 |
| LLM witness | ✅ `cmd/llmtap` 请求体与响应体逐调用留底；透明核同时保 SSE flush 与 WebSocket upgrade；device-proof 仍签真实受众，不放宽证明消费边界 |
| 测量脚本箱 | ✅ `cmd/measure` 提供 diff/regions/contrast/latency/compare；diff 与 latency 支持 ROI，compare 对源图与视频首帧先做确定性栅格归一并以 `changedFrac` 硬拒大幅构图漂移；合成已知几何守卫绿 |
| CODEX | ✅ [WRK-088](CODEX.md) 八域 33 条法，裁决只能援引法条或测量值，法不够先立法 |
| COVERAGE | ✅ [WRK-089](COVERAGE.md) 已对齐新 main：工具 124 / 端点 257 / 面 114 / 边 353，共 **848 行 × 5 级 = 4240 格**；它是一期覆盖真相源 |
| JOURNEYS | ✅ [WRK-090](JOURNEYS.md) 现有 47 条只作一期路线；400+ 与逐行认领按用户 P12 推迟二期，不阻塞一期按 COVERAGE 驻停清扫 |
| 账本 gate | ✅ `judge.py` 校验证据文件、CODEX 法条、L2 六件五通道证据、三流连接、可读 MOV、开放警报和四小时锚点凭证；任一缺失物理拒收 pass |
| 锚点自校 | ✅ [WRK-091](ANCHORS.md) 冻结 10 个正反锚点；无答案答卷通过才签发绑定题集哈希的四小时凭证，题集变化或凭证过期自动锁 gate |
| 统计警报 | ✅ `alarms.py` 监控裁决过快、速率暴冲、发现率塌方；ack 必须写复审结论，且在出现新裁决前不会拿同一批历史原地复活；新证据到达后重新评估 |
| 操作手册 | ✅ `testend/rig/README.md` 自足描述起、检、停、校准、测量、裁决和警报，任何 agent 无需旧对话即可使用 |
| 产品主循环 | ✅ 已从第一条未裁决格启动；前置真实切片持续覆盖 onboarding、chat、composer、toc、log drawer、Read、Write、Edit、LS、Glob、Grep、Bash、BashOutput、KillShell、ask_user、todo_write、todo_read 以及 function 全生命周期。所有产品语义、错误态、数据真相和视觉问题均按 stop-and-fix 冻结、修复并真实重跑；当前已完成 control、approval、workflow search/get/create/edit/revert/delete、capability-check、trigger/stage/activate/deactivate/kill、flowrun 查询/重放、approval inbox/decision、`search_triggers`、`get_trigger`、`create_trigger` 四种 source kind、`edit_trigger`、`delete_trigger`、`fire_trigger`、`search_activations`、`get_activation`、`search_firings`、`search_documents`、`list_documents`、`read_document`、`create_document`、`edit_document`、`move_document`、`delete_document`、`list_attachments`、`read_attachment` 与 `inspect_media`。TOOL-069 至 TOOL-098 的已知产品缺陷均有红证据、修复、守卫测试和真实复验；当前中央账本 **525 judgments**，锚点有效、警报 clean；第十批 **40 / 50**，原子前线 `TOOL-099 install_mcp_server` 仍未绿，静态 floor 修复后的 Deny formal 已封存，未到 50 格不跑统一长门禁、不提交。 |

**当前执行状态（2026-08-02 00:08）。** `TOOL-050 revert_control` 正式 session 为 `/private/tmp/anselm-rig-formal-110/sessions/20260802-000259`。formal-109 首轮红证据确认 hosted model 首次发送 `version:"1"`，后端拒绝并在 App 留下失败 activity，随后模型 retry 成功；前线冻结后在 control 工具边界增加 exact decimal integer string 解码，公开 schema 仍保持 integer，浮点/布尔/数组/坏字符串继续拒绝，补 control 测试、工具描述和领域文档，定向 Go 测试通过。formal-110 正向真实只执行一次 `revert_control`，wire 的 stringified version 被接受，active pointer 从 v2 移到 v1 `ctlv_c05fb8b13fd7b636`，UI 只有一张成功 `Reverted control … · ↩ v1` activity，正文明确 v2 仍在 history；负向只执行一次 version 999，返回 `control logic version not found`，UI 只有一张失败卡且明确 active v1 unchanged，无 retry/新版本。screen.mov `147.631667s / 2784x1808 / 60fps`，SSE messages `1..29`、notifications `1..7` 连续，entities 已连接，LLM chat completion 全 200，backend 只有刻意负路径 WARN，frontend 无 runtime 红线；fixture/conversation DELETE=204 后 GET=404，台架已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央 300 judgments，锚点有效，警报最终 clean；第六批 4 / 50，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-051`。

**当前执行状态（2026-08-01 23:51）。** `TOOL-049 edit_control` 正式 session 为 `/private/tmp/anselm-rig-formal-108/sessions/20260801-234249`。formal-107 红证据确认同一用户意图被执行成缺 reason 的 v2 与带 reason 的 v3；前线冻结后将非空 `changeReason` 设为 AI schema 必填，并在 mutation 之前以 `CONTROL_CHANGE_REASON_REQUIRED` 拒绝缺失或空白值，补 control 测试与 error-code/领域文档，定向 `go test ./internal/app/tool/control ./internal/app/loop` 通过。formal-108 正向真实只执行一次 `edit_control`，wire 的 stringified branches 使用正确 `port`，reason 为 `acceptance TOOL-049 final fix`，后端创建 v2 `ctlv_34cbcddfc2f6d22a`，UI 只有一个成功 activity 和完整三分支表；负向只执行一次缺 reason 调用，后端返回 `input validation failed: changeReason is required`，UI 显示失败原因和 `Draft unsaved · truth is still the last version`，无 retry，REST active version 仍为 v2、没有 v3。screen.mov `189.023333s / 2784x1808 / 60fps`，SSE messages `1..29`、entities `7..8`、notifications `16..21` 连续，LLM chat completion 全 200，backend 只有刻意负路径 WARN，frontend 无 Flutter runtime 红线；fixture 与 conversation DELETE=204 后 GET=404，台架已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央 295 judgments，锚点有效，警报最终 clean；第六批 3 / 50，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-050`。

**当前执行状态（2026-08-01 23:30）。** `TOOL-048 create_control` 正式 session 为 `/private/tmp/anselm-rig-formal-106/sessions/20260801-232207`。formal-104 的托管模型字符串化 branches 和 formal-105 的 `name`/重复调用问题均先冻结为红并保留证据；修复后定向 `go test ./internal/app/tool/control ./internal/app/loop` 通过。formal-106 真实 App 正向只创建一个 `acceptance_control_fixture_106`，LLM wire 中 `branches` 是 JSON 字符串但 branch 使用正确 `port`，backend decoder 接受后返回 `ctl_a385d713822f5367`、active version `ctlv_fe1349dcbb94cd67`，UI 展示完整有序 `pass/review` 表且无红行；负向同一会话只尝试重复名称一次，返回 `control logic name already exists`，UI 明确显示未创建与错误解释，无 retry。录屏、五通道 journal、正负终帧和证据文件 `evidence/tool-048-formal-106-green.txt` 已封存；screen.mov `230.008333s / 2784x1808 / 60fps`，messages `1..29`、entities `7..8`、notifications `16..20` 连续，LLM chat completion request/response 全 200，backend 仅刻意负向 WARN，frontend 无运行时红线；fixture 与 conversation DELETE=204 后 GET=404，台架已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央 290 judgments，锚点有效，警报最终 clean；第六批已从 1 / 50 推进为 2 / 50，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-049`。

**当前执行状态（2026-08-01 18:16）。** `TOOL-036 search_agent` 已在正式 session `/private/tmp/anselm-rig-formal-20260801-78/sessions/20260801-181026` 完成正向名称命中、空 query 列全库和 identifier-shaped no-match 三条真实 App 路径；五通道证据、三张终帧和 fixture/对话清理事实均保留。该格尚未裁决，因为修复触及共享搜索语义原语，`search_function`、`search_handler` 等旧绿格必须先复验。Goal API 仍为 `blocked` 且不提供恢复操作；不创建重复 Goal、不谎报完成，盘上 `LOOP.md` 仍为 `active`，当前批次 **15 / 50**，下一动作是同类搜索复验。

**当前执行状态（2026-08-01 18:30）。** `TOOL-036 search_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`；共享 `ContentSearch` 影响的 `TOOL-014 search_function`、`TOOL-024 search_handler` 已由 formal session 79 对命中、空 query、identifier no-match 六条路径复验并恢复五级绿。formal-78/79 的五通道、录屏和终帧保留，三条统计警报复审并 ack 后为 `clean (230 judgments)`。本批新完成单格为 **16 / 50**（旧格复验不重复计数），未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-037 get_agent`；Goal API 仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal、不谎报完成。

**当前执行状态（2026-08-01 18:40）。** `TOOL-037 get_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`；formal-80 的严格正向最终字段表完整，负向不存在 ID 单次失败且无 retry，前置 setup 400、Bash 污染和中途未完成截图均不进入绿证据。五通道、视觉终帧、fixture/对话清理回执保留，警报复审并 ack 后为 `clean (235 judgments)`。本批新完成单格为 **17 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-038 create_agent`；Goal API 仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal、不谎报完成。

**当前执行状态（2026-08-01 19:10）。** `TOOL-038 create_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。formal-81 暴露首发 scoped SSE 竞态导致重复 user bubble，已修复普通 send 的 REST head reconcile，并通过 Flutter 37 项定向测试；formal-82 暴露显式 agent description 被托管模型漏发，已收紧工具契约、schema 描述、后端守卫测试和 agent 文档。formal-83 修复后正向 exact metadata 贯穿 LLM wire、entities、REST 和 UI，负向重复名只执行一次并显示可解释失败，无 retry/副作用；formal-84 无 Computer Use 基线确认 frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线，formal-83 动态 AXTree 行归类为观察器噪声。五通道、录屏、终帧、fixture/对话 DELETE→GET 404 和 SQLite `deleted_at` 均保留，警报复审并 ack 后 `clean (240 judgments)`。本批新完成单格为 **18 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线为 `TOOL-039 edit_agent`；Goal API 旧实例仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal。

**当前执行状态（2026-08-01 19:22）。** `TOOL-039 edit_agent` 已完成五级裁决 `G1/F2/A5/C4/G2`。前置冻结并修正 `get_agent` stale description、agent service 注释与领域文档，明确 LLM `edit_agent` partial merge、HTTP `:edit` full snapshot；定向 Go 测试与 docs verify 通过。formal-85 真实 onboarding + managed gateway + Computer Use 正向只改 agent prompt，UI 显示 v1→v2、version ID 和 preserved-fields 说明，REST activeVersion、mount-health `allHealthy=true`、skill/document/function relation 与 SQLite 只有 v1/v2 一致；负向不存在 ID 只执行一次，显示 `agent not found` 与 `Draft unsaved · truth is still the last version`，无 retry。LLM body 的历史 tool_calls 已经逐 body 复核为上下文回放，不是重复执行；backend 仅预期 not-found WARN。五通道录屏 `290.713333s`，LLM 7/9 全 200，SSE durable `messages 1..36`、`entities 1..4`、`notifications 1..15` 无 gap；frontend 除 Computer Use 诱发 AXTree bridge 噪声外无 Flutter/Dart/RenderFlex/Unhandled/Exception，formal-84 无 CU 基线已完成对照。所有 fixture 和 conversation DELETE=204→GET=404，进程已收台，警报复审并 ack 后 `clean (245 judgments)`。本批新完成单格为 **19 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-040 revert_agent`；Goal API 旧实例仍为不可恢复的 `blocked`，盘上 `LOOP.md` 保持 `active`，不创建重复 Goal。

**Day 0 已完成。** 主循环配置为从 COVERAGE 第一条未裁决格开始，遵守“台架先绿 → 锚点解锁 → 旅程走线
**当前状态：** 第九批 `TOOL-081..090` 已完成 50/50、统一长门禁全绿并提交 `32b33499`；下一前线为 `TOOL-091 list_attachments`。
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
