---
id: WRK-093
type: working
status: active
owner: "@weilin"
created: 2026-08-01
reviewed: 2026-08-02
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

## 当前前线（2026-08-04，TOOL-110 已收口）

统一长门禁首轮由旧的“一次返回 55 个子节点”契约断言失败；按现行 `/documents` cursor 分页实现修正 testend，保留 `/documents/tree` 一次整树 metadata 断言。第十一批收口时完整 `make testend` 又冻结了一个真实前置问题：`install_mcp_server` 的不可绕过 danger gate 没有被 chat 验收剧本处理，导致回合正确停在 `streaming`；场景现已逐次断言并批准两道人闸，定向场景与完整 testend `go test ./...`（scenarios 292.290s）均通过。最终 `make verify`、backend `go test ./...`、锚点、警报、diff check 待本次提交前执行。

**当前更新。** 第九批已完成统一长门禁并提交 `32b33499`；第十批 `TOOL-091..100` 已完成 **50 / 50**，中央账本 **535 judgments**，长门禁与 `553fa150` 提交均已完成。第十一批 `TOOL-101..110` 已完成 **50 / 50 单格**；中央账本 **585 judgments**。`TOOL-110` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-190256` 证明 Explore 子运行只派发一次且真实返回 `CLAUDE.md` 首标题；非法类型路径经 stop-and-fix 后显示 `validation failed · not started`，无轨迹回放提示，SSE 负向无 `subagent:true` 子消息。五通道、SSE、LLM wire、frontend console 与录屏一致，`rig-check` 全绿；正式证据 `evidence/TOOL-110.md`，警报复审 `evidence/tool-110-ledger-alarm-reaudit.md`。`judge.py` 已写入 `G1/F2/A5/C4/G2`，锚点 10/10，`alarms.py check` clean。完整 testend 已通过；收口时修正了 MCP chat danger-gate 验收剧本，并同步 `docs/references/backend/domains/mcp.md`。当前只剩最终 `make verify`、backend tests、工作树审计和提交，下一原子前线为 `TOOL-111 get_subagent_trace`。

下方既有 TOOL-106 及更早描述均为历史过程记录；恢复执行只以上述当前前线、`README.md` §5.2、`LOG.md` 最新条目和 COVERAGE 当前行作为真相。

`TOOL-106` 的前置红 session 已保留：托管模型数组字符串化导致重复调用、可选元数据省略、以及冲突 Activity rail 的成功/失败混合语义；stop-and-fix 已增加精确兼容解码、完整契约描述和统一失败动词/侧幕状态，定向 Go/Flutter 测试通过。正式证据为 `evidence/tool-106-formal-171941-green.md`；锚点因过期重新完成 10/10 校准，账本 gate 五格已写入，`gap-too-fast` 与 `discovery-collapse` 已用 `evidence/tool-106-ledger-alarm-reaudit.md` 复审并 ack，`alarms.py check` clean，未到 50 格不跑统一长门禁、不提交。

下方既有 TOOL-099/100 与旧批次描述为历史过程记录；恢复执行时以上述当前前线、`README.md` §5.2 和 `LOG.md` 最新条目为准。

`TOOL-098` green session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-100552` 的录屏为 `385.805000s / 2784x1808 / 60fps`；五级 `G1/F2/A5/C4/G2` 已写入 `COVERAGE.md`，行状态 `✓✓✓✓✓`。query `database query` 得 4、unmatchable 得 0 且显示 actionable recovery、unfiltered 得 96 且卡片 `first 30 of 96` 可打开有界 JSON tree；messages `1..48`、notifications `1..6`，LLM/REST/SQLite/UI 对齐，frontend/backend 红线为空。正式证据为 `tool-098-formal-100552-green.md`，账本复审为 `tool-098-ledger-alarm-reaudit.md`；观察器一次 30s timeout 已重取最终状态并单独归类，不算产品失败。

修复后 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-104247` 用新 binary 重跑 `TOOL-099` 无 env 路径：真实 UI 显示 `Dangerous · Awaiting your approval`，SSE 为 `tool_call(dangerous) → interaction → resolved(Deny) → tool_result`，没有安装执行或半安装行；录屏 `88.993333s / 2784x1808 / 60fps`，五通道和 `rig-check` 全绿。证据 `evidence/tool-099-formal-104247-red-deny-gate.md` 只证明负路径，不写 `judge.py`。

上一轮 success formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-143238` 已得到 action-time `Allow`，修复后的卡片显示 `Allowed · connected · 2 tools`，动态 `search_tools` 与 `mcp__context7__resolve-library-id` 一次调用成功；但 uninstall cleanup 没有 gate 且发生了错误名重试，红证据 `evidence/tool-099-formal-143238-red-uninstall-no-gate-retry.md` 仍为红。下一步从修复后二进制重跑卸载，必须证明 `dangerous → interaction`、一次调用、失败名不重试和最终持久化清理。

`TOOL-097` green session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-095429` 的录屏为 `173.423333s / 2784x1808 / 60fps`；五级 `G1/F2/A5/C4/G2` 已写入 `COVERAGE.md`，行状态 `✓✓✓✓✓`。真实 durable card 显示六个默认角色、`Anselm Free` 脱敏 key 与 `ok` 状态、端点、`anselm-auto` 的 `1M/16.4k/image · video` 能力及 native option；messages durable `1..14`、notifications `1..2`，LLM wire/REST/SQLite/UI 对齐，frontend/backend 红线扫描为空。红证据为 `tool-097-formal-094444-red-thin-card.md`，账本复审为 `tool-097-ledger-alarm-reaudit.md`；第十批不因单格完成提前跑长门禁或提交。

`TOOL-095` 的产品结论：创建写入 `source=ai,pinned=false`；更新真实 `source=user,pinned=true` 记忆后只改变 description/body，策展与作者归属保留；非法 slug 原样拒绝并以红色 `Not saved` 显示具体规则，绝不静默改名或重试。SSE messages durable `1..42`、notifications `1..9` 连续，LLM 24 个状态条目全 200，backend/frontend journal clean。五格写账触发的 `gap-too-fast`/`pass-burst`/`discovery-collapse` 已在 `tool-095-ledger-alarm-reaudit.md` 中逐格复核后 ack。

`TOOL-093 inspect_media` formal green：红 session 暴露 fresh media turn 把 schema 示例 `att_...` 当成真实附件 ID，先造成一次失败调用；修复后，`history.go` 在 model-only `<uploaded_attachments_for_tools>` 目录提供按媒体顺序的精确 ID，同时 inspect schema/description 移除可复制示例值。真实 App 在 665.508333s 录屏中完成 image default vision、tiles、crop、text query、audio range、video range 六条路径；没有失败卡、placeholder 参数或伪造 transcript/scene/越界视觉结论。视频模型重复请求由 loop `Duplicate tool call suppressed`，未二次执行。messages `1..97`、notifications `1..2` 连续，LLM `58×200/8×201`，backend/frontend clean；正式证据为 `evidence/tool-093-formal-191935-green.md`，复审为 `tool-093-ledger-alarm-reaudit.md`，五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-092 read_attachment` formal green：首轮 hosted caller 将 canonical `id` 误发成 `attachmentId`，真实失败卡被冻结；修复 schema/description 的 `id` 规范并增加受管别名归一化后，真实 App 一次完成小文本正文读取、长文 `index/offset/query`、越界 offset 自纠和 PNG 媒体描述符降级。长文索引 `19 chunks / 145689 chars`，query 只有一个有界命中；图片明确指向 `inspect_media`，不伪造像素结论。主录屏 `432.071667s / 2784x1808 / 60fps`，重开 companion `35.160000s`；messages durable `1..111`、notifications `1..2` 无 gap，LLM 42×200/2×201，backend/frontend clean。正式证据为 `evidence/tool-092-formal-184402-green.md`，账本复审为 `tool-092-ledger-alarm-reaudit.md`，五级 `G1/F2/A5/C4/G2` 已落账。

第八批已完成 **50 / 50** 并提交 `31ad1e72`；第九批已完成 **50 / 50**，中央账本 **485 judgments**。第十批正式账本推进到 **500 judgments**，anchors 10/10 有效，正式 alarms clean；`TOOL-091` 的空/正向路径、`TOOL-092` 的文本/长文/媒体路径与持久化重开、`TOOL-093` 的六条 inspect_media 路径均已封存。一次未 export `RIG_HOME` 的试写误归默认账本，已重放到正式根并在台架手册和 LOG 记录；下一原子前线为 `TOOL-094 read_memory`。

`TOOL-091 list_attachments` formal green：空 workspace 一次真实 `list_attachments` 返回 empty；上传一个 91-byte plain-text fixture 后一次真实 `list_attachments` 返回一条 live metadata。SQLite 与 SSE close/tool result/LLM wire/UI 的 filename、kind、MIME、size、createdAt 一致；messages durable `1..29` 无 gap；工具卡逐字段展示本地化上传时点，正文表格由 redactor 指向附件卡，避免全局 timestamp privacy boundary 与产品可用性冲突。录屏 `346.391667s / 2784x1808 / 60fps`，backend/frontend scan clean；五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-088 edit_document` 的七轮首测红证据覆盖 reasoning placeholder、tags 编码、拆分 mutation、重复 search、provider 双重编码、失败 search 恢复和 filesystem-shaped search 参数。stop-and-fix 修复 per-Run safe-call ledger、search_documents 的窄 provider compatibility、tags 一层 JSON 编码解码，以及单一 canonical edit/opaque ID prompt 契约；测试、领域/API 文档和抽取清册同步。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-155506` 以新二进制、真实 onboarding、真实 Flutter App、受管 gateway、Computer Use、录屏和五通道台架重跑：一次 search、一次 edit、一次 child search，用户编辑目的完成，root rename 后 child path 正确级联；无失败活动、retry 或重复 mutation。REST/SQLite/tool result/UI 一致，messages `1..27`、notifications `1..5` 连续，LLM 全 200，backend/frontend clean，录屏 `140.740000s`。正式证据为 `evidence/tool-088-formal-155506-green-edit-document.md`，五级 `G1/F2/A5/C4/G2` 已落账；下一前线 TOOL-089。

`TOOL-089 move_document` 首轮 formal `20260803-162904` 冻结为红：true-cycle 后重复同一 pair，且前端把 terminal duplicate 渲成第二张误导性的 `Not run` 卡；红证据保留。stop-and-fix 增加可选 `RepeatTerminaler` 终态标记、per-Run terminal ledger、terminal duplicate 前端隐藏、cycle-specific failure card 与双语/领域/抽取清册同步，S18 五方法接口不变。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-164319` 使用修复后二进制和真实 App 重跑三条产品路径：position 0 移入、position 2 移回 root 并单次 list、移入 descendant 的 terminal cycle rejection。SQLite seq `3/4`、`9/10`、`12/13`、`18/19`，最终 tree、UI、REST/tool result、LLM wire 一致；546.920000s screen.mov 可读，SSE 452 frames/61 durable/无 gap，LLM 全 200，backend/frontend 无未解释红线。正式证据为 `evidence/tool-089-formal-164319-green.md`，复审为 `tool-089-ledger-alarm-reaudit.md`；`G1/F2/A5/C4/G2` 已落账。

`TOOL-090 delete_document` 首轮 formal `20260803-170003` 冻结为红：后端 not-found 软失败和最终 prose 正确，但工具卡显示成功删除。修复为 completed not-found payload 的失败重分类、琥珀原始证据与自动展开；同步前端测试、Document/Chat 文档和工具清册。formal green `20260803-170748` 以新二进制和真实 App 重跑 exact search + cascade delete、missing-ID no-op 负路径及 Library 投影；234.611667s screen.mov 可读，SQLite/REST/UI/LLM wire 一致，SSE 298 frames、messages `1..36`、notifications `1..7` 单调、无 gap，LLM 全 200，backend/frontend clean。证据为 `evidence/tool-090-formal-170748-green.md`，复审为 `tool-090-ledger-alarm-reaudit.md`；`G1/F2/A5/C4/G2` 已落账，中央账本 485，警报 clean。第九批 **50 / 50**，当前跑统一长门禁；下一前线 TOOL-091。

`TOOL-081 search_activations` 首轮冻结三条真实红：`firingCount` 被解释为历史累计、`payload.manual=true` 被解释为 CEL 阈值通过、以及 hosted model 的字符串标量导致后端拒绝和可见 retry。修复为 per-activation fan-out/manual bypass 语义、exact bool/decimal scalar string 窄兼容，测试、API/domain 文档和抽取清册同步；三份红证据均保留不计绿。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-113825` 用真实 Flutter App、受管 gateway、Computer Use、314.906667s 录屏、三路 SSE witness、backend/frontend journal 和 LLM tap 完成复验：最终 UI 因果解释正确，请求序列无失败/retry，五通道一致，SSE durable seq 单调，LLM 响应全 200，backend/frontend 无未解释红线。fixture 通过独立本地 API session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-114620` DELETE=204→GET=404 清理，SQLite 审计保留，台架已收台；五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-082 get_activation` 使用 formal session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-115120` 读取真实历史 activation 与不存在 ID：正向 200，负向 404；UI 如实展示 manual fan-out、缺失 optional fields 和 authoritative not-found，无 retry。screen.mov `179.710000s`，SSE durable messages `1..18`、notifications `1..2` 单调，LLM 全 200，backend 仅预期 not-found WARN，frontend clean。正式证据为 `evidence/tool-082-formal-115120-green.txt`；首次 L5 因证据文件瞬时不可见而被 gate 拒绝，确认落盘后幂等补写，复审说明已记录；五级落账。

`TOOL-083 search_firings` 的两轮红分别暴露 hosted model 字符串化 `limit` 和把 `pattern` 当作必填 `triggerId` 的引导错误；修复为 exact decimal limit 窄兼容，以及 description/schema/validation 的 exact opaque triggerId 契约，补测试、API 文档和抽取清册。formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-120402` 三条有效查询无失败/retry，结果 1/1/0，空 skipped 是合法 no-match；screen.mov `141.861667s`，SSE durable messages `1..39`、notifications `1..2` 单调，LLM 全 200，backend/frontend clean。正式证据为 `evidence/tool-083-formal-120402-green.txt`，三条警报已按红绿证据复审 ack，五级落账。

`TOOL-084 search_documents` 先后冻结四条真实红：filesystem `path/pattern` 形状误投到文档搜索；显式分页返回 cursor 但 schema 没有 cursor；assistant 在同一 tool-call 消息中先流出用户可见答案，导致重复 Page 3；混合搜索的 semantic-only recall 引入无关文档。formal 红证据保留于 `sessions/20260803-121222/`、`121822/`、`122316/`、`123034/`、`123622/` 的 `evidence/` 下，均不计绿。

stop-and-fix 收紧 `search_documents` 的文档库语义、`query/limit/cursor` 契约和首调用即携带显式 limit 的规则；补充结果 metadata hydration、精确 cursor 续页、tool-call 消息不得带用户答案的 loop 提示，并让文档关键词搜索显式走 lexical-only，保留 RAG/omni 的 hybrid 行为。同步 Go 测试、chat prompt 测试、文档和工具抽取清册；`go test ./internal/app/chat ./internal/app/tool/document ./internal/app/search`、`make -C docs verify`、`git diff --check` 均通过。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-124129` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、连续录屏和五通道台架完成：首调用即 `limit=1`，后续两页使用精确 cursor `eyJoIjoiY2UxNGM5MjM4NzRkIiwibyI6MX0` 与 `eyJoIjoiY2UxNGM5MjM4NzRkIiwibyI6Mn0`，总计 3 条目标文档，无 `Noisy Field Notes` 语义误命中；最终 UI 只有一份答案、无失败卡/retry/重复 Page 3。录屏 `187.523333s`，SSE durable seq `1..48` 连续，LLM wire 与 REST/SQLite 交叉一致，backend/frontend 无未解释错误；fixture 清理为 DELETE=204、GET=404、列表为空。正式证据为 `evidence/tool-084-formal-124129-green-search-documents.txt`，账本复审为 `tool-084-ledger-alarm-reaudit.txt`，五级 `G1/F2/A5/C4/G2` 已落账。

`TOOL-085 list_documents` 首轮正式空目录路径在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-130911` 冻结为红：旧 60 秒响应头预算让 UI 最终显示 `LLM_STREAM_ERROR`，用户拿不到已知空结果；红证据保留且不计绿。stop-and-fix 将共享建连响应头预算提高到 120 秒，保持 ChatTurnSec、流式 idle 和 LLMStreamMaxSec 不变，并补 transport 单测与 Chat domain 说明。formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-132312` 真实完成 Large Collection `40/40/40` 游标分页和 C · Empty Notebook 空目录路径，UI 明示 `complete:true`、`hasMore:false`、总数 120、首尾 0/119 及 `Listed document · empty`；LLM wire/REST 一致、全 200，SSE conversation durable `1..36`、`37..54`，backend/frontend clean，录屏 `418.840000s`。证据为 `evidence/tool-085-formal-132312-green-list-documents.md`，警报复审为 `tool-085-ledger-alarm-reaudit.md`，五级已落账；第九批推进到 **25 / 50**，下一前线 `TOOL-086 read_document`，未到第 50 格不跑统一长门禁、不提交。

`TOOL-086 read_document` 先后冻结两条真实红：formal-133944 的 query-required 空参数被前端误呈为 `Listed document · failed`，且模型把 filesystem `path/pattern` 形状投给 `search_documents`；formal-134623 的模型将文档名称/路径误当 opaque `read_document.id`，产生一次可见 not-found 后才搜索重试。修复为前端 search-only channel、以及 `read_document` description/schema 的 exact opaque `doc_` ID 契约，并同步 entity-search/document 测试与 domain docs。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-135027` 真实 Flutter App + 受管 gateway + Computer Use 重跑，wire 严格为 `search_documents` → `search_tools` → `read_document`；最终 UI 完整展示 path、description、tags、全部标题、中文注记和最终句，无失败卡/retry。REST/SQLite、tool result、SSE messages durable `1..27`、LLM 全 200、backend/frontend journal 一致，录屏 `159.260000s / 2784x1808 / 60fps`；正式证据为 `evidence/tool-086-formal-135027-green-read-document.md`，警报复审为 `tool-086-ledger-alarm-reaudit.md`，五级已落账。cleanup session `20260803-135432` 已将本轮 fixture DELETE=204→GET=404，列表为空，台架已收台；第九批推进到 **30 / 50**，下一前线 `TOOL-087 create_document`，未到 50 格不跑统一长门禁、不提交。
formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-135027` 真实 Flutter App + 受管 gateway + Computer Use 重跑，wire 严格为 `search_documents` → `search_tools` → `read_document`；最终 UI 完整展示 path、description、tags、全部标题、中文注记和最终句，无失败卡/retry。REST/SQLite、tool result、SSE messages durable `1..27`、LLM 全 200、backend/frontend journal 一致，录屏 `159.260000s / 2784x1808 / 60fps`；正式证据为 `evidence/tool-086-formal-135027-green-read-document.md`，警报复审为 `tool-086-ledger-alarm-reaudit.md`，五级已落账。cleanup session `20260803-135432` 已将本轮 fixture DELETE=204→GET=404，列表为空，台架已收台；第九批推进到 **30 / 50**，下一前线 `TOOL-087 create_document`，未到 50 格不跑统一长门禁、不提交。

`TOOL-087 create_document` formal-140938、142906、143806、144710 先后冻结为红：分别发现 placeholder ID 进入用户表格、首次 create 漏掉必填 name、先造空根再删除/编辑且同名子文档重复 mutation、以及用户明确提供的 description/tags 被模型静默漏传。四份红证据均保留、不计绿。stop-and-fix 修复 system prompt、loop redactor，并把 LLM schema 收紧为每次必传 name/description/content/tags；未提供后三者显式传空字符串/空数组，用户值同一 canonical call 原样带上；Go loop/chat/document 回归、工具清册与 document domain 文档同步。

formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-145421` 真实 Flutter App + 受管 gateway + Computer Use + 五通道重跑：root `/Release Atlas` 与 child `/Release Atlas/Ship Checklist` 正确写入，root description/tags 与 child description 均与用户输入一致，child `parentId` 精确指向 root；最终 UI 只显示两项 Created，无 retry/delete/edit/duplicate/failure，路径和嵌套关系清楚。SSE durable messages/entities/notifications 为 `1..26`/`1..4`/`1..4` 连续唯一，LLM 两次实际 create 均带齐必填字段且全 HTTP 200，REST/SQLite/tool result/UI 一致，backend/frontend clean，录屏 `282.973333s`。证据为 `evidence/tool-087-formal-145421-green-create-document.md`；台架已收台。`judge.py` 写入五级，中央账本由 465 增至 **470 judgments**；两条统计警报按锚点重校、四份红证据和五通道复审后 ack，`alarms.py check` clean。第九批推进到 **35 / 50**，下一前线 `TOOL-088 edit_document`，未到第 50 格不跑统一长门禁、不提交。

`TOOL-079` 的首轮 Computer Use 观察在打开/关闭模型 Popover 后产生 105 行 macOS `AXTree` 更新失败，画面没有立即破碎但可访问性树已退化；已在 `an_popover.dart` 为常驻 `OverlayPortal` 增加稳定的 `Semantics(container:true, explicitChildNodes:true)` 边界，补 14/14 Flutter 回归并通过 frontend 5174 项、docs verify、相关 Go tests 和 diff 检查。负向 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-073913` 的 Deny 未执行删除；正向 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-101120` 的 Allow 只执行一次 delete，UI 显示主行不可恢复、listener 停止、关系影响和审计历史保留，SQLite/REST、SSE、LLM wire、backend/frontend journals 与 `838.035000s / 2784x1808 / 60fps` 封口录屏一致。五级 `G1/F2/A5/C4/G2` 已落账；正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-101120/evidence/tool-079-formal-green-delete-trigger.txt`。本批仍未到第 50 格，不启动统一长门禁、不提交。

`TOOL-078` formal-136 首轮真实 create 暴露 hosted model 将 `config` 发成 JSON 字符串，后端拒绝、App 留失败活动并 retry；修复后 formal-137 真实 onboarding 先 create cron，再 edit name/description/expression，最终 SQLite 为 `acceptance_078_cron_renamed`、`Edit acceptance trigger`、`*/20 * * * *`、`paused=0`，UI 无失败卡/retry/Settling 残留。五通道证据为 screen.mov `222.758333s`、SSE 432 帧且 messages durable `1..59`、LLM tap 24 个有状态响应全 200、backend/frontend 错误扫描 clean；证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-070531/evidence/tool-078-formal-137-green-edit-trigger.txt`。模型最后一次 reasoning 声称字符串化但 wire 仍是 native object，已如实记录，不将其冒充字符串 wire 成功；真实历史红证据与 decoder 单测继续承担该兼容路径证明。五级 `G1/F2/A5/C4/G2` 已落账，gap-too-fast 按批量写账复审并 ack，当前未到 50 格不跑统一长门禁、不提交。

formal-132 暴露 webhook endpoint 被错误脱敏成不可用 placeholder；formal-133 暴露 sensor 自然语言 output map 未规范化导致两次失败重试；formal-134 暴露 fsnotify 坏 config 让 Flutter trigger 卡直接 Map 强转，真实 App 出现 `Something went wrong` 和 Dart type-cast 异常。三份红证据均保留不计绿。修复分别落在 webhook 语义 redaction、sensor map→CEL 规范化及 trigger card 的坏输入容错，并同步 Go/Flutter 回归测试与 domain docs。

`TOOL-080` 首轮暂停负向把恢复动作错误引导到 `edit_trigger`，冻结为红；修复后工具描述、trigger domain 文档、抽取清册和守卫测试共同明确 Resume control/`:resume`，而非 `edit_trigger`。formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-104036` 的正向只执行一次 `fire_trigger` 并产生一个 activation/firing/completed flowrun，暂停负向只执行一次并无 mutation；screen.mov `223.748333s`，SSE 三流无 gap/error，LLM 响应全 200，backend/frontend 扫描 clean。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-104036/evidence/tool-080-formal-green-fire-trigger.txt`，fixture 通过真实 DELETE=204→GET=404 清理，五级已落账。

formal green session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-064904` 使用新二进制、真实 Flutter App、真实受管网关、Computer Use 和五通道台架走通 sensor、cron、webhook、fsnotify 四种 source kind。sensor 真实搜索 function 后一次创建，cron 展示 next fire，webhook 精确 endpoint 只在工具卡可复制，fsnotify 展示路径/事件/pattern；四条均一次成功，最终画面无错误横幅。screen.mov `297.055000s`；SSE 778 帧、messages durable 尾段 `102..116` 单调；backend/frontend 无未解释红线，REST/SQLite/LLM wire/UI 一致。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-064904/evidence/tool-077-formal-135-green-four-trigger-kinds.txt`。五级 `G1/F2/A5/C4/G2` 已落账，gap-too-fast 已按完整复核说明 ack；未到第 50 格，不启动统一长门禁、不提交。

## 历史前线摘要（更新前，2026-08-02 05:27）

第六批已完成 **50 / 50**，中央账本 `350 judgments`，锚点校准有效，警报复审后 clean，统一长门禁和完整 testend 已通过并提交 `8e2c93e4`。`TOOL-055 edit_approval`、
`TOOL-056 revert_approval`、`TOOL-057 delete_approval`、`TOOL-058 search_workflow`、`TOOL-059 get_workflow` 与
`TOOL-060 create_workflow` 已完成 formal 红路径、修复和正负五通道重跑；第七批的 `TOOL-061 edit_workflow` 与 `TOOL-062 revert_workflow` 也已完成 stop-and-fix、正负五通道复验和真实 fixture 清理，当前 **10 / 50**，中央账本 `360 judgments`，下一前线为 `TOOL-063 delete_workflow`，未到第 50 格不启动统一长门禁和提交。
`TOOL-063` 已冻结并完成两轮 stop-and-fix：per-Run exact-once mutation ledger 与“删除主行不可恢复、没有 restore 操作”的产品真相均已有代码、测试和文档证据；formal-139 已由真实 App 走到危险删除人闸，但该不可逆动作尚未获授权，故不判绿、不写账本。当前应从 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-052255` 的保留证据继续，而不是另起台架。
formal-120 的正式证据为 `/private/tmp/anselm-rig-formal-120/sessions/20260802-013952/evidence/tool-055-formal-120-green.txt`。
formal-122 的正式证据为 `/private/tmp/anselm-rig-formal-122/sessions/20260802-020059/evidence/tool-056-formal-122-green.txt`。
formal-123 红证据为 `/private/tmp/anselm-rig-formal-123/sessions/20260802-020830/evidence/tool-057-formal-123-red-gate-fact-and-delete-semantics.txt`；
formal-124 绿证据为 `/private/tmp/anselm-rig-formal-124/sessions/20260802-021702/evidence/tool-057-formal-124-green.txt`。
formal-125 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-022906/evidence/tool-058-formal-125-red-search-fields.txt`；
formal-126 绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-023543/evidence/tool-058-formal-126-green.txt`。
formal-127 绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-024437/evidence/tool-059-formal-127-green.txt`。
formal-128 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-025448/evidence/tool-060-formal-128-red-stringified-ops-retry.txt`；formal-129 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030431/evidence/tool-060-formal-129-red-metadata-omitted.txt`；formal-130 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030934/evidence/tool-060-formal-130-red-metadata-guidance-insufficient.txt`；formal-131 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-031452/evidence/tool-060-formal-131-red-required-metadata-ops-error.txt`；formal-132 绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-032142/evidence/tool-060-formal-132-green-stringified-metadata.txt`。TOOL-061 正向 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-041823`，固定后的正式负向证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-042438/evidence/tool-061-formal-acceptance.txt`。
formal-128 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-025448/evidence/tool-060-formal-128-red-stringified-ops-retry.txt`；formal-129 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030431/evidence/tool-060-formal-129-red-metadata-omitted.txt`；formal-130 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030934/evidence/tool-060-formal-130-red-metadata-guidance-insufficient.txt`；formal-131 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-031452/evidence/tool-060-formal-131-red-required-metadata-ops-error.txt`；formal-132 绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-032142/evidence/tool-060-formal-132-green-stringified-metadata.txt`。TOOL-061 正向 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-041823`，固定后的正式负向证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-042438/evidence/tool-061-formal-acceptance.txt`；TOOL-062 正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-044518/evidence/tool-062-formal-acceptance.txt`。
formal-128 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-025448/evidence/tool-060-formal-128-red-stringified-ops-retry.txt`；formal-129 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030431/evidence/tool-060-formal-129-red-metadata-omitted.txt`；formal-130 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-030934/evidence/tool-060-formal-130-red-metadata-guidance-insufficient.txt`；formal-131 红证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-031452/evidence/tool-060-formal-131-red-required-metadata-ops-error.txt`；formal-132 绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-032142/evidence/tool-060-formal-132-green-stringified-metadata.txt`。TOOL-061 正向 session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-041823`，固定后的正式负向证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260802-042438/evidence/tool-061-formal-acceptance.txt`。
TOOL-057 的最终语义是软删主行、清关系、保留版本历史、执行前经过危险人闸；TOOL-058 的最终语义是直接关键词优先、无直接命中时补语义，并返回 workflow 完整状态字段；TOOL-059 的最终语义是完整返回并展示 active graph、生命周期、并发策略和错误边界。
`TOOL-060` 的最终语义是显式保留 metadata，且在执行边界窄兼容 hosted model 的精确 stringified tags/ops；`TOOL-061` 的最终语义是编辑已有 workflow 时只发一次合法 mutation，缺失实体只呈现一张诚实失败卡；`TOOL-062` 的最终语义是同一调用携带 workflowId/version，兼容 hosted model 的精确 stringified version，失败结果权威且版本历史保留。三者的 REST/SQLite/SSE/UI/wire 一致；正式 fixture 已通过真实 API 删除并验证 GET=404，SQLite 仅留契约要求的最后 workspace 与审计行。锚点重新校准后 gap/discovery 警报均按证据重审并销账，当前第七批 **10 / 50**，下一前线 `TOOL-063 delete_workflow`。

以下为前一状态的历史摘要，保留用于追溯：

第五批已达到 **50 / 50**：`TOOL-033` 至 `TOOL-046` 均完成五级真实裁决，已提交 `90f51edd`。第六批当前 **24 / 50**，中央账本为 `320 judgments`，锚点校准有效，警报复审后 clean。`TOOL-047 get_control` 的 formal-103 已通过；`TOOL-048 create_control` 的 formal-104/105 红证据暴露 stringified branches、branch `name` 误用和同批重复 mutation，修复后 formal-106 已完成正负五通道复核。`TOOL-049 edit_control` 的 formal-107 红证据暴露同一用户意图产生缺 reason 的 v2 与带 reason 的 v3；修复后 formal-108 已完成审计 reason 正负五通道复核。`TOOL-050 revert_control` 的 formal-109 红证据暴露 hosted model 字符串化 version 导致首轮失败与 retry；修复后 formal-110 真实 App 正向只出现一张成功 `↩ v1` activity，负向不存在版本只出现一张失败卡且 active v1 不变。formal-110 录屏 `147.631667s / 2784x1808`，messages durable `1..29`、notifications `1..7` 连续，entities 已连接，LLM chat completion 全 200，backend 仅刻意负向 WARN，frontend 无 Flutter runtime 红线；证据文件为 `/private/tmp/anselm-rig-formal-110/sessions/20260802-000259/evidence/tool-050-formal-110-green.txt`，fixture/conversation DELETE=204 后 GET=404，台架已收台。`TOOL-051 delete_control`、`TOOL-052 search_approval`、`TOOL-053 get_approval` 的 formal-112/113/114 均完成真实 App 正负五通道复核；`TOOL-054 create_approval` 的 formal-115 红证据与 formal-116 修复后绿证据也已封存，formal-116 无失败活动、无 retry、无第二次 mutation，fixture/conversation DELETE=204 后 GET=404。最新证据为 `/private/tmp/anselm-rig-formal-116/sessions/20260802-010803/evidence/tool-054-formal-116-green.txt`。第六批未到 50 格，不跑统一长门禁、不提交；下一前线为 `TOOL-055 edit_approval`。

`TOOL-051 delete_control` 已完成 stop-and-fix 与正式复验。formal-111 红证据暴露空参 `get_control`、缺少可见 destructive approval gate、以及 post-delete fetch；formal-112 真实 App 正向先查关系，再只调用一次 delete，明确停在 `Dangerous / Awaiting your approval` 卡，批准后只出现一张 `Allowed` 删除活动。REST 证明实体 404、关系清空、版本历史保留，workflow capability-check 明确报告缺失 control；正式证据为 `/private/tmp/anselm-rig-formal-112/sessions/20260802-002441/evidence/tool-051-formal-112-green.txt`。screen.mov `293.141667s / 2784x1808`，messages durable `1..24`、notifications `1..7` 单调，entities 已连接，LLM 全 200，backend/frontend journal 无未解释红线。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `305 judgments`，警报逐级复审并串行 ack 后 clean；第六批未到 50 格，不跑统一长门禁、不提交。

`TOOL-052 search_approval` 已完成 formal-113：三个真实 REST fixture 支撑 `refund` 正向命中、随机 query 0 结果、空 query 全量列表三条只读目的；正向结果卡可点击进入 Approval 详情，完整 description/template/rules 可见。wire 三次各只调用一次 search_approval，SSE messages durable `1..40`、notifications `1..7` 单调，entities 已连接，LLM 全 200，backend/frontend 无未解释红线；三条 approval 与两条 conversation 已 DELETE=204 并验证列表为空。证据为 `/private/tmp/anselm-rig-formal-113/sessions/20260802-003731/evidence/tool-052-formal-113-green.txt`。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `310 judgments`，警报复审后 clean；第六批 **14 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-053 get_approval`。

`TOOL-053 get_approval` 已完成 formal-114：真实 onboarding 后建立带 `releaseName`/`riskScore`/`hasMigration` 三字段、完整 markdown template、`allowReason=true`、`timeout=2h`、`timeoutBehavior=reject` 的 approval fixture。正向真实 App 只调用一次 `get_approval`，逐层展示 id/name/description、输入表、完整 template 和 Behavior Settings；缺失 ID 负向也只调用一次，显示明确 not-found 红卡与不编造详情的说明，无 retry。screen.mov `222.798333s / 2784x1808 / 60fps`，messages durable `1..29`、notifications `1..5` 连续，entities 已连接，LLM 响应全 200，backend 仅刻意负路径 WARN，frontend 无 Flutter runtime 红线；approval 与 conversation DELETE=204 后列表为空、GET=404。证据为 `/private/tmp/anselm-rig-formal-114/sessions/20260802-004855/evidence/tool-053-formal-114-green.txt`。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `315 judgments`，警报复审后 clean；第六批 **19 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-054 create_approval`。

`TOOL-054 create_approval` 已完成 stop-and-fix 与正式复验。formal-115 首轮真实 App 冻结为红：托管模型将 `allowReason` 与 `inputs` 字符串化，首轮后端拒绝后 retry，UI 同时留下失败和成功活动；红证据为 `/private/tmp/anselm-rig-formal-115/sessions/20260802-005845/evidence/tool-054-formal-115-red-stringified-scalars-and-retry.txt`。approval 边界随后加入 native/精确 JSON 字符串兼容 decoder，输入对象按 key 稳定排序，公开 schema 未放宽，并补定向测试与领域文档。formal-116 `/private/tmp/anselm-rig-formal-116/sessions/20260802-010803` 以真实 App、受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑：模型只调用一次 `create_approval`，无 retry/search/第二次 mutation；UI 只有一张 Created activity，完整表单结果与 wire/REST 一致。screen.mov `245.026667s / 2784x1808`，messages durable `1..15`，LLM 最终 stop，backend/frontend 无未解释运行时红线；approval/conversation DELETE=204 后列表为空、GET=404。正式证据为 `/private/tmp/anselm-rig-formal-116/sessions/20260802-010803/evidence/tool-054-formal-116-green.txt`。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `320 judgments`，警报复审并串行 ack 后 clean；第六批 **24 / 50**，未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-055 edit_approval`。

`TOOL-055 edit_approval` 的 stop-and-fix 链已完整封存：formal-117 真实会话暴露全量替换字段被托管模型省略，formal-118 暴露空缺 `changeReason`，formal-119 的真实 App 观察暴露 edit 失败 UI 错误复用 create/draft 文案并渲染可操作审批按钮；三轮红事实均不计绿。修复后补齐全量字段/非空审计理由的执行前校验、窄兼容 decoder、工具描述/公开 schema、领域文档和 Flutter regression。

formal-120 `/private/tmp/anselm-rig-formal-120/sessions/20260802-013952` 使用真实 App、受管网关、Computer Use、三路 SSE witness、LLM tap 和连续录屏重跑。正向只调用一次 `edit_approval` 将 v1→v2；负向只调用一次空 `changeReason`，mutation 前拒绝且无 v3、无 retry。screen.mov `417.105000s / 2784x1808 / 60fps`；messages durable `1..29`、entities `1..2`、notifications `1..6` 连续，LLM observed responses 全 200，backend 只有刻意负向 validation WARN，frontend 产品运行时 marker scan clean。严格 `rig-check` 只因 215 行 Computer Use 读取动态 macOS AX 树的已知 `accessibility_bridge.cc` 观察噪声失败；该事实已写入正式证据，没有被隐藏。fixture/conversation DELETE=204 后 GET=404、列表清空，rig-down 已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `325 judgments`，警报复审后 clean；第六批由 **24 / 50** 推进至 **29 / 50**，下一前线为 `TOOL-056`，未到 50 格不跑统一长门禁、不提交。

`TOOL-056 revert_approval` 的 formal-121 `/private/tmp/anselm-rig-formal-121/sessions/20260802-015701` 首轮冻结为红：托管模型把 `version` 发成字符串，后端拒绝并让 App 出现失败活动后准备 retry；红证据已封存，不计绿。stop-and-fix 在 approval 工具边界增加 exact decimal integer string 兼容，公开 schema 仍为 integer，浮点/布尔/数组/坏字符串继续拒绝，并补测试、描述和领域文档。formal-122 `/private/tmp/anselm-rig-formal-122/sessions/20260802-020059` 真实正向只出现一张 `Reverted approval · ↩ v1`，负向 version 999 只出现一张可解释失败卡且 active v1 不变；无 retry、无 v3。录屏 `100.383333s / 2784x1808 / 60fps`，messages durable `1..29`、notifications `1..7` 连续，entities 已连接，LLM observed responses 全 200，backend 只有刻意负向 version-not-found WARN，frontend/AXTree marker scan clean。REST/SQLite/UI/wire 一致，fixture/conversation DELETE=204 后 GET=404、列表清空，rig-down 已收台。五级 `G1/F2/A5/C4/G2` 已落账，中央账本 `330 judgments`，警报复审后 clean；第六批由 **29 / 50** 推进至 **34 / 50**，下一前线为 `TOOL-057`，未到 50 格不跑统一长门禁、不提交。

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

2026-08-02 00:08 (+0800)：`TOOL-050 revert_control` formal-109 首轮真实 App 冻结为红：hosted model 将 `version` 发成字符串，后端拒绝，UI 留下失败 activity，随后 retry 成功；红证据为 `/private/tmp/anselm-rig-formal-109/sessions/20260801-235559/evidence/tool-050-formal-109-red-stringified-version.txt`，不计绿。stop-and-fix 在 control 工具边界加入 exact decimal integer string 解码，公开 schema 仍为 integer，浮点/布尔/数组/坏字符串继续拒绝；补 control 测试、工具描述和领域文档，定向 Go 测试通过。
- formal-110 `/private/tmp/anselm-rig-formal-110/sessions/20260802-000259` 用新二进制、真实 onboarding、真实受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。正向只执行一次 `revert_control`，wire 的 `version:"1"` 被兼容接受，active pointer 从 v2 移到 v1 `ctlv_c05fb8b13fd7b636`；UI 只有一个成功 `Reverted control … · ↩ v1` activity，正文明确 v2 仍在历史。负向只执行一次 version 999，backend 返回 `control logic version not found`，UI 只有一张失败卡且说明 active v1 unchanged，无 retry/新版本。
- 五通道：screen.mov `147.631667s / 2784x1808 / 60fps`；SSE messages durable `1..29`、notifications `1..7` 连续，entities 已连接且无 durable 业务帧，三流各连接一次；LLM 五个 chat completion request/response 全 200；backend 只有刻意负路径 WARN；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception runtime marker。正负终帧和摘要保存在 session evidence 内。control 与 conversation DELETE=204，随后 GET=404，列表无 fixture 残留；rig-down 已封口且无台架进程泄漏。
- 五级裁决 `TOOL-050=G1/F2/A5/C4/G2` 已写入 COVERAGE；中央账本从 295 增至 `300 judgments`，锚点有效，gap-too-fast/discovery-collapse 按 formal-110 证据逐级复审并 ack，最终 `alarms.py check` clean。本批由 **3 / 50** 推进至 **4 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-051 delete_control`。

2026-08-01 23:51 (+0800)：`TOOL-049 edit_control` formal-107 首轮真实 App 冻结为红：托管模型先省略 `changeReason` 生成 v2，再补 reason 生成 v3，同一用户意图产生两次版本 mutation；红证据为 `/private/tmp/anselm-rig-formal-107/sessions/20260801-233447/evidence/tool-049-formal-107-red-missing-change-reason.txt`，不计绿。stop-and-fix 将非空 `changeReason` 加入 AI schema required、工具描述和执行前校验，新增 `CONTROL_CHANGE_REASON_REQUIRED`、control 测试、error-code 与领域文档；定向 `go test ./internal/app/tool/control ./internal/app/loop` 通过。
- formal-108 `/private/tmp/anselm-rig-formal-108/sessions/20260801-234249` 使用新二进制、真实 onboarding、真实受管网关、Computer Use、独立三路 SSE witness、LLM tap 和连续录屏重跑。正向只执行一次 `edit_control`，wire 使用 stringified branches 且每项为正确 `port`，exact reason 为 `acceptance TOOL-049 final fix`，创建 v2 `ctlv_34cbcddfc2f6d22a`；UI 只有一个成功 activity，完整呈现 pass/escalate/review。负向只执行一次缺 reason 调用，backend 在 mutation 前返回 `input validation failed: changeReason is required`，UI 显示失败原因和 `Draft unsaved · truth is still the last version`，无 retry；REST active version 仍是 v2，无 v3。
- 五通道：screen.mov `189.023333s / 2784x1808 / 60fps`；SSE messages durable `1..29`、entities `7..8`、notifications `16..21` 连续，三流各连接一次；LLM 五个 chat completion request/response 全 200；backend 只有刻意负路径 WARN；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception runtime marker。正负终帧和摘要保存在 session evidence 内。control 与 conversation DELETE=204，随后 GET=404，列表无 fixture 残留；rig-down 已封口且无台架进程泄漏。
- 五级裁决 `TOOL-049=G1/F2/A5/C4/G2` 已写入 COVERAGE；中央账本从 290 增至 `295 judgments`，锚点有效，gap-too-fast/discovery-collapse 按 formal-108 证据逐级复审并 ack，最终 `alarms.py check` clean。本批由 **2 / 50** 推进至 **3 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-050 revert_control`。

2026-08-01 23:30 (+0800)：`TOOL-048 create_control` formal-104/105 先后冻结为红：托管模型发出 stringified branches、错误使用 `name`，并在一批 assistant response 中重复 mutation；修复为窄 decoder、明确 `port` schema/描述和同批完全重复调用抑制，定向 control/loop 测试通过。formal-106 使用真实 App + 受管网关 + Computer Use 完成正向一次成功创建和负向一次重复名称拒绝。正向 UI 只有一个成功 activity，完整展示 `pass`/`review` 有序分支；负向显示 `Draft unsaved · nothing was created`、`control logic name already exists`，无 retry。session `/private/tmp/anselm-rig-formal-106/sessions/20260801-232207` 的录屏为 `230.008333s / 2784x1808 / 60fps`，SSE durable `messages 1..29`、`entities 7..8`、`notifications 16..20` 连续，LLM chat completion 全 200，backend 仅预期 duplicate-name WARN，frontend 无运行时红线；fixture/conversation DELETE=204 后 GET=404，台架收台。`TOOL-048=G1/F2/A5/C4/G2` 已落账，中央 clean(290 judgments)，本批 **2 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线 `TOOL-049 edit_control`。

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
