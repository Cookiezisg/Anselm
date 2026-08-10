---
id: WRK-092
type: working
status: active
owner: "@weilin"
created: 2026-08-01
reviewed: 2026-08-10
review-due: 2026-10-30
audience: [human, ai]
landed-into:
---

## 2026-08-11 — EP-204 `GET /api/v1/workspaces/{id}/stats` 收口，批次三十二 50/50

- 产品目的：删除 workspace 前必须显示将被删除的真实内容；空 workspace、未知 workspace、跨 header 误导和 blob 盘点超时都要给出诚实且可解释的结果，不能把未知体积伪装成零。
- 静态审计确认 path id 主体、live row scope、软删除过滤、running/generating 交集和 CAS workspace 边界；500ms bounded walk 超时保留 `blobBytes=-1`，清理后可恢复。定向 Go `workspace/store/blob/handler`、Flutter Settings/workspace 和 rig 单测通过；本格无新增产品代码修复。
- 真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-044429`，数据目录 `/private/tmp/anselm-data-ep204-workspace-stats-20260811`；真实 App 创建 content workspace、conversation、document、29-byte attachment 和 empty comparison workspace，通过 Settings → Workspaces 打开非当前 workspace 的删除盘点。UI 显示 `Taking inventory…` 后收敛到 `1 conversations · 0 entities · 1 documents · 29 B of attachments.`；REST/SQLite/CAS 一致，unknown id 为 `404 WORKSPACE_NOT_FOUND`，conflicting header 不改 path subject，200,000-file fixture 证明超时 `blobBytes=-1` 后恢复 29。
- 五通道封口：录屏 `304.740000s / 2784x1808 / 60fps`，30fps 两段首个可见反馈各 `33.3ms`，全分辨率 diff/contact sheet 已审阅；backend 无应用红线，frontend 仅已知 IMK 平台噪声，ssetap 三流接线且无 gap，llmtap managed bootstrap 原始状态保留，确定性 slice 不伪造 completion。正式按 `G1/F2/A1/C4/G2` 写入 `COVERAGE EP-204=✓✓✓✓✓`，ledger `1710→1715 judgments`，anchors=`10/10`；`gap-too-fast`/`discovery-collapse` 经独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-204-ledger-reaudit.md` ack，未改任何阈值/算法/法典/锚点/gate，最终 alarms clean。
- 批次三十二由 `45→50/50`。根 `make verify`、完整 `make -C backend testend`（`270.044s`）、workspace/search/Flutter 专项回归、rig 单测、coverage、anchors、alarms、diff、进程端口和 fixture 审计均已通过；完整 gate 不因批次完成而降低标准。验收文档已提交 `e83e0fc6`，下一原子前线为 EP-205。

## 2026-08-11 — EP-203 `DELETE /api/v1/workspaces/{id}` 收口，批次三十二 45/50

- 产品目的：用户在删除 workspace 前必须看清真实内容盘点，错误名称不能误删；精确确认后 UI roster、REST、stats、删除后读路径和 durable 状态要共同收敛，最后一个 workspace 必须被产品和 API 双重保护。
- 静态审计确认 handler → service → store 的删除链路、真实 stats 盘点、精确名称确认、当前/最后一个 workspace 的 UI affordance 门控和 `CANNOT_DELETE_LAST_WORKSPACE` 保护均符合契约，未发现需要 stop-and-fix 的产品代码缺陷。
- 真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-042252`，数据目录 `/private/tmp/anselm-data-ep203-workspace-delete-20260811`；Alpha=`ws_c2c0b5ec6ce86f6c`、Beta=`ws_7602c406a380b4d8`、Gamma=`ws_9ca729321b5ccb16`。Beta 的真实 conversation/document 盘点在确认面显示 `1 conversations · 0 entities · 1 documents · 0 B of attachments.`；错误名称不执行，真实焦点+键盘输入精确名称后删除 Beta，再删除非当前 Alpha，最终 roster 只剩当前 Gamma，最后一个没有删除 affordance。
- REST 矩阵覆盖 Beta/Alpha `204`、删除后 list 收敛、详情/stats `404 WORKSPACE_NOT_FOUND`、最后 Gamma `422 CANNOT_DELETE_LAST_WORKSPACE` 且 Gamma 仍可读；backend journal 对应 `04:29:39.420`、`04:30:51.966`、`04:31:06.566`。五通道均真实：backend 无 panic/FATAL/WARN/ERROR，frontend 仅已知 macOS IMK 平台噪声，llmtap 14 个状态均为 `200`，ssetap 记录三流接线及 Beta 的 `document.created`/`conversation.created` durable 帧。
- 封口录屏 `493.813333s / 2784x1808 / 60fps`；Beta/Alpha 删除动作到首个可见反馈均 `16.7ms`，未见黑帧、死 loading、裁切、文字跳变、残留 dialog 或未解释 reflow。完整 REST/UI/五通道/测量证据在 session `evidence/`，正式产品证据为 `EP-203-final-green.md`。
- 定向 Go workspace/store/handler、Flutter Settings/workspace、rig 单测通过；正式以 `G1 / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-203=✓✓✓✓✓`，formal ledger `1705→1710 judgments`，anchors=`10/10`。`gap-too-fast` 与 `discovery-collapse` 已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-203-ledger-reaudit.md` 独立复核并 ack，未改阈值/算法/法典/锚点/gate；`gen_coverage.py --check` 应为 `848/335/0`，`alarms.py check` clean。AX `set_value` 不触发 Flutter `onChanged` 的仪器限制只记台架 caveat，不是产品缺陷。批次三十二由 `40→45/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-204。

## 2026-08-11 — EP-202 `PATCH /api/v1/workspaces/{id}` 收口，批次三十二 40/50

- 产品目的：用户必须能在 Settings → Workspaces 中真实修改工作区名称和颜色，并在 Chat 中切换 Local fetch / Jina proxy；partial PATCH 不得覆盖未改字段，坏输入不得污染持久状态，UI 选中态必须和 API 真相回声一致。
- 静态审计确认 handler 的严格 JSON 解码、显式 id 路由、partial Update 和 name/language/webFetchMode 校验均符合契约，未发现需要 stop-and-fix 的代码缺陷。首轮 AX `set_value` 绕过 Flutter `onChanged`，没有产生 PATCH，已明确丢弃；accepted run 改用真实焦点、键盘输入、颜色点击和 Save。
- 固定五通道 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-040349`，数据目录 `/private/tmp/anselm-data-ep202-workspace-patch-20260811`：真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap、conductor 窗口录屏均由同一 manifest 托管。在线 `rig-check` 的 D1、health、SSE、llmtap、Flutter、console、recorder 全通，收台录屏 `558.061667s / 2788x1808 / 60fps`。
- App 真实 rename/color 后 Alpha GET 回读 `EP202 Patch Alpha Renamed` / `#E2A93B`；Chat 真实点击 Jina 后 GET 为 `webFetchMode=jina`，再点击 Local 后 GET 为 `local`。Beta 的 avatar-only、language-only、webFetch-only、name-only partial 更新均保留未改字段；invalid language、invalid webFetchMode、blank name、unknown field、trailing JSON、unknown id 均得到诚实拒绝，负向 probe 后业务字段未污染。第一版未知 id probe 仅作仪器记录，不冒充字段校验证据。
- 60fps 控件 ROI 测量：颜色 `50.0ms`、Jina `33.3ms`、Local `50.0ms` 首个可见反馈；圆点尺寸、选中 ring、segmented inset 和说明文案对齐，逐帧未见黑帧、死 loading、裁切、文字跳变或 unexplained reflow。backend 无应用级 WARN/ERROR/panic/FATAL；frontend 仅有已知 macOS IMK 平台噪声；ssetap 为 Alpha/Beta 各连接 messages/entities/notifications，llmtap 真实记录 challenge/install/models `200`。
- 定向 Go workspace/store/handler 测试通过；`mise exec -- flutter test ...` 相关 Settings/workspace 测试 `33` 项通过；rig 单测 `6` 项通过。正式按 `G1 / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-202=✓✓✓✓✓`，formal ledger `1700→1705 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848 rows / 334 carried / 0 tombstones`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-202-ledger-reaudit.md` 独立复核并 ack，未改阈值/算法/法典/锚点/gate；最终 `alarms.py check`=`clean (1705)`。批次三十二由 `35→40/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-203。

## 2026-08-11 — EP-201 `GET /api/v1/workspaces/{id}` 收口，批次三十二 35/50

- 产品目的：按 id 单读 workspace 必须回读完整对象；未知和删除后的 id 要给出同一准确的 `404 WORKSPACE_NOT_FOUND`；Settings → Workspaces 的用户可见 roster 与 API 真相必须收敛，且 onboarding/global 读取不能被无关 workspace header 误挡。
- 静态审计确认 handler → `workspace.Service.Get` → store 的显式 id 链路、ORM miss 到 `WORKSPACE_NOT_FOUND` 的翻译和 workspace-exempt 路由均符合产品边界；workspace prefs repository 真实调用同一路径。Go workspace/app/store/handler 定向测试通过。
- 主真实五通道 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-034512`：Computer Use 从空数据目录创建 `EP201 GET Alpha`，打开 Settings → Workspaces；REST 隔离矩阵另建 Beta，Alpha/Beta 单读 `200`、未知 id `404`、无关 header 仍 `200`、删除 Beta 后 `404`、最终 roster 只剩 Alpha。完整矩阵为 `evidence/EP-201-rest-matrix.txt`。
- Beta 被立即删除以隔离负向 fixture，故 backend 唯一相关 DEBUG 是受管开通被 workspace lifecycle cancellation 取消；该行已原样披露并分类为预期 probe 清理，不是 WARN/ERROR，不被隐藏。主 session backend 无 panic/FATAL/WARN/ERROR 应用红线；frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow 红线。
- 补充真实短重放 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-035449` 从空库创建 `EP201 GET Replay`，由同一 conductor 托管真实 Flutter、Computer Use、录屏、三路 SSE、llmtap 与受管网关；在线 `rig-check` 全通，收台录屏 `97.645000s`。
- 逐帧 stop-and-fix 分流：主 session 1fps 中疑似黑帧 `frame-0096`/`0098` 直接查看为正常 Settings → Chat；原始 60fps `95.5–98.5s` 的 `YAVG` 稳定为 `190.546`，确认为抽样/缩略图误导。补充 session 的物理动作前最后稳定 Chat 帧 `frame-0264` 与首个完整 Workspaces 帧 `frame-0265` 用 `measure latency` 得 `16.7ms`、`changedFrac=0.04142`；RPC 调用起点计算出的 `633.3ms` 被明确丢弃，未混入产品时延判定。
- 五通道：两 session 的 SSE witness 均连接 `messages/entities/notifications`；primary/replay LLM tap 分别记录真实 bootstrap `200`，不虚构 completion；frontend 只有已知 macOS runner/IMK 平台噪声；录屏与 Settings roster 无裁切、死 loading、文字跳变、overflow 或未解释 reflow。
- 定向 Flutter Settings/workspace/hot-switch 测试 `15` 项、rig 单测 `6` 项全部通过；`git diff --check` 通过。完整产品证据为主 session `evidence/EP-201-final-green.md`，ledger re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-201-ledger-reaudit.md`。
- anchors `10/10`；`judge.py` 以 `G1/F2/A1/C4/G1` 写入五格，中央账本 `1695→1700 judgments`，COVERAGE `EP-201=✓✓✓✓✓`，`gen_coverage.py --check`=`848 rows / 333 carried / 0 tombstones`。`gap-too-fast` 与 `discovery-collapse` 按独立 re-audit ack，未修改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1700)`。
- 批次三十二由 `30→35/50`；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-202 `PATCH /api/v1/workspaces/{id}`。

## 2026-08-11 — EP-200 `POST /api/v1/workspaces` 收口，批次三十二 30/50

- 产品目的：空库 onboarding 中创建 workspace 后，用户必须立刻知道系统正在准备什么，等待后进入可用 Chat；API caller 的输入边界、免费档异步开通、默认场景播种和最终 roster 也必须收敛为同一份真相。
- 首轮真实探针发现：`{"name":"EP200 Trailing"}{"name":"EP200 Trailing2"}` 被 decoder 接受并返回 `201`，静默丢弃尾随值。前线冻结，修复 `backend/internal/transport/httpapi/handlers/decode.go`，要求 body 恰为一个完整 JSON 值；补 `decode_test.go` 覆盖第二对象、第二个 `null`、垃圾尾巴、合法空白和 optional EOF，并同步 `docs/references/backend/api.md`。
- 产品 stop-and-fix：`workspace_create_control.dart` 的 `_saving` 状态原本存在，但 setup 文案因 `AnimatedOpacity` 条件错误始终透明。现在等待态可见、输入只读、按钮禁用，并补 widget 回归测试，避免用户在受管档准备期间面对无反馈空白。
- 固定版真实五通道 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-032721`：真实 Flutter macOS App + Computer Use 从空 onboarding 创建 `EP200 UI Loading`，另一路 REST 创建 `EP200 API Loading`；真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏均由 conductor 托管。点击后首个可见 setup 反馈为 `16.7ms`，workspace POST `03:28:47.414`、受管 provision/probe `03:28:47.832`、shell roster `03:28:48.217`；录屏 `121.798333s / 2784x1808 / 60fps`。
- 固定版 REST 证据覆盖合法创建、尾随 JSON=`400 INVALID_REQUEST`、空名称、非法语言、未知字段、65-rune 名称和列表收敛；固定版矩阵在 `sessions/20260811-032721/evidence/EP-200-rest-red-fix-replay.txt`，完整产品证据为 `EP-200-final-green.md`，formal re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-200-ledger-reaudit.md`。
- 五通道复核：backend 无 panic/FATAL/ERROR/WARN；SSE witness 发现并连接当前 workspace 的 messages/entities/notifications；llmtap 记录真实 proof challenge/install/models `200`，无伪造 completion；frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow 红线。视觉测量为 `14.68:1` 对比度、`16.7ms` 首反馈、稳定 Chat ROI 无超过 `0.02` 的异常帧差。
- 正式按 `G1 / F2 / A1 / C4 / G1` 写入 `COVERAGE EP-200=✓✓✓✓✓`；formal ledger `1690→1695 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/332/0`。`gap-too-fast` 与 `discovery-collapse` 已用独立 re-audit、红证据、固定版 session、负向矩阵、测量和静态验证 ack；未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (1695)`。批次三十二由 `25→30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线 EP-201。

## 2026-08-11 — EP-199 `GET /api/v1/workspaces` 收口，批次三十二 25/50

- 产品目的：空库 onboarding、真实创建多个 workspace、footer switcher、Settings roster 和当前 workspace 标记必须共同呈现同一份稳定名册；列表顺序在相同创建时间下也不能漂移。删除确认表面本轮走查，但完整 UI 删除收口明确留给 EP-203。
- 首轮静态 stop-and-fix：store 原先只按 `created_at ASC` 排序，相同时间戳会让冷启动首个 workspace 与 roster 顺序不确定。现在固定 `created_at ASC, id ASC`，新增相同时间戳 tie-break 回归，并同步 API/support-services 文档，明确这是 machine-wide、有界、不分页完整名册。
- 真实五通道 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-025525`：全新数据目录、真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap、封口录屏 `320.688333s / 2784x1808`。App 先显示空 onboarding，再真实创建 `EP199 Workspace Alpha`、`EP199 Workspace Beta`、`EP199 Workspace Gamma`，通过 footer switcher 三向切换，在 Settings → Workspaces 观察完整 roster 与当前标记，并打开 Beta 删除确认表面。
- 为避免不可逆 fixture 操作误算为 UI 删除验收，Beta 最终由 session 内直接 REST probe 隔离删除；列表收敛为 Alpha/Gamma，已删除对象 `404 WORKSPACE_NOT_FOUND`。这验证了 endpoint 真相，但不宣称 UI Confirm 删除闭环，后者留给 EP-203。
- 五通道与视觉：backend 无 WARN/ERROR/panic/FATAL，frontend 无 Dart/Flutter/RenderFlex/Unhandled/Exception/runtime 红线；三个 workspace 各自接入 messages/entities/notifications，本 GET-only slice 无虚构业务帧；llmtap challenge/install/models 全真实 `200` 且无伪造 completion。`rig-check` 的 D1、health、SSE、llmtap、Flutter、console、recorder 检查通过；1fps 321 帧逐帧复核 onboarding、Chat、switcher、roster、delete confirmation，无裁切、死 loading、文字跳变或未解释 reflow。原始创建 60fps 片段首个可见反馈 `16.7ms`，深色文字对纯白背景对比度 `14.68:1`，稳定 ROI diff 无异常。完整证据为 session `evidence/EP-199-final-green.md`，formal re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-199-ledger-reaudit.md`。
- 正式按 `measure:workspace-roster-purpose / G1 / A1 / C4 / G1` 写入 `COVERAGE EP-199=✓✓✓✓✓`；formal ledger `1685→1690 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/331/0`。`gap-too-fast` 与 `discovery-collapse` 已依据原始 session、数据库、LLM body、SSE、测量和静态验证逐项复核并 ack，未修改阈值、算法、法典、锚点或 gate；最终 `alarms.py check`=`clean (1690)`。批次三十二由 `20→25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-200。

## 2026-08-11 — EP-198 `PATCH /api/v1/search/settings` 收口，批次三十二 20/50

- 产品目的：机器级搜索设置的部分更新必须不覆盖未提字段、错误时不留下半套配置，并让 embedder/model 变化对所有已索引 workspace 的向量缓存与补算保持一致；真实 App 仍只能呈现它真正拥有的设置入口，不能为内部 endpoint 编造 UI。
- 首轮静态 stop-and-fix：原实现逐项写 `search_meta`，多字段 PATCH 在后写失败时可能半更新；且只 invalidate/kick 当前请求 workspace。新增 `SetMetaBatch` 单事务写入，补 later-write rollback infra 守卫；Service 记录已进入索引的 workspace，机器级设置变化向所有已知 workspace fan-out invalidate/backfill kick。同步 domain/API/search 文档。
- 真实五通道 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-024018`：真实 Flutter macOS App、Computer Use、受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap 和封口录屏 `239.978333s / 2784x1808`。真实 onboarding 创建 `EP198 Search Settings Patch Lab`，再经 sidecar 创建第二 workspace；App 内打开 Settings/Models & keys 和 Settings 搜索确认没有独立 search-settings UI。
- REST/SQLite 事实：两 workspace 初始设置一致；unknown field、非法 embedder、畸形 JSON 均 `400`；空对象为 `200` no-op；`ollamaModel` 与 `ollamaBaseUrl` 可分别 PATCH 且互不覆盖；死端口 Ollama 保持 lexical search；另一 workspace 立即观察到同一 machine-level patch；两个 workspace 各建文档并搜到 lexical hit；空 URL/model 恢复默认，builtin 最终 `engine.ready`。完整 19 项记录在 session `evidence/EP-198-api.json`。
- 五通道与视觉：backend 无 WARN/ERROR/panic/FATAL，唯一 degraded 行是预期 provider-unavailable fallback；两个 workspace 各连接 messages/entities/notifications，只有真实 `document.created` durable frames，没有虚构 settings lifecycle；llmtap 的 challenge/install/models/quota 均为真实 `200`，未把确定性 REST 路径伪报 completion；frontend 无 Dart/Flutter/RenderFlex/Unhandled 红线。onboarding、Chat、Models & keys 抽帧稳定，Settings 主内容 ROI 15 秒间隔 `changedFrac=0`，无裁切、死 loading、reflow 或跳变。
- 正式按 `measure:search-settings-patch-purpose / F2 / A1 / C4 / na` 写入 `COVERAGE EP-198=✓✓✓✓~`；formal ledger `1680→1685 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/330/0`。写账触发的 `gap-too-fast`/`discovery-collapse` 已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-198-search-settings-patch-ledger-reaudit.md` 独立复核并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1685)`。EP-198 隔离数据目录已按授权移入 Trash，session/录屏/journals/evidence 保留；批次三十二由 `15→20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线 EP-199。

## 2026-08-11 — EP-197 `GET /api/v1/search/settings` 收口，批次三十二 15/50

- 产品目的：机器级搜索设置必须在不同 workspace 间保持同一真相；新 Ollama provider 在首次成功响应前不能伪报 ready，失败后要给出可解释状态，同时不能让语义引擎不可达破坏 lexical search。该 endpoint 没有独立用户界面、导航入口或可轮询产物，真实 App Settings 走查后 L5 诚实记 `na`，由父级 Search surface 承担 discoverability。
- 首轮静态 stop-and-fix：Ollama adapter 只要对象存在就被 GET settings 误报 `engine.status=ready`，用户无法区分“已配置”与“上游实际可用”。现在 adapter 初始为 `absent`，一次失败为 `error + lastError`，一次成功为 `ready`，状态读写有锁；GET 不同步探测外部 daemon。补 engine unit/race、service、handler 和真实 testend 回归，并同步 search domain 文档。
- 真实五通道 session `/private/tmp/anselm-rig-ep197-search-settings-20260811/sessions/20260811-021913`：真实 Flutter macOS App、Computer Use、受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap、封口录屏 `401.060000s / 2784x1808 / 60fps`。真实 onboarding 创建 `EP197 Search Settings Lab`，App 内打开 Settings、Settings 搜索和 Models & keys；两个 workspace 通过同一 sidecar 复核 machine-level scope。
- REST/SQLite 事实：初始 builtin/absent；非法 embedder=`400 SEARCH_EMBEDDER_INVALID`；off 在另一 workspace 同步可见；不可达 Ollama 首次 GET 保持 absent，真实文档 + reindex 触发失败嵌入后变 error 并带 connection-refused，搜索仍返回 lexical hit；空 URL/model 与 builtin PATCH 恢复默认。`search_meta` 最终恢复为预期 machine settings，无秘密进入证据。
- 五通道对证：backend 只有预期 provider-unavailable lexical fallback，无应用级 panic/FATAL/未解释 WARN/ERROR；SSE 两 workspace 各自连接 messages/entities/notifications，本 slice 只观察到真实 `document.created` durable notification；LLM tap 的 challenge/install/models/quota 均经真实网关成功，本确定性路径无 completion；frontend 只有既有 macOS launcher/IMK 噪声，无 Dart/Flutter/RenderFlex/Unhandled/runtime 红线。封口帧的 onboarding 与 Models & keys 几何稳定，无裁切、死 loading、错位或 reflow。
- 正式按 `measure:search-settings-purpose / F2 / A1 / C4 / na` 写入 `COVERAGE EP-197=✓✓✓✓~`；formal ledger `1675→1680 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/329/0`。写账触发的 `gap-too-fast`/`discovery-collapse` 已由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-197-search-settings-ledger-reaudit.md` 独立复核并 ack，阈值/算法/法典/锚点/gate 未改，最终 `alarms.py check`=`clean (1680)`。批次三十二由 `10→15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线 EP-198。

## 2026-08-11 — EP-196 `POST /api/v1/search:reindex` 收口，批次三十二 10/50

- 产品目的：索引重建必须是就地的，不能制造搜索空窗；同 workspace 的重复重建要明确冲突，不同 workspace 不能互相阻塞；重建期间的搜索和之后的 Chat grounding 必须仍然完成用户目的。
- 静态核对：实现是 per-workspace single-flight、force-reconcile 就地覆盖词法行、向量失效后后台重嵌；补齐旧 `202` 注释为真实 `204` fire-and-forget 语义，并同步 testend/bootstrap 注释和搜索文档。
- 真实五通道 session `/private/tmp/anselm-rig-ep196-reindex-20260811/sessions/20260811-015322`：真实 Flutter macOS App、Computer Use、受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap、封口录屏 `335.445000s / 2784x1808`。180 篇带 `EP196-REINDEX-TOKEN` 的文档用于重建；同 workspace burst=`204×6 + 409×114`，第二 workspace 同时=`204`，重建期间 24 次搜索均 `200,total=181`。
- Chat 真实 prompt 要求使用 document search 且禁止猜测；LLM wire 真实 `search_documents` 返回 `total=181`，UI tool card 显示 `10 of 181`，助手准确返回 `181` 和 `EP196 Reindex Document 180`。backend 无应用红线，frontend 只有已知 macOS IMK 噪声，两个 workspace 各自三流连接；primary messages `1..14`、notifications `1..183` 连续无 gap。
- 逐帧：30fps submit action=`219`→首个可见反馈 frame=`220`，`33.3ms`、changedFrac=`0.01506`；稳定 transcript ROI 的 `f000400→f000401` 无超过 rig 阈值的 diff。稳定 Chat 帧无裁切、重排、死 spinner 或未解释跳变。
- 正式按 `measure:search-reindex-purpose / F2 / A1 / C4 / na` 写入 `COVERAGE EP-196=✓✓✓✓~`；L5 因该内部 fire-and-forget endpoint 无独立 UI/导航/可轮询产物而诚实记 `na`。formal ledger `1670→1675 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/328/0`。`gap-too-fast`/`discovery-collapse` 经 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-196-reindex-ledger-alarm-reaudit.md` 独立复核并 ack，未改阈值/算法/法典/锚点/gate；最终 `alarms.py check`=`clean (1675)`。EP-196 隔离数据已按授权移入 Trash，session、录屏、journals、evidence 与 formal ledger 保留；批次未满 50 格，不跑统一长门禁、不提交；下一原子前线 EP-197。

## 2026-08-11 — EP-195 GET /api/v1/search 收口，批次三十二 5/50

- 产品目的：用户不仅要能搜到结果，还要能控制类型、标签、inclusive 时间窗和 archived 边界，稳定翻页不重复；异常参数不能静默改变意图；Chat 通过真实 search_documents 必须返回与文档库一致的名称和 snippet。
- 首轮静态 stop-and-fix：malformed RFC3339、倒置 window、非法 includeArchived 原先会被忽略或变成另一种查询。现在 transport/domain 显式返回 SEARCH_INVALID_WINDOW / SEARCH_INVALID_INCLUDE_ARCHIVED，带参数详情并统一 UTC；补 handler、domain/app/infra、black-box testend 回归和 API/search/error 文档。
- 真实五通道 session /private/tmp/anselm-rig-ep195-search-20260811/sessions/20260811-013347：真实 Flutter macOS App、Computer Use、受管 https://api.anselm.website、三路独立 ssetap、backend/frontend journals、llmtap、封口录屏 235.940000s / 2784x1808。三篇带唯一 token 的文档 + 一条 archived conversation 真实验证 omni total/cursor、document/tag/window 分页、false/true archived、cursor filter mismatch、三类明确 422 和 exact-name ranking。
- Chat 真实 prompt 要求使用 document search 且禁止使用 conversation title；UI 稳定出现 Searched document EP195-RANK-TOKEN · 3 found 和三行精确表格，LLM wire 真实记录 search_documents query/result，未发生猜测。backend 无应用红线，frontend 仅已知 launcher/IMK 噪声，三流 durable seq 分别连接且 messages 1..14 单调。
- 逐帧：30fps f000375→f000376 首反馈=33.3ms，全局 changedFrac=0.00495，Composer ROI=0.06062；稳定 table/tool capsule/composer 无黑帧、死 spinner、overflow、reflow。标题 Se 中间态经 SQLite、最终通知、reserved footprint 和 late settle frames 复核为有意 AnTypewriter 揭示，不是截断落库或标题槽跳动。
- 正式按 measure:search-purpose / F2 / A1 / C4 / G1 写入 COVERAGE EP-195=✓✓✓✓✓，formal ledger 1665→1670 judgments，anchors=10/10，gen_coverage.py --check=848/327/0。gap-too-fast/discovery-collapse 经 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-195-search-ledger-alarm-reaudit.md 独立复核并 ack，未改阈值/算法/法典/锚点/gate；最终 alarms.py check=clean (1670)。EP-195 隔离数据已按授权移入 Trash；本条记录当时批次三十二为 5/50，随后由 EP-196 推进到 10/50。

## 2026-08-11 — EP-194 `POST /api/v1/memories/{name}/unpin` 收口，批次三十一 50/50

- 产品目的：取消置顶必须让记忆停止进入后续对话的常驻正文，同时保留记忆、索引可见、可重新置顶，并让 Pinned 过滤和下一轮 Chat 对用户诚实。
- 真实五通道 session `/private/tmp/anselm-rig-ep194-memory-unpin-20260811/sessions/20260811-005136`：真实 Flutter macOS App + Computer Use + `https://api.anselm.website` + 三路独立 ssetap + backend/frontend journals + llmtap，录屏 `229.195000s / 2784x1808 / 60fps`。真实路径为 Unpin → Pinned 空态 → Chat 列出 memory index 名称；没有 `read_memory`。
- 五通道真相：Unpin 与重复 Unpin 均 `200/pinned:false`，REST/file 保留正文与 metadata；notifications durable `1..3` 只记录一次 `memory.updated`，messages durable `1..8` 单调，seq=0 仅为 delta；gateway proof/install/models/chat/auto-title 全 `200`，LLM body 没有完整 unpin-guide 正文；backend/frontend 无应用红线，IMK 为已知 launcher 噪声。
- 逐帧：Unpin `100.0ms`，Pinned 空态 `66.7ms`，Chat 首反馈 `66.7ms`，各有 changed box；原始 60fps 十二帧黑帧复核均为正常空态亮度 `YAVG=189.839/YMIN=16/YMAX=235`，确认不是产品黑屏。完整证据为 session `evidence/EP-194-final-green.md`，formal 警报复核为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-194-ledger-alarm-reaudit.md`。
- 正式按 `measure:memory-unpin-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-194=✓✓✓✓✓`，formal ledger `1660→1665 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/326/0`。`gap-too-fast`、`pass-burst`、`discovery-collapse` 已按原始证据 re-audit 逐条 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1665)`。隔离数据目录按授权移入 Trash；批次三十一达到 **50/50**；root make verify、完整 testend（284.530s）、专项回归、rig 自测、docs/coverage/anchors/alarms/diff、端口/进程和 fixture 审计均已通过，工作树审计后提交，P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-11 — EP-193 `POST /api/v1/memories/{name}/pin` 收口，批次三十一 45/50

- 产品目的：用户在真实 Memory roster 中 Pin/Unpin 时，必须看见可理解、可操作且不会重复提交的反馈；过滤器、文件、REST、SSE 和后续 Chat grounding 要共同证明 pinned 状态真的成立。
- 首轮 stop-and-fix：旧 pin action 直接 await Future，没有 single-flight busy state，也没有 pin 专属错误反馈；失败可能成为未处理 Flutter exception，快速连点可能发出竞争 mutation。改为 keyed stateful row、`_pinBusy` latch、共享 spinner、action-specific AX label、localized notice，并补 fixture gate/error/call-count 与 12 项 Memory 回归；Settings 文档和 en/zh i18n 同步。
- 真实五通道 session `/private/tmp/anselm-rig-ep193-memory-pin-fix-20260811/sessions/20260811-003318`：真实 Flutter macOS App + Computer Use + `https://api.anselm.website` + 三路独立 ssetap + backend/frontend journals + llmtap，录屏 `181.463333s / 2784x1808 / 60fps`。真实路径 Pin → Pinned → Unpin 空态 → All → repin，再回 Chat 读取 `pin-guide`，最终 assistant 精确返回 `Pin this only when it should ride every conversation.`。
- 五通道真相：三次 pin mutation 与 roster GET=`200`；REST 最终 `pin-guide=true`、`quiet-note=false`，`pinned=true` 只有 `pin-guide`，file frontmatter=`pinned: true`；notifications durable seq=`1..7` 单调，messages 记录真实 `read_memory` tool call/result 和 assistant close，llmtap gateway 与三次 completion 全 `200`，frontend/backend 无应用级红线。
- 逐帧：Pin=`33.3ms`、Pinned=`66.7ms`、Unpin empty=`66.7ms`、All=`33.3ms`、repin=`66.7ms`；Chat 首个可见反馈=`433.3ms`。连续 diff 有 changed box 证据，无黑帧、残留 spinner、列表错位或文字跳变。完整证据为 session `evidence/EP-193-final-green.md`，账本复核为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-193-ledger-alarm-reaudit.md`。
- 正式按 `measure:memory-pin-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-193=✓✓✓✓✓`；formal ledger `1655→1660 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/325/0`。`gap-too-fast`、`discovery-collapse` 已依据独立 re-audit ack，阈值/算法/法典/锚点/gate 未改，最终 `alarms.py check`=`clean (1660)`。隔离数据目录已移入 Trash；批次未满 50 格，不跑统一长门禁、不提交；下一前线 EP-194。

## 2026-08-10 — EP-192 `DELETE /api/v1/memories/{name}` 收口，批次三十一 40/50

- 产品目的：真实用户必须先理解 memory 的物理删除和不可逆后果，Cancel 不改变状态，Confirm 后 UI、REST、文件和 durable notification 共同收敛；另一个客户端删除当前打开对象时，详情页必须停止编辑幽灵数据并回到权威名册。
- 真实五通道 session `/private/tmp/anselm-rig-ep192-memory-20260810/sessions/20260810-154348`：真实 Flutter macOS App、Computer Use、受管 `https://api.anselm.website`、三路 ssetap、backend/frontend journals、llmtap、封口录屏 `29509.911667s / 2788x1808 / 60fps`。创建 `daily-rule`/`keep-me`，验证删除对话框 Cancel 无 DELETE；第二客户端 DELETE `keep-me` 后详情被驱逐并显示 removal notice；用户明确授权后真实 UI Confirm 删除 `daily-rule`，最终 empty roster 保留 `New memory` 入口。
- stop-and-fix：Memory detail 现在只在 settled roster 确认对象消失时 post-frame eviction；loading/error 不误驱逐；新增 `_MemoryGone`、移除提示/标题/返回文案、en/zh i18n、Settings 文档和外部删除 widget regression。静态 memory/store/HTTP Go tests、`TestContractKnowledge_MemorySurface`、Flutter Memory/lifecycle tests（11 项）、`flutter analyze`、measure tests、docs verify 和 diff check 全绿。
- 五通道真相：backend 两次 DELETE=`204`、最终 GET=`[]`、重复删除=`404 MEMORY_NOT_FOUND`、非法 name=`400 MEMORY_INVALID_NAME`，产品 session 无应用错误；notifications durable seq=`1..4` 对应两 create/two delete，其他两流已连接但无虚构业务帧；llmtap challenge/install/models 全 `200`，settings-only path 无 completion；frontend 无 Dart/Flutter/layout/runtime 红线，只有已知 launcher foreground 噪声。
- 逐帧：外部删除 notice 首个可见反馈=`16.7ms`；UI Confirm 用 `actionFrame=344` 的保守对齐，首个可见反馈=`83.3ms`，`changedFrac=0.00770`，box=`(675,392)-(2395,991)`；对话框居中可读，空态转换无黑帧、文字跳变、死 spinner 或残留 dialog。正式证据：session 内 `evidence/EP-192-final-green.md`；警报复核：`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-192-ledger-alarm-reaudit.md`。
- formal ledger 按 `measure:memory-delete-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-192=✓✓✓✓✓`，`1650→1655 judgments`，anchors=`10/10`，`gen_coverage.py --check`=`848/324/0`。`gap-too-fast` 是五级批量写账造成的间隔信号，`discovery-collapse` 是没有人为伪造 fail 的清洁路径信号；均已独立重读原始证据后 ack，未改阈值/算法/法典/锚点/gate，正式 `alarms.py check`=`clean (1655)`。fixture `/private/tmp/anselm-data-ep192-memory-20260810` 已按授权移入 Trash；session/ledger/录屏/journals/evidence 保留。未满 50 格，不跑统一长门禁、不提交；下一原子前线 EP-193。

## 2026-08-10 — EP-191 `PUT /api/v1/memories/{name}` 收口，批次三十一 35/50

- 产品目的：这不是只验 `200` 的 Upsert 接口；真实用户在 Memory editor 建立可复用记忆后，外部更新必须在当前页面内收敛，名称、多行正文、描述、置顶/source 策展和删除结果要同时在 UI、REST、文件 store 与 notifications durable stream 中成立。
- 首轮 R2 不计绿：录屏 MOV 只有秒级 `startedAt`，无法把 A1 的 `≤100ms` 对齐成可审计数字。先修台架：`spawn.py` 写入 recorder PID 与 UTC 微秒 `spawnRequestedAt/spawnReturnedAt`，manifest 指向 lifecycle，`rig-check` 验证 PID/时间区间；脚本语法、生命周期 self-test、`git diff --check` 通过。随后用新二进制和新数据目录重跑 R3。
- R3 真实五通道 session `/private/tmp/anselm-rig-ep191-memory-20260810-r3/sessions/20260810-151539`：真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、backend/frontend journals、llmtap、封口录屏 `336.938333s / 2784x1808 / 60fps`。真实 editor 创建 `daily-rule-r3`；外部 PUT 使同页 roster 直接变为 `Updated in R3 externally`；真实创建/更新/删除 `r3-curated`，多行 `description` 不能覆盖 `pinned=true/source=user`。
- 五通道交叉核验：backend 真实 PUT/GET/DELETE 与 file store 一致，无应用 WARN/ERROR/panic/fatal；notifications durable seq=`1..5` 单调，对应两 create、两 update、一次 delete；entities/messages 已连接且无虚构业务帧；llmtap challenge/install/models 全 `200`，本格不触发 completion；frontend 无 Dart/Flutter/RenderFlex/Unhandled/Exception/runtime 红线，只有已知 launcher foreground 噪声。
- 逐帧：`source_007→source_008` 是唯一变化，`measure diff`=`changedFrac 0.00058`、box=`(1114,540)-(1396,563)`，仅记忆描述行；PTS 差 `16.7ms`，作为保守可见反馈上界满足 A1，无黑帧、整面重排、死 spinner 或布局跳变。完整可复核细节在 session `evidence/EP-191-r3-final-green.md`。
- stop-and-fix：后端修复多行 description 的 frontmatter 注入，补 round-trip test；前端 provider 改为 durable signal 后权威 list 原地 reconcile + generation guard，避免 loading gap；API/Memory settings 文档同步。定向 Go memory/store/HTTP 包测试、`TestContractKnowledge_MemorySurface`、Flutter Memory/lifecycle tests（10 项）和 `flutter analyze` 全绿。
- formal ledger 以 `G1/F2/A1/C4/G2` 写入 `COVERAGE EP-191=✓✓✓✓✓`，中央账本 `1645→1650 judgments`，anchors=`10/10`。`gap-too-fast`、`discovery-collapse` 依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-191-ledger-alarm-reaudit.md` 独立复审并 ack，阈值/算法/法典/锚点/gate 未改，最终 `alarms.py check`=`clean (1650)`；`gen_coverage.py --check`=`848/323/0`。
- 按用户授权移入 Trash `/private/tmp/anselm-data-ep191-memory-20260810`、`-r2`、`-r3` 三个隔离数据目录；正式 ledger、session、录屏、journals、evidence 与测量目录保留。批次三十一由 `30/50→35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线 EP-192，P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-10 — EP-190 `GET /api/v1/memories/{name}` 收口，批次三十一 30/50

- 产品目的：用户从真实 Settings → Resources → Memory 名册进入一条记忆后，必须看见完整名称、描述和多语言多行正文；单读 endpoint 对真实文件、未知 name 和非法 name 要诚实，不能把 roster hydrate 冒充隐藏的单读请求。
- 真实 session `/private/tmp/anselm-rig-ep190-memory-20260810/sessions/20260810-135706`：真实 Flutter macOS App + Computer Use + `https://api.anselm.website` + 三路独立 ssetap + backend/frontend journals + llmtap，录屏 `120.555000s / 2784x1808 / 60fps`。真实建立 `deep-dive` 与 `quiet-note`，进入详情后稳定显示锁定 Name、Description 和完整中英文多行 Content。
- API/file truth：`GET /memories/deep-dive`=`200` 返回完整对象，`ghost-note`=`404 MEMORY_NOT_FOUND`，`Upper-Case`=`400 MEMORY_INVALID_NAME`；file store 仅有预期的 `deep-dive.md` 与 `quiet-note.md`。notifications durable seq=`1..2` 单调，对应两条 created；纯 GET 没有 durable side effect，entities/messages 没有虚构事件；llmtap challenge/install/models 全 `200`，无 completion。
- 静态验证：后端 `TestContractKnowledge_MemorySurface` 与 memory/store/handler 定向 Go tests 全绿；详情页诚实保留从权威 roster hydrate、没有单独 repository `getMemory` 方法的实现边界；`git diff --check` 干净。
- 逐帧与测量：详情切换 `actionFrame=78` 后 `feedbackFrame=80`，可见反馈=`66.7ms`，稳定帧 `changedFrac=0`，changed box=`(1048,259)-(2393,950)`，满足 A1；frontend 无 Dart/Flutter/layout/runtime 红线，backend 无应用 WARN/ERROR/panic/fatal，唯一 launcher foreground 行按既有规则归类为 VM 前噪声。
- 正式按 `measure:memory-detail-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-190=✓✓✓✓✓`，formal ledger `1640→1645 judgments`，anchors=`10/10`。`gap-too-fast`、`discovery-collapse` 依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-190-ledger-alarm-reaudit.md` 独立复审并 ack，最终 `alarms.py check`=`clean (1645)`；`gen_coverage.py --check`=`848 rows / 322 carried judgments / 0 tombstones`。
- 按用户授权删除 `/private/tmp/anselm-data-ep190-memory-20260810`；formal ledger、session、录屏、journals、evidence 与测量复核目录保留。批次三十一由 `25/50→30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线 EP-191，P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-10 — EP-189 `GET /api/v1/memories` 收口，批次三十一 25/50

- 产品目的：真实用户进入 Settings → Resources → Memory 时，All/Pinned/Search 必须让名册可读且可操作；loading、读取失败和确认空列表不能混淆，pin/unpin 要在 UI、文件 store、REST 和通知流中共同收敛。
- 首轮静态 stop-and-fix 发现 `.value ?? []` 会把 Memory GET 失败伪装成空态；已改为 `AnLastGood` + workspace reset key，补 loading skeleton、localized error、Retry 和 empty 分流，新增 8 项 settings widget 回归，并同步 `docs/references/frontend/features/settings.md`。
- 真实 session `/private/tmp/anselm-rig-ep189-memory-20260810/sessions/20260810-133324`：真实 Flutter macOS App + Computer Use + `https://api.anselm.website` + 三路独立 ssetap + backend/frontend journals + llmtap，录屏 `268.238333s / 2784x1808 / 60fps`。12 条 memory、3 条 pinned 真实进入 workspace；All=12、Pinned=3、Search=`workflow-goal`，真实 unpin→pin 后最终 GET=`pinned:true`。
- API/file truth：all/pinned/unpinned=`12/3/9`、name ascending，文件 store 正好 12 个 `.md`；notifications durable seq=`1..17` 单调，对应 12 created、3 initial pin、1 unpin、1 final pin；entities/messages 物理连接但本只读路径无 durable frame，未虚构 SSE；llmtap challenge/install/models 全 `200`，无 completion（本格不触发 LLM）。backend 无应用 WARN/ERROR/panic/fatal，frontend 无 Dart/Flutter/layout/runtime 红线，唯一 launcher foreground 行按既有规则归类为 VM 前噪声。
- 逐帧与测量：All/Pinned/Search/pin transition 稳定帧无裁切、重复、残留 spinner 或跳变；30fps 测量名册反馈=`66.7ms`、Pinned/Search=`33.3ms`，均满足 A1。证据为 session 内 `EP-189-final-green.md`、`EP-189-api-db-sse.txt`、`EP-189-latency.txt`、`EP-189-frontend-terminal-review.md`。
- 正式按 `measure:memory-roster-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-189=✓✓✓✓✓`，formal ledger `1635→1640 judgments`，anchors=`10/10`。写账触发的 `gap-too-fast`、`discovery-collapse` 依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-189-ledger-alarm-reaudit.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1640)`；`gen_coverage.py --check`=`848 rows / 321 carried judgments / 0 tombstones`。
- 按授权删除 `/private/tmp/anselm-data-ep189-memory-20260810`；正式 ledger、session、录屏、journals、evidence 保留。批次三十一由 `20/50→25/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线 EP-190，P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-10 — EP-188 `DELETE /api/v1/attachments/{id}` 收口，批次三十一 20/50

- 产品目的：用户在真实 Composer 中移除一张已准备好的、尚未发送的图片后，缩略图要立即消失，服务端要软删同一附件，metadata/content/重复删除要停止服务；本格不是只看 DELETE `204`。
- 真实五通道 session `/private/tmp/anselm-rig-ep188-rerun-20260810/sessions/20260810-130805`：workspace=`ws_a874dbf4461dcf47`，attachment=`att_0e0b2e21ebf1104f`，真实 Flutter macOS App + Computer Use + 真实受管网关 + 三路独立 ssetap + backend/frontend journals + llmtap，录屏 `359.475000s / 2784x1808 / 60fps`。
- 真实时序：upload `201`=`13:13:24.395 +0800`，ready metadata `200`=`13:13:46.550 +0800`，DELETE `204`=`13:14:13.178 +0800`/`1ms`；SQLite 同一行 `deleted_at=2026-08-10 05:14:13.178006+00:00`。收台后 metadata、content、重复 DELETE 均为 `404 ATTACHMENT_NOT_FOUND`，原始回执保留在 `evidence/post-delete-http.txt`。
- SSE 三条流均真实连接并 clean EOF，但 attachment-only draft deletion 没有业务 lifecycle frame，durable frame=0，未虚构 SSE；llmtap challenge/install/models 全 `200`，无 chat completion；frontend 只有已知 macOS launcher foreground 噪声，无 Dart/Flutter/layout/runtime 红线；backend 无 WARN/ERROR/panic/fatal/exception。
- 逐帧：`0044.png` 为 ready thumbnail + close affordance，`0045.png` 为第一张移除后的变化帧；`measure latency`=`16.7ms`、changedFrac=`0.00872`、box=`(1082,676)-(2366,940)`，满足 A1。L4/L5 复核 shared thumbnail/Composer/AnButton 几何、AX `Remove` 与 `AnButton.iconOnly -> AnInteractive` 的 tooltip/hover/focus 合同；证据明确声明没有单独保存 hover screenshot，不把未观察到的 hover 写成事实。
- 正式按 `measure:attachment-delete-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-188=✓✓✓✓✓`，formal ledger `1630→1635 judgments`，anchors=`10/10`。`gap-too-fast` 与 `discovery-collapse` 依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-188-ledger-alarm-reaudit.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1635)`；`gen_coverage.py --check`=`848 rows / 320 carried judgments / 0 tombstones`。
- 批次三十一由 `15/50→20/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线 EP-189，P12 旅程 400+ 仍按用户裁定推迟二期。

## 2026-08-10 — EP-186/EP-187 preparation cancel/retry 收口，批次三十一 15/50

- 产品目的：大型图片 preparation 期间，用户必须能看懂等待、主动取消、明确重试，并最终得到真实 thumbnail；这两格不是只验 `200` 的后台接口，而是 Composer 的可控等待闭环。
- 首轮真实台架发现红：旧前端只在约 8 秒内做 10 次 `800ms` 轮询；真实 media preparation 约 17–22 秒，后端已 `ready` 后 UI 仍永久显示 `Preparing media...`。这破坏用户目的，红证据保留，不计绿。
- stop-and-fix：改为前 10 次 `800ms`、之后 `2s` 的持续 terminal-state 轮询；暂时 metadata GET 失败不终止；长等待显示 `Still preparing media...`；cancel/retry/dispose 清理轮询状态。补充长等待 widget 测试、cancel/retry 可见按钮断言、i18n 与 chat reference 文档。
- 真实五通道 session `/private/tmp/anselm-rig-ep186-pollfix-20260810/sessions/20260810-123430`：真实 Flutter macOS App、Computer Use、受管网关、三路 ssetap、backend/frontend/LLM journals、封口录屏 `425.251667s / 2784x1808 / 60fps`。`att_948b33fc2427f981`（真实 `38.7MB`）实际走过 cancel `200`、`Media prep cancelled`、retry `200`；`att_94e6ee9c8250da4e` 实际走过 10 次快速 poll、之后约 2 秒轮询、最终 ready。稳定帧为 `cancelled.jpg`、`retrying.jpg`、`long-wait.jpg`、`ready.jpg`。
- 五通道结论：backend/REST/SQLite 的 attachment 状态与 UI 收敛一致；三路 SSE 正常连接但该 attachment-only slice 无 durable chat frame；LLM 无调用且未把空调用冒充证据；frontend 只有已知 runner foreground 噪声，无 Dart/Flutter/layout/runtime 红线；backend 无 WARN/ERROR/panic/fatal/exception。逐帧无 stale label、死 spinner、裁切或跳变。
- 定向验证：`flutter test` chat composer + pending attachment `38` 项全绿，Go media/handler tests 全绿，`flutter analyze` 无问题；COVERAGE `EP-186=✓✓✓✓✓`、`EP-187=✓✓✓✓✓`。
- 正式账本 `1620→1630 judgments`，anchors=`10/10`；写账触发的 `gap-too-fast`、`pass-burst`、`discovery-collapse` 已依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-186-187-ledger-alarm-reaudit.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1630)`；`gen_coverage.py --check`=`848/319/0`。
- 批次三十一由 `5/50→15/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线 EP-188，P12 旅程 400+ 仍按用户裁定推迟二期。

## 2026-08-10 — EP-185 `GET /api/v1/attachment-playback/{token}` 收口，批次三十一 5/50

- 产品目的：这是 EP-184 lease 后 native player 实际调用的隐藏 bearerless fetch；它必须在无 bearer/workspace header 时只服务 token 绑定的 audio，保留 MIME、Range/seek 和 Content-Range，并在 unknown token、soft delete、非 audio 和 mint workspace 缺失时诚实失败。没有独立用户入口，L5 归 EP-184 的 Play audio affordance，记 `na`。
- 静态与黑盒：handler playback tests 和 `TestContractDocsAtt_AudioPlaybackLease` 全绿，覆盖无 header 原字节、`audio/mpeg`、Range `206`、非 audio `415`、missing workspace、unknown token `404` 和软删后旧 lease `404`；handler 的全 blob materialization limitation 保持诚实，不虚报为 memory streaming。
- 真实五通道证据复用 EP-184 封口 session `/private/tmp/anselm-rig-ep184-20260810/sessions/20260810-102935`：native player 实际产生 bearerless `206/2 bytes/1ms` 首探针和 `206/230059 bytes/1ms` 完整 fetch；三路 ssetap、LLM tap、frontend terminal、`355.428333s / 2784x1808 / 60fps` 录屏均在同一台架会话中。
- 视觉/测量：连接 surface 的最后 ready `f0073`→第一帧 `Loading audio...`=`16.7ms`，changed box=`(1366,292)-(1732,336)`；EP-184 的 Pause/时长/进度/resume/自然结束复核无新增跳变或错误帧。
- 正式按 `measure:attachment-playback-purpose / F2 / A1 / C4 / na` 写入 `COVERAGE EP-185=✓✓✓✓~`；formal ledger `1615→1620`，anchors=`10/10`。写账后的 `gap-too-fast`、`discovery-collapse` 依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-185-playback-fetch-ledger-reaudit.md` 独立复审并逐条 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1620)`；`gen_coverage.py --check`=`848/317/0`。
- 批次三十一当前 **5/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-186 preparation cancel，P12 旅程 400+ 继续推迟二期。

## 2026-08-10 — EP-184 `POST /api/v1/attachments/{id}/playback-lease` 收口，批次三十 50/50，统一门禁已关闭

- 产品目的：原生播放器不能携带 bearer header；用户录音发送后，音频卡必须通过 workspace-scoped 短期 opaque lease 继续完成 Play、Pause、Resume、时长/进度和自然结束回到 Play 的真实闭环。非音频、无 workspace、未知/过期 lease、软删后的旧 lease 必须分别诚实失败。
- 静态验证：handler playback-lease tests、frontend audio-player/user-turn tests（20 项）、`TestContractDocsAtt_AudioPlaybackLease` 全通过；覆盖 audio-only `415`、missing-workspace `401`、lease `200`、Range `206`、unknown token `404` 和 soft-delete 后 `404`。本格无新增产品代码修复，复核确认 busy state 与 `Loading audio...` 在 HTTP 请求前先可见。
- 真实五通道 session `/private/tmp/anselm-rig-ep184-20260810/sessions/20260810-102935`：Computer Use 在真实 Flutter macOS App 录制并发送 `M4A · 224.7 KB`，真实受管 `https://api.anselm.website` 返回精确 `EP184 audio ready.`；之后真实 Play 走 lease 和两次 Range `206`，进入 Pause/`0:15`/蓝色进度，暂停恢复和自然结束均正确。录屏 `355.428333s / 2784x1808 / 60fps` 已封口。
- 真相交叉核验：backend 为 upload `201`、metadata `200`、lease `200/159`、playback `206/2` 与 `206/230059`；ssetap 三流独立连接、messages durable `1..9` 单调、user close 携 attachment id、touchpoint=`attached`、assistant close 精确完成；llmtap challenge/install/models/chat 全 `200`，媒体 chat body `63639` bytes、无 base64；frontend 无应用级 Flutter/Dart/layout/runtime 红线，AXTree tooling pattern 单独审阅，收台无残留。
- 视觉/测量：blue/white contrast=`4.70:1`；progress=`141x4`，play control=`56x56`。server-timestamp 对齐得出的 `116.7ms/200ms` 因 busy state 先于 HTTP 请求而拒绝；真实 last-ready `f0073`→first-loading `f0074` 用 `measure latency` 得 `16.7ms`、changed box=`(1366,292)-(1732,336)`，满足 A1。原始 evidence 另含 `EP-184-api-db-sse.txt`、`EP-184-llm-summary.txt`、`EP-184-frontend-terminal-review.md` 和 `EP-184-latency.txt`。
- 正式按 `measure:attachment-playback-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-184=✓✓✓✓✓`；formal ledger `1610→1615`，anchors=`10/10`。新证据触发的 `gap-too-fast`、`discovery-collapse` 依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-184-playback-lease-ledger-reaudit.md` 独立复审并逐条 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1615)`；`gen_coverage.py --check`=`848/316/0`。
- 批次三十现为 **50/50**；根 `make verify`、完整 `make -C backend testend`（`311.848s`）、本批专项回归、gofmt、diff、anchors、alarms、coverage、进程与工作树审计均通过，统一门禁已关闭，下一步提交。临时 `/private/tmp/anselm-data-ep184-20260810` 已在证据封存后按授权移入 Trash，session/formal evidence 保留。P12 旅程 400+ 继续推迟二期。

## 2026-08-10 — EP-183 `GET /api/v1/attachments/{id}/content` 收口，批次三十 45/50

- 产品目的：附件原始内容在真实 App 预览、media provider 读取、Range/seek 和缓存重验证中必须保持字节、MIME、文件名和删除边界真实；Unicode、控制字符或反斜杠文件名不能破坏响应 header，软删后内容必须停止服务。
- 静态 stop-and-fix 修复了 `Content` 与 bearerless `PlaybackContent` 手工拼接 `Content-Disposition` 的 header 安全和 Unicode 表达问题，统一使用标准 MIME serializer。handler 测试锁住完整字节、MIME、安全文件名、Range 206 和条件请求 304；black-box contract 锁住真实 upload 后 200/206/304/416、软删 404，并按标准库语义校验 invalid-range 解释；audio playback lease 回归继续通过。
- 有效真实 session 复用 `/private/tmp/anselm-rig-ep181-20260810/sessions/20260810-094431`：真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路独立 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 231.580s` 封口录屏实际发生 content `200/1,111,731 bytes`，同一内容进入缩略图和真实多模态回合；不把 upload 回执冒充 content GET。
- 五通道/真相：SQLite attachment 行、CAS blob、API metadata、原始 content 字节和消息 attachment id 一致；ssetap messages/entities/notifications 独立连接且 durable seq 单调；llmtap 确认相对 media lease、无 base64/绝对 host；backend 无应用 WARN/ERROR/panic/FATAL，frontend 仅有已知 launcher foreground 噪声，无 Dart/Flutter/layout/runtime 红线；软删后的 API/DB 与 content 404 一致。
- 逐帧/测量：附件 thumbnail、user card、composer action slot 和 assistant 排版稳定，连续解码 final window 无 diff 超过 `0.0005`，contrast=`8.86:1`；30fps action→visible feedback=`33.3ms`，black-box content GET=`0–3ms`。L5 诚实为 `na`，该 transport row 没有独立 click target，discoverability 归 EP-181 Composer 入口。
- 正式按 `measure:attachment-content-purpose / F2 / A1 / C4 / na` 写入 `COVERAGE EP-183=✓✓✓✓~`；formal ledger `1605→1610 judgments`，anchors=`10/10`。写账后的 `gap-too-fast`、`discovery-collapse` 依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-183-content-ledger-reaudit.md` 独立复审并逐条 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1610 judgments)`；`gen_coverage.py --check`=`848/315/0`。
- 定向 Go handler/app attachment tests、平台 content/playback contracts、frontend media tests、gofmt、anchors、alarms、coverage 和 diff check 均通过；真实台架监听归零，EP-183 evidence 与 formal re-audit 保留。批次三十当前 **45/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-184，P12 旅程 400+ 继续推迟二期。

## 2026-08-10 — EP-182 `GET /api/v1/attachments/{id}` 收口，批次三十 40/50

- 产品目的：附件在真实 App 生命周期里被重新读取时，filename、MIME、kind、size、sha256 和 id 必须与后端/SQLite 真相一致；图片 preparation 要呈现真实 sidecar 状态，worker 暂不可用不能隐藏 metadata。
- 静态契约补强：handler tests 锁住 ready image preparation 全量字段和 unavailable fallback；black-box attachment REST matrix 在每次 upload 后真实 GET metadata，逐字段比对六个 metadata 字段，非图片锁 `not_required/not_required`，软删 404 边界继续覆盖。
- 真实 session 复用 `/private/tmp/anselm-rig-ep181-20260810/sessions/20260810-094431`，因为 backend journal 实际记录三次 `/api/v1/attachments/att_de36c7c54c9af7a7` metadata GET=`200`（418/464/464 bytes），随后 content=`200/1,111,731 bytes`；该 session 是真实 Flutter App、Computer Use、受管 `https://api.anselm.website`、三路 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 231.580s` 封口录屏。EP-181 的 thumbnail、durable user card、streaming/final UI 均未出现 stale metadata、missing card 或 preparation 跳变。
- 五通道/真相：SQLite attachment/CAS/message attachment id/API 投影一致；messages/entities/notifications 均有独立连接，messages durable seq=`1..9` 单调且 user close 携 attachment id；llmtap 确认相对 media lease、无 base64/绝对 host；backend/frontend 无应用错误红线，仅保留已知 launcher foreground 噪声。
- 视觉/测量：附件 thumbnail、remove、user card、composer action slot、assistant 排版稳定；连续 decode final window 无 diff 超阈，contrast=`8.86:1`，action→visible feedback=`33.3ms`，backend GET=`0–1ms`。L5 对 API-only row 诚实为 `na`，discoverability 归 EP-181 Composer 入口。
- 正式写入 `COVERAGE EP-182=✓✓✓✓~`，`measure:attachment-user-purpose / F2 / A1 / C4 / na`；formal ledger `1600→1605 judgments`，anchors=`10/10`。每次新证据触发的 `gap-too-fast`、`discovery-collapse` 均按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-182-get-attachment-ledger-reaudit.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1605 judgments)`；`gen_coverage.py --check`=`848/314/0`。
- 定向 Go handler/app attachment/media tests、平台 attachment contracts、gofmt、anchors、alarms、coverage、diff check 均通过；无新增临时数据目录，真实台架监听归零，EP-182 evidence 与 re-audit 保留。批次三十由 **35→40/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-183，P12 旅程 400+ 继续推迟二期。

## 2026-08-10 — EP-181 `POST /api/v1/attachments` 收口，批次三十 35/50

- 产品目的：用户从真实 Composer 选择图片、看到缩略图、写 prompt、发送后，真实受管多模态模型必须看见同一图片并返回有用答案；附件、消息、SSE、SQLite、blob 和五通道 journal 共同收敛。
- 静态 stop-and-fix 修复了 upload handler 的错误分类与 multipart 临时文件泄漏：只有 MaxBytesError 返回 `ATTACHMENT_TOO_LARGE`，损坏/非 multipart 返回 `ATTACHMENT_BAD_UPLOAD`，请求结束清理临时文件。新增 handler round-trip、malformed boundary、33 MiB cleanup 测试、black-box contract 和 attachment reference 同步。
- 有效真实 session 为 `/private/tmp/anselm-rig-ep181-20260810/sessions/20260810-094431`：真实 Flutter macOS App、Computer Use、`https://api.anselm.website`、三路 ssetap、llmtap、backend/frontend journals、`2784x1808 / 60fps / 231.580s` 封口录屏。真实走过 paperclip、macOS picker、Preparing、thumbnail、send、assistant 完成态；回答与画面内容一致。早先 stale-index 误关窗口的 `093951` session 明确排除，不进任何裁决。
- 五通道/真相：本地 attachment POST=`201`/12ms，metadata/content=`200`/1,111,731 bytes；SQLite/CAS/message blocks 与 attachment id 一致，源图和远端 PUT body SHA-256 相同；SSE messages durable seq=`1..9` 单调，user close、attachment touchpoint、auto-title 均正确；llmtap proof/media init/PUT/complete=`201`/multimodal chat 全 `200`，chat body 使用相对 lease 且无 base64；backend 无应用 WARN/ERROR/panic/FATAL，frontend 只有已知 launcher foreground 噪声，无 Dart/Flutter/layout/runtime 红线。
- 视觉/测量：附件 card、remove、发送中 stop、完成后 microphone 均稳定；连续解码 final window 无 diff 超阈，随机 seek H.264 partial-frame 伪影已排除；30fps action→feedback upload=`33.3ms`、send=`33.3ms`，contrast=`8.86:1`。证据为 session `evidence/EP-181-final-green.md`、`EP-181-api-db-sse.txt`、`EP-181-llm-summary.txt`、`EP-181-frontend-terminal-review.md`、`EP-181-latency.txt` 和四张稳定帧。
- 正式按 `measure:attachment-user-purpose / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-181=✓✓✓✓✓`，formal ledger `1595→1600 judgments`，anchors=`10/10`。写账触发的 `gap-too-fast`、`discovery-collapse` 依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-181-ledger-alarm-reaudit.md` 两阶段独立复审并逐条 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1600 judgments)`；`gen_coverage.py --check`=`848/313/0`。
- 定向 Go handler/app attachment tests、两个平台 attachment contract、gofmt、measure、anchors、coverage 和 `git diff --check` 已通过；台架已收台、监听归零；`/private/tmp/anselm-data-ep181-20260810` 按授权在证据和账本封存后清理，session/录屏/journals/evidence/formal ledger 保留。批次三十由 **30→35/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-182，P12 旅程 400+ 继续推迟二期。

## 2026-08-10 — EP-180 `POST /api/v1/conversations/{id}/sandbox-envs:reset-all` 收口，批次三十 30/50

- 产品目的：一次清理 conversation 的全部 scratch env；所有 idle env 全部删除，任何 resident/running env 在 mutation 前阻止整批操作，重复调用幂等，foreign workspace 不能借 conversation id 越权；Settings roster、REST、SQLite、SSE、LLM wire 和 backend journal 必须共同收敛。
- 静态审计发现逐 env 删除会在 idle sibling 已删后才撞到 running env，造成“返回失败但已部分改变”。新增 `DestroyOwners`，稳定排序加锁、完整预检所有 owner，任一 `RunningPID > 0` 即零 mutation 返回 `ErrEnvInUse`，预检通过后才统一销毁；新增 sandbox unit test 与平台 contract partial-delete guard。
- 真实 session `/private/tmp/anselm-rig-ep180-20260810/sessions/20260810-091401` 使用真实 Flutter macOS App、Computer Use、真实受管 `https://api.anselm.website`、三路 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 451.906667s` 封口录屏。onboarding 后真实 gateway 回合精确显示 `EP180 gateway regression OK.`；reset-all 的 scratch env 由受控 SQLite fixture 物化，因为当前产品没有用户可直接触发的 conversation-env producer，fixture 不被当作前端入口。
- 五通道/真相：owned list/reset-all/list=`200(2 rows)/200 removed=2/200 empty`，重复调用=`200 removed=0`；resident guard=`409 SANDBOX_ENV_IN_USE` 且 SQLite/list 均证明两行未被部分删除；foreign list/reset-all=`404 CONVERSATION_NOT_FOUND`；messages durable seq `1..8`、notifications durable seq `2..6` 单调，四条 `sandbox.env_deleted`，ephemeral delta 为 `seq=0`；真实 gateway proof/install/models/chat 全 `200`；frontend 除已知 launcher foreground 噪声外无 Flutter/Dart/RenderFlex/overflow/Unhandled/lost-device 红线。
- 逐帧与测量：两行 Settings 状态显示可读 title、绿色健康点、`0 deps · 0 B`，running 行明确标识 `running`，无 opaque id；最终进入 `No environments` 空态。绿色区域各为 `13x13`，文字对比度 `8.86:1`，两段 action→feedback 实测 `100ms`，稳定窗口 changed fraction=`0.00682`。L5 对 API-only reset-all 诚实记 `na`。
- 正式写入 `COVERAGE EP-180=✓✓✓✓~`，`G1/F2/A1/C4/na`；formal ledger `1590→1595 judgments`，anchors=`10/10`。两类统计警报逐次独立复审、逐次 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1595 judgments)`；`gen_coverage.py --check`=`848/312/0`。
- 定向 Go tests、平台 contract、gofmt、anchors、alarms、coverage、diff check 通过；台架已收台，监听归零；专用 `/private/tmp/anselm-data-ep180-20260810` 按授权清理，session/录屏/journals/evidence/formal ledger 保留。批次三十由 **25→30/50**，不满 50 格不跑统一长门禁、不提交；下一原子前线 EP-181，P12 旅程 400+ 继续推迟二期。

## 2026-08-10 — EP-179 `POST /api/v1/conversations/{id}/sandbox-envs/{kind}:reset` 收口，批次三十 25/50

- 产品目的：对同一 conversation scratch env 只重置请求的 runtime kind，保留 sibling kind；foreign workspace 即使知道 conversation id 也不能读或删；真实 Settings roster、REST、SQLite、SSE 和 backend journal 必须共同收敛。
- 静态审计确认 EP-178 已修复的 conversation workspace authorization gate 覆盖 list/reset/reset-all；本格新增平台 contract fixture，owned list 物化 python/node 两行，python reset 后只剩 node，foreign list/reset 均为 `404 CONVERSATION_NOT_FOUND`。定向 handler authorization test 与平台 contract 通过。
- 真实 session `/private/tmp/anselm-rig-ep179-20260810/sessions/20260810-085428` 使用真实 Flutter macOS App、Computer Use、真实受管 Anselm gateway、两 workspace、三路独立 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 260.555000s` 封口录屏。App onboarding 后经真实 gateway 得到精确 `EP179 gateway regression OK.`；fixture 物化后执行 owned `python:reset`，Settings → Sandbox → Conversations 最终只显示可读 conversation title、绿点和 `0 deps · 0 B`，无 opaque id、stale row、spinner 或跳变。
- 五通道/真相：owned GET/reset/GET=`200/204/200`，SQLite 最终只保留 `se_ep179_node`；foreign workspace list/reset=`404/404 CONVERSATION_NOT_FOUND`；ssetap messages durable `seq=1..8`、notifications `seq=1..3` 单调，`seq=3` 是精确 `sandbox.env_deleted`，ephemeral delta 为 `seq=0`；llmtap proof/install/models/chat 全 `200`；backend route lines 与 UI/DB/SSE 一致；frontend 只有已知 launcher foreground 噪声，无 Flutter/Dart/RenderFlex/Unhandled 红线。
- 证据：session 内 `EP-179-final-green.md`、`EP-179-api-db-sse.txt`、`EP-179-llm-summary.txt`、`EP-179-frontend-terminal-review.md`、`EP-179-latency.txt`、最终帧 `evidence-frames/EP-179-00:03:42.png`；formal re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-179-ledger-alarm-reaudit.md`。reset action→durable deletion 同 tick，刷新 projection `10ms` 后完成，A1 通过。
- 正式写入 `COVERAGE EP-179=✓✓✓✓~`，`G1/F2/A1/C4/na`，formal ledger `1585→1590 judgments`，anchors `10/10`；两次统计警报均按机制开启、复审后 ack，最终 `alarms.py check`=`clean (1590 judgments)`，`gen_coverage.py --check`=`848/311/0`。L5 `na` 是 API-only endpoint 无独立前端入口的诚实边界，沿用 EP-172 规则，不伪造 discoverability。
- 真实台架已收台、监听归零；EP-179 数据目录在证据封存后按授权清理，session/录屏/journals/evidence/formal ledger 保留。批次三十由 **20→25/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-180 `POST /api/v1/conversations/{id}/sandbox-envs:reset-all`。P12 旅程 400+ 继续按用户裁定推迟二期，一期以 COVERAGE 矩阵为覆盖真相。

## 2026-08-10 — EP-178 `GET /api/v1/conversations/{id}/sandbox-envs` 收口，批次三十 20/50

- 产品目的：用户在 Settings → Sandbox → Conversations 能看懂自己的 conversation scratch env；机器级 manifest 不能被 foreign workspace 通过已知 conversation id 读取或重置；有标题显示可读名称，无标题显示本地化 `New chat`，绝不暴露 `cv_*_python` 实现 ID。
- 首轮真实 session `/private/tmp/anselm-rig-ep178-20260810/sessions/20260810-082354` 暴露两条红线：路由只按 owner ID 前缀过滤 manifest、没有先验证 conversation workspace；真实 UI 直接显示 `cv_88d4ab78611c73c0_python`。stop-and-fix 加入 conversation resolver 授权门、conversation owner-name hydration、前端本地化 fallback，并补 Go/handler/platform contract/Flutter S5 守卫和 backend/frontend reference。
- fixed session `/private/tmp/anselm-rig-ep178-fixed2-20260810/sessions/20260810-083204` 使用真实 Flutter macOS App、Computer Use、真实受管 Anselm gateway、两 workspace、三路独立 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 203.811667s` 封口录屏。真实 gateway 回合先得到 `EP178 ready` 标题；Settings 命名帧显示 `Reply with exactly: EP178 ready`，清空 title/summary 后同一 tab 显示本地化 `New chat`，无内部 ID、错位、spinner 或跳变；随后真实 gateway regression 精确返回 `EP178 gateway regression OK.`。
- 五通道/真相：owned GET `200` 一条 env；foreign workspace 同 opaque id `404 CONVERSATION_NOT_FOUND`；missing contract list/reset/reset-all 同码；owned reset `204`。SQLite 一条 ready env、四条 completed message、六条 completed block；ssetap 两 workspace 三流均连接，owned messages durable `seq=1..8`、notifications `seq=1..2` 单调，entities durable `0` 是本路径正确边界；llmtap fixed session proof/chat 全 `200`；backend 无应用 WARN/ERROR/panic/FATAL，frontend 仅保留已知 launcher foreground 噪声，无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device 红线。
- 证据：session 内 `EP-178-final-green.md`、`EP-178-api-db-sse.txt`、`EP-178-llm-summary.txt`、`EP-178-frontend-terminal-review.md`、`EP-178-latency.txt` 和两张稳定帧；首轮 opaque-ID 红帧保留在 `/private/tmp/anselm-rig-ep178-20260810/sessions/20260810-082354/evidence-frames/EP-178-owner-opaque-red.png`。formal ledger `1580→1585 judgments`，`G1/F2/A1/C4/G2` 已写入 `COVERAGE EP-178=✓✓✓✓✓`，anchors `10/10`。
- 写账触发的 `gap-too-fast`、`discovery-collapse` 已按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-178-ledger-alarm-reaudit.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 `alarms.py check`=`clean (1585 judgments)`；`gen_coverage.py --check`=`848/310/0`。定向 Go、平台 contract、Flutter S5 `18/18`、`flutter analyze`、`make -C docs verify`、anchors、coverage、`git diff --check` 全绿；并发 Flutter 工具竞态未计入通过，串行重跑后才收口。
- 台架已收台、监听归零；按授权删除 `/private/tmp/anselm-data-ep178-20260810`，session/录屏/journals/evidence/formal ledger 保留。批次三十由 **15→20/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-179 `POST /api/v1/conversations/{id}/sandbox-envs/{kind}:reset`。P12 旅程 400+ 继续按用户裁定推迟二期，一期以 COVERAGE 矩阵为覆盖真相。

## 2026-08-10 — EP-177 `POST /api/v1/sandbox:retry-bootstrap` 收口，批次三十 15/50

- 产品目的：真实 sandbox 根目录损坏时，用户要看到安全的人话 degraded 状态，能理解要修数据目录/权限；故障未修复时 Retry 不能假绿，修复后同一个 Retry 必须让 backend 状态、Settings callout 与文件系统共同回到 ready。
- 真实 session `/private/tmp/anselm-rig-ep177-20260810/sessions/20260810-075240` 使用全新数据目录、真实 Flutter macOS App、Computer Use、真实受管 Anselm gateway、三路独立 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 183.766667s` 封口录屏。App onboarding 创建 `EP177 Retry Bootstrap`，进入 Settings → Sandbox 先确认健康空态；随后把专用数据目录的 `sandbox/` 暂时替换为普通文件构造真实故障。
- stop-and-verify：真实 App 重进 Sandbox 后显示 `Sandbox bootstrap failed` callout、可操作 Retry 和人话说明，无路径/Go/OS 细节；故障仍在时 Computer Use 点击 Retry，REST 是 `200 {ok:false}`，UI 不假绿；恢复原始目录后再次点击 Retry，REST 是 `200 {ok:true}`，状态 GET 也是 ready，红色 callout 整块消失。没有发现需要修复的产品或视觉缺陷；录屏逐帧未见布局跳变、残留 spinner、stale error 或截断文案。
- 五通道：backend 仅有两条受控故障注入 WARN，随后明确 `sandbox bootstrap ready`，无 panic/FATAL/未解释 ERROR；ssetap 三流物理连接，durable frame=`0` 是正确边界（本格只变 machine health、不写 entity row）；frontend 无 Flutter/Dart/RenderFlex/Unhandled/lost-device 红线；llmtap 真实网关 challenge/install/models 全 `200`。本地 retry backend `elapsed_ms=0`；`measure latency` 在 `retry-select/` 的 30fps 帧集上测得 degraded action-baseline→callout 消失首帧=`33.3ms`、changed box=`(262,98)-(599,390)`，无 VFR 猜测。
- 正式按 `G1 / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-177=✓✓✓✓✓`，formal ledger `1575→1580 judgments`，anchors=`10/10`；写账后的 `gap-too-fast`、`discovery-collapse` 按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-177-ledger-alarm-review.md` 复审并逐条 ack，最终 `alarms.py check`=`clean (1580 judgments)`，未改阈值/算法/法典/锚点/gate。证据为 session 内 `evidence/EP-177-final-green.md`、`EP-177-sse-summary.txt`、`EP-177-latency.txt`；`gen_coverage.py --check`=`848/309/0`。
- 定向 backend sandbox/handler/store tests、平台 contract、Flutter S5/Storage `29/29`、`flutter analyze`、`make -C docs verify`、anchors、alarms 和 coverage 均全绿。专用数据目录恢复后随账本落定按授权清理，session/录屏/journals/evidence 保留；批次三十由 **10→15/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-178 `GET /api/v1/conversations/{id}/sandbox-envs`。P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-10 — EP-176 `POST /api/v1/sandbox:gc` 收口，批次三十 10/50

- 产品目的：GC 必须让用户知道自己正在永久删除本机闲置 environment 文件，而不是误删 owner 或 runtime；普通阈值无命中要显示 `Reclaimed 0`，全量回收后 Settings、REST、SSE 和文件事实要共同进入空 env 态，随后真实 Function Run 必须能懒重建并回到可用。
- 首轮真实 session `/private/tmp/anselm-rig-ep176-20260810/sessions/20260810-071453` 暴露红线：GC 成功后 UI 仍显示 `0 B`、`No runtimes yet`，同屏 env 与 REST 已有真实数据；另一次真实 Entities Function Run 后重进 Settings 仍显示 `No environments`。stop-and-fix 将 SettingsOcean 的 Sandbox 进入/重进边界扩展为同时 invalidate bootstrap、runtimes、disk、env 四套 projection；Storage 仍只刷新 disk。新增四投影重进 widget test，定向 Flutter `29/29` 与 `flutter analyze` 全绿。
- fixed session `/private/tmp/anselm-rig-ep176-fixed2-20260810/sessions/20260810-073250` 为全新数据目录、真实 Flutter macOS App、Computer Use、受管 Anselm gateway、三路独立 ssetap、llmtap、backend/frontend journals、窗口录屏；`screen.mov`=`2784x1808 / 329.896667s`。真实 App 创建 workspace、打开 Sandbox 空态、在 Entities 点击 Function `Run` 三次；每次 `Done`/`{"ok":true}`，终端出现 `env attempt 1 ok`。普通 GC 确认后 `Reclaimed 0`；全量 GC 确认文案说明永久移除闲置 env 文件，确认后 `No environments`，四个 runtime 与 `453.0 MB` 保留；下一次真实 App Run 成功重建 env，重进 Sandbox 再显示 `ep176_gc_probe`。
- 五通道：确认动作到首个可见变化 `33.3ms`、`changedFrac=0.08912`；backend journal 无 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线；ssetap 三流连接，notifications durable `seq=1..9`、entities `seq=1..6` 单调，记录 `sandbox.env_deleted`、installing/ready 和三轮 entity build open/delta/close，seq=0 delta 未进耐久序列；llmtap challenge/install/models 全 `200`，本场确定性 Function 路径不声称发生模型 completion。`rig-check` 收台前通过，录像 ffprobe 可读。
- 正式按 `G1 / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-176=✓✓✓✓✓`，formal ledger `1570→1575 judgments`，anchors=`10/10`；写账后的 `gap-too-fast`、`discovery-collapse` 依据真实封口会话和锚点复核逐条 ack，最终 `alarms.py check`=`clean (1575 judgments)`。证据为 fixed session `evidence/EP-176-final-green.md`、`EP-176-sse-summary.txt`、`EP-176-latency.txt`；`gen_coverage.py --check`=`848 rows / 308 carried / 0 tombstones`。专用数据目录在收台、证据封存和账本落定后按授权安全删除，session 证据与 formal ledger 保留。批次三十由 **5→10/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-177 `POST /api/v1/sandbox:retry-bootstrap`。P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-10 — EP-175 `GET /api/v1/sandbox/bootstrap-status` 收口，批次三十 5/50

- 产品目的：Settings → Sandbox 打开时，用户能区分 ready、loading、transport failure 和 degraded bootstrap；故障信息必须是安全的人话并给出 Retry，不能把本机路径、Go 包装错误或 OS 细节泄漏到 HTTP/UI；修复后 Retry 必须让后端与 App 收敛回 ready。
- 首轮真实 session `/private/tmp/anselm-rig-ep175-20260810/sessions/20260810-063949` 构造 `sandbox` 普通文件，真实 App 红帧直接暴露 `sandboxapp.Bootstrap`、临时目录路径和 `not a directory`。红证据永久保留，不计绿。第二轮修复 GET 后，真实 REST 复验又抓到 POST retry 回执仍泄漏原始错误，再次冻结。
- stop-and-fix：GET/POST degraded envelope 统一为 `error="sandbox bootstrap failed"`，raw error 只留 backend journal；前端 `_BootstrapHealth` 显式处理 skeleton、transport error、degraded、retrying，不再渲 `SandboxBootstrap.error`；新增中英文人话、fixture failure/slow seams、handler contract tests、Flutter S5 tests 和 API/foundation/settings 文档同步。
- fixed session `/private/tmp/anselm-rig-ep175-fixed-20260810/sessions/20260810-065405` 由 conductor 托管重建 backend、真实 Flutter App、Computer Use、受管 Anselm gateway wiring、三路 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 109.246667s` 录屏。故障帧只显示本地化 `Sandbox bootstrap failed` + `Retry`；恢复专用目录后真实点击 Retry，HTTP POST/GET 安全 `200`，红色 callout 消失。
- 五通道：backend 只在故障构造时记录预期 degraded WARN，端点不泄漏 raw；ssetap 独立连接 notifications/messages/entities，设置只读路径无伪造业务 durable frame；llmtap 记录真实 `https://api.anselm.website` ready，本格不声称模型 completion；frontend 只有已知 launcher foreground/TSM 噪声，无 Dart/Flutter/layout/Unhandled 红线。`measure latency` 动作帧→首个可见变化=`16.7ms`、`changedFrac=0.13254`。
- 正式 anchors=`10/10` 后按 `G1 / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-175=✓✓✓✓✓`，账本 `1565→1570 judgments`；每次写账触发的 `gap-too-fast`/`discovery-collapse` 都先由 gate 阻断，再按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-175-ledger-alarm-review.md` 复审、校准并 ack，最终 alarms clean=`1570`；coverage check=`848/307/0`，未改阈值、算法、法典、锚点或 gate。
- 定向 `go test ./internal/app/sandbox ./internal/transport/httpapi/handlers`、Flutter S5 `15/15`、`rig-check` 全绿；证据、录屏、红绿 session 均保留在 `/private/tmp`。批次三十当前 **5/50**，未到用户规定的 50 格，不跑统一长门禁、完整 testend 或提交；下一原子前线为 EP-176 `POST /api/v1/sandbox:gc`。P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-10 — EP-174 `GET /api/v1/sandbox/disk-usage` 收口，批次二十九 50/50，统一门禁已关闭

- 产品目的：Sandbox 与 Storage 的机器级磁盘数字必须来自同一 runtime/env manifest projection；常驻 SettingsOcean 重新进入和 Sandbox/Storage 切换必须刷新；loading、error、settled-empty 不得伪装成 `0 B`；删除 env 后 exact REST/SQLite 与前端投影要能解释地收敛。
- 首轮真实 App session `/private/tmp/anselm-rig-ep174-20260810/sessions/20260810-053705` 冻结为红：REST=`475033055` 且 env=`30464` bytes，但两个 UI 都卡在 `0 B`。红证据永久保留；修复 strict `totalBytes` 解析、共享 `AnLastGood` loading/error+Retry/data、Settings/面板进入失效 provider，并补 Flutter/testend/docs。
- fixed session `/private/tmp/anselm-rig-ep174-20260810/sessions/20260810-055332` 为真实 Flutter macOS App + Computer Use + 受管网关接线 + 三路 ssetap + llmtap + backend/frontend journals + `197.005000s` 录屏。Sandbox/Storage 均显示 `453.0 MB`；删除 env 后 Sandbox 为 `No environments`，exact REST/SQLite=`475002591`，delta=`30464`；Storage 保持一位小数 `453.0 MB` 是正确舍入，不是 stale。cleanup session `/private/tmp/anselm-rig-ep174-cleanup-20260810/sessions/20260810-060148` 通过 API DELETE Function=`204`、GET=`404 FUNCTION_NOT_FOUND`，未直接改库。
- 五通道：三路 SSE 连接并 clean EOF；`sandbox.env_deleted` 是 notifications stream frame-only Broadcast echo，不是 inbox row；没有伪造 message/entity 帧或模型 completion。backend 无应用 WARN/ERROR/panic/FATAL，frontend 只有已知 launcher 噪声，无 Flutter/Dart/layout/Unhandled 红线；固定 session 内保存 REST/DB/SSE/LLM/frontend/latency/final evidence 与五张帧。
- 正式 anchors=`10/10` 后按 `G1 / F2 / measure:sandbox-disk-refresh / C4 / G2` 写入 `COVERAGE EP-174=✓✓✓✓✓`，账本 `1560→1565 judgments`；每次写账触发的 `gap-too-fast`/`discovery-collapse` 均依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-174-sandbox-disk-usage-ledger-reaudit.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 alarms clean=`1565`；coverage check=`848/306/0`。
- 批次二十九由 **49→50/50**。根 `make verify` 首次只暴露未格式化的既有 `w6_navigation_test.dart`，机械格式化后第二轮 backend/frontend/docs/demo 全绿；完整 testend 首次 `287.787s` 有一次未定位失败，随后同命令重跑通过，第三轮 JSON 全量也通过（`356` pass、`0` fail）。残留 testend 进程/目录为零；异常保留在 fixed session 的 `EP-174-batch29-gate.md`，不伪造为未发生。正式 alarms=`clean (1565)`、coverage=`848/306/0`；批次统一门禁已通过，提交为 `ad64c505`，批次二十九已关闭；下一原子前线为 EP-175 `GET /api/v1/sandbox/bootstrap-status`，批次三十从 `0/50` 开始。P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-10 — EP-173 `DELETE /api/v1/sandbox/envs/{id}` 收口，批次二十九 49/50

- 产品目的：确认前说明永久删除本机 env 文件且 owner 保留；取消不 mutation；确认后 Settings roster、REST、SQLite、文件系统、机器级 disk usage 和 SSE 必须共同收敛；resident env 必须被 `SANDBOX_ENV_IN_USE` 拒绝，不能静默删除进程正在使用的目录。
- 首轮真实 App session `/private/tmp/anselm-rig-ep173-20260810/sessions/20260810-050116` 冻结为红：确认文案没有本机文件/owner 保留说明，成功后 disk provider stale。红证据永久保留；stop-and-fix 增加 `runningPid > 0` 的 409 guard，补完整 en/zh 文案，成功同时刷新 owner roster 与 disk provider，并补 fixture、Flutter、REST contract 回归。
- fixed session `/private/tmp/anselm-rig-ep173-20260810/sessions/20260810-051303` 使用真实 Flutter macOS App、Computer Use、真实受管网关、三路 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 307.925000s` 录屏。真实 Function `ep173_delete_fixed` 的 env 占用 `2,403,614` bytes；Cancel 保持 row/disk，Confirm 后 owner roster 为空、disk 从 `477406205` 精确变为 `475002591`，Function 保留、env row/目录消失，detail/repeat delete 均为 404。
- 五通道：三路 SSE clean EOF，notifications `seq=1..4` 只有一次 `sandbox.env_deleted`；backend/REST/SQLite/文件系统一致且无应用 WARN/ERROR/panic/FATAL；frontend 只有已知 launcher 噪声；llmtap 真实连接 managed gateway，但确定性 DELETE 不伪造模型 completion。首个可见反馈 `33.3ms`，modal close 作为连续转场单独复核。详见 session 内 `EP-173-final-green.md`、REST/DB/SSE/LLM/frontend/latency evidence。
- 正式 anchors=`10/10` 后按 `G1 / F2 / measure:sandbox-env-delete / C4 / G2` 写入 `COVERAGE EP-173=✓✓✓✓✓`，账本 `1555→1560 judgments`；`gap-too-fast`/`discovery-collapse` 按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-173-sandbox-env-delete-ledger-reaudit.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 alarms clean=`1560`；coverage check=`848/305/0`。
- cleanup session `/private/tmp/anselm-rig-ep173-20260810/sessions/20260810-052400` 已删除临时 Function，正式 session/录屏/journals/evidence/红证据保留；定向 sandbox/backend/frontend/testend tests、`make -C docs verify`、`git diff --check` 均通过。批次二十九由 **48→49/50**，未到 50 格不跑统一长门禁、完整 testend 或提交；下一原子前线为 EP-174 `GET /api/v1/sandbox/disk-usage`。

## 2026-08-10 — EP-172 `GET /api/v1/sandbox/envs/{id}` 收口，批次二十九 48/50

- 产品目的：用户读取单个 Sandbox env 时必须理解它归属于哪个 Function/Handler、使用哪个 runtime、有哪些依赖以及当前状态；已知 id 的 list/detail manifest 要一致，未知 id 必须明确 `404 SANDBOX_ENV_NOT_FOUND`。该端点是机器级 API-only 详情，没有独立视觉入口，L4 以 Settings Sandbox owner 名册判定，L5 诚实记 `na`。
- 首轮真实 App/REST session `/private/tmp/anselm-rig-ep172-20260810/sessions/20260810-043638` 冻结为红：legacy env 返回 `deps:null`，Settings Functions 行显示内部复合 owner id；红证据 `/private/tmp/anselm-rig-ep172-20260810/env-detail-red.jsonl` 与旧 session 永久保留，不计绿。
- stop-and-fix 在 store 边界将空依赖归一为 `[]`，Function/Handler 新 env 写入父实体名，旧 env 在 sandbox read boundary hydrate 当前 owner name，`EnsureEnv` 也刷新持久 owner name；补 app/store/function/handler 回归、testend contract、API/foundation/settings 文档。
- fixed session `/private/tmp/anselm-rig-ep172-20260810/sessions/20260810-044951` 使用真实 Flutter macOS App、Computer Use、真实受管 Anselm gateway、独立三路 ssetap、llmtap、backend/frontend journal 和 `2784x1808 / 60fps / 162.153333s` 录屏。Settings Functions 显示 `ep172_detail_probe`；list/detail 均为 `ownerName=ep172_detail_probe`、`deps=[]`、`ready`，missing id 为 `404 SANDBOX_ENV_NOT_FOUND`。
- 五通道：三路 SSE 连接并 clean EOF，本只读端点没有伪造业务 durable frame；llmtap 仅 ready 是正确边界；managed challenge/install/models 全 `200`；backend 无 panic/FATAL/WARN/ERROR，frontend 无未解释 Flutter/Dart/layout/Unhandled 红线。证据为 session 内 REST/DB/SSE/LLM/frontend summaries、`EP-172-settings-ownername.jpg`、`EP-172-latency.txt` 和 `EP-172-final-green.md`。原始 SQLite legacy row 仍是 `owner_name=''`、`deps=NULL`，读边界投影与文档对此均诚实标注，新建/EnsureEnv 会写回 owner name。
- 正式 anchors=`10/10` 后按 `measure:sandbox-env-detail / F2 / A1 / C5 / G2` 写入 `COVERAGE EP-172=✓✓✓✓~`，账本 `1550→1555 judgments`；`gap-too-fast`/`discovery-collapse` 依据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-172-ledger-alarm-reaudit.md` 独立复审并 ack，未改阈值/算法/法典/锚点/gate，最终 alarms clean=`1555`；`gen_coverage.py --check`=`848/304/0`。
- 定向 `mise exec -- go test -count=1 ./internal/app/sandbox ./internal/infra/store/sandbox ./internal/app/function ./internal/app/handler ./internal/bootstrap`、testend Sandbox contract、`git diff --check` 和覆盖 check 全绿。EP-172 专用数据目录按用户授权移入 Trash，正式 session/录屏/journals/evidence/formal ledger 与红证据保留；批次二十九由 **47→48/50**，未到 50 格不跑统一长门禁、完整 testend 或提交；下一原子前线为 EP-173 `DELETE /api/v1/sandbox/envs/{id}`。

## 2026-08-10 — EP-171 `GET /api/v1/sandbox/envs` 收口，批次二十九 47/50

- 产品目的：Sandbox 五个 owner tab 必须把 loading、error、settled-empty 分开；Functions、Handlers、MCP、Skills、Conversations 的 owner、依赖、大小、状态和失败原因必须与 REST/SQLite 真相一致，切 tab 不得串数据。
- 首轮真实 App session `/private/tmp/anselm-rig-ep171-20260810/sessions/20260810-035855` 冻结为红：`.value`/空列表把 loading 或后端错误伪装成 `No environments yet`；修复后的中间 session `/private/tmp/anselm-rig-ep171-20260810/sessions/20260810-040709` 又抓到 failed 行错误在单行 meta 中变成 `failed: dependen…`。两轮红证据永久保留，不计绿。
- stop-and-fix 在 `_EnvList` 使用 `AnLastGood` 三态、错误 Retry 和 settled-empty；把 backend `errorMsg` 放进 `AnRow.hint` 双行信息层，meta 只显示 deps/size/status；补 `envListErrors` fixture、i18n、11 项 Sandbox widget tests 和 Settings 文档契约。
- 最终 session `/private/tmp/anselm-rig-ep171-20260810/sessions/20260810-040910` 使用真实 Flutter App、Computer Use、窗口录屏、backend journal、独立三路 SSE witness、llmtap 和受管 gateway wiring，录屏 `2784x1808 / 60fps / 404.886667s`。五个 tab 最终分别显示 `inventory sync`、完整 `dependency install failed` 的 `reporter`、`building…` 的 `filesystem`、`markdown cleaner`、`EP171 scratch`；跨 Handlers→Functions 后无 owner 残留、空白、裁切或溢出。
- REST/SQLite：缺 owner kind=`400 SANDBOX_OWNER_KIND_REQUIRED`，bogus=`400 SANDBOX_INVALID_OWNER_KIND`；五个合法 kind 各一行；SQLite `5 env + 1 runtime`，env=`35840` bytes、runtime=`20480` bytes、total=`56320`，REST disk usage 同为 `56320`。failed `errorMsg`、installing status、依赖数组和 owner identity 三面一致。
- 五通道：rig-check 收台前通过；SSE 三流连接并在 rig-down 以 EOF 断开，本只读名册没有伪造业务帧；llmtap 只有 ready 是正确边界；backend 无应用 WARN/ERROR/panic/FATAL，frontend 仅已知 launcher foreground 噪声，无 Dart/Flutter/layout/Unhandled/lost-device 红线。最终证据为 session 内 REST/DB/SSE/LLM/frontend summaries、五张 owner 帧、`EP-171-final-green.md`。
- 逐帧：Handlers 点击前最后稳定帧到下一帧可见反馈 `16.7ms`，`changedFrac=0.00165`、bbox=`(1058,714)-(2375,885)`；下划线 `AnMotion.mid` spring 约 `133ms` 落位，不是数据错位。见 `EP-171-latency.txt`。
- formal anchors=`10/10` 后按 `measure:sandbox-env-list / F2 / A1 / C4 / G2` 写入 `COVERAGE EP-171=✓✓✓✓✓`，正式账本 `1545→1550 judgments`；`gap-too-fast`/`discovery-collapse` 经 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-171-sandbox-env-list-ledger-reaudit.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 alarms clean=`1550`，`gen_coverage.py --check`=`848/303/0`。
- 期间一次 shell 未 export `RIG_HOME`，五条裁决也落入默认个人 journal；未删除 append-only 审计记录，已备份并明确排除 campaign authority，formal rig 已在完整复核后重新落账，默认误路由警报已单独 ack。专用数据目录 `/private/tmp/anselm-data-ep171-20260810` 已按授权移入 Trash，session/证据/formal ledger 保留。
- 定向 `flutter test test/features/settings/s5_sandbox_test.dart`=`11/11`、`flutter analyze`、后端 handler/store tests、`make -C docs verify`、`git diff --check`、coverage check 全绿。批次二十九由 **46→47/50**，未到 50 格不跑统一长门禁、完整 testend 或提交；下一原子前线为 EP-172 `GET /api/v1/sandbox/envs/{id}`。

## 2026-08-10 — EP-170 `DELETE /api/v1/sandbox/runtimes/{id}` 收口，批次二十九 46/50

- 产品目的：用户确认删除 runtime 后，本机文件必须永久移除；仍被 environment 引用时必须明确拒绝；取消确认不得 mutation；成功后 App、REST、SQLite 与机器级 disk usage 必须共同回到真实空态；确认文案必须说明永久删除本机文件且之后可重新安装。
- 首轮真实 App session `/private/tmp/anselm-rig-ep170-20260810/sessions/20260810-032438` 冻结为红：删除确认只显示 `Deletes “uv 0.11.4”; rejected if envs still reference it.`，没有永久删除/可重新安装说明。第二轮 `/private/tmp/anselm-rig-ep170-20260810/sessions/20260810-033409` 又抓到删除成功后 runtime 与文件已消失但 UI 仍显示旧 `45.4 MB`，前端只刷新 roster、没有刷新机器级 disk provider。两份红证据永久保留，不计绿。
- stop-and-fix 更新 `en/zh` 删除确认文案；Sandbox install/delete 成功后显式 invalidate `sandboxDiskProvider`；fixture 增加确定性 `diskAfterRuntimeDelete`；补真实鼠标 hover/cancel/confirm Flutter 回归测试，并同步 `docs/references/frontend/features/settings.md` 的 disk truth、永久删除、env guard 和 cancel contract。
- fixed session `/private/tmp/anselm-rig-ep170-20260810/sessions/20260810-033823` 使用全新数据目录、真实 Flutter macOS App、Computer Use、真实受管 Anselm gateway、独立三路 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 30fps / 233.596667s` 封口录屏。安装 `uv 0.11.4` 后真实 UI 显示 `45.4 MB`；Cancel 保持 runtime 不变；Confirm 后稳定显示 `Disk usage 0 B`、`No runtimes yet`、`No environments`。
- REST/SQLite/文件系统：成功 DELETE=`204`，list=`200/data:[]`，disk=`200/totalBytes:0`，SQLite runtime 为空，sandbox=`0B`；未知/重复 DELETE=`404 SANDBOX_RUNTIME_NOT_FOUND`。真实持久 `sandbox_envs` 引用时 DELETE=`409 SANDBOX_ENV_IN_USE` 且 runtime 保留；清 env 后再删，最终三面全空。负向和清理矩阵在 `EP-170-rest-matrix.txt`。
- 五通道：messages/entities/notifications 三流各连接一次并 clean EOF；仅清理 guard env 产生一条真实 `sandbox.env_deleted` durable notification，runtime install/delete 没有 E 契约 lifecycle frame，证据如实记为无 runtime frame；managed challenge/install/models 经 llmtap 全 `200`，本设置路径没有模型调用；backend 无应用 WARN/ERROR/panic/FATAL；frontend 只有已知 launcher `Failed to foreground app; open returned 1`，无 Flutter/Dart/layout/Unhandled/Exception 红线。证据为 `EP-170-final-green.md`、`EP-170-sse-summary.txt`、`EP-170-llm-summary.txt`、`EP-170-frontend-terminal-review.md`。
- 逐帧：30fps 封口录像中确认后的首次可见转场反馈 `33.3ms`，`changedFrac=0.09139`，bbox=`(227,0)-(2384,1600)`；modal dismiss 与最终 `0 B` 空态分别由转场和稳定帧复核，测量未冒充 provider 收敛时间。详见 `EP-170-latency.txt` 与 `EP-170-transition-montage.png`。
- 正式账本以 anchors=`10/10` 解锁后写入 `measure:sandbox-runtime-delete / F2 / A1 / C4 / G2`，`COVERAGE EP-170=✓✓✓✓✓`，中央账本 `1540→1545 judgments`。写账触发的 `gap-too-fast`/`discovery-collapse` 经 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-170-delete-runtime-ledger-reaudit.md` 独立复审并 ack；未改阈值、算法、法典、锚点或 gate，最终 `alarms.py check`=`clean (1545 judgments)`；`gen_coverage.py --check`=`848 rows / 302 carried judgments / 0 tombstones`。
- 定向 `flutter test test/features/settings/s5_sandbox_test.dart`=`9/9` 通过，相关格式/文档同步完成。批次二十九由 **45→46/50**，未满 50 格不跑统一长门禁、完整 testend 或提交；下一原子前线为 `EP-171 GET /api/v1/sandbox/envs`。P12 旅程 400+ 按用户裁定推迟二期。

## 2026-08-10 — EP-169 `POST /api/v1/sandbox/runtimes` 收口，批次二十九 45/50

- 产品目的：真实用户在 Settings → Sandbox → Install 选择 runtime kind/version 后，必须看到真实进行中反馈；成功状态要在 App、REST、SQLite 闭环；重复安装不得重复写入；版本错误要在下载前给出可行动提示；无取消协议时安装进行中不能把 Cancel 伪装成可用。
- 首轮真实 App session `/private/tmp/anselm-rig-ep169-20260810/sessions/20260810-024930` 冻结为红：`uv not-a-version` 只得到泛化 install error。第二轮 `/private/tmp/anselm-rig-ep169-fixed-20260810/sessions/20260810-030057` 又抓到 Cancel 在同步安装中仍可点击，用户退出表单但后台继续安装并在 `33.469s` 后返回 `201`。两份红证据和录像永久保留，不计绿。
- stop-and-fix 新增结构化 `SANDBOX_RUNTIME_VERSION_UNSUPPORTED`，保留 `kind/version/hint`；其他安装失败带 `SANDBOX_RUNTIME_INSTALL_FAILED` 和 runtime identity；前端显示本地化 actionable 文案，`_busy` 时锁住 Install/Cancel；补 Go domain/infra/app 测试、Flutter Sandbox widget tests、i18n、API/error/foundation/settings 文档。
- fixed session `/private/tmp/anselm-rig-ep169-fixed2-20260810/sessions/20260810-030537` 使用全新数据目录、真实 Flutter macOS App、真实受管 Anselm gateway、Computer Use、独立三路 ssetap、llmtap、backend/frontend journals 和 `2784x1808 / 60fps / 363.938333s` 封口录屏。真实安装 `uv 0.11.4`，中途显示 `Installing…`，最终 UI 为 `uv 0.11.4 / 45.4 MB`、Environments 为空。
- 同一 `uv 0.11.4` 重复 POST 返回 `201 / elapsed_ms=0`，SQLite 只有一行，`idx_sandbox_runtimes_kind_version` 唯一索引存在；UI `not-a-version` 返回 `422 SANDBOX_RUNTIME_VERSION_UNSUPPORTED`、hint=`0.11.4` 且不发起下载；直接 REST 还验证 python `3.10`=`422`、unknown field=`400 INVALID_REQUEST`、缺 workspace=`401 UNAUTH_NO_WORKSPACE`。
- 五通道/真相：三路 SSE 各连接一次并在 rig-down 时 clean EOF；本路径只改 Sandbox runtime，不产生 messages/entities/notifications durable business frame，已在 `EP-169-sse-summary.txt` 如实记为无业务帧。SQLite/REST 一致为一条 uv runtime、零 env；managed challenge/install/models 经 llmtap 全 `200`；frontend 仅已知 launcher/TSM 噪声；backend 无应用 WARN/ERROR/panic/FATAL。
- 逐帧证据：60fps 录屏中错误提交前一帧到 actionable error 首帧 `16.7ms`，`changedFrac=0.00446`，bbox=`(1048,648)-(1990,800)`；长安装由 `Installing…` 承担，不把下载耗时冒充反馈延迟。证据文件包括 `EP-169-final-green.md`、REST/SSE/LLM/frontend summaries、latency、两张 UI 画面。
- 正式账本以 anchors `10/10` 解锁后，由 `judge.py` 写入 `measure:sandbox-runtime-install / F2 / A1 / C4 / G2`，`COVERAGE EP-169=✓✓✓✓✓`，中央账本 `1535→1540 judgments`。写账触发的 `gap-too-fast`/`discovery-collapse` 经 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-169-sandbox-runtime-install-ledger-reaudit.md` 独立复审并 ack；红证据、负向矩阵和无业务帧事实均保留，未改阈值/算法/法典/锚点/gate，最终 alarms clean=`1540`。
- 定向 Go、Flutter test/analyze、slang、format、`git diff --check` 通过；`gen_coverage.py --check`=`848 rows / 301 carried judgments / 0 tombstones`。临时数据目录按用户批准移入 Trash，session/录屏/journals/evidence/formal ledger 保留。
- 批次二十九由 **40→45 / 50**，未满 50 格不跑统一长门禁、完整 testend 或提交；下一原子前线为 `EP-170 DELETE /api/v1/sandbox/runtimes/{id}`。P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-10 — EP-168 `GET /api/v1/sandbox/runtimes/available` 收口，批次二十九 40/50

- 产品目的：Sandbox 安装目录必须返回真实 user-facing runtime kind、默认版本和 pinned/open 语义；切换 kind 后版本字段必须立即跟随新 kind，固定版本只能选目录内值，自由版本不能继承上一个 kind 的输入；取消安装不得产生假的 runtime/environment。
- 第一轮真实 App 在 session `/private/tmp/anselm-rig-ep168-20260810/sessions/20260810-022136` 冻结为红：`dotnet`→`uv` 后仍显示 `10.0.300`，而目录返回 `uv` 默认 `0.11.4`。红证据 `evidence/EP-168-red-stale-version.md` 与画面永久保留，不计绿；stop-and-fix 以 kind 作为开放版本输入的状态身份，切换时用后端 default 重建字段，并补 Sandbox widget 回归。
- fixed session `/private/tmp/anselm-rig-ep168-fixed-20260810/sessions/20260810-023115` 使用全新数据目录、真实 onboarding、真实 Flutter App、真实受管 Anselm gateway、Computer Use、独立三路 ssetap、llmtap、backend/frontend journals 与 `2784x1808 / 60fps / 308.378333s` 封口录屏。真实 UI 验证 `dotnet/node/python/uv` 四类；`uv` 显示 `0.11.4`，Python 仅 `3.11/3.12/3.13`，Node 仅 `22`；最终取消并回到稳定 Sandbox 空态，无安装 mutation。
- 五通道/真相：三流各连接一次并 clean EOF；只读目录路径没有 durable SSE frame，已如实记录。REST `available`=`200/287 bytes/0ms`，installed=`200/data:[]`，缺 workspace=`401 UNAUTH_NO_WORKSPACE`；SQLite `sandbox_runtimes`/`sandbox_envs` 均为零行；managed challenge/install/models 经 tap 全 `200`；backend 无 WARN/ERROR/panic/FATAL，frontend 只有已知 launcher foreground 噪声，无 Flutter/Dart/layout/Unhandled 红线。
- 逐帧测量：10fps 窗口以 Sandbox 空态为 action，Install 表单首个可见变化 `100.0ms`，`changedFrac=0.01755`，bbox=`(1048,259)-(2392,1373)`。正式证据为 session `EP-168-final-green.md`、`EP-168-rest-matrix.txt`、`EP-168-sse-summary.txt`、`EP-168-llm-summary.txt`、`EP-168-frontend-terminal-review.md`、`EP-168-latency.txt` 和五张视觉帧。
- 五级裁决写入 `measure:sandbox-runtime-catalog / F2 / A1 / C4 / G2`，`COVERAGE EP-168=✓✓✓✓✓`，正式账本 `1530→1535 judgments`；写账触发的 `gap-too-fast`/`discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-168-sandbox-available-ledger-reaudit.md` 独立复审并逐条 ack，未改阈值、算法、法典、锚点或 gate，最终 alarms clean=`1535`；anchors=`10/10`，`gen_coverage.py --check`=`848 rows / 300 carried judgments / 0 tombstones`。
- 批次二十九由 **35→40/50**，未到用户规定的 50 格，不跑统一长门禁、完整 testend 或提交；下一原子前线为 EP-169 `POST /api/v1/sandbox/runtimes`。P12 旅程 400+ 按用户裁定推迟二期。

## 2026-08-10 — EP-167 `GET /api/v1/sandbox/runtimes` 收口，批次二十九 35/50

- 产品目的：Sandbox 必须区分 settled empty、loading 和读取失败；用户在真实 Settings → Sandbox 安装一个真实 runtime 后，App、REST、SQLite 必须表达同一条机器级事实，长安装等待必须有可见状态。
- 静态前置审查抓到真实产品红线：runtime provider 失败被 `value ?? []` 伪装成 `No runtimes yet`。stop-and-fix 改为 `AnLastGood` 的 skeleton/error+Retry/settled-empty 三态；fixture 改为持久 `ApiException`，Flutter widget tests 5 项、analyze、format 全绿。红线不计绿但修复与回归保留在工作树。
- 正式真实 session `/private/tmp/anselm-rig-ep167-20260810/sessions/20260810-020306` 使用全新数据目录、真实 onboarding、真实 Flutter App、真实受管 Anselm gateway、Computer Use、独立三路 ssetap、llmtap、backend/frontend journals 与 `2784x1808 / 60fps / 250.355000s` 封口录屏。真实 UI 走过 `data: []` 空态、Install 表单、`node/22`、`Installing…` 和最终 `node 22 / 176.3 MB`；无红卡、死 spinner、overflow 或错误空态。
- 五通道/真相：messages/entities/notifications 各连接一次、clean EOF 断开；本 GET 路径没有 durable SSE frame，已如实记录；backend install=`201 / 4816ms`、随后 list=`200 / 0ms`，缺 workspace=`401 UNAUTH_NO_WORKSPACE`；REST 与 SQLite 同为 `sr_44fa65f6ee586816|node|22|runtimes/node/22|184839302`；managed challenge/install/models 经 tap 全 `200`；backend 无应用 WARN/ERROR/panic/FATAL，frontend 只有已知 launcher foreground 噪声，无 Flutter/Dart/layout/Unhandled 红线。
- 逐帧测量：10fps、ROI `1000,520,800,220`、action index `145` 到首个 `Installing…` 反馈 `100.0ms`，`changedFrac=0.06705`；安装长耗时另由按钮状态承担。证据为 session `evidence/EP-167-final-green.md`、`EP-167-sse-summary.txt`、`EP-167-db-final.txt`、`EP-167-llm-summary.txt`、`EP-167-frontend-terminal-review.md`、`EP-167-latency.txt` 和三张 UI 帧。
- 五级裁决写入 `measure:sandbox-runtime-list / F2 / A1 / C4 / G2`，`COVERAGE EP-167=✓✓✓✓✓`，正式账本 `1525→1530 judgments`；写账触发的 `gap-too-fast`/`discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-167-sandbox-runtime-ledger-reaudit.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 alarms clean=`1530`；anchors=`10/10`，`gen_coverage.py --check`=`848 rows / 299 carried / 0 tombstones`。
- 批次二十九由 **30→35/50**，未到用户规定的 50 格，不跑统一长门禁、完整 testend 或提交；下一原子前线为 EP-168。P12 旅程 400+ 按用户裁定推迟二期。

## 2026-08-10 — EP-166 `GET /api/v1/conversations/{conversationId}/touchpoints` 收口，批次二十九 30/50

- 产品目的：真实对话创建文档后，Activity 触点台账、REST keyset、durable touchpoint signal、SQLite、LLM 工具结果和最终 UI 必须表达同一条 Created 事实；随后搜索同一文档必须成功收敛，不留失败工具行或死 spinner。
- 首轮真实 session `/private/tmp/anselm-rig-ep166-20260810/sessions/20260810-012443` 抓到两个真实 hosted-model 参数边界问题：`create_document.tags` 是精确 JSON 编码数组字符串，`search_documents.limit` 是精确整数字符串。错误状态在真实 Activity 中可见；红 session 和分析永久保留，不计绿。
- stop-and-fix 新增共享 `decodeDocumentTags`：标准数组与精确 JSON 编码数组字符串兼容；`search_documents.limit` 只兼容原生整数与精确十进制整数字符串。逗号拼接 tags、浮点、任意字符串、数组和布尔值仍拒绝；工具 schema、描述、Go 回归测试和 `docs/references/backend/domains/document.md` 同步。
- fixed session `/private/tmp/anselm-rig-ep166-fixed-20260810/sessions/20260810-014119` 使用全新数据目录、真实 onboarding、真实 Flutter App、真实受管 Anselm gateway、Computer Use、`2784x1808 / 60fps / 242.446667s` 封口录屏、backend/frontend journals、三路 ssetap 和 llmtap。真实 `create_document` 携带 `tags:"[]"` 成功创建 `EP166 Fixed Note`；真实 `search_documents` 携带 `limit:"5"` 成功找到它；最终 UI 显示 `1 touched`、`Created`、成功搜索卡和可用 Composer。`the requested item` 为 loop opaque-ID redaction 的预期结果，真实 ID 在 durable tool blocks 中保留。
- 五通道/DB：messages durable `1..29` 无 gap；entities 观测到 touchpoint seq=`9`；notifications `1..3`；SQLite/REST 均为一篇文档和一条 assistant-created touchpoint，`hasMore=false`；user/assistant/tool blocks 全 completed，assistant `end_turn`，无 pending/streaming/error；managed challenge/install/models/chat 全 `200`；backend 无应用 WARN/ERROR/panic/FATAL，frontend 除已知 launcher foreground 噪声外无 Dart/Flutter/layout/Unhandled 红线。`measure latency` 首个可见搜索反馈=`100ms`（10fps，`changedFrac=0.05281`）。证据为 session `evidence/EP-166-final-green.md`、`EP-166-sse-summary.txt`、`EP-166-db-final.txt`、`EP-166-llm-summary.txt`、`EP-166-frontend-terminal-review.md`、`EP-166-latency.txt`、`EP-166-fixed-final-ui.jpg` 和 `EP-166-fixed-search-ui.jpg`。
- 定向 Go document/tool/handler tests、`git diff --check` 全绿。五级裁决写入 `measure:touchpoint-ledger / F2 / A1 / C4 / G2`，`COVERAGE EP-166=✓✓✓✓✓`，正式账本 `1520→1525 judgments`；写账触发的 `gap-too-fast`/`discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-166-touchpoint-ledger-reaudit.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 alarms clean=`1525`；anchors=`10/10`，`gen_coverage.py --check`=`848 rows / 298 carried judgments / 0 tombstones`。
- 批次二十九由 **25→30/50**，未到用户规定的 50 格，不跑统一长门禁、完整 testend 或提交；下一原子前线为 EP-167。P12 旅程 400+ 按用户裁定推迟二期。

## 2026-08-10 — EP-165 `GET /api/v1/conversations/{conversationId}/todos` 收口，批次二十九 25/50

- 产品目的：真实模型写入的整张 Todo 清单必须能由 REST 水化、由 messages durable `todo` signal 整表替换并在 Activity/Tasks 中显示；completed 项必须可经 `todo_read` 从保存真相读回；`todo_write([])` 后 REST/SQLite 是空数组、Tasks 行消失，恢复后再与最终画面一致。
- 真实 session `/private/tmp/anselm-rig-ep165-20260810/sessions/20260810-010359` 使用全新数据目录、真实 onboarding、真实 Flutter App、真实受管 Anselm gateway、Computer Use、`2784x1808 / 60fps / 364.420000s` 录屏、backend/frontend journals、三路 ssetap 和 llmtap。真实 Todo 初始写入后第二态为 `SSE=completed`、`TODO-EP165=in_progress`；真实打开 Activity/Tasks，右侧 ring=`1/2`，展开后完成勾与进行中点、标签准确。
- 真实 `todo_read` 回执 `Read checklist · 2 items · 1 done`；真实 `todo_write([])` 回执 `Checklist cleared`，Tasks 行消失，REST 与 SQLite 同为 `[]`；随后恢复 `EP165 REST verified=completed`、`EP165 final evidence=in_progress`，最终帧恢复 `1/2`。未知 conversation 在合法 workspace 下返回立法的空清单语义；无效 workspace 被 auth 拒绝为 `UNAUTH_NO_WORKSPACE`。
- 五通道/DB：messages durable seq=`1..66` 单调唯一，todo signal 在 seq=`9/16/45/60` 分别记录初始/进度/清空/恢复；notifications=`1..2`，entities 已物理连接。SQLite 最终主清单两项 JSON 与画面一致，四条 user/assistant 均 completed、assistant `end_turn`、无 pending/streaming/error；managed challenge/install/models/chat 全 `200`；backend 无应用错误；frontend 只有已知 launcher foreground 噪声，无 Flutter/Dart/layout/Unhandled 红线。证据为 session `evidence/EP-165-final-green.md`、`EP-165-sse-summary.txt`、`EP-165-db-final.txt`、`EP-165-llm-summary.txt`、`EP-165-frontend-terminal-review.md`、`EP-165-latency.txt`、`EP-165-final-ui.jpg`。
- 中文 Computer Use 长句一次未逐字抵达 App，已作为外部输入通道限制记录，不计入产品判断；后续 ASCII 路径逐字由 App/LLM wire/SQLite/SSE 互证，未隐藏该事实。
- 定向 Go 三包测试、Flutter Todo/Rundown/Activity `31 tests`、Flutter analyze、`measure latency`=`16.7ms` 全绿。五级裁决写入 `measure:todo-truth / F2 / A1 / C4 / G2`，`COVERAGE EP-165=✓✓✓✓✓`，账本 `1515→1520 judgments`；`gap-too-fast`/`discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-165-todo-ledger-reaudit.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 alarms clean=`1520`。
- 批次二十九由 **20→25/50**，未到 50 格不跑统一长门禁、完整 testend 或提交；下一原子前线为 EP-166。P12 旅程 400+ 按用户裁定推迟二期。

## 2026-08-10 — EP-164 `GET /api/v1/conversations/{id}/anchors` 收口，批次二十九 20/50

- 产品目的：真实用户在当前聊天打开 Scenes 后能看到全量场次锚点；点击当前现场回合只给反馈并留在现场，已载历史行近跳，未载行才深跳；keyset 必须翻到服务端结束，纯附件回合必须有可读标题。
- 首轮真实 session `/private/tmp/anselm-rig-ep164-20260810/sessions/20260810-003558` 抓到真实前端竞态：首轮 REST 水化早于消息产生，目标仍在 `live` 层；首次点击当前场次被 `settled`-only 判定为深跳，出现多余“回到现场”并错误脱离现场。红证据 `evidence/EP-164-live-anchor-red.md` 和录像永久保留，不计绿；立即冻结前线。
- stop-and-fix：`ConversationTranscript.containsLiveTurn` + `TranscriptJumpResult.present` 明确区分现场/近跳/深跳；present 只洗亮，不释放 pin、不重置 scroll、不调用 `?around=`；补 transcript model/controller regression。场次 provider 移除静默 40 页截断，超过显式护栏或游标不前进进入可重试错误；纯附件 user anchor 显示本地化“附件”。
- fixed session `/private/tmp/anselm-rig-ep164-fixed-20260810/sessions/20260810-004656` 使用全新数据目录、真实 onboarding、真实受管 gateway、Computer Use、`2784x1808 / 60fps` 录屏、frontend/backend journal、三路 ssetap、llmtap。真实发送 `Reply with exactly EP164-FIXED and nothing else.` 得到精确 `EP164-FIXED`；打开 Scenes 后**首次**点击当前场次，AX 树无 `Jump to present`，稳定截图与录像显示仍留在现场。
- 五通道/DB：messages durable=`1..8`、notifications=`1..2` 单调唯一，entities 已连接且无本路径 durable entity mutation；LLM challenge/install/models/chat 全 `200`；SQLite 仅一条 completed user、一条 completed assistant、三条 completed blocks，`stop_reason=end_turn`，无 pending/streaming/error；受管 key base URL 实际指向 `http://127.0.0.1:9013/v1`；backend 点击后无新的 `/messages` 深跳请求。frontend 只有已知 runner 启动提示，无 Flutter/Dart/布局/Unhandled 红线；录屏 `226.656667s` 已封口，红绿证据均保留。
- 定向 `flutter test`（19 tests）、Flutter analyze、slang/dart format、coverage check、`git diff --check` 全绿。五级裁决脚本写入 `measure:anchor-navigation / F2 / A1 / C4 / G2`，`COVERAGE EP-164=✓✓✓✓✓`，正式账本 `1510→1515 judgments`；anchors=`10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 经 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-164-ledger-alarm-reaudit.md` 独立复审并 ack，未改阈值、算法、法典、锚点或 gate，最终 alarms clean(1515)；`gen_coverage.py --check`=`848 rows / 296 carried / 0 tombstones`。
- 批次二十九由 **15→20/50**，未到 50 格不跑统一长门禁、完整 testend 或提交；下一原子前线为 EP-165。P12 旅程 400+ 按用户裁定推迟二期。

## 2026-08-10 — EP-163 `POST /api/v1/conversations/{id}/interactions/{toolCallId}` 收口，批次二十九 15/50

- 产品目的：真实 `ask_user` 停泊后，用户能在 App 读懂并回答；resolve 只能作用于当前 workspace、当前 conversation 中真实 pending 的 tool-call；非法 action、错误 workspace、错误 conversation 和重复决议必须分别大声拒绝；正确决议后 UI、SSE、SQLite、LLM wire 一起收口。
- 首轮真实 session `/private/tmp/anselm-rig-ep163-20260810/sessions/20260810-001149` 抓到真实安全边界缺陷：同一 conversation/tool-call id 配另一个 workspace header 错误返回 `204` 并消费 pending broker 请求。红证据永久保留于 `evidence/EP-163-cross-workspace-defect.md`，不计绿；立即停场、收掉旧二进制。
- stop-and-fix 在 `chat.Service.ResolveInteraction` 前置 workspace-scoped `ConversationReader.Get`，再查 broker conversation 归属；补 `TestResolveInteraction_ConversationScoped`，同步 handler/API/domain 文档。修复后的真实 session `/private/tmp/anselm-rig-ep163-fixed-20260810/sessions/20260810-001739` 使用全新数据目录和新 binary 重跑。
- fixed session 由 conductor 归属真实 Flutter App、真实受管 Anselm gateway、Computer Use、`2784x1808` 窗口录屏、frontend/backend journals、三路 ssetap 与 llmtap；真实 UI 显示 awaiting 卡、`staging`/`production`、自由文本、`Don't answer`、`Send`，点击 production 后显示 Answered 并完成助手回合。
- 负向矩阵：`aprove`=`422 INTERACTION_INVALID_ACTION`；foreign workspace=`404 CONVERSATION_NOT_FOUND` 且 pending 快照不变；同 workspace 错 conversation=`404 NO_PENDING_INTERACTION`；缺 header=`401 UNAUTH_NO_WORKSPACE`；成功后 duplicate=`404 NO_PENDING_INTERACTION`。GET interactions 由 pending 变 `200 {data:[]}`。
- 五通道：messages durable `1..14`、notifications `1..3` 单调唯一；pending/resolved 是同一 tool-call 的 ephemeral signal，后续 durable tool_result=`production` 与 message close 对齐；entities 三路连接；managed challenge/install/models/chat 全 `200`；SQLite 仅一条 completed user/assistant，`stop_reason=end_turn`，无 pending/streaming/error；frontend/backend 无未解释应用红线。
- 定向 Go tests、`make -C docs verify`、coverage check、`git diff --check` 全绿。五级裁决脚本写入 `measure:interaction-lifecycle / F2 / A1 / C4 / G2`，`COVERAGE EP-163=✓✓✓✓✓`，正式账本 `1505→1510 judgments`；统计警报以 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-163-ledger-alarm-reaudit.md` 独立重审并 ack，最终 alarms clean(1510)，未改阈值、算法、法典、锚点或 gate。
- 批次二十九由 **10→15/50**，未到 50 格不跑统一长门禁、完整 testend 或提交；下一原子前线为 EP-164。P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-10 — EP-162 `GET /api/v1/conversations/{id}/interactions` 收口，批次二十九 10/50

- 产品目的：真实 `ask_user` 停泊后，问题/选项/awaiting 状态必须在 App 可理解呈现；离开再回来必须由 REST 快照恢复；作答后门收口、回合完成；未知/跨 workspace 不能伪装成空成功。
- 静态审计先发现真实 ownership bug：handler 直接读 broker-only `PendingInteractions`，跨 workspace/未知会话返回 `200 {data:[]}`。新增 `chat.Service.ListInteractions` ownership pre-check，handler 统一 N1 error mapping；保留内部无错误 helper，补 `TestConversationScopedReads_ForeignConversation404`，同步 API/domain 文档。
- 真实 session `/private/tmp/anselm-rig-ep162-20260809/sessions/20260809-235739` 由 conductor 管理真实 Flutter App、受管 Anselm gateway、Computer Use、60fps 录屏、frontend/backend journals、三路 ssetap 与 llmtap；录屏 `2784x1808 / 60fps / 365.093333s`。真实模型调用 `ask_user`，REST pending snapshot、离开重开后的 GET hydration、App 选择 `production`、最终 `Answered` 与 assistant 完成均通过。
- 五通道：messages durable `seq=1..14`、notifications `1..2` 单调唯一；ephemeral interaction/resolved signals 与 durable tool_result/close 互证；LLM challenge/install/models/chat 全 200；SQLite 一条 completed user + 一条 completed assistant，tool_call/tool_result/end_turn 一致；frontend/backend 无未解释应用红线。负向矩阵为已决 `200[]`、缺 header `401`、有效 foreign workspace `404`、unknown `404`；30 次 read median `1.290ms`、p95 `2.299ms`。
- 正式账本通过 `judge.py` 写入 `L1 measure:interaction-lifecycle / L2 F2 / L3 A1 / L4 C4 / L5 G2`，`COVERAGE EP-162=✓✓✓✓✓`，账本 `1500→1505`。批写触发的 `gap-too-fast`/`discovery-collapse` 经 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-162-ledger-alarm-reaudit.md` 独立复审并 ack，最终 alarms clean(1505)；anchors、阈值、算法、法典和 gate 未改。
- 定向 Go/handler/store tests、`make -C docs verify`、coverage check、`git diff --check` 全绿。批次二十九由 `5→10/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-163。

## 2026-08-09 — EP-161 `GET /api/v1/conversations/{id}/usage` 收口，批次二十九 5/50

- 产品目的：API-only usage 读必须返回当前 conversation 的真实 input/output token 成本；空对话返回零，Retry 的被取代 assistant 成本保留，跨 workspace/未知 id/缺失 workspace 分流诚实。
- 真实 session `/private/tmp/anselm-rig-ep161-20260809/sessions/20260809-233339` 由 conductor 归属真实 Flutter App、真实受管 Anselm gateway、Computer Use、独立三路 SSE witness、llmtap、backend/frontend journals 和 60fps 录屏；`screen.mov` 为 `2784x1808 / 60fps / 311.593333s`。真实 onboarding、空 conversation usage、两轮精确回复 `EP161-ONE`/`EP161-TWO`、真实 Retry 后稳定 `2/2` 均完成。
- REST/SQLite：两轮后 `29531/87/29618`；Retry 后 `44316/127/44443`。SQLite 保留 superseded assistant 并记录 `superseded_by`；空对话=`200` 零值，跨 workspace/unknown=`404 CONVERSATION_NOT_FOUND`，缺 workspace=`401 UNAUTH_NO_WORKSPACE`。矩阵和 DB 真相在 session evidence。
- messages SSE durable `1..22`、notifications `1..3` 严格单调，entities 已物理连接；managed challenge/install/models/chat 全 HTTP 200。utility auto-title 一次 200 只回 reasoning、无 `[DONE]`，按既定本地 fallback 生成可用标题，事实保留在 LLM evidence，不计作隐藏错误。
- frontend 只有已知 runner 启动噪声 `Failed to foreground app; open returned 1`，无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device/panic/fatal；backend 448 行无 WARN/ERROR/panic/fatal/exception。最终帧显示两轮、`2/2`、action row 和 Composer，无死 spinner、重复答案、布局跳变或隐藏 CTA。usage 30 次 backend-only latency median=`1.083ms`、p95=`1.592ms`、max=`1.768ms`。
- 本格触发的 stop-and-fix 是事实修正：Go 三处旧注释把历史 `tokensUsed` 计划写成“详情视图显示”，改为 API-only usage aggregate；没有凭空新增 Flutter UI。定向 Go 三包测试全绿，`git diff --check` 全绿；`gen_coverage.py --check`=`848/293/0`。
- 五级裁决脚本写入 `L1 measure:usage-sum pass / L2 F2 pass / L3 A1 pass / L4 na(API-only无visual surface) / L5 na(API-only无clickable control)`，`COVERAGE EP-161=✓✓✓~~`。写账触发 `gap-too-fast`/`discovery-collapse`，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-161-ledger-alarm-reaudit.md`，逐条 ack 后 alarms clean=`1500 judgments`，未改阈值、算法、法典、锚点或 gate。
- 批次二十九由 **0→5/50**，未到用户规定的 50 格，不跑统一长门禁、完整 testend 或提交；下一前线为 EP-162。P12 旅程 400+ 仍按用户裁定推迟二期。

## 2026-08-09 — EP-160 `GET /api/v1/conversations/{id}/system-prompt-preview` 五级收口，批次二十八 53/50

- 产品目的：preview 必须展示与真实模型回合一致、且受 workspace/conversation 隔离约束的系统提示；空对话、默认/自定义 prompt、workdir、locale、跨 workspace 和缺失资源都要给出可解释结果，而不是只验证 `200`。
- 真实 session `/private/tmp/anselm-rig-ep160-20260809/sessions/20260809-225559` 由 conductor 归属真实 Flutter App、真实受管 Anselm gateway、Computer Use、独立三路 SSE witness、llmtap、backend/frontend journals 与 60fps 录屏；`screen.mov` 为 `2784x1808 / 60fps / 312.325s`。真实 onboarding 与 Composer 回合输入 `EP160 HISTORY MARKER. Reply exactly EP160-REPLY and do not call tools.`，最终 UI 精确显示 `EP160-REPLY`，Composer、Copy/Fork/Retry/Read aloud 均可用，无死 spinner、重复消息、overflow 或隐藏 CTA。
- REST 矩阵覆盖主/空/自定义 prompt/自定义 workdir/第二 workspace `zh-CN`；正向均 `200`，unknown conversation=`404 CONVERSATION_NOT_FOUND`，缺失/非法 workspace=`401 UNAUTH_NO_WORKSPACE`，跨 workspace 访问=`404`。`Accept-Language` 不越权覆盖 workspace language，preview 分别得到 `Reply in English.` 与 `Reply in Chinese.`。
- preview 与真实 llmtap chat request 的 system message 均为 `31,415` bytes，SHA-256 均为 `bb8e2b5ffd715b9c5800421d1b7cd97714df1a7f0f078374117b435db43f03cd`；preview GET 不产生 completion，managed challenge/install/models/chat 全 HTTP `200`。SQLite 主回合 user/assistant 均 completed、`stop_reason=end_turn`，blocks 与 durable SSE seq 连续，三路 stream 均由独立 witness 物理连接。
- 五通道正式证据为 session 内 `evidence/EP-160-final-green.md`、`EP-160-sse-summary.txt`、`EP-160-db-final.txt`、`EP-160-llm-summary.txt`、`EP-160-frontend-terminal-review.md`、`EP-160-latency.txt` 和 `EP-160-final-ui.png`；backend 无应用 WARN/ERROR/panic/FATAL，frontend 除已知 launcher foreground 噪声外无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device/panic/fatal 红线。独立 latency session 的 30 次 preview median=`4.921ms`、max=`23.555ms`，满足 A1。
- 定向 backend chat、Flutter `chat_transcript_test.dart` `30/30` 和 prompt/chat testend 场景全绿。统一门禁完整通过：根 `make verify`（backend/frontend/docs/demo）全绿，独立 `go test ./...` 全绿，`make -C backend testend` 全量 `309.754s` 通过；testend 后无残留 server/llama/test 进程，`gen_coverage.py --check`=`848/292/0`，`git diff --check` 通过。
- anchors=`10/10`、写账前 alarms clean(1490)；脚本写入 `G1/F2/A1/C4/G2` 后中央账本 `1490→1495 judgments`，`COVERAGE EP-160=✓✓✓✓✓`。写账触发的 `gap-too-fast`/`discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-160-prompt-preview-ledger-reaudit.md` 独立复审并 ack，未改阈值、算法、法典、锚点或规则，最终 alarms clean(1495)。
- 批次二十八由 **48→53/50**，统一长门禁已收口；下一原子前线为 EP-161 `GET /api/v1/conversations/{id}/usage`，提交后启动。P12 旅程 400+ 按用户裁定推迟二期，一期仍以 COVERAGE 矩阵为覆盖真相。

## 2026-08-09 — EP-159 `POST /api/v1/conversations/{id}:retry` 五级收口，批次二十八 48/50

- 产品目的：用户在真实对话里重生成或编辑重发后，当前版本必须自动成为可读、可继续的版本；版本指针、历史可寻址性、SQLite、SSE、App 和模型 wire 必须表达同一事实，而不是只验证 `202`。
- 首轮真实 session `/private/tmp/anselm-rig-ep159-20260809/sessions/20260809-220855` 逐帧捕获产品红：编辑重发已经生成第 3 版，但 UI 仍停在旧的 `2/3` 版本选择；DB、SSE 和 LLM wire 正确，问题是前端保留过期 `_versionChoice`。同时 user `Open` 帧缺少 `RetryOf`，只在 `Close` 帧携带，违反版本指针契约。该 session 不计绿，红证据保留；stop-and-fix 修复 backend `emit.go` 的 user open 指针，并在 `chat_transcript.dart` 以 `_versionLatest` 清除过期选择，让新 retry 版本自动成为当前版本。
- 修复后二次真实 session `/private/tmp/anselm-rig-ep159b-20260809/sessions/20260809-224316` 由真实 rig 启动 rebuilt macOS App、真实受管 gateway、Computer Use、独立 SSE tap、LLM tap 和 60fps 录屏；真实完成 onboarding、原始对话、assistant Retry、键盘编辑重发，重启重开后显示编辑后的答案 `3/3`，再 Retry 后收敛到 `4/4`。最终画面无重复问句、旧版抢焦点、overflow、死 composer 或隐藏错误。
- REST/SQLite：`superseded_by` 与 `retryOf` 版本链完整，当前 assistant=`msg_f6b268d522dd70e0`，历史版本仍可寻址；当前 fixed retry 的 messages durable `seq=1..6` 严格连续，seq=0 delta 未污染游标，assistant open/close 均带正确 `retryOf`。entities、notifications、messages 三路均由独立 witness 物理连接。
- LLM wire 的 managed challenge/install/models 与 chat completion 全 HTTP 200，最终 user 内容精确为编辑后的句子；backend 无应用 WARN/ERROR/panic/FATAL，frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled 红线。Computer Use AX 树与最终截图交叉确认 `4/4`；动作帧、稳定帧和编辑重发最终帧均保留。
- 五通道证据封存在该 session 的 `evidence/EP-159-final-green.md`、`EP-159-sse-summary.txt`、`EP-159-db-final.txt`、`EP-159-llm-summary.txt`、`EP-159-frontend-terminal-review.md`、`EP-159-latency.txt`、`EP-159-edit-resend-final-green.png`、`EP-159-retry-final-green.png`、`frames/retry-action.png` 和 `frames/retry-settled.png`；首轮红 session、红分析和修复前画面保留。
- Go `internal/app/chat` 定向测试通过；Flutter `chat_transcript_test.dart` 定向测试 `30/30` 全绿。账本写入前 anchors=`10/10`、alarms clean(1485)；脚本写入 `G1/F2/A1/C4/G2` 后中央账本 `1485→1490 judgments`，`COVERAGE EP-159=✓✓✓✓✓`。写账触发的 `gap-too-fast`/`discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-159-ledger-reaudit.md` 独立复审并 ack，最终 alarms clean(1490)，未改阈值、算法、法典、锚点或规则。
- 本格结束后批次二十八由 **43→48/50**，还差 2 格；按用户“50 格后统一”裁定，未跑整批长门禁、完整 testend 或提交。P12 旅程 400+ 继续推迟二期；下一原子前线为 EP-160 `GET /api/v1/conversations/{id}/system-prompt-preview`。

## 2026-08-09 — EP-158 `POST /api/v1/conversations/{id}:fork` 五级收口，批次二十八 43/50

- 产品目的：用户从真实 assistant 回合点 `Fork from here` 后，必须得到一个可继续工作的独立线程；前缀复制、源线程隔离、分叉线程续聊，REST、SQLite、SSE、App 和模型 wire 必须共同表达同一事实，而不是只验证 `201`。
- 首轮真实 session `/private/tmp/anselm-rig-ep158-20260809/sessions/20260809-212709` 逐帧捕获产品红：分叉点击后约 600ms 内没有持久即时反馈，动作排看起来像“点了没反应”。该 session 不计绿，红证据保留；stop-and-fix 将 `TurnActions.onFork` 改为 `FutureOr`，加入 `_forking` 状态、固定几何的 `正在分叉…` 文案和重复点击阻断，并同步中英文 i18n、生成文件、`turn_actions_test.dart` 与 Chat 文档。
- 定向 Flutter `turn_actions_test.dart` 共 13 项全绿。修复后二次真实 session `/private/tmp/anselm-rig-ep158b-20260809/sessions/20260809-214700` 由真实 rig 启动 rebuilt macOS App、真实受管 gateway、Computer Use、独立 SSE tap、LLM tap 和 60fps 录屏；source 得到 `EP158B-REPLY`，点击真实 `Fork from here` 后打开 `(fork)`，续聊得到 `EP158B-FORK`。
- REST/SQLite：source=`cv_d017547a9ca77894` 只有 2 条 completed message / 3 个连续 blocks；fork=`cv_98ad5f34baa38c7e` 正确指向 source 与 cut message，拥有 4 条 completed message / 6 个连续 blocks，source 没有 fork 后消息。所有行均为 completed，fresh ids，无 pending/streaming/error 残留。
- SSE：三路 messages/notifications/entities 均物理连接；messages durable `seq=1..16` 连续，notifications `seq=1..3` 连续，43 条消息流记录中的 seq=0 delta 未污染游标。LLM wire 的 challenge/install/models 与三次 chat completion 全 HTTP 200；backend 无 ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/overflow/Unhandled 红线，唯一 launcher foreground warning 单独分类。
- 逐帧 A1：点击前最后稳定帧 `f00264`，下一帧 `f00265` 已发生路由反应，`changedFrac=0.02202`、bbox=`(218,116)-(2398,1620)`，首反馈 `16.7ms`。请求完成过快，busy 图标没有形成独立稳定帧；证据只宣称真实可见的 route feedback，不冒充 spinner 帧。尝试额外 source-only 输入时发现 Computer Use `set_value` 的 AX/截图同步差异，未发送草稿，SQLite 和源线程证据保持干净，作为台架边界单独记录。
- 五通道证据封存在该 session 的 `EP-158B-final-green.md`、`EP-158B-sse-summary.txt`、`EP-158B-db-final.txt`、`EP-158B-llm-summary.txt`、`EP-158B-frontend-terminal-review.md`、`EP-158B-latency.txt`、`EP-158B-before-fork.png` 和 `EP-158B-fork-continuation.png`；临时数据在审计后按用户授权移入 Trash，session 保留。
- anchors=`10/10`、写账前 alarms clean(1480)；脚本写入 `G1/F2/A1/C4/G2` 后为 `1485 judgments`，`COVERAGE EP-158=✓✓✓✓✓`。写账触发的 `gap-too-fast`/`discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-158-fork-ledger-reaudit.md` 独立复审并 ack，未改阈值、算法、法典、锚点或账本规则，最终 alarms clean(1485)。
- 本格完成后批次二十八由 **42→43/50**；按用户“50 格后统一”裁定，未跑整批长门禁、完整 testend 或提交。P12 旅程 400+ 继续推迟二期；下一原子前线为 EP-159 `POST /api/v1/conversations/{id}:retry`。

## 2026-08-09 — EP-157 `POST /api/v1/conversations/{id}:seen` 五级收口，批次二十八 42/50

- 产品目的：用户停止执行中的搜索后，前端必须显示中性 `Interrupted`/`Stopped`，不能把主动停止误报成 `Search failed`，更不能泄露 `Grep.execStdlib: context canceled`；随后 `:seen` 清掉 unread，重复调用幂等且不改 `last_message_at`。
- 首轮真实 session `/private/tmp/anselm-rig-ep157-20260809/sessions/20260809-210239` 捕获红：Grep 被 Stop 取消后 tool_result 以 `status=error` 携 raw context 错误收尾，UI 显示失败卡。红证据保留在 `evidence/EP-157-red-cancellation.md`，冻结本格并直接修复。
- 修复版真实 session `/private/tmp/anselm-rig-ep157-fixed-20260809/sessions/20260809-211301`：真实 Flutter App、真实受管 gateway、Computer Use、录屏 `2784x1808 / 60fps / 225.113333s`，同一搜索/Stop 路径复跑后只显示 `Interrupted`/`Stopped`；五秒静置稳定，无 raw error、死 spinner 或失败卡。最终截图为 `EP-157-fixed-stopped.png`。
- 修复把执行中取消收束为 `tool_result status=cancelled`、固定中性结果和空 wire error；前端按 tool_call/tool_result 任一取消锚点派生中性卡。Go `./internal/app/loop` 全包、Flutter `tool_card_state_test.dart` 与 `tool_card_builds_test.dart` 全部通过；后端与前端参考文档已同步。
- REST：App 自动 `:seen` 与额外两次显式 `POST ...:seen` 均 204；SQLite `unread=0`、`last_message_at` 不变。SSE messages durable `seq=1..10` 无缺口，取消 tool_result/assistant close 均 `cancelled` 且无 error；entities/notifications/messages 三路由独立 witness 连接。llmtap challenge/install/models 与两次 chat completion 全 200，第二次是 auto-title，不产生新 durable blocks。
- 五通道证据为 session 内 `EP-157-final-green.md`、`EP-157-rest-matrix.md`、`EP-157-sse-summary.txt`、`EP-157-db-final.txt`、`EP-157-llm-summary.txt`、`EP-157-frontend-terminal-review.md` 和 `frontend-ax-review.md`；backend 无 ERROR/panic/FATAL，frontend 无 Flutter/Dart/layout 红线。81 条固定 AXTree 调试桥噪声按 session 规则审阅，不以 grep 消音。
- anchors=`10/10`、写账前 alarms clean(1475)；`G1/F2/A1/C4/G2` 写入中央账本 `1475→1480 judgments`，`COVERAGE EP-157=✓✓✓✓✓`。写账触发的 `gap-too-fast`/`discovery-collapse` 由独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-157-seen-ledger-reaudit.md` ack，未改阈值、算法、法典、锚点或规则，最终 alarms clean(1480)。数据目录按用户授权移入 Trash，session/账本保留。
- 本格完成后批次二十八由 **41→42/50**；按用户“50 格后统一”裁定，未跑整批长门禁、完整 testend 或提交。P12 旅程 400+ 继续推迟二期；下一原子前线为 EP-158 `POST /api/v1/conversations/{id}:fork`。

## 2026-08-09 — EP-156 `POST /api/v1/conversations/{id}:cancel` 五级收口，批次二十八 41/50

- 产品目的：用户点 Stop 后，在途生成必须真实取消并持久化为 `cancelled` assistant row，Composer 立即恢复可用，下一轮可以正常完成；不能只凭 204 或单一 UI 状态判绿。
- 最终真实 session 为 `/private/tmp/anselm-rig-ep156-20260809/sessions/20260809-203558`，录屏 `2784x1808 / 60fps / 688.681667s`。Computer Use 在真实 App 中两次提交长流式回合、两次点击 Stop，看到 `Stopped`，随后新回合返回精确 `RECOVERED-OK`；accepted frames 为 `EP-156-cancelled.png` 与 `EP-156-recovered.png`。
- REST 矩阵记录两次真实 `POST ...:cancel` 均为 204，取消后历史读取 200，新回合仍接受 202；漏写冒号的 `...ancel` 404 被保留为 route-guard 负向证据，不冒充产品失败。SQLite 最终十条消息均终态，含两条 cancelled assistant，无 pending/streaming/error。
- 五通道正式证据为 session 内 `evidence/EP-156-final-green.md`、`EP-156-rest-matrix.md`、`EP-156-sse-summary.txt`、`EP-156-db-final.txt`、`EP-156-llm-summary.txt`、`EP-156-frontend-terminal-review.md`、`frontend-ax-review.md` 与 `EP-156-fixture-cleanup.md`。messages SSE durable `seq=1..36` 严格连续，三路 stream 均物理连接；llmtap 26 条记录中 16 条 HTTP 响应全部 200，恢复分片重组为 `RECOVERED-OK`。
- backend 810 行仅有一条取消竞态的 `context canceled` 增量落盘 WARN，finalize 成功；frontend 2983 行中的 2965 条固定 AXTree bridge tooling 噪声已独立复核且闲置不增长，另有一条 launcher warning，无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device 红线。60 fps 测量脚本记录最后生成帧到第一帧 `Stopped` 为 `16.7ms`。
- targeted tests 已通过：`mise exec -- go test -count=1 ./internal/app/chat ./internal/transport/httpapi/handlers`；`mise exec -- flutter test test/features/chat/ui/chat_composer_test.dart`（33/33）；`mise exec -- go test ./cmd/measure`。EP-156 无业务代码改动。
- 账本写入前 anchors=`10/10`、alarms clean(1470)；脚本写入 `G1/F2/A1/C4/G2` 后为 `1475 judgments`，`COVERAGE EP-156=✓✓✓✓✓`。`gap-too-fast`/`discovery-collapse` 由独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-156-conversation-cancel-ledger-reaudit.md` ack，最终 alarms clean(1475)，未改机制。隔离 fixture 已按授权通过 `/usr/bin/trash` 可恢复移除；正式 session、录屏、journals 和账本保留。
- 批次二十八由 **40→41/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-157 `POST /api/v1/conversations/{id}:seen`。P12 旅程 400+ 仍按用户裁定推迟二期。

## 2026-08-09 — EP-155 `GET /api/v1/conversations/{id}/messages` 五级收口，批次二十八 40/50

- 产品目的：真实用户能够在对话历史中稳定翻页、从 Scenes 深跳到旧目标、阅读目标上下文，再回到现场；REST cursor/around/dir、新旧排序、hydrated blocks、SSE 与 Flutter transcript 必须共同表达同一份历史真相。
- 最终真实 session 为 `/private/tmp/anselm-rig-ep155-20260809/sessions/20260809-201539`，录屏 `2784x1808 / 60fps / 382.738333s`，accepted frame 和 Computer Use 现场复核证明 Scenes、旧目标蓝色 wash、`Jump to present`、cancelled 行和可用 Composer 均可发现且稳定。
- REST 矩阵覆盖 newest-first 首页、cursor 第二页、around 目标窗口、older/newer continuation、最新目标边界，以及 malformed cursor、缺 cursor、非法 dir、参数冲突、missing target/conversation 的 400/404；正向响应均 hydrated blocks。
- 五通道正式证据为 session 内 `evidence/EP-155-final-green.md`、`EP-155-rest-matrix.md`、`EP-155-sse-summary.txt`、`EP-155-db-final.txt`、`EP-155-llm-summary.txt`、`EP-155-frontend-terminal-review.md` 与 `EP-155-fixture-cleanup.md`。messages SSE durable `seq=1..38` 严格连续；notifications/entities 均连接且本只读旅程无 durable event；LLM proof/install/models/五次 chat 全 HTTP 200。
- backend 520 行仅有一条因刻意 Stop 取消产生的 `context canceled` 增量落盘 WARN，finalize 成功；frontend 647 行中的 621 条 exact AXTree tooling 噪声已独立复核，闲置无增长，无 Dart/Flutter/RenderFlex/overflow/Unhandled/fatal 红线。SQLite 十条消息均终态（5 user completed、4 assistant completed、1 assistant cancelled），无 pending/streaming/error。
- targeted tests 已通过：`mise exec -- go test ./internal/infra/store/messages ./internal/app/chat ./internal/transport/httpapi/response ./internal/transport/httpapi/handlers`；EP-155 无业务代码改动。账本写入前 anchors=`10/10`、alarms clean(1465)，脚本写入 `G1/F2/A1/C4/G2` 后为 `1470 judgments`，`COVERAGE EP-155=✓✓✓✓✓`；`gap-too-fast`/`discovery-collapse` 由独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-155-messages-history-ledger-reaudit.md` ack，最终 alarms clean(1470)，未改机制。
- 460M fixture 在证据、账本和复审完成后按授权通过 `/usr/bin/trash` 移入 Trash；正式 session、录屏、journals、账本和复审保留。批次二十八由 **35→40/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-156 `POST /api/v1/conversations/{id}:cancel`。P12 旅程 400+ 仍按用户裁定推迟二期。

## 2026-08-09 — EP-154 `POST /api/v1/conversations/{id}/messages` 五级收口，批次二十八 35/50

- 产品目的：真实用户只附一张图也能完成完整对话回合；user 先落库并回声，assistant 流式打开并闭合，模型真实看见图片并给出可读答案；随后显式命中 `inspect_media` 时，受管网关的媒体预算不足也必须诚实降级，不能把上游 400 暴露给用户。
- 首轮真实附件 session `/private/tmp/anselm-rig-ep154-20260809/sessions/20260809-194419` 抓到真实产品红线：1,111,731-byte JPEG 的 model-default PNG proxy 为 5,238,623 bytes，网关返回 `BAD_REQUEST media exceeds the per-request decoded size limit`。stop-and-fix 改为按最终 staging bytes 计预算；proxy 超预算但原图可交付时回退原图，`inspect_media` 同样回退，二者都不可交付时返回结构化 budget-degraded 说明。定向 `internal/app/attachment`、`internal/app/tool/attachment`、`internal/bootstrap` Go tests 通过。
- 修复后二次真实 session `/private/tmp/anselm-rig-ep154-20260809/sessions/20260809-195358`：真实 Flutter App、真实受管 Anselm gateway、Computer Use、录屏 `2784x1808 / 60fps / 432.191667s`。真实走过附件菜单、macOS 文件选择器、`Preparing media...`、缩略图、attachment-only send、助手完成态，再在同一对话显式调用 `inspect_media`；最终 UI 有结构化表格、历史背景、操作行和可用 Composer，无红色工具失败、死 spinner、重复错误或布局跳变。
- 五通道证据封存在同 session 的 `evidence/EP-154-final-green.md`、`EP-154-sse-summary.txt`、`EP-154-db-final.txt`、`EP-154-llm-summary.txt`、`EP-154-frontend-terminal-review.md`、`EP-154-fixture-cleanup.md`。三路 SSE 均连接，messages durable seq=`1..24`；SQLite 四条 message、九条 block 全为 `completed`，无 pending/streaming/error/cancelled；llmtap 所有上传、primary chat、nested vision 和收尾响应为 `200/201`；backend 无应用 WARN/ERROR/panic/FATAL；frontend 仅保留已知 runner 启动噪声 `Failed to foreground app; open returned 1`，无 Dart/Flutter/RenderFlex/overflow/Unhandled 红线。发送到首个可见反馈为 `100.0ms`，满足 CODEX A1。
- 写账前 anchors=`10/10`、警报检查为 clean(1460)；五级 `G1/F2/A1/C4/G2` 写入中央账本 `1460→1465 judgments`，`COVERAGE EP-154=✓✓✓✓✓`。写入后按机制出现 `gap-too-fast` 与 `discovery-collapse`，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-154-messages-ledger-reaudit.md`，逐条 ack 后最终 `alarms.py check`=`clean (1465 judgments)`；未修改阈值、算法、法典、锚点或门禁规则。
- 本格结束时所有会话进程和监听均已归零；证据封存完成后，隔离数据目录 `/private/tmp/anselm-data-ep154-attachment-fixed-20260809` 已按用户授权通过 `/usr/bin/trash` 可恢复移除，session 证据和账本不受影响。P12 旅程 400+ 继续按用户裁定推迟二期，一期以 COVERAGE 矩阵为覆盖真相；不提前运行 50 格统一长门禁或提交。批次二十八由 **30→35/50**，下一原子前线为 EP-155 `GET /api/v1/conversations/{id}/messages`。

## 2026-08-09 — EP-153 `POST /api/v1/conversations/{id}/workdir:add-worktree` 五级收口，批次二十八 30/50

- 产品目的：让用户在真实对话里发现并理解平行工作树；创建仓库旁的 `wt/<name>` sibling worktree 并迁移当前 conversation；冲突目录、非法名称和既有但未 checkout 的分支分别得到明确、可行动的结果，不接管用户已有文件。
- 真实 session `/private/tmp/anselm-rig-ep153-20260809/sessions/20260809-190946`：真实 Flutter App、真实受管 Anselm gateway、Computer Use、录屏 `2784x1808 / 60fps / 512.488333s`。Computer Use 打开 workdir 菜单，初始长菜单经真实滚动后 Git 操作区和 `Open a worktree…` 可见；对话框说明平行 checkout、`wt/<name>`、迁移 conversation 且不自动 commit/push。真实输入 `session` 后创建 `/private/tmp/ep153-repo.ZkdbHn-session` / `wt/session`；再次创建 `reopen` 后复用预先存在的空闲 `wt/reopen`，App、REST、外部 Git 和 residency 均刷新到 `/private/tmp/ep153-repo.ZkdbHn-reopen`。Composer 两次经真实网关精确返回 `EP153-ACK`、`EP153-REOPEN-ACK`。
- 正向与负向交叉证据：首次创建 200、`dirty=false`、平面 sibling 路径；`taken` 返回 409 `CONVERSATION_WORKTREE_EXISTS` 并点名 `/private/tmp/ep153-repo.ZkdbHn-taken`，碰撞 sentinel SHA-256 前后均为 `70e85898d13a5318b2a0c59dad361eb2d9cd5be94208b5b16a3e1c21cc31c4cb`。`../escape`、`/absolute`、`nested/deep`、`..`、`-b` 均为 422 `CONVERSATION_INVALID_WORKTREE_NAME`；`reopen` 为 200 且不改变 main HEAD。已有 transcript 后第二次迁移恰落一个 `kind=workdir` marker；空线程第一次迁移不伪造 marker。最终 REST/SQLite 保留七条消息块与正确当前 workdir。
- 五通道正式证据为同 session `evidence/EP-153-final-green.md`；SSE=`evidence/EP-153-sse-summary.txt`：messages 29 records、16 durable、max seq=16，notifications 6 records、4 durable、max seq=4，entities connected 无 durable entity event；llmtap proof/install/models/chat 全 HTTP 200；backend 无应用 WARN/ERROR/panic/FATAL。frontend 只有启动器 `Failed to foreground app; open returned 1`，随后无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device/panic/fatal；`frontend-terminal-review.md` 将其独立分类，idle 8 秒零增长。收台后进程/监听归零。
- 写账前 `gap-too-fast`/`discovery-collapse` 按机制打开，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-153-conversations-add-worktree-ledger-reaudit.md`；anchors=`10/10`，ack 后 `alarms.py check` clean(1455)。五级 `G1/F2/A1/C4/G2` 写入账本 `1455→1460 judgments`，`COVERAGE EP-153=✓✓✓✓✓`。写账后警报按新 evidenceThrough 再开，第二份复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-153-post-judgment-alarm-reaudit.md`，逐条 ack 后最终 clean(1460)；未改阈值/算法/法典/锚点/规则。
- 定向 Go conversation/gitinfo/httpapi handler tests、Flutter workdir menu tests（23 项）、`gen_coverage.py --check`（848/285/0）、`git diff --check`、`make -C docs verify` 通过；fixture 与数据按用户授权用 `/usr/bin/trash` 清理，session 证据保留。本格只完成真实证据、账本 gate 和必要警报复审；批次统一长门禁、完整 testend、提交按“50 格后统一”后置。批次二十八由 **25→30/50**，P12 旅程 400+ 按用户裁定推迟二期；下一原子前线为 EP-154 `POST /api/v1/conversations/{id}/messages`。

## 2026-08-09 — EP-152 `POST /api/v1/conversations/{id}/workdir:create-branch` 五级收口，批次二十八 25/50

- 产品目的：新分支必须可发现、从当前 HEAD 创建并切换；脏改动明确随分支带走而不被静默丢失；冲突、非法 ref、非 Git 目录和未知对话均给出可行动错误。
- 真实 session `/private/tmp/anselm-rig-ep152-20260809/sessions/20260809-185543`：真实 Flutter App、真实受管 Anselm gateway、Computer Use、录屏 `2784x1808 / 60fps / 298.141667s`。真实 UI 打开 `New branch…`，显示从当前 commit 创建且 uncommitted changes 会随之带走的解释；输入 `feat/new` 后创建成功，随后外部制造 `pkg/DRAFT.txt`，菜单显示 `Branch feat/new`、`Uncommitted changes` 和 `Commit or stash your changes first, then switch branches`。
- 正向 REST/SQLite/fixture：clean create 返回 `feat/new,dirty=false`；dirty create `feat/from-dirty` 返回 200、`dirty=true`，前后 HEAD=`5f36ad9a80fa94dab0bbcb26ba65f33aa06a553c`，README SHA 不变，DRAFT 保留。`EP-152-exists.json`=`409 CONVERSATION_BRANCH_EXISTS`，`EP-152-invalid.json`=`422 CONVERSATION_INVALID_BRANCH`，普通目录=`422 CONVERSATION_WORK_DIR_NOT_GIT_REPO`，未知 conversation=`404 CONVERSATION_NOT_FOUND`。真实 Composer 通过受管 gateway 精确得到 `EP152-ACK`。
- 五通道正式证据为同 session `evidence/EP-152-final-green.md`；SSE=`evidence/EP-152-sse-summary.txt`：messages durable max seq=8、notifications durable max seq=4、entities 已连接无事件；llmtap proof/install/models/chat 全 `200`；backend 无应用 WARN/ERROR/panic/FATAL；frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device/panic/fatal 红线，80 条固定 AXTree stale-node 由 `frontend-ax-review.md` 独立分类，idle 8 秒零增长。rig-down 后进程/监听归零。
- 写账前 `gap-too-fast`/`discovery-collapse` 按机制打开，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-152-conversations-create-branch-ledger-reaudit.md`；anchors=`10/10`，ack 后 `alarms.py check` clean(1450)。五级 `G1/F2/A1/C4/G2` 写入账本 `1450→1455 judgments`，`COVERAGE EP-152=✓✓✓✓✓`。写账后警报按新 evidenceThrough 再开，第二份复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-152-post-judgment-alarm-reaudit.md`，逐条 ack 后最终 clean(1455)；未改阈值/算法/法典/锚点/规则。
- 定向 Go conversation/gitinfo/handler tests、Flutter workdir menu tests（23 项）、`gen_coverage --check`（848/284/0）、`git diff --check`、`make -C docs verify` 通过；隔离 fixture/数据按用户授权通过 `/usr/bin/trash` 清理，session 证据保留。本格只完成真实证据、账本 gate 和必要警报复审；批次统一长门禁、完整 testend、提交按“50 格后统一”后置。批次二十八由 **20→25/50**，P12 旅程 400+ 继续按用户裁定推迟二期；下一原子前线为 EP-153 `POST /api/v1/conversations/{id}/workdir:add-worktree`。

## 2026-08-09 — EP-151 `POST /api/v1/conversations/{id}/workdir:switch-branch` 五级收口，批次二十八 20/50

- 产品目的：切已有分支必须让用户看见真实 Git 结果、禁止脏树静默搬活、区分未知分支和非法 ref，并返回新投影避免旧分支残帧；分支切换不改变 conversation residency。
- 真实 session `/private/tmp/anselm-rig-ep151-20260809/sessions/20260809-184030`：真实 Flutter App、真实受管 Anselm gateway、Computer Use、录屏 `2784x1808 / 60fps / 532.688333s`。构造 main/feature Git repo，真实 App 点击 feature 后外部 Git/REST projection 同步为 feature；同线程 Composer 通过真实网关精确返回 `EP151-ACK`。
- Computer Use 观察 clean Git 菜单的 `Branch main`/`feature`，切换后 transcript 保持可读；外部制造 untracked 文件后菜单改为 `Branch feature`、`Uncommitted changes`、`Commit or stash your changes first, then switch branches`，不提供必定失败的分支行。
- REST 负向：脏态切 main=`422 CONVERSATION_WORK_DIR_DIRTY`，未知本地分支=`404 CONVERSATION_BRANCH_NOT_FOUND`，`--upload-pack=evil`=`422 CONVERSATION_INVALID_BRANCH`；HEAD 和未提交文件均未动。移走未提交文件后 REST 切回 main=`200`，返回重探投影，SQLite transcript 完整保留。
- 五通道正式证据为同 session `evidence/EP-151-final-green.md`；SSE 汇总 `EP-151-sse-summary.txt`：messages durable max seq=8、notifications max seq=2，三路连接成立；llmtap proof/install/models/chat 全 HTTP 200；backend 无 WARN/ERROR/panic/FATAL，frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device/panic/fatal 红线。121 条固定 AXTree stale-node 日志已在 `evidence/frontend-ax-review.md` 独立分类，8 秒静置零增长。
- 账本写入前 `gap-too-fast`/`discovery-collapse` 按机制打开，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-151-conversations-switch-branch-ledger-reaudit.md`；anchors=10/10，逐条 ack 后 `alarms.py check` clean(1445)。五级 `G1/F2/A1/C4/G2` 写入账本 `1445→1450 judgments`，`COVERAGE EP-151=✓✓✓✓✓`。本格只完成真实证据、必要预检查和账本写入；批次统一警报最终复核、长门禁、完整 testend、提交按“50 格后统一”后置。
- 定向 Go conversation/gitinfo/handler tests、Flutter workdir menu tests（23 项）、`gen_coverage --check`（848 rows / 283 carried / 0 tombstones）、`git diff --check`、`make -C docs verify` 通过；下一原子前线为 EP-152，批次二十八由 **15→20/50**。P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-09 — EP-150 `GET /api/v1/conversations/{id}/workdir` 五级收口，批次二十八 15/50

- 产品目的：驻地投影必须诚实呈现 path/exists/isGitRepo/dirty/branch/branches/worktrees；真实 Git 状态变化、目录被外部移动、路径变成普通文件和用户主动 Leave 都不能伪装或丢失；缺失态必须给出可理解且可行动的 UI。
- 真实 session `/private/tmp/anselm-rig-ep150-20260809/sessions/20260809-182721`：真实 Flutter App、真实受管 Anselm gateway、Computer Use、录屏 `2784x1808 / 60fps / 523.606667s`。构造真实 Git repo、main/feature 分支、独立 worktree、dirty 文件和移动后的 missing/file 路径；真实 gateway 回合精确返回 `EP150-ACK`。
- REST/SQLite/fixture：未挂载为空 projection；clean subdir 为 `exists=true,isGitRepo=true,branch=main,dirty=false`，branches/worktrees 完整；untracked 文件后 dirty=true，checkout 后 branch=feature；移动目录、挂载普通文件均为 `exists=false,isGitRepo=false,dirty=false`；未知 conversation=404；UI Leave 后最终 projection 为空，workdir marker 历史保留，fixture/worktree 未被破坏。
- Computer Use 逐帧打开缺失目录菜单，确认 `This directory no longer exists`，Finder/Terminal 动作禁用，Switch/Leave 可用；随后真实点击 Leave，回到 laptop/no-working-directory。截图：`evidence/EP-150-missing-menu.png`、`evidence/EP-150-final-unmounted.png`。
- 五通道正式证据为同 session `evidence/EP-150-final-green.md`；SSE 汇总 `EP-150-sse-summary.txt`：notifications durable max seq=7、messages max seq=8，三路连接成立；llmtap proof/install/models/chat 全 HTTP 200；backend 无 WARN/ERROR/panic/FATAL，frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device/panic/fatal 红线。38 条固定 AXTree stale-node 日志已在 `evidence/frontend-ax-review.md` 独立分类，未知格式仍 fail-closed。
- 账本写入前 `gap-too-fast`/`discovery-collapse` 按机制打开，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-150-conversations-workdir-ledger-reaudit.md`；anchors=10/10，逐条 ack 后 `alarms.py check` clean(1440)。五级 `G1/F2/A1/C4/G2` 写入账本 `1440→1445 judgments`，`COVERAGE EP-150=✓✓✓✓✓`。本格只完成真实证据、必要预检查和账本写入；批次统一警报最终复核、长门禁、完整 testend、提交按“50 格后统一”后置。
- 局部 `gen_coverage --check`（848 rows / 282 carried / 0 tombstones）、`git diff --check`、`make -C docs verify` 通过；下一原子前线为 EP-151，批次二十八由 **10→15/50**。P12 旅程 400+ 继续按用户裁定推迟二期。

## 2026-08-09 — EP-149 `POST /api/v1/conversations:delete-workdir` 五级收口，批次二十八 10/50

- 产品目的：批量删除必须让用户理解“删对话、不删目录、不删消息、置顶保留”，跨 active/archive 视图统一生效；确认后当前线程回到可用空 Chat，重复请求返回 `deleted:0`，负向 workDir 输入大声失败。
- 真实 session `/private/tmp/anselm-rig-ep149-20260809/sessions/20260809-180957`：真实 Flutter App + 真实受管 Anselm gateway + Computer Use；录屏 `2784x1808 / 60fps / 633.358333s`。构造 Alpha 活跃/归档普通线程、活跃/归档置顶 survivor、Beta 驻地和未挂载 Recents；两个普通线程真实 gateway 回合精确完成 ACK。
- UI 逐帧：默认 active-only 打开 Alpha More actions，确认框盘点 2 条并说明不删除磁盘文件、置顶不受影响；先 Cancel 无副作用，再从打开的普通线程确认 Delete all。Alpha 消失、当前线程回到空 Chat，Pinned/Beta/Recents 保留；Show archived 后 Pinned=`2`，归档置顶灰点可见，删除普通线程不复现，置顶 transcript 仍显示 `EP149-PINNED-ACK`。
- REST/SQLite：重复 POST `{"deleted":0,"workDir":"/tmp/ep149-alpha"}`；两个目标 GET/messages GET=`404`；`archived=all` 仅余两个置顶、Beta、Recents，group 仅余 Beta；空 workDir=`400 INVALID_REQUEST`，相对路径=`422 CONVERSATION_INVALID_WORK_DIR`。目标 conversation 只有 `deleted_at`，2 message/3 block 原样保留，relations/touchpoints=0，Alpha/Beta sentinel 文件原样存在。
- 五通道证据为同 session `evidence/EP-149-final-green.md`，AXTree 独立复核为 `evidence/frontend-ax-review.md`；三路 SSE durable notifications=`1..13`（两条 deleted）、messages=`1..16`（两次 completed turn）；llmtap challenge/install/models/chat 全 `200`；backend 无应用 WARN/ERROR/panic/FATAL，frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device/panic/fatal 红线，135 条固定 AXTree 仪器噪声 8 秒静置不增长；rig-check 五通道通过，收台无残留进程/监听。
- 写账前统计检查按机制打开 `gap-too-fast`/`discovery-collapse`；独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-149-conversations-delete-workdir-ledger-reaudit.md` 后逐条 ack，未改阈值/算法/法典/锚点/规则，最终 clean(1435)。五级 `G1/F2/A1/C4/G2` 写入账本 `1435→1440 judgments`，`COVERAGE EP-149=✓✓✓✓✓`，anchors `10/10`。
- 本格只完成真实证据、账本 gate 与必要警报复审；批次统一长门禁、完整 testend、`gen_coverage --check`、工作树提交按用户“50 格后统一”裁定后置。批次二十八由 **5→10/50**，P12 旅程 400+ 继续按用户裁定推迟二期；下一原子前线为 EP-150。

## 2026-08-09 — EP-148 `POST /api/v1/conversations:archive-workdir` 五级收口，批次二十八 5/50

- 产品目的：批量归档不是只返回一个整数；用户必须能发现驻地组动作，理解“可恢复、置顶保留”，确认后看到整组离开 active rail，Show archived 能找回完整组，重复请求返回 `archived:0` 且不二次变更。
- 上一场 EP-148 候选真实 session 留下产品红：模型自造不存在的 `search_memory`，UI 显示裸 `tool not found` 失败卡。红证据保留、不计绿；stop-and-fix 修改 `chat/prompt.go`、`loop/tools.go`，补 prompt/loop regression，并同步 Chat、Memory、Loop 文档。未知工具现在明确“不执行 + 当前目录不可用 + 恢复方向”。
- 修复后二次真实 session 为 `/private/tmp/anselm-rig-ep148-fix-20260809/sessions/20260809-175213`。Computer Use 从真实 Alpha workdir group 打开 Archive all conversations，确认框明确显示三条、可恢复、置顶保留；确认后 active-only rail 保留 Pinned/Beta/Recents。Show archived 后 Pinned=`2`、Alpha=`3`，三条 archived 行灰点可读；Beta 真实受管网关回合精确返回 `EP148-ACK`。
- REST/SQLite/SSE：正向后 Alpha `activeCount=0, archivedCount=3`，重复 POST 返回 `{"archived":0,"workDir":"/tmp/ep148-alpha"}`；SQLite 普通 Alpha 三行 `archived=1,pinned=0,deleted_at=NULL`，置顶行不受批量动作影响；notifications durable seq `1..15` 含两条 `conversation.archived`，messages durable seq `1..8` 收束到 completed assistant。LLM challenge/install/models/chat 全部 HTTP 200，wire 无 `search_memory` tool call。
- 五通道证据为同 session `evidence/EP-148-final-green.md`，AXTree 独立复核为 `evidence/frontend-ax-review.md`；录屏 `742.650000s / 2784x1808 / 60fps` 已封口，backend 无应用 panic/FATAL/WARN/ERROR，frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled/lost-device 红线，五个进程与监听收台归零。
- 五级裁决 `G1/F2/A1/C4/G2`，账本 `1430→1435 judgments`，`COVERAGE EP-148=✓✓✓✓✓`，anchors `10/10`。本格只执行真实证据、anchors 和 judge；统计警报复核、全量长门禁、完整 testend 和提交按用户“50 格后统一”裁定后置。`gen_coverage --check`=`848/280/0`，`make -C docs verify` 与定向 Go tests 通过。
- 批次二十八由 **0→5/50**；未满 50 格不跑统一门禁、不提交。P12 旅程 400+ 继续按用户裁定推迟二期；下一原子前线为 EP-149。

## 2026-08-09 — EP-147 `GET /api/v1/conversations/workdir-groups` 五级收口，批次二十七 50/50

- 产品目的：mounted conversation 在 Pinned、workdir group、Recents 中恰好出现一次；组头计数来自整个 workspace 服务端投影；最新活跃组自动展开，用户明确折叠/展开选择优先；归档、路径碰撞和空驻地均可读。
- 首轮真实绿候选在受管 gateway 回合后抓到产品红：beta 已排到第一组，但稳定 `pageKey` 保留旧折叠态，最新回复被藏在组内。红证据保留于 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-163937/evidence/EP-147-fold-state-red.md`；stop-and-fix 将 `AnSidebarList` 的自动默认态与用户选择分离，并补侧栏重排/手动选择及聊天最近度回归。
- 最终真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-164708`：真实 App Composer 完成 alpha→beta 两次受管 gateway 回合；beta 变第一组后 `EP147 Beta active` 立即可见，alpha 退第二组；Show archived 后 beta/alpha 组头均为 `2`，归档行灰点正确，随后恢复 active-only。录屏 `2784x1808 / 60fps / 317.476667s`，已 rig-down 封口。
- REST 矩阵 `sessions/20260809-164708/evidence/EP-147-rest-matrix-final.jsonl` 覆盖零参数有界分组、忽略 cursor/limit、active/all/archived、alpha workDir、显式空 workDir；分组最终为 beta `1+1`、alpha `1+1`、right/anselm `1+0`、left/anselm `1+0`，置顶 alpha 不污染 group count。
- 五通道正式证据为 `sessions/20260809-164708/evidence/EP-147-final-green.md`：manifest/backend/SSE/frontend/LLM journals、真实截图和录屏齐全；llmtap challenge/两次 completion 全 200，SSE durable seq 单调至 16，backend/frontend 无应用级红线。夹具已按用户授权 Trash，回执为 `EP-147-fixture-cleanup.md`；红绿 session、journals、账本和证据保留。
- 五级裁决 `G1/F2/A1/C4/G2`，账本 `1425→1430 judgments`，`COVERAGE EP-147=✓✓✓✓✓`，anchors `10/10`；gap/discovery 警报经独立复审 ack，阈值/算法/法典/锚点未变，最终 `alarms.py check`=`clean (1430 judgments)`。
- 统一长门禁已实际通过：`gen_coverage.py --check`=`848/279/0`，anchors calibration passed，`make -C docs verify`、`git diff --check`、根目录 `make verify`（backend/frontend/docs/demo）全绿；frontend `make verify` 为 `5287 tests` 全绿，`make -C backend testend` 全包 `382.092s` 通过。
- 门禁期间全量 Flutter 测试捕获真实 pending timer 回归：transcript 深链分叉在无 rail 监听时会触碰永久存活的 list provider。修复为 `conversationListProvider` `autoDispose`，无监听时释放 SSE/合帧计时器，重新挂载从服务端真相重建；Chat 文档、fork/rail 回归和 48 个定向测试同步通过。
- 批次二十七由 **45→50/50**；统一门禁、完整 testend 和警报复核已收口，并已提交 `54dae950`，不提前启动下一原子。P12 旅程 400+ 按用户裁定继续推迟二期。

## 2026-08-09 — EP-146 `DELETE /api/v1/conversations/{id}` 五级收口，批次二十七 45/50

- 产品目的：删除不是只返回 `204`，而是让对话从 rail、详情和消息入口消失，保留 D1 消息审计，清掉关系与 conversation touchpoints，并在生成中删除时安全取消且不毒化后续会话。
- 正式真实 App session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-160637`：Computer Use 从 More actions 打开确认框并删除 `EP146 DELETE target`；目标从 rail 消失、空 composer 可用。删除前曾通过真实受管 gateway 发送带 function mention 和附件的消息并得到精确 `EP146-ACK`。
- REST/SQLite 证据：删除头保留 `deleted_at`，GET/list/messages 均为 `404/不出现`，user/assistant rows 与 blocks 保留；relations 与 conversation_touchpoints 归零；function/attachment 不被 conversation 删除误级联。真实 fork 的源→fork relation 在删除 fork 后双向查询均为空，fork 消息审计仍保留。
- 取消竞态：`EP146 in-flight delete` 在 `isGenerating=true` 时由 App 删除，assistant 终态为 `cancelled`，partial durable text 保留；随后新建 `EP146 post-delete health` 并经真实 gateway 得到 `EP146-POST-OK`，证明队列和后端仍健康。唯一 `incremental block persistence failed: context canceled` 是删除取消与可选增量写入的预期竞态；detached finalizer 已成功补齐落盘，warning 被保留并逐行审查，不作静默过滤。
- 五通道正式证据齐全：`manifest/backend/SSE/frontend/LLM` journals 与 `2784x1808 / 60fps / 678.315s` 可读录屏；三路 SSE durable seq 连续并观测 `conversation.deleted`、取消回合 close 帧；llmtap challenge/install/models/两次 chat 均 `200`；backend/frontend 无 panic/FATAL/未处理 Flutter/Dart/RenderFlex/overflow 红线，启动 wrapper 已知 foreground 噪声单独分类。
- 正式绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-160637/evidence/EP-146-final-green.md`；独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-146-conversations-delete-ledger-reaudit.md`。五级裁决 `G1/F2/A1/C4/G2`，账本 `1420→1425 judgments`，`COVERAGE EP-146=✓✓✓✓✓`，anchors `10/10`；gap/discovery 警报按独立复审 ack，阈值/算法/法典/锚点未变，最终 `alarms.py check`=`clean (1425)`。
- 临时 fixture 按用户授权通过 `/usr/bin/trash` 移入 Trash，formal session、录屏、journals、红绿证据和账本保留。`gen_coverage.py --check`=`848/278/0`，定向验证、`make -C docs verify` 与 `git diff --check` 通过。批次二十七由 **40→45/50**，未到 50 格不跑统一长门禁、不提交；P12 旅程 400+ 继续推迟二期，下一原子前线为 EP-147。

## 2026-08-09 — EP-145 `PATCH /api/v1/conversations/{id}` 五级收口，批次二十七 40/50

- 首轮真实负向矩阵抓到产品红：空 PATCH 返回 `200`，但无变化仍刷新 `updatedAt` 并发出 `conversation.updated`；这违反既有 no-op 契约。红证据永久保留在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-154227/evidence/EP-145-empty-patch-red.md`，该 session 不计入绿证据。
- stop-and-fix：`conversation.Service.Update` 现在以语义 `changed` 短路 title、system prompt、attached documents、archive、pin、ModelOverride（含 options map）和 workDir；无变化只补派生 runtime flags，跳过 Save、workdir marker 与生命周期 emit。补齐 conversation/workdir app tests、testend HTTP no-op test，并同步 API/domain 文档。
- 正式真实 App session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-155101`：Computer Use 完成 `Auto→anselm-auto→Auto`，已删除驻地的 `This directory no longer exists` 降级态，真实 Anselm 驻地的 branch/dirty Git 投影与 Leave；最终回到未挂载、无 model override。mounted/final 视觉证据和 `261.255s` 窗口录屏均保留。
- REST/SQLite/SSE 交叉证据：空 PATCH 前后 `updatedAt=2026-08-09T07:53:54.427062Z` 不变，SSE 行数 `13→13` 且无新增生命周期帧；部分 model `422 CONVERSATION_INVALID_MODEL_OVERRIDE`、相对 workDir `422 CONVERSATION_INVALID_WORK_DIR`、未知字段 `400 INVALID_REQUEST`、跨 workspace/missing id `404 CONVERSATION_NOT_FOUND`；SQLite 最终 `model_override=NULL`、`work_dir=''`、无新增消息块。
- 五通道正式文件齐全：manifest/backend/SSE/frontend/LLM journals 与 finalized `screen.mov`；三路 SSE 均连接，真实设置变化 durable seq `1..5` 单调。backend 无应用级 WARN/ERROR/panic/FATAL；Flutter 无 Dart exception/assert/RenderFlex/overflow，启动 wrapper 的已知 foreground 噪声单独分类；该确定性 PATCH 路径不虚构 LLM completion。
- 正式绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-155101/evidence/EP-145-final-green.md`；独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-145-conversations-patch-ledger-reaudit.md`。五级裁决 `G1/F2/A1/C4/G2`，账本 `1415→1420 judgments`，`COVERAGE EP-145=✓✓✓✓✓`，anchors `10/10`；写账触发的两项统计警报已独立复审并 ack，最终 `alarms.py check`=`clean (1420 judgments)`，阈值/算法/法典/锚点未变。
- 定向 conversation/store/httpapi Go tests、testend ModelOverride/workdir tests、`gen_coverage.py --check`（848/277/0）、`make -C docs verify`、`git diff --check` 通过。EP-145 两个临时数据目录按用户授权通过 `/usr/bin/trash` 移入 Trash，formal session、录屏、journals、账本和证据保留；批次二十七由 **35→40/50**，未到 50 格不跑统一长门禁、不提交。P12 旅程 400+ 仍推迟二期；下一原子前线为 EP-146。

## 2026-08-09 — EP-144 `GET /api/v1/conversations/{id}` 五级收口，批次二十七 35/50

## 2026-08-09 — EP-144 `GET /api/v1/conversations/{id}` 五级收口，批次二十七 35/50

- 产品目的：详情接口必须让用户在冷启动后仍看到真实的生成中、等待输入和未读状态；详情、pending `ask_user` 卡、消息块、SSE 和最终回复必须共同指向同一条对话真相，而不是只返回一份静态 JSON。
- 首轮真实冷启动抓到产品红：`interactions` 已有 pending `ask_user`，但 streaming assistant 没有 durable `tool_call` BlockNode，应用冷开后只能显示 `thinking`，用户看不到问题。红证据保留在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-145808/evidence/EP-144-cold-open-red.md`。
- stop-and-fix：loop 增加可选 `BlockRecorder`，采样后的 blocks 在工具执行前先持久化；chat host 回写 store 分配的 block ID/seq，并在最终收尾过滤已记录块；messages store 增加事务化 `AppendBlocks`。补齐 ask_user 冷启动和 streaming append 回归测试，chat/messages/loop/backend 文档同步。
- 修复后的探索还捕获到受管模型错误发送 `search_flowruns.limit` 字符串，以及 Grep/Glob 省略 `path` 的参数红；该分支停止并保留在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-151404/evidence/EP-144-tool-args-red.md`，不计入绿证据。workflow validation 已增加精确整数字符串兼容和 Go 回归。
- 最终真实 App session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-152447`：冷开时 Computer Use 清楚看到橙色 `Awaiting your answer` 卡、prompt、输入框、`Don't answer`、`Send`；REST 为 `isGenerating=true`、`awaitingInput=true`、`hasUnread=false`，`interactions` 一个 pending ask_user，SQLite 一个同 ID durable tool_call。回答后 App 显示精确 `EP144F clean fixed cold-open verified.`，最终三个状态全 false，SQLite `completed/end_turn`，一条 tool_call 对应一条 tool_result，无重复块。
- 五通道证据具备非空 manifest/backend/SSE/frontend/LLM journals 和已封口可读录像；messages durable SSE seq `1..14` 单调，llmtap challenge/install/models/chat 均为 `200`，backend/frontend 无应用级 WARN/ERROR/panic/FATAL/Unhandled/FlutterError/RenderFlex/overflow。rig-down 后进程和端口归零，确定性详情 endpoint 未虚构 LLM completion。
- 正式绿证据为 `.../sessions/20260809-152447/evidence/EP-144-final-green.md`，fixture 删除回执为同 session 的 `evidence/EP-144-fixture-cleanup.md`；独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-144-conversations-ledger-reaudit.md`。五级裁决 `G1/F2/A1/C4/G2`，账本 `1410→1415 judgments`，`COVERAGE EP-144=✓✓✓✓✓`，anchors `10/10`；原阈值/算法/法典/锚点未变，`alarms.py check`=`clean (1415 judgments on record)`。
- REST 负向矩阵覆盖 unread/generating/awaiting/normal fixture、跨 workspace 和 missing ID 的 `CONVERSATION_NOT_FOUND`；临时对话 `DELETE=204` 且立即 `GET=404`。定向 Go tests、`gen_coverage.py --check`、`make -C docs verify`、`git diff --check` 通过。批次二十七由 **30→35/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-145。P12 旅程 400+ 仍按用户裁定推迟二期。

## 2026-08-09 — EP-143 `GET /api/v1/conversations` 五级收口，批次二十七 30/50

- 首轮真实 App 抓到产品红：32 条 pinned 对话以 page size 30 加载时，rail 先显示 `Pinned 30`，继续滚动后才变为 `Pinned 32`。这不符合产品真相，也会让用户误以为还有一条对话没有归类；红帧保留在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-141059/evidence/EP-143-pinned-count-red.png`。
- stop-and-fix：backend `List` 同轴 `Count` 并通过 `X-Anselm-Total-Count` 返回完整过滤人群；Flutter `ConvAxis.total` 不再使用 `rows.length`，并在 pin/archive/create/move/rename/delete 后刷新 total 而不重置已加载 rows/cursor。补齐 store、service、handler、provider、rail、fixture 和 workspace-isolation tests；API、conversation domain、frontend chat reference 与 endpoint extract 同步。
- REST 证据为固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-143124/evidence/EP-143-final-count-matrix.tsv`、`EP-143-final-page-walk.tsv`、`EP-143-final-cross-axis.tsv`：覆盖 default/created/name、archive、pin、workdir、search，18 页总数稳定，跨轴 cursor 全部 `400`。最终 baseline 为 32 pinned、4 active unpinned。
- Computer Use 最终帧 `EP-143-final-initial.jpg`、`EP-143-final-after-scroll.jpg` 始终显示 `Pinned 32`；真实 unpin/re-pin 帧显示 `31/3` 后回到 `32/2`。最终绿证据为 session 内 `evidence/EP-143-final-green.md`，包含首轮红、修复、REST、视觉、五通道和离线测试。
- 五通道 session 由真实 Flutter App、受管 gateway、Computer Use、recorder、backend journal、三路独立 SSE witness、frontend console 和 llmtap 共同归属；三流均连接，notifications durable seq `1..2` 单调，backend/frontend 无应用红线，rig-down 后进程/端口归零。确定性 list endpoint 不虚构 LLM completion。
- `judge.py` 按 `G1/F2/A1/C4/G2` 写入五格，账本 `1405→1410 judgments`，`COVERAGE EP-143=✓✓✓✓✓`，anchors `10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 经独立复审，回执为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-143-conversations-ledger-reaudit.md`，最终 `alarms.py check`=`clean (1410 judgments)`；阈值、算法、法典、锚点未变。
- 临时 fixture 在证据封存及用户授权后通过 `/usr/bin/trash` 移入 Trash，回执为 `evidence/EP-143-fixture-cleanup.md`；正式 session、录像、journals、formal evidence 和账本保留。定向 conversation Go/Flutter tests、`gen_coverage.py --check`、`make -C docs verify`、`git diff --check` 通过。批次二十七由 **25→30/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-144 `GET /api/v1/conversations/{id}`。P12 旅程 400+ 仍按用户裁定推迟二期。

## 2026-08-09 — EP-142 `POST /api/v1/conversations` 五级收口，批次二十七 25/50

- 真实 App 从 onboarding 创建工作区后，独立 REST fixture 创建的六条有效对话通过 notifications stream 出现在 rail；空线程、New chat、首条真实消息、自动标题和第二条精确回复全部完成。最终 conversation `cv_4322ff9a345e529c` 的 SQLite blocks、messages、SSE close 帧、App transcript 与 LLM wire 一致。
- REST 矩阵覆盖 trim、缺省/空/空白/null title、错误类型、unknown field、坏 JSON、缺 workspace；正向 `201`，负向 `400/401`，没有 ghost conversation。证据为 session 内 `evidence/EP-142-rest-boundary-matrix.jsonl`。
- 固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-133054`：真实 Flutter App、受管 gateway、Computer Use、窗口录像、backend/SSE/frontend/LLM 五通道；录屏 `388.956667s / 2784x1808 / 60fps`，notifications `1..8`、messages `1..16` 单调无重，backend/frontend 无应用红线，llmtap readiness/proof/install/models/chat 全为 `200`。
- 原生分辨率稳定帧 `EP-142-stable.png→EP-142-stable2.png` 的 `measure compare` 为 `changedFrac=0.00004, pass=true`。`sky.type_text` 的 CJK 注入限制作为台架问题单独记录，不计产品红；ASCII 精确回复由 DB/SSE/LLM/UI 交叉证明。
- 正式证据为 `.../sessions/20260809-133054/evidence/EP-142-conversation-create-final-green.md`，fixture Trash 回执同 session，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-142-conversation-create-ledger-reaudit.md`；临时数据已按授权移入 Trash，正式 session/journal/录像保留。
- `judge.py` 按 `G1/F2/A1/C4/G2` 写入五格，账本 `1400→1405 judgments`，`COVERAGE EP-142=✓✓✓✓✓`，anchors `10/10`。写账触发的 `gap-too-fast`/`discovery-collapse` 经独立复审 ack，最终 `alarms.py check`=`clean (1405 judgments)`；阈值、算法、法典、锚点均未变。
- 定向 chat ocean/composer `37` tests、backend conversation/httpapi 选择性回归、`git diff --check` 通过。批次二十七由 **20→25/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-143 `GET /api/v1/conversations`。P12 旅程 400+ 仍按用户裁定推迟二期。

## 2026-08-09 — EP-141 `POST /api/v1/documents/{id}:iterate` 五级收口，批次二十七 20/50

- 产品目的：用户能从真实 Library 文档行的 More actions 发现 `Edit with AI`，进入带当前文档 mention 的 Chat，对文档提出自然语言修改；AI 修改目标正文时，标题、description、tags、Promise heading 和子页不被误改，用户能在 Activity 与回到 Library 后确认结果。
- 独立 REST/SQLite/SSE 矩阵为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-131242/evidence/EP-141-rest-boundary-matrix.jsonl`：有效请求 `202` 并真实创建 conversation；空/空白请求 `400 EMPTY_ITERATE_REQUEST`，坏类型/JSON `400 INVALID_REQUEST`，缺文档 `404 DOCUMENT_NOT_FOUND`，缺 workspace `401 UNAUTH_NO_WORKSPACE`，负向不留幽灵行。
- stop-and-fix：后端 endpoint 已存在，但 Library 行菜单没有入口；补齐 live repository、fixture、`Edit with AI` 菜单、双语文案、Dio wire/widget tests 与 Library reference。真实 App 路径为 Library → More actions → Edit with AI → Chat；模型真实 `read_document`/`edit_document` 目标 id，回到 Library 后正文和保护字段一致，Activity 为 `1 touched / Edited`。
- 最终 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-131242`：真实 Flutter App、受管 gateway、Computer Use、窗口录像、backend/SSE/frontend/LLM 五通道；录像 `2784x1808 / 60fps / 409.856667s`，三流均连接，backend/frontend 无应用红线，启动期 runner foreground 提示已分类。稳定终帧 `395→405` 经 `measure compare` 为 `changedFrac=0`。
- 正式证据为 session 内 `evidence/EP-141-document-iterate-final-green.md`，fixture Trash 回执为 `evidence/EP-141-fixture-cleanup.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-141-document-iterate-ledger-reaudit.md`；临时 fixture 已按授权移入 Trash，正式 session/录像/journal 保留。
- `judge.py` 按 `G1/F2/A1/C4/G2` 写入五格，账本 `1395→1400 judgments`，anchors `10/10`，`COVERAGE EP-141=✓✓✓✓✓`。写账后 gap/discovery 两警报按原阈值打开，独立复审确认真实 session、负向矩阵、视觉证据、stop-and-fix 与定向测试齐全后 ack；`alarms.py check`=`clean (1400)`，`gen_coverage.py --check`=`848/273/0`。
- Flutter Library/repository `57` tests、backend document/aispawn/httpapi 选择性回归、testend contract、`git diff --check` 通过。P12 旅程 400+ 仍按用户裁定推迟二期；批次二十七由 **15→20/50**，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-142 `POST /api/v1/conversations`。

## 2026-08-09 — EP-140 `POST /api/v1/documents/{id}:duplicate` 五级收口，批次二十七 15/50

- 产品目的：用户从真实 Library 的行级 More actions 找到 Duplicate；复制后得到完整、可寻址的新子树，正文/description/tags/wikilink 出边保留，根名与父级语义明确，且新根自动打开让用户立即知道结果在哪里。
- 独立 REST/SQLite/SSE 矩阵固定在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-124218`，覆盖根级同级、显式 parent、空 body、`parentId:null`、嵌套源、后代 parent，以及 missing source/parent、空 parent、坏 JSON、unknown field、缺/错 workspace；正向 `201`，负向真实 `404/422/400/401`，结构/关系证据确认新 ID、重映射 path/parent、完整 metadata 和新 wikilink edges。接口文档明确逐节点写入、非跨子树原子。
- 最终真实 App session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-124808`：Computer Use 从 More actions → Duplicate 创建 `Duplicate Source 2`，自动打开新根，再打开 `Child One` 与 `Grandchild` 复核 body、description、tags、breadcrumb、Path、size、modified 和层级；树、正文和右岛一致，无路径滞后、裁剪、光标跳变或未解释布局红线。notifications 只有该 UI duplicate 的一个 durable `document.created` seq=1。
- 五通道收台：backend D1 `:8895`/PID `44395`，ssetap `44412`，llmtap `:8795`/PID `44369`，Flutter runner `44414`，recorder `44811`；录像 `458.446667s / 2784x1808 / 60fps`，rig-down 后进程/端口归零；backend 无应用 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/overflow/Unhandled 红线，三流均连接。确定性 duplicate 不虚构 LLM completion；真实 gateway challenge/install/models readiness 保留在 setup session `.../124107`。
- stop-and-fix：发现 fixture repository 仍是浅复制，会让测试对线上深拷贝契约撒谎；已改为 BFS 深拷贝并补 fixture test。backend test 增加显式 parent、metadata、子孙、fresh IDs 和 wikilink relation 回归；API/Library reference 同步。live duplicate 无产品源代码红。
- 正式证据为同 session `evidence/EP-140-document-duplicate-final-green.md`，清理回执为 `evidence/EP-140-fixture-cleanup.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-140-document-duplicate-ledger-reaudit.md`；临时 fixture 已按用户授权提交 Trash，正式 session/录像/journal/矩阵/证据保留。
- `judge.py` 按 `G1/F2/A1/C4/G2` 写入五格，账本 `1390→1395 judgments`，COVERAGE `EP-140=✓✓✓✓✓`；anchors `10/10`。写账后 gap-too-fast/discovery-collapse 按原阈值触发，独立复审后 ack，未改阈值/算法/法典/锚点；最终 `alarms.py check`=`clean (1395)`，`gen_coverage.py --check`=`848/272/0`。
- 定向 backend document/handler/store Go tests、Library + live-metrics Flutter `60` tests、fixture dart format、gofmt、`make -C docs verify`、`git diff --check` 通过。批次二十七由 **10→15/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-141 `POST /api/v1/documents/{id}:iterate`。P12 旅程 400+ 仍按用户裁定推迟二期，一期以 COVERAGE 矩阵为覆盖真相。

## 2026-08-09 — EP-139 `POST /api/v1/documents/{id}:move` 五级收口，批次二十七 10/50

- 产品目的：用户在真实 Library 中把文档移到根级/嵌套父级、按同级上缘/下缘重排，整棵后代子树、正文和 metadata 保持完整；树、面包屑、中心正文和右岛 Path/Modified 必须在一次真实拖拽后同时指向同一位置；非法 position、自落、成环和越界 mutation 前拒绝；同槽重复移动是真 no-op。
- 首轮真实红 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-115232` 抓到负数/过大 position 被接受并发布移动，红证据 `evidence/EP-139-document-move-red-negative-position.md` 保留；stop-and-fix 增加 `DOCUMENT_INVALID_POSITION`、`0..N` inclusive 插入边界和 no-op publish/timestamp 守卫，补 Go tests 与 backend/API/domain/events/extract 文档。
- 固定 binary 的真实 App 拖拽又抓到右岛 Path 落后于树/面包屑；修复 Inspector 以最新 tree row 供 Path/Size/Modified、正文 provider 保持冻结，补 Library widget regression。再一轮五通道交叉发现 initial live seed 伪造 Modified 时间；修复 seed 只供字数/大小，真实 edit 才供乐观时间，持久时间较新则优先，并补 `documentInspectorUpdatedAt` tests。
- 最终 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-122441` 由 conductor 托管新 backend、真实 Flutter App、Computer Use、窗口录像、frontend console、backend journal、三路独立 SSE witness 和 llmtap；录屏 `176.760000s / 2784x1808 / 60fps`，rig-check/rig-down 均通过且进程归零。真实拖拽 `Source Section → EP139 Beta → Destination Section` 两次完成，最终 App 同时显示正确缩进、面包屑、正文和 Path，`Modified=12:26` 与后端持久行一致。
- REST/SQLite/SSE 对证：正向覆盖 root/nested/reorder/append/显式 0/inclusive end/descendant preservation；负向覆盖 position 类型、self/cycle/missing parent/document、坏 JSON、workspace 隔离和 unknown action。最终 source 为 `parentId=doc_b16767da037811f4`、`position=0`、`/EP139 Beta/Destination Section/Source Section`；notifications 只有真实 `document.moved seq=1,2`，两个 no-op 无新增帧。
- 五通道：backend D1 `:8894`/PID `38988`，ssetap `39015`，llmtap `:8829`/PID `38951`，Flutter runner `39023`，recorder `39524`；backend 250 行无应用 WARN/ERROR/panic/FATAL，frontend 18 行无 Flutter/Dart/overflow/Unhandled，三流均连接；llmtap 记录 readiness，确定性 endpoint 不虚构 completion。稳定抽帧保存在 session `evidence/`。
- 正式证据为 `.../sessions/20260809-122441/evidence/EP-139-document-move-final-green.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-139-document-move-ledger-reaudit.md`。anchors `10/10`；`judge.py` 按 `G1/F2/A5/C4/G2` 写入五格，账本 `1385→1390 judgments`，COVERAGE `EP-139=✓✓✓✓✓`。写账后 gap-too-fast/discovery-collapse 按原阈值打开，独立复审后 ack，阈值/算法/法典/锚点未改；`alarms.py check`=`clean (1390)`，`gen_coverage.py --check`=`848/271/0`。
- 定向 Go document/handler/store、Library + live-metrics Flutter `59` tests、gofmt、`make -C docs verify`、`git diff --check` 通过。批次二十七由 **5→10/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-140 `POST /api/v1/documents/{id}:duplicate`。


## 2026-08-09 — EP-138 `DELETE /api/v1/documents/{id}`（批次二十七 5/50）

- 产品目的：用户从 Library 行级 More actions 找到 Delete，理解整棵子树会被移除；Cancel 必须是零副作用，Confirm 后根/子/孙/兄弟从 live tree、GET 和
  详情选区消失；另一个视图删除打开中的页或祖先时，编辑器不能继续伪装可写，必须显示 `This page was deleted` 并回到干净草稿。
- 真实 App 路径已完成：打开根页 → More actions → Delete；确认框准确显示 `Delete this page?` 与目标名称及 subtree 后果；先 Cancel 保持标题、正文、树、
  inspector 全部不变，再 Confirm，rail/center/right island 一起卸载并回到 `Untitled`。外部删除打开子页的第二次复现经过 tree resync 在 14 个 120ms 采样中从
  第 2 个样本看到 `This page was deleted`，没有静默跳走。
- API/SQLite/SSE 对证：级联树根、子、双孙、兄弟后续 GET 全 `404 DOCUMENT_NOT_FOUND`；重复/未知 DELETE 均 `404`；软删 tombstone 保留且 subtree 删除时刻一致，
  live relations=`0`；同名重建为新的 `201`；跨 workspace 删除为 `404`，目标在所属 workspace 仍 `200`。notifications durable seq `1..18` 单调，包含
  `document.deleted` 与 `relation.dependency_broken`，三路 SSE 均连接。
- session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-112205` 由真实 Flutter App、受管 gateway、Computer Use、窗口录像、backend journal、
  frontend console、三路独立 SSE witness 和 llmtap 托管；录屏 `1025.690000s / 2784x1808 / 60fps`，D1 backend `:8892`/PID `28732`，gateway
  challenge/install/models 全 HTTP `200`。backend 无应用红线，frontend 无 Dart/Flutter/RenderFlex/overflow/unhandled 等运行时红线；固定格式 AXTree
  stale-node 观察器消息经 `evidence/frontend-ax-review.md` 审阅，未知形状仍 fail-closed。
- 正式证据为同 session `evidence/EP-138-document-delete-final-green.md`，清理回执为 `evidence/EP-138-fixture-cleanup.md`，独立账本复审为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-138-document-delete-ledger-reaudit.md`。用户再次确认删除后复核：临时 workspace/文档 fixture 已清理，
  disposable data 目录 `/private/tmp/anselm-rig-ep138-doc-delete-data` 已不存在；正式 session、录屏、journals、证据和账本均保留。
- `judge.py` 按 `G1/F2/A5/C4/G2` 写入五格，正式账本 `1380→1385 judgments`；anchors `10/10`，两条统计警报按原阈值独立复审并 ack，最终
  `alarms.py check`=`clean (1385)`；`gen_coverage.py --check`=`848 rows / 270 carried / 0 tombstones`。EP-138 无产品源代码修复。
- 批次二十七由 **0→5/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-139 `POST /api/v1/documents/{id}:move`。

## 2026-08-09 — EP-137 `PATCH /api/v1/documents/{id}`（50/50）

- 首轮真实 Library 路径冻结两处产品红：空 patch 会改变 `updatedAt` 并发布伪 `document.updated`；修复后二次真实 App 仍发现右岛 Properties 在正文保存后停留旧 `61 B`，而中心/REST 已是新正文 `68 B`。
- stop-and-fix：backend no-op/等值 patch 在 Save、updatedAt、关系同步和发布前早返回，并补 Go no-op publish/store 守卫；frontend live metrics 带文档身份、编辑同帧喂入、旧 provider 播种不得覆盖同页编辑、切页清空，补 stale-seed/document-identity Flutter 守卫；backend/frontend 文档同步。
- 绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-104917` 从全新 onboarding 起步。API 矩阵覆盖 no-op、四种分部更新、冲突/成功改名级联、非法名/tags、unknown、坏 JSON、缺 workspace、超 1 MiB；真实 App 标题编辑+正文追加后 Properties 与 REST 同步 `45 B`，重开最终根页同步 `66 B`，删除当前页显示 `This page was deleted`。
- 五通道：录屏 `459.506667s / 2784x1808 / 60fps`；backend D1 `:8891`/PID `21316` 无应用红线；SSE 三流连接、notifications durable `1..13` 连续；LLM challenge/install/models 全 `200`；Flutter console 无应用红线。startup 的 `Failed to foreground app; open returned 1` 为 runner 提示，App 随后正常 resident。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-137-documents-patch-final-green.md`，红证据与独立复审分别在 formal evidence 目录；fixture `DELETE=204` 后 tree 为空。五级 `G1/F2/A5/C4/G2` 写入账本 `1375→1380`，anchors `10/10`，警报复审 ack 后 clean；`gen_coverage.py --check`=`848/269/0`。
- 定向 backend document/store/transport Go 测试、Library 相关 Flutter `57` tests、格式化与 `git diff --check` 通过；批次二十六达到 `50/50`。
- 统一长门禁已通过：根目录 `make verify` 的 backend/frontend/docs/demo 四组全绿；`make -C backend testend` 完整场景集全绿（`290.263s`）；正式 `RIG_HOME` 下 anchors `10/10`、`alarms.py check`=`clean (1380)`、`gen_coverage.py --check`=`848/269/0`、相关 Go 回归、testend 进程组清理与 `git diff --check` 均通过。现在只剩选择性工作树审计与本批 commit，未提前推进下一格。

## 2026-08-09 — EP-136 `GET /api/v1/documents/{id}`（45/50）

- 真实 App 打开根/子/空三类单读：中文多行 markdown、独立子正文、empty body、description/tags、字节大小、面包屑和深 Path 全部一致；删除当前打开页后显示 `This page was deleted` 并回到干净草稿态。
- API 负向覆盖 unknown、跨 workspace、缺 workspace；根级级联删除后根/子/空三条单读均为 `404 DOCUMENT_NOT_FOUND`，无残留读穿。SSE durable `16..20` 连续记录 3 created + 2 deleted。
- 固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-101828`；录屏 `163.011667s / 2784x1808 / 60fps`。backend D1 `:8888`/PID `15559`，LLM challenge/install/models 全 `200`，frontend/backend 无应用红线。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-136-documents-get-final-green.md`，cleanup 回执在固定 session evidence；五级 `G1/F2/A5/C4/G2` 写入账本 `1370→1375`，警报按原阈值触发、独立复审、ack 后 clean；`COVERAGE` `✓✓✓✓✓`，`gen_coverage.py --check`=`848/268/0`。
- 定向 Go 测试、相关 Library/eviction Flutter `56` tests、`git diff --check` 通过；未到 50 格，不跑统一长门禁、不提交。下一前线 EP-137。

## 2026-08-09 — EP-135 `GET /api/v1/documents/tree`（40/50）

- 真实 App 通过 `/tree` metadata 投影渲染父子 Library 树；构造空页、正常正文页、三个空格正文页和两层子树，空/已写图标、`hasContent`、size、description/tags、缩进、面包屑和深 Path 全部一致。
- API 返回 `200`/7 行；所有行无 `content` 而带显式 `hasContent`，断言 `hasContent == sizeBytes>0`；`?limit=1&cursor=bogus` 仍返回完整同字节结果；缺 workspace `401`、错误 POST `404`；SQLite id/parent/position/content bytes 对账一致。
- 固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-100933`；录屏 `296.061667s / 2784x1808 / 60fps`。backend D1 `:8887`/PID `13897`，SSE notifications durable `16..23` 连续覆盖 5 created + 3 deleted，LLM challenge/install/models 全 `200`，frontend/backend 无应用红线。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-135-documents-tree-final-green.md`，cleanup 回执在固定 session evidence；五级 `G1/F2/A5/C4/G2` 写入账本 `1365→1370`，警报按原阈值触发、独立复审、ack 后 clean；`COVERAGE` `✓✓✓✓✓`，`gen_coverage.py --check`=`848/267/0`。
- 定向 Go 测试、Library Flutter `56` tests、`make -C docs verify`、`git diff --check` 通过；一次 SQLite shell 引号错误已如实记录为台架命令问题；未到 50 格，不跑统一长门禁、不提交。下一前线 EP-136。

## 2026-08-09 — EP-134 `POST /api/v1/documents`（35/50）

- 真实 Flutter App 从 Library `New page` 创建根页，编辑并保存完整字段；再从行级 `New sub-page` 创建真实子页，App、REST、backend journal 和树路径一致。最终画面保存为 `EP-134-ui-full-metadata.png` / `EP-134-ui-final.png`。
- 完整 API 矩阵覆盖 root/nested create、完整字段、同名自动后缀、省略字段默认值、256/257 标题边界、空名/斜杠名、缺父、坏 JSON、超 1 MiB 正文和缺 workspace；负向均无幽灵行。精确删除 UI 临时子页 `doc_854ff4ce20aa279c` 得 `204`，复查子列表为空。
- 固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-095218`；录屏 `732.240000s / 2784x1808 / 60fps`。backend D1 `:8886`/PID `11871`，SSE notifications durable `16..27` 无 gap，LLM challenge/install/models 全 `200`，frontend/backend 无应用红线。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-134-documents-create-final-green.md`，cleanup 回执在固定 session evidence；五级 `G1/F2/A5/C4/G2` 写入账本 `1360→1365`，警报按原阈值触发、独立复审、ack 后 clean；`COVERAGE` `✓✓✓✓✓`，`gen_coverage.py --check`=`848/266/0`。
- 定向 Go 测试、`make -C docs verify`、`git diff --check` 通过；台架输入 modifier/select-all 误操作已单独记录，未计产品红；未到 50 格，不跑统一长门禁、不提交。下一前线 EP-135。

## 2026-08-09 — EP-133 `GET /api/v1/documents`（30/50）

- 首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-093715` 发现跨父节点复用 opaque cursor 会 `200` 但静默跳过当前父节点前几行；按 stop-and-fix 冻结为红，保留红轮录屏、HTTP body 和日志。
- 修复 `siblingCursor` 绑定 `parentId`，跨父 cursor 返回 `400 INVALID_REQUEST`；新增 store 回归测试，同步 API/domain reference。固定二进制 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-094240` 重跑真实 App、受管 gateway、Computer Use、窗口录屏、backend/SSE/frontend/LLM 五通道。
- 最终真实矩阵覆盖根级三页无重无漏、`parentId=` 根级等价、子节点两页、跨父双向拒绝、未知 parent 空页、坏 cursor/坏 limit、无 workspace；App 显示父子缩进、面包屑、Path 和空正文提示，无应用红线。录屏 `154.291667s / 2784x1808 / 60fps`，SSE notifications seq `16..21`，LLM challenge/install/models 全 200。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-133-documents-list-final-green.md`；临时数据按用户授权移入 Trash，回执在固定 session evidence。五级 `G1/F2/A5/C4/G2` 写入账本 `1355→1360`，告警按原阈值触发、复审、ack 后 clean；`COVERAGE` `✓✓✓✓✓`，`gen_coverage.py --check`=`848/265/0`。
- 定向 Go 测试、`gofmt`、`git diff --check`、`make -C docs verify` 均通过；未到 50 格，不跑统一长门禁、不提交。下一前线 EP-134。

## 2026-08-09 · EP-132 `POST /api/v1/mcp-registry:install` 五级收口，批次二十六 25/50

- 真实固定 App 从 marketplace 安装 `microsoft/markitdown`，经历真实 Python runtime provisioning 和 `Installing…` 状态后，名册
  从空态变为 `1 servers · 1 ready`，server 为 `markitdown`、`ready · 1 tools`；真实 UI screenshot 与 REST row 一致。
- 首轮真实 App 暴露产品红：Firecrawl 空提交只显示笼统 `required environment variables missing`，没有投影后端已经返回的
  `details.missing` 字段名。stop-and-fix 在 `mcp_forms.dart` 统一表单/市场卡错误投影为字段化文案，新增中英文 key 和回归测试；
  修复前红 frame 保留，不计绿。
- 固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-092607`，录屏 `162.711667s / 2784x1808 / 60fps`，
  `EP-132-markitdown-ready.png` 与 `EP-132-missing-env-after-fix.png` 已保存；正式证据为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-132-mcp-registry-install-final-green.md`。
- 真实 API 负向矩阵：duplicate `409 MCP_NAME_CONFLICT`、missing `422 MCP_ENV_MISSING` + `missing=[FIRECRAWL_API_KEY]`、unknown
  `404 MCP_REGISTRY_NOT_FOUND`、malformed `400 INVALID_REQUEST`、no workspace `401 UNAUTH_NO_WORKSPACE`；删除清理 `204` 后 REST `data=[]`，
  App 回到市场空名册。raw headers/bodies 随 session 封存。
- 五通道：backend D1 `:8883`/PID `6192`；SSE 三流连接、notifications durable `16..19`，entities status connecting→ready；LLM
  challenge/install/models 全 `200` 且真实 upstream 为 `https://api.anselm.website`；frontend 无 Flutter runtime 红线。backend 只有已解释的
  markitdown 上游 pydantic warning，未隐藏。
- formal `judge.py` 按 `G1/F2/A5/C4/G2` 将 `1350→1355 judgments` 写入五格，`COVERAGE EP-132=✓✓✓✓✓`；集中写账打开的两条统计警报经
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-132-ledger-alarm-reaudit.md` 独立复审并 ack，最终 `alarms.py check`=`clean (1355)`。
- `mise exec -- flutter test test/features/settings/s4_mcp_test.dart`=`18/18 passed`，`make -C frontend gen` 通过；临时数据目录按授权移入
  Trash。批次二十六完成 **25/50**，未跑统一长门禁、完整 testend 或提交。下一原子前线为 EP-133。

## 2026-08-09 · EP-131 `POST /api/v1/mcp-registry:plan` 五级收口，批次二十六 20/50

- 真实固定 App 从 marketplace 打开 context7、Firecrawl、Notion 三种安装计划：`stdio/node` + secret env、required 星标、以及
  `streamable-http` + `Connect & authorize` 均与后端 plan 投影一致；本格只做零副作用预检，未点击 OAuth、未安装 server。
- 首轮产品审查发现 plan 失败分支只有 raw red line，没有 Retry/Cancel，loading 分支也只能依赖 breadcrumb 离开；停止并修成标准 `AnState`
  error + detail + Retry/Cancel，loading skeleton 也有 Cancel。这个 stale-entry 失败由 widget test 真实诱发，未伪装成 gateway 红线。
- 固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-091054` 录屏 `137.875000s / 2784x1808 / 60fps`；四张
  UI frame、代表性 plan 200、unknown/empty 404、malformed 400、no-workspace 401、安装前后名册字节不变和五通道 evidence 均封存于
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-131-mcp-registry-plan-final-green.md`。backend/frontend 无应用红线，宿主
  `Failed to foreground app; open returned 1` 明示为台架噪声，真实 managed gateway challenge/install/models 均经 llmtap 200。
- formal `judge.py` 按 `G1/F2/A5/C4/G2` 将 `1345→1350 judgments` 写入五格，`COVERAGE EP-131=✓✓✓✓✓`；集中写账触发的
  `gap-too-fast`/`discovery-collapse` 经独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-131-ledger-alarm-reaudit.md`
  ack，`alarms.py check`=`clean (1350)`，阈值/算法/法典/锚点不变。
- 发现后新增定向测试，`mise exec -- flutter test test/features/settings/s4_mcp_test.dart`=`17/17 passed`，`make -C frontend gen`、
  `gen_coverage.py --check`（848 rows / 263 carried / 0 tombstones）通过；批次二十六仍未到 50 格，未跑统一长门禁、完整 testend 或提交。
  下一原子前线为 EP-132 `POST /api/v1/mcp-registry:install`。

## 2026-08-09 · EP-130 `GET /api/v1/mcp-registry` 五级收口，批次二十六 15/50

- 真实 App 在 Settings > MCP servers 展示完整 curated 市场：96 张卡片、名称/描述、适用 prerequisite chip、真实键盘搜索
  `database` 得到 `dbhub` 与 `mcp-server-neon`，清空后恢复完整列表，继续滚动可到最后两张卡片；市场浏览没有安装副作用。
- 首轮真实运行发现产品红：registry 真实请求耗时 `2983ms` 时，未完成请求的界面先显示 `No MCP servers yet`，把等待误报成空态。
  stop-and-fix 将 loading 改为明确六卡 skeleton、失败改为可 Retry 的错误态，只有 settled empty 才显示空态；英语/中文文案与 15-case
  Flutter 测试同步更新。红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-084332` 保留。
- 固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-084847` 录屏 `369.315000s / 2784x1808 / 60fps`；三张
  UI 截图、API 200/96 unique、query body 相等、缺 workspace 401、五通道 journals 和正式证据均封存于
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-130-mcp-registry-final-green.md`。backend/frontend 无应用红线，已明示宿主
  `Failed to foreground app; open returned 1` 噪声；真实 managed gateway challenge/install/models 均经 llmtap 200。
- formal `judge.py` 按 `G1/F2/A5/C4/G2` 将 `1340→1345 judgments` 写入五格，`COVERAGE EP-130=✓✓✓✓✓`；集中写账触发的
  `gap-too-fast`/`discovery-collapse` 经独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-130-ledger-alarm-reaudit.md`
  ack，`alarms.py check`=`clean (1345)`，阈值/算法/法典/锚点不变。
- `mise exec -- flutter test test/features/settings/s4_mcp_test.dart`=`15/15 passed`、`make -C frontend gen`、`gen_coverage.py --check`
  （848 rows / 262 carried / 0 tombstones）通过；批次二十六仍未到 50 格，未跑统一长门禁、完整 testend 或提交。下一原子前线为
  EP-131 `POST /api/v1/mcp-registry:plan`。

## 2026-08-09 · EP-129 `GET /api/v1/mcp-calls/{id}` 五级收口，批次二十六 10/50

- 真实 App 通过受管 gateway 调阅成功与失败 MCP 调用详情：状态、工具名、错误、stderr、输入/输出、耗时和 exact timing 均与
  REST/SQLite 对齐；未知 ID 与跨 workspace 读取均为 `404 MCP_CALL_NOT_FOUND`。最终 Chat 只调用一次 `get_mcp_call`，画面显示
 失败诊断和 stderr，结构化调用卡片保留精确时间。
- 首轮红证据发现正文表格将 exact `startedAt` 渲成 `相应时间`，与卡片真相冲突。stop-and-fix 增加 MCP-call 专用表格脱敏、工具描述
 约束、跨 chunk redactor 测试，并同步 MCP/loop/chat 文档；新 binary 重跑后正文不再出现占位时间。红 session 不删除。
- 绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-083017` 录屏 `188.761667s`；五通道、修复前红证据和
 负向矩阵均封存于 formal evidence。Flutter debug runner 的宿主 `Failed to foreground app; open returned 1` 明示为台架噪声，未发现
 任何 Flutter/Dart/RenderFlex/Unhandled 或 backend 应用红线。
- formal `judge.py` 按 `G1/F2/A5/C4/G2` 将 `1335→1340 judgments` 写入五格，anchors `10/10`，`COVERAGE EP-129=✓✓✓✓✓`；
  `gap-too-fast`/`discovery-collapse` 经独立复审后 ack，`alarms.py check`=`clean (1340)`。一次漏带 `RIG_HOME` 的默认账本误路由已
  独立审计并排除，不改变 formal 数字或阈值。fixture 脚本和数据按授权移入 Trash，session/证据保留。
- 定向 Go、gofmt、`make -C docs verify`、`gen_coverage.py --check`（848 rows / 261 carried / 0 tombstones）与 diff check 通过；批次二十六
  仍未到 50 格，未跑统一长门禁、完整 testend 或提交。下一原子前线为 EP-130。

## 2026-08-09 · EP-127 `POST /api/v1/mcp-servers/{name}/tools/{tool}:invoke` 五级收口，批次二十五 50/50

- 真实 App 安装 `ep127-invoke` 后显示 `ready · 2 tools`；REST 直调覆盖成功 200、fixture error/未知 tool 502、坏 JSON/错误 action
  400、未知 server 404。连续三次失败真实翻 `ready→degraded`，下一次成功恢复 `ready`；entities SSE 记录状态信号，失败单 Call
  详情与 stderr tab 均带真实 fixture stderr。SQLite 最终 `mcp_calls` 为 13 条 manual calls，`5 ok / 8 failed`，App Call history 同步
  显示 `✓ 5 · ✗ 8`。
- 首轮真实画面发现恢复态仍显示历史 `lastError` 红条；修复前端只在当前 `failed/degraded` 投影活动错误，保留 API 历史诊断并补 widget
  test。随后 13 条历史触发真实 Flutter `BOTTOM OVERFLOWED BY 20 PIXELS`；修复 Call history 固定 pane 的滚动视口，补 20 行 fixture
  test，真实滚动到尾部无 overflow。两处红均保留在过程观察中，不计绿。
- 修复版正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-065857` 录屏 `119.625000s / 2784x1808 / 60fps`；
  前一 invoke/status session `20260809-065509` 和最终 scroll top/bottom frame 均保留。backend/frontend journal 无应用红线，三路 SSE
  连接，llmtap 真实连 `https://api.anselm.website`，本确定性 REST 格不虚构 completion。临时 fixture/data 已按授权移入 Trash，清理
  回执为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-127-fixture-cleanup.md`。
- 正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-127-mcp-invoke-final.md`，独立复审为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-127-ledger-alarm-reaudit.md`；`judge.py` 按 `G1/F2/A5/C4/G2` 写入
  `1325→1330 judgments`，anchors `10/10`，`COVERAGE EP-127=✓✓✓✓✓`。集中写账触发的 `gap-too-fast`/`discovery-collapse` 已按原阈值
  独立复审并 ack，最终 `alarms.py check`=`clean (1330 judgments)`，未改阈值、算法、法典或锚点。
- 批次二十五已 **50/50**。统一长门禁已通过：根目录 `make verify` 的 backend、frontend、docs、demo 四组全绿，`make -C backend testend`
  全量通过（307.330s）；EP-127 定向 Flutter/Go 回归、`gen_coverage.py --check`、anchors `10/10`、`alarms.py check` 和
  `git diff --check` 均通过。当前只剩选择性工作树审计与本批次 commit，EP-128 未推进。

## 2026-08-09 · EP-126 `GET /api/v1/mcp-servers/{name}/calls` 五级收口，批次二十五 45/50

- 首轮真实 App 冻结为红：Call history 行是一条成功/一条失败，但聚合显示 `✓ 0 · ✗ 0`；REST/SQLite 已为 `1/1`。根因是
  frontend `listMcpCalls` 读取了错误的 N1 envelope 层，修复为读取 `data.aggregates`，补真实 envelope regression test，并同步
  backend API 与 frontend settings 文档。红截图保留在
  `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-062546/evidence/EP-126-calls-aggregate-red.png`，不计绿。
- 修复后正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-063641` 由真实 Flutter App、受管 gateway、Computer Use
  和窗口录制完成；重新进入 Call history 显示 `✓ 3 · ✗ 3`，六行 tool/manual/elapsed 与 REST 聚合、cursor continuation、tool/triggeredBy
  filter、`status=bogus -> 422 MCP_CALL_INVALID_STATUS`、single detail/unknown 404、SQLite 六行一致。录屏
  `109.243333s / 2784x1808 / 60fps` 已封片。
- 五通道：backend D1 `:8873`，frontend/backend 无应用红线；ssetap 的 messages/entities/notifications 三流均连接，读路径无 durable
  mutation frame；llmtap D1 `:8808` 与持久化 managed key wiring 一致，真实 upstream readiness 为 `https://api.anselm.website`，本格不虚构
  completion。曾用 `:8809` 的复用数据 session 被 rig-check 正确拒绝，未混入绿证据。
- 正式证据为 `sessions/20260809-063641/evidence/EP-126-calls-final-green.md`，红基线和清理回执同在 session evidence；`judge.py` 按
  `G1/F2/A5/C4/G2` 写入 `1320→1325 judgments`，anchors `10/10`，`COVERAGE EP-126=✓✓✓✓✓`。集中写账触发的 `gap-too-fast` 与
  `discovery-collapse` 已按原阈值独立复审并 ack，复审记录为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-126-mcp-calls-ledger-reaudit.md`，最终 `alarms.py check`=`clean (1325)`；
  未改阈值、算法、法典或锚点。
- fixture 与 isolated data 已在证据封口、进程归零且用户授权后移入 Trash，清理回执为
  `sessions/20260809-063641/evidence/EP-126-fixture-cleanup.md`。批次二十五由 **40→45/50**，未满 50 格不跑统一长门禁、不提交；下一
  原子前线为 EP-127 `POST /api/v1/mcp-servers/{name}/tools/{tool}:invoke`。

## 2026-08-09 · EP-125 `GET /api/v1/mcp-servers/{name}/stderr` 五级收口，批次二十五 40/50

- 产品目的覆盖真实 stdio MCP 产生 300 条长 stderr 噪声时的 bounded-tail 体验。真实 App 从 Add manually 到 `1 servers · 1 ready`、
  `ready · 1 tools`，进入详情 stderr tab 后显示 terminal viewport、`show 4269 earlier lines` 和最新的
  `EP125_TAIL_MARKER`/`EP125_TAIL_MESSAGE`；REST `data.size=262144` 精确命中 256 KiB ring 上限，未知名称返回
  `404 MCP_SERVER_NOT_FOUND`。本格没有产品源代码修复。
- 绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-061239` 由真实 Flutter App、受管 gateway、Computer Use
  和窗口录制完成，录屏 `375.708333s / 2784x1808 / 60fps`；ready roster、stderr detail 和 backend/SQLite/REST 证据均保留。
- 五通道封口：backend D1 `:8870` 记录真实 stderr drain 与 endpoint 200；SSE 三流连接，notifications durable `1..3` 覆盖 sandbox
  installing/ready 与 `mcp.installed`，entities `disconnected→connecting→ready`，messages 在只读生命周期无 durable frame；frontend
  无 Dart/Flutter/RenderFlex/Unhandled/overflow/lost-device 红线；managed gateway challenge/install/models 全 `200`。首次误读
  N1 envelope 的探针按 `.data` 重跑，误探针不计绿。
- 正式证据为 `sessions/20260809-061239/evidence/EP-125-mcp-stderr-final-green.md`，清理回执为同一 session 的
  `evidence/EP-125-fixture-cleanup.md`；`judge.py` 按 `G1/F1/A1/C4/G2` 写入 `1315→1320 judgments`，anchors `10/10`，
  `COVERAGE EP-125=✓✓✓✓✓`。集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按原阈值复审并 ack，复审记录为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-125-mcp-stderr-ledger-reaudit.md`，最终 `alarms.py check`=`clean`
  （1320 judgments），未改阈值、算法、法典或锚点。
- fixture 和 isolated data 在证据封口、进程归零且用户授权后移入 Trash；正式 session、录屏、journals、截图、REST/SQLite 回执和账本
  保留。批次二十五由 **35→40/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-126
  `GET /api/v1/mcp-servers/{name}/calls`。

## 2026-08-09 · EP-124 `POST /api/v1/mcp-servers/{name}:reconnect` 五级收口，批次二十五 35/50

- 产品目的覆盖首装后的健康重连、外部进程失败、失败后恢复，以及 roster overflow 和详情页两个 Reconnect 入口。真实 App
  从 `ready · 1 tools` 变为 `failed` 时保留同一张卡、具体 initialize EOF 和失败通知；清除故障后恢复 `ready · 1 tools`，详情
  页仍保留工具描述。本格没有产品源代码修复。
- 绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-060125` 由真实 Flutter App、受管 gateway、Computer Use
  和窗口录制完成，录屏 `283.540000s / 2784x1808 / 60fps`；ready、failed、recovered、detail 关键画面和负向过程均保留。
- 五通道封口：backend D1 `:8869`，首装 PUT 与四次 reconnect 均 `200`，失败响应为 `status=failed` + `lastError`，SQLite 最终一条
  active stdio 行；SSE notifications durable seq `3..7` 覆盖 installed、ready/failed/ready reconnect 结局，entities 状态同步；
  frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow/lost-device 红线，AX mapping 有独立 review；managed gateway challenge/install/models
  全 `200`。
- 正式证据为 `sessions/20260809-060125/evidence/EP-124-mcp-reconnect-final-green.md`，AX 复审为同一 session 的
  `evidence/frontend-ax-review.md`，清理回执为 `evidence/EP-124-fixture-cleanup.md`；`judge.py` 按 `G1/F1/A1/C4/G2` 写入
  `1310→1315 judgments`，`anchors 10/10`，`COVERAGE EP-124=✓✓✓✓✓`。集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按
  原阈值独立复审并 ack，复审记录为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-124-mcp-reconnect-ledger-reaudit.md`，
  最终 `alarms.py check`=`clean`（1315 judgments），未改阈值、算法、法典或锚点。
- 临时 fixture、failure marker 和 rig data 在证据封口、进程归零且用户授权后移入 Trash；正式 session、录屏、journals、截图、
  REST/SQLite 回执和账本保留。批次二十五由 **30→35/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-125
  `GET /api/v1/mcp-servers/{name}/stderr`。

## 2026-08-09 · EP-123 `DELETE /api/v1/mcp-servers/{name}` 五级收口，批次二十五 30/50

- 产品目的覆盖 roster overflow 和详情页两个删除入口，以及 Cancel 保留、Confirm 删除、重复 DELETE 和最终 marketplace 空态。
  真实 App 中两条 stdio fixture 都完成了取消后保留、确认后离开名册；删除不是只看 `204`，而是检查 UI、REST、SQLite、SSE
  和生命周期共同收口。本格没有产品源代码修复。
- 绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-054819` 由真实 Flutter App、受管 gateway、Computer Use
  和窗口录制完成，录屏 `304.541667s / 2784x1808`；确认、取消、roster、detail、最终空态关键画面和负向矩阵均保留。
- 五通道封口：backend D1 `:8868`，两次 DELETE `204`，列表 `200` 空，对象 GET/重复 DELETE `404 MCP_SERVER_NOT_FOUND`，
  SQLite 两条 `deleted_at` tombstone；SSE 三流连接并观察到两条 `mcp.removed` durable 帧，entities 与 UI 对齐；frontend 无
  Dart/Flutter/RenderFlex/Unhandled/overflow/lost-device 红线，AXTree bridge churn 有独立 review；managed gateway challenge/install/models
  全 `200`。
- 正式证据为 `sessions/20260809-054819/evidence/EP-123-mcp-delete-final-green.md`，清理回执为同一 session 的
  `evidence/EP-123-fixture-cleanup.md`；`judge.py` 按 `G1/F1/A1/C4/G2` 写入 `1305→1310 judgments`，`anchors 10/10`，
  `COVERAGE EP-123=✓✓✓✓✓`。集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按原阈值独立复审并 ack，复审记录为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-123-mcp-delete-ledger-reaudit.md`，最终 `alarms.py check`=`clean`
  （1310 judgments），未改阈值、算法、法典或锚点。
- 临时 fixture 脚本和 rig data 在证据封口、进程归零且用户授权后移入 Trash；正式 session、录屏、journals、截图、REST/SQLite 回执
  和账本保留。批次二十五由 **25→30/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-124
  `POST /api/v1/mcp-servers/{name}:reconnect`。

## 2026-08-09 · EP-122 `PUT /api/v1/mcp-servers/{name}` 五级收口，批次二十五 25/50

- 产品目的覆盖 Add manually 的 stdio 首装、同名原地替换、失败 remote 落盘和 reconnect 失败解释。真实 App 首装 `ep122-put`
  显示 ready/1 tool；同名 v2 提交后仍只有一张卡，详情工具更新为 `echo_v2`，SQLite 对证同一 server id；不可达
  `streamable-http` 落 `failed`，详情显示真实 connection-refused 和 `No tools`，点击 Reconnect 显示明确失败反馈。该格无源代码修复。
- 绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-053718` 由真实 Flutter App、受管 gateway、Computer Use
  和窗口录制完成，录屏 `367.730000s / 2784x1808`；ready、替换、failed、reconnect 关键画面、SQLite 回执和失败路径均保留。
- 五通道封口：backend D1 `:8867`，PUT/GET/reconnect 全真实 `200`，无应用 panic/WARN/ERROR/FATAL；SSE 三流 durable seq `1..6`
  单调并覆盖 installed/updated/failed/reconnected，entities status 对齐；frontend 无 Dart/FlutterError/RenderFlex/Unhandled/
  overflow/lost-device 红线；managed gateway challenge/install/models 全 `200`。AX tree 的 TextField value 错映射作为独立仪器观察留档。
- 正式证据为 `sessions/20260809-053718/evidence/EP-122-mcp-put-final-green.md`，清理回执为
  `sessions/20260809-053718/evidence/EP-122-fixture-cleanup.md`；`judge.py` 按 `G1/F1/A1/C4/G2` 写入 `1300→1305 judgments`，
  `anchors 10/10`，`COVERAGE EP-122=✓✓✓✓✓`。集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按原阈值独立复审并 ack，
  复审记录为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-122-mcp-put-ledger-reaudit.md`，最终 `alarms.py check`=`clean`
  （1305 judgments），未改阈值、算法、法典或锚点。
- 临时 fixture 脚本和 rig data 在证据封口、进程归零且用户授权后移入 Trash；正式 session、录屏、journals、截图、REST/SQLite 回执
  和账本保留。批次二十五由 **20→25/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-123
  `DELETE /api/v1/mcp-servers/{name}`。

## 2026-08-09 · EP-121 `GET /api/v1/mcp-servers/{name}` 五级收口，批次二十五 20/50

- 产品目的覆盖详情页实时 status、连接错误、缓存 tools、unknown/cross-workspace 隔离和外部删除回名册。首轮真实
  Computer Use 抓到名册已刷新但详情 body 为空的产品红；stop-and-fix 在详情顶层按 settled MCP roster 对账，对象消失时下一帧
  回名册并显示“已删除/列表已刷新”，loading/error 不误驱逐；新增回归后定向 MCP tests `11 passed`，最终 binary 重跑为绿。
- 绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-051842` 由真实 Flutter App、受管 gateway、Computer Use
  和窗口录制完成 ready 本地 stdio、failed 不可达 remote、详情、unknown/cross-workspace `404`、外部删除和最终空名册；录屏
  `646.830000s / 2784x1808`，红截图和最终绿截图均保留。主 workspace proof challenge/install/models 全 `200`；隔离 workspace
  立即删除导致的 cancel install 在证据中诚实标为生命周期收尾。
- 五通道封口：backend D1 `:8866`，GET ready/failed `200`、unknown/cross-workspace `404`、DELETE `204`、最终列表 `200`，无应用
  panic/WARN/ERROR；SSE 三流 durable `mcp.installed` seq `3/4/8`、`mcp.removed` seq `5/9/10` 单调，entities ready/failed status
  对齐；frontend 无 Dart/FlutterError/RenderFlex/Unhandled/overflow/lost-device 红线；llmtap 记录真实 gateway 线缆。
- 正式证据为 `sessions/20260809-051842/evidence/EP-121-mcp-get-final-green.md`，清理回执为
  `sessions/20260809-051842/evidence/EP-121-fixture-cleanup.md`；`judge.py` 按 `G1/F1/A1/C4/G2` 写入 `1295→1300 judgments`，
  `anchors 10/10`，`COVERAGE EP-121=✓✓✓✓✓`。集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按原阈值独立复审并 ack，
  复审记录为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-121-mcp-get-ledger-reaudit.md`，最终 `alarms.py check`=`clean`
  （1300 judgments），未改阈值、算法、法典或锚点。
- 临时 MCP fixture、脚本和数据目录在证据封口、进程归零且用户授权后移入 Trash；正式 session、录屏、journals、红绿截图、REST
  回执和账本保留。批次二十五由 **15→20/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-122
  `PUT /api/v1/mcp-servers/{name}`。

## 2026-08-09 · EP-120 `GET /api/v1/mcp-servers` 五级收口，批次二十五 15/50

- 首轮真实 App 发现两处产品红：MCP 列表 loading 被错误压成空态文案；外部删除后只监听 entities 的旧实现保留幽灵卡。stop-and-fix
  引入 `AnLastGood` 加载/错误/重试态，并同时监听 entities 与 notifications `mcp.*` 生命周期，统一重取 REST 真相；中英文文案
  和 loading/error/stale 生命周期 widget 回归同步完成。
- 绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-045431` 由真实 onboarding、受管免费档 provision、
  Computer Use 和窗口录制完成空列表、ready 本地 stdio、failed 不可达 remote、外部创建和外部删除；终帧显示 `2 servers · 1 ready ·
  1 failed` 与具体错误，删除后无需重启自动回到 marketplace 空态，REST 最终为 `{"data":[]}`。
- 五通道封口：录屏 `809.755s / 2784x1808`；backend D1 `:8865` 记录空列表/两轮 PUT/最终列表/两轮 DELETE/最终空列表，
  无 WARN/ERROR/panic/FATAL；SSE 三流覆盖 entities `connecting→ready/failed` 与 notifications durable seq
  `3,4,5,6,9,10,11,12`；frontend 无 Dart/FlutterError/RenderFlex/Unhandled/overflow/lost-device 红线；managed gateway
  challenge/install/models/quota 全 200。`rig-check` 通过后 `rig-down` 封片，owned process groups 归零。
- 正式证据为 `sessions/20260809-045431/evidence/EP-120-mcp-list-final-green.md`，清理回执为
  `sessions/20260809-045431/evidence/EP-120-fixture-cleanup.md`；`judge.py` 按 `G1/F1/A1/C4/G2` 写入 `1290→1295 judgments`，
  `anchors 10/10`，`COVERAGE EP-120=✓✓✓✓✓`。集中写账触发的两条警报已按原阈值复核并 ack，最终 `alarms.py check`=`clean`
  （1295 judgments），未改阈值、算法、法典或锚点。
- 临时 MCP 配置、脚本和数据目录在证据封口、进程归零且用户授权后移入 Trash；正式 session、录屏、journals、截图、REST 回执和
  账本保留。批次二十五由 **10→15/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-121
  `GET /api/v1/mcp-servers/{name}`。

## 2026-08-09 · EP-119 `DELETE /api/v1/skills/{name}/files/{path...}` 五级收口，批次二十五 10/50

- 首轮真实 App 用外部先删竞态发现产品红：旧文件预览和幽灵行在 `404 SKILL_FILE_NOT_FOUND` 后仍留屏，旧 UI 只显示泛化
  `Action failed`。stop-and-fix 让删除 API 失败也刷新文件树，stale 404 回到 skill 概览并显示“已删除、列表已刷新”，其他
  失败显示带路径的重试文案；新增错误常量、中英文文案和 widget 回归。
- 绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-043659` 由真实 onboarding、受管免费档 provision、
  Computer Use 和窗口录制完成附属/嵌套删除、取消确认、manifest 保护、重复删除和外部先删竞态；最终文件列表只有
  `SKILL.md` 164 bytes、`scripts/run.py` 39 bytes，终帧 `evidence/EP-119-final.png` 保留。
- 五通道封口：录屏 `364.575000s`；backend D1 `:8864` 记录创建 `201`、删除 `204`、保护 `400`、缺失 `404` 和最终列表 `200`，
  无应用 WARN/ERROR/panic/FATAL；SSE 三流连接且 notifications durable seq `1..8` 单调；frontend 无 Dart/FlutterError/
  RenderFlex/Unhandled/overflow/lost-device 应用红线；managed gateway challenge/install/models 全 `200`。`rig-check` 通过后
  `rig-down` 封片，owned process groups 归零。
- 正式证据为 `sessions/20260809-043659/evidence/EP-119-skill-file-delete-final-green.md`，独立警报复审为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-119-skill-file-delete-ledger-reaudit.md`；`judge.py` 按 `G1/F2/A1/C4/G2`
  写入 `1285→1290 judgments`，anchors `10/10`，`COVERAGE EP-119=✓✓✓✓✓`。集中写账触发的 `gap-too-fast` 与
  `discovery-collapse` 已按原阈值复审并 ack，最终 `alarms.py check`=`clean (1290 judgments on record)`，未改阈值、算法、法典
  或锚点。
- 临时数据目录 `/private/tmp/anselm-rig-ep119-green-data2` 在证据封口、进程归零且用户明确授权后以 `trash` 清理，清理记录为
  `sessions/20260809-043659/evidence/EP-119-fixture-cleanup.md`；正式 session、录屏、journals 和账本保留。批次二十五由
  **5→10/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-120 `GET /api/v1/mcp-servers`。

## 2026-08-09 · EP-118 `PUT /api/v1/skills/{name}/files/{path...}` 五级收口，批次二十五 5/50

- 首轮真实 App 发现 raw `SKILL.md` 保存失败后退出编辑态的产品红：后端 422 被 UI 误呈为成功，用户没有失败原因、草稿或重试路径。
- stop-and-fix 将共享 `AnCodeEditor` 接入 async durable-save：只有 204 成功才退出；失败保留 draft/editor/retry，并展示本地化错误。
  `SKILL_INVALID_FRONTMATTER` 的 name mismatch 显示具体目录名；补齐中英文和 async editor 回归。
- 绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-035833` 真实完成附属 Markdown 204、malformed/name mismatch
  两条 422、manifest 修正 204；最终 `SKILL.md` 194 bytes、`references/initial.md` 50 bytes、`scripts/run.py` 17 bytes，终帧保留。
- 五通道封口：录屏 `1040.068333s`；backend D1 `:8862` 无应用 WARN/ERROR/panic/FATAL；SSE 三流连接且 notifications durable `1..9`；
  frontend 无 Dart/FlutterError/RenderFlex/Unhandled/lost-device，固定 AXTree observer churn 由 session review 复核；managed gateway
  challenge/install/models 全 200。`rig-check` 通过后 `rig-down` 封片，owned process groups 归零。
- 正式证据为 `sessions/20260809-035833/evidence/EP-118-skill-file-write-final-green.md`，独立警报复审为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-118-skill-file-write-ledger-reaudit.md`；`judge.py` 按 `G1/F2/A1/C4/G2`
  写入 `1280→1285 judgments`，anchors `10/10`，`COVERAGE EP-118=✓✓✓✓✓`。集中写账触发的 `gap-too-fast` 与
  `discovery-collapse` 已按原阈值独立复审并 ack，最终 `alarms.py check`=`clean (1285 judgments on record)`。
- 批次二十五由 **0→5/50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-119。临时 fixture 在证据封口后按用户授权清理，
  session/journals 保留。

## 2026-08-09 · 批次二十四统一门禁与提交收口，前线推进 EP-118

- EP-117 `GET /api/v1/skills/{name}/files/{path...}` 已完成五级裁决，批次二十四达到 `50/50`。
- 统一长门禁全部通过：`make verify`、backend 完整 `go test ./...`、完整 testend、EP-117 Flutter 回归、
  `gen_coverage.py --check`、anchors、alarms 和工作树审计；正式账本为 `1280 judgments`，未改阈值、算法、法典或锚点。
- 批次提交为 `dbea703b`，只包含验收台架/working 文档和 EP-117 raw-byte 错误修复；另一团队的未暂存改动没有被提交。
- 下一原子前线为 EP-118 `PUT /api/v1/skills/{name}/files/{path...}`，在下一批满 `50` 格之前不重复跑统一长门禁。

## 2026-08-09 · EP-117 `GET /api/v1/skills/{name}/files/{path...}` 五级收口，批次二十四 50/50

- 产品目的：真实 Library 必须能读取 Markdown/JSON 等裸字节文件，未知类型要诚实降级；超过 1 MB 在线读取护栏时必须解释
  原因并保留系统打开/Finder 逃生口；MIME、长度、文件名、workspace 隔离、缺失和路径安全与后端真相一致。
- 首轮真实 App session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-023756` 冻结为红：`oversize.md` 为
  `1,048,577` 字节，后端是 `422 SKILL_FILE_TOO_LARGE`，UI 却显示泛化的 `Couldn't open this. The local engine didn't
  return it.`。stop-and-fix 修复统一 `ApiClient` 的 raw-byte JSON 错误解码，统一三个文件读取分支的具体错误态，补中英文、
  系统打开/Finder 动作、widget 回归和 `getBytes()` 网络回归；红证据保留，不计绿。
- 固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-025507` 使用修复后新 binary、真实受管 gateway、
  Computer Use、60fps 窗口录制、backend/frontend journal、三路独立 SSE witness 和 LLM tap。四个有效文件 HTTP `200` 且
  MIME/长度/Disposition 正确；超限 `422`，缺失/未知 `404`，缺 workspace `401`，编码 `..` 路径 `400`。App 显示 `5 files`，
  Markdown、JSON、未知二进制和超限卡均逐帧核对；超限卡显示明确 1 MB 文案及两个逃生按钮。录屏
  `108.925000s / 2784x1808 / 60fps`，SSE 三流连接且 notifications durable seq `16..19`，backend 无 WARN/ERROR/panic/FATAL，
  frontend 无 Flutter/Dart/RenderFlex/Unhandled/overflow 红线，managed gateway challenge/install/models 全 200。
- 正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-025507/evidence/EP-117-skill-file-read-final-green.md`，
  独立警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-117-skill-files-ledger-reaudit.md`。anchors `10/10`；
  正式账本 `1275→1280 judgments`，`G1/F2/A5/C4/G2`，`COVERAGE EP-117=✓✓✓✓✓`；集中写账警报复审后 ack，`alarms.py check`
  clean，未改阈值/算法/法典/锚点。
- 批次二十四由 **45→50/50**。统一长门禁已通过：完整 `make verify`、backend `go test ./...`、本批修复涉及的 Flutter 回归、
  完整 testend、`gen_coverage.py --check`、anchors、alarms 和工作树审计均通过；当前只收口提交，提交前不进入 EP-118。

## 2026-08-09 · EP-116 `GET /api/v1/skills/{name}/files` 五级收口，批次二十四 45/50

- 产品目的：真实 Library 的 Files inspector 必须显示稳定、可理解的公开文件树；`SKILL.md` 必须存在，附属文件按路径和
  元数据呈现，provenance sidecar 不得泄漏，未知 skill/缺 workspace 要明确失败，删除后当前选中详情要诚实收口。
- 固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-022720` 使用真实 Flutter App、Computer Use、
  窗口录制、backend/frontend journal、三路独立 SSE witness、managed gateway 和 LLM tap。App 逐帧显示 `Files 3`：
  `SKILL.md`、`references/live.md`、`references/seed.md`；REST 顺序和大小/更新时间完全一致，公开列表没有
  `.anselm-install.json`。未知 skill 为 `404 SKILL_NOT_FOUND`，缺 workspace 为 `401 UNAUTH_NO_WORKSPACE`；删除后
  `204→404`，App 收到 durable delete，rail/中心清空、显示 `This skill was deleted` 并回到 `Untitled`。
- 首次单根 fixture URL basename 偏差只发生在 setup，已写入 `EP-116-fixture-setup-note.md` 并排除出产品绿判断；修正后的
  fixture 才用于正式路径。source server、archive、临时数据和 setup scratch 已按用户授权清理，formal session/journals 保留。
- 五通道收台：录屏 `180.800000s / 2784x1808 / 60fps`；backend 无 panic/fatal/error，frontend 无 Dart/Flutter/RenderFlex/
  Unhandled/overflow 红线；SSE 三流连接且 durable lifecycle seq 单调；managed gateway bootstrap 全 200。
- 正式绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-022720/evidence/EP-116-skill-files-final-green.md`，
  独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-116-skill-files-ledger-reaudit.md`。`judge.py` 按
  `G1/F2/A5/C4/G2` 将正式账本 `1270→1275 judgments` 写入五格，anchors `10/10`，COVERAGE `EP-116=✓✓✓✓✓`，
  `gen_coverage.py --check`=`848 rows / 248 carried / 0 tombstones`；集中写账打开的 `gap-too-fast`/`discovery-collapse`
  经独立复审后 ack，最终 `alarms.py check`=`clean (1275 judgments on record)`，未改阈值、算法、法典或锚点。
- 批次二十四从 **40 / 50** 推进至 **45 / 50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-117
  `GET /api/v1/skills/{name}/files/{path...}`。

## 2026-08-09 · 台架参数护栏修复（未入账，不占 COVERAGE 格）

- 仪器自检时发现 `rig-up.sh --help` 原先没有参数分支，会实际启动 backend、两类 tap、Flutter App 和窗口录制；该
  30.390000s 会话 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-013647` 已立即收台，未执行产品操作、
  未写 judgment、未计入任何 COVERAGE 格，也不作为五通道产品证据。
- stop-and-fix：`rig-up.sh` 现在只接受空参数、`-h/--help`（纯输出）或直接拒绝未知参数；`testend/rig/README.md`
  增加操作护栏，避免只读探查命令再次启动真实台架。

## 2026-08-09 · EP-115 `POST /api/v1/skills:install` 五级收口，批次二十四 40/50

- 产品目的：真实 App 从 source 预览后只安装新的合法 skill；Library、正文、文件树、provenance、信任门和后端写入
  同一真相；已有 skill no-force 不覆盖，force 才替换。
- 固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-021859` 完成 App 新 skill 安装、已有项
  禁选、坏 manifest 禁选、no-force skip、force v2 替换、新 skill 重放 skip 和删除清理。App 逐帧显示新 skill、2 文件、
  provenance、`Pre-approval pending`，force 后 existing 的 v2 正文/文件/allowed-tools 也一致；删除后当前详情被 SSE 驱逐。
- REST 证据保存安装结果、hash baseline、文件裸读、no-force/force 响应、坏候选 skip、`204→404` cleanup；SSE durable seq
  `16..20` 单调且没有 skip/replay 幽灵事件。backend 的三条 WARN 是刻意负路径、逐项可解释；frontend 无 Dart/Flutter/
  RenderFlex/Unhandled/overflow 红线；managed gateway bootstrap 全 200；录屏 `246.440000s / 2784x1808 / 60fps`。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-115-skill-install-final-green.md`，独立复审
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-115-skill-install-ledger-reaudit.md`。正式账本 `1265→1270 judgments`，
  `G1/F2/A5/C4/G2`，anchors `10/10`，COVERAGE `EP-115=✓✓✓✓✓`，`gen_coverage.py --check`=`848/247/0`，最终
  `alarms.py check` clean，未改阈值/算法/法典/锚点。source fixture/runtime 已按授权删除。批次未满 50，不跑统一长门禁、不提交；
  下一原子前线为 EP-116。

## 2026-08-09 · EP-114 `POST /api/v1/skills:inspect-source` 五级收口，批次二十四 35/50

- 产品目的：安装前让用户看到所有候选、失败原因、已有 skill、allowed-tools 与真实选择状态；已有 skill 不得伪装成
  可执行的重复安装，inspect 不得写入工作区。
- 首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-015806` 冻结为红：已有
  `commit-helper` 带 `installed` 标记却被 UI 默认选中，而 no-force install 实际只会返回 `skipped`，用户选择与实际动作
  不一致。红证据保留，不计绿。
- stop-and-fix：前端默认选择收窄为 `installable && !alreadyExists`，已有项保留可见但开关禁用，补“已在库中”文案、
  宽容器 widget 回归和中英文生成翻译。
- 固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-020745` 重跑真实 source fixture：非法
  候选原因可读且不可选，已有项关闭且不可选，新项默认选中并先展示 `Read/Grep/run_function`；取消新项后安装按钮禁用，
  重新选择后恢复。Cancel 后列表仍只有两个 seeded skill，没有写入或生命周期帧。录屏 `182.816667s / 2784x1808`，正式
  证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-114-skill-inspect-final-green.md`。
- 五通道收台全绿：backend inspect=200 且无应用红线；SSE 三流均连接且无伪造业务帧；frontend 无 Dart/Flutter/
  RenderFlex/Unhandled/overflow 红线；LLM bootstrap challenge/install/models 全 200；source fixture/runtime 已按授权删除。
- 定向 Flutter library tests 全绿，analyze 无 issues。正式账本 `1260→1265 judgments`，`G1/F2/A5/C4/G2`，anchors `10/10`，COVERAGE
  `EP-114=✓✓✓✓✓`，`gen_coverage.py --check`=`848/246/0`。警报独立复审为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-114-skill-inspect-ledger-reaudit.md`，最终 `alarms.py check`
  clean；未改阈值、算法、法典或锚点。批次未满 50，不跑统一长门禁、不提交；下一原子前线为 EP-115。

## 2026-08-09 · EP-113 `POST /api/v1/skills/{name}:approve-tools` 五级收口，批次二十四 30/50

- 产品目的：第三方 Skill 的 allowed-tools 信任门必须由用户明确打开；首次授权只产生一次真实 `skill.updated`，重复点击、
  网络重试和公开 API 重放必须幂等，不伪造第二个生命周期信号，同时 App、REST、provenance、文件树和 SSE 保持同一真相。
- 首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-013940` 冻结为红：首次 App 授权产生
  `seq=17 skill.updated`，但重复公开 API 虽然 REST 状态无变化，仍产生 `seq=18 skill.updated`。红证据保留，不计绿。
- stop-and-fix：`ApproveTools` 对已批准状态直接返回当前实体，不重写 provenance、不刷新 `updatedAt`、不发通知；补
  `TestApproveTools_IsIdempotentAfterApproval` 和 Skill domain 文档，并保留安装/更新单生命周期事件回归。
- 固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-014829` 以真实 source fixture 完成
  Inspect、Install、App pending→active 审批、重复 API、未知/本地 Skill 负向矩阵。待授权与已授权帧/AX 树稳定；首次
  授权只有 `seq=17 skill.updated`，重复请求前后 `updatedAt`、`toolsApproved` 完全一致且无第二个 SSE 更新事件。
  录屏 `189.115000s / 2784x1808`，正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-113-skill-approve-final-green.md`。
- 五通道收台全绿：backend/frontend 无应用红线，三路 SSE 已连接且 durable seq 对证，LLM tap 真实记录 managed
  challenge/install/models，窗口录屏经 ffprobe 可读；未知与本地 Skill 均为 `422 SKILL_NOT_INSTALLED`。
- 定向 `go test`、`go test -race`、`git diff --check` 全绿。正式账本 `1255→1260 judgments`，`G1/F2/A5/C4/G2`，
  anchors `10/10`，COVERAGE `EP-113=✓✓✓✓✓`，`gen_coverage.py --check`=`848/245/0`。两条集中写账警报按
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-113-skill-approve-ledger-reaudit.md` 独立复审后 ack，
  最终 `alarms.py check`=`clean (1260)`，未改阈值、算法、法典或锚点。
- source fixture/runtime 已按用户授权删除；formal session、录像、journals、红绿证据和账本保留。批次二十四当前 **30/50**；
  未满批不跑统一长门禁、不提交。下一原子前线为 EP-114 `POST /api/v1/skills:inspect-source`。

## 2026-08-09 · EP-112 `POST /api/v1/skills/{name}:update` 五级收口，批次二十四 25/50

- 产品目的：上游 skill 更新后，中心正文、文件树、描述、provenance、allowed-tools 信任状态、通知和失败保护必须
  同代一致；本地改动非 force 要明确阻断，force 更新也不能静默丢掉未改变的信任配置。
- 首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-011139` 冻结为红：后端已是
  v2，但中心 native editor 仍显示 v1 正文和已删除文件内容；同一更新还重复发出 `skill.created` 与 `skill.updated`。
  红证据保留，不计绿。
- stop-and-fix：正文版本变化时只重置内部 native editor、保留页面滚动/大纲壳，并用 generation guard 阻断旧实例延迟保存；
  安装/更新落地改为一次操作只发一个正确的 lifecycle event；补 Go/Flutter 回归测试和 frontend library 文档。
- 固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-012412` 由真实 Flutter App、Computer Use、
  真实受管 gateway、窗口录制、backend/frontend journal、三路独立 SSE witness 和 LLM tap 完成 v1→v2、local drift 409、
  Force update 正负路径。最终录屏 `405.186667s / 2784x1808`；中心与右岛同代、3 文件收敛为 2 文件、`Read` pre-approval 保持，
  无 stale body、重复 mutation、loading 残留或 Flutter runtime 红线。
- 五通道证据：update/读取 HTTP 200；SSE 只有对应 `skill.updated`；frontend console 无应用红线；managed gateway bootstrap 全 200；
  正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-final-green.md`，首轮红证据和两张负向画面均保留。
- 定向 Go、race、Flutter library test、`make -C docs verify`、`git diff --check` 全绿。正式账本 `1250→1255 judgments`，
  `G1/F2/A5/C4/G2`，anchors `10/10`，两条统计警报按
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-ledger-reaudit.md` 独立复审后 ack，
  `alarms.py check`=`clean (1255)`，`gen_coverage.py --check`=`848/244/0`，EP-112=`✓✓✓✓✓`。
- 本轮本地 source fixture/runtime 已按用户授权删除，formal session、录像、journals、证据和账本保留。批次二十四当前 **25/50**；
  未满批不跑统一长门禁、不提交。下一原子前线为 EP-113 `POST /api/v1/skills/{name}:approve-tools`。

## 2026-08-09 · EP-111 `POST /api/v1/skills/{name}:activate` 五级收口，批次二十四 20/50

- 产品目的：激活 skill 后，精确参数要抵达正确的 inline/fork 边界；歧义不能扩大搜索；Explore 文件读取必须受
  workdir/精确绝对路径约束；fork 返回后父回合不能继续执行工具；最终用户看到的是可理解、可继续的结果，而不是
  工具成功卡片或模型自述。
- 最终真实 session `/private/tmp/anselm-rig-ep111-skill-activate-20260808/sessions/20260809-005230` 使用真实
  Flutter App、Computer Use、正确持久化 gateway tap `8877`、backend/frontend journal、三路 ssetap 和 LLM tap；
  `rig-check` 五通道全绿。输入 `["the ep111-fork skill file"]` 后，App 显示 `Activated skill ep111-fork`
  和明确中文歧义报告：无绝对路径、无挂载工作目录、不能定位且未扩大搜索。loading、最终态和静态保持期间的
  Computer Use 画面干净；录屏 `156.808333s / 2784x1808 / 60fps`，messages durable seq `1..41` 单调。
- 五通道结果：backend 只留预期 fork scope refusal WARN，无 panic/FATAL；frontend 无 Flutter/Dart/RenderFlex/
  Unhandled/Exception；managed proof/chat wire 成功；独立 SSE 三流均连接同 workspace。精确绝对路径的
  `003714` 补证一次 `Read` 后父回合 `tools=0`；对抗 `004327` 补证模型忽略空工具集发送 `get_skill` 时，
  loop 跳过 AutoActivator、不执行并写 `TURN_TOOLS_DISABLED`。
- stop-and-fix 已落地：Explore filesystem scope 变为真实错误且拒绝越界；fork 成功后 run-local `TurnControl`
  移除父工具 schema；未知 agent 在 create/replace 早拒 `422 SKILL_FORK_AGENT_TYPE_INVALID`；失败 fork 不污染
  active skill。定向 Go/race/Flutter 测试、gofmt、diff check 通过；正式证据为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-111-skill-activate-final-green.md`。
- 负证据保留：`002025/002846` 说明 prompt-only 不足；`001920` 为 `rig-check` 捕获的旧 tap 接线错误；`004327`
  动态 ReplayKit 窗口录制有短暂重影，但实时 Computer Use 和新正确接线 session 未复现，已按仪器异常登记，
  不隐藏、不改判产品绿。
- 正式 ledger `1245→1250 judgments`，`G1/F2/A5/C4/G2`，anchors `10/10`，alarms clean；COVERAGE
  `848 rows / 247 carried / 0 tombstones`。批次二十四由 `15/50→20/50`，未满批不跑统一长门禁、不提交；
  下一原子前线为 COVERAGE 下一行。
- 五格写入按原机制打开 `gap-too-fast` / `discovery-collapse`；独立复审证据为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-111-skill-activate-ledger-reaudit.md`。复核最终 session、
  精确路径、晚发工具、prompt-only 红证据、旧 tap 接线红证据、race、anchors 和 coverage 后按原阈值 ack，未改算法、
  法条或锚点；最终 alarms clean。
- 用户授权的 fixture cleanup 已完成：`ep111-inline` / `ep111-fork` 删除均为 `204`，随后
  `GET=404`，列表仅剩两个 seeded skills，filesystem 和 relations 无残留；正式清理证据为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-111-fixture-cleanup.md`。同时恢复了因临时清理误删的
  `anchor-answers-final.json`，用冻结 hash 重跑校准为 10/10，未修改 anchor set 或 gate。

---

## 2026-08-08 · EP-111 激活路径首轮红与 runner 类型契约修复（未入账）

- 真实 App session `/private/tmp/anselm-rig-ep111-skill-activate-20260808/sessions/20260808-232650` 仍在运行，
  首轮 inline 两次激活均在工具/SSE/LLM wire 中得到真实 `CLAUDE_SESSION_ID` 与 `CLAUDE_SKILL_DIR`，但模型最终文本
  用 `the requested item` 和伪造路径替换了真实值；这是模型对工具真相不忠实的产品红，不按工具卡成功判绿。
- 同一 session 的 fork fixture `agent="explore"` 被成功保存，激活时才报
  `unknown type "explore" (have [Explore Plan general-purpose])`。配置面没有 enum/有效值提示，冻结为“创建可保存、运行才埋雷”。
- stop-and-fix：domain `SubagentRunner` 暴露同一 registry 的 `SupportedAgentTypes`；Skill create/replace 早拒未知类型，
  legacy/installed 激活在 active-skill 预授权前 fail-closed，并新增 `SKILL_FORK_AGENT_TYPE_INVALID` details；失败 fork
  不污染父回合。工具 schema/description、Library 中英文 hint、demo/contract fixture、Skill/API/error/frontend reference
  已同步。
- 定向验证：Go skill/subagent/tool/handler tests 全绿；Flutter skill contract/library/tree tests `58` 项全绿；`dart run slang`
  全绿；`git diff --check` 与 gofmt 全绿。尚未重启台架、尚未写 formal ledger、尚未增加 COVERAGE 格子；批次二十四仍 `15/50`。
- 下一步：使用新 binary 重跑真实 inline/fork 成功、坏 agent 创建/激活、无 runner、未知 skill、参数形状与 installed trust，
  处理模型叙述忠实度红线后才决定 EP-111 是否可以五级入账。

---

## 2026-08-08 · EP-110 DELETE /api/v1/skills/{name} 五级收口，批次二十四 15/50

- 产品目的：删除 skill 后，完整 bundled file tree、function binding、Library 选中态、REST、SSE、filesystem 与 workspace isolation 必须一致；确认文案要明确，删除后的界面不能残留已删除对象。
- 真实 session `/private/tmp/anselm-rig-ep110-skill-delete-20260808/sessions/20260808-231300` 使用真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness、受管 gateway 和 LLM tap。fixture `ep110-delete-tree` 含 `SKILL.md`、`references/notes.md`、`scripts/check.py`，并绑定 seeded `greet`；App 显示 `3 files · 1 bindings`、文件树和 Bindings。
- 从 row actions 打开并确认 `Delete this skill?` 对话框后，rail 移除 fixture、中心回到 `Untitled`；REST skill/files 均为 `404 SKILL_NOT_FOUND`，列表只剩两个 seeded skills，filesystem 整目录消失，equip relation 清空。负向矩阵：缺 workspace=`401 UNAUTH_NO_WORKSPACE`、非法名=`400 SKILL_INVALID_NAME`、未知/重复/跨 workspace=`404 SKILL_NOT_FOUND`。
- 五通道封口：录屏 `217.530000s`；backend 无 `WARN/ERROR/panic/FATAL`，frontend 无 Flutter/Dart 应用红线；SSE 三流连接，notifications durable seq `16..19` 单调并含 create、两次 bundled-file update、delete；主 workspace gateway challenge/install/models 全 `200`。隔离 workspace 立即删除时的 install cancellation 是预期生命周期取消，不计主路径成功或失败。
- 定向验证：`mise exec -- go test ./internal/app/skill ./internal/app/relation ./internal/transport/httpapi/handlers`、`mise exec -- go test -race ./internal/app/freetier`、`flutter test test/features/library/deleted_page_eviction_test.dart test/features/library/library_test.dart test/features/library/skill_tree_preview_test.dart`（57 tests）全绿；gofmt/diff check 全绿。EP-110 无新增产品源代码修复，EP-109 free-tier race fix 仍由测试覆盖。
- 正式证据为 `/private/tmp/anselm-rig-ep110-skill-delete-20260808/sessions/20260808-231300/evidence/EP-110-final-green.md`，formal 指针为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-110-skill-delete-final-green.md`，告警复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-110-approval-ledger-reaudit.md`。正式 `RIG_HOME` 下 `judge.py` 按 `G1/F2/A5/C4/G2` 将 `1240→1245 judgments` 写入五格；`gap-too-fast`/`discovery-collapse` 经独立复审 ack，`alarms.py check`=`clean (1245)`，anchors `10/10`，`gen_coverage.py --check`=`848 rows / 242 carried / 0 tombstones`。首次无前缀命令造成的默认账本副本不作为权威。
- 批次二十四由 `10/50→15/50`；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-111 `POST /api/v1/skills/{name}:activate`。

## 2026-08-08 · EP-109 PUT /api/v1/skills/{name} 五级收口，批次二十四 10/50

- 产品目的：用户完整覆盖 skill 配置时，结构化读-改-写必须更新所有 owned fields，同时保留未知 manifest 元数据、comment、键序与 body；REST、Library、SSE、raw `SKILL.md` 和删除后的 UI 必须同真相。
- 真实 session `/private/tmp/anselm-rig-ep109-fix-20260808/sessions/20260808-225941` 使用真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness、受管 gateway 和 LLM tap。raw manifest 含 `license`、`metadata.author`、`x-vendor-thing`、scalar tools 等未知/非规范形态；结构化 PUT 更新 description/body/allowedTools/context/agent/arguments/disableModelInvocation/userInvocable，REST 与 raw read 证明未知字段、comment/order 和 body 保真。
- 真实 Library 终帧显示更新正文、Fork、Agent、Read/Grep、new/review 以及两个 Off 开关。Computer Use 的 `command+a` 追加文本、`set_value` 不触发 Flutter `onChanged` 被分类为台架注入限制，未当产品红；REST 恢复 canonical Agent 后再清理。fixture DELETE `204`、GET `404 SKILL_NOT_FOUND`、列表只剩两条 seeded skill；App rail 移除 fixture，中心回到 `Untitled`。
- 首轮旧 session `/private/tmp/anselm-rig-ep109-skill-put-20260808/sessions/20260808-224130` 发现真实 race：workspace 删除后异步 free-tier hook 仍尝试写 managed key/seed 并 WARN。stop-and-fix 在 provisioner 增加 workspace tombstone、cancel+join，reaper 先停止并等待 flight；新增 `TestStopWorkspace_PreventsLateProvision` 与 `TestStopWorkspace_CancelsInFlightProvision`。最终 immediate create/delete `ws_fce55961d70faad5` 只留下 debug lifecycle cancellation，无 managed key、WARN 或 ERROR。
- 五通道封口：`rig-check` 全绿，`rig-down` 封片 `384.140000s`；backend/frontend 无应用红线；SSE 三流均连接，notifications durable seq `16..24` 单调并含 create/update/delete；LLM proof challenge/install/models 全 `200`。完整证据为 session `evidence/EP-109-final-green.md`，formal 指针为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-109-skill-put-final-green.md`，告警复审为 `EP-109-approval-ledger-reaudit.md`。
- 定向验证：`mise exec -- go test ./internal/app/skill ./internal/transport/httpapi/handlers`、`mise exec -- go test -race ./internal/app/freetier`、`mise exec -- flutter test test/features/library/library_test.dart test/features/library/skill_tree_preview_test.dart`（52 tests）全绿；gofmt/diff check 全绿。formal `judge.py` 按 `G1/F2/A5/C4/G2` 将 `1235→1240 judgments` 写入五格，anchors `10/10`；`alarms.py check` 在独立复审后 clean，`gen_coverage.py --check`=`848 rows / 241 carried / 0 tombstones`，未改阈值/算法/法典/锚点。
- 批次二十四由 `5/50→10/50`；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-110 `DELETE /api/v1/skills/{name}`。

## 2026-08-08 · EP-108 GET /api/v1/skills/{name} 五级收口，批次二十四 5/50

- 产品目的：用户在 Library 打开 skill 时得到完整正文、typed frontmatter、真实 `dir` 和安装 provenance；文件树点开附属 markdown 继续可读，跨 workspace、缺 workspace、未知项和删除都必须诚实收口。
- 首轮真实 App 冻结为红：`skillFileLocation()` 错写 `/documents/skill/...`，点击 `guide.md` 落到 `Untitled`。修复为 `/library/skill/:name?file=<relative path>` 并补 URL path/query 回归。
- 路由修复后的新 binary 再冻结第二条真实红：附属 markdown 把 shrink-wrapped `AnEditor` 放进 `SingleChildScrollView`，Flutter console 报 `RenderBox/RenderSliver` 协议错误。改为 `CustomScrollView + SliverPadding + AnEditor`，保留标准 overlay scrollbar，补 widget regression；两份红日志留存，不计绿。
- 最终 session `/private/tmp/anselm-rig-ep108-skill-get-20260808/sessions/20260808-223113` 真实路径打开 `ep108-installed` 的 `guide.md`，中心显示 `Installed reference` 和正文，右岛 Files/Provenance/Outline 完整，Outline 为 `Installed reference`；无错误卡、空白页、裁切、loading 残留或视口跳变。REST 同时验证用户 skill 未知 frontmatter 键保真、安装 skill provenance/file hashes/dir、隐藏 sidecar、五种负向上下文边界。
- 按用户授权清理两个 skill 和隔离 workspace：DELETE `204`，随后 skill GET `404`，最终列表只剩 seeded skills 和主 workspace；notifications durable `seq=1,2` 为两个 `skill.deleted`，App rail 移除并回到 `Untitled`。
- 五通道：`rig-check` 全绿，`rig-down` 录屏 `137.360000s` 可读；三路 SSE 对 workspace 连接，backend/frontend/llmtap/ssetap 无应用红线，LLM tap 指向 `https://api.anselm.website`。完整证据为 `/private/tmp/anselm-rig-ep108-skill-get-20260808/sessions/20260808-223113/evidence/EP-108-skill-get-final-green.md`，formal 副本同名。
- 定向验证：`mise exec -- flutter test test/features/library/library_test.dart test/features/library/skill_tree_preview_test.dart`=`52 tests passed`；Dart format、diff check 通过。formal `judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1230→1235 judgments` 写入五格，anchors `10/10`；独立复审 `EP-108-skill-get-ledger-reaudit.md` 后 `alarms.py check` clean；`gen_coverage.py --check`=`848 rows / 240 carried / 0 tombstones`。
- 批次二十四由 `0/50→5/50`；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-109 `PUT /api/v1/skills/{name}`。

## 2026-08-08 · EP-107 POST /api/v1/skills 五级收口，批次二十三 50/50

- 产品目的：用户在真实 Chat 中用自然语言创建一个完整 skill；`create_skill` 工具 schema、REST 请求、持久化 frontmatter、durable SSE、Library Properties/Activity 与删除后的 UI 真相必须一致，结果要可理解、可继续使用，而不是只看一个 `201`。
- 首轮真实 Chat 冻结产品红：schema 漏掉 `userInvocable`，用户明确要求 `true` 但工具不能发送，REST 读取也确认 frontmatter 缺失。stop-and-fix 修改 `backend/internal/app/tool/skill/crud.go` 的严格 bool 解码、映射和 schema/description，补 `crud_test.go` native/exact-string 回归并同步 `docs/references/backend/domains/skill.md`；红证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-107-user-invocable-red.md` 保留。
- 固定真实 Chat session `/private/tmp/anselm-rig-ep107-skill-create-rerun-20260808/sessions/20260808-215429` 重跑成功：一次真实 `create_skill` 创建 `ep107-chat-notes-v2`，REST/LLM wire/UI 均确认 `userInvocable:true`、`disableModelInvocation:true`、`allowedTools:["Read"]`；Library Properties 显示 `Model can invoke Off` 和 `User-invocable On`，无裁切、重叠、loading 残留或视口跳变。
- 回归继续冻结第二条产品红：REST/agent 路径删除当前选中 skill 后，rail 已刷新但中心详情仍显示已删除正文和属性。stop-and-fix 修改 `frontend/lib/features/library/ui/library_ocean.dart` 的“曾见过且已消失”选中态驱逐逻辑，补中英文 `skillGone` 文案、生成字符串和 `deleted_page_eviction_test.dart` 两个回归。
- 最终真实 Flutter session `/private/tmp/anselm-rig-ep107-skill-create-rerun2-20260808/sessions/20260808-215933` 创建/选中 `ep107-delete-live2` 后 DELETE `204`；约 350ms 后 rail 移除、中心回到 `Untitled` 并显示 `This skill was deleted`。随后 GET `404 SKILL_NOT_FOUND`，workspace `ep107-*` 计数为 0；SSE notifications durable `seq=19` 为 `skill.deleted`。录屏 `259.116667s` 已由 `rig-down` 封片，五通道 `rig-check` 全绿，backend/frontend/llmtap/ssetap 无未解释应用红线。
- 定向验证：`mise exec -- go test ./internal/app/tool/skill -count=1` 通过；`mise exec -- flutter test test/features/library/deleted_page_eviction_test.dart test/features/library/library_test.dart` 通过（51 tests）；anchors `10/10`；`gen_coverage.py --check`=`848 rows / 239 carried / 0 tombstones`。
- formal `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 按 `G1/F2/A5/C4/G2` 将账本 `1225→1230 judgments` 写入五格，COVERAGE `EP-107=✓✓✓✓✓`。集中写账触发 `gap-too-fast`/`discovery-collapse`，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-107-skill-create-ledger-reaudit.md`，按原阈值 ack 后 `alarms.py check`=`clean (1230 judgments on record)`，未改阈值/算法/法典/锚点。最终证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-107-skill-create-final-green.md`。
- 批次二十三达到 **50/50**。尚未执行统一长门禁和提交；下一动作是完整 `make verify`、完整 `go test ./...`、已修场景回归、工作树审计和提交。全绿提交后才启动 EP-108。

## 2026-08-08 · EP-106 GET /api/v1/skills 五级收口，批次二十三 45/50

- 产品目的：用户在真实 Library → Skills 中看到完整、按名称排序、轻量且不泄露正文路径的 skill 列表；`disableModelInvocation=true` 不能错误隐藏用户 skill；外部创建/删除要经 durable signal 真实刷新。固定 session `/private/tmp/anselm-rig-ep106-skills-list-20260808/sessions/20260808-213055` 使用真实 Flutter App、受管 gateway、Computer Use、backend/frontend journal、三路 SSE witness、LLM tap 和窗口录屏。
- REST/UI：基线 2 条；创建三个临时 skill 后 list 5 条且排序严格；list 无 `body`/`dir`/`provenance`，缺 workspace `401 UNAUTH_NO_WORKSPACE`，错误 body frontmatter `422 SKILL_INVALID_FRONTMATTER`；长名称 rail 等高省略，详情 Properties 可用；模型不可调用 skill 仍可见并显示 `Model can invoke Off`。App 打开期间 `ep106-live-refresh` 创建后出现，删除 `204→404 SKILL_NOT_FOUND`，其余 fixture 清理后回到两条 seeded skill。
- 五通道：`rig-check` 全绿，`rig-down` 录屏 `267.278333s / 2784x1808 / 60fps`；backend/frontend/llmtap/recording 无应用红线；三路 ssetap 均连接，notifications durable seq `16..23` 单调唯一，四次 create + 四次 delete 完整；本格为确定性列表切片，不伪造 completion。完整证据 `/private/tmp/anselm-rig-ep106-skills-list-20260808/sessions/20260808-213055/evidence/EP-106-skills-list-final-green.md`，正式指针同名位于 `/private/tmp/anselm-rig-formal-20260801-3/evidence/`。
- 正式账本 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 按 `G1/F1/B2/C5/G2` 写入 `1220→1225 judgments`，anchors `10/10`；独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-106-skills-list-ledger-reaudit.md`，gap-too-fast/discovery-collapse 按原阈值打开后复审并 ack，最终 `alarms.py check`=`clean (1225 judgments on record)`，未改阈值/算法/法典/锚点。`gen_coverage.py --check`=`848 rows / 238 carried / 0 tombstones`，COVERAGE `EP-106=✓✓✓✓✓`。
- 仪器纪律：首轮账本命令漏 export `RIG_HOME`，五条初始 append 进入默认旁路 journal；未手改账本，随后用 `env RIG_HOME=...` 重新执行 formal gate，旁路记录隔离，formal journal 与 COVERAGE 对齐。批次二十三当前 45/50，下一前线 EP-107。

## 2026-08-08 · EP-105 GET /api/v1/approvals/{id}/versions/{version} 五级收口，批次二十三 40/50

- 产品目的：用户能按数字或 opaque version ID 读取 Approval 的单个历史快照，不能跨父、猜版本或在主行软删后丢审计。固定 session `/private/tmp/anselm-rig-ep105-approval-version-get-20260808/sessions/20260808-212032` 建立 A(v1/v2/v3) 与 B(v1)，真实 App 从 Entities → Approval A → Versions 看到 v3 active、v2 diff 与完整版本内容，逐帧无裁切、重叠、死 loading 或跳变。
- REST/negative matrix：A numeric v2、opaque v1/v3→`200`；`0/-1/999/2.0`、跨父 opaque、未知父→`404 APPROVAL_VERSION_NOT_FOUND`；缺 workspace→`401 UNAUTH_NO_WORKSPACE`。A/B DELETE→`204`，exact entity GET→`404`，A 删除后 numeric v2/opaque v3 仍→`200`；SQLite 保留 A 3 条、B 1 条版本。
- 五通道：`rig-check` 全绿，`rig-down` 录屏 `213.058333s / 2784x1808 / 60fps`；backend/frontend/llmtap 无应用红线；notifications durable seq `16..21` 单调唯一，A/B create/edit/delete 信号完整；本格是确定性读取，不伪造 completion。完整证据 `/private/tmp/anselm-rig-ep105-approval-version-get-20260808/sessions/20260808-212032/evidence/EP-105-approval-version-get-final-green.md`，正式指针同名位于 `/private/tmp/anselm-rig-formal-20260801-3/evidence/`。
- 正式账本 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 按 `G1/F1/B2/C5/G2` 写入 `1215→1220 judgments`，anchors `10/10`；独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-105-approval-version-get-ledger-reaudit.md`，统计警报复审后 ack，未改阈值/算法/法典/锚点；`alarms.py check` clean，`gen_coverage.py --check`=`848 rows / 237 carried / 0 tombstones`，COVERAGE `EP-105=✓✓✓✓✓`。批次二十三当前 40/50，下一前线 EP-106。

## 2026-08-08 · EP-104 GET /api/v1/approvals/{id}/versions 五级收口，批次二十三 35/50

- 产品目的：让用户从真实 App 的 Approval Versions 入口审查完整 immutable history，而不是只得到一个 API 数组。固定 UI session `/private/tmp/anselm-rig-ep104-approval-versions-20260808/sessions/20260808-210508` 建立 25 个版本，首屏 v25 自动展开并显示 active marker 与 v24→v25 diff，分页加载 v5..v1，v1 可展开，行菜单显示 `Show diff / Show all / Set active`；逐帧无裁切、重叠、死 loading 或滚动跳变。
- REST/negative matrix：`limit=20` 两页 cursor 得 v25..v6/v5..v1；`limit=0→400 INVALID_REQUEST`、malformed cursor→`400 MALFORMED_CURSOR`、unknown parent→`404 APPROVAL_NOT_FOUND`、缺 workspace→`401 UNAUTH_NO_WORKSPACE`；`limit=999` 有界成功。
- 按用户授权删除临时 UI fixture `apf_f7d3208a5fceb8dc`：DELETE `204`，exact GET `404`，versions 仍返回 25 行 v25..v1；App 通过 durable delete signal 回到 Entities Overview，Approval 从 rail 消失，Parts `1→0`。初次 harness 的 zsh `$APPROVAL:edit` 误发 `/dit` 无 mutation，改 `${APPROVAL}:edit` 后重跑成功，噪声已单独记录。
- 五通道：`rig-check` 收台全绿，`rig-down` 录屏 `518.151667s`；backend/frontend/llmtap 无应用红线；notifications durable seq `16..67` 单调唯一，UI fixture 信号为 `42..67`；本格是确定性读取，不伪造 completion。完整证据 `/private/tmp/anselm-rig-ep104-approval-versions-20260808/sessions/20260808-210508/evidence/EP-104-approval-versions-final-green.md`，正式指针同名位于 `/private/tmp/anselm-rig-formal-20260801-3/evidence/`。
- 正式账本 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 按 `G1/F2/B2/C5/G2` 写入 `1210→1215 judgments`，anchors `10/10`；独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-104-approval-versions-ledger-reaudit.md`，统计警报复审后 ack，未改阈值/算法/法典/锚点；`alarms.py check` clean，`gen_coverage.py --check`=`848 rows / 236 carried / 0 tombstones`，COVERAGE `EP-104=✓✓✓✓✓`。批次二十三当前 35/50，下一前线 EP-105。

## 2026-08-08 · EP-103 POST /api/v1/approvals/{id}:iterate 五级收口，批次二十三 30/50

- 产品目的：从 Approval 行菜单进入一个带完整当前定义的 AI 编辑对话；首轮先澄清具体改动，第一次具体 edit 调用就复制完整 replacement snapshot 并产生正确 v2。不能把“先失败再 retry”算作用户可接受的成功旅程。
- 首轮真实 App session `/private/tmp/anselm-rig-ep103-approval-iterate-20260808/sessions/20260808-203834` 冻结为产品红：模型猜错 mention 中的 Approval opaque id，App 显示 `approval form not found` 后才用正确 id retry。stop-and-fix 在 aispawn steering、`get_approval` 描述和 API 契约加入 exact target lock，并补 prompt 回归测试。
- 第二次真实 session `/private/tmp/anselm-rig-ep103-approval-iterate-fixed-20260808/sessions/20260808-204652` 冻结第二个产品红：模型向严格完整 replacement `edit_approval` 发送 delta，用户看见 `Edit failed`、`Draft unsaved` 和失败工具卡后才 retry。后端严格契约保持不变；stop-and-fix 要求首次调用带齐 `approvalId`、`inputs`、`template`、`allowReason`、`timeout`、`timeoutBehavior` 和非空 `changeReason`，未知字段先重读，绝不依赖 retry；同步 `docs/references/backend/api.md`。
- 固定 green session `/private/tmp/anselm-rig-ep103-approval-iterate-fixed2-20260808/sessions/20260808-205246` 使用真实 Flutter App、Computer Use、窗口录制、backend/frontend journal、独立三路 SSE witness、managed gateway 和 LLM tap。真实路径为 Entities → Approval 行菜单 → `Edit with AI` → 首轮读取定义并提问 → 用户提交模板变更 → 第一次完整 `edit_approval` 产生 v2；终帧显示成功 v2、before/after diff、最终摘要和 Activity `1 touched / Edited`，无红卡、裁切、loading 残留、输入/视口跳变或重复 mutation。
- 五通道对证：录屏 `356.106667s / 2784x1808 / 60fps`；backend 无 `WARN|ERROR|panic|fatal|exception`，frontend 无 Flutter/Dart/RenderFlex/Unhandled/overflow/concurrent-modification/assert 红线；SSE messages durable `1..33`、notifications `16..21` 单调，cleanup 的 `approval.deleted`/`conversation.deleted` 为 seq `20/21`；llmtap challenge/install/models/chat completions 全 `200`，首次 edit wire 为完整字段且无失败 retry。完整证据为同 session `evidence/EP-103-approval-iterate-final-green.md`，正式指针为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-103-approval-iterate-final-green.md`。
- 负向矩阵：空/空白 request `400 EMPTY_ITERATE_REQUEST`、未知 Approval `404 APPROVAL_NOT_FOUND`、缺 workspace `401 UNAUTH_NO_WORKSPACE`。按用户授权删除 Approval 与专用 AI conversation，均 `DELETE 204 → GET 404`，列表为空，删除证据保留在 `evidence/ep103-cleanup-*`。
- 正式账本使用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`，`judge.py` 按 `G1/F2/A5/C4/G2` 从 `1205→1210 judgments` 写入五格，anchors `10/10`。写账打开的 `gap-too-fast` 与 `discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-103-approval-iterate-ledger-reaudit.md` 独立复审并 ack，未改阈值、算法、法典或锚点；最终 `alarms.py check`=`clean (1210 judgments on record)`。
- `gen_coverage.py --check`=`848 rows / 235 carried / 0 tombstones`，EP-103=`✓✓✓✓✓`。批次二十三由 **25/50→30/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-104 `GET /api/v1/approvals/{id}/versions`。

## 2026-08-08 · EP-102 POST /api/v1/approvals/{id}:revert 五级收口，批次二十三 25/50

- 产品目的：用户从 Approval 的 Versions 表面把历史版本设为 active 后，Overview、Versions、Activity、REST、SQLite 和 SSE 必须保持同一个真相；未知版本和畸形版本输入必须大声失败，不能切错版本、重复 mutation 或留下脏状态。
- 首轮真实 App session `/private/tmp/anselm-rig-ep102-approval-revert-20260808/sessions/20260808-201325` 冻结为产品红：正常点击版本动作触发 selectable 子树重建时，`frontend.log` 出现真实 Flutter `Concurrent modification during iteration`，栈落在 `MultiSelectableSelectionContainerDelegate._flushInactiveSelections`；红证据为同 session `evidence/EP-102-frontend-defect-and-fix.md`，不计绿。
- stop-and-fix 修改 `frontend/lib/core/ui/an_interactive.dart`：业务点击即时执行，selection region focus handoff 延后一个 frame并加脱离守卫，避免同步改变 selectable 集合时并发遍历；新增 `frontend/test/core/ui/an_selection_region_test.dart` 回归。`mise exec -- flutter test test/core/ui/an_selection_region_test.dart` 为 6/6，定向 analyze 和 diff check 通过。
- 固定真实 session `/private/tmp/anselm-rig-ep102-approval-revert-fixed-20260808/sessions/20260808-202631` 重跑 v2→v1、外部 REST v1→v2 resync、UI 再 v2→v1；最终 v1 active、Versions 保留 v2/v1、Overview 精确显示 v1，未知 `999→404 APPROVAL_VERSION_NOT_FOUND`、字符串 `"1"→400 INVALID_REQUEST`，无运行时异常、重复 mutation、裁切或视口跳变。录屏 `304.298333s` 已封片。
- 五通道对证：backend journal 无应用 WARN/ERROR/panic/fatal；frontend 仅有已分类 AXTree stale-node 观察器消息，没有 `ConcurrentModificationError` 或 Flutter/Dart runtime 红线；ssetap notifications durable seq `16..21` 单调并包含 reverted/deleted；REST/SQLite、SSE close 快照、UI 截图逐项一致；llmtap 真实 managed gateway challenge/install/models 全部 200。最终绿证据为同 session `evidence/EP-102-approval-revert-final-green.md`。
- 用户已授权 cleanup：DELETE `204`、GET `404 APPROVAL_NOT_FOUND`、列表总数 0，SSE 仅一条 `approval.deleted`；清理证据为同 session `EP-102-fixture-cleanup.md`。
- 正式账本使用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`，按 `G1/F2/A5/C4/G2` 从 `1200→1205 judgments` 写入五格，anchors `10/10`；正式独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-102-approval-revert-ledger-reaudit.md`。集中写账打开的 gap/discovery 警报按原阈值复审并 ack，未改阈值、算法、法典或锚点，最终 `alarms.py check` clean。
- `gen_coverage.py --check`=`848 rows / 234 carried / 0 tombstones`，EP-102=`✓✓✓✓✓`。批次二十三由 **20/50→25/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-103 `POST /api/v1/approvals/{id}:iterate`。

## 2026-08-08 · EP-101 POST /api/v1/approvals/{id}:edit 五级收口，批次二十三 20/50

- 产品目的：用户从 Approval 的 `Edit with AI` 入口完成一次完整 replacement，新增
  `refundReason:string`、精确替换模板，并保留未改变的 `allowReason=true`、`timeout=4h`、
  `timeoutBehavior=reject`；不能以一次失败 retry 后的数据正确冒充流畅旅程。
- 首轮真实 App session `/private/tmp/anselm-rig-ep101-approval-edit-20260808/sessions/20260808-193907`
  冻结为红：模型遗漏 unchanged `allowReason`，后端正确拒绝完整替换，用户看见红色工具结果、
  “previous version remains active”和随后 retry 成功。红证据保留且不计绿。
- stop-and-fix 强化 `edit_approval` description/schema，要求先读当前实体并复制所有 required fields，
  特别是未改变的布尔值；补工具契约测试，同步 `docs/references/backend/domains/approval.md`。定向
  `mise exec -- go test ./internal/app/tool/approval ./internal/app/approval`、
  `mise exec -- go test ./internal/app/loop ./internal/app/chat`、gofmt 和 `git diff --check` 通过。
- 固定真实 session
  `/private/tmp/anselm-rig-ep101-approval-edit-fixed-20260808/sessions/20260808-195118` 使用真实 Flutter
  App、受管 gateway、Computer Use、录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap
  重跑。最终一次 `edit_approval` 产生 v3，REST/SSE/LLM wire/UI 逐项一致：三个输入字段、精确模板、
  `allowReason=true`、`4h`、`reject`；终帧显示完整请求、单一成功工具卡、齐全字段表和
  `EP101 Refund Review Edited ×2`，无红卡、裁切、loading 残留、视口跳变或重复 mutation。
- Computer Use 的中文 `type_text` 会丢失部分中文字符，最终精确意图用 ASCII 等价请求从正常 composer
  重走；该输入层限制单独记录，不把丢字结果冒充产品通过。证据为
  `/private/tmp/anselm-rig-ep101-approval-edit-fixed-20260808/sessions/20260808-195118/evidence/EP-101-approval-edit-final-green.md`，
  红证据和 `EP-101-final-frame.png`、录屏、五通道原始日志均保留。
- 用户已授权清理临时夹具：DELETE `204`，随后 GET `404 APPROVAL_NOT_FOUND`，列表为空，SSE 仅一条
  `approval.deleted`；清理细节见同 session 的 `EP-101-fixture-cleanup.md`。
- 正式账本必须使用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`：`judge.py` 按
  `G1/F2/A5/C4/G2` 从 `1195→1200 judgments` 写入五格，anchors `10/10`。正式
  `alarms.py check` 先打开 `gap-too-fast/discovery-collapse`，独立复审为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-101-approval-edit-ledger-reaudit.md`，
  未改阈值/算法/法典/锚点后 ack，最终 clean。一次未带 formal `RIG_HOME` 的默认账本副本保留作错路由
  审计，正式 working state 与 COVERAGE 只认 formal ledger。
- `gen_coverage.py --check`=`848 rows / 233 carried / 0 tombstones`；rig-check、rig-down、五通道、
  定向 Go tests、gofmt、diff check 均通过。批次二十三由 **15/50→20/50**，未到 50 格不跑统一长门禁、
  不提交；下一原子前线为 EP-102 `POST /api/v1/approvals/{id}:revert`。

## 2026-08-08 · EP-100 DELETE /api/v1/approvals/{id} 五级收口，批次二十三 15/50

- EP-100 完成真实 App、真实受管 Anselm gateway、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和 LLM tap。固定 session 为 `/private/tmp/anselm-rig-ep100-approval-delete-20260808/sessions/20260808-192034`，录屏 `494.890000s`，真实 gateway upstream 为 `https://api.anselm.website`。
- 产品目的为移除活动 Approval、清理关系边、保留 immutable version history，并让依赖 workflow 保持可见且可修复。真实 App 删除确认后，Approval 从 rail/Parts 消失，关系图清边，Notifications 显示删除与 `1 reference dangling`；workflow graph/editor 保留原始 dangling ref，不静默重绑。
- REST 矩阵覆盖主删除 `204`、删除后 `404 APPROVAL_NOT_FOUND`、列表消失、三条 versions 历史保留、workflow/capability missing-ref、关系清理、重复/未知删除、缺 workspace、cross-owner 和同名复用；SQLite 证明软删主行带 `deleted_at`、三条版本保留且无目标关系行。
- 五通道完整：backend 652 行无应用 WARN/ERROR/panic/FATAL；frontend 18 行只有已知 launcher 噪声；三路 SSE 均连接且主 notifications durable seq `16..24` 单调；llmtap challenge/install/models 全部物理经真实 gateway 返回 200；rig-check 前后全绿，rig-down 正常收台。最终绿证据为 `EP-100-approval-delete-final-green.md`。
- 用户授权的独立 cleanup `/private/tmp/anselm-rig-ep100-cleanup-20260808/sessions/20260808-192941` 删除依赖 workflow、trigger 和 auxiliary workspace，DELETE `204` 后精确 GET `404`；主 workspace、seeded graph、journals、录像和证据保留。清理证据为 `EP-100-fixture-cleanup.md`。
- 独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-100-approval-delete-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1190→1195 judgments`，COVERAGE `EP-100=✓✓✓✓✓`，anchors `10/10`；集中写账打开的 gap/discovery 警报经复审 ack，未改阈值、算法、法典或锚点，`alarms.py check`=`clean (1195)`，`gen_coverage.py --check`=`848 rows / 232 carried / 0 tombstones`。
- 本格无产品源代码变更；anchors、alarms、coverage 与 `git diff --check` 已验证。pytest 不在当前 Python 环境中安装，已如实记录。批次二十三由 `10/50→15/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-101 `POST /api/v1/approvals/{id}:edit`。

## 2026-08-08 · EP-099 PATCH /api/v1/approvals/{id} 五级收口，批次二十三 10/50

- EP-099 完成真实 App、真实受管 Anselm gateway、Computer Use、窗口录制、backend/frontend journal、三路独立 SSE witness 和 LLM tap。固定 session 为 `/private/tmp/anselm-rig-ep099-approval-patch-20260808/sessions/20260808-190922`，录屏 `280.013333s`，真实 gateway upstream 为 `https://api.anselm.website`。
- REST 矩阵覆盖 name-only、description-only、name+description、等值/空 patch、`name:null`、空白名、重复名、未知字段、畸形 JSON、未知 ID、缺 workspace、cross-owner 与 valid cross-workspace。实际变化均 `200`；no-op 不刷新 `updatedAt`、不发 durable notification；错误分别为 `APPROVAL_INVALID_NAME`、`APPROVAL_NAME_DUPLICATE`、`INVALID_REQUEST`、`APPROVAL_NOT_FOUND`、`UNAUTH_NO_WORKSPACE`。
- 真实 App rail 与 Overview 收敛到最终 `EP099 Approval Final` / `Final product description`；v1、输入、template、reason、timeout、reject behavior 完整可见，Versions 仅有 v1 / `Diff, 0 added, 0 removed`，无裁切、重叠、loading 残留或输入跳变。主 workspace notifications seq `16..20`、cross workspace `1..2` 各自在 workspace 内连续，SQLite 三个夹具各只有一行 v1。
- backend journal 326 行无应用 WARN/ERROR/panic/FATAL；frontend 只有已知 launcher 噪声，无 Dart/Flutter/RenderFlex/Unhandled 红线；三路 SSE 已连接，llmtap challenge/install/models 全部物理经真实 gateway wiring。最终绿证据为 `EP-099-approval-patch-final-green.md`。
- 用户授权的独立 cleanup session `/private/tmp/anselm-rig-ep099-cleanup-20260808/sessions/20260808-191456` 删除三个 Approval 和辅助 workspace：DELETE `204`，精确 GET `404`，主 workspace 保留且列表无 EP099；SQLite 保留软删主行与 v1 immutable version history。清理证据为 `EP-099-fixture-cleanup.md`。
- 正式账本按 `G1/F2/A5/C4/G2` 从 `1185→1190 judgments`，COVERAGE `EP-099=✓✓✓✓✓`，anchors `10/10`。集中写账打开的 `gap-too-fast`/`discovery-collapse` 由 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-099-approval-patch-ledger-reaudit.md` 独立复审并 ack，未改阈值、算法、法典或锚点；formal `alarms.py check`=`clean (1190)`，`gen_coverage.py --check`=`848 rows / 231 carried / 0 tombstones`。
- 定向 Go 回归、`make -C docs verify`、anchors、gofmt 与 `git diff --check` 全绿。批次二十三由 `5/50→10/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-100 `DELETE /api/v1/approvals/{id}`。

## 2026-08-08 · EP-098 GET /api/v1/approvals/{id} 五级收口，批次二十三 5/50

- 首轮真实对抗冻结数据真相红：真实 Approval 的 `active_version_id` 指向不存在版本时，旧二进制返回 `200` 但省略 `activeVersion`，前端会把损坏误解成“还没有版本”。红证据为 `/private/tmp/anselm-rig-ep098-approval-get-20260808/sessions/20260808-184502/evidence/EP-098-approval-get-red-dangling-active.md`，不计绿。
- stop-and-fix 对 Approval/Control/Function/Handler/Agent/Workflow 六个同类单读服务统一 fail-closed：空 pointer 返回 `*_NO_ACTIVE_VERSION`，悬空 pointer 返回 `*_VERSION_NOT_FOUND`，成功响应始终 hydrate `activeVersion`；补 Approval 空/悬空回归测试与 API 契约。
- 固定真实 session `/private/tmp/anselm-rig-ep098-approval-get-fixed-20260808/sessions/20260808-185307` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journals、三路独立 SSE witness、managed gateway 和 LLM tap；录屏 `292.263333s / 46M`。REST 覆盖正常 v2、空/悬空 pointer、未知 ID、缺 workspace、cross-workspace 与 valid-owner 矩阵；App Overview、滚动底部和 Versions diff 均无产品红。
- 五通道对证：backend 294 行无 WARN/ERROR/panic/fatal；frontend 只有已知 launcher `Failed to foreground app; open returned 1`，无 Dart/Flutter runtime 红线；SSE 三流连接并留下 8 个 durable frames；LLM tap 物理接到 `https://api.anselm.website`，确定性读路径不虚构 completion。最终绿证据为 `EP-098-approval-get-final-green.md`。
- 用户授权的独立 cleanup session `/private/tmp/anselm-rig-ep098-cleanup-20260808/sessions/20260808-190106` 删除两个 Approval 和探针 workspace，DELETE 全部 `204`；主 workspace 保留、列表为空、删除后单读 `404`，SQLite 保留 soft-delete 行与 immutable version history。清理证据为 `EP-098-fixture-cleanup.md`。
- 正式账本以 `G1/F2/A5/C4/G2` 从 `1180→1185 judgments`，`COVERAGE EP-098=✓✓✓✓✓`，anchors `10/10`；集中写账的 `gap-too-fast`/`discovery-collapse` 经封口录屏、五通道、红证据、修复测试与 cleanup 独立复审后 ack，正式 `alarms.py check` clean(1185)，`gen_coverage.py --check` clean(848 rows, 230 carried, 0 tombstones)。一次未 export `RIG_HOME` 的五条副本保留在默认 ledger 作错路由审计并已销账，formal ledger 才是权威。
- 已 `gofmt`；定向 `mise exec -- go test ./internal/app/approval ./internal/app/control ./internal/app/function ./internal/app/agent ./internal/app/handler ./internal/app/workflow ./internal/transport/httpapi/handlers` 全绿。批次二十三由 `0/50→5/50`，未到 50 格不跑统一长门禁、不提交；下一前线为 EP-099 `PATCH /api/v1/approvals/{id}`。

## 2026-08-08 · 批次二十二统一长门禁与提交，批次二十三 0/50

- EP-089..EP-097 累计变更已提交为 `20de5cea`（`test(acceptance): close approval list batch twenty-two`）。统一 `make verify` 的 backend/frontend/docs/demo 四门全绿；显式 `backend mise exec -- go test ./...` 全绿；本批 Approval/Control/entity/Conversation 相关回归 35 项全绿；`git diff --check` 与分批 `gofmt -l` 全绿。
- Working 状态从批次二十二 `50/50` 迁移到批次二十三 `0/50`；这是历史快照，当前恢复应以上方 EP-099 记录为准。

## 2026-08-08 · EP-097 GET /api/v1/approvals 五级收口，批次二十二 50/50

- EP-097 完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。用户实际目标是 Approval 名册可用而不是只有 200：23 条 fixture 后 Entities rail 显示 `Approval 23`，`APPROVAL-0` 搜索为 9 条，清空恢复 23 条，尾部无空白 seam；详情显示 v1、输入、模板、reason、timeout 和 timeout behavior；删除一条后 rail 23→22，当前详情仍连贯。没有发现需要 stop-and-fix 的产品或代码红。
- REST 矩阵覆盖 `limit=20` 的 `20+3` cursor 分页、`limit=999` 上限、`limit=0 → 400 INVALID_REQUEST`、大小写不敏感搜索与精确总数、缺 workspace、坏 cursor、删除后旧 cursor；删除为 `204`，exact GET 为 `404`。原始响应/headers 位于 `/private/tmp/anselm-rig-ep097-approval-list-20260808/sessions/20260808-182005/evidence/`。
- 固定真实 session `/private/tmp/anselm-rig-ep097-approval-list-20260808/sessions/20260808-182005` 使用 workspace `ws_14972f564f66a37d`，窗口 `28467`，录屏 `286.545000s / 49M`。backend 441 行无应用红线，frontend 18 行只有已知 launcher 噪声，SSE notifications durable seq `1..24` 连续，真实 llmtap wiring 指向 `https://api.anselm.website`；本确定性读取切片不虚构 completion。绿证据为 `EP-097-approval-list-final-green.md`。
- 用户授权的 fixture cleanup 已完成：首轮真实 session 删除 1 条，cleanup session `/private/tmp/anselm-rig-ep097-cleanup-20260808/sessions/20260808-182627` 删除剩余 22 条；23 个 DELETE 全部 `204`、23 个 exact GET 全部 `404`、活动列表为 0。SQLite 为 `23 deleted / 23 versions retained`，清理证据为固定 session 的 `EP-097-fixture-cleanup.md`，journals/录像/证据全部保留。
- 正式账本按 `G1/F2/A5/C4/G2` 从 `1175→1180 judgments`，COVERAGE `EP-097=✓✓✓✓✓`，anchors=10/10。L2 初次漏传 `--session` 被拒，随后以真实台架 session 补录成功；独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-097-approval-list-ledger-reaudit.md`。统计警报按原阈值复审后 ack，未改阈值、算法、法典或锚点；`alarms.py check`=`clean (1180)`，`gen_coverage.py --check`=`848 rows / 229 carried / 0 tombstones`。
- 批次二十二达到 **50/50**。现在必须执行统一长门禁并在全绿后提交；EP-098 在统一门禁和提交前不启动。

## 2026-08-08 · EP-096 POST /api/v1/approvals 五级收口，批次二十二 45/50

- 首轮真实 App 冻结出产品红：受管模型把 `2h` 编码为 `"7200"`，工具边界先报 `invalid timeout duration or missing/invalid timeoutBehavior`，模型随后重试成功；UI 同时出现失败工具行、`Draft unsaved · nothing was created` 和成功创建卡片。红证据永久保留于 `/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-175421/evidence/EP-096-approval-create-red.md`。
- stop-and-fix 在 approval tool 解码边界增加精确整数秒字符串/整数兼容归一化（`7200`→`2h`），公开 HTTP/domain duration 契约仍严格拒绝零、负数、无单位小数和坏形状；补解码、tool execution、domain/handler regression tests，并同步 approval domain 文档。定向 Go tests `go test ./internal/app/tool/approval ./internal/app/approval ./internal/domain/approval ./internal/transport/httpapi/handlers` 通过。
- 固定真实 session `/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-180647` 由同一 conductor 托管真实 Flutter App、Computer Use、`28438` 窗口 `132.026667s` 录像、backend/frontend journal、三路独立 SSE witness、managed gateway 和 LLM tap。用户实际创建 `ep096-refund-review-fixed`，要求 amount/customer 类型、reason、`2h` 和 reject；最终正文、Created v1、单一 Activity 和展开预览均一致，2h、auto-reject、note 与 Approve/Reject 完整可见，无失败行、矛盾文案、裁切、重叠或 loading 残留。
- 五通道交叉核验：backend 无 WARN/ERROR/panic/tool execute failed；frontend 只有已知 launcher `Failed to foreground app; open returned 1`，无 Dart/Flutter/RenderFlex/Unhandled runtime error；SSE 记录唯一 create open/close、approval.created 和 touchpoint，durable seq 单调；LLM upstream 全 200，真实参数仍为 `"timeout":"7200"`。REST/SQLite 同时证明 `apf_c07e5096237e71db` active v1 为 `2h/reject`，`7200` 未泄漏到 durable truth。
- 用户授权的 fixture cleanup 已执行：独立 session `/private/tmp/anselm-rig-ep096-cleanup-20260808/sessions/20260808-181438` 通过 API 删除三条审批、三条验收对话，DELETE `204×6`，exact GET `404×6`，列表无 `ep096-*`；三条审批主行的 `deleted_at` 保留，三条 immutable v1 version rows 保留，红绿证据、journals 与录像未删。清理证据为 `/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-180647/evidence/EP-096-fixture-cleanup.md`。
- 正式绿证据为 `/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-180647/evidence/EP-096-approval-create-final-green.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-096-approval-create-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1170→1175 judgments`，COVERAGE `EP-096=✓✓✓✓✓`，anchors=10/10；集中写账打开的统计警报经红绿证据、修复测试、负向边界和五通道复审后 ack，未改阈值、算法、法典或锚点。`alarms.py check`=`clean (1175)`，`gen_coverage.py --check`=`848 rows / 228 carried / 0 tombstones`。
- 批次二十二由 **40/50→45/50**；尚未到第 50 格，不跑统一长门禁、不提交。下一原子前线为 EP-097 `GET /api/v1/approvals`。

## 2026-08-08 · EP-095 GET /api/v1/controls/{id}/versions/{version} 五级收口，批次二十二 40/50

- 静态审查先冻结一个契约红：Control handler 的 opaque version 分支只按 `versionID` 做 generic lookup，没有把 URL parent 纳入查询；有效的 A version ID 存在通过 B 路径命中的风险。红证据为
  `/private/tmp/anselm-rig-ep095-control-version-get-20260808/sessions/20260808-173922/evidence/EP-095-control-version-get-red-unscoped-opaque.md`，明确这是修复前静态风险，不把修复后的 HTTP 结果冒充旧行为。
- stop-and-fix 对 Control 与 Approval 做同类横扫：新增 `GetVersionForControl`/`GetVersionForApproval`，store 查询同时绑定 parent ID 和 opaque version ID，handler/app 接入 parent-scoped path；cross/unknown 映射为 `CONTROL_VERSION_NOT_FOUND`/`APPROVAL_VERSION_NOT_FOUND`。新增 store/app regression，API 与两个 domain reference 同步。
- 定向 Go 验证通过：`mise exec -- go test ./internal/app/control ./internal/app/approval ./internal/infra/store/control ./internal/infra/store/approval ./internal/transport/httpapi/handlers`。
- 固定真实 session `/private/tmp/anselm-rig-ep095-control-version-get-20260808/sessions/20260808-173922` 由同一 conductor 托管真实 Flutter App、Computer Use、`2784x1808 / 60fps / 369.273333s` 录屏、backend/frontend journal、三路独立 SSE witness、managed gateway 和 LLM tap。真实 UI 打开 Control A 的 Versions，显示 active v4、diff 与 v3/v2/v1 历史；无裁切、重叠、loading 残留或视觉跳变。
- REST 矩阵覆盖 A own numeric/opaque、A-with-B opaque、B-with-A opaque、unknown parent、unknown numeric `999`、`0`、`-1`；合法读取 `200`，cross/unknown 全部 `404 CONTROL_VERSION_NOT_FOUND`，原始矩阵为 session `evidence/EP-095-control-version-get-http.json`，绿证据为 `EP-095-control-version-get-final-green.md`。
- 五通道：rig-check 收台前全绿；backend 464 行无 panic/fatal/error/warn；frontend 18 行仅已知 Flutter launcher `Failed to foreground app; open returned 1`，无 Dart/Flutter/RenderFlex/Unhandled runtime error；SSE 三流均 connect，notifications durable frame 观察到 B 创建；llmtap 真实 upstream 为 `https://api.anselm.website`，本确定性读取路径不虚构 completion；rig-down 封口且 owned processes 归零。
- 用户批准后清理本轮两条 acceptance Control A/B：DELETE `204×2`，随后 GET `404×2`，活动列表为空；SQLite 主行保留 `deleted_at`，A v1–v4/B v1 immutable version history、session、journals、录像和证据全部保留。清理证据为 `evidence/EP-095-fixture-cleanup.md`。
- 正式绿证据为 `/private/tmp/anselm-rig-ep095-control-version-get-20260808/sessions/20260808-173922/evidence/EP-095-control-version-get-final-green.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-095-control-version-get-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1165→1170 judgments`，COVERAGE `EP-095=✓✓✓✓✓`，anchors `10/10`；集中写账触发的 `gap-too-fast`/`discovery-collapse` 经静态红证据、固定 session、负向矩阵、修复测试和五通道重读后 ack，未改阈值/算法/法典/锚点，`alarms.py check`=`clean (1170)`，`gen_coverage.py --check`=`848 rows / 227 carried / 0 tombstones`。
- 批次二十二由 **35/50→40/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-096。

## 2026-08-08 · EP-094 GET /api/v1/controls/{id}/versions 五级收口，批次二十二 35/50

- 首轮真实 App 走查发现 Control 详情只有 `Overview`，没有 `Versions`；typed provider 对 Control/Approval 又返回空页，用户无法审查版本历史。红画面永久保留于
  `/private/tmp/anselm-rig-ep094-control-versions-20260808/sessions/20260808-170835/evidence/EP-094-control-versions-red-detail.jpeg`。
  stop-and-fix 接入 Control/Approval typed paging、versioned support-kind 详情页和 JSON diff，Trigger 保持唯一无版本 kind，并补实体/provider Flutter 回归。
- 第二轮真实负向矩阵发现未知 Control 的 versions 请求返回 `200` 空历史，无法与“真实父但历史为空”区分；红证据为
  `/private/tmp/anselm-rig-ep094-control-versions-fixed-20260808/sessions/20260808-171948/evidence/EP-094-control-versions-red-parent-empty.md`。
  修复 Control/Approval `ListVersions` 先解析父实体，未知父返回对应 `*_NOT_FOUND`，并补 app tests 与 API/domain 文档。
- 固定 session `/private/tmp/anselm-rig-ep094-control-versions-fixed2-20260808/sessions/20260808-172811` 由同一 conductor
  托管真实 Flutter App、Computer Use、`132.408333s` 窗口录制、frontend/backend journal、三路独立 SSE witness、managed gateway 和 LLM tap。
  真实 UI 从 Entities → Control → Versions 显示 active v4、v3→v4 `+1 −1` diff（0.90→0.95）及 v3/v2/v1 历史；无裁切、重叠、loading 残留或输入跳变。
- HTTP 矩阵为 valid `[4,3]`/`[2,1]` cursor 分页、`limit=0 → 400 INVALID_REQUEST`、坏 cursor → `400 MALFORMED_CURSOR`、未知父 → `404 CONTROL_NOT_FOUND`。
  完整 REST 证据为同 session `evidence/EP-094-control-versions-http.json`，最终绿证据为 `EP-094-control-versions-final-green.md`。
- 五通道：收台前 `rig-check.sh` 全绿；SSE 三流均 connect，backend 无 panic/fatal/error/warn，frontend 无 Dart/Flutter/RenderFlex/Unhandled/runtime exception，
  llmtap wiring 指向真实 `https://api.anselm.website` 上游。本切片是确定性 REST/UI 读取，不虚构无必要的 chat completion；Flutter runner foregrounding warning 已单独按启动器噪声记录。
- 独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-094-control-versions-ledger-reaudit.md`；`judge.py` 按 `G1/F2/A5/C4/G2`
  将 `1160→1165 judgments`，COVERAGE `EP-094=✓✓✓✓✓`，anchors `10/10`。集中写账打开的 `gap-too-fast`/`discovery-collapse` 经红绿证据复核后 ack，
  未改阈值/算法/法典/锚点，`alarms.py check`=`clean (1165)`，`gen_coverage.py --check`=`848 rows / 226 carried / 0 tombstones`。
- 批次二十二由 **30/50→35/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-095。

## 2026-08-08 · EP-093 POST /api/v1/controls/{id}:iterate 五级收口，批次二十二 30/50

- 首轮真实清理发现产品红：另一客户端删除当前会话后，rail 已移除列表行，但中心 transcript、右侧 Activity 和
  `/chat/:id` 深链仍留在屏幕上。红证据永久保留于
  `/private/tmp/anselm-rig-ep093-control-iterate-20260808/sessions/20260808-164054/evidence/EP-093-control-iterate-red-stale-transcript.md`。
  stop-and-fix 在 `ConversationRail` 接入 durable `conversation.deleted`，命中当前 URL 会话时回 landing；同一
  notifications 流 resync 重读当前行，仅服务端明确 404 才离开深链；补 external-delete widget 回归和
  lifecycle-resync 源码门禁。
- 固定 session `/private/tmp/anselm-rig-ep093-control-iterate-fixed-20260808/sessions/20260808-165406` 由同一 conductor
  托管真实 Flutter App、Computer Use、`317.221667s` 窗口录制、frontend/backend journal、三路独立 SSE witness、
  managed gateway 和 LLM tap。真实 App 从 fresh onboarding → Entities → Control → More actions → Edit with AI，
  真实模型只调用一次 `edit_control`，v2 active 将 approve `0.80→0.85`，score/review/两侧 emit 保留，reason 为
  `EP-093 iterate continuation fixed`，Activity 显示 `1 touched`。
- HTTP 对证：空 request=400 `EMPTY_ITERATE_REQUEST`，未知 control=404 `CONTROL_NOT_FOUND`；最终 v2 的 inputs/
  branches/emit/reason 和恰好 2 个版本由 REST 对证。删除当前会话=204 后 notifications 的 durable
  `conversation.deleted` 使 App 下一帧回 landing；Control 删除=204→GET=404，无 fixture 残留。
- 五通道：SSE 281 条，messages durable `1..24`、notifications `1..6` 单调唯一，entities 已连接；backend 429 行无
  WARN/ERROR/FATAL/panic/exception/tool execute failed，frontend 17 行无 RenderFlex/Unhandled/exception/runtime error；
  LLM tap 22 条，challenge/install/models 与 4 次真实 chat completion 的有状态记录全 HTTP 200；rig-check/rig-down
  干净收台。正式绿证据为
  `/private/tmp/anselm-rig-ep093-control-iterate-fixed-20260808/sessions/20260808-165406/evidence/EP-093-control-iterate-final-green.md`，
  独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-093-control-iterate-ledger-reaudit.md`。
- `judge.py` 以 `G1/F2/A5/C4/G2` 将账本 `1155→1160 judgments`，`COVERAGE EP-093=✓✓✓✓✓`，anchors=10/10；集中
  写账触发的 `gap-too-fast`/`discovery-collapse` 经红绿 session、负路径矩阵、修复测试、锚点和五通道重读后 ack，
  未改阈值/算法/法典/锚点，`alarms.py check`=`clean (1160)`，`gen_coverage.py --check`=`848 rows / 225 carried / 0 tombstones`。
- 批次二十二由 **25/50→30/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-094。

## 2026-08-08 · EP-092 POST /api/v1/controls/{id}:revert 五级收口，批次二十二 25/50

- 真实 App 从 fresh onboarding 进入 Entities → Control → EP092 Revert Router → More actions → Edit with AI；用户
  要求只把 active pointer 回到 v1，保留 name/description，不创建新版本，并保留 v2 历史。真实受管模型只调用一次
  `revert_control`，wire 使用 `controlId=ctl_548ae4e803f5ceca`、`version:"1"`；App 成功活动解释 pointer、无新版本、
  名称描述不变和历史保留。最终 Computer Use 画面逐帧显示 v1、score number、approve `input.score >= 0.80`、
  review default、两侧 emit decision，无裁切、重叠、loading 残留或视觉跳变。
- 固定 session `/private/tmp/anselm-rig-ep092-control-revert-20260808/sessions/20260808-162625` 由同一 conductor
  托管真实 App、Computer Use、`474.791667s / 2784x1808 / 60fps` 窗口录制、frontend/backend journal、三路独立
  SSE witness、managed gateway 和 LLM tap。HTTP 矩阵覆盖 v2/v1 成功回退、zero/unknown 版本 404；SQLite 证明
  active pointer=v1、版本表只有 v1/v2、v2 保留、name/description 未变；cleanup DELETE=204→GET=404 后真实 App
  收敛到 `0 entities, 0 relations` 空态。
- 五通道：SSE 197 条，messages durable `1..24`、notifications `1..8` 严格单调无 gap，entities 已连接；backend
  602 行无应用级 WARN/ERROR/FATAL/panic/exception/tool execute failed，frontend 19 行无 Flutter runtime 红线；
  LLM tap 22 条，challenge/install/models 与 5 次 chat completion 全 200；rig-check/rig-down 干净收台。
- 正式绿证据 `/private/tmp/anselm-rig-ep092-control-revert-20260808/sessions/20260808-162625/evidence/EP-092-control-revert-final-green.md`，
  独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-092-control-revert-ledger-reaudit.md`。`judge.py` 按
  `G1/F2/A5/C4/G2` 写入五级，账本 `1150→1155`，`COVERAGE EP-092=✓✓✓✓✓`，anchors=10/10；集中写账触发的
  `gap-too-fast`/`discovery-collapse` 经证据复审后 ack，未改阈值/算法/法典/锚点，`alarms.py check`=`clean (1155)`，
  `gen_coverage.py --check`=`848 rows / 224 carried / 0 tombstones`。首轮错误路径是 harness 的 shell quoting 404，
  无产品 mutation，正确引用路径已重跑并记录。
- 批次二十二由 **20/50→25/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线 EP-093。

## 2026-08-08 · EP-091 POST /api/v1/controls/{id}:edit 五级收口，批次二十二 20/50

- 首轮真实 AI 编辑 session `/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-160105` 发现两层产品红：
  托管模型把 `inputs`/`branches` 作为精确 JSON 数组字符串传给旧工具时解码失败；更严重的是模型省略可选
  `inputs` 后，旧 `edit_control` 将原有 `score:number` 声明擦成 `null` 的 v3。红证据永久保留在
  `evidence/EP-091-control-edit-red-inputs-erased.md`，前线按 stop-and-fix 冻结。
- 修复覆盖 AI tool、domain service 和 HTTP handler：`decodeControlInputs` 接受原生数组及精确 JSON 数组字符串，
  malformed/object/non-array 仍拒绝；edit presence 语义为省略保留 active declaration、显式 `[]` 才清空；HTTP
  坏输入在 mutation 前返回 `INVALID_REQUEST`。补充 service/tool 回归与 Control API/domain 文档同步。
- 固定真实 session `/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-161138` 由同一 conductor
  托管真实 Flutter App、Computer Use、`388.893333s / 2784x1808` 窗口录屏、frontend/backend journal、三路独立
  SSE witness、managed gateway 和 LLM tap。v2 基线后真实 App Edit with AI 创建 v4，LLM body `00006` 证实真实
  hosted model 传入 stringified inputs，v4 保留 score；HTTP 省略 inputs 创建 v5 仍保留 score；malformed inputs
  返回 400 且 GET 证明未 mutation。最终 UI 逐帧显示 active v5、score number、0.96 approve、review default 与两侧 emit。
- 五通道：messages durable seq `1..35`、notifications `1..5` 严格单调，entities 连接完成；backend 494 行无
  WARN/ERROR/FATAL/panic/tool execute failed，frontend 18 行无 Flutter/Dart/RenderFlex/Unhandled，challenge 与
  5 次真实 chat completion 全 200；rig-check 收台前归属全绿，rig-down 无残留。
- 正式绿证据 `/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-161138/evidence/EP-091-control-edit-final-green.md`，
  独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-091-control-edit-ledger-reaudit.md`。`judge.py` 按
  `G1/F2/A5/C4/G2` 写入五级，正式账本 `1145→1150`，`COVERAGE EP-091=✓✓✓✓✓`，anchors 10/10；集中写账触发的
  `gap-too-fast`/`discovery-collapse` 经红绿 session、五通道、回归测试和锚点复审后 ack，未改阈值/算法/法典/锚点。
  最终 `alarms.py check`=`clean (1150)`，`gen_coverage.py --check`=`848 rows / 223 carried / 0 tombstones`。
  批次二十二由 **15/50→20/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线 EP-092 `POST /api/v1/controls/{id}:revert`。

## 2026-08-08 · EP-090 DELETE /api/v1/controls/{id} 五级收口，批次二十二 15/50

- 首轮真实 session `/private/tmp/anselm-rig-ep090-control-delete-20260808/sessions/20260808-152528` 发现
  产品红：Control/Approval 删除后的 REST `/relgraph` 已正确变成 4 relations，但真实 App 等待约 2.5s 仍显示
  8 entities/6 relations，保留已删除实体的 ghost nodes。问题冻结，不把列表刷新误当作关系图真相。
- stop-and-fix 在 `EntityRepository` 增加 workspace-wide durable `relationSignals()`；Live 只消费 durable
  notifications，ephemeral 不触发耐久快照；`relGraphProvider` 监听 relation pulse 与 lifecycle resync，并以
  300ms 合并删除与 `relation.dependency_broken`，避免中间拓扑闪现和重复 `/relgraph`。Fixture 与 3 项 provider
  守卫测试同步，Flutter 定向 15 项全通过。
- 固定真实 session `/private/tmp/anselm-rig-ep090-control-delete-fixed-20260808/sessions/20260808-153741` 由同一
  conductor 托管真实 App、Computer Use、98.700000s/2784x1808/60fps 录屏、frontend/backend journal、三路
  独立 SSE witness、managed gateway 和 LLM tap。创建后真实 App 从 6/4 收敛到 14/10；删除后收敛到 REST 的
  12/8，Control/Approval rail 消失、Parts 回到 0、剩余 workflow/trigger/function 保留。
- HTTP 对证：两类 delete=204，exact GET/重复 DELETE=404；版本历史保留；relations 清除被删实体边；capability-check
  明确报告悬空 control/approval 引用。notifications durable seq 1..8 严格连续；backend 195 行无应用红线，
  frontend 18 行无 Flutter runtime 红线，三流连接，rig-check/rig-down 干净。确定性 REST/UI 切片没有伪造 LLM
  completion，llmtap 只记录真实 ready/wiring。
- 红证据为 `.../EP-090-control-delete-red.md`，绿证据为
  `/private/tmp/anselm-rig-ep090-control-delete-fixed-20260808/sessions/20260808-153741/evidence/EP-090-control-delete-final-green.md`，
  独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-090-control-delete-ledger-reaudit.md`。
  `judge.py` 以 `G1/F2/A5/C4/G2` 将账本 `1140→1145`，`COVERAGE EP-090=✓✓✓✓✓`；anchors=10/10。集中写账的
  `gap-too-fast`/`discovery-collapse` 按复审记录 ack，未改阈值/算法/法典/锚点；alarms clean(1145)，清册
  `848 rows / 222 carried / 0 tombstones`。批次二十二由 10/50→15/50，未到 50 格不跑统一长门禁、不提交；
  下一前线 EP-091。

## 2026-08-08 · EP-089 PATCH /api/v1/controls/{id} 五级收口，批次二十二 10/50

- 固定真实 session `/private/tmp/anselm-rig-ep089-control-patch-fixed-20260808/sessions/20260808-151021` 由同一
  conductor 托管真实 Flutter App、Computer Use、401.523333s 窗口录制、frontend/backend journal、三路独立
  SSE witness、managed gateway 和 LLM tap。真实 onboarding 创建 workspace `ws_618e9cd917e1c055`，managed
  free-tier provision 成功，challenge/install/models 全 HTTP 200。
- 首轮红 session `/private/tmp/anselm-rig-ep089-control-patch-20260808/sessions/20260808-150028` 发现真实产品
  缺陷：Control `PATCH {}` 返回 200 仍刷新 `updatedAt` 并发 `control.updated` durable signal。stop-and-fix
  让 Control/Approval `UpdateMeta` 比较实际字段变化；空 patch/等值 patch 直接返回，不 Save、不刷新时间、不
  publish。红证据永久保留，API/domain 文档和两个 app 层 recording-notifier 回归测试同步。
- 固定版真实构造 Control `ctl_e5e6640b7767de8f` 与 Approval `apf_9e839c46b7ca8211`。Control 实际 patch 后
  App 详情准确显示新 name/description、v1、inputs、ordered branches；Control 空/等值 patch 与 Approval 空/
  等值 patch 均 HTTP 200 且 `updatedAt` 不变。SSE notifications durable `1..6` 严格为两类实体 created、实际
  updated、deleted；no-op 没有幽灵帧。负边界覆盖两类空名、未知字段、未知 ID、缺 workspace，分别得到预期
  422/400/404/401。
- cleanup Control/Approval 均 DELETE=204→GET=404，live lists=0，workspace 保留；真实 App 删除后 Overview 显示
  Control/Approval 无残留、Parts 0、关系图 0 entities/0 relations，空态文案完整。backend 511 行无应用红线，
  frontend 19 行无 Flutter runtime 红线，三路 SSE 无 gap，rig-check/rig-down 干净收台。证据为
  `evidence/EP-089-control-patch-final-green.md`，红证据为 `evidence/EP-089-control-patch-red.md`。
- `judge.py` 按 `G1/F2/A5/C4/G2` 将 central ledger `1135→1140 judgments`，`COVERAGE EP-089=✓✓✓✓✓`；
  anchors=10/10。`gap-too-fast`/`discovery-collapse` 在完整重读红绿 session、REST、SSE、backend/frontend/LLM、
  UI 和单测后 ack，未改阈值/算法/法典/锚点；`alarms.py check`=`clean (1140)`，`gen_coverage.py --check`=
  `848 rows / 221 carried / 0 tombstones`。批次二十二由 **5/50→10/50**，未到 50 格不跑统一长门禁、不提交；
  下一原子前线为 EP-090。

## 2026-08-08 · EP-088 GET /api/v1/controls/{id} 五级收口，批次二十二 5/50

- 真实 session `/private/tmp/anselm-rig-ep088-control-get-20260808/sessions/20260808-143506` 由同一
  conductor 托管真实 Flutter App、Computer Use、窗口录像、backend/frontend journal、三路独立 SSE witness、
  managed gateway 和 LLM tap。创建 v1→编辑 v2 的 Control 后，REST GET 返回内嵌 `activeVersion`；真实
  Entities 详情页显示名称/描述/id/v2/更新时间、3 个输入和 3 个有序分支，条件、port、emit 均可读。
- stop-and-fix：删除 fixture 后 Overview 空态只写 function/handler/agent/workflow，漏掉 rail 上的
  Control/Approval/Trigger。修复 English/简体中文 locale 为泛化的实体详情引导，重新生成 slang 产物，补
  空 repository widget regression；定向测试 3 项通过，热重载后真实空态再次逐帧核对。
- HTTP 矩阵：存在 GET=200（`activeVersion` v2）、未知 id=404 `CONTROL_NOT_FOUND`、缺 workspace=401
  `UNAUTH_NO_WORKSPACE`、DELETE=204、删除后 GET=404。第二次 Control 也完成同样 cleanup；workspace 保留。
  过度转义 CEL 的一次 422 和 shell 把 `${CID}:edit` 误写成 `/controls/dit` 的一次 404 是 harness 负证据，
  后端契约行为正确，不计产品红。
- 五通道：录屏 `722.733333s` / `2784×1808`，ffprobe 可读；SSE 三流均连接，Control durable seq 4/5/6
  为 created/edited/deleted 且无 gap；backend 无 panic/WARN/ERROR/FATAL，frontend 无 Flutter runtime 红线，
  managed challenge/install/models 全 200。证据为 session `evidence/EP-088-control-get-real-session.md`，
  详情帧与空态帧同目录保留。
- `judge.py` 以 `G1/F2/A5/C4/G2` 将账本 `1130→1135 judgments`，`COVERAGE EP-088=✓✓✓✓✓`；anchors
  `10/10`。`gap-too-fast`/`discovery-collapse` 经独立复审最终录屏、REST、SSE、backend/frontend/LLM 和
  修复证据后 ack，阈值/算法/法典/锚点未改，`alarms.py check`=`clean (1135)`；清册为
  `gen_coverage.py --check` 的预期 `848 rows / 220 carried / 0 tombstones`。
- 批次二十二由 **0/50→5/50**；尚未达到 50 格，不跑统一长门禁、不提交。下一原子前线为 EP-089。

## 2026-08-08 · EP-087 GET /api/v1/controls 五级收口，批次二十一 50/50

- 首轮真实 App + managed Anselm gateway + Computer Use + 五通道 session
  `/private/tmp/anselm-rig-ep087-controls-20260808/sessions/20260808-134141` 发现真实产品红：已有
  `EP087 Control 05` 不在首页时，输入 `05` 显示空态；同一请求的 REST `search=05` 也没有过滤，仍返首页
  与总数 55。红证据永久保留，问题不是“用户没翻页”的可接受副作用。
- stop-and-fix 同时修复 Control 与同类 Approval：handler 读取 `search`，domain filter 传递它，store 的
  list/count 使用大小写不敏感的 name 字面量子串条件，`X-Anselm-Total-Count` 与结果使用同一过滤条件；
  补充两类 store 回归，`%`/`_` 不作为 SQL wildcard。定向 Go tests 和 `git diff --check` 通过。
- fixed session `/private/tmp/anselm-rig-ep087-controls-20260808-fixed/sessions/20260808-135159` 由同一
  conductor 托管真实 Flutter App、Computer Use、录屏、frontend/backend journal、三路独立 SSE witness、
  managed gateway 和 LLM tap；录屏 `402.373333s`，创建 55 Control+3 Approval。API 矩阵覆盖分页无重叠、
  `search=05`、`search=no-such-control`、跨实体 `search=02`、字面量 `%`、非法/上限 `limit`；UI 逐帧覆盖
  命中、跨实体结果和明确空态。
- 五通道对证：SSE `116` 条 durable lifecycle frame（58 creates+58 deletes），三流均连接且无 gap；
  backend 无 WARN/ERROR/panic/FATAL，frontend 无未审 Flutter failure，managed gateway challenge/install/
  models 六条状态记录全 HTTP 200。清理 58 个 fixture 全部 DELETE=204→GET=404，两个列表回到
  `total=0, rows=0`，Parts 回到 0，workspace 保留，审计/通知事实保留。
- 正式证据为 session `evidence/EP-087-search-fixed.md`，独立账本复审为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-087-search-ledger-alarm-reaudit.md`；anchors=10/10。
  `judge.py` 以 `G1/F2/A5/C4/G2` 将账本 `1125→1130 judgments`，`COVERAGE EP-087=✓✓✓✓✓`；
  gap-too-fast/discovery-collapse 经独立复审 ack，未改阈值、算法、法典或锚点，`alarms.py check`=`clean (1130)`，
  `gen_coverage.py --check`=`848 rows / 219 carried / 0 tombstones`。
- 批次二十一由 `45/50→50/50`。随后完成 backend/frontend/docs/demo 子门禁、根 `make verify`、不带缓存的
  全量 Go 测试、完整 `make -C backend testend`（`269.878s`）和资源卫生审计；anchors=`10/10`、警报
  `clean (1130)`、清册 `848/219/0` 均保持。统一门禁全部通过，本批次可提交；下一原子前线为 EP-088。

## 2026-08-08 13:35 · EP-086 POST /api/v1/controls 五级收口，批次二十一 45/50

- 首轮真实 App + managed Anselm gateway + Computer Use + 五通道 session
  `/private/tmp/anselm-rig-ep086-control-20260808/sessions/20260808-132051` 发现真实产品红：未知
  input type `money` 被 201 接受并在实体详情渲染。红证据永久保留；没有把它降级成构造错误。
- stop-and-fix 在 `backend/internal/domain/control/control.go`、`internal/app/control/crud.go` 增加
  `CONTROL_INVALID_INPUTS` schema 校验，补 `control_test.go` 覆盖未知类型/重复字段名及 invalid edit 不
  铸版本，并同步 control domain/error-code 文档。修复后矩阵为：空名/空分支/缺 catchall/非法 CEL/未知
  类型/重复字段名=422，合法 control=201，重复名称=409。
- fixed session
  `/private/tmp/anselm-rig-ep086-control-20260808-fixed/sessions/20260808-132726` 由同一 conductor
  托管真实 App、录屏、frontend/backend journal、三路独立 SSE witness、managed gateway 和 LLM tap；
  录屏 `166.691667s`，rig-check/rig-down 通过，三路 durable SSE 无 gap，challenge/install/models 全 200，
  frontend/backend 无未解释应用红线。Control 详情逐帧显示 `amount: number`、`region: string`、
  三条路由分支、默认分支和 emit keys。
- SQLite/REST/UI/SSE 对证：合法 fixture cleanup 为 DELETE=204→GET=404，workspace GET=200，tombstone、
  v1 版本和 created/deleted notifications 保留，relations=0，实体列表和详情收敛为空态。
- 正式证据为 session `evidence/EP-086-control-real-session.md`，账本复审为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-086-control-ledger-reaudit.md`。anchors=10/10；
  `judge.py` 以 `G1/F2/A5/C4/G2` 将 `1120→1125 judgments`，`COVERAGE EP-086=✓✓✓✓✓`；警报复审
  后 `alarms.py check`=`clean (1125)`，`gen_coverage.py --check`=`848/218/0`。
- 批次二十一由 `40/50→45/50`；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-087
  `GET /api/v1/controls`。

## 2026-08-08 13:10 · EP-085 ANY webhook catch-all 五级收口，批次二十一 40/50

- 真实 App + managed Anselm gateway + Computer Use + 五通道 session
  `/private/tmp/anselm-rig-ep085-webhook-20260808-final/sessions/20260808-125703` 完成外部 webhook
 目的链：无 bearer 入站、HMAC/plain-secret 认证、Activation 审计、Firing 去重、workflow run、详情页
  Last fired/Activity/Dispatch 回声、path edit 和 cleanup。首轮发现打开 Overview 的 Last fired 不刷新，
  第二轮发现 plain-secret 详情缺少认证载体；两处均 stop-and-fix 后用最终 session 重跑，不计红为绿。
- 外部矩阵真实结果：wrong method=405、bad/missing/wrong auth=401、valid JSON/duplicate/different/text
  HMAC=202、plain header/query=202；path edit 后旧路径=404、新路径=202。重复 body 只增加 Activation，
  不重复 Firing/run。UI 显示 HMAC 算法/custom header/Listening/Last fired/Copy→Copied，以及
  X-Webhook-Secret header or ?token= query 的 plain-secret 说明且不渲染 secret。
- 五通道对证：screen.mov=539.071667s；rig-check/rig-down 通过；SSE notifications/entities/messages
  全连接，durable seq=1..10/1..12 无 gap；backend/frontend 无未解释应用红线；managed challenge/install/
  models 全 200，确定性 webhook slice 没有伪造 completion。SQLite 为 HMAC 5 Activation/4 Firing/4
  completed Flowrun、duplicate dedup group=0；plain-secret 2 Activation/1 Firing。
- 证据为 session evidence/EP-085-webhook-real-session.md，独立复审为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-085-webhook-ledger-reaudit.md`。全部 fixture
  DELETE=204→GET=404，三类 live 列表为空，workspace 保留；session/journal/录屏/抽帧全保留。
- `judge.py` 以 `G1/F2/A5/C4/G2` 将中央账本 `1115→1120 judgments`，`COVERAGE EP-085=✓✓✓✓✓`；
  集中写账的 gap-too-fast/discovery-collapse 按复审证据 ack，阈值/算法/法典/锚点未改，
  `alarms.py check`=`clean (1120)`。批次二十一由 `35/50→40/50`，未到 50 格不跑统一长门禁、不提交；
  下一原子前线为 EP-086 `POST /api/v1/controls`。

## 2026-08-08 12:38 · EP-084 GET /api/v1/trigger-schedule 五级收口，批次二十一 35/50

- 真实 App + managed Anselm gateway + Computer Use + 五通道 session
  `/private/tmp/anselm-rig-ep084-schedule-20260808-retry/sessions/20260808-122252` 完成 Scheduler
  Overview 前瞻时间线：dense/sparse cron、paused、unreferenced、webhook no-forecast、cap/truncated、
  cell launch、hover overflow 和 cleanup convergence 全部走通。setup-only 旧 wiring session 被 rig-check
  正确拒绝并保留，不计产品红。
- 真实 dense cron 产生 9 条 `fire → run_started → run → run_terminal(completed)`，Overview 绿色格、
  next-fire KPI、Paused 语义、honest truncation、hover card 与最终 `No automation yet` 均由 REST/SQLite/
  SSE/UI 五通道对证。录屏 `667.105000s`；SSE 73 条，entities durable `1..20`、notifications durable `1..27`；
  frontend/backend 无应用红线，managed gateway challenge/install/models 全 200，已知 Flutter runner warning
  单独归类为仪器噪声。
- 10 个临时 fixture 精确清理：每个 DELETE=`204`、后续 GET=`404`，workspace GET=`200`，session/journal/录屏保留。
  定向 Go 黑盒 2 项、Scheduler KPI/Overview Flutter 回归 65 项通过。
- 正式证据 `.../evidence/EP-084-schedule-real-session.md`，ledger re-audit
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-084-trigger-schedule-ledger-reaudit.md`。anchors=`10/10`；
  `judge.py` 以 `G1/F2/A5/C4/G2` 将中央账本 `1110→1115 judgments`，`COVERAGE EP-084=✓✓✓✓✓`；集中写账
  打开 `gap-too-fast`/`discovery-collapse`，独立复审后 ack，阈值/算法/法典/锚点未改，`alarms.py check`=`clean (1115)`，
  `gen_coverage.py --check`=`848 rows / 216 carried / 0 tombstones`。
- 批次二十一由 `30/50→35/50`；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-085
  `ANY /api/v1/webhooks/{triggerId}/{path...}`。

## 2026-08-08 12:19 · EP-083 GET /api/v1/triggers/{id}/firings 五级收口，批次二十一 30/50

- 首轮真实 Dispatch 走查冻结两个产品问题：`missed` 不在筛选菜单，折叠行泄露 `wf_...` workflow 实现 ID；
  stop-and-fix 后后端通过 `NamesByIDs` 批量补只读 `workflowName`，前端折叠行显示人类名称，展开详情
  保留准确 `Workflow ID`，筛选菜单加入 `missed` 并排除 transient `claimed`。
- post-fix session `/private/tmp/anselm-rig-ep083-dispatch-postfix-20260808/sessions/20260808-120703`
  由 conductor 托管真实 Flutter App、Computer Use、录屏、frontend/backend journal、三路 SSE witness、
  managed gateway 和 LLM tap；录屏 `208.211667s / 2784x1808`，`rig-check`/封口/`rig-down` 通过，
  owned process/listener 全部收台。REST 两条 missed firing 的 `workflowName` 一致且无 flowrun，五通道和
  视觉证据均与修复后 UI 对齐；前置 raw-ID 红证据保留。
- 正式证据 `.../evidence/EP-083-dispatch-postfix.md`，账本复审
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-083-dispatch-ledger-reaudit.md`。workflow、
  function、trigger 三个临时 fixture 均 `DELETE=204→GET=404`，session/journal/录屏保留，seeded 数据和
  workspace 未动。Go handler、Flutter trigger tests（13 项）、`flutter analyze`、`git diff --check` 通过。
- `judge.py` 以 `G1/F2/A5/C4/G2` 将中央账本 `1105→1110 judgments`，`COVERAGE EP-083=✓✓✓✓✓`，
  anchors=`10/10`。集中写账打开 `gap-too-fast`/`discovery-collapse`，复审证据已逐项 ack，
  `alarms.py check`=`clean (1110)`，阈值/算法/法典/锚点未改；`gen_coverage.py --check` 为
  `848/215/0`。
- 批次二十一由 `25/50→30/50`；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-084
  `GET /api/v1/trigger-schedule`。

## 2026-08-08 11:34 · EP-082 GET /api/v1/firings 五级收口，批次二十一 25/50

- 受控真实恢复 session `/private/tmp/anselm-rig-ep082-real-recover-20260808/sessions/20260808-112631`
  由同一 conductor 托管 App、Computer Use、录屏、backend/frontend journal、三路 SSE witness、managed
  gateway 和 LLM tap；精确 SIGKILL 跨过三个 cron 刻度，恢复真实记账 `missed=3`，录屏
  `300.341667s / 2784x1808 / 60fps`，`rig-check`/`rig-down` 通过。
- REST/SQLite/SSE/UI 对证：11:24/11:25/11:26 三条 firing 为 `missed` 且无 activation/flowrun；11:27–11:29
  恢复后各自 `fire → run_started → run_terminal(completed)`；global/nested pagination、path precedence、
  inclusive/exclusive time bounds、invalid status/time 全绿。Scheduler 多个稳定帧显示 `Missed · 24h = 3`、
  灰色缺口和截断说明；cleanup 为 `204→404` 且搜索无 fixture，session/journal/录屏保留。
- 初次无效时序红作为 setup evidence 保留并排除；无产品代码修复。正式证据
  `EP-082-firings-real-recovery.md`，独立账本复审 `EP-082-firings-ledger-reaudit.md`；官方 focused misfire
  场景、ffprobe、diff check 通过。`judge.py` `G1/F2/A5/C4/G2` 使账本 `1100→1105`，`COVERAGE EP-082=✓✓✓✓✓`，
  anchors=`10/10`；集中写账 `gap-too-fast`/`discovery-collapse` 按复审 ack，`alarms.py check`=`clean (1105)`，
  `gen_coverage.py --check`=`848/214/0`，阈值/算法/法典/锚点未改。
- 批次二十一由 `20/50→25/50`；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-083
  `GET /api/v1/triggers/{id}/firings`。

## 2026-08-08 10:57 · EP-081 v8 GET /api/v1/trigger-activations/{id} 复验收收口，批次二十一 20/50

- v7 的真实红证据不是只修最终文本：SSE reasoning delta/close 曾暴露 `the recorded time`，并在列表式输出中出现空 `triggerId`。stop-and-fix 将 `triggerId` camelCase、中文别名和 `createdAt` 纳入整行保持/替换规则，新增流式 delta、最终 reasoning block、中文 Field/Value 表回归。
- v8 session `/private/tmp/anselm-rig-ep081-fixed-v8-20260808/sessions/20260808-105255` 使用真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路独立 SSE witness、真实 managed gateway 和 LLM tap；录屏 `72.693333s / 2784x1808`。五通道均无应用级红线，SSE messages/entities/notifications=`44/1/5`，产品可见 delta/close 无两个英文占位词，LLM 的单次 `get_activation` 参数准确。
- v8 trigger=`trg_08cf1efcf08b2f50`、activation=`tra_f20f3bce4269cfe6`、conversation=`cv_59605e07a942a124`；清理真实 DELETE=`204×2`、后续 GET=`404×2`，session/journal/录屏保留。v4/v5/v6/v7 红 session 和修复链不覆盖。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-081-trigger-activation-green-v8.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-081-trigger-activation-ledger-reaudit-v8.md`。anchors `10/10`；`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1095→1100 judgments`，`COVERAGE EP-081=✓✓✓✓✓`，两条集中写账警报按复审 ack，`alarms.py check`=`clean (1100)`，`gen_coverage.py --check`=`848/213/0`。
- 批次二十一由 **15/50→20/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-082 `GET /api/v1/firings`。

## 2026-08-08 09:58 · EP-081 GET /api/v1/trigger-activations/{id} 五级收口，批次二十一 15/50

- 产品目的：用户在真实 Chat 中要求查看一条具体 activation；模型只调用一次 `get_activation` 并逐字
  使用 `activationId`，正文中的不透明 ID/时间诚实指向相邻 activation 卡片，展开 dossier 后能复制
  Activation ID、Trigger ID、Created at 精确值，同时读到 kind、fired、payload、firingCount 和 detail。
  首轮空参数/假占位词被真实 App 逐帧判红，修复后没有失败重试卡或伪字段。
- 正式旧红证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-081-trigger-activation-red.md`；
  修复同步 `get_activation` description/schema、activation 表脱敏及跨 provider chunk 守卫、Flutter
  dossier 可复制真相字段、中英文 i18n、trigger reference/tool extract。代码没有取消全局 opaque-value
  边界，而是把精确值收敛到相邻结构化卡片。
- 正式绿 session `/private/tmp/anselm-rig-ep081-fixed-20260808/sessions/20260808-095310` 由同一
  conductor 托管真实 Flutter App、Computer Use、窗口录屏、backend/frontend journal、三路独立 SSE
  witness、真实 managed gateway 和 LLM tap；录屏 `126.495s / 2784x1808 / 60fps`，`rig-check`、
  封口、`rig-down`、owned process/listener 收台全通过。
- 五通道 journal：ssetap=`122` 帧，messages/entities/notifications 三流各连接一次；messages durable
  seq=`1..14`，notifications durable seq=`16..19`，entities fire signal 含同一 activationId；LLM
  wire 的 tool call 为 `{"activationId":"tra_ce29943da240d8c2"}`，tool_result 与 REST 均保留完整
  `triggerId=trg_0cd4d02ed97da065`、`createdAt=2026-08-08T01:54:24.33765Z`。backend/frontend 无
  应用级 WARN/ERROR/panic 或 Flutter/Dart/RenderFlex/Unhandled/assertion 红线。
- 删除后留存：DELETE trigger=`204`，trigger GET=`404 TRIGGER_NOT_FOUND`，list 缺席；原 activation
  GET=`200` 且完整返回，未知 activation=`404 TRIGGER_ACTIVATION_NOT_FOUND`。
- 正式绿/独立复审证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-081-trigger-activation-{green,ledger-reaudit}.md`；
  anchors=`10/10`；`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1090→1095 judgments`，`COVERAGE EP-081=✓✓✓✓✓`。
  两条集中写账警报按 re-audit ack，`alarms.py check`=`clean (1095)`，`gen_coverage.py --check`=`848/213/0`；
  阈值、算法、法典和锚点未改。批次由 `10/50→15/50`，未到第 50 格不跑统一长门禁、不提交；下一前线为 EP-082 `GET /api/v1/firings`。

## 2026-08-08 09:22 · EP-080 GET /api/v1/triggers/{id}/activations 五级收口，批次二十一 10/50

- 产品目的：用户在真实 Trigger Activity 中能理解 fired 与 non-fired 都会留下审计记录，能展开
  return value/payload/detail/fan-out，使用 `Fired only`、`All activity` 和 `Load more`，并在
  没有任何活动的 Trigger 上看到明确 empty state。真实 App 路径逐帧稳定，无裁切、跳变、死 spinner、
  stale filter 或 phantom row。
- 正式 session `/private/tmp/anselm-rig-ep080-trigger-activations-20260808/sessions/20260808-091208`
  由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路
  独立 SSE witness、真实 managed gateway 和 LLM tap；录屏 `552.811667s / 2784x1808`，
  `rig-check`/`rig-down`/ffprobe 全通过，owned process/listener 归零。
- REST/SQLite/SSE/UI 对证：sensor trigger=`trg_2bb2bcfa0b2cfd40`、workflow=`wf_04912a30c0738c8f`；
  SQLite=`83 activations (75 fired + 8 non-fired)`, `74 completed flowruns`, cleanup 时一条 pending
  firing 明确为 `shed`。3-row cursor、`firedOnly` continuation、坏 cursor=`400 MALFORMED_CURSOR`、
  无活动 cron empty state 均真实取证；missing-parent 的空列表边界也保留，不擅自改 API 契约。
- 五通道 journal：ssetap=`323` 帧，messages/entities/notifications 三流均连接，entities=`305` 帧/`148`
  durable seq=`7..154` 单调，notifications=`9` durable seq=`16..24` 单调；backend/frontend 无应用级
  WARN/ERROR/panic/FATAL 或 Flutter/Dart/RenderFlex/Unhandled/assertion 红线；deterministic graph 无
  模型 completion，LLM ready/proof/install/models 全 HTTP 200。后端 fixture setup 的错误方法探针已写入
  red record，未冒充产品问题。
- 正式红/绿/独立复审证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-080-trigger-activations-{red,green,ledger-reaudit}.md`。
  anchors=`10/10`；`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1085→1090 judgments`，`COVERAGE EP-080=✓✓✓✓✓`；
  两条集中写账警报按独立复审 ack，`alarms.py check`=`clean (1090)`，`gen_coverage.py --check`=`848/212/0`，
  阈值、算法、法典和锚点未改。
- 批次二十一由 `5/50→10/50`；未达到第 50 格，不跑统一长门禁、不提交。下一前线为 EP-081
  `GET /api/v1/trigger-activations/{id}`；EP-079 修复和本轮文档随批次统一提交。

## 2026-08-08 09:07 · EP-079 POST /api/v1/triggers/{id}:iterate 五级收口，批次二十一 5/50

- 产品目的：用户从真实 Trigger rail 的行级 More actions 找到 `Edit with AI`，进入带实体快照的
  Chat，提出具体描述变更；匹配的 `edit_trigger` 只改目标字段，重新启动 App 后 detail 读到新
  数据，name、cron、outputs 保持不变。重复工具调用显示 duplicate suppression，未发生第二次执行。
- 正式主 session `/private/tmp/anselm-rig-ep079-trigger-iterate-20260808/sessions/20260808-084829`
  使用同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、
  三路独立 SSE witness、真实 managed gateway 和 LLM tap；录屏 `556.521667s` 可由 ffprobe 读取，
  `rig-check`、封口和 `rig-down` 通过，owned process/listener 归零。重启补证 session
  `/private/tmp/anselm-rig-ep079-trigger-iterate-20260808/sessions/20260808-085846` 因 recorder
  SIGKILL 无 `screen.mov`，明确排除出 L2，只用于 fresh-process 数据真相与 composer clean 观察。
- REST/SQLite/SSE/UI/LLM 对证：trigger=`trg_8c4ac7993daee63d` 的 description 更新，name、
  `config.expression=0 0 1 1 *`、`firedAt` output 未变；空 request=`400 EMPTY_ITERATE_REQUEST`，
  缺失 target=`404 TRIGGER_NOT_FOUND`，均无 phantom conversation。ssetap=`255` 帧/`34` durable，
  durable seq 单调；LLM tap 的 managed gateway 响应全 HTTP 200；backend/frontend 无应用级红线。
- 首轮 Computer Use 输入注入出现字符/草稿异常，已通过重启清除并在证据中明确归类为 harness
  输入问题，不将其冒充产品红；产品路径和公开 message API 的实际 chat loop 仍完整取证。EP-079
  的 generic edit steer 修复补齐 trigger/control/approval 并同步测试与 support-services 文档，
  留在当前工作树，待批次第 50 格统一提交。
- 正式红/绿/独立复审证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-079-trigger-iterate-{red,green,ledger-reaudit}.md`。
  anchors=`10/10`；`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1080→1085 judgments`，
  `COVERAGE EP-079=✓✓✓✓✓`；两条集中写账警报按独立复审 ack，`alarms.py check`=`clean (1085)`，
  `gen_coverage.py --check`=`848 rows / 211 carried / 0 tombstones`，阈值、算法、法典和锚点未改。
- 批次二十一由 `0/50→5/50`；未达到第 50 格，不跑统一长门禁、不提交。下一前线为 EP-080
  `GET /api/v1/triggers/{id}/activations`。

## 2026-08-08 08:23 · 批次二十统一长门禁、完整黑盒与资源卫生收口，下一批从 EP-079 开始

- 统一门禁全部通过：根 `make verify` 的 backend/frontend/docs/demo 全绿；`mise exec -- go test ./...` 全模块通过；正确入口 `make -C backend testend` 的完整 `testend/scenarios` 通过，`312.251s`，未启用真实 eval/provider secret，不消耗 managed gateway 配额。
- 收台审计通过：testend 的 anselm-server、llama-server、sandbox 和 rig 进程均已退出，8777/8802/8742 无残留 listener；`git diff --check` 通过，锚点 10/10 且 hash 绑定，`alarms.py check`=`clean (1080)`，`gen_coverage.py --check`=`848 rows / 210 carried / 0 tombstones`。
- 批次二十累计 `52/50`（EP-067 至 EP-078 的五级格子及批次边界外的当前状态同步），已完成统一门禁和工作树审计；本次状态同步后创建批次提交。下一批为批次二十一，当前 `0/50`，下一原子前线 EP-079 `POST /api/v1/triggers/{id}:iterate`。

## 2026-08-08 08:09 · EP-078 POST /api/v1/triggers/{id}:resume 五级收口，批次二十 52/50，统一门禁进行中

- 产品目的：用户从同一 Trigger 详情暂停后，能从同一处恢复当前 config 的真实 source listener；UI 回到 `Listening / Listening: Yes`，workflow 引用保持，真实 source 必须再次产生 activation→firing→completed flowrun；Register 失败必须保持可重试暂停态。
- 正式 session `/private/tmp/anselm-rig-ep078-resume-20260808/sessions/20260808-080107` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录像、frontend/backend journal、三路独立 SSE witness、LLM tap 和 managed gateway；录屏 `98.143333s / 2784x1808 / 60fps`，`rig-check`/封口/`rig-down` 通过，无 owned process/listener 残留。
- Computer Use 真实路径为 Trigger detail → More actions → Pause → Resume；关键帧 `evidence/trigger-paused.png` / `trigger-resumed.png`。暂停后 REST/UI 为 `paused=true/listening=false`，恢复后为 `paused=false/listening=true/refCount=1`，同页状态和菜单收敛。
- REST/SQLite/SSE 对证：恢复后的真实 sensor 链为 `tra_91cb77260bc974a7 → trf_26e35d9eac90a5ec → fr_bc99453575eb1cc0`，flowrun `origin=sensor,status=completed`；entities durable `seq=1..4` 单调，三流均连接，status true/false、fire、run_started、run_terminal 均有 witness。LLM ready-only 符合 deterministic workflow，不伪造 completion。
- 失败边界由 `TestResume_RegisterFailureRollsBackAndStaysRetryable` 锁定：Register 失败上抛、持久化 paused=true、report gate 关闭，source 恢复后 retry 才重新 live。backend/frontend/LLM=`170/33/1`，frontend AXTree observer 行已复核为工具噪声，无应用级红线。
- Go 四包定向回归和 Flutter 四组定向回归全绿；正式红/绿/独立复审证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-078-trigger-resume-{red,green,ledger-reaudit}.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1075→1080 judgments`，COVERAGE `EP-078=✓✓✓✓✓`，`alarms.py check`=`clean (1080)`，`gen_coverage.py --check`=`848/210/0`，anchors `10/10`。
- 批次二十由 **47/50→52/50**；已触发约定的统一长门禁、完整 testend、工作树审计和提交，门禁结束前不推进下一原子前线、不提交半成品。

## 2026-08-08 07:56 · EP-077 POST /api/v1/triggers/{id}:pause 五级收口，批次二十 47/50

- 产品目的：用户从真实 Trigger rail 的 More actions 点击 Pause 后，源头 listener 必须停止但 workflow 引用保留；详情要显示 `Paused / Listening: No`，Fire 不能绕过暂停；Resume 从同一处恢复当前 config 的 listener，并让真实 source 再次产生事件。
- 正式 session `/private/tmp/anselm-rig-ep077-pause-20260808/sessions/20260808-074937` 由 conductor 托管真实 Flutter App、Computer Use、窗口录像、frontend/backend journal、三路独立 SSE witness、LLM tap 和 managed gateway；录屏 `207.725000s / 2784x1808 / 60fps`，`rig-check`、封口和 `rig-down` 通过，无 owned process/listener 残留。
- Computer Use 真实路径为 rail→More actions→Pause→详情；暂停态关键帧 `evidence/trigger-paused-final.png` 显示 `Paused`、`Listening: No`、`Listeners: 1` 和 inert Fire；Resume 关键帧 `evidence/trigger-resumed-final.png` 回到 `Listening / Yes`。rail 同槽位从 Pause 切为 Resume，没有跳页或旧状态残留。
- REST/SQLite/SSE 对证：暂停 `paused=true/listening=false/refCount=1`，`:fire=422 TRIGGER_PAUSED` 且 activation/firing/flowrun 数不变；Resume 后 sensor 新建 `tra_217e69d5737b4a0c → trf_e1ce88be0f712109 → fr_6aeac3da976cacbb`，flowrun `completed`。entities SSE 记录 status true/false、fire、run_started(seq=3)、run_terminal(seq=4)，三流均连接。
- 健康：backend/frontend/LLM=`254/32/1`；backend 无应用 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/RenderFlex/Unhandled/assertion 红线，AXTree churn 由 session review 明确归类为 Computer Use 观察器噪声；deterministic workflow 只有 LLM ready。工具误操作（zsh `path` 覆盖 PATH、`$ID:resume` 未加花括号、首次 rig-check 缺 AX review）均重跑并保留审计，不计产品红。
- 正式红/绿/独立复审分别为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-077-trigger-pause-{red,green,ledger-reaudit}.md`；`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1070→1075 judgments`，`COVERAGE EP-077=✓✓✓✓✓`。两条集中写账警报已独立复审并 ack，`alarms.py check`=`clean (1075)`，anchors `10/10`，阈值、算法、法典和锚点未改；`gen_coverage.py --check`=`848/209/0`。
- 定向 `go test`、Flutter trigger/provider tests、Dart analyze、录像封口、收台和 `git diff --check` 通过。批次二十由 **42/50→47/50**；未到 50 格不跑统一长门禁、不提交，下一前线 EP-078 `POST /api/v1/triggers/{id}:resume`。

## 2026-08-08 07:10 · EP-075 DELETE /api/v1/triggers/{id} 五级收口，批次二十 41/50

- 产品红：真实 Trigger detail 的 generic Delete 确认只说移出 active catalog，没有解释 `Listening: Yes / Listeners: 1`，也没有说明 `ep072fix-listening-workflow` 会留下悬空引用；红帧 `/private/tmp/anselm-rig-ep075-delete-20260808/sessions/20260808-065336/frames/ep075-delete-confirm-red.png` 永久保留，不计绿。
- stop-and-fix：`EntityRail` 对 trigger 删除前 fresh 读取已有 `GET /api/v1/relgraph`，列出入向 `equip/link` 使用者，listener 热时说明会停止监听，关系快照失败则 fail-closed；补中英文 i18n、实体 rail widget regression，并同步 frontend entities/backend events 文档。
- 绿 session `/private/tmp/anselm-rig-ep075-delete-20260808/sessions/20260808-070205`：真实 App/Computer Use 从 rail→detail→More actions→Delete→专用确认→Delete；确认框列出 workflow、停止 listener、repair 后果；删除后回 Overview，Trigger `24→23`、Parts `24→23`、关系图 `10→8`，通知托盘显示 deleted 与 dangling dependency。
- 五通道：录屏 `308.340000s / 2784x1808 / 60fps`；backend 无应用 WARN/ERROR/panic/FATAL；frontend 只有 2 条固定 AXTree observer churn，`evidence/frontend-ax-review.md` 标记 `tooling-ax-tree/reviewed`，静置 10 秒不增长且无 Dart/FlutterError/RenderFlex/overflow/Unhandled/lost-device；ssetap 三流均连接，rig-check/rig-down 通过且 owned process groups 归零；llmtap 为 gateway ready-only。
- REST/SQLite/SSE 对证：DELETE `204`，exact GET `404 TRIGGER_NOT_FOUND`，list `23` 且 deleted id 缺席；tombstone、5 activation、5 firing 保留，删除后新增 activation/firing 为 0；relgraph 无该 trigger 边；capability-check 诚实报告缺失 trigger；notifications durable `trigger.deleted`、`relation.dependency_broken`，entities/notifications seq 分别 `1..2/1..2` 单调。
- 证据：正式红绿与独立复审分别为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-075-trigger-delete-{red,green,ledger-reaudit}.md`；关键帧在 green session frames。锚点 `10/10`；`judge.py` `G1/F2/A5/C4/G2` 将账本 `1060→1065`，COVERAGE `EP-075=✓✓✓✓✓`；两条统计警报按独立复审 ack，`alarms.py check` clean(1065)，`gen_coverage.py --check`=`848/207/0`。
- 验证：Dart analyze、实体 rail `30` 项 Flutter 测试、trigger/relation/http handler Go 测试、`git diff --check` 通过；未到第 50 格，不跑统一长门禁、不提交。下一前线 EP-076 `POST /api/v1/triggers/{id}:fire`。

## 2026-08-08 06:40 · EP-074 PATCH /api/v1/triggers/{id} 五级收口，处理 fixture 红线，批次二十 40/50

- 产品目的：用户用 `Edit with AI` 修改 trigger 后，名称、描述和 source config 在同一打开的 rail/detail 中即时可见；热 listener 不因编辑丢失，下一次触发时间随 cron 重算；暂停状态不被编辑误启动，Resume/Pause 的真实状态无需刷新即可理解。
- 首轮代码红是 trigger CRUD 只刷新搜索索引、不发 `trigger.created/edited/deleted` durable notification，导致 AI 编辑成功而已打开的 rail/detail 留在旧投影。stop-and-fix 为 Service 接入 notification emitter 并统一 `publish`；pause/resume 保持 scoped ephemeral `status`，不污染通知中心。新增 Go CRUD notification 测试、detail scoped-status re-fetch 回归，并同步 backend events/trigger 文档。
- 正式 session `/private/tmp/anselm-rig-ep074-trigger-edit-20260808/sessions/20260808-062838` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、真实 managed gateway 和 LLM tap；录屏 `562.808333s / 2784x1808 / 60fps`，`rig-check`/`rig-down` 通过且 owned process/listener 归零。真实路径为 AI edit `ep072fix-cron-8→ep074-edit-final`、`*/20`，Resume=`Listening: Yes / Next fire: 06:40`，热改 `*/30` 后仍在线且 next-fire=`07:00`，恢复 `*/20` 后 Pause=`Listening: No / Next fire: —`。
- 台架还捕获了 `ep072fix-sensor-4` 错把需要 `name` 的 `greet` function 作为无参 sensor probe 的真实 TypeError。按用户许可删除坏 trigger，使用无参 `sync_inventory` 重建 probe，并把 active workflow action 显式接到 `start.name`；capability-check=`structurallyValid=true,resolved=true`，修复后 sensor fire 与 workflow run 均 completed，后续没有新的错误帧。早期红证据保留，不改写为绿。
- 五通道对证：backend 无修复后应用 WARN/ERROR/panic/FATAL；SSE messages/entities/notifications durable seq=`1..49/3..6/1..9` 且单调，含 trigger lifecycle 与 workflow terminal；LLM wire 的 `edit_trigger` config、REST/SQLite/UI 同值；frontend/Terminal 只有已审阅 runner 启动提示，无 Dart/Flutter/RenderFlex/overflow/Unhandled 红线。正式红绿证据位于同 session `evidence/`，独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-074-trigger-edit-ledger-reaudit.md`。
- anchors=`10/10`；`judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，中央账本 `1055→1060 judgments`，`COVERAGE EP-074=✓✓✓✓✓`。集中写账产生的 `gap-too-fast`/`discovery-collapse` 已依据独立复审逐条 ack；未改阈值、算法、法典或锚点，最终 `alarms.py check`=`clean (1060)`，`gen_coverage.py --check`=`848 rows / 206 carried / 0 tombstones`。未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-075 `DELETE /api/v1/triggers/{id}`。

## 2026-08-08 04:26 · EP-069 GET /api/v1/flowrun-matrix 五级收口，修复删除后 scheduler stale row，批次二十 15/50

- 产品目的：用户在 Scheduler 的矩阵中能同时理解 completed、failed、running/awaiting-approval 和 sparse/not-reached；红格能打开精确失败 dossier，等待列能打开 Gantt/approval，Failed/Waiting/All 筛选不与矩阵脱节。真实 App 逐帧没有裁切、溢出、跳变、死 spinner 或错误 CTA。
- 固定正式 session `/private/tmp/anselm-rig-ep069-flowrun-matrix-fixed-20260808/sessions/20260808-041832` 使用真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和 managed gateway；录屏 `293.975000s`，最终 backend/frontend/SSE/LLM=`402/18/18/1`，`rig-check`/`rig-down` 通过且 owned process/listener 归零。
- REST/SQLite/SSE/UI 对证：矩阵列顺序 newest-first；known/ghost、all-ghost、重复 ID、blank-only `400 INVALID_REQUEST`、51-ID `422 FLOWRUN_MATRIX_TOO_MANY_IDS`、running 无 elapsed、terminal 有 elapsed 均真实取证，node rows 与 UI 状态一致。三路 SSE 均连接，deterministic graph 没有 LLM 节点，LLM tap 只有 readiness 不伪造 completion。
- 首轮真实清理暴露真实产品缺陷：REST 已空且 notifications 已发 durable `workflow.deleted`，scheduler rail 仍显示已删 workflow。stop-and-fix 在 `scheduler_rail_provider` 增加 durable lifecycle notification refetch 和 300ms debounce，补 `scheduler_rail_provider_test.dart`；固定 session 清理后 UI 真实收敛到 `No automation yet`。函数签名不匹配只保留为 fixture setup failure evidence，没有误判为产品红。
- 正式证据 `/private/tmp/anselm-rig-ep069-flowrun-matrix-fixed-20260808/sessions/20260808-041832/evidence/EP-069-flowrun-matrix-real-session.md`，ledger re-audit `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-069-flowrun-matrix-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 写入，账本 `1030→1035 judgments`，COVERAGE `EP-069=✓✓✓✓✓`，anchors `10/10`；集中写账触发的 `gap-too-fast`/`discovery-collapse` 按独立复审 ack，`alarms.py check` clean(1035)，阈值/算法/法典/锚点未改。
- 后端 scheduler/store 测试、`TestFlowrunMatrix_Grid`、matrix/home 与 rail provider Flutter 定向测试均通过。按授权清理临时 fixture，live entities 为空，tombstone/version/run/node 审计保留，seeded entities 未动。批次二十由 **10/50→15/50**；未到 50 格不跑统一长门禁、不提交，下一前线为 EP-070 `POST /api/v1/flowruns/{id}/approvals/{node}:decide`。

## 2026-08-08 04:02 · EP-068 GET /api/v1/flowrun-stats 五级收口，批次二十 10/50

EP-068 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。主 session `/private/tmp/anselm-rig-ep068-flowrun-stats-fixed-20260808/sessions/20260808-035335` 由 conductor 托管 Flutter、窗口录制、backend/frontend journal、三路 SSE witness 和 LLM tap，录屏 `214.181667s / 2784x1808 / 60fps`。Scheduler Overview 真实显示 `Running 1`、`Waiting 1`、`Failed · 24h 2`、`Next fire in <1m`；真实 cron 停机跨刻度重启后显示 `Missed · 24h 2`，lane 无障碍描述同步为 `2 missed`；workflow 详情显示真实 cron runs、matrix、`Success 100% · avg 38–39ms`。

REST 真实覆盖 workspace totals、byWorkflow 请求顺序与 ghost、future/倒挂半开窗、recentN clamp、重复/空 ID、51-ID cap、坏 since/until，以及真实 missed vs started：最终 stats 为 `running=1/completedSince=6/failedSince=2/parkedNodes=1/missed=2`；SQLite `trigger_firings` 为 `2 missed + 3 started`，missed 无 flowrun_id，四条手工 run 的 approval/health/failure 状态与 node 审计一致。backend `356` 行、frontend `18` 行、SSE `29` 行、LLM `1` 行，三流均连接，无应用级 panic/FATAL/WARN/ERROR、Flutter/Dart/RenderFlex/Unhandled/assertion 红线；deterministic graph 无 completion 请求是正确边界。

本格没有产品源代码修复；targeted scheduler unit、`TestFlowrunStats_BatchProjection`、`TestTrigger_MisfireMissedAccounting` 通过。先将 parked run `fr_ff847dc5b94e0737` 决策为 `no`，再按用户授权删除 3 workflow、1 approval、1 trigger、1 function，全部 `204→404`；live lists 为空，tombstone/version/run/node/firing 审计和 seeded entities 保留。清理脚本首次因 zsh 变量名 `path` 覆盖 `PATH` 未执行删除，改为 `endpoint` 后幂等重跑成功；属于台架命令错误，不计产品红。

正式证据 `/private/tmp/anselm-rig-ep068-flowrun-stats-fixed-20260808/sessions/20260808-035335/evidence/EP-068-flowrun-stats-real-session.md`，ledger 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-068-flowrun-stats-ledger-reaudit.md`。账本 `1025→1030 judgments` 按 `G1/F2/A5/C4/G2` 写入，COVERAGE `EP-068=✓✓✓✓✓`，anchors `10/10`；集中写账打开 `gap-too-fast` 与 `discovery-collapse`，独立复审后 ack，`alarms.py check` clean(1030)，阈值/算法/法典/锚点未改。批次二十当前 **10/50**，未到 50 格不跑统一长门禁、不提交；下一前线 EP-069 `GET /api/v1/flowrun-matrix`。

## 2026-08-08 03:42 · EP-067 GET /api/v1/flowrun-inbox 五级收口，批次二十 5/50

- 产品目的：用户在 Scheduler 和通知托盘都能找到所有 parked approval，并在做决定前理解流程上下文、节点、问题和期限；Approve、带理由 Reject、非法请求和重复决策都必须与后端真相一致，收口后不得留下死卡。
- 正式 session `/private/tmp/anselm-rig-ep067-flowrun-inbox-20260808/sessions/20260808-033401` 使用真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路 SSE witness、LLM tap 和真实 managed gateway wiring；录屏 `205.191667s / 2784x1808 / 60fps`，窗口 `26563`。Scheduler → Waiting on you → Approve、Notifications → Needs you → + Reason → Reject、最终两个空态均真实走通。
- 首轮实机观察捕获 approval capsule 的真实 `RenderFlex overflowed by 18 pixels`，冻结并 stop-and-fix：异步问题高度重新测量，内容用 `OverflowBox` 防止动画中间态把可见文案挤出；补 `an_approval_capsule_test.dart` 回归，最终 session `frontend.log` 无 Flutter/Dart/RenderFlex/Unhandled/assertion 红线。另修复 `FlowrunNode` 的 inbox workflow/deadline enrich 解码，并让共享 `ApprovalGate` 显示流程名、`Awaiting approval`、倒计时和节点名；生成代码同步。
- 真实 run `fr_30b3f4d1e090ee0d` Approve 后 REST/SQLite=`completed, decision=yes`；`fr_68dae31075077ccd` 托盘带理由 Reject 后=`completed, decision=no, reason=需要业务方再确认`；`fr_86ea343f844bfb69` 的 `maybe`=`422 FLOWRUN_INVALID_DECISION`、未知字段=`400 INVALID_REQUEST`，两次拒绝不消费 parked 行，随后正常决策；重复决策=`422`。最终 inbox=`{parked:[]}`，三条 run 各一个 `run_terminal(completed)`。
- 五通道：backend/frontend/SSE/LLM=`330/17/19/1`；三路 SSE 均连接，entities durable `1..6`、notifications `1..3` 连续；LLM tap 已接通 `https://api.anselm.website`，deterministic graph 没有 LLM 节点，故只记录 `ready`、不伪造 completion。`rig-check`、录屏封口和 ffprobe 通过。
- 正式证据 `.../EP-067-flowrun-inbox-real-session.md`，独立账本复审 `.../EP-067-flowrun-inbox-ledger-reaudit.md`。anchors `10/10`；`judge.py` 按 `G1/F2/A5/C4/G2` 将正式账本从 `1020→1025 judgments`，COVERAGE `EP-067=✓✓✓✓✓`。集中写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按原阈值独立复审并 ack，`alarms.py check` 最终 clean(1025)，阈值、算法、法典、锚点未改。
- 按用户删除授权，workflow/approval 精确 DELETE `204×2`、GET `404×2`、搜索列表为空；tombstone、version、三条 run/node 审计保留，fixture relations=0，seeded entities 未动。targeted Flutter `81` 项、`flutter analyze`、`git diff --check`、`gen_coverage.py --check`=`848/199/0` 通过。批次二十由 `0/50→5/50`，未满 50 不跑统一长门禁、不提交；下一前线为 EP-068 `GET /api/v1/flowrun-stats`。

## 2026-08-08 03:15 · 批次十九提交完成，工作树闭合

- 统一长门禁、完整黑盒回归、资源卫生和工作树审计全部通过后，已创建提交 `fcbb4301` (`test(acceptance): close workflow lifecycle batch nineteen`)；提交包含 50 个文件、`1475 insertions(+), 96 deletions(-)`。
- 提交后再次确认 branch `acceptance-loop` 工作树 clean；没有遗留台架进程、fixture 临时文件或未提交文档差异。批次十九正式闭合，下一原子前线为 EP-067 `GET /api/v1/flowrun-inbox`，等待下一轮 loop 唤醒。

## 2026-08-08 03:13 · 批次十九统一长门禁、完整黑盒回归与资源卫生收口

- 前端修复后根 `make verify` 全绿：backend、frontend、docs、demo 四子门禁均通过；frontend 仍为生成成功、analyze clean、四组共 `5233` tests green。显式 `mise exec -- go test ./...` 全模块通过；Subagent、tool-error-display、Scheduler 修复回归合计 `44` 项通过。
- 完整 backend 黑盒回归 `make testend` 通过：`go test -count=1 -parallel 16 -timeout 15m ./scenarios/...` → `ok github.com/sunweilin/anselm/testend/scenarios 313.161s`。未开启 EVALS、未注入 provider secret，不消耗受管网关额度；场景自带的 server、llama-server、sandbox 进程均由 harness 收台。
- 收台审计通过：没有存活的 testend/anselm-server/llama-server 或 pid/socket 残留；`git diff --check` 通过，`gen_coverage.py --check`=`848 rows / 198 carried / 0 tombstones`，`alarms.py check`=`clean (1020)`，10/10 anchor 仍在有效窗内。阈值、算法、法典和裁决标准均未改。
- 批次十九的五十格、统一长门禁、完整黑盒和已修场景回归均已完成；当前只剩工作树逐项审计、暂存和提交，提交后下一原子前线为 EP-067 `GET /api/v1/flowrun-inbox`。

## 2026-08-08 03:00 · 批次十九统一门禁前端红→修→绿，补齐 Subagent 校验细节

- 批次十九达到 50/50 后首次执行 `make -C frontend verify`，格式化、生成、analyze 均通过；聊天组日志先报 `tool_card_subagent_test.dart` 的校验失败卡没有显示 `subagent_type must be one of` 原始细节。Composer 尺寸条目在并行日志中与其他测试输出交错，单独复跑及完整聊天组均通过，未将台架输出误判成产品红。
- stop-and-fix 修改 `frontend/lib/features/chat/ui/tool_card_subagent.dart`：参数校验发生在 Spawn 前时，继续显示“未启动”而不虚构轨迹/回答，同时在其下保留一次真实校验细节；本地化错误概括仍由底盘显示，durable/wire 原文不变。既有 `Subagent validation failure says not started and has no replay fiction` 回归测试因此重新通过，未放宽标准、未改变成功路径。
- 修复后 `make -C frontend verify` 全绿：生成成功、analyze 无问题、四组测试共 `5233` 项通过。`git diff --check`、`gen_coverage.py --check`(`848/198/0`) 和 `alarms.py check` clean(1020) 均通过；当前继续执行根门禁，尚未提交。

## 2026-08-08 02:38 · EP-066 POST /api/v1/flowruns/{id}:cancel 五级收口，修复 Cancelled/Idle 语义缺陷，批次十九 50/50

- 首轮真实 Flutter + Computer Use session `/private/tmp/anselm-rig-ep066-flowrun-cancel-20260808/sessions/20260808-022218` 在取消 parked approval 后抓到真实产品缺陷：右侧 dossier 已说 `Status: Cancelled`，主状态 chip 却说 `Idle`。停止前线，修复 `frontend/lib/features/scheduler/ui/scheduler_run.dart` 为中性取消色调 + 明确 `Cancelled` 域标签，并补 `scheduler_run_test.dart` 回归断言；定向 Flutter tests 全绿。
- 修复后二次正式 session `/private/tmp/anselm-rig-ep066-flowrun-cancel-fixed2-20260808/sessions/20260808-022851` 重新走完整真实路径：Scheduler → parked approval run → Open → Cancel run → confirmation → Cancel run。确认框明确说明 `parked approvals are withdrawn`；终帧主 chip、dossier、error、节点收口全部一致，无 stale CTA、死 inbox、spinner、裁切或布局跳变。录屏 `275.491667s / 2784x1808 / 60fps`。
- REST/SQLite/SSE 真相：正确 `POST :capability-check`=`200` 且 `structurallyValid=true,resolved=true`；cancel=`202`；最终 `cancelled by user`、`replayCount=0`、human=`cancelled`、start=`completed`、parked=`0`；二次 cancel=`422 FLOWRUN_NOT_CANCELLABLE`，replay=`422 FLOWRUN_NOT_REPLAYABLE`，inbox=`parked=[]`。SSE 三流全连接，entities durable `run_started(seq=1) → run_terminal(cancelled,seq=2)`，notification=`seq=1`，无 gap，terminal 恰一条。早先 `GET :capability-check` 404 由 backend journal 证实是探针方法错，排除为产品红。
- 五通道 journal `backend/frontend/SSE/LLM=335/17/8/1`，窗口录像可读；backend 无 panic/FATAL/WARN/ERROR，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线。LLM tap 在线并承接 managed gateway 指针；deterministic graph 不伪造模型 completion。正式 evidence、API probe、红证据、cleanup 均已落盘。
- `judge.py` 按 `G1/F2/A5/C4/G2` 写入 `1015→1020 judgments`，COVERAGE `EP-066=✓✓✓✓✓`；`gap-too-fast` 与 `discovery-collapse` 按正式红/绿 session、五通道、SQLite、anchors 独立复审并 ack，`alarms.py check` clean(1020)，`gen_coverage.py --check`=`848 rows / 198 carried / 0 tombstones`，阈值/算法/锚点未改。
- 按用户授权，独立 no-App cleanup `/private/tmp/anselm-rig-ep066-cleanup-20260808/sessions/20260808-023430` 对 workflow、webhook trigger、approval 精确 DELETE `204×3`、后续 GET `404×3`；tombstone、version、run/node 审计保留，fixture relations=0，seeded entities 未动。批次十九由 **45/50→50/50**；现在执行一次统一长门禁、工作树审计和提交，下一前线 EP-067 `GET /api/v1/flowrun-inbox`。

## 2026-08-08 02:20 · EP-065 POST /api/v1/flowruns/{id}:replay 五级收口并完成真实 webhook 夹具清理，批次十九 45/50

- 产品目的：用户能从 Scheduler 打开失败 run，理解失败节点和 replay 范围，确认后只重跑失败节点并复用已完成结果；成功结果要回到同一 dossier 和 Overview，已完成 run 的重复 replay 必须明确拒绝。
- 正式 session `/private/tmp/anselm-rig-ep065-flowrun-replay-fixed-20260808/sessions/20260808-021122` 使用真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路 SSE witness、LLM tap 和受管 gateway；录屏 `147.960000s / 2784x1808 / 60fps`。正式 graph 使用真实 webhook `trg_4fc6464cb69089fe`，capability-check clean。早先 test-only `trg_manual` session 因悬空引用排除，不计绿。
- UI 路径 `Scheduler Overview → failed run → Open → Replay → confirmation → Replay → completed dossier → finish node → Overview` 逐帧通过：确认文案为 `Re-runs 1 failed nodes · reuses 2 completed results.`，成功显示 `Replay #1`、`4 nodes · Completed 4`、finish `final=2`，Overview 回到 `Failed · 24h 0`。未发现旧失败 CTA、重复活动、spinner、裁切、布局跳变或其它视觉缺陷。
- REST/SQLite 对证：`POST /flowruns`=`201`；直接 `POST ...%3Areplay`=`202`、同 run `replayCount=1`、`flaky.n=2`、`finish.final=2`、四节点 completed；第二次 replay=`422 FLOWRUN_NOT_REPLAYABLE`。每个 run 的 stable/finish 各一次成功，flaky 一次失败加一次 replay 成功，completed nodes 未重跑；原始失败 JSON 可解析且无控制字符。
- 五通道 journal 为 backend/frontend/SSE/LLM=`296/18/48/10`；notifications `16..32`、entities `7..18` 单调，gateway challenge/install/models 全 200，backend/frontend 无应用级未解释红线。正式证据 `.../EP-065-flowrun-replay-final-green.md`，API probe `.../EP-065-flowrun-replay-api-probes.md`，cleanup `.../EP-065-flowrun-replay-cleanup.md`。
- `judge.py` 按 `G1/F2/A5/C4/G2` 写入 `1010→1015 judgments`，COVERAGE `EP-065=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1015)，清册 `848/197/0`。gap-too-fast/discovery-collapse 因批量写账与无新 fail 正常打开，已用独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-065-flowrun-replay-ledger-reaudit.md` ack；阈值、算法、锚点未改。
- 按用户删除授权，cleanup 已对 workflow/trigger/handler/两个 function 执行 `DELETE 204×5 → GET 404×5`；tombstone、version/run/node/execution 审计保留，relations=0，seeded entities 未动。批次十九由 `40/50→45/50`，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-066 `POST /api/v1/flowruns/{id}:cancel`。

## 2026-08-08 01:53 · EP-064 GET /api/v1/flowruns/{id}/activity 五级收口并完成夹具清理，批次十九 40/50

- 产品目的：用户能在 Scheduler run inspector 看到 function、handler、agent、MCP 四类真实执行组成的 Gantt，逐节点查看 output、排队/执行时长和 execution log；API 四表聚合、keyset 分页、空 run 与错误边界必须和 UI/SQLite 一致。
- 最终真实 session `/private/tmp/anselm-rig-ep064-flowrun-activity-20260808b/sessions/20260808-014240` 使用真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路 SSE witness、LLM tap 和受管网关；录屏 `475.320000s / 2784x1808`，窗口 `26407`。真实 workflow 为 `webhook → function → handler → agent → MCP`，run `fr_c322e8cac2176f65` 完成；四张执行审计表各一行，activity 为 `function 29ms → handler 0ms → agent 9707ms → mcp 3ms`，`readyAt ≤ startedAt`，`limit=2` 两页无重无漏，空 run/坏 cursor/zero limit/ghost run 边界符合契约。
- Scheduler 逐帧确认 Done、5 nodes completed、Gantt、比例诚实的长 agent 条、node output、execution log ID、pinned v3，无视觉或产品直觉缺陷。backend/frontend/SSE/LLM journals 为 `623/17/118/16`，真实 gateway chat completion 200，未见应用级 WARN/ERROR/panic/Flutter/Dart/RenderFlex/Unhandled 红线，`rig-check` 与 `rig-down` 通过。
- 本格没有产品代码修复；清理第一次因 zsh 变量错误只发 `/api/v1/` 404，未改状态，逐条绝对 URL 重跑后 workflow×2、trigger×1、MCP×1 均 DELETE `204`、精确 GET `404`；真实 run、节点/四张审计表和 seeded function/handler/agent 保留，relations=0。正式证据 `/private/tmp/anselm-rig-ep064-flowrun-activity-20260808b/sessions/20260808-014240/evidence/EP-064-flowrun-activity-real-session.md`，API probe 同目录 `EP-064-flowrun-activity-api-probes.json`，cleanup `/private/tmp/anselm-rig-ep064-cleanup-20260808/sessions/20260808-015120/evidence/EP-064-flowrun-activity-cleanup.md`。
- `judge.py` 按 `G1/F2/A5/C4/G2` 写入 `1005→1010 judgments`，COVERAGE `EP-064=✓✓✓✓✓`，anchors `10/10`，gap-too-fast/discovery-collapse 经独立复核 ack 后 `alarms.py check` clean(1010)，清册 `848/196/0`；阈值与三曲线算法未调整。未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-065 `POST /api/v1/flowruns/{id}:replay`。

## 2026-08-08 01:37 · EP-063 GET /api/v1/flowruns/{id} 五级收口并完成夹具清理，批次十九 35/50

- 产品目的：用户能从 Scheduler 打开真实完成的 run，看到稳定的 run 头、节点完成数、分页节点列表，并展开剩余节点查看单节点 output 和 execution log；REST 必须提供同一 run 的有界 keyset continuation、错误语义和 workspace 隔离。
- 最终真实 session `/private/tmp/anselm-rig-ep063-flowrun-get-20260808/sessions/20260808-012500` 使用真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路 SSE witness、LLM tap 和受管网关；录屏 `438.676667s / 2784x1808`，真实路径 `Scheduler → completed run → Show remaining 14 → node25`，终帧与 AX 树已封存。
- API/SQLite/UI 对证：workflow `wf_75f1ef981c05df4b` 的 run `fr_4174d512cfc9b9ea` 用 `limit=10` 分页为 `10+10+6`，26 个唯一节点全 completed，三页 header 同一 run；unknown run、坏 cursor、`limit=0`、`limit=51` clamp 和 cross-workspace lookup 都按契约处理。SQLite 保留 26 nodes、25 function executions、版本 pin，删除后 fixture relations=0。
- 五通道：backend 590 行、frontend 18 行、SSE 124 行（entities durable `7..60`、notifications `16..19` 分 stream 连续）、LLM 16 行且 managed challenge/install/models 全 200；无未解释应用红线，deterministic workflow 不伪造 completion。收台前 `rig-check` 全绿，`rig-down` 无残留。
- 正式证据 `/private/tmp/anselm-rig-ep063-flowrun-get-20260808/sessions/20260808-012500/evidence/EP-063-flowrun-get-real-session.md`，API probe 同目录 `EP-063-flowrun-get-api-probes.json`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-063-flowrun-get-ledger-reaudit.md`。按 `G1/F2/A5/C4/G2` 写入 `1000→1005 judgments`，COVERAGE `EP-063=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1005)；gap-too-fast 按独立复审 ack，阈值和算法未改。
- 按用户删除授权，cleanup `/private/tmp/anselm-rig-ep063-cleanup-20260808/sessions/20260808-013308` 精确删除 workflow/function/隔离 workspace，DELETE `204×3`、exact GET `404×3`、主 workspace `200`；SQLite tombstone 与执行审计保留。批次十九由 `30/50→35/50`，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-064 `GET /api/v1/flowruns/{id}/activity`。

## 2026-08-08 01:22 · EP-062 POST /api/v1/flowruns 五级收口并完成夹具清理，批次十九 30/50

- 产品目的：用户能从 Workflow debugger 触发一次手动 run，看到 Done、节点完成数、耗时和输出，再进入 Scheduler durable run inspector；API 的单 trigger 自动选择与多 trigger 显式 `entryNode` 必须和真实产品路径一致，非法入口、未知 workflow、未知字段和 malformed JSON 必须 fail-loud。
- 最终真实 session `/private/tmp/anselm-rig-ep062-flowrun-start-20260808/sessions/20260808-005702` 由真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路 SSE witness、LLM tap 和受管网关完成；录屏 `1293.626667s / 2784x1808 / 60fps`，真实 UI 路径 `Entities → ep062-manual-run → debugger → Trigger → Open run → Scheduler inspector`，最终帧显示 Done、Completed 2、107ms、pinned version 和 `accepted: true / source: ui`。
- REST/SQLite/SSE/UI 对证：`fr_0f741423bace74b4` 单入口完成，`fr_764f18dec3c769b1` 显式 `t2→b` 完成，`fr_d7ea4365f1097af6` 与 UI trigger 语义一致，`fr_8e32ab2d25642afb` 为真实 App run；负路径覆盖 multiple entry、ghost/action entry、unknown field、missing/unknown workflow、malformed JSON，分别得到 `FLOWRUN_INVALID_ENTRY`、`INVALID_REQUEST`、`WORKFLOW_NOT_FOUND`。backend 1582 行、frontend 20 行、SSE 87 行/55 durable frame、LLM 10 行；entities `37/39/40` 对应 run_started/function close/run_terminal(completed)，无应用级未解释红线，gateway challenge/install/models 全 200。
- 初始 shell fixture 的 literal `\\n` SyntaxError 和 Computer Use 自定义 editor 的 AX-only `set_value` 均已明确分类为构造/仪器观察，不计产品缺陷；修复/替代后 API 与真实 UI 均成功，不修改产品源代码。本格最终证据为同 session 的 `EP-062-flowrun-start-real-session.md`、`EP-062-flowrun-start-api-probes.json`、`EP-062-final-frame.png`，ledger re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-062-flowrun-start-ledger-reaudit.md`。
- `judge.py` 按 `G1/F2/A5/C4/G2` 写入 `995→1000 judgments`，COVERAGE `EP-062=✓✓✓✓✓`，anchors `10/10`，alarms clean(1000)，清册 `848/194/0`；集中写账触发的 `gap-too-fast` 已独立复审 ack，阈值和算法未改。按用户授权 cleanup `/private/tmp/anselm-rig-ep062-cleanup-20260808/sessions/20260808-011934` 已 DELETE `204×3`，exact GET `404×3`，live workflow list 空，SQLite 保留 2 workflow/1 function tombstone、3 versions、8 flowruns、8 function executions，relations=0，seeded 数据未动。下一前线 EP-063，批次十九 `30/50`，未满 50 不跑统一长门禁、不提交。

## 2026-08-08 00:54 · EP-061 GET /api/v1/flowruns 五级收口并完成夹具清理，批次十九 25/50

- 产品目的：用户可在 Workflow Runs cockpit 以 keyset 继续翻历史，也可在 Scheduler 以 offset 页码、来源和状态筛选浏览完整 flowrun 真相；分页、时间窗和非法输入必须与同一后端过滤契约一致，失败、等待、取消和完成状态必须可解释。
- 最终真实 session `/private/tmp/anselm-rig-ep061-flowruns-20260808/sessions/20260808-003250` 由真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路 SSE witness、LLM tap 和受管网关完成；录屏 `630.583333s / 2784x1808 / 60fps`，Entities keyset `20→28`、Scheduler offset `29` 行/三页、来源筛选、failed inspector 与 approval waiting inspector 均真实走通。
- REST/SQLite/API probe：cursor 与 offset 无重叠且顺序一致，half-open started/completed 时间窗、非法 cursor/offset/status/origin/time、未知 workflow/trigger 组合和 completed/failed/running/cancelled 桶均符合契约；fixture 最终 34 flowruns=`30 completed/2 failed/2 cancelled`，主列表 workflow 29 条完成历史。backend 915 行、frontend 17 行、SSE 111 行/107 frame、LLM 10 行；notifications `16..37`、entities `7..77` 单调，gateway challenge/install/models 全 200，无应用级未解释红线。
- 正式绿证据 `/private/tmp/anselm-rig-ep061-flowruns-20260808/sessions/20260808-003250/evidence/EP-061-flowruns-real-session.md`，API probe/SSE summary/final frame 同目录；账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-061-flowruns-ledger-reaudit.md`。按 `G1/F2/A5/C4/G2` 写入 `990→995 judgments`，COVERAGE `EP-061=✓✓✓✓✓`，anchors `10/10`，alarms clean(995)，清册 `848/193/0`；`gap-too-fast` 独立复审后 ack，阈值和算法未改。本格无产品源代码修复，Go/Flutter targeted、diff、coverage 检查通过。
- 按用户删除授权，独立无 App cleanup `/private/tmp/anselm-rig-ep061-cleanup-20260808/sessions/20260808-004956` 已删除 5 workflow、5 trigger、1 approval、1 deliberate-failure function：DELETE `204×12`、精确 GET `404×12`、`ep061-` live lists 为空；approval parked run 先 `:kill` 收束。SQLite tombstones=`5 workflow/5 trigger/1 approval/1 function`、fixture relations=`0`，34 flowruns、8 workflow versions、4 trigger firings 保留，seeded `greet`/`sync_inventory`/`演示工作台` 未动；清理证据为 cleanup session 的 `EP-061-flowruns-cleanup.md`。下一前线 EP-062，批次十九 `25/50`，未满 50 不跑统一长门禁、不提交。

## 2026-08-08 00:27 · EP-060 GET /api/v1/workflows/{id}/versions/{version} 红→修→绿收口，批次十九 20/50

- 产品目的：用户从 workflow Versions 页面或 API 读取一个明确的历史 graph；数字/opaque 版本地址都必须仍属于 URL 中的 workflow，跨父读取必须大声 404，不能把另一 workflow 的 immutable graph 伪装成当前版本。
- 首轮真实红 session `/private/tmp/anselm-rig-ep060-workflow-version-20260808/sessions/20260808-001344` 复现 `GET /workflows/B/versions/<A opaque id> → 200` 且响应 `workflowId=A`；红证据 `EP-060-workflow-version-red.md` 永久保留，不计绿。stop-and-fix 新增 workflow parent-scoped repository/app/handler path，scheduler 全局 pinned `GetVersion` 不变；store/app/handler 回归、API/domain 文档已同步。
- 固定真实 session `/private/tmp/anselm-rig-ep060-workflow-version-fixed-20260808/sessions/20260808-001940` 使用真实 App、Computer Use、窗口录制、frontend/backend journals、三路 SSE witness、真实 gateway LLM tap。UI `Entities → Workflow → Versions` 显示 v2 展开、v1→v2 diff、完整 trigger graph；录屏 `106.916667s / 2784x1808 / 60fps`，最终帧 `EP-060-final-frame.jpg`，无裁切/重叠/死控件。
- REST/SQLite 对证：A 数字 v2 与自有 opaque v2 均 200、`workflowId=A`、`graphParsed` 存在；B opaque、B 数字 v2、A 的 0/-1/999/unknown 均 `404 WORKFLOW_VERSION_NOT_FOUND`。SSE notifications durable `16,17,18` 单调；backend/frontend 无未解释应用红线；LLM challenge/install/models 全 200，本只读路径不伪造 completion；`rig-check` 与 `rig-down` 全部通过。
- cleanup `/private/tmp/anselm-rig-ep060-cleanup-20260808/sessions/20260808-002310` 已按授权 DELETE workflow/trigger=`204×4`、后续 GET=`404×4`、live lists 为空；SQLite 保留两 workflow tombstone、3 个 immutable version、两 trigger tombstone，fixture relations=0，seeded `演示对话` 未动，收台无残留。
- 正式证据 `/private/tmp/anselm-rig-ep060-workflow-version-fixed-20260808/sessions/20260808-001940/evidence/EP-060-workflow-version-final-green.md`；账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-060-workflow-version-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 写入 `985→990 judgments`，COVERAGE `EP-060=✓✓✓✓✓`；anchors `10/10`，`alarms.py check` clean(990)，`gen_coverage.py --check` 为 `848 rows / 192 carried / 0 tombstones`。批次十九 `15/50→20/50`，未到 50 格不跑统一长门禁、不提交；下一前线 EP-061 `GET /api/v1/flowruns`。

## 2026-08-08 00:07 · EP-059 GET /api/v1/workflows/{id}/versions 五级收口，批次十九 15/50

- 产品目的：真实用户能从 Entities 找到 workflow 的 Versions tab，在 20 条分页边界看到明确的 `Load more`，点击后得到完整 v22..v1 历史；首个版本自动展开、差异可读、追加无重复、结束后无死控件。
- 真实 session `/private/tmp/anselm-rig-ep059-workflow-versions-20260808/sessions/20260807-235745` 使用 conductor、真实 Flutter App、Computer Use、251.178333s/2784x1808/60fps 窗口录屏、frontend/backend journal、三路 SSE witness、真实 gateway LLM tap。fixture workflow `wf_e6a23f5c4c1e6ad0` 与 trigger `trg_dc40065b733c5085` 形成 22 个版本；首屏 v22..v3，Load more 后 v2/v1，最终帧 v15..v1 无红卡/截断/死控件。
- REST/SQLite/UI 对证：limit=20 第一页 `22..3`、cursor 第二页 `2..1` 严格无重叠；数字与 opaque ID 单读均为 v22；`limit=0` 为 `400 INVALID_REQUEST`，坏 cursor 为 `400 MALFORMED_CURSOR`；SQLite 保留 22 个 workflow version rows。
- 五通道：backend 无 panic/FATAL/未解释错误；frontend 无 Flutter/Dart 运行期红线（`Dart VM Service` 为正常启动行）；notifications durable seq `16..37` 严格单调无 gap；llmtap 完成 challenge/install/models 握手但不虚构确定性版本页的 completion；`rig-check` 五通道全绿，`rig-down` 后无残留。
- 正式证据 `/private/tmp/anselm-rig-ep059-workflow-versions-20260808/sessions/20260807-235745/evidence/EP-059-workflow-versions-final-green.md`，ledger/alarm 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-059-ledger-alarm-reaudit.md`。anchors `10/10`，按 `G1/F2/A5/C4/G2` 写入正式账本 `980→985 judgments`，COVERAGE EP-059=`✓✓✓✓✓`，`gen_coverage.py --check`=`848 rows / 191 carried / 0 tombstones`。
- 集中写账触发的 `gap-too-fast` 已按独立录屏、五通道、REST/SQLite、SSE 和最终帧复审并 ack，25 秒阈值与三曲线算法未改，`alarms.py check` clean(985)。cleanup `/private/tmp/anselm-rig-ep059-cleanup-20260808/sessions/20260808-000634` DELETE workflow/trigger=`204×2`、GET=`404×2`，22 个版本和 deleted_at 保留、relations=0、seeded `演示对话` 未动。下一原子前线为 EP-060。

## 2026-08-07 23:52 · EP-058 POST /api/v1/workflows/{id}:iterate 红→修→绿收口，批次十九 10/50

- 产品目的：真实用户从 Workflow 行进入 `Edit with AI`，自然语言描述图变更后，AI 必须读取正确实体、只产生一次可核对的 `edit_workflow` mutation，并把新版本和成功状态呈现在 App；空请求、错误目标不得建 conversation。
- 三条真实红链永久保留：`/private/tmp/anselm-rig-ep058-workflow-iterate-20260807/sessions/20260807-230750` 暴露 hosted-model `get_trigger`/workflow ops 形状错误；`...fixed2.../20260807-232114` 暴露重复 trigger 与原始错误重复展示；`...fixed3.../20260807-233252` 暴露 mention 有唯一 trigger ID 仍首轮发空参 `get_trigger`。第一次 answer 输入失败形成 `Empty answer` 也保留，不计绿。
- stop-and-fix 采用窄兼容而非放松契约：`get_trigger` 只接受 canonical `triggerId`，仅对精确 `trg_...` hosted alias 做归一化；loop 只在最新证据有唯一 trigger ID 时修复缺参；workflow edit 只兼容已观测的 known-op `type` alias；成功 activity 退休同目标旧失败 projection 但保留 durable failure transcript；失败 entity get 不再重复渲染原始错误。
- 最终真实 session `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed4-20260807/sessions/20260807-233816` 由同一 conductor 托管真实 Flutter App、Computer Use、571.585000s/2784x1808/60fps 录屏、frontend/backend journal、三路 SSE witness、真实 Anselm gateway LLM tap。重新提交明确英文意图后只调用一次 `edit_workflow`，App 显示 `Edited`、workflow v2、`entry → summarize` 与三条成功 Activity，无红卡/retry/重复 mutation。
- REST/SQLite/SSE/LLM wire 对证：v2 graph 为 `entry(trg_0dee30ab43f0ecfa) → summarize(agent ag_87bc026f0b6d1c7c)`；messages durable `1..94`、entities `7..8`、notifications `16..19` 无 gap，LLM chat 全 200；whitespace 返回 `400 EMPTY_ITERATE_REQUEST`，missing workflow 返回 `404 WORKFLOW_NOT_FOUND`，两条负路径前后 conversation 数不变。
- 目标 Go/Flutter tests、`flutter analyze`、`git diff --check` 通过；收台前 `RIG_HOME=...fixed4... rig-check.sh` 五通道全绿，`rig-down` 封口并保留 journals。正式绿证据 `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed4-20260807/sessions/20260807-233816/evidence/EP-058-workflow-iterate-final-green.md`，ledger/alarm 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-058-ledger-alarm-reaudit.md`。
- anchors 重新校准 `10/10`；按 `G1/F2/A5/C4/G2` 写入正式账本 `975→980 judgments`，清册 EP-058=`✓✓✓✓✓`，`gen_coverage.py --check`=`848 rows / 190 carried / 0 tombstones`。批量写账的 `gap-too-fast` 已独立复审并 ack，25 秒阈值与三曲线算法未改，`alarms.py check` clean(980)。
- 按用户授权的独立 cleanup `/private/tmp/anselm-rig-ep058-cleanup-20260807/sessions/20260807-235013` DELETE conversation/workflow/trigger=`204×3`，后续 GET=`404×3`；workflow v1/v2、4 messages、42 blocks、soft-delete tombstone 保留，fixture relations=0，seeded `演示对话` 未动，cleanup 收台无残留。批次十九由 `5/50→10/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-059 `GET /api/v1/workflows/{id}/versions`。

## 2026-08-07 22:45 · EP-057 POST /api/v1/workflows/{id}:capability-check 红→修→绿收口，批次十九 5/50

- 产品目的：用户可以在 Chat 中按 workflow 名称发起能力检查；clean、悬空引用、数据流 advisory warning 和 not-found 必须分别呈现，不能猜 ID、把 warning 当 blocking、把缺失资源伪装成空结果。
- 首轮真实红 session `/private/tmp/anselm-rig-ep057-workflow-capability-20260807/sessions/20260807-221211` 保留了 hosted model 目标解析错误、可避免失败卡和 placeholder prose；不计绿。stop-and-fix 让 `get_workflow`/`capability_check_workflow` 支持精确 `workflowId`/`workflowName`，对观测到的单段 `file_path` alias 做窄归一化，返回 resolved id/name，touchpoint/card 使用真实身份，并修复中文 typed placeholder 脱敏。
- 最终真实 session `/private/tmp/anselm-rig-ep057-workflow-capability-20260807/sessions/20260807-223010` 由同一 conductor 托管真实 App、Computer Use、602.966667s 窗口录屏、frontend/backend journal、三路 SSE witness、真实 Anselm gateway LLM tap。四条 fresh Chat 会话分别验证 clean=`ok/problems[]/warnings[]`、dangling=2 blocking problems、warning=1 advisory warning、missing=`workflow not found`；稳定画面无 retry、duplicate mutation 或虚构详情。
- 五通道与真相对证：SSE messages durable `1..78`、notifications `1..8` 单调无 gap；LLM chat responses 全 200；backend 只有预期 missing 负路径 WARN；frontend 无 Dart/Flutter/RenderFlex/overflow/Unhandled 红线，仅有已知 IMK runner 环境行；REST/SQLite 与 UI、tool result 一致。Go targeted tests、Flutter capability-card 13 项、`flutter analyze` 和收台前 `rig-check` 全绿。
- 正式绿证据为 `/private/tmp/anselm-rig-ep057-workflow-capability-20260807/sessions/20260807-223010/evidence/EP-057-workflow-capability-final-green.md`，独立 ledger/alarm 复审为 `/private/tmp/anselm-rig-ep057-workflow-capability-20260807/sessions/20260807-223010/evidence/EP-057-ledger-alarm-reaudit.md`。anchors `10/10` 后按 `G1/F2/A5/C4/G2` 写入五格，正式账本 `970→975 judgments`，COVERAGE `EP-057=✓✓✓✓✓`，`gen_coverage.py --check` 为 `848 rows / 189 carried / 0 tombstones`。
- 集中写账触发的 `gap-too-fast` 已逐项复审并 ack，25 秒阈值与算法未改，最终 `alarms.py check` clean(975)。按用户授权，独立 cleanup `/private/tmp/anselm-rig-ep057-cleanup-20260807/sessions/20260807-224320` 已软删 3 workflow、1 trigger、2 function；后续对象 GET/list 诚实为空或 404，SQLite `deleted_at` 对证、3 条 workflow version history 与审计事实保留、fixture relations=0、收台无残留。
- 批次十九当前 **5/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-058 `POST /api/v1/workflows/{id}:iterate`。

## 2026-08-07 22:10 · EP-056 POST /api/v1/workflows/{id}:revert 五级收口，批次十八 50/50，统一门禁通过

- 产品目的：用户在 Workflow Versions 页面能理解版本差异、选择历史版本并即时看到 active 指针切换；回退不删除历史、不制造新版本，非法版本号给出明确错误。
- 最终真实 session `/private/tmp/anselm-rig-ep056-workflow-revert-20260807/sessions/20260807-214211` 由真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关完成。用户从 v3 依次 `Set active` 到 v2、v1；header、绿色 active marker、历史 diff 均稳定可读，录屏 `338.140000s / 2784x1808 / 60fps`。
- REST/SQLite/SSE：两次合法 revert=200，version `999`/`0` 均为 `404 WORKFLOW_VERSION_NOT_FOUND`；最终 active `wfv_1da2f4946f7dee62`，v1/v2/v3 保留且无 v4；notifications durable seq `16..20` 单调无 gap。backend 459 行、frontend 76 行无未解释应用红线，LLM 只记录真实 readiness。
- 正式绿证据 `/private/tmp/anselm-rig-ep056-workflow-revert-20260807/sessions/20260807-214211/evidence/EP-056-workflow-revert-final-green.md`，ledger/alarm 独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-056-workflow-revert-ledger-alarm-reaudit.md`；账本 `965→970` 按 `G1/F2/A1/C4/G2` 写五格绿，COVERAGE `EP-056=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(970)，`gen_coverage.py --check` 为 `848 rows / 188 carried / 0 tombstones`。
- 批次十八达到 `50/50` 后统一执行一次：`make verify` backend/frontend/docs/demo 全绿；完整 `go test -count=1 -timeout 20m ./...` 全绿；本批修复场景前端定向回归 79 项与 analyze 全绿；`make -C backend testend` 全绿（`testend/scenarios 298.841s`）；未放宽任何阈值或算法。
- 按用户授权的无 App cleanup session `/private/tmp/anselm-rig-ep056-cleanup-20260807/sessions/20260807-220655` 删除专用 workflow/trigger：workflow DELETE `204`、幂等重试 `404`，trigger DELETE `204`，后续 GET 均 `404`；3 个 workflow versions、软删除主行和执行/节点历史保留，fixture relations=0，收台无残留。下一原子前线为 EP-057 `POST /api/v1/workflows/{id}:capability-check`。

## 2026-08-07 21:30 · EP-055 POST /api/v1/workflows/{id}:edit 红→修→绿收口，批次十八 45/50

- 产品目的：用户在真实 Workflow 图编辑器中修改节点/边并保存，成功要可见；无效图要在全屏编辑器内给出结构化错误；结构变更后画布要保持可读，不能把用户视口留在旧图位置。
- 首轮真实红 session `/private/tmp/anselm-rig-ep055-workflow-edit-20260807/sessions/20260807-210151` 抓到两处缺陷：结构变更后旧 viewport 未 fit，`start` trigger 被截在左侧；删除唯一 trigger 后保存虽返回 `422 WORKFLOW_INVALID_GRAPH`，全屏编辑路由没有 notice host，用户看不到 `graph must have at least one trigger node`。红帧和正式红证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-055-workflow-edit-red.md` 永久保留，不计绿。
- stop-and-fix：`AnGraphCanvas` 区分内部 fit 与用户平移/缩放，pristine editable viewport 在结构/方向变化后重 fit，用户主动变换后保留；全屏 graph/editor 路由挂载 `BandNoticeHost`，错误在顶层可见。graph canvas、router、workflow editor regression tests、format/analyze 已通过。
- 最终真实 session `/private/tmp/anselm-rig-ep055-workflow-edit-20260807/sessions/20260807-212105` 由真实 Flutter App、Computer Use、录屏、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关完成。用户添加 `sync_inventory` Action、连接 `task → task2` 并保存，看到 `New version saved`；再删除唯一 trigger 保存，看到结构化错误，`Unsaved changes` 与 Save/Discard 保持可用，Discard 恢复合法图。录屏 `379.343333s / 2784x1808 / 60fps`，最终成功/错误帧已封存。
- REST/SQLite/SSE：合法 edit=200，active version `wfv_d454f6b6f5fffd5f`，版本链 v1/v2/v3；非法保存=422，不产生 v4；notifications 有 durable `workflow.edited`，三流无 gap。backend/frontend 无未解释应用级红线，LLM readiness-only，rig-check 通过且收台无残留进程组。
- 正式绿证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-055-workflow-edit-final-green.md`，ledger/alarm 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-055-workflow-edit-ledger-reaudit.md`；正式账本 `955→960` 写五格红，再 `960→965` 按 `G1/F2/A5/C4/G2` 写五格绿，COVERAGE `EP-055=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(965)，`gen_coverage.py --check` 为 `848 rows / 187 carried / 0 tombstones`。
- 按用户授权的无 App cleanup session `/private/tmp/anselm-rig-ep055-cleanup-20260807/sessions/20260807-213318` 删除专用 workflow/trigger/functions：workflow 首次 DELETE=204、幂等重试=404，其余 DELETE=204，后续 GET=404；workflow versions、function versions、flowrun/节点/审计 history 保留，fixture relations 清理且无关文档未动。批次十八由 `40/50→45/50`，红→修复绿不重复计数；未满 50 格不跑统一长门禁、不提交。下一原子前线为 EP-056 `POST /api/v1/workflows/{id}:revert`。

## 2026-08-07 20:55 · EP-054 POST /api/v1/workflows/{id}:kill 红→修→绿收口，批次十八 40/50

- 产品目的：硬停会摘监听、取消全部在途 run、撤回 parked approval 并回到 `inactive`；详情页不能提供危险动作的一键直达，必须把真实影响范围讲清楚并要求用户确认。
- 首个真实红 session `/private/tmp/anselm-rig-ep054-workflow-kill-20260807/sessions/20260807-202624` 在 Runs 面板抓到 parked approval 旁的直接 `Kill`：一次点击即取消，没有确认、没有显示会撤回 approval。红帧和正式红证据已永久保留，不计绿。
- stop-and-fix 将详情页直杀改为共享 `AnExpandReveal` + `AnTypeToConfirm`：显示当前 running/parked 数量，明确停止监听、取消执行和撤回 approval 的后果；错误名称点击不执行，精确 workflow 全名才解锁红色确认。补齐中英文 i18n、generated strings、widget regression test，并以真实键盘事件复核 AX 与画面一致，长名称输入横向滚动不跳变。
- 最终真实绿 session `/private/tmp/anselm-rig-ep054-workflow-kill-final-20260807/sessions/20260807-204108` 由真实 Flutter App、Computer Use、录屏、frontend console、backend、三路独立 SSE witness、LLM tap 和受管网关完成。用户从 Workflow → Runs 看到 `running / Awaiting approval`，错误名称保持 running，精确名称确认后画面稳定为 cancelled；录屏 `358.753333s / 2784x1808 / 60fps`，确认框 open/armed/final frames 已封存。
- REST/SQLite/SSE 交叉一致：workflow inactive，trigger `listening=false/refCount=0`，flowrun `cancelled / killed by user`，start node completed、hold node cancelled、approval inbox 为空；kill 后 webhook=404，capability check `structurallyValid=true,resolved=true`，版本和 execution history 保留；三流 durable seq 单调、无 gap。backend `478` 行无应用红线；frontend `19` 行仅已知 launcher/IMK 平台噪声，无 Dart/FlutterError/RenderFlex/overflow/Unhandled/lost-device；LLM 为 readiness-only，确定性图不虚构 completion。
- 正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-054-kill-final-green.md`，红证据为 `EP-054-kill-direct-no-confirm-red.md`，前端复核及 ledger/alarm 独立复审同目录封存。正式账本先 `945→950` 写入五格红，再 `950→955` 按 `G1/F2/A5/C4/G2` 写入五格绿；COVERAGE `EP-054=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(955)，`gen_coverage.py --check` 为 `848 rows / 186 carried / 0 tombstones`，阈值和算法未改。
- 按用户授权的无 App cleanup session `/private/tmp/anselm-rig-ep054-cleanup-20260807/sessions/20260807-204933` 删除红场与绿场两套专用夹具：DELETE `204×6`、对象 GET `404×6`、两条 cancelled flowrun GET `200`；主实体软删，执行/节点/firing/activation/version history 保留，relations=0，收台无残留。批次十八由 `35/50→40/50`，红→修复绿不重复计数；未满 50 格不跑统一长门禁、不提交。下一原子前线为 EP-055 `POST /api/v1/workflows/{id}:edit`。

## 2026-08-07 20:25 · EP-053 POST /api/v1/workflows/{id}:deactivate 五级收口，批次十八 35/50

- 产品目的：真实用户能在 Workflow 详情停用监听而不杀掉在途执行；approval parked run 在 `draining` 状态仍可继续，决策完成后 workflow 自动收口为 `inactive`；停用后的 webhook 必须拒绝，重复停用不得重复 listener、run 或历史。
- 最终 session `/private/tmp/anselm-rig-ep053-workflow-deactivate-20260807/sessions/20260807-200724` 由同一 conductor 托管真实 Flutter App、Computer Use、录屏、frontend console、backend、三路独立 SSE、LLM tap 和受管网关。真实画面走完 `inactive → active / Listening → webhook park → draining → approval yes → inactive`，Runs 面板保持同一条 run 从 `Awaiting approval` 到 completed；录屏 `360.425000s / 2784x1808 / 60fps`，关键帧为 draining/awaiting 与 inactive/completed。
- REST/SQLite/SSE 交叉一致：最终 workflow inactive、trigger `listening=false/refCount=0`；一条 completed webhook flowrun、两个 completed node、一个 firing、workflow v1/approval v1 history 保留；三流记录 `active → draining → inactive`、park/decide 和 `run_started(seq=1) → run_terminal(seq=2,completed)`，无 gap。停用后 webhook=404，重复 deactivate=200；LLM 为 ready-only，不虚构确定性图的 completion。
- 五通道封口：screen `360.425000s / 2784x1808 / 60fps`；backend 476 行无应用 panic/FATAL/WARN/ERROR；frontend 114 行，其中 96 条固定 AXTree bridge tooling pattern 已审阅，未知模式仍 fail-closed；rig-check 通过，rig-down 后 owned process groups 归零。正式绿证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-053-workflow-deactivate-final-green.md`，ledger/alarm 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-053-ledger-alarm-reaudit.md`。
- 正式账本 `940→945` 按 `G1/F2/A5/C4/G2` 写入五格，COVERAGE `EP-053=✓✓✓✓✓`；anchors `10/10`，`alarms.py check` clean(945)，`gen_coverage.py --check` 为 `848 rows / 185 carried / 0 tombstones`，阈值和算法未改，集中写账产生的 gap alarm 已按独立复审 ack。
- 按用户授权的 cleanup session `/private/tmp/anselm-rig-ep053-final-cleanup-20260807/sessions/20260807-201616` 无 App 删除三件专用夹具：DELETE `204×3`、GET `404×3`、flowruns `200`；SQLite 证明主行仅软删、执行/节点/firing/版本 history 保留、relations=0，收台后无残留。批次十八由 `30/50→35/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-054 `POST /api/v1/workflows/{id}:kill`。

## 2026-08-07 20:05 · EP-052 POST /api/v1/workflows/{id}:activate 红→修→绿收口，批次十八 30/50

- 产品目的：真实用户能从 Workflow 详情发现 Activate，让可运行图进入 `active / Listening`，重复上线不重复挂 listener；真实 webhook 能连续产生可追踪的 completed run；不可运行图必须在 App 中给出完整、可行动的缺失引用，而不是泛化错误。
- 首轮负路径 session `/private/tmp/anselm-rig-ep052-workflow-activate-20260807/sessions/20260807-192310` 证明后端 422 `WORKFLOW_NOT_RUNNABLE` 正确，但 UI 只显示 `Action failed`。第一次修复的长 notice 在真实 36px capsule 中又被省略号截断；红证据永久保留，不计绿。
- stop-and-fix：`frontend/lib/features/entities/ui/entity_rail.dart` 现在保留结构化 `ApiException` 问题，提取 `WORKFLOW_NOT_RUNNABLE` 的首条问题并把缺失 ref 映射为可行动 notice；同步中英文 i18n、生成字符串、rail 回归测试和实体文档。最终短文案为 `Missing: $ref` / `缺少：$ref`，真实画面完整显示 `trg_00000000ep052bad`。
- 最终真实绿 session `/private/tmp/anselm-rig-ep052-workflow-activate-20260807/sessions/20260807-194656`：真实 App 走 UI Deactivate→Activate，回到 `active / Listening`；重复 REST activate=200 且 trigger `refCount=1`；两次 webhook `final-first/value=3` 与 `final-second/value=4` 均 202，Runs 不离开页面更新到 `Runs · 4`，最新 run completed。负 workflow activate 仍 422/inactive。
- REST/SQLite/界面一致：四条 webhook flowrun、四条 activation/firing、四个 completed trigger node result 均保留原始 payload，全部 pin `wfv_a41f15b41dad7f50`；positive active/lifecycle 与 trigger listening projection 一致。三流 SSE 记录 lifecycle `inactive→active→active`、fire 信号和两轮 durable `run_started→run_terminal`；LLM tap 只有 readiness，本确定性图不虚构 completion。
- 五通道封口：录屏 `382.471667s / 2784x1808 / 60fps`；backend `475` 行；frontend `79` 行，其中 `61` 条固定 Flutter macOS AXTree bridge churn 已逐条写 session review，未知模式仍 fail-closed；`rig-check` 通过，收台无残留。正式红证据、绿证据、前端复核和 ledger/alarm 复审均已封存于 `/private/tmp/anselm-rig-formal-20260801-3/evidence/`。
- 正式账本从 `930→935` 写入五条红，再从 `935→940` 写入 `G1/F2/A5/C4/G2` 五条绿；COVERAGE `EP-052=✓✓✓✓✓`。红写入后的 `gap-too-fast`、绿写入后的 `gap-too-fast/pass-burst` 均经独立复审销账，`alarms.py check` clean(940)，anchors 10/10，`gen_coverage.py --check` 为 `848 rows / 184 carried / 0 tombstones`，阈值算法未修改。
- 按用户授权，独立无 App cleanup session `/private/tmp/anselm-rig-ep052-final-cleanup-20260807/sessions/20260807-195424` 对三件专用夹具 DELETE 均 204，后续三件 GET 均 404；flowrun GET=200，版本、activation/firing/node result 历史保留，fixture relations=0。批次十八由 `25/50→30/50`，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-053 `POST /api/v1/workflows/{id}:deactivate`。

## 2026-08-07 19:15 · EP-051 POST /api/v1/workflows/{id}:stage 红→修→绿收口，批次十八 25/50

- 产品目的：一次布防不把 workflow 变成持续 active；下一次真实 webhook fire 只执行一次并自动撤防，active 状态下 stage 必须明确拒绝。首轮真实 session 的 Runs 面板在 webhook 完成后停在 `Runs · 0`，虽然 REST/SQLite/SSE 已正确；这是产品实时真相缺陷，红证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-051-open-runs-stale-red.md` 永久保留，正式台账由 920 补录到 925 条红裁决。
- stop-and-fix：`run_cockpit_provider.dart` 接入 workflow scope durable `run_started`/`run_terminal` 订阅，120ms debounce 重读 REST，保留 selected run/node；`entity_format.dart` 将 empty-string terminal cursor 与 `null` 同视为结束，修复版 flowrun detail 只产生一次 App GET，旧 binary 的约 20 次重复 GET 消失。守卫测试、analyze 和 frontend entities 文档已同步。
- 最终 session `/private/tmp/anselm-rig-ep051-workflow-stage-final-20260807/sessions/20260807-190337` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录像、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关。App 在打开 Runs 页先显示 `Runs · 0`；stage 后真实 webhook `{"event":"EP051-FINAL","value":9}` 返回 202，未切 tab/手动刷新即变为 `Runs · 1`、completed、flowrun id、pinned version、trigger 节点和 Run graph。先 activate 再 stage 返回 409 `WORKFLOW_ALREADY_ACTIVE`，deactivate 后回 inactive。
- REST/SQLite：activation 1 条、firing 1 条、completed webhook flowrun `fr_43bb4b87e43a677d` 1 条，start node 原样保留 body、headers、method、path、firedAt；自动撤防后重复路径不建第二条 firing/run。screen 149.625000s / 2784x1808 / 60fps；backend 227 行无应用 panic/FATAL/WARN/ERROR；SSE 三流全连接，entities durable `run_started seq=1`→`run_terminal seq=2`；frontend 17 行无 Dart/Flutter/RenderFlex/Unhandled/overflow/lost-device 运行期红线，启动器 `open returned 1` 单独归因；LLM ready-only，不虚构 completion。
- 正式绿证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-051-workflow-stage-final-green-realtime-fix.md`，前端复核 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-051-frontend-runtime-review-realtime-fix.md`，独立 ledger/alarm 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-051-ledger-alarm-reaudit-realtime-fix.md`。anchors 10/10 后按 `G1/F2/A5/C4/G2` 写账，正式台账 `925→930 judgments`，COVERAGE EP-051=✓✓✓✓✓；`alarms.py check` clean(930)，`gen_coverage.py --check` 为 848 rows / 183 carried / 0 tombstones。gap-too-fast/pass-burst 均按复审证据 ack，阈值和算法未改。
- 证据封存后按用户授权以独立无 App 台架删除两轮 EP-051 专用 workflow/trigger：4 个 DELETE 均 204，4 个已删对象 GET 均 404，另有 2 个 flowrun GET 均 200；两条 completed flowrun、各自 v1、activation/firing/node result 保留，SQLite relation 数为 0。清理 session `/private/tmp/anselm-rig-ep051-final-cleanup-20260807/sessions/20260807-191329` 已收台且无残留进程。批次十八仍为 25/50（红→修复绿不重复计数），未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-052 `POST /api/v1/workflows/{id}:activate`。

## 2026-08-07 18:20 · EP-050 POST /api/v1/workflows/{id}:trigger 五级收口，批次十八 20/50

- 产品目的：真实用户在 Scheduler workflow 详情页找到 `Run now`，手动执行后能追踪结果；手动路径不改变 inactive/listener 状态，不冒充真实 trigger fire；可选 payload 原样进入入口节点，错误输入不制造幽灵 run。
- 正式 session `/private/tmp/anselm-rig-ep050-workflow-trigger-20260807/sessions/20260807-180921` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录像、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关。UI 从 Scheduler Overview 进入 `ep050-manual-run`，点击 `Run now` 后显示 toast、绿色 `Manual · 18:12`；第二次合法 payload 后出现 `Manual · 18:15`，Matrix 到达 2 runs，打开第二条旗舰详情显示 Done/Completed、0ms、v1 pinned version、1 个 completed trigger 节点。workflow 仍 Inactive，trigger 仍 never fired。
- REST/SQLite：两次成功请求均为 `202`，flowrun 为 `fr_e87daec34cb74b0a` 与 `fr_58e12b1ffac09e2e`，均 completed/manual/pinned v1；payload 节点结果为 `{"count":2,"message":"EP050 payload","nested":{"ok":true}}`。`{"payload":"not-an-object"}` 返回 `400 INVALID_REQUEST`，列表仍恰有两条 run。
- 五通道：screen `427.206667s / 2784x1808 / 60fps`；backend `549` 行无应用 panic/WARN/ERROR；SSE notifications/entities/messages 全连接，entities durable seq `1..4` 单调记录两次 start→terminal；frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow/lost-device 运行期红线，唯一启动阶段 Flutter `Failed to foreground app; open returned 1` 由独立文档归因并保留；LLM ready-only，本确定性路径不虚构 completion。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-workflow-trigger-final-green.md`，前端复核 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-frontend-runtime-review.md`，警报复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-ledger-alarm-reaudit.md`。anchors `10/10` 后按 `G1/F2/A5/C4/G2` 写入，账本 `910→915 judgments`，COVERAGE `EP-050=✓✓✓✓✓`。
- 五格写入打开的 `gap-too-fast` 与 `discovery-collapse` 已按完整录屏、红负向输入、REST/SQLite、五通道 journal 独立复审并 ack；25 秒阈值、5% discovery floor 与算法未改，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 182 carried / 0 tombstones`。EP-050 无源代码修复，rig-down 后进程归零。
- 批次十八从 **15→20 / 50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 `EP-051 POST /api/v1/workflows/{id}:stage`。

## 2026-08-07 18:03 · EP-049 DELETE /api/v1/workflows/{id} 五级收口，批次十八 15/50

- 产品目的：真实用户从 Workflow 详情发现删除入口，读懂二次确认，删除后回到真实活动目录；活动 Workflow 与关系边消失，不可变版本历史保留，不能留下 stale detail 或幽灵 trigger 引用。
- 正式 session `/private/tmp/anselm-rig-ep049-workflow-delete-20260807/sessions/20260807-174109` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关。目标 `ep049-workflow-delete` 在 UI 中从 Entities Overview 打开详情，经 More actions → Delete → 点名实体的二次确认 → Delete；Workflow count `2→1`，目标行和详情消失，无空白面或 stale detail。
- REST/SQLite/关系真相：DELETE=204，后续 GET=404 `WORKFLOW_NOT_FOUND`；软删主行 `wf_beba4f5635a577d3` 有 `deleted_at`，版本 `wfv_a10baa6211bd01d9` 保留，目标关系数为 0；trigger 保留但 `refCount=0/listening=false`；notifications durable `1 workflow.created`、`2 workflow.deleted`，三路 SSE 连接无 gap。
- 五通道：screen `375.838333s / 2784x1808 / 60fps`；backend `451` 行无应用 panic/FATAL/WARN/ERROR；frontend `20` 行无 Dart/Flutter/RenderFlex/Unhandled/overflow/lost-device 红线；LLM ready-only（确定性 REST 不虚构 completion）。两条固定格式 AXTree bridge 行经无 Computer Use 基线与 observer control 独立归因到 Flutter macOS 观察器/semantics churn，未知 AX 和应用错误仍 fail-closed。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-049-workflow-delete-final-green.md`，AX 复核 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-049-frontend-ax-review.md`，警报复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-049-ledger-alarm-reaudit.md`。anchors `10/10` 后按 `G1/F2/A5/C4/G2` 写入，账本 `905→910 judgments`，COVERAGE `EP-049=✓✓✓✓✓`。
- 两条统计警报按完整绿证据、负向 REST、SQLite、AX 对照与五通道 session 逐项复审并 ack，阈值与算法未修改，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 181 carried / 0 tombstones`。EP-049 没有源代码修复，试验性 Semantics 包装已撤回；rig-down 后进程归零。
- 批次十八从 **10→15 / 50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 `EP-050 POST /api/v1/workflows/{id}:trigger`。

## 2026-08-07 17:42 · EP-048 PATCH /api/v1/workflows/{id} 五级收口，批次十八 10/50

- 产品目的：真实用户必须能在 Workflow 详情治理卡内调整并发策略，理解五种运行语义，选择通过 meta PATCH 生效且不创建新版本；不能要求用户绕过 App 直接调用 API。
- 首轮真实红 session `/private/tmp/anselm-rig-ep048-workflow-patch-20260807/sessions/20260807-171935` 证明治理卡只有静态 `Concurrency: serial`，AX 树没有操作入口；红证据永久保留，不计绿。
- 第一修复 session `/private/tmp/anselm-rig-ep048-workflow-patch-fix-20260807/sessions/20260807-172937` 已接入下拉，但视觉审查发现五条解释在菜单实际宽度下被省略号截断，继续冻结。
- stop-and-fix：Workflow governance 接入 `AnDropdown<String>`，五项 wire policy 各有中英文 label/hint；提示压缩为可在真实菜单宽度内完整显示的短句，选择沿用 `_patchMeta`，fixture 回归确认不升版本；同步 `make gen` 生成文件、Flutter 文档和测试。
- 最终绿 session `/private/tmp/anselm-rig-ep048-workflow-patch-fix-20260807/sessions/20260807-173308`：真实 App 进入 Workflow 详情，打开菜单完整看到 `Serial / Queue each trigger`、`Skip while running / Drop while running`、`Keep latest / Keep newest pending`、`Replace current / Cancel current run`、`Run in parallel / Overlap runs`；选择 `Keep latest` 后页面回读稳定，v1 不变，无裁切/跳变/错误红面。
- REST `PATCH` 与后续 `GET` 均 200；SQLite 为 `concurrency=buffer_one`、原 `active_version_id`、版本数 1；SSE 收到 durable `workflow.updated`。五通道 manifest/journals/录屏均由 conductor 托管，LLM 本项不触发且不伪造 completion；启动时 rig-check 通过，收台无残留。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-048-workflow-patch-final-green.md`，红证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-048-red-no-concurrency-affordance.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-048-ledger-alarm-reaudit.md`；anchors `10/10`，按 `G1/F2/A1/C4/G2` 写入五格，正式账本 `900→905 judgments`，COVERAGE `EP-048=✓✓✓✓✓`。
- 写账触发的 `gap-too-fast`/`discovery-collapse` 已逐项复审 ack，阈值与算法未修改，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 180 carried / 0 tombstones`。本格本地 `make gen`、Flutter 11 项回归、目标 analyze、Workflow app/handler Go tests 与 `git diff --check` 全绿；批次十八由 **5→10/50**，未满批不跑统一长门禁、不提交。下一原子前线为 `EP-049 DELETE /api/v1/workflows/{id}`。

## 2026-08-07 16:16 · EP-046 GET /api/v1/workflows 五级收口，批次十七 50/50

- 产品目的：真实用户在 Entities 中查看 Workflow 列表、用前缀/精确名称定位、得到诚实的零结果反馈，并能滚动到最后一项；总数不能被已加载行数冒充，分页不能漏行或重复。
- 真实 session `/private/tmp/anselm-rig-ep046-workflow-list-20260807/sessions/20260807-155947` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关。空查询为 Workflow 21，`EP046` 为 21，`EP046-Search-Target` 为 1，零结果显示 `No entities match your search.`；滚动到末端可见 `ep046-list-workflow-01`，21 条全部可达，无裁切/溢出/stale row。
- REST `limit=5` 分页为 `5+5+5+5+1`，首响应 `X-Anselm-Total-Count: 21`，21 名称唯一无重叠；精确/前缀/零结果为 1/21/0；`limit=0`、非数字 limit、坏 cursor 为结构化 400。SQLite 独立为 21 条 live Workflow；对证原始文件在 session evidence。
- SSE 三流连接，notifications durable seq `16..36` 单调唯一，21 条 distinct `workflow.created`；backend 无应用 WARN/ERROR/panic/FATAL；frontend 无 Flutter/Dart/RenderFlex/Unhandled/overflow 应用红线，固定 65 条 AXTree bridge 观察器噪声以 `frontend-ax-review.md` 审阅且 3 秒不增长；LLM tap challenge/install/models 全 200，本确定性列表不需要 completion，不虚构模型证据。
- 正式证据为 `.../sessions/20260807-155947/evidence/EP-046-workflow-list-final-green.md`，屏幕录像 `805.681667s / 2784x1808`；账本警报复审为同目录 `EP-046-ledger-alarm-reaudit.md`。anchors `10/10` 后按 `G1/F2/A5/C4/G2` 写入五格，COVERAGE `EP-046=✓✓✓✓✓`，正式账本 **890→895 judgments**。
- 五格连续写入打开 `gap-too-fast`、尾窗零 fail 打开 `discovery-collapse`；完整录屏、负向 REST/搜索路径、五通道 journal、anchors 和清册一致性已独立复审，阈值与算法未改，逐项 ack 后 `alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 178 carried / 0 tombstones`。
- 批次十七现已 **50/50**；统一收口已通过：根目录 `make verify`、`make -C backend testend`、完整 `testend ./...`、agent/workflow/loop 后端专项、EP-044 Flutter 三组回归、`gofmt`、`git diff --check`、清册/anchors/alarms 检查均全绿；testend/台架进程组归零，工作树无未跟踪文件。本批次进入同一提交固化，下一步不提前进入 EP-047。

## 2026-08-07 15:52 · EP-045 POST /api/v1/workflows 五级收口，批次十七 45/50

- 产品目的：真实用户在 Chat 中要求复用既有 trigger 创建 workflow；模型必须先找到正确 trigger，单次 mutation 创建只有一个 trigger 节点的 v1，保留 description/tags/changeReason，保持 inactive，且 UI 不出现失败卡或 retry。
- 红场一 `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-152351`：Computer Use `type_text` 丢下划线和标点，且模型先发扁平 `nodeId/triggerId`；输入保真问题与产品红证据分离记录，不计绿。
- 红场二 `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-153602`：AX 核对后的精确安全 ASCII 输入仍让模型先发 `nodes`/`edges` 图快照，后端正确拒绝，模型自修后成功；真实 UI 留下 `create_workflow Failed` 与 `Draft unsaved`，冻结为产品红，不计绿。
- stop-and-fix：decoder 增加两种窄兼容：无冲突 `nodeId→node.id`、`triggerId→node.ref` 且仅 trigger；精确 `nodes`+`edges` snapshot 的 `type/triggerId→kind/ref` 确定性展开为 add_node/add_edge。未知键、缺数组、冲突、错误 kind 和任意其它对象 fail-closed；参数 schema、opsDoc、workflow domain、tools 清册和 decoder/Execute 测试同步。
- 最终绿 session `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-154617`：真实 Flutter App、Computer Use、录屏、frontend console、backend、三路独立 SSE、llmtap、受管网关全由 conductor 托管；一次 trigger search + 一次成功 create，无失败/重试。UI 结果表显示 `ep045-snapshot-digest`、描述、`acceptance, workflow, snapshot`、既有 trigger、`Inactive (deactivated)`、v1，Activity 仅一条 Created。
- 后端/SQLite/REST：workflow `wf_64daa9eefc827154`、version `wfv_78be24cae05bd43f`/v1、`active=false`、`lifecycleState=inactive`；唯一节点引用 `trg_f3b9a6e64e4a68e9`，edges 为空；trigger 无重复。SSE 具备 tool/build/`workflow.created`/touchpoint；frontend 无应用级 Dart/Flutter/RenderFlex/Unhandled/overflow；LLM proof/chat 全穿 `https://api.anselm.website`；收台无残留。
- 正式证据 `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-154617/evidence/EP-045-workflow-create-final-green.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-045-workflow-create-ledger-reaudit.md`；anchors `10/10`，按 `G1/F2/A1/C4/G2` 写入五格，正式账本 **885→890 judgments**，COVERAGE `EP-045=✓✓✓✓✓`。两条统计警报按独立复审 ack，阈值算法未修改；`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 177 carried / 0 tombstones`。
- 批次十七由 **40→45/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线：`EP-046 GET /api/v1/workflows`。

---

## 2026-08-07 15:17 · EP-044 GET /api/v1/agent-executions/{id} 五级收口，批次十七 40/50

- 产品目的：Agent Logs 的历史行必须能从轻量列表摘要进入真实单条详情，显示版本、provider/model、输入输出、耗时和完整 transcript；不能渲染空详情壳，也不能为读历史重复调用模型。
- 首个真实红 session `/private/tmp/anselm-rig-ep044-agent-execution-detail-20260807/sessions/20260807-150221` 证明旧实现展开后只有列表字段，没有 transcript，也没有单条详情 GET；红证据永久保留，不计绿。
- stop-and-fix 新增 Agent execution 单读 repository 接线；首次展开 lazy fetch；共享 transcript hydration + `BlockTreeView` 渲染；补齐版本/耗时/开始结束时间；durable close 重取列表时保留已加载详情；同步 Flutter/provider/repository/API/domain 测试与文档。
- 绿 session `/private/tmp/anselm-rig-ep044-agent-execution-detail-20260807/sessions/20260807-150928` 由真实 Flutter App、Computer Use、受管网关和五通道台架完成。最新执行展开后显示 `agv_96efb03aec9f0423`、`3617ms`、`Trace · 2 steps`；点击 Reasoning 后五步 reasoning 完整可读，`1764` text 输出仍在下方；画面无裁切、重叠、空详情或错误红线。
- 五通道：录屏 `121.028333s / 2784x1808 / 60fps`；backend 明确记录列表与 `GET /api/v1/agent-executions/agx_2bb96a87c0d3ce15` `200 / 1159 bytes`，无应用 WARN/ERROR/panic/fatal/4xx/5xx；SSE 三流独立连接并正常收台；frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow 应用红线，仅保留已知 macOS launcher foreground 噪声；LLM tap 绑定 `https://api.anselm.website`，本次历史读取不虚构 completion。
- 正式证据 `/private/tmp/anselm-rig-ep044-agent-execution-detail-20260807/sessions/20260807-150928/evidence/EP-044-agent-execution-detail-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-044-agent-execution-detail-ledger-reaudit.md`；anchors `10/10`，`judge.py` 以 `G1/F2/A1/C4/G2` 写入五格，中央账本 **880→885 judgments**，COVERAGE `EP-044=✓✓✓✓✓`。
- `gap-too-fast` 与 `discovery-collapse` 按独立复审逐项 ack，阈值与算法未修改；`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 176 carried / 0 tombstones`。批次十七由 **35/50→40/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-045 POST /api/v1/workflows`。

## 2026-08-07 14:54 · EP-043 GET /api/v1/agents/{id}/executions 五级收口，批次十七 35/50

- 产品目的：Agent Logs 是执行历史档案，不是右侧运行台的缓存副本；用户要能看到完整分页、真实 aggregates、可展开输入/输出/provider/model，并在 Logs 已打开时自动看到从 REST/其它表面落账的新执行。
- 首个真实负路径 session `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-143107` 抓到未知父 Agent 错误 `200` 空历史。修复后 session `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-143520` 又抓到 UI 真红：右侧已是 `21 total runs`，中间 Logs 仍为 `3 Done / 0 Failed`。两条红证据保留，不计绿。
- stop-and-fix：`SearchExecutions` 先解析父 Agent，未知父变为 `404 AGENT_NOT_FOUND`；`LogListNotifier` 订阅 executable scope 的 durable `FrameClose`，去抖重读当前可见窗口与 aggregates，保留展开行、保留最近可信快照，并保护 load-more 游标；补 app/store/provider 回归测试和 API/domain/frontend 文档。
- 最终真实绿 session `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-144741`：真实 managed gateway `:invoke` 输入 `number=42` 返回 `agx_2bb96a87c0d3ce15`、`ok`、`1764`；已打开 Logs 不刷新即从 `21 Done` 更新到 `22 Done`，右岛同步 `22 total runs · last ok 3.6s`，最新行置顶展开后显示真实 ID、输入/输出、provider `anselm`、model `anselm-auto` 和 `Use this input`。
- REST/SQLite/界面一致：分页 `20+2` 无重叠，aggregate `22/22/0`；`status=failed` 空且聚合诚实；非法 status `422 AGENT_EXECUTION_INVALID_STATUS`；未知父 `404 AGENT_NOT_FOUND`。绿 session 录屏 `183.773333s / 2784x1808 / 60fps`，backend `254` 行，frontend `18` 行，SSE 三流连接且 Agent scope 真实 `open → seq=0 delta → durable close`，LLM proof/chat HTTP 200，收台无残留；前端 raw journal 仅保留已知 macOS launcher foreground 噪声，未隐藏。
- 正式证据 `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-144741/evidence/EP-043-agent-executions-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-043-agent-executions-ledger-reaudit.md`。anchors `10/10` 后按 `G1/F2/A1/C4/G2` 由 `judge.py` 五格落账，中央账本 `875→880 judgments`，COVERAGE `EP-043=✓✓✓✓✓`。
- 写账打开的 `gap-too-fast` 与 `discovery-collapse` 已依据独立复审逐项 ack，阈值与算法未修改；`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 175 carried / 0 tombstones`。批次十七由 **30/50→35/50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `EP-044 GET /api/v1/agent-executions/{id}`。

## 2026-08-07 14:25 · EP-042 GET /api/v1/agents/{id}/versions/{version} 五级收口，批次十七 30/50

- 产品目的：用户从真实 Agent 的 Versions 面板读取数字或 opaque `agv_` 版本 ID 时，结果必须属于当前 Agent；跨父版本和不存在的父 Agent 不能被伪装成成功详情。
- 首个真实负路径 session `/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-141645` 抓到真实缺陷：opaque ID 走全局查找，另一 Agent 的 v4 和未知父 Agent 错误返回 200。红 session 保留，不计绿。
- stop-and-fix 增加 Agent parent-scoped opaque lookup，app 先校验父 Agent，数字/opaque 共用父级边界；补 store/app 回归测试并同步 API/domain 文档。修复后绿 session 为 `/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-142043`。
- REST 矩阵：自有数字/opaque v4、自有数字 v1 为 200；跨父数字/opaque v4 为 `404 AGENT_VERSION_NOT_FOUND`；未知父数字/opaque 为 `404 AGENT_NOT_FOUND`；自有未知数字/opaque 为 `404 AGENT_VERSION_NOT_FOUND`。SQLite 为 active v4、版本 `[4,3,2,1]`；Versions UI 的 v4→v3、v3→v2 diff、v1 完整 prompt 和 earliest version 均可读。
- 五通道：screen `129.010000s / 2784x1808 / 60fps`；backend `196` 行无应用红线；SSE 三流均连接并正常断开，本只读 GET 无 durable mutation frame；frontend `18` 行无 Flutter/Dart/RenderFlex/Unhandled/overflow/失联红线；LLM tap 真实绑定 `https://api.anselm.website`，仅 ready、无虚构 completion；`rig-check`/`rig-down` 封口且无残留。
- 正式证据 `/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-142043/evidence/EP-042-agent-version-detail-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-042-agent-version-detail-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 `870→875`，COVERAGE `EP-042=✓✓✓✓✓`。
- `gap-too-fast`/`discovery-collapse` 依据红绿分离和五通道证据逐条 ack，阈值与算法未修改；`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 174 carried / 0 tombstones`。批次十七 `30/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-043 GET /api/v1/agents/{id}/executions`。

## 2026-08-07 14:15 · EP-041 GET /api/v1/agents/{id}/versions 五级收口，批次十七 25/50

- 产品目的：用户从真实 Agent 详情进入 Versions，能辨认 active v4、按时间阅读 v3/v2/v1，展开可读 diff，并把 v1 识别为 earliest version；分页、数字/opaque 版本寻址和未知边界都诚实。
- 首个正确接线 session `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140230` 暴露真实产品契约缺陷：未知父 Agent 的版本列表错误返回 `200 {data:[],hasMore:false}`。前一条 `8806` 接线错误 session `/private/tmp/anselm-rig-ep041-agent-versions-20260807/sessions/20260807-140126` 也保留并排除。
- stop-and-fix：`agentapp.Service.ListVersions` 先查父 Agent 再分页，未知父实体现在返回 `404 AGENT_NOT_FOUND`；补 `TestService_ListVersionsRequiresExistingAgent`，同步 API/domain 文档。修复后新 binary 的绿 session 为 `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140622`。
- REST 正路径为 `[4,3]`/`[2,1]` 两页，数字/opaque v4 均 200；999、未知 opaque 版本为 `404 AGENT_VERSION_NOT_FOUND`，未知父 Agent 为 `404 AGENT_NOT_FOUND`。SQLite 确认 active v4、版本严格 `[4,3,2,1]`，无 v5 或 mutation。
- 五通道：screen `256.180000s / 2784x1808 / 60fps`；backend `320` 行无应用红线；SSE notifications/messages/entities 三流均连接并正常断开，因只读 GET 无 durable mutation frame；frontend `18` 行无 Flutter/Dart/RenderFlex/Unhandled/overflow/失联红线；LLM tap 真实绑定 `https://api.anselm.website`，无虚构 completion。`rig-check`/`rig-down` 封口且无残留。
- 正式证据 `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140622/evidence/EP-041-agent-versions-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-041-agent-versions-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 `865→870`，COVERAGE `EP-041=✓✓✓✓✓`。
- `gap-too-fast`/`discovery-collapse` 按独立复审 ack，阈值与算法未修改；`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 173 carried / 0 tombstones`。批次十七 `25/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-042。

## 2026-08-07 13:56 · EP-039 POST /api/v1/agents/{id}:iterate 五级收口，批次十七 20/50

- 产品目的：从 Agent 行菜单进入 `Edit with AI`，得到可识别的 AI 编辑对话；seed 读取当前配置，后续用户意图只产生一次 `edit_agent`，新版本立即 active、diff 可读且可执行。
- 正路径 session `/private/tmp/anselm-rig-ep039-agent-iterate-20260807/sessions/20260807-134539` 由同一 conductor 托管真实 App、Computer Use、录屏、backend、三路 SSE、frontend console 和受管网关 tap；对话 `cv_3438427f7e802314` 自动命名，v3→v4 只新增 EP039 receipt 句子，v4 为 `agv_1890517a41cdc11b`。
- UI 真实显示当前配置、unchanged-fields 表、Versions `v3 → v4` diff、一次 Agent Edited 和 `All mounts healthy`；随后 v4 invoke 使用 Function mount 返回 `{"receipt":"EP039","total":0}`，没有 retry/duplicate mutation/stale v3 结果。
- 负路径空 request 返回 `400 EMPTY_ITERATE_REQUEST`，未知 Agent 返回 `404 AGENT_NOT_FOUND`；前后 conversation 数均为 1，版本严格 `[4,3,2,1]`，无 v5 或幻影会话。
- 五通道：screen `301.048333s / 2784x1808 / 60fps`；backend `422` 行无应用红线；SSE notifications `1..3`、messages `1..35`、entities `1..10` 连续；frontend `20` 行无 Flutter/Dart/RenderFlex/Unhandled/overflow/失联红线，仅审计过的 macOS launcher/IMK 平台噪声；LLM tap 25 条记录、8 次 completion response 全 HTTP 200，真实上游为 `https://api.anselm.website`。
- 正式证据 `/private/tmp/anselm-rig-ep039-agent-iterate-20260807/sessions/20260807-134539/evidence/EP-039-agent-iterate-final-green.md`，独立复核 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-039-agent-iterate-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 `860→865`，COVERAGE `EP-039=✓✓✓✓✓`。
- `gap-too-fast`/`discovery-collapse` 按独立复核 ack，阈值与算法未修改；`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 172 carried / 0 tombstones`。机械清册另核对出 EP-040 已有完整五级正式裁决，本轮不重复写账；批次十七 `20/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-041。

## 2026-08-07 13:42 · EP-038 POST /api/v1/agents/{id}:edit 五级收口，批次十七 15/50

- 产品目的：全量 Config snapshot 编辑生成并激活新版本；挂载、inputs/outputs 和历史不丢，真实 App 能重取 lifecycle signal 并展示可读 diff；未知字段不部分落库。
- 正路径 session `/private/tmp/anselm-rig-ep038-agent-edit-20260807/sessions/20260807-133427` 由同一 conductor 托管真实 App、Computer Use、录屏、backend、三路 SSE、frontend console 和受管网关 tap；v3 `agv_76bde4aaf3c188ea` active，UI Overview/Versions/Recent 与 REST/SQLite 一致。
- 台架 shell 插值错误落到 `/agents/dit` 的 404 在有效 mutation 前发生且无副作用，已明确排除；真实未知字段负路径只发一次，返回 `400 INVALID_REQUEST`，版本严格仍为 `[3,2,1]`，无 v4/retry/部分写入。
- 五通道：screen `150.373333s / 2784x1808 / 60fps`；backend `231` 行；frontend `18` 行；SSE 三流仅正路径 `agent.edited` durable seq 1、无 gap；LLM tap ready-only（确定性 REST 不虚构 completion）；应用红线为零，rig-down 无残留。
- 正式证据 `/private/tmp/anselm-rig-ep038-agent-edit-20260807/sessions/20260807-133427/evidence/EP-038-agent-edit-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-038-agent-edit-ledger-reaudit.md`。anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 `855→860`，COVERAGE `EP-038=✓✓✓✓✓`。
- `gap-too-fast`/`discovery-collapse` 因集中写账打开，经独立复核 ack，阈值与算法未修改；`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 171 carried / 0 tombstones`。批次十七 `15/50`，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-039。

## 2026-08-07 13:31 · EP-037 POST /api/v1/agents/{id}:revert 五级收口，批次十七 10/50

- 产品目的：用户能在真实 Agent Versions 中辨认版本与 diff，切换 active 指针；切换后不把旧版本 Trace/Result 冒充新版本产出，同时保留 Recent 审计历史。
- 真实 App 正向路径先将 v2→v1，再临时切到 v2 执行受管网关调用 `subtotal=100,tax=10` 得 `total=110`，最后在结果仍可见时切回 v1；最终画面 v1 active、v2 历史保留、Recent 最新 9.9s 保留、旧 Trace/Result 清空。
- 真实负路径 `version=999` 只调用一次，HTTP `404 AGENT_VERSION_NOT_FOUND`；active v1 不变，无 v3、无 retry。REST/SQLite/UI/SSE/wire 对 `110` 和最终指针一致。
- session `/private/tmp/anselm-rig-ep037-agent-revert-20260807/sessions/20260807-132025`：screen `427.071667s / 2784x1808 / 60fps`；backend 546 行无应用红线；frontend 94 行仅固定格式 AXTree 观察器噪声，session review 记录三秒不增长且无 Dart/Flutter/RenderFlex/Unhandled/overflow；SSE notifications `1..4`、entities `1..10` 单调；LLM proof/chat status 全 200；rig-down 无残留。
- 正式证据 `/private/tmp/anselm-rig-ep037-agent-revert-20260807/sessions/20260807-132025/evidence/EP-037-agent-revert-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-037-agent-revert-ledger-reaudit.md`。`G1/F2/A1/C4/G2` 五级写账，账本 `850→855`，COVERAGE `EP-037=✓✓✓✓✓`。
- 两条统计警报按独立复审 ack，阈值未放宽；`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 170 carried / 0 tombstones`。批次十七 `10/50`，未到 50 格不跑统一长门禁、不提交；下一前线为 EP-038。

## 2026-08-07 13:15 · EP-036 POST /api/v1/agents/{id}:invoke 五级收口，批次十七 5/50

- 首轮真实 App 观察到 stale-result：外部执行 trace 已到达右岛，但旧本地 Result 卡和 Recent 计数未切换；红 session 保留，stop-and-fix 增加 durable close 后账本重取、settled 面板 observed-run reset、controller 回归测试和实体文档。
- 最终 session `/private/tmp/anselm-rig-ep036-agent-invoke-20260807/sessions/20260807-131105`：真实 UI 先跑 `0+0`，再用 REST 发起 `400+60`；右岛最终只显示 `total=460`，Recent 从 8 到 9，工具 trace 与 Result 一致。
- 五通道：screen `177.275000s / 2784x1808 / 60fps`；backend 240 行无应用红线；frontend 17 行无应用红线；三流 SSE durable entities `11..20` 无 gap；LLM tap 请求/响应全 200；SQLite `agx_faf49cf4a927835b` 为 `ok / 460 / 8432ms`；rig-down 无残留。
- 正式证据 `/private/tmp/anselm-rig-ep036-agent-invoke-20260807/sessions/20260807-131105/evidence/EP-036-agent-invoke-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-036-agent-invoke-ledger-reaudit.md`。`G1/F2/A1/C4/G2` 五级写账，账本 `845→850`，COVERAGE `EP-036=✓✓✓✓✓`。
- 两条统计警报按独立复审 ack，阈值未放宽；`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 169 carried / 0 tombstones`。批次十七 `5/50`，未到 50 格不跑统一长门禁、不提交；下一前线为 EP-037。

## 2026-08-07 · 批次十六统一长门禁收口，50/50

- EP-035 完成后按 WRK-093/P15 执行唯一一次批次门禁：根目录 `make verify` 全绿（backend 完整 `go test ./...`、frontend、docs、demo），`make -C backend testend` 全绿，独立 testend 全包 `mise exec -- go test -count=1 -timeout 20m ./...` 全绿。
- Agent/实体后端专项与 Flutter 实体专项全绿；`gofmt`、`git diff --check`、`gen_coverage.py --check`（848 rows / 168 carried / 0 tombstones）、`alarms.py check`（845 judgments）全绿，testend/台架进程组归零。
- 工作树审计通过，EP-027 至 EP-035 的代码、回归测试、COVERAGE 和三份工作记录在本批次一起固化；下一原子前线为 `EP-036`，不提前进入下一格。

## 2026-08-07 11:49 · EP-035 DELETE /api/v1/agents/{id} 五级收口，批次十六 50/50

- 产品目的：用户从真实 Agent 详情的 More actions 进入删除，看到明确的不可逆确认；确认后 Agent 从 active catalog/rail 消失，详情选区回到可用 Overview，关系清空，版本审计保留，重复删除不重复清边或发事件。
- 前置事实：独立 preflight 已完成 Cancel 路径，目标 `ag_4e200525b2c3d63a` 为 `EP034 Meta Edited`、active v1，删除前有一条真实 equip 边；此前错误 llmtap 端口归属 session 按 D1 拒绝报绿，均保留且不混入正式绿证据。用户随后明确确认最终 Delete。
- 真实绿 session `/private/tmp/anselm-rig-ep035-agent-delete-20260807/sessions/20260807-114742` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录屏、frontend console、backend、三路独立 SSE witness 和受管网关 tap。确认后 HTTP DELETE=204；画面最终回到 Overview，Agent=46，目标行消失，无 stale detail/blank pane，关系图 0 entities/0 relations。
- 逐帧审查没有丢中间帧：删除后右岛首次挂载的标准 `AnCountUp` 约 0.5 秒从 0 揭示到 46，rail 权威徽标已经是 46，最终卡片、REST 和 SQLite 均为 46。时间线抽帧保存在 session evidence，按 CODEX B1/B3 判定为新内容首次出现的有界动效，不是 DB 计数错误。
- 五通道：录屏 `325.161667s / 2784x1808 / 60fps`；backend `411` 行，无 panic/FATAL/WARN/ERROR，含 relation purge removed=1；SSE 三流全连接，notifications durable seq 1 为 `agent.deleted`，messages/entities 本确定性删除路径无 mutation frame，不虚构事件且无 gap/error；frontend `26` 行仅两条标准数字节点 AXTree bridge 观测器噪声，session review 已封存，未知 AXTree/Dart/Flutter/RenderFlex/overflow/Unhandled 仍 fail-closed；LLM tap 只有真实受管 gateway ready，本格不需要 completion 不冒充模型证据。`rig-check` 通过，`rig-down` 已封口且无残留。
- REST/SQLite：目标 GET=404 `AGENT_NOT_FOUND`；精确 search 为空/total=0；v1 `agv_815f9ac1a7b414bd` 版本审计仍可读；live relations=0；软删 row 与 version row 保留，execution 为空且诚实。后端回归测试锁定重复 Delete 为 not-found 且不重复 purge/event；Flutter entity rail 28 tests 通过。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-035-agent-delete-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-035-agent-delete-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，正式账本 **840→845 judgments**。`gap-too-fast`/`discovery-collapse` 依据独立复审 ack，阈值未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 168 carried judgments / 0 tombstones`。
- 批次十六由 **45→50 / 50**。统一长门禁、完整 testend、专项回归、工作树审计均已通过；本批次已固化，下一原子前线为 `EP-036`。

## 2026-08-06 17:40 · EP-034 PATCH /api/v1/agents/{id} 五级收口，批次十六 45/50

- 产品目的：用户在真实 Agent 详情中编辑名称、description 和 tags，保存后继续使用同一个 active v1、prompt、mount health 和其它配置；冲突、显式清空和 canonical reread 都必须诚实。
- 首轮真实 Computer Use 冻结输入红线：选区后直接输入没有可靠替换 Flutter 文本控制器，生成拼接名称 `EP034 MixEP034 Meta EditedEP034 Meta Editeded Mounts`；红事实保留在 `/private/tmp/anselm-rig-ep034-agent-meta-20260806/sessions/20260806-173957/screen.mov`、`frames/t180.png`、`frames/t220.png` 与 SSE seq 1，当场 REST 恢复后才继续。
- stop-and-fix 不绕过 Flutter controller，改用清空字段后输入的可靠 Computer Use 路径；真实 App 最终保存 `EP034 Meta Edited`、`Updated independent mount description` 和 tags `ep034`/`mount-health`/`acceptance`。active pointer 仍为 `agv_815f9ac1a7b414bd`、version 1；重复名称 409，`tags=[]` 200 后恢复，未铸造 v2。
- 固定 session `/private/tmp/anselm-rig-ep034-agent-meta-20260806/sessions/20260806-173957`：录屏 `460.890000s / 2784x1808 / 60fps`；backend `547` 行；frontend `19` 行；SSE `11` 行，三流连接且 notifications durable seq 1..7 单调；LLM 真实受管 tap ready、无模型 completion（本格为 metadata REST/UI 路径）；应用红线无，收台无残留。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-034-agent-meta-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-034-agent-meta-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，账本 **835→840 judgments**。`gap-too-fast` 与 `discovery-collapse` 按独立复审 ack，阈值未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 167 carried judgments / 0 tombstones`。
- 批次十六由 **40→45 / 50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为清册 `EP-035 DELETE /api/v1/agents/{id}`。

## 2026-08-06 17:26 · EP-040 GET /api/v1/agents/{id}/mount-health 五级收口，批次十六 40/50

- 产品目的：用户在 Agent 详情里能逐挂载理解 tool/knowledge 健康；坏知识文档解释原因，健康知识文档显示用户可识别的标题，而不是只能看到 opaque ID。
- 首轮真实 Computer Use 冻结红线：混合挂载的红绿状态正确，但健康 knowledge 行只显示 `doc_0304ff76789e4545`；红证据保留于 `/private/tmp/anselm-rig-ep034-agent-mount-health-20260806/sessions/20260806-171415/evidence/ep034-mixed-mount-opaque-name-red.png`。
- stop-and-fix 增加可选 `KnowledgeNamer`，生产 document adapter 从同一 workspace-scoped `GetBatch` 解析标题；命名失败不改变权威健康结果，缺失/无名文档回退稳定 ref；前端 Knowledge 卡与 Mount health 行统一标题 + ref。
- 最终真实 session `/private/tmp/anselm-rig-ep034-agent-mount-health-20260806/sessions/20260806-172201`：API 同时返回缺失文档 `healthy:false,error=knowledge document does not exist` 与健康文档 `name=EP034 Mixed Knowledge two,healthy:true`；Computer Use 真实看到两处标题/ID投影一致。录像 `71.411667s / 2784x1808 / 60fps`，backend `139` 行、frontend `18` 行、SSE `9` 行、LLM `1` 行，五通道通过、红线干净、收台无残留。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-034-agent-mount-health-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-040-agent-mount-health-ledger-reaudit.md`；清册真实编号为 `EP-040`（此前工作记录临时写成 EP-034，已在 §5.2 纠正），按 `G1/F2/A1/C4/G2` 写入 `COVERAGE.md` 为 `✓✓✓✓✓`，账本 **830→835 judgments**。`gap-too-fast`、`discovery-collapse` 因 gate 批次速率与尾窗机械信号打开，独立复审后 ack，阈值未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 166 carried judgments / 0 tombstones`。
- 批次十六由 **35→40 / 50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为清册 `EP-034 PATCH /api/v1/agents/{id}`。

## 2026-08-06 17:10 · EP-033 GET /api/v1/agents/{id} 五级收口，批次十六 35/50

- 产品目的：用户打开 Agent 后能理解 identity、active version、prompt、mount health、能力、I/O 与 Invoke 状态；删除当前实体后不留幽灵详情。
- 真实 App 先走 `EP032 Alpha Planner` 空配置详情，再创建隔离 `EP033 Rich Detail` fixture；Computer Use 真实打开并下滚，看到完整 prompt、输入/输出类型与描述、Workspace default 和稳定的 Invoke 面板。Inputs 一级标题与卡内标题按双列网格局部上下文复核，与同类 Function 详情一致，未判为缺陷。
- 最终 session `/private/tmp/anselm-rig-ep033-agent-get-20260806/sessions/20260806-170359`：录屏 `227.458333s / 2784x1808 / 60fps`；backend `302` 行、frontend `17` 行、SSE `11` 行、LLM witness `1` 行；notifications 收到 `agent.created` seq 1、`agent.deleted` seq 2，三流 EOF 收台，红线扫描干净，收台无残留。
- REST/SQLite/UI 对证：合法单读含完整 activeVersion；未知 id `404 AGENT_NOT_FOUND`；缺失/错误 workspace `401 UNAUTH_NO_WORKSPACE`；临时删除后 live Agent 45，UI 46→45 自动回 Overview。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-033-agent-get-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-033-agent-get-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **825→830 judgments**，COVERAGE `EP-033=✓✓✓✓✓`。两条统计警报按独立复审 ack，阈值未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 165 carried judgments / 0 tombstones`。
- 批次十六由 **30→35 / 50**；未到 50 格，不运行统一长门禁、不提交。此前记录把下一项写成 EP-034；按清册真实编号应为 `EP-040 GET /api/v1/agents/{id}/mount-health`。

## 2026-08-06 16:58 · EP-032 GET /api/v1/agents 五级收口，批次十六 30/50

- 产品目的：用户能在真实实体海洋看到准确 Agent 总数，搜索、清空搜索、滚动 keyset 分页不丢行不重行，REST/UI/SQLite/SSE 与鉴权错误一致。
- 首轮真实 App `/private/tmp/anselm-rig-ep032-agent-list-input-20260806/sessions/20260806-162636` 抓到产品红：45 个 Agent 首屏显示 40，翻页后跳成 45；这不是可接受的分页副作用，冻结并 stop-and-fix。中间修复 session `/private/tmp/anselm-rig-ep032-agent-list-count-fixed-20260806/sessions/20260806-164204` 因复用受管 key 旁路新 tap 被 D1/channel-5 拒绿，不计最终证据。
- 修复保持 N4 body 不变，七类实体列表增加 `X-Anselm-Total-Count`；前端 `Page.total`、rail、Overview 消费精确 header；durable lifecycle 增删改再刷新总数，fixture 与 63 项定向 Flutter 回归覆盖实时计数。
- 最终 session `/private/tmp/anselm-rig-ep032-agent-list-count-fixed-20260806/sessions/20260806-165306`：真实 App 首屏/rail/Overview 为 45，真实输入 `alpha` 为 2，五次 Backspace 恢复 45，滚动后仍 45；REST 三页 `20/20/5`、45 unique、无 overlap，header `45/2/1/0`，body 无 `total`，SQLite live count 45。
- 五通道封口：录屏 `72.431667s / 2784x1808 / 60fps`；backend `162` 行、frontend `19` 行、SSE `8` 行、LLM witness `1` 行，应用级红线扫描干净，三路 SSE 全连接并 EOF 收台，channel 5 经 tap，收台无残留。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-032-agent-list-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-032-agent-list-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **820→825 judgments**，COVERAGE `EP-032=✓✓✓✓✓`。两条统计警报按独立复审 ack，阈值未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 164 carried judgments / 0 tombstones`。
- 批次十六由 **25→30 / 50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为 `EP-033 GET /api/v1/agents/{id}`。

## 2026-08-06 16:08 · EP-031 POST /api/v1/agents 五级收口，批次十六 25/50

- 产品目的：真实用户在 Chat 中创建 Agent 后，identity、完整 Config 快照、v1、名称/描述/tags/prompt 必须真实落库并可由 UI 继续查看。
- 首轮红 session `/private/tmp/anselm-rig-ep031-agent-create-20260806/sessions/20260806-154305` 证明 hosted model 将 `tags` 发成精确 JSON 数组字符串时旧执行边界失败，真实 App 显示 `Create agent failed`；中间固定版 `/private/tmp/anselm-rig-ep031-agent-create-fixed-20260806/sessions/20260806-155712` 又暴露流式脱敏孤立 `)`。两轮均保留为红，不冒充绿。
- stop-and-fix 在 `create_agent` 执行边界接受原生数组或精确 JSON 数组字符串，拒绝逗号 prose/非数组；流式 redactor 对 `id`/`identifier` 括号保持完整后整段移除；新增 agent shape、非法 tags 和 hosted chunk 边界回归。
- 最终真实 session `/private/tmp/anselm-rig-ep031-agent-create-final-20260806/sessions/20260806-160242`：首次 create 成功，唯一 live Agent 为 `ag_e093c9019b049a4e` v1；最终文案 `Agent created successfully: EP031 Planner with tags [acceptance, planner].`，无 placeholder/孤立标点。Computer Use 展开 Created agent 卡看到完整 prompt、description、tags 和 Viewed agent 活动；模型追加一次安全 `get_agent`，无重复 create。
- 五通道：录屏 `157.588333s / 2784x1808 / 60fps`，终帧 `.../evidence/ep031-final-frame.png`；backend `255` 行无应用级红线；三路 SSE 均连接、无 error，messages durable `1..22`、notifications `1..5` 单调，entities 无 mutation frame 不虚构；frontend 无应用级 Flutter/Dart/RenderFlex/Unhandled 红线，仅 macOS foreground/IMK 宿主噪声；受管网关 challenge/install/models/chat completion 全 `200`；REST/SQLite/UI/SSE/wire 一致，收台无残留。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-031-agent-create-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-031-agent-create-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **815→820 judgments**，COVERAGE `EP-031=✓✓✓✓✓`。`gap-too-fast` 与 `discovery-collapse` 按复审文件逐条 ack，阈值未放宽，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 163 carried judgments / 0 tombstones`。
- 批次十六由 **20→25 / 50**；未到 50 格，不运行统一长门禁、不提交。下一原子前线为 `EP-032 GET /api/v1/agents`。

## 2026-08-06 15:39 · EP-030 GET /api/v1/handler-calls/{id} 五级收口，批次十六 20/50

- 产品目的：用户从真实 Handler Logs 展开单条调用后，必须能看到完整 input/output/error/logs/elapsed/time；列表摘要不能掩盖后端已有的运行日志。
- 首轮真实 App session `/private/tmp/anselm-rig-ep030-handler-call-20260806/sessions/20260806-152822` 发现前端只显示 traceback/摘要、没有懒取或呈现 `logs`，冻结为产品红；旧 LLM tap 端口导致的 `/sessions/20260806-152734` D1/channel-5 拒绝保留为台架接线错误，不计产品红。
- stop-and-fix 增加 Live/Fixture `getHandlerCall`，Handler Logs 展开懒加载单调用详情，复用 loading/error/retry，并呈现 logs；补 repository/provider 回归测试和 API 文档。
- 固定 session `/private/tmp/anselm-rig-ep030-handler-call-20260806/sessions/20260806-153325`：Computer Use 看到失败行 `Logs EP029-failure` 与 traceback、成功行 `Logs EP029-stdout` 与 output，`3 Done/2 Failed` 和 Recent rail 稳定，无裁切、重叠或跳变；REST/SQLite 对证 200/200/404/401 边界。
- 五通道封口：录屏 `72.985000s / 2784x1808`；backend `141` 行无应用红线；三路 SSE 全连接，GET-only 无 mutation frame/error；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception/SEVERE 应用红线；LLM tap 只有 ready，不冒充 completion；收台无残留。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-030-handler-call-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-030-handler-call-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **810→815 judgments**，COVERAGE `EP-030=✓✓✓✓✓`，两条统计警报复审后 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 162 carried judgments / 0 tombstones`。
- 批次十六由 **15→20 / 50**；未满 50 格，不运行统一长门禁、不提交。下一原子前线为 `EP-031`。

## 2026-08-06 15:21 · EP-029 GET /api/v1/handlers/{id}/calls 五级收口，批次十六 15/50

- 产品目的：用户能在真实 Handler Logs 中可靠查看调用历史，分页与筛选不丢行，aggregates 与列表/数据库一致；列表轻量，单条详情保留 logs，失败必须可诊断。
- 首轮固定版真实 session `/private/tmp/anselm-rig-ep029-handler-calls-20260806/sessions/20260806-150759` 发现未知 Handler 的 `data.calls=null`，违反 N4 空列表必须为 `[]`，冻结为红；malformed fixture 与错误 URL 已明确排除为台架输入错误并保留。
- stop-and-fix 在共享 `response.Paged` 边界递归规范化嵌套 nil slice，补 `TestPagedEnvelope_NestedEmptyListIsArray` 与 API 文档；固定版 session `/private/tmp/anselm-rig-ep029-handler-calls-20260806/sessions/20260806-151331` 复跑通过：分页 `2+2+1` 无重叠，5 行为 3 ok/2 failed，status/method/version/triggeredBy/空筛选和非法参数矩阵正确，未知 Handler 为 `calls=[]`。
- Computer Use 清除残留搜索后打开真实 Handler Logs：`3 Done`/`2 Failed`、红绿状态、成功 output 与失败 traceback 均可读，列表和 Recent rail 无裁切、重叠或跳变；SQLite、REST、UI、detail logs 一致。
- 五通道封口：录屏 `419.660000s / 2784x1808`；backend `496` 行无应用红线；三路 SSE 全连接且 GET-only 场景无 mutation frame/error；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception/SEVERE 应用红线，仅 macOS IMK 宿主噪声；LLM tap 只有 ready，不冒充 completion；收台无残留。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-029-handler-calls-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-029-handler-calls-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **805→810 judgments**，COVERAGE `EP-029=✓✓✓✓✓`，两条统计警报按复审 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 161 carried judgments / 0 tombstones`。
- 批次十六由 **10→15 / 50**；未满 50 格，不运行统一长门禁、不提交。下一原子前线为 `EP-030 GET /api/v1/handler-calls/{id}`。

## 2026-08-06 14:50 · EP-028 DELETE /api/v1/handlers/{id}/config 五级收口，批次十六 10/50

- 产品目的：清除 Handler 持久化 init-args、停止 resident、让必填缺失可解释，清空后的方法调用必须明确失败；重复 DELETE 保持 204 幂等但不得制造重复 `handler.config_cleared` 通知。
- 首轮真实 session `/private/tmp/anselm-rig-ep028-handler-config-20260806/sessions/20260806-143909` 发现重复 DELETE 发出两条 `config_cleared` durable 帧，冻结为红。stop-and-fix 让 repository `ClearConfig` 返回 changed，SQL 更新增加 `config_encrypted <> ''` 竞态谓词，app 只在真实变化时广播；store/app/tool/transport 单测和真实 `TestHandler_ConfigFlow` 回归通过。
- 修复后 session `/private/tmp/anselm-rig-ep028-handler-config-20260806/sessions/20260806-144550`：恢复配置后正确 `:call` 返回 `label=live-fixed/token_seen=true`；首个 DELETE=204 后 GET 为 `config=null`/`unconfigured`/`missingConfig=[token]`/`stopped`；清空后调用=422 `HANDLER_CONFIG_INCOMPLETE`；重复 DELETE=204 且只留一条 `handler.config_cleared`；未知 Handler=404 `HANDLER_NOT_FOUND`。最终 App 逐帧显示 `v1 · stopped`、`unconfigured`、缺失 token 和真实历史，无 secret 泄漏、陈旧态、裁切、重叠或视觉跳变。
- 五通道：录屏 `92.295000s / 2784x1808`；backend `168` 行无应用 WARN/ERROR/panic/fatal；messages/entities/notifications 全连接，notifications durable 只有 seq 1 `config_updated`、seq 2 `config_cleared`；frontend 无 Dart/Flutter/RenderFlex/Unhandled/Exception 红线；LLM tap 只有 ready（REST-only 路径不冒充模型 completion）；REST/SQLite/UI/SSE/secret scan 一致，收台无残留。精确 secret scan 未命中 `ep028-secret-fixed`/`live-fixed`。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-028-handler-config-clear-final-green.md`，独立账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-028-handler-config-clear-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，正式账本 **800→805 judgments**，COVERAGE `EP-028=✓✓✓✓✓`，两条统计警报按复审证据 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 160 carried judgments / 0 tombstones`。批次十六由 **5→10 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-029。

## 2026-08-06 14:32 · EP-027 PUT /api/v1/handlers/{id}/config 五级收口，批次十六 5/50

- 产品目的：用户只修改 Handler 配置中的目标键时，省略键必须保留，`null` 必须按 JSON Merge Patch 删除可选键，实例必须以新配置重启，敏感值不能泄漏；同一目的必须能从真实 Chat 工具路径完成。
- 真实路径完成：初始未配置 GET 为 `config=null`/`unconfigured`/`missingConfig=[api_key]`；完整 PUT 后为 masked `api_key=********`、`prefix=alpha`、`ready`/`running`；修正冒号路径后 `:call` 返回 `prefix=alpha`/`secret_seen=true`；`prefix=delta` 与 `prefix=null` 均重启，后者回落 `default-prefix` 且 secret 仍为 true。严格 Chat 重跑只执行 `update_handler_config`，将 prefix 改为 `epsilon`，未调用 Handler 方法。
- 固定 session `/private/tmp/anselm-rig-ep027-handler-config-20260806/sessions/20260806-142114` 录屏 `583.983333s / 2784x1808 / 134890529 bytes`；backend `598` 行无应用 panic/fatal/WARN/ERROR，三流 SSE durable `messages 1..66 / entities 7..8 / notifications 16..30` 单调，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，LLM wire 与受管网关真实接线成立，REST/SQLite/UI/secret scan 一致，收台无残留。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-027-handler-config-update-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-027-handler-config-update-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，账本 **795→800 judgments**，COVERAGE `EP-027=✓✓✓✓✓`，两条统计警报按复审记录 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 159 carried judgments / 0 tombstones`。
- 早期 `...dball` 是台架 URL 构造错误；一次探索性 Chat 在重复 `get_handler` 被抑制后额外调用 `state()`。两者均保留在证据并排除出绿路径，严格重跑已按“只用 update 工具并立即停止”通过，不隐藏、不降低门禁。
- 批次十六由 **0→5 / 50**；未满 50 格不运行统一长门禁、不提交。下一原子前线：`EP-028 DELETE /api/v1/handlers/{id}/config`。

## 2026-08-06 14:00 · EP-026 GET /api/v1/handlers/{id}/config 五级收口，批次十五 50/50

- 产品目的：用户读取 Handler 配置时，已配置、未配置、必填项缺失和敏感值必须可解释且安全；未知 Handler 必须明确 not-found，不能伪造配置。
- 真实路径完成：配置 Handler `hd_e00e27a160934cff` 的 GET 为 `200`、`configState=ready`、`api_key=********`、region/retries 保真；未配置 Handler `hd_0ab292edeb52cef2` 的 GET 为 `200`、`configState=unconfigured`、`missingConfig=[api_key]`；未知 `hd_0000000000000000` 为 `404 HANDLER_NOT_FOUND`。真实 App 逐帧展示 ready/masked schema 与 stopped/unconfigured/missing api_key，未泄漏 secret、未裁切、未重叠、无视觉跳变。
- 首个 PUT 探针得到 `405` 是测试命令漏写显式 `-X PUT` 的仪器构造错误；补正后产品 PUT 为 `204`。该事实进入证据和复审，不把台架错误伪装成产品红，也不降低负路径标准。
- 固定 session `/private/tmp/anselm-rig-ep026-handler-config-20260806/sessions/20260806-134441` 由同一 conductor 托管真实 App、录屏、frontend console、backend、三路独立 SSE witness、LLM tap 和受管网关；录屏 `245.513333s / 2784x1808`，收台无残留。backend 无应用 WARN/ERROR/panic，三流 durable seq 单调，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，gateway challenge/install/models 全 HTTP 200；REST/SQLite/UI/SSE/secret scan 一致。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-026-handler-config-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-026-handler-config-ledger-reaudit.md`。anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，正式账本 **790→795 judgments**，COVERAGE `EP-026=✓✓✓✓✓`；原阈值触发的统计警报已依据独立复审逐项 ack，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 158 carried judgments / 0 tombstones`。
- 批次十五由 **45→50 / 50**。统一长门禁已通过：anchors/alarms clean，根目录 `make verify` 全绿，`make -C backend testend` `305.314s`、`testend` 全包 `359.770s`、Handler 后端专项和实体详情 Flutter `7/7` 均通过，gofmt/diff clean，testend 进程组归零；批次已提交 `6ffc44bb`。下一原子前线为 `EP-027 PUT /api/v1/handlers/{id}/config`。

## 2026-08-06 13:58 · EP-025 GET /api/v1/handlers/{id}/versions/{version} 五级收口，批次十五 45/50

- 产品目的：用户从某个 Handler 的 Versions 面板读取数字版本或 opaque `hdv_...` 版本 ID 时，结果必须属于当前 Handler；跨父 ID 必须明确不存在，不能把别的 Handler 的代码伪装成当前版本。
- 首轮真实路径冻结为红：A Handler 读取 B 的 opaque version ID 错误返回 B。红 session `/private/tmp/anselm-rig-ep025-handler-version-get-20260806/sessions/20260806-132936` 与跨父证据永久保留。
- stop-and-fix 增加 parent-scoped repository lookup，数字与 opaque 单版本读取共用父 Handler 边界；同步 store/app/transport、回归测试和 Handler domain 文档。
- 固定真实 session `/private/tmp/anselm-rig-ep025-handler-version-get-fixed-20260806/sessions/20260806-133348` 由 conductor 托管真实 App、Computer Use、录屏、frontend console、backend journal、三路 SSE witness、LLM tap 和受管网关。A 自有数字/opaque 与 B 自有 opaque 均 200；A/cross-parent、未知数字、未知 opaque 均 404 `HANDLER_VERSION_NOT_FOUND`。Versions 画面显示正确 owner 的 v1/stopped/ready/active/source/change reason 和完整代码，无错归属、裁切或跳变；录屏 186.876667s/30MB，收台无残留。
- 五通道：backend 无 WARN/ERROR/panic；messages/entities/notifications 全连接且 durable seq 单调；frontend 无应用级 Flutter/Dart/RenderFlex/Unhandled 红线；llmtap 受管网关 bootstrap 全 200，本确定性路径不把 recorder ready 冒充 completion；REST/SQLite 与 UI 交叉一致。
- 正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-025-handler-version-final-green.md`，独立账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-025-handler-version-ledger-reaudit.md`。anchors 10/10 后按 G1/F2/A1/C4/G2 写入五级裁决，账本 **785→790 judgments**，COVERAGE EP-025=✓✓✓✓✓；gap-too-fast/discovery-collapse 按原阈值独立复审并 ack，alarms.py check clean，gen_coverage.py --check 为 848 rows / 157 carried judgments / 0 tombstones。
- 批次十五由 **40→45 / 50**；未满 50 格不运行统一长门禁、不提交。下一原子前线为 `EP-026 GET /api/v1/handlers/{id}/config`。

## 2026-08-06 13:27 · EP-024 GET /api/v1/handlers/{id}/versions 五级收口，批次十五 40/50

- 产品目的：用户能在 Handler 详情中查看完整版本历史，首屏快速理解当前 active 版本，继续加载后仍能准确到达最早版本，并展开代码核对变更。
- 真实 App 路径：22 个真实版本首屏 v22→v3，`Load more` 追加 v2/v1 后终止；active v22、v22 的 `v21 → v22` diff、v1 的 `earliest version` 和完整代码卡均可达，滚动时无裁切、重叠或异常跳变。录屏 `/private/tmp/anselm-rig-ep024-handler-versions-20260806/sessions/20260806-131758/screen.mov` 为 398.341667s/90MB。
- REST/SQLite 真相：cursor 续页为 20+2、无重复、hasMore 正确；`limit=0/abc` 为 400 `INVALID_REQUEST`，坏 cursor 为 400 `MALFORMED_CURSOR`；SQLite 为 22 个 distinct versions、1..22、active=v22、全部环境 ready。未知父实体的空集合结果按现有版本集合读取语义记录，未擅自改变跨资源契约。
- 五通道：backend journal 499 行且无 WARN/ERROR/panic；messages/entities/notifications 全连接，entities durable 44 帧至 seq 50、notifications 66 帧至 seq 81 且单调；frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线，仅有已知 macOS 调试宿主噪声；受管网关 challenge/install/models 全 HTTP 200，本只读切片无 chat completion。
- 正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-024-handler-versions-final-green.md`，独立账本复审为 `EP-024-handler-versions-ledger-reaudit.md`；anchors 10/10 后按 G1/F2/A1/C4/G2 写入五级裁决，正式账本 780→785 judgments，COVERAGE EP-024=✓✓✓✓✓。原阈值触发的 gap-too-fast/discovery-collapse 已在重读同一五通道证据后 ack，阈值不变，alarms.py check clean；gen_coverage.py --check 为 848 rows / 156 carried judgments / 0 tombstones。
- 批次十五由 35→40 / 50；未满 50 格不运行统一长门禁、不提交。下一原子前线为 `EP-025 GET /api/v1/handlers/{id}/versions/{version}`。

## 2026-08-06 13:10 · EP-023 POST /api/v1/handlers/{id}:iterate 五级收口，批次十五 35/50

- 产品目的：用户从 Handler actions 进入 Edit with AI，在对话中说明修改，模型应读取当前实体、处理 ask-user 回答，用正确的编辑操作铸造新版本，App 要呈现可理解的结果和触点。
- 首轮真实路径先红：模型把既有 status 的 legacy set_methods 全量列表归一成 add_method，后端真实返回 method "status" already exists，UI 出现红色 Update handler failed。红 session /private/tmp/anselm-rig-ep023-handler-iterate-20260806/sessions/20260806-124805 和独立证据保留，不从账本历史抹除。
- stop-and-fix：edit path 读取 active method 名称，既有方法归一为 update_method，新方法归一为 add_method；强化 edit_handler 描述，新增 legacy split regression test，并同步 Handler domain 文档。
- 固定真实 session /private/tmp/anselm-rig-ep023-handler-iterate-fixed-20260806/sessions/20260806-130116 由 conductor 托管 App、Computer Use、录屏、frontend console、backend journal、三路 SSE witness 和 LLM tap。真实 UI 链路完成 ask-user 回答与一次 update_method，最终显示 v2/running、最终说明和 Activity 1 touched；录屏 400.173333s，收台无残留。
- 五通道互证：LLM challenge/install/models 与 chat completions 全 200；wire 最终 mutation 无 set_methods；SSE messages/entities/notifications durable 单调且 close 与 DB 对齐；SQLite 仅有 v1/v2、active=v2；固定路径无应用级 WARN/ERROR/panic 或 Flutter/Dart/RenderFlex/Unhandled 红线，macOS runner/IMK 行单独归类为 host instrumentation noise。
- 正式证据为 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-023-handler-iterate-final-green.md，独立账本复审为 EP-023-handler-iterate-ledger-reaudit.md；anchors 10/10 后按 G1/F2/A1/C4/G2 写入五级裁决，正式账本 775→780 judgments，COVERAGE EP-023=✓✓✓✓✓。
- gap-too-fast 与 discovery-collapse 按原阈值触发后分别复审并 ack，未放宽阈值，最终 alarms.py check clean；gen_coverage.py --check 为 848 rows / 155 carried judgments / 0 tombstones。
- 批次十五由 30→35 / 50；未满 50 格不运行统一长门禁、不提交。下一原子前线为 EP-024 GET /api/v1/handlers/{id}/versions。

## 2026-08-06 12:46 · EP-022 POST /api/v1/handlers/{id}:edit 五级收口，批次十五 30/50

- 产品目的：用户修改既有 Handler 方法后，系统应铸造新版本、让新版本 active、重建环境并重启 resident；App 不能把旧版本结果挂在新版本标题下，随后调用必须执行新代码；非法 method 必须无副作用地失败。
- 最终真实 session `/private/tmp/anselm-rig-ep022-handler-edit-20260806/sessions/20260806-123828` 由 conductor 托管真实 Flutter App、受管 Anselm 网关、Computer Use、窗口录制、frontend console、backend journal、三路独立 SSE witness 和 LLM tap。fixture `hd_f3d9a96f278672d0` v1 首次 Call 后 App 显示 `v1 · running`；真实 `POST :edit` 用 canonical `update_method` 产生 v2 `hdv_6ff081d3ae49ebf6`，App 显示 `v2 · running`/`ready`，旧结果清除；随后 Call 返回 `{"edited":true,"revision":"v2"}`，Recent=2。
- 负路径真实 `does_not_exist` edit 返回 `422 HANDLER_OP_INVALID`，details 明确指出 method 缺失；版本列表仍只有 v1/v2、active v2，无 v3、无重启/调用副作用。
- 五通道：REST 200/422 与 SQLite active/version/call 对齐；两次成功调用钉住不同 resident instance；SSE notifications durable `16..21`、entities `7..10` 单调无 gap，messages/entities/notifications 均连接；受管网关 challenge/install/models 全 200；frontend 无 Dart/Flutter/Unhandled/RenderFlex/overflow 红线。Flutter 启动器的单条 `Failed to foreground app; open returned 1` 随后进入 resident 并完成所有 UI 动作，已在证据中单独归为仪器噪声，未知错误仍 fail-closed。
- 录屏 `191.498333s / 2784x1808 / 60fps`，收台无 conductor 残留。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-022-handler-edit-final-green.md`，session 细节为 `.../evidence/EP-022-handler-edit-green.md`，独立 ledger/alarm 复审为 `EP-022-handler-edit-ledger-reaudit.md`。
- anchors 重新校准 `10/10`；`judge.py` 按 `G1/F2/A1/C4/G2` 写入五级裁决，正式账本 **770→775 judgments**。原阈值触发的 `gap-too-fast`/`discovery-collapse` 已按独立复审分别 ack，未调整阈值，`alarms.py check` clean；`gen_coverage.py --check` 为 `848 rows / 154 carried judgments / 0 tombstones`。
- 批次十五由 **25→30 / 50**；未满 50 格不运行统一长门禁、不提交。下一原子前线为 `EP-023 POST /api/v1/handlers/{id}:iterate`。

## 2026-08-06 12:26 · EP-021 POST /api/v1/handlers/{id}:revert 五级收口，批次十五 25/50

- 首轮真实 v2→v1 回退路径冻结为产品红：主详情已显示 `v1 · running`，但右岛 Run terminal 仍把刚才 v2 的结果卡挂在 v1 标题下。红 session `/private/tmp/anselm-rig-ep021-handler-revert-20260806/sessions/20260806-121633` 已封存；另有一条 fixture-only 的 Python `true`/`True` 构造错误，App 正确显示 `HANDLER_CLIENT_CALL_FAILED` 与 traceback，不计产品绿。
- stop-and-fix 在 `entityDetailProvider` 观察到 active version 真正变化时清除 Run terminal 的已落定瞬时结果，保留方法/来源选择和 durable Recent 台账；同步 controller、RunTerminal 监听、回归测试与 frontend entities 文档。定向 controller 测试最终 **10/10**，目标 `flutter analyze` clean。
- 最终 session `/private/tmp/anselm-rig-ep021-handler-revert-fixed-20260806/sessions/20260806-122413` 使用新 binary、真实 App、Computer Use、受管网关、三路独立 SSE witness、frontend console、backend journal、LLM tap 和录屏完成绿重跑。Versions → v1 → More actions → Set active 后画面显示 `v1 · running`、`ready`、`Active version: v1`，旧 v2 结果消失而 `Recent · 1` 保留；随后真实 Call 返回 `version=v1`，Recent 增至 2。
- REST/SQLite 真相：两条不可变版本均保留，meta 不变；成功调用各自钉住 v2/`hdi_78d4625216b3e876` 与 v1/`hdi_74e7075fa48dee05`；`version=99` 返回 `404 HANDLER_VERSION_NOT_FOUND`，active pointer 不变。SSE durable `handler.created`/`handler.edited`/`handler.reverted` 为 seq `16/19/22`，三流无 gap；受管网关 challenge/install/models 全 HTTP 200。
- 五通道封口：录屏 `145.865000s / 2784x1808 / 60fps`；rig-check 五通道全绿，frontend/backend 无 Dart/Flutter/Unhandled/RenderFlex/overflow/panic/FATAL/ERROR/WARN 红线；AXTree bridge churn 由 session-scoped review 归类为已知 macOS Flutter 调试仪器噪声，未知形状仍硬失败；rig-down 无残留进程。
- 正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-021-handler-revert-final-green.md`，账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-021-handler-revert-ledger-reaudit.md`，红证据和五通道细节在两套 session evidence 中。anchors `10/10` 后写入 `G1/F2/A5/C4/G2`，中央账本 **765→770 judgments**，COVERAGE `EP-021=✓✓✓✓✓`；写账触发的 gap-too-fast/discovery-collapse 按独立复审逐项 ack，阈值未放宽，最终 `alarms.py check` clean。
- 批次十五由 **20→25 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-022`。

## 2026-08-06 12:04 · EP-020 POST /api/v1/handlers/{id}:restart 五级收口，批次十五 20/50

- 首轮真实 Handler `:call` 成功后冻结为产品红：resident 已被惰性拉起，REST/SQLite 为 `runtimeState=running`，但 Handler detail 仍显示 `v1 · stopped`。stop-and-fix 在 Handler call 收尾后 invalidate detail provider，重新读取 server-owned runtime state；修复同步到 controller、回归测试和 frontend entities 文档。
- 最终 session `/private/tmp/anselm-rig-ep020-handler-restart-fixed-20260806/sessions/20260806-120431` 使用最终 binary、真实 App、Computer Use、受管网关、三路独立 SSE witness、frontend console、backend journal、LLM tap 和录屏完成绿重跑。首次 Call 后 UI 显示 `v1 · running`、`ready`、`Done`；Restart instance 原地完成且不铸新版本；第二次 Call 的 Recent 为 2。REST/SQLite 为同一 active version `hdv_b075d14eefb8e00f`、两个真实 resident instance `hdi_51fd8207eeaa0161` 与 `hdi_da984cee7bc1fdf`、两次成功调用。
- 负路径用真实未配置必填 `token` 的 `ep020_restart_blocked` Handler 执行 Restart，UI 显示 `Handler “ep020_restart_blocked” restart failed · View`，后端返回 `422 HANDLER_CONFIG_INCOMPLETE`，没有实例、调用行或成功事件伪影。
- 五通道封口：录屏 `200.308333s / 2784x1808 / 60fps`；SSE `handler.restarted` 成功 durable seq `16`、失败 seq `20..22`，无 gap；backend/frontend/LLM tap 全部来自同一 manifest，受管网关 challenge/install/models 全 HTTP 200；AXTree bridge churn 作为 macOS Flutter 调试仪器噪声独立复核，应用红线扫描无 Dart/Flutter/Unhandled/overflow，收台无残留进程。
- 正式证据为 `sessions/20260806-120431/evidence/EP-020-handler-restart-green.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-020-handler-restart-ledger-reaudit.md`。定向 controller 测试 `9/9`、目标 `flutter analyze` 通过；anchors `10/10` 后写入 `G1/F2/A5/C4/G2`，账本 **760→765 judgments**，`gen_coverage.py --check` 为 `848 rows / 152 carried judgments / 0 tombstones`。写账产生的 gap-too-fast/discovery-collapse 按独立复审逐项 ack，阈值未放宽，最终 `alarms.py check` clean。
- 批次十五由 **15→20 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-021`。

## 2026-08-06 11:53 · EP-019 POST /api/v1/handlers/{id}:call 五级收口，批次十五 15/50

- 首轮真实 Handler `:call` 成功路径通过；失败路径冻结为红：后端 N1 `details` 中已有用户错误和 Python traceback，但右岛只显示通用 `HANDLER_CLIENT_CALL_FAILED`。stop-and-fix 将 `ApiException.details` 接入运行状态，并增加双语 details 标题；最终真实重跑又发现 JSON 字符串转义让 traceback 难读，继续修为结构化键值 + 真实换行 + 8000 字硬上限。
- 最终 session `/private/tmp/anselm-rig-ep019-handler-call-final-20260806/sessions/20260806-114857` 使用新 binary、真实 App、Computer Use、受管网关、独立三路 SSE witness、frontend console、backend journal、LLM tap 和录屏完成。成功方法真实显示 `Done`、`ep019-call-start` 和 `{"ok":true,"value":7}`；失败方法真实显示 `Failed`、`HANDLER_CLIENT_CALL_FAILED`、`ep019-before-failure`，details 区域逐行呈现 `ValueError: ep019 expected failure`。录屏 `176.410000s / 2784x1808 / 60fps`，最终截图 `EP-019-handler-call-final-failure.jpeg`。
- 五通道交叉核验：backend `POST ...:call` 成功 200、失败 502，SQLite/REST 调用聚合为 `1 ok/1 failed`、同一 resident instance、v1 不变；SSE entities `open/delta/close` durable seq `9..12` 单调且 delta 为 seq=0，messages/notifications 均已连接；LLM challenge/install/models 全 200，本确定性调用无 completion；frontend/backend 无未解释应用红线，收台无残留进程。
- 修复同步到 `run_terminal_state`/controller/UI、`entity_format`、双语 i18n 与回归测试；证据为 session `evidence/EP-019-green.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-019-handler-call-ledger-reaudit.md`。定向 controller **8/8**、run terminal UI **7/7**、目标 analyze 通过；`rig-check.sh` 五通道全绿，`rig-down.sh` 正常封口。
- 显式 formal root anchors `10/10` 后，`judge.py` 写入 `G1/F2/A5/C4/G2`，中央账本 **755→760 judgments**，COVERAGE `EP-019=✓✓✓✓✓`。写账触发 `gap-too-fast` 与 `discovery-collapse`；依据独立复审逐项 ack，阈值未放宽，最终 `alarms.py check` clean。
- 批次十五由 **10→15 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-020 POST /api/v1/handlers/{id}:restart`。

## 2026-08-06 11:35 · EP-018 DELETE /api/v1/handlers/{id} 五级收口，批次十五 10/50

- 真实 App 首先通过 Handler rail 的 More actions 打开删除菜单；Computer Use 逐帧确认弹窗明确写出对象 `order_desk`、从 active catalog 移除和不可撤销。第一次 Escape 取消后 row/detail 保持不变；第二次确认后 Handler count 从 `1` 变 `0`，详情回 Overview，不留死详情。
- 真实 session `/private/tmp/anselm-rig-ep018-handler-delete-20260806/sessions/20260806-112755` 由同一 conductor 托管 App、窗口录制、backend、三路 SSE witness、frontend console 和 llmtap。录屏 `246.323333s / 2784x1808 / 60fps`；确认截图和删除后 Overview 截图均已封存。
- HTTP/SQLite 真相：DELETE `204`；live list `[]`；GET `404 HANDLER_NOT_FOUND`；重复 DELETE `404 HANDLER_NOT_FOUND`；versions 仍 `200` 保留单一 v1 审计行。Handler `deleted_at` 非空，sandbox env 行和 filesystem path 消失，relation 无残留。
- durable 真相：notifications 表与 SSE 均记录 `sandbox.env_deleted` → `handler.deleted`；notifications durable seq `16,17` 连续无 gap。frontend/backend 扫描无 panic/FATAL/WARN/ERROR/Flutter/Dart/RenderFlex/Unhandled 红线；受管 gateway challenge/install/models 全部真实 HTTP 200，本确定性删除 slice 无模型 completion，未伪造 wire。
- `rig-check.sh` 在收台前五通道全绿；`rig-down.sh` 优雅停止所有归属进程并封口录像。正式证据为 `evidence/EP-018-green.md`，警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-018-ledger-reaudit.md`。
- 定向验证：`go test ./internal/app/handler ./internal/transport/httpapi/handlers` 通过；`entity_rail_test.dart` **27/27**；目标 Flutter analyze 无问题。显式 formal root 下 anchors `10/10`，`judge.py` 写入 `G1/F2/A5/C4/G2`，中央账本 **750→755 judgments**，COVERAGE `EP-018=✓✓✓✓✓`；两条统计警报经独立复审后 ack，`alarms.py check` clean。
- 批次十五由 **5→10 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-019 POST /api/v1/handlers/{id}:call`。

## 2026-08-06 11:09 · EP-017 PATCH /api/v1/handlers/{id} 五级收口，批次十五 5/50

- 首轮真实 App 证据冻结为红：Handler Overview 只有只读 description，没有 tags 入口，用户不能完成 Handler 元数据维护；红截图保留在 `/private/tmp/anselm-rig-ep017-handler-patch-20260806/sessions/20260806-104925/evidence/EP-017-red-handler-meta.png`，不计绿。
- stop-and-fix 将 Handler 接入与 Function/Workflow 一致的 `AnKv` meta surface：description 与 tags 可编辑，成败都重读 canonical detail；`HANDLER_INVALID_NAME` 在实体 rail 显示具体本地化错误；同步 `entities.md` 与 detail section 规则。
- 修复后真实 session `/private/tmp/anselm-rig-ep017-handler-patch-20260806/sessions/20260806-105636` 由同一 conductor 托管 Flutter App、窗口录像、backend、三路独立 SSE witness、frontend console 和 llmtap。Computer Use 从空 description/tags 开始输入并提交，最终 UI 为 `edited from empty field`、`from-ui`、`v1 · running`、`ready`，无错误卡、假版本或重启跳变。
- 五通道封口：`screen.mov` `559.990000s / 2784x1808 / 60fps` 可读；notifications durable `1..4` 单调无 gap，messages/entities 连接且本路径无额外 durable mutation；SQLite 只有 `hdv_9dd804b9b99233da` v1，最终 resident `bump` `status=ok` 返回 `{"count":1}`；HTTP 负路径保留非法名称 400 `HANDLER_INVALID_NAME` 和未知 ID 404；frontend 无未解释 Flutter/Dart 红线，llmtap 受管网关线缆 ready/wiring 通过。
- 同类复查发现 description/tags 保存失败误用了 `renameFailed` 文案；stop-and-fix 增加 `metaSaveFailed` 双语键，并同步 Function/Workflow 的同类异常路径。新 binary 真实 session `/private/tmp/anselm-rig-ep017-handler-patch-20260806/sessions/20260806-111449` 重新从空 meta 完成 Computer Use 输入，最终为 `rechecked metadata`/`recheck-tag`，录屏 `159.730000s / 2784x1808 / 60fps`，notifications durable `1..3` 无 gap，SQLite 仍为单一 v1，resident `bump` 仍成功；frontend/backend 扫描无未解释应用红线。
- 代码验证：目标 entity `flutter analyze` 无问题；`go test ./internal/domain/handler ./internal/transport/httpapi/handlers ./internal/app/handler` 通过；`an_kv_test.dart` 6/6 通过。首轮正式证据保留为 session 内 `evidence/EP-017-green.md`；最终证据为新 session 内 `evidence/EP-017-recheck-green.md`，最终独立警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-017-recheck-ledger-reaudit.md`。
- 显式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 下先以 `anchors.py check` 重校 10/10，再由 `judge.py` 用新证据写入 `G1/F2/A5/C4/G2`，中央账本 **745→750 judgments**，COVERAGE `EP-017=✓✓✓✓✓`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 按新红绿历史、五通道证据和原阈值独立复审后 ack，`alarms.py check` clean；批次十五仍为 **5 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-018 DELETE /api/v1/handlers/{id}`。

## 2026-08-06 10:15 · EP-016 GET /api/v1/handlers/{id} 五级收口，批次十四 50/50

- 真实 App session `/private/tmp/anselm-rig-ep016-handler-get-20260806/sessions/20260806-100548` 完成 Handler 详情用户路径：Computer Use 逐帧确认名称、v1、stopped、unconfigured、activeVersion、Python 3.12、必填 sensitive `api_key`、默认 `region`、`ping` 方法和 source，REST/SQLite 证明 configState、runtimeState、missingConfig、schema 与未知 ID 404 一致。
- 五通道来自同一 conductor manifest：封口 `screen.mov` `292.240000s / 2784x1808 / 60fps`，messages/entities/notifications 三路 SSE 已连接且 durable entities `7..8`、notifications `16..20` 无 gap，backend journal、frontend console、LLM tap 均无未解释应用红线。清理 DELETE=204 后 GET=404，SQLite 仅保留软删 handler/version 审计，临时 env 已回收。
- 正式证据 `evidence/EP-016-green.md` 通过 `G1/F2/A5/C4/G2` 五级裁决，中央账本由 **735→740 judgments**；anchors `10/10`。`gap-too-fast` 与 `discovery-collapse` 以 `evidence/EP-016-alarm-reaudit.md` 独立重读后 ack，`alarms.py check` clean，阈值未放宽。
- 批次十四由 **45→50 / 50**，因此进入统一长门禁、完整 testend、警报复核、工作树审计和提交阶段；下一原子前线为 `EP-017 PATCH /api/v1/handlers/{id}`。
- 收口门禁结果：根 `make verify` 全绿（backend、frontend、docs、demo；Flutter 四组共 `5204` tests）；`make -C backend testend` 全量场景通过（`290.174s`）；`testend` module `go test -count=1 -timeout 30m ./...` 全包通过（场景 `327.947s`）；无 `anselm-server`、`llama-server` 或 testend 残留进程。复核 `gen_coverage.py --check`、anchors `10/10`、`alarms.py check` 和 `git diff --check` 均通过。

## 2026-08-06 07:48 · EP-011 GET /api/v1/functions/{id}/versions/{version} 五级收口，批次十四 25/50

- 首轮真实 App session `/private/tmp/anselm-rig-ep011-functions-20260806/sessions/20260806-073520` 冻结为红：A 的 opaque 版本详情接受了 B 的版本 ID 并返回 B；代码审查还发现 `:run` 显式版本 ID 没有 function parent scope。红证据保留，不计绿。
- stop-and-fix 增加 parent-scoped version lookup，详情 opaque-ID 路由与显式 Function run 共用；同步 repository/store/app/transport、黑盒回归和 function API/domain 文档。fixed session `/private/tmp/anselm-rig-ep011-functions-20260806-fixed/sessions/20260806-074225` 用新 workspace、新 A/B fixture 和 A v2 真实重跑。
- Computer Use 走 `Entities → Function → A → Versions`：v2 active、真实 change reason、`+1 −1` diff、v1 可展开并显示 `v1 · earliest version` 与完整代码；无错归属、裁切或视觉跳变。A/B own opaque ID 与数字版本 200，A/cross-parent B ID 与 unknown ID 404，A 显式 v1 run 返回 owner A。
- 清理 DELETE A/B=204，之后 GET A/B=404；SQLite 保留 2 条 soft-deleted function、3 条 version、1 条 execution audit。五通道为 `screen.mov` `284.375s / 2784x1808 / 60fps`、SSE 三流各连接一次且 entities `1..6`/notifications `1..14` durable seq 单调、backend/frontend 无未解释应用红线、llmtap proof/install/models 全 HTTP 200；deterministic 路径无 completion，不冒充 recorder ready。
- 正式证据为 `EP-011-green.md`，红绿账本复审为 `EP-011-ledger-alarm-reaudit.md`。显式正式根下五级 `G1/F2/A5/C4/G2` 使账本 **710→715 judgments**；anchors `10/10`，两条新警报经独立复审后 ack，最终 `alarms.py check` clean。批次十四由 **20→25 / 50**，下一原子前线为 `EP-012 GET /api/v1/functions/{id}/executions`。

## 2026-08-06 07:30 · EP-010 GET /api/v1/functions/{id}/versions 五级收口，批次十四 20/50

- 真实 App session `/private/tmp/anselm-rig-ep010-functions-20260806/sessions/20260806-072203` 构造 21 个真实 Function 版本并打开 Versions 页面；首屏显示 v21→v2 共 20 条和 Load more，续页唯一显示 v1，v21 active，v21 diff 为 `v20 → v21`、`+1 −1`，v1 展开显示 `v1 · earliest version` 和完整代码。三张稳定截图已封存，未发现裁切、错位或不可解释跳变。
- REST 与 UI 交叉核验：首页 20 条、cursor 续页 1 条，顺序与 change reason/code 完全一致；`limit=0/abc` 为 400 `INVALID_REQUEST`，坏 cursor 为 400 `MALFORMED_CURSOR`。清理后 DELETE=204、主实体 GET=404、live list 移除；版本历史仍可读，符合 API 文档的不可变审计历史约定。
- 五通道：封口 `screen.mov` 为 `456.258333s / 2784x1808 / 60fps`；messages/entities/notifications 三流均连接，entities durable `1..42`、notifications durable `1..85` 单调，entities delta 为 seq=0；backend 无 panic/FATAL/WARN/ERROR，frontend 无 Flutter/Dart/Unhandled/连接错误；llmtap 真实记录 proof challenge、install、models 全 HTTP 200，本旅程无模型 completion，不冒充 recorder ready。
- 正式账本在显式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 下由 **705→710 judgments**，COVERAGE `EP-010=✓✓✓✓✓`；`gap-too-fast` 与 `discovery-collapse` 按 `EP-010-ledger-alarm-reaudit.md` 独立重审后 ack，anchors `10/10`，最终 `alarms.py check` clean。批次十四由 **15→20 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-011 GET /api/v1/functions/{id}/versions/{version}`。

## 2026-08-06 07:17 · EP-009 POST /api/v1/functions/{id}:iterate 五级收口，批次十四 15/50

- 首轮真实 App session `/private/tmp/anselm-rig-ep009-functions-20260806/sessions/20260806-065426` 冻结为红：实体 rail 的 `Edit with AI` 发出 generic opening，最终 chat 标题为 `Help me make changes to this`，用户无法确认正在编辑哪个 Function；红截图和完整 journal 保留，不计绿。
- stop-and-fix 将前端固定 opening 改为带所选 Function 名称的双语请求，并在后端增加 whitespace-only request 守卫与 regression test；同步 i18n 生成物、entity rail 测试、aispawn 测试、API 文档。随后 fixed3 新 binary 的真实 App session `/private/tmp/anselm-rig-ep009-functions-20260806-fixed3/sessions/20260806-070454` 重新完成同一路径：真实 Function 名称同时出现在 user bubble、chat header 和 mention snapshot，助手读取同一 Function，composer 保持可继续编辑；没有 retry、第二个 conversation 或隐藏 mutation。
- 负向边界逐一真实核对：未知 Function `404 FUNCTION_NOT_FOUND`、空/空白 request `400 EMPTY_ITERATE_REQUEST`、malformed JSON `400 INVALID_REQUEST`，conversation 数量在边界调用前后不变；清理阶段 Function 与 conversation 均 DELETE=204，随后 GET=404。REST/SQLite、touchpoint、tool call/result 和 UI 事实一致。
- 五通道：`screen.mov` 封口 `408.985000s / 2784x1808 / 60fps`；backend 554 行、无 panic/FATAL/WARN/ERROR；SSE durable messages `1..18`、entities `1..2`、notifications `1..8` 单调，delta seq=0；LLM tap 12 个响应全 HTTP 200，4 个 request body 留档；frontend 无 Dart/Flutter/RenderFlex/Unhandled/Exception 红线。唯一 223 行精确 `accessibility_bridge.cc` AXTree 观察器提示在 `evidence/frontend-ax-review.md` 中作 session-scoped tooling review，未知格式仍硬失败。
- 账本 gate 在显式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 下写入 `G1/F2/A5/C4/G2`，中央账本 **700→705 judgments**，COVERAGE `EP-009=✓✓✓✓✓`；写账触发 `gap-too-fast` 与 `discovery-collapse`，由 `evidence/EP-009-ledger-alarm-reaudit.md` 逐项复审并 ack，anchors `10/10`，最终 `alarms.py check` clean。批次十四由 **10→15 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-010 GET /api/v1/functions/{id}/versions`。

## 2026-08-06 · EP-008 POST /api/v1/functions/{id}:edit 五级收口，批次十四 10/50

- 首轮真实 App 发现助手正文把 opaque `Version ID` 脱敏成 `the requested item`；fixed2 负向又发现畸形 `ops` 被普通 Go error 映射为 HTTP 500。两份红证据均保留，不计绿；stop-and-fix 分别增加跨 provider chunk 的 Version ID 占位整行/句式脱敏，以及 `ParseOps` 到 `FUNCTION_OP_INVALID` 的结构化 422 映射，并补 loop/function 测试和 chat/function 领域文档。
- fixed3 session `/private/tmp/anselm-rig-ep008-functions-20260806-fixed3/sessions/20260806-064400` 以新 binary、真实 onboarding、真实 Flutter App、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal 和 174.058333s 录屏完成绿重跑：按名称定位已有 Function，保持 value，只把 version v1 改为 v2，`edit_function` 恰一次；UI 只显示一张 Updated v2 活动卡，环境 ready，正文无 placeholder 或错误卡。
- 五通道交叉核验：screen `2784x1808/60fps`；messages/entities/notifications durable seq 分别 `1..42`、`1..8`、`1..9` 唯一单调；LLM 20 个响应全 HTTP 200；backend/frontend 无未解释应用红线。REST/SQLite 证明 active v2、历史恰有 v1/v2、v1 未变、执行数为 0；空 ops 200 只重建 env、畸形 ops 422 且 mutation 前真相不变。Function 与内置 conversation 已真实 DELETE=204 清理。
- `judge.py` 已在显式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 独立写入 `G1/F2/A5/C4/G2`，中央账本 **695→700 judgments**，COVERAGE `EP-008=✓✓✓✓✓`。写账触发 `gap-too-fast` 与 `discovery-collapse`，复审证据 `EP-008-ledger-alarm-reaudit.md` 已逐项 ack，anchors `10/10`，最终 `alarms.py check` 为 `clean (700 judgments)`；阈值未放宽。批次十四从 **5 / 50** 推进至 **10 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-009 POST /api/v1/functions/{id}:iterate`。
# WRK-092 · 验收战役日志

## 2026-08-06 10:00 · EP-015 GET /api/v1/handlers 五级收口，批次十四 45/50

- 主真实 App session `/private/tmp/anselm-rig-ep015-handlers-20260806/sessions/20260806-094604` 用 44 个真实 Handler 加 seed 行验证了 Entities rail 的 `20+20+5` cursor 续页、顺序、末页和 45 行边界；Computer Use 真实输入 `ep015-handler-3` 得到 10 条 `ep015-handler-39..30`。
- 独立干净 replay `/private/tmp/anselm-rig-ep015-handlers-20260806/sessions/20260806-095453` 从空字段真实输入 `ep015-no-such-handler`，AX 树显示精确查询和 `No entities match your search.`，无把空态伪装成加载失败。
- REST 同一 workspace 交叉核验三页 `20/20/5`、`hasMore`、search、空结果、`limit=0 → 400 INVALID_REQUEST`；清理 44 个临时 Handler 全部 DELETE=204、搜索为空、已删 GET=404。SQLite 为 `handlers_total=45/live=1/ep015_deleted=44`、44 个版本保留、临时 env 回收。
- 五通道：主 `screen.mov` `317.096667s`、两个 clean replay `66.646667s/37.375000s` 均 ffprobe 可读；SSE 独立连接三流，主 durable entities `7..94`、notifications `16..147` 连续无 gap，messages 无 durable 变更；llmtap bootstrap 全 200；backend/frontend 无未解释应用红线。
- `set_value` 造成的隐藏输入串接被重复复现并作为 Computer Use 仪器限制隔离，未进入绿证据；精确搜索与精确空态均从 clean keyboard input 重跑。正式证据 `EP-015-green.md`，空态补证 `EP-015-empty-search.md`，警报复审 `EP-015-alarm-reaudit.md`。
- 显式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 下 `G1/F2/A5/C4/G2` 使账本 **730→735 judgments**；anchors `10/10`，两条统计警报经独立五通道复审后 ack，`alarms.py check` clean。批次十四 **40→45 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-016 GET /api/v1/handlers/{id}`。

## 2026-08-06 09:40 · EP-014 POST /api/v1/handlers 五级收口，批次十四 40/50

- 首轮真实 App 与后端 journal 保留了多种 hosted model legacy Handler op 形状；stop-and-fix 增加有限、确定性的兼容翻译，明确 Handler 的 canonical `add_method` 协议，不把 Function 的 `set_code` 语义冒充成功。
- compat8 绿路径又冻结一个产品视觉红线：脱敏器将不可用 ID 表格行变成空行，Flutter 表格因此隐藏真正的 `ping` 方法。修复为物理移除该行，补 durable close 与流式 redaction 回归；compat9 新 binary 重跑通过。
- Computer Use 最终画面显示 `Handler ep014compat 已创建完成`、名称、Python 3.12、`ping` 无输入且返回 `{pong: true}`、Init 参数无、版本 v1，并明确说明未调用该方法；无 opaque ID、空表格断行、retry 或错误卡。
- 同一 session `/private/tmp/anselm-rig-ep014-handlers-20260806-compat9/sessions/20260806-093450` 的 REST/SQLite 事实为 create `201`、GET env/config ready 与 runtime stopped、未知字段 `400 INVALID_REQUEST`、真实 `:call` 返回 `pong=true`、调用聚合 `1 ok/0 failed`，清理 DELETE `204` 后 GET `404`；版本/env/调用审计按约保留。
- 五通道封口：`screen.mov` `189.793333s` 可读；messages/entities/notifications 三路均连接，durable seq 单调无 gap；llmtap 全 HTTP 200；backend/frontend 无未解释应用红线。正式证据 `EP-014-green.md`，独立警报复审 `EP-014-alarm-reaudit.md`。
- 显式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 下 `G1/F2/A5/C4/G2` 使正式账本 **725→730 judgments**；anchors `10/10`，`alarms.py check` clean。批次十四 **35→40 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-015 GET /api/v1/handlers`。

## 2026-08-06 08:32 · EP-013 GET /api/v1/function-executions/{id} 五级收口，批次十四 35/50

- EP-012 已明确保留的边界在真实 App 中完成 stop-and-fix：执行列表保持轻量（2 条真实执行与 `1 ok/1 failed` aggregates，列表不携带 `logs`），展开 Logs 行时才调用单执行详情 GET。
- 真实 Function `ep013_logs2` 跑出 `n=2` 成功和 `n=7` 失败两条执行。REST 单详情分别返回完整 input/output/logs/timing 与 traceback；伪造 ID 返回 404 `FUNCTION_EXECUTION_NOT_FOUND`。UI 的失败行显示 ID、trigger、version、input、error、logs、elapsed、local time；成功行的 Computer Use accessibility state 也包含 input/output/logs。
- 五通道封口：session `/private/tmp/anselm-rig-ep013-functions-20260806/sessions/20260806-082436` 的 `screen.mov` 为 `346.728333s / 2784x1808`；SSE 三流连接并记录 function create/run/error/delete durable 帧，LLM tap proof/install/models 全 HTTP 200，frontend 无 Flutter/Dart/Unhandled/AXTree 红线，backend 无 panic/FATAL。收台后 `ffprobe` 可读。
- 清理两枚临时 Function：DELETE 均为 204，live list 为空；SQLite 为 `live_functions=0`、`deleted_functions=2`、`execution_rows=2`。第一次 zsh 错误拼接 `:run` 产生的两个 `...fn...un` 404 保留在 backend journal，已明确归类为测试命令错误，不计产品红。
- 正式证据 `EP-013-green.md`，账本复审 `EP-013-ledger-alarm-reaudit.md`。显式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 下五级 `G1/F2/A5/C4/G2` 使账本 **720→725 judgments**；anchors `10/10`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按复审证据 ack，`alarms.py check` clean。批次十四由 **30→35 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-014 POST /api/v1/handlers`。

## 2026-08-06 08:10 · EP-012 GET /api/v1/functions/{id}/executions 五级收口，批次十四 30/50

- 首轮真实 App session `/private/tmp/anselm-rig-ep012-functions-20260806/sessions/20260806-075245` 冻结为红：真实 Function 产生 22 条执行（18 success、4 failed），REST aggregate 正确为 18/4，但 Overview 只显示最近 5 条推导出的 `5 today`，Logs 列的 UTC 时间也没有转换为本地时间；红截图和 backend/frontend/SSE/LLM journal 保留，不计绿。
- stop-and-fix 将 `totalCount` 从 function/handler/agent/mcp domain/store 贯通到 API contract 和 frontend `RecentRunsSnapshot`，Overview 改用服务端总量，`fmtTime` 统一 `DateTime.toLocal()`；同步双语 i18n、生成物、回归测试和 API/domain 文档。
- fixed session `/private/tmp/anselm-rig-ep012-functions-20260806-fixed/sessions/20260806-080821` 以新 binary + 真实 onboarding + 受管网关 + Computer Use 重跑：Overview 显示 `22 total runs`，Logs 显示 `18 Done`/`4 Failed`、本地 `2026-08-06 08:10`；失败行展开有 ID/trigger/version/input/error/elapsed/time，Load more 后 22 行完整可达，无重复活动、错误卡或视觉跳变。
- 五通道封口：`screen.mov` `258.726667s / 2784x1808 / 60fps`；三路 SSE 均连接，entities durable `1..46`、notifications `1..5` 单调，messages 本路径无 durable 消息；llmtap 10 条 bootstrap/proof/install/models 记录；backend/frontend journal 无 panic/FATAL/WARN/ERROR/Flutter/Dart/Unhandled 红线。SQLite 保留 22 条 execution 审计；Function DELETE=204 后 GET=404，live function 为零。
- 正式证据为 `evidence/EP-012-green.md`，独立警报复审为 `evidence/EP-012-ledger-alarm-reaudit.md`。显式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 下五级 `G1/F2/A5/C4/G2` 使账本 **715→720 judgments**；anchors `10/10`，`alarms.py check` clean。批次十四由 **25→30 / 50**，未满 50 格不跑统一长门禁、不提交。
- 刻意保留的下一格边界：列表接口不带每条 execution 的 `logs`，当前前端没有调用 `GET /api/v1/function-executions/{id}` 的懒加载路径；EP-013 专门验证单次详情的 logs/input/output/error 是否真正交付用户。下一原子前线为 `EP-013`。

## 2026-08-06 · EP-007 POST /api/v1/functions/{id}:revert 五级收口，批次十四 5/50

- 真实 App session `/private/tmp/anselm-rig-ep007-functions-20260806/sessions/20260806-060152` 在 Versions 面板通过 `Set active` 完成 v2→v1 回退。UI 保留 v1/v2 历史，active 标记、顶部状态和右侧运行结果均切到 v1；这是版本指针变化，不制造新版本，也不删除旧版本。
- 五通道对证：REST 带参数执行返回 `rest-v1`/`version=v1`；非法 v99 返回 `FUNCTION_VERSION_NOT_FOUND` 且 active pointer 不变；SQLite 的 function/version/execution/notification 真相与 `function.reverted` durable SSE 帧一致。三路 SSE、backend、frontend console、LLM tap、录屏和 manifest 均保留；LLM tap 只记录真实网关 bootstrap/ready，没有伪造模型 completion。
- 第二 session 通过真实 DELETE=204、GET=404、live list 为空完成清理；SQLite 保留 soft-delete，notifications 有 `function.deleted`，清理不改写第一台架的产品证据。录屏固定帧 `evidence/ep007-after-revert.jpg` 和 `evidence/ep007-final-clean.jpg` 可读；`ep007-run-v1.jpg` 的坐标输入中间非法 JSON 明确不作为绿证据。
- Computer Use 的 `set_value` 绕过自定义编辑器回调，坐标输入还原 JSON 时出现中间错误；该现象被记录为仪器/输入限制，未借其生成正向断言，也未发现产品代码红线。frontend journal 中的 `accessibility_bridge` 是已知 AX 观察器噪声，除此之外无 Flutter/Dart/RenderFlex/Unhandled 应用红线；`rig-check` 保留该已知失败，不静默过滤。
- 正式五级 `G1/F2/A5/C4/G2` 已用显式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 写入，中央账本 **690→695 judgments**；`gap-too-fast` 与 `discovery-collapse` 已由 `evidence/EP-007-ledger-alarm-reaudit.md` 独立重审并 ack，阈值未放宽，`alarms.py check` clean。批次十四当前 **5 / 50**，未满批不跑统一长门禁、不提交；下一原子前线为 `EP-008 POST /api/v1/functions/{id}:edit`。

## 2026-08-06 · EP-006 POST /api/v1/functions/{id}:run 五级收口，批次十三 50/50

- 真实 App session `/private/tmp/anselm-rig-ep006-functions-20260806/sessions/20260806-053154` 完成 Example → Run 正向路径两次执行和非法 JSON 负向路径。正向 UI 显示 `Done`、73ms 与 `count=0/kind=args/value=""`；负向真实输入 `A` 显示 `Payload must be valid JSON.`，Run 置灰，点击不增加 Recent 执行数。
- REST、SQLite 与 backend journal 对齐两条 `ok/manual` execution；三路 SSE 在动作前均连接。ready env 的同步 Function run 按代码只写执行审计、不发布实体/消息帧，因此 ssetap 零帧是预期结果而不是漏收；frontend 仅静态 macOS IMK 噪声，LLM tap 记录 ready，无模型请求。
- 录屏封口 `528.990000s`，五通道证据为 `evidence/EP-006-real-app.md`；临时 fixture 随后真实 DELETE=204、GET=404、搜索为空。五级 `G1/F2/A5/C4/G2` 写入 COVERAGE，正式账本 `685→690`，写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按 `evidence/EP-006-ledger-alarm-reaudit.md` 重审并 ack，最终 `alarms.py check` clean。
- 早先五次 judge 未显式导出 `RIG_HOME`，记录保留在默认账本作错路由审计；权威五格已用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 正式重放。下一原子前线为 `EP-007 POST /api/v1/functions/{id}:revert`；批次十三达到 50/50，统一长门禁待运行。

## 2026-08-06 · EP-005 DELETE /api/v1/functions/{id} 五级收口，批次十三 45/50

- 首轮真实 App session `/private/tmp/anselm-rig-ep005-functions-20260806/sessions/20260806-045736` 发现确认框只说 `“ep004-meta-function-45” will be removed.`，没有告诉用户不可撤销；该次只打开后取消，红证据保留。stop-and-fix 将实体删除确认改为双语 active-catalog removal + irreversible consequence，并补精确 i18n widget assertion、entities 文档规则和生成代码。
- 修复后二次真实 session `/private/tmp/anselm-rig-ep005-functions-20260806/sessions/20260806-050031` 用 Computer Use 走实体 rail → More actions → Delete → Confirm；固定确认帧和删除后 Overview 帧已封存，录屏 `209.958333s / 2784x1808 / 60fps`，UI 没有裁切、按钮拥挤或 stale detail route。删除后通过真实 API 创建替代 fixture，不编辑 SQLite。
- 五通道对证：backend `DELETE` 为 `204` 且无应用 WARN/ERROR/panic/FATAL；REST 为目标 `404 FUNCTION_NOT_FOUND`、搜索空、live list 44 条不含目标；SQLite 保留软删 `deleted_at` 与 v1，环境/执行记录/关系边清理；notifications durable seq `1..2` 严格为 `sandbox.env_deleted` → `function.deleted`，三流均连接；LLM tap 为真实 upstream `ready`，deterministic menu 路径没有模型调用，不冒充 request/response。
- frontend journal 仅有两条相同的 macOS AXTree bridge 观察器噪声，静置 5 秒不增长，零 Flutter/Dart/RenderFlex/Unhandled 应用红线；`rig-check` 的该失败输出保留并按 `testend/rig/README.md` 已知动态 AX 规则分流，没有隐瞒。正式证据为 `evidence/EP-005-formal-acceptance.md`，账本复审为 `evidence/ep-005-ledger-alarm-reaudit.md`。
- 正式账本 `/private/tmp/anselm-rig-formal-20260801-3` 由 **680→685 judgments**，五级 `G1/F2/A5/C4/G2` 已写入 `COVERAGE` 的 `EP-005 DELETE /api/v1/functions/{id}` 行；写账触发的 `gap-too-fast` 与 `discovery-collapse` 经重新校准 anchors `10/10`、独立五通道复审后 ack，正式 `alarms.py check` clean。中途发现 shell wrapper 不导出结构化 env，五条初始命令误写默认账本；误路由行与默认警报均保留审计并销警，正式水位只认显式 `RIG_HOME` 重放。批次十三由 **40→45 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-006`。

## 2026-08-06 · EP-004 PATCH /api/v1/functions/{id} 五级收口，批次十三 40/50

- 真实 App session `/private/tmp/anselm-rig-ep004-functions-20260806/sessions/20260806-044310` 复用 `fn_23da72e9518042de` fixture，完成无效名称、有效名称和恢复 canonical name 三条路径；无效名称的 PATCH 为 `400 FUNCTION_INVALID_NAME`，有效名称与恢复均为 `200`，侧栏/详情最终都回到 `ep004-meta-function-45`，notifications durable seq `1..2` 单调。录屏、backend、SSE、frontend console 由同一 manifest 归属，`rig-down` 干净收台。
- 首轮产品红线是异步 metadata PATCH 失败后编辑器仍退出并把错误伪装成保存成功。stop-and-fix 让 `AnInlineEdit` 等待 `Future` 完成：失败保留 draft 和编辑态，调用错误回调并展示完整规则；成功才退出并刷新 canonical truth。最终 notice 为 `Lowercase; a-z 0-9 - _; 1–64.`，截图 `ui-invalid-name.png`、`ui-valid-name.png`、`ui-restored.png` 已封存。
- 独立 session `/private/tmp/anselm-rig-ep004-functions-20260806/sessions/20260806-044956` 校准 channel-5 recorder：真实 `llm.jsonl` 有 `event=ready` 与 `upstream=https://api.anselm.website`，同时保留 screen/backend/SSE/frontend journals。该 journey 没有模型调用，ready 只证明 recorder 在线和上游绑定，不冒充 LLM request/response；`rig-check` 五通道通过。
- 正式证据为 `sessions/20260806-044956/evidence/ep-004-functions-patch-formal.md`，账本复审为 `ep-004-ledger-reaudit.md`。正式账本 `/private/tmp/anselm-rig-formal-20260801-3` 由 **675→680 judgments**，五级 `G1/F2/A5/C4/G2` 已写入 `COVERAGE` 的 `EP-004 PATCH /api/v1/functions/{id}` 行；`gap-too-fast` 与 `discovery-collapse` 按复审证据串行 ack，`alarms.py check` clean。批次十三由 **35→40 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-005`。

## 2026-08-06 · EP-003 GET /api/v1/functions/{id} 实机五级收口，批次十三 35/50

- 最终 session `/private/tmp/anselm-rig-ep003-functions-20260806/sessions/20260806-035647` 由同一 manifest 托管真实 Flutter App、窗口录屏、backend、三路 SSE witness、frontend console 和 LLM tap；复用 EP-002 的 45 个真实 Function fixture，D1 attribution 和五通道 `rig-check` 通过，`rig-down` 干净收台。
- 真实产品路径从 Entities rail 打开 `ep002_function_45`，详情一次呈现 `v1 · ready`、描述、tags、完整 Python code、Inputs/Outputs 空值 em dash、Python 3.12、env ID、同步时间和 Dependencies；滚动检查 Environment 区域与右侧 run terminal 无覆盖、裁切或几何跳变。REST 同时证明成功 `200` 的 activeVersion 与缺失 `fn_missing_ep003` 的 `404 FUNCTION_NOT_FOUND`，无伪造详情。
- 同一最终会话发送一次真实受管网关消息并收到精确 `function detail witness ready`。录屏 `163.976667s / 2784x1808`；backend 无 panic/FATAL/WARN/ERROR/validation/tool-execution failure；SSE messages durable `1..8`、notifications `1..2` 单调，entities 已连接；frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线，仅有已知 macOS IMK 系统诊断；LLM challenge 与两次 chat completion 完成响应全为 HTTP 200。
- EP-003 没有发现产品或代码红线，不产生 stop-and-fix。正式证据为 `evidence/ep-003-function-get-green.md`，终帧为 `evidence/ep-003-final-detail.jpg`，API 摘要为 `evidence/function-probes-summary.json`。
- anchors `10/10`；正式账本根 `/private/tmp/anselm-rig-formal-20260801-3` 五级 `G1/F2/A5/C4/G2` 由 **670→675 judgments**，COVERAGE `EP-003=✓✓✓✓✓`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 依据 `evidence/ep-003-ledger-reaudit.md` 复审并串行 ack，未放宽阈值，最终 `alarms.py check` clean。批次十三由 **30 / 50** 推进至 **35 / 50**；EP-003 是本批新增的一行五格，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-004 PATCH /api/v1/functions/{id}`。

## 2026-08-06 · EP-002 GET /api/v1/functions 实机五级收口，批次十三 30/50

- 最终 session `/private/tmp/anselm-rig-ep002-functions-20260806/sessions/20260806-034541` 由同一 manifest 托管真实 Flutter App、窗口录屏、backend、三路 SSE witness、frontend console 和 LLM tap；创建 45 个真实 Function fixture，收台后保留 45 条 fixture 回执，D1 attribution 和五通道 `rig-check` 通过。
- 真实产品路径完成 Entities rail 的 20→40→45 加载、三页 `20+20+5` cursor 分页、filtered search、非法 limit、上限 limit 和 no-match 搜索。前置观察发现 no-match 变成无解释空白 rail；stop-and-fix 增加 `filterEmptyLabel` 与中英文 `No entities match your search.`，普通空 workspace 结构不变。
- 同一最终会话又完成一次真实受管网关 chat，App 收到 `pagination witness ready.`。录屏 `151.576667s` 可读；backend 无 panic/FATAL/WARN/ERROR/validation/tool-execution failure；SSE 三流连接且 messages durable `1..8`、notifications `1..2` 单调；frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线；LLM tap 完成响应均 HTTP 200。
- 定向 frontend tests `41/41`，`make -C frontend gen`、Dart format、`git diff --check` 通过。产品证据为 `evidence/ep-002-functions-green.md`，警报复审为 `evidence/ep-002-ledger-reaudit.md`。
- anchors `10/10`；正式账本 `/private/tmp/anselm-rig-formal-20260801-3` 五级 `G1/F2/A5/C4/G2` 由 **665→670 judgments**，COVERAGE `EP-002=✓✓✓✓✓`。写账后 `gap-too-fast` 与 `discovery-collapse` 按复审证据串行 ack，未放宽任何阈值，最终 `alarms.py check` clean。批次十三由 **25 / 50** 推进至 **30 / 50**；EP-002 是本批新增的一行五格，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-003 GET /api/v1/functions/{id}`。

## 2026-08-06 · EP-001 最终代码五通道重验证，批次十三仍 25/50

- 代码审查发现 EP-001 绿会话之后仍有一个审计真相问题：通用 provider 参数归一化被记成 `get_flowrun` 专属 `argumentRepair`；同时 `edit_function` 已声明兼容形状但没有在 `ValidateInput` 阶段校验畸形 `ops`。stop-and-fix 已补通用审计原因、写前校验、`null`/重复 required 守卫及 Go 回归，未放宽公开 schema。
- 最终代码 session `/private/tmp/anselm-rig-ep001-auditfix-20260806/sessions/20260806-032244` 由 conductor 同时托管真实 Flutter App、窗口录屏、backend、三路 SSE witness、frontend console 和 LLM tap，并重新完成 onboarding、受管免费网关、`create_function` 与真实 `run_function`。provider wire 的外层 `ops` 是 JSON 字符串；durable `message_blocks`/SSE 已规范化成四项 native ops，attrs 为 `argumentRepair=provider arguments normalized by tool boundary`；function v1/env `ready`，execution `ok`，输入 `{"celsius":100}`，输出 `{"fahrenheit":212}`。
- 五通道结果：`rig-check` 通过 D1、health、SSE、LLM tap、Flutter runner 和录屏归属；`screen.mov` 封口 `200.358333s` 可读；messages/entities/notifications durable seq 分别 `1..26`、`1..2`、`1..5` 单调；LLM 完成响应全 200；backend/frontend 无未解释应用红线，仅有已知 macOS IMK 输入法诊断。最终证据为 `evidence/ep-001-audit-fix-green.md`。
- 正式账本五格以 `G1/F2/A5/C4/G2` 追加最终代码证据，**660→665 judgments**；这是同一 `EP-001` 覆盖行的复验，不增加覆盖单元，批次十三保持 **25 / 50**。批写触发的 `gap-too-fast` 与 `discovery-collapse` 由 `evidence/ep-001-auditfix-ledger-reaudit.md` 记录复审后 ack，anchors `10/10`，最终 `alarms.py check` 为 `clean (665 judgments)`。`gen_coverage.py` 已携带新证据，下一原子前线为 `EP-002 GET /api/v1/functions`；未到 50 格不跑统一长门禁、不提交。

## 2026-08-06 · EP-001 POST /api/v1/functions 实机五级收口，批次十三 25/50

- 前置真实 App 会话连续发现并保留三条红证据：外层 `ops` JSON 字符串化导致首轮 retry；成功正文的 ID 行被脱敏成 `the requested item`；嵌套 `set_inputs/set_outputs` 字段形状不兼容导致 retry。三轮均停在红线上修复，未计入绿。
- stop-and-fix 在 `create_function/edit_function` 执行边界加入窄兼容：合法 JSON 数组字符串、无歧义字段 map、完整覆盖 properties 的 JSON-Schema 均还原为 canonical flat fields；CSV/prose/歧义/不完整 required 继续拒绝。同步工具描述、function/API 文档、抽取清册和 Go 回归。opaque ID 表格行改为删除坏占位，精确 ID 保留在可展开、可复制的工具卡。
- 正式绿 session `/private/tmp/anselm-rig-ep001-green3-20260806/sessions/20260806-030648` 由同一 manifest 托管真实 Flutter App、backend、三路 SSE witness、LLM tap、前端 console 和录屏；只调用一次 `create_function`，SQLite 只有一个函数/v1、`env_status=ready`，消息块中的 tool call 已是规范化 native arrays，助手正文无坏占位。五通道证据为 `evidence/ep-001-formal-green-provider-shapes.md`，录屏 `337.441667s`，收台无残留进程。
- anchors `10/10`；正式账本根 `/private/tmp/anselm-rig-formal-20260801-3` 的五级裁决为 `G1/F2/A5/C4/G2`，账本 **655→660 judgments**，COVERAGE `EP-001=✓✓✓✓✓`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 `evidence/ep-001-ledger-alarm-reaudit.md` 独立复审并 ack，阈值未放宽，最终 `alarms.py check` clean(660)。`gen_coverage.py --check` clean(848 rows, 133 carried judgments, 0 tombstones)。批次十三由 **20 / 50** 推进至 **25 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-002 GET /api/v1/functions`。

## 2026-08-06 · TOOL-124 enroll_voice 实机五级收口，批次十三 20/50

- session `/private/tmp/anselm-rig-tool124-live-20260806/sessions/20260806-022721` 由同一 manifest 托管真实 Flutter App、backend、三路 SSE witness、LLM tap、窗口录像和 cleanup；`rig-check` 通过，`rig-down` 正常收台，`screen.mov` 可读且无残留进程。
- 真实用户目的链路为：生成短参考音频 → 解释持久音色身份和有限库存 → `enroll_voice` 危险人闸批准 → 网关登记 → 用 `acceptance-narrator` 复用生成音频 → Settings 读取 `1 of 2 slots free` → 用本地音色行删除 → `/voices` 回到空集、remaining=2。参考附件 `att_353b3737368b9dbf` 为 WAV 157484 bytes/3.280000s；复用附件 `att_e06c667a3db58ac3` 为 WAV 169004 bytes/3.520000s；网关句柄 `vce_23b241a4e1789dd687ab954eef2dc39d` 与本地行 `vce_b905053ec7c7c2eb` 的边界已交叉核对。
- 五通道证据封存于 `evidence/tool-124-enroll-voice-formal-20260806.md`：messages durable `1..52`、notifications `1..2` 单调，entities 已连接且 ephemeral delta 为 seq `0`；LLM wire 的 speech/create/upload/delete 状态与 SQLite、REST、tool result、UI 一致；backend/frontend 无未解释 runtime 红线。Computer Use 中文输入丢失作为仪器限制记录，英文主路径正常完成。
- 首轮产品红线：Settings 将音色 GET 失败显示成空库存。stop-and-fix 改为明确错误状态 + `Retry`，补 fixture failure hook、双语文案、`voices_card_test.dart` 6/6、`flutter analyze` 和 settings 领域规则；不以空状态伪装连接失败。
- 正式账本根 `/private/tmp/anselm-rig-formal-20260801-3` 的五级裁决为 `G1/F2/A5/C4/G2`，账本从 `650` 增至 **655 judgments**，anchors `10/10`；`gap-too-fast` 与 `discovery-collapse` 用 `evidence/tool-124-ledger-alarm-reaudit.md` 独立复审并 ack，未放宽阈值，最终 `alarms.py check` clean。COVERAGE 已由生成器携带为 `TOOL-124=✓✓✓✓✓`，`gen_coverage.py --check` clean(848 rows, 0 tombstones)。批次十三 **20/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-001 POST /api/v1/functions`。

## 2026-08-06 · TOOL-123 animate_image 实机五级收口，批次十三 15/50

- API Serve 修复提交 `0d06f6e58615fec2fd04e3c15d16aea2edaf4aef` 已由 CI `31029509745` 与 production deploy `31029785594` 成功发布；真实受管 `/models` 明示 I2V 能力后，才启动本轮真实 App，不把部署绿当产品绿。
- session `/private/tmp/anselm-rig-tool123-live-20260806/sessions/20260806-020305` 完成真实用户路径：生蓝色帆船图 → 危险 `animate_image` 人闸批准 → I2V 提交/轮询/媒体上传 → 保存 5 秒 MP4 → 播放至 `0:05 / 0:05` → 重播 → 全屏 → 退出全屏。源附件 `att_88a52e72d00ccc1f`、视频附件 `att_5863a6340ae60b18` 的 receipt、SQLite、SSE、UI 和 LLM 线缆一致。
- 五通道正式证据为 `sessions/20260806-020305/evidence/tool-123-animate-image-formal-20260806.md`；647.886667 秒 `screen.mov` 可读，messages durable `1..38`、notifications `1..2` 按流单调，ephemeral delta 保持 seq=0，I2V `202`、轮询 `200`、媒体上传 `201`、最终对话 `200`，backend/frontend 无未解释 runtime 红线。首帧 `go run ./cmd/measure compare` 为 `changedFrac=0.1009`、pass=true，源图构图与首帧均保持帆船左侧、右侧开阔水面。
- 首轮 session `/private/tmp/anselm-rig-tool123-live-20260806/sessions/20260806-015946` 的 AXTree 红证据保留；冷启动稳定等待后的 `/020305` 无 AXTree/Flutter/Dart 红线。前端 loading/error/retry 修复由 34 项定向媒体测试与 `flutter analyze` 锁定。
- 正式 ledger 根为 `/private/tmp/anselm-rig-formal-20260801-3`：anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已写入，正式账本 `645→650 judgments`，COVERAGE `TOOL-123=✓✓✓✓✓`。五级批写触发 `gap-too-fast` 与 `discovery-collapse`，独立复审证据为 `tool-123-ledger-alarm-reaudit.md`，两项均已 ack，阈值未放宽，最终 `alarms.py check` clean(650)。
- 期间一次未 export `RIG_HOME` 的 L1 误写入默认旧账本；默认账本保留原始审计且已销账，正式 L1 已在 formal 根重放，后续只允许显式 formal 根。批次十三从 `10/50` 推进至 `15/50`，未到 50 格不跑统一长门禁、不提交；下一格为 `TOOL-124 enroll_voice`。

## 2026-08-06 01:28 · TOOL-123 API Serve 精确 SHA 已成功部署，产品裁决仍冻结

- 邻仓提交 `0d06f6e58615fec2fd04e3c15d16aea2edaf4aef` 已推送 `main`；CI run `31029509745` 的 hygiene、SBOM、frontend drift、race/integration/fuzz/coverage、vulnerability 与 lint 全绿。
- 同一 SHA 触发 production deploy run `31029785594`：admission 通过，`build-test-deploy` 未被跳过并在 5m16s 内完成全部复验、静态 linux/amd64 构建和 pinned SSH schema-aware 发布。远端安装器报告 `deploy gate OK on 0d06f6e58615`、`public API healthz is green`、`public static site is green`。
- 本机独立请求 `https://api.anselm.website/healthz` 返回 `200 {"status":"ok"}`；未带设备证明的 `/v1/models` 返回预期 `401 DEVICE_PROOF_REQUIRED`，公网入口与证明边界均在线。下一步用台架真实 install 响应跑 `check_i2v_contract.py`，通过后才进入 App 五通道和 exact-first-frame 复验。
- 旧 `changedFrac=0.99601` 红证据不撤销，`TOOL-123=·····`、中央账本 645、批次十三 10/50 均不变；部署绿不等于产品绿，本次不提交主仓。

## 2026-08-05 06:53 · TOOL-123 增加 I2V 实机前置哨兵，真实探针诚实拒绝

- 新增 `testend/rig/check_i2v_contract.py`，读取 llmtap 保存的原始或 gzip `/models` 响应；只有 `video_generation.available=true`、`image_to_video=true`、`routing=content` 和有效 capability version 同时满足才返回 0，缺失契约返回 2，不写产品账本。
- 对真实 session `/private/tmp/anselm-rig-tool123-probe/sessions/20260805-063224/llm-responses/00003_v1_models.bin` 执行结果为 `i2v: unavailable`，与先前五通道红证据和 API Serve clean 状态一致。该哨兵避免下一次 loop 在工具诚实缺席时盲起真实 App。
- `test_i2v_contract.py`、`test_gen_coverage.py`、`test_judge.py` 共 6 项通过；`gen_coverage --check` clean(848 rows)、`make -C docs verify`、`git diff --check`、正式 `alarms.py check` clean(645) 通过。本轮没有 judge pass、没有推进 `10/50`、没有提交。

## 2026-08-05 06:50 · 清册生成器只读校验与 848 行基线复核

- 机械复核确认 `COVERAGE.md` 与生成器的真实基线为 **848 行 × 5 = 4240 格**，不是旧日志中的 827 行；`TOOL-121/122` 既有 `✓✓✓✓✓` 与 `TOOL-123` 的 `·····` 均保留，未写入账本。
- 发现并修复台架自身的写入风险：原 `gen_coverage.py --help` 会直接重生成清册。现在默认无参数仍显式重生成，`--check` 只读检查漂移，`--help` 只显示帮助；新增 `test_gen_coverage.py` 覆盖帮助不写盘与漂移检查。
- 本地验证：Python 回归 `3` 项通过，真实 `python3 testend/rig/gen_coverage.py --check` clean，帮助命令前后清册 hash 一致，`git diff --check` 通过；本轮不写 `judge.py`，批次十三仍 `10/50`。

## 2026-08-05 06:46 · TOOL-123 上游模型边界一手文档复核，红线保持

- 阿里云 Model Studio 一手文档将 `wan2.7-t2v` 明确列为文生视频；首帧图生视频使用独立的 `happyhorse-1.1-i2v` 或 `wan2.7-i2v`。因此 API Serve 当前把 `img_url` 送进 T2V 端点，不足以形成 I2V 或 exact-first-frame 契约；不能为了推进覆盖而放宽 Anselm 的能力闸。
- 证据链接已同步到 `docs/references/backend/managed-gateway.md`。本轮没有改 API Serve，没有启动新的高成本 App 视频轮次，没有写 `judge.py`；`TOOL-123` 继续 `·····`，批次十三仍 `10/50`。
- 本地验证：`mise exec -- go test ./internal/infra/llm ./internal/app/tool/generate` 通过，`make -C docs verify` 通过，`git diff --check` 通过，正式 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check` 为 `clean (645 judgments)`；API Serve `main...origin/main` clean。

## 2026-08-05 06:32 · TOOL-123 线上 I2V 能力声明复核，红线保持

- 为避免把上一轮正式视频红证据当作静态历史，conductor 以独立数据目录启动真实 backend、llmtap 和 SSE tap（App/录像刻意关闭），真实创建 workspace 并完成受管 install/probe；session 为 `/private/tmp/anselm-rig-tool123-probe/sessions/20260805-063224`。
- 原始网关响应 `llm-responses/00003_v1_models.bin` 是 gzip 保存，解压后的 `/v1/models` 明确包含 `video_generation.available=true`，但没有 `image_to_video`。同一时刻 API Serve 仓 `main...origin/main` 无 diff；源码存在 `/v1/videos/animations` 与 `img_url` 上游线缆，却没有在能力 catalog 发布 I2V 明示。
- 同步复核厂商一手模型文档：`wan2.7-t2v` 被列为文生视频；首帧图生视频使用独立的 `happyhorse-1.1-i2v` 或 `wan2.7-i2v`。因此当前网关把 `img_url` 送进 `wan2.7-t2v` 不能证明 I2V，exact-first-frame 红线是上游模型/配置契约问题，不是 Anselm 可以靠放宽闸门修正的客户端问题（来源见 `docs/references/backend/managed-gateway.md`）。
- 该探针没有启动真实 App、没有提交视频、没有产生五级裁决或账本写入；它只确认当前部署仍是 T2V-only 能力声明。Anselm 的 fail-closed 闸保持不变，`TOOL-123` 继续 `·····`，批次十三仍 `10/50`，中央账本仍 645，不能把缺少契约的路由猜成绿。
- 探针由 `rig-down.sh` 正常收台，backend/ssetap/llmtap 无残留；探针 session 与原始线缆证据保留。
- 同轮本地长回归随后完成：`mise exec -- go test ./...`（`testend/scenarios`）全绿，用时 `362.072s`；它覆盖真实二进制黑盒但不改变受管网关能力声明，也不替代 `TOOL-123` 的真实 App 五通道正式重跑。

# 2026-08-05 06:16 · 关停红线 stop-and-fix 后真实收台通过，TOOL-123 仍红，10/50

- 新 binary + 真实 Flutter App + 真实受管 Anselm gateway + Computer Use session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-061404`：从空数据目录创建 `Acceptance Shutdown QA`，发送 `shutdown lifecycle probe`，逐帧观察搜索、思考、最终回答和自动标题；窗口录屏、backend journal、三路 SSE witness、LLM tap 均由同一 manifest 归属。
- 首次收台暴露真实生命周期问题：`chat.Shutdown()` 的 `wg.Wait()` 等待可选自动标题，10 秒 `autoTitleTimeout` 吃掉后端 6 秒 shutdown ctx，继而出现 `search embed worker did not stop before shutdown deadline`、`sandbox shutdown ... context deadline exceeded`。这不是可接受的“预期 WARN”。
- stop-and-fix：`chat.Shutdown(ctx)` 接入剩余预算；自动标题移出主 queue wait group，绑定 chat lifecycle cancel，并在 provider 无视取消时于最终 `SetAutoTitle` 前再次检查；回合尾 compaction 绑定同一 lifecycle；补 `TestShutdown_DoesNotWaitForAutoTitle` 和 shutdown race guard。同步 chat/bootstrap/reqctx 文档。
- 修复后 `rig-down.sh`：`shutting down gracefully`=`2026-08-05T06:16:12.720+0800`，`sandbox shutdown: all handles killed`=`06:16:12.722+0800`；backend 无 `WARN|ERROR|panic|FATAL`，frontend 无 `FlutterError|DartError|RenderFlex|Unhandled|Exception`，三路 SSE 正常收口。证据 `sessions/20260805-061404/evidence/shutdown-lifecycle.md`。
- 本地验证：`go test ./internal/app/chat ./internal/bootstrap ./internal/app/search ./internal/app/sandbox`、`docs make verify`、`git diff --check` 全部通过；API Serve `main...origin/main` clean。该修复只清除关停红线，不写 `judge.py`，不改变 `TOOL-123` 的 `changedFrac=0.99601/pass=false` 产品红线，批次十三仍 **10 / 50**，不提交。

# 2026-08-05 05:59 · TOOL-123 增加首帧独立测量与能力 fail-closed，红线保持，10/50

- 对正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-053150` 的源图与视频首帧运行 `testend/cmd/measure compare`：确定性归一源图到首帧 `1920×1080` 栅格后，`changedFrac=0.99601`、包围盒覆盖全画面、`pass=false`，命令以非零退出码结束。该结果独立复核了“视频首帧被上游重新构图”的产品红线，不把分辨率差异误报成失败，也不把编码噪声误报成成功。
- stop-and-fix 将受管 `animate_image` 能力改为 fail-closed：`video_generation.available=true` 只能证明文生视频；必须再有 `image_to_video=true` 才注入工具，探测缺失/损坏/失败均诚实缺席。新增 Anselm 能力解析单测、Router 闸单测，`go test ./internal/infra/llm ./internal/app/tool/generate`、`go test ./cmd/measure` 和 `git diff --check` 通过。
- 同步 `stream-llm.md`、`managed-gateway.md`、README/LOOP；API Serve 仓库保持 clean/no diff。`TOOL-123` 仍不写 `judge.py`、COVERAGE 仍为 `·····`，批次十三保持 **10 / 50**，不提交，等待 API Serve 提供明确 I2V 契约后再用真实 App/网关重跑。

# 2026-08-05 05:50 · TOOL-123 animate_image 正式复验冻结为红，批次十三 10/50

- `TOOL-123 animate_image` 的正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-053150` 完成真实 App、真实受管网关、Computer Use、一次生图→用户批准→一次动画、播放到 `0:05 / 0:05` 的全链路。三路 SSE durable messages `1..32`、notifications `1..2` 连续，LLM wire 一次 `/v1/videos/animations` submit `202` 后成功轮询，backend/frontend journal 无未解释 runtime 红线；正式证据为 `evidence/TOOL-123.md`。
- 前置静态红线已在正式运行前修复：旧 binary 曾在 `FirstFrame` 存在时同时发送 `aspect/resolution`；当前 wire 只有 `prompt/seconds/image`，Go 回归已覆盖。该问题不是本次红因。
- 产品复核发现不可接受的语义红线：源图是近景、灯塔在左侧的 `1344×768` 画面，但视频首帧被重新构图为远景、灯塔在右侧的另一幅画面。`animation-source.png`、`animation-first-frame.png` 和 `animation-output.mp4` 均保留在 session evidence；“用那张原图作为第一帧”的用户目的未达成。
- 因此 `TOOL-123` 不写 `judge.py`、不写五级绿灯，`COVERAGE.md` 保持空白；批次十三保持 **10 / 50**，前线冻结在 `TOOL-123`。API Serve 仓库保持 clean/no diff；需先解决上游模型/配置契约或重新裁定产品承诺，再重跑并做真实首帧对比。未到 50 格，不跑统一长门禁、不提交。

# 2026-08-05 05:10 · TOOL-122 edit_image 第 1 格通过，6/50

- `TOOL-122 edit_image` 的第 1 格以 `G1` 通过：正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-050103` 完成真实生图→改图用户目的，来源与改后附件分离，精确红→蓝结果保留原构图；无第二次生成、无 retry。证据为 `evidence/TOOL-122.md`。
- `COVERAGE.md` 当前 `TOOL-122=✓····`，中央账本 `640→641 judgments`，警报 `clean`。批次十三当前 **6 / 50**；按 P15 继续逐格裁决，未到 50 格不跑统一长门禁、不提交。下一格为 `F2`。

# 2026-08-05 05:12 · TOOL-122 edit_image 第 2 格通过，7/50

- `TOOL-122 edit_image` 的第 2 格以 `F2` 通过；同一正式 session 的 manifest、SSE、backend/frontend journal 和 LLM wire 证据完整，UI、SSE、持久化结果与实际改图附件一致。错误 session 路径曾被 gate 拒绝，未写入账本；改用正确路径后通过。
- `COVERAGE.md` 当前 `TOOL-122=✓✓···`，中央账本 `641→642 judgments`，警报 `clean`。批次十三当前 **7 / 50**；按 P15 继续逐格裁决，未到 50 格不跑统一长门禁、不提交。下一格为 `A5`。

# 2026-08-05 05:14 · TOOL-122 edit_image 第 3 格通过，8/50

- `TOOL-122 edit_image` 的第 3 格以 `A5` 通过：正式录屏与证据显示生图→改图链路没有几何跳变、重复生成、无谓 retry 或交互卡死。
- `COVERAGE.md` 当前 `TOOL-122=✓✓✓··`，中央账本 `642→643 judgments`，警报 `clean`。批次十三当前 **8 / 50**；按 P15 继续逐格裁决，未到 50 格不跑统一长门禁、不提交。下一格为 `C4`。

# 2026-08-05 05:16 · TOOL-122 edit_image 第 4 格通过，9/50

- `TOOL-122 edit_image` 的第 4 格以 `C4` 通过：正式画面中来源/改后媒体卡、比例、尺寸和改图事实清楚且视觉一致，没有 generic fallback 或首帧几何跳变。
- `COVERAGE.md` 当前 `TOOL-122=✓✓✓✓·`，中央账本 `643→644 judgments`，警报 `clean`。批次十三当前 **9 / 50**；按 P15 继续逐格裁决，未到 50 格不跑统一长门禁、不提交。下一格为 `G2`。

# 2026-08-05 05:18 · TOOL-122 edit_image 五级收口，10/50，警报待复审

- `TOOL-122 edit_image` 第 5 格以 `G2` 通过，五级 `G1/F2/A5/C4/G2` 全部落账，COVERAGE 为 `✓✓✓✓✓`；正式 session 和证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-050103/evidence/TOOL-122.md`。
- 中央账本 `644→645 judgments`。写入后统计机制按设计打开 `gap-too-fast` 与 `discovery-collapse`；在独立复审证据写入并串行 ack 前，不接受下一项 pass、不跑统一长门禁、不提交。批次十三当前 **10 / 50**。

# 2026-08-05 05:21 · TOOL-122 警报复审完成，前线移交 TOOL-123

- 锚点复校 `10/10` 通过；独立复审证据 `sessions/20260805-050103/evidence/tool-122-ledger-alarm-reaudit.md` 对 `gap-too-fast` 的账本批写入解释、`discovery-collapse` 的历史红证据和五通道正式证据逐项交叉核验。
- 两条警报已串行 ack，最终 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check` 为 `clean (645 judgments)`。批次十三仍为 **10 / 50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 `TOOL-123 animate_image`。

# 2026-08-05 04:20 · 第十三批 TOOL-121 generate_video 正式收口，5/50

- 首轮真实 landscape 路径后，产品复核冻结两条红线：generate_video receipt 的 filename/sizeBytes 被前端丢弃；视频卡在附件行迟到时默认 16:9，portrait/square 首帧可能发生几何跳变。stop-and-fix 补齐 `AnMediaRef` 的 filename/size/aspect hints、portrait/square/landscape 占位比例、native controller 实际几何覆盖和 delayed-meta widget guard；Flutter 21 项、analyze、Go generate/llm tests、diff check 通过。
- 修复后正式 portrait session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-040847` 使用真实 Flutter App、真实受管网关、Computer Use、窗口录屏、三路 SSE witness、LLM tap、backend/frontend journal 完成。危险工具批准前未执行；批准后只调用一次 generate_video，UI 真实显示 `Generating video…`、`running…`、`generated in 1m43s, downloading…`，最终文件为 `generated-20260804-201201.mp4 · video/mp4 · 4.6 MB · 5s`。
- 五通道交叉核对：blob 为 H.264/AAC `720×1280`、`5.038005s`、`4825115` bytes；messages durable `1..16`、notifications `1..2` 无 gap，entities 已连接；LLM 一次视频 submit 202、十次成功轮询、无 retry/第二次生成；backend/frontend 无未解释红线；录屏 `378.828333s`。播放自然结束后 AX 显示 `0:05 / 0:05`、`Replay`、`Fullscreen`，画面为真实灯塔帧。
- 用户确认后的隔离 cleanup 对准确 conversation 执行 DELETE=204，GET=404，列表为空；唯一 workspace、正式录屏、journals 和 evidence 均保留。正式证据 `sessions/20260805-040847/evidence/TOOL-121.md`，警报复审 `tool-121-ledger-alarm-reaudit.md`；anchors 10/10，五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 `635→640 judgments`。写账触发 `gap-too-fast` 与 `discovery-collapse`，经独立复审并串行 ack 后 `alarms.py check` 为 `clean (640 judgments)`。批次十三当前 **5 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-122 edit_image`。

# 2026-08-05 03:47 · 第十二批收口提交，下一前线 TOOL-121

- 第十二批 `TOOL-111..120` 已完成 **50 / 50**，统一长门禁、完整 testend、anchors `10/10`、警报复核和工作树审计均通过。
- 当前提交为 `91cdd51c`（`test(acceptance): close generate speech batch`）；未回退另一团队改动，当前工作树已干净。
- 中央账本保持 **635 judgments**，`alarms.py check` 为 `clean`；下一原子前线为 `TOOL-121 generate_video`，尚未开始。

# 2026-08-05 03:33 · 第十二批 TOOL-120 generate_speech 正式收口，50/50，进入统一门禁

- 真实 App + 真实受管网关 + Computer Use 完成一次语音合成：工具卡显示真实文件名、WAV、大小和精确时长；点击播放走一次 lease，Range 读取成功，播放自然结束后可重播。
- 首轮产品复核先冻结并修复两条红线：收据提示丢失导致音频卡首帧事实不足；元数据失败泄露裸 `att_` 且在途骨架落地会发生几何跳变。补齐 filename/sizeBytes/durationMs、固定音频几何、失败人话重试和播放失败/离线/缺失分流；定向 Flutter 13/13 通过，Chat reference 同步。
- 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-032851`：录屏 `180.128333s`；messages durable `1..14`、notifications `1..2`；一次 `/v1/audio/speech` 200、一次 `generate_speech` tool call；SQLite 附件 `audio/wav`、`126764` bytes，blob 为 24kHz mono PCM WAV；backend/frontend 无未解释红线。
- 五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本 `630→635 judgments`。写账触发的 `gap-too-fast`、`discovery-collapse` 以 10/10 anchor、正式绿 session、前置历史红 session、五通道证据复审并串行 ack；最终 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check` 为 `clean (635 judgments)`。
- 批次十二达到 **50 / 50**。按 P15 现在运行统一长门禁、完整 `make verify`、完整 testend、已修场景回归、工作树审计；所有门禁完成前不进入 `TOOL-121`、不提交。

# 2026-08-05 03:43 · 第十二批统一门禁通过，待提交

- 根 `mise exec -- make verify` 全绿：backend、frontend、docs、demo；frontend verify 为 `5191 tests`，并修掉另一团队当前 conversation card 改动中 3 个 analyzer warning（只删除无效 `!`，语义不变）。
- backend `mise exec -- make -C backend test` 全包通过；完整 `mise exec -- make -C backend testend` 通过，`github.com/sunweilin/anselm/testend/scenarios` 用时 `281.869s`，退出码 0。
- 收口前复核：anchors `10/10`，`alarms.py check` 为 `clean (635 judgments)`，`git diff --check` 通过；工作树中的其他团队改动未回退，待统一纳入本次可追溯提交。
- 当前只剩提交动作；提交完成后再把前线整体推进为 `TOOL-121 generate_video`，不在门禁未闭合时提前开始。

# 2026-08-05 03:17 · 第十二批 TOOL-119 generate_image 正式收口，45/50

- 首轮真实生成路径冻结为红：`**Attachment ID:** the requested item` 进入助手正文；随后两轮新 binary 又由独立 SSE witness 捕获 `Attachment ID` 标签和反引号半截在中间 delta 泄露。stop-and-fix 将媒体语义标签行从通用 opaque redaction 中窄化处理，并让 streaming redactor 跨 provider chunk 暂存整行；Go regression 覆盖真实 `att_...` 值边界，最终 user-facing delta/close 无 `Attachment ID`、`attachmentId`、`att_` 或坏占位。
- 逐帧产品复核发现第二条红线：`generate_image` 解析了 receipt 的 `width/height`，但工具卡只传 `attachmentId`，landscape/portrait 在附件 metadata 到达前会先以方形占位，随后跳变。stop-and-fix 将 filename、mime、sizeBytes、width/height、source 完整传给统一 `AnMediaRefCard`，并新增 delayed-meta widget guard，证明 `1536×1024` 在 metadata 未到时即保持 1.5:1。
- 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-031323` 使用新 binary、真实 Flutter App、真实受管 gateway、Computer Use、独立三路 SSE witness、LLM tap、backend/frontend journal 和连续录屏完成 landscape 路径。最终 UI 显示真实 `1344×768` 图像、文件名和大小，助手确认文案与画面一致，composer 正常恢复；screen.mov `102.498333s / 2784x1808 / 60fps`。
- 五通道交叉核对：messages durable `1..14`、notifications `1..2` 单调；tool_result 仅落真实 attachment receipt，assistant-only SSE 禁词扫描 clean；wire 恰一次 `/v1/images/generations`、一次 upload、一次 complete，三次 chat completion，全部响应成功；SQLite attachment 为 live `image/png`、`1083971` bytes、`1344×768`；backend/frontend journal 无 panic/error/Flutter/Dart/RenderFlex/Unhandled 红线。`rig-check` 运行中通过，`rig-down` 已收台且无孤儿。
- 证据 `sessions/20260805-031323/evidence/TOOL-119.md`，警报复审 `tool-119-ledger-alarm-reaudit.md`；anchors `10/10`。`judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，中央账本 `625→630 judgments`；写账触发的 `gap-too-fast`、`discovery-collapse` 已基于正式录屏、三轮红证据、修复回归和五通道复核串行 ack，最终 `alarms.py check` 为 `clean (630 judgments)`。
- 批次十二推进到 **45 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `TOOL-120 generate_speech`。

# 2026-08-05 02:44 · 第十二批 TOOL-118 WebSearch 正式收口，40/50

- 首轮真实成功路径冻结为红：托管模型把公开 schema 的 `limit` 发成字符串，后端拒绝后 App 出现 validation failure 和 retry。stop-and-fix 将公开 schema 保持 integer，同时在执行边界接受 native integer 与精确十进制字符串，浮点、任意字符串、数组、布尔继续拒绝；新增 Go validation/truncation regression。
- 修复后二次真实 App 路径又冻结一条视觉红线：助手复述的 provider 401 长错误落成单行 fenced code，在 transcript 右侧被裁切。stop-and-fix 让 `AnMarkdown` 围栏代码默认 `wrap:true`，`AnCodeEditor` 钉住只读 `TextWidthBasis.parent`，新增 Markdown/代码组件回归；最终真实帧 `frame-195.jpg` 中错误完整折为两行，工具卡与助手复述都可读。
- 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-023835` 以新 binary、真实 Flutter App、真实受管 gateway、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal 和窗口录像完成成功/失败两路径。正向仅一次 WebSearch，Alpha/Beta 有序、`2+ hits`、`truncated:true`；401 负向仅一次 WebSearch，无 retry，工具卡红色且 assistant 原样错误可读。录像 `244.275000s / 2784x1808 / 60fps`；messages `1..40`、notifications `1..4` 单调，0 gap；LLM bodies 对两条路径均只有一个 WebSearch，HTTP responses 全 200；backend 只有预期 401 WARN，frontend 无异常。
- 证据 `sessions/20260805-023835/evidence/TOOL-118.md`，警报复审 `tool-118-ledger-alarm-reaudit.md`；anchors `10/10`。`judge.py` 以 `G1/F2/A5/C4/G2` 写入 `TOOL-118=✓✓✓✓✓`，中央账本 `620→625 judgments`，两条统计警报经证据复审后串行 ack，最终 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 alarms.py check` 为 `clean (625 judgments)`。台架已由 `rig-down.sh` 收台，临时 fake provider 已停止并删除，正式 journals/录像/evidence 保留。
- 批次十二推进到 **40 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `TOOL-119 generate_image`。

# 2026-08-05 02:09 · 第十二批 TOOL-117 WebFetch 正式收口，35/50

- 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-020051` 使用真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和窗口录屏。真实 onboarding 创建 `Web Acceptance` 工作区后，Chat 依次完成 RFC 9110 正向摘要、loopback 安全拒绝、`example.com` local JS-shell 降级，以及 Chat 设置切换 `Jina proxy` 后的同页真实摘要。
- 正向 local 路径从 `Fetching...` 收口为 486 字 grounded 摘要；local shell 路径显示 `JS page`、127 字和可行动建议，不伪装成成功；Jina 路径持久化为 `web_fetch_mode=jina`，返回 133 字并准确回答 `Example Domain` 标题/用途。所有路径无 retry、无原始 HTML 灌入、无本地地址网络副作用。
- 五通道封口：`screen.mov` `336.700000s / 2784x1808 / 60fps`，抽取正向 settled、local JS、Jina settled 和 in-progress 画面；SQLite 的 tool_call/progress/tool_result/text 与 UI 对齐；SSE messages durable `1..62`、notifications `1..2` 单调，四条 WebFetch tool-result close；LLM tap 42 行、28 个 HTTP response 全 200；backend 无 WARN/ERROR/panic/fatal，frontend 无 Flutter/Dart/Unhandled/RenderFlex/AX 红线，唯一 foreground launcher noise 按既知规则单独披露。
- 正式证据为 `sessions/20260805-020051/evidence/TOOL-117.md`，警报复审为 `tool-117-ledger-alarm-reaudit.md`。anchors `10/10`；`judge.py` 已以 `G1/F2/A5/C4/G2` 写入五格，COVERAGE `TOOL-117=✓✓✓✓✓`，中央账本 `615→620 judgments`。五格写账触发的 `gap-too-fast`、`pass-burst`、`discovery-collapse` 已基于本格复核证据串行 ack，最终 `alarms.py check` 为 `clean (620 judgments)`。批次十二推进至 **35 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `TOOL-118 WebSearch`。

# 2026-08-05 01:53 · 第十二批 TOOL-116 get_relations 正式收口，30/50

- 首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-014547` 冻结为红：最终关系表在端点名称后泄露 `(fromId: deploy-helper)`，中间 SSE delta 还曾吐出裸关系占位符；该 session 不计绿，红 journal 保留。
- stop-and-fix：关系表现在识别 `起点 (from)`/`终点 (to)`/`端点名称` 列，只在用户面展示 kind 与人名；`fromId`/`toId`/`edgeId` 等机器字段和裸占位符在流式 delta 与 durable close 统一收口，精确 ref 只留在 tool card、tool result 与 LLM 审计线缆。新增 Go 单测覆盖真实 hosted-model 表格形态，并同步 chat domain 法条。
- 修复后二次正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-015059` 使用新 binary、真实 macOS App、真实受管 gateway、Computer Use、窗口录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap。真实请求只调用一次 `get_relations`，返回一条 `equip` 边；最终画面为 `技能 deploy-helper → 函数 greet`，关系引用显示为 `精确 ref 见关系卡`，无 retry、mutation 或矛盾卡片。
- 五通道复核：`rig-check.sh` 五观察器全绿后收台，`screen.mov` 已由 `rig-down.sh` 封口；assistant-only SSE delta/reasoning/close 禁词扫描为空，messages/entities/notifications 均连接，LLM 状态全 200，backend/frontend 无 panic/fatal/error/warn/Flutter/Dart/RenderFlex/Unhandled 红线。正式证据为 `sessions/20260805-015059/evidence/TOOL-116.md`，警报复审为 `tool-116-ledger-alarm-reaudit.md`。
- 锚点 `10/10`；`judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，COVERAGE `TOOL-116=✓✓✓✓✓`，中央账本 `610→615 judgments`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已用红/绿 session、完整五通道 journal、修复回归和锚点结果复审并串行 ack，最终 `alarms.py check` 为 `clean (615 judgments)`。第十二批推进至 **30 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `TOOL-117 WebFetch`。

# 2026-08-04 22:35 · 第十二批 TOOL-114 manage_conversation 正式收口，20/50

- 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-222259` 使用真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和连续录屏。真实 App 完成当前对话 rename、pin、unpin、archive、发送新消息自动 unarchive、显式 unarchive；最后执行空标题 rename 负路径。
- 六个真实 `manage_conversation` tool-call/result 对按 `rename → pin → unpin → archive → unarchive → 空标题 rename` 收口；空标题仅一次调用，服务端返回 `rename requires a non-empty title`，无 retry、fallback 或 mutation。notifications durable 顺序为 `updated → pinned → unpinned → archived → unarchived → updated`，与侧栏、顶栏和主内容 UI 一致。稳定画面中的失败卡、原始错误、标题未变化和 composer 均可读，没有裁切或布局红线。
- 五通道封口：`screen.mov` `411.743333s / 2784x1808 / 60fps`；messages durable `1..96`、notifications `1..6` 单调，entities 已连接；LLM chat completion responses 全 200；backend 唯一 WARN 是刻意触发的空标题业务校验，frontend 无 Flutter/Dart/Unhandled/RenderFlex/AX 红线。正式证据为 `evidence/TOOL-114.md`，收尾画面为 `evidence/tool-114-frame-405.jpg`。
- 定向 `go test ./internal/app/tool/conversation ./internal/app/chat ./internal/app/loop`、`make -C docs verify`、`git diff --check` 通过；`anchors.py check` 10/10。`judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，COVERAGE `TOOL-114=✓✓✓✓✓`，中央账本 `600→605 judgments`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已用完整录屏、五通道原始 journal、正/负路径和稳定画面复审，复审证据为 `evidence/tool-114-ledger-alarm-reaudit.md`，串行 ack 后最终 `alarms.py check` 为 `clean (605 judgments)`。批次十二推进至 **20 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 `TOOL-115 search_blocks`。

# 2026-08-04 22:20 · 第十二批 TOOL-113 list_conversations 正式收口，15/50

- 首轮真实复验 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-220707` 冻结为红：provider raw response 与 durable close 的三条 RFC3339 正确，但真实 SSE 中间帧把 `Alpha planning` 的 `lastMessageAt` 改成 `the recorded time`；同时发现普通词尾 `ge` 被 partial `get_flowrun` matcher 误判。红 session、backend/SSE/frontend/LLM journals 全部保留，不计绿。
- stop-and-fix：`redact.go` 将 partial tool name 收紧为 token-boundary；`lastMessageAt` Markdown 表格在无换行尾行、空目标列和孤立 `|` 行期间整体暂存，直到下一帧或 `Flush`；补真实 provider wire chunk regression，`chat.md` 同步流式法条。定向及相关 Go 回归、`make -C docs verify`、`git diff --check` 全部通过。
- 修复后二次正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-221418` 使用新 binary、真实 macOS App、真实受管 gateway、Computer Use、窗口录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap。真实 App 只执行三次 `list_conversations`，逐 cursor 取回 Gamma/Alpha/Beta 三页；中间 text delta 与 durable close 无占位，最终稳定画面完整可读。`screen.mov` 封口 `162.765s / 2784x1808 / 60fps`，messages durable `1..20` 单调，backend/frontend 无未解释红线，LLM wire 全 200。正式证据 `evidence/TOOL-113.md`，稳定终帧为 `evidence/tool-113-final-frame.jpg`。
- anchors `10/10`；`judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，COVERAGE `TOOL-113=✓✓✓✓✓`，中央账本 `595→600 judgments`。写账触发 `gap-too-fast` 与 `discovery-collapse`，已在 `evidence/tool-113-ledger-alarm-reaudit.md` 中用红/绿 session、五通道证据和校准结果复审并串行 ack，最终 `alarms.py check` 为 `clean (600 judgments)`。批次十二推进至 **15 / 50**，不跑统一长门禁、不提交；下一原子前线为 `TOOL-114 manage_conversation`。

# 2026-08-04 21:04 · 第十二批 TOOL-112 search_conversations 正式收口，10/50

- 首轮真实 App session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-205354` 冻结为红：空 workspace 创建后，后台免费档 provisioning 与首条 Chat 消息竞态，画面出现 `LLM_RESOLVE_ERROR · no model configured for scenario`。红 session、backend/SSE/frontend/LLM journals 全部保留，不计绿。
- stop-and-fix：后端 `Provisioner` 以 workspace 为键合并后台 hook 与前台 `POST /freetier:provision`；桌面 onboarding 在释放 Chat 前做既有 provision action 的 20s 前台就绪检查，并显示“正在准备工作区…”；FTS snippet 窗口由 16 扩到有界 64 token，补精确 `ORBITAL-112-FIX4` 连字符回归，backend managed-gateway/search 文档同步。
- 修复后 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-210040` 从 fresh data 启动真实 App 与受管 gateway：workspace 创建、默认模型就绪、干净源回合、重命名 `Launch plan notes`、新对话真实调用 `search_conversations`、展开结果卡、复制指针入口、点击行深跳均完成。结果为 1 个 message hit，完整高亮 `ORBITAL-112-FIX4`、`matchedChunks=2`、`messageId` 芯片与目标消息画面一致。
- 五通道封口：`rig-check.sh` 和 `rig-down.sh` 通过；screen.mov 窗口绑定可读；SSE 三流连接、durable close 与 DB 一致；LLM wire 含真实 search tool result；backend/frontend journal 无未解释 runtime 红线。正式证据 `evidence/TOOL-112.md`。
- 锚点 `10/10`；`judge.py` 五格 `G1/F2/A5/C4/G2` 写入，COVERAGE `TOOL-112=✓✓✓✓✓`，中央账本 `590→595 judgments`。写账触发 `gap-too-fast` 与 `discovery-collapse`，已以红/绿 session、五通道证据和校准结果书面 ack，最终 `alarms.py check` 为 `clean (595 judgments)`。批次十二推进至 **10 / 50**，不跑统一长门禁、不提交；下一原子前线为 `TOOL-113 list_conversations`。

# 2026-08-04 19:47 · 第十一批统一长门禁通过，发现并修正 MCP danger-gate 场景缺口

- 完整 `make testend` 首轮唯一红线为 `TestP4bMcp_ChatInstallErrorFaces`：`install_mcp_server` 的静态危险下限使真实 chat 回合停在 `streaming` 等待用户批准，旧剧本没有处理 interaction。这是验收剧本缺口，不是 MCP 安装挂死；产品安全门不降低。
- stop-and-fix：场景现在逐次等待并断言 `danger/install_mcp_server` interaction，模拟用户批准两次后才验证 `MCP_ENV_MISSING`（`STRIPE_API_KEY`）与 `MCP_REGISTRY_NOT_FOUND` 回喂模型、且无 server 残留；MCP 领域文档同步写明安装/卸载即使最终前置失败也必须先过人在环。
- 定向 `TestP4bMcp_ChatInstallErrorFaces` 通过（`5.78s`），完整 `make testend` 通过，scenarios `292.290s`，退出码 0。当前无 `anselm-testend`/`llama-server` 残留；本批 50/50 长门禁完成，进入最终 `make verify`、审计和提交。
- 最终 `make verify` 四门全绿（backend/frontend/docs/demo）；`git diff --check` 通过，`anchors.py check` 恢复并通过 10/10，`alarms.py check` 为 `clean (585 judgments)`。锚点答卷留在台架 `RIG_HOME`，不进入仓库。批次随后提交为 `de146b72`，下一前线 `TOOL-111 get_subagent_trace`。

# 2026-08-04 19:06 · 第十一批 TOOL-110 Subagent 正式收口，50/50

- 首轮真实负向路径冻结为红：非法 `subagent_type=Nope` 在后端校验前没有启动子运行，但前端仍显示 `Spawned subagent Nope · failed`，并展示“轨迹仅流不落盘——用 get_subagent_trace 回放”，产品语义错误；红证据保留在 session `20260804-185546`，不计绿。
- stop-and-fix：Subagent 卡片增加失败动词与未启动说明；校验失败不再展示轨迹回放提示，也不把错误结果重复渲成子代理回答；补双语 i18n、widget regression、frontend chat reference 与 backend subagent reference。`make gen`、Dart format 和 `tool_card_subagent_test.dart` 全绿。
- 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-190256` 使用修复后二进制、真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和窗口录屏。正向 Explore 只派一次，真实读取 `CLAUDE.md` 并返回 `Anselm — Agent 工作守则`；负向只一次校验错误，UI 明确 `Subagent validation failed · not started`。
- 五通道封口：`rig-check.sh` 全绿，screen.mov 可读；正向 SSE 恰一个 `subagent:true` 子消息，负向为 0；LLM wire 全 200；backend 只有预期 validation WARN；frontend 无 Flutter/AX/Unhandled/断连红线。正式证据为 `evidence/TOOL-110.md`，警报重审为 `evidence/tool-110-ledger-alarm-reaudit.md`。
- 锚点 10/10 校准有效，`judge.py` 五格 `G1/F2/A5/C4/G2` 已写入，COVERAGE `TOOL-110=✓✓✓✓✓`，中央账本 `580→585 judgments`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按真实录屏、负向红证据、五通道 journal 和回归测试重审并 ack，`alarms.py check` clean。第十一批达到 **50 / 50**，现执行唯一一次长门禁与提交；下一前线为 `TOOL-111 get_subagent_trace`。

# 2026-08-04 18:10 · TOOL-108 delete_skill 正式收口，40/50

- 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-180135` 使用真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和 `564.176667s` 录屏。前置负向路径验证模型自报 `danger=safe` 不会越过静态危险下限；不存在目标 `missing-skill-108` 在危险闸上点击 Deny 后只形成一次 `Denied`，没有执行和重试。
- 正向 fixture `delete-target-108` 在用户明确确认后点击 Allow，UI 逐帧显示一次 `Dangerous · Awaiting your approval`、一次 `Deleted skill … · deleted` activity 和成功反馈；目标目录消失，`GET /api/v1/skills` 不再列出目标，单项 GET 为 `404 SKILL_NOT_FOUND`，其余 fixture 不受影响。
- 五通道封口：SSE 有一次 `skill.deleted`、一次 `deleted` touchpoint 和一次成功 `tool_result`；LLM wire 只有一次 `delete_skill` mutation 和一次最终报告；backend 无 WARN/ERROR/panic/fatal，frontend 无 Flutter/Dart/Unhandled/Build scheduled 红线；`rig-check.sh` 五通道全绿，`rig-down.sh` 成功停止全部观察器并保留 journals/录屏。
- `judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE `TOOL-108=✓✓✓✓✓`，中央账本 `570→575 judgments`。五格写入触发 `gap-too-fast` 与 `discovery-collapse`，已依据正式录屏、负向路径、五通道证据与 anchors 10/10 写入 `evidence/tool-108-ledger-alarm-reaudit.md` 并串行 ack；最终 `alarms.py check` 为 `clean (575 judgments)`。第十一批 **40 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线 `TOOL-109 run_skill_script`。

# 2026-08-04 18:00 · TOOL-107 edit_skill 正式收口，35/50

- 本格先后冻结四条真实红线且全部不计账：`173117` 为 Computer Use 换行误提交；`173358` 为 Flutter `Build scheduled during frame`，栈落在 `AnInteractive.onHoverScrollSettled`；`174614` 为托管模型把 `disableModelInvocation:false` 字符串化后首次 edit 失败并违规重试；`175039` 为缺失 skill 的 `skill not found` 被重复执行两次并形成两张红卡。红证据均保留在对应 session 的 `evidence/`。
- stop-and-fix：`AnInteractive` settle 改为 post-frame flush，增加布局阶段回归；Skill CRUD 增加精确 bool 字符串兼容，数字/模糊 truthy 仍拒绝；`EditSkill.HaltOnRepeat` 将 `skill not found` 标为本回合终局，后续重复只 ledger suppress；backend/frontend 领域文档与定向测试同步。
- 最终正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-175428` 使用新 binary、真实 Flutter App、真实受管 gateway、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal 和窗口录屏 `130.763333s`。成功路径一次 `get_skill` + 一次 `edit_skill`，Activity 只有 `Edited`；缺失路径只有一张 `Failed`，错误为 `skill not found`，侧幕 `Draft unsaved · truth is still the last version`，无第二 tool call、无创建残留。
- `rig-check.sh` 五通道全绿；backend 无 WARN/ERROR/panic（唯一失败行为是预期 missing-skill）；frontend 只有已知 foreground 诊断，无 Flutter exception；SSE/LLM wire/SQLite/文件系统/UI 一致。`judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE `TOOL-107=✓✓✓✓✓`，中央账本 `565→570 judgments`。
- 写账触发 `gap-too-fast` 与 `discovery-collapse`；anchor 10/10 校准、四条红证据、最终绿 session、回归结果和 `tool-107-ledger-alarm-reaudit.md` 已完成重审并串行 ack，最终 `alarms.py check` 为 `clean (570 judgments)`。第十一批 **35 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线 `TOOL-108 delete_skill`。

# 2026-08-04 17:19 · TOOL-106 create_skill 正式收口，30/50

- 前置红 session 已保留并驱动修复：`170849` 记录托管模型将 `allowedTools`/`arguments` 发成 JSON 数组字符串，旧执行层拒绝后模型重复调用；`171251` 记录模型省略可选元数据；`171503` 记录重名失败时 Activity rail 错把成功动词与 `Failed` 并列。三份红证据均不计绿。
- stop-and-fix 增加 create/edit skill 共用的精确数组字符串兼容解码，只接受原生字符串数组或完整 JSON 数组编码字符串，普通标量/对象/混合数组/非法编码继续拒绝；工具描述明确 required/optional 元数据。中心卡片和侧幕失败态统一使用明确失败语义；Go/Flutter 定向守卫测试与 skill/chat 文档同步。
- 正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-171941` 使用新 binary、真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和 `333.665000s` 录屏。成功路径只创建一次 `release-notes-106e`，卡片展示完整元数据与正文，Activity 只有 `Created`；重名路径只调用一次，中心显示 `Create skill failed` 与 `skill name already exists`，侧幕只显示 `Failed` 和 `Draft unsaved · nothing was created`，无 retry、第二条 mutation 或矛盾成功卡。
- 五通道封口：`rig-check.sh` 全绿；D1、backend、SSE 三流、Flutter runner、window recorder、LLM tap 均归属同一 session；backend 仅预期重名 WARN，无 panic/fatal；frontend 只有已知 foreground 诊断，无 Flutter/Dart/Unhandled 红线；SSE/SQLite/LLM wire/UI 一致。正式证据 `evidence/tool-106-formal-171941-green.md`，台架已收台且 journals/录屏保留。
- 锚点因超过 4 小时先被 gate 正确拒绝，随后重新完成 10/10 校准；`judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，COVERAGE `TOOL-106` 为 `✓✓✓✓✓`，中央账本 `560→565 judgments`。五格写入触发的 `gap-too-fast` 与 `discovery-collapse` 已依据正式正负路径、三份红证据、五通道 session 和新锚点复审并 ack，说明为 `evidence/tool-106-ledger-alarm-reaudit.md`，`alarms.py check` clean。第十一批当前 **30 / 50**，下一原子前线为 `TOOL-107 edit_skill`，未到 50 格不跑统一长门禁、不提交。

# 2026-08-04 17:02 · TOOL-105 get_skill 正式收口，25/50

- existing 路径在真实 App 中严格执行一次 `get_skill(name=deploy-helper)`，禁止 activate/create/edit/mutate/retry。结构化 card 显示 identity、description/context/source、allowed-tools chips 和完整 Markdown body；逐帧展开 `raw result` 后核对未过滤的 opaque allowed-tool、workspace dir、ISO `updatedAt`、完整 frontmatter/body。助手 prose 中的机器值被全局法条脱敏，这是安全边界，不把 redaction 误判为数据损坏，也不放开全局 redactor。
- missing 路径在隔离新 chat 中严格执行一次 `get_skill(name=missing-skill-105)`，禁止 retry/activate/create/edit/mutate。App 只显示一张 `Viewed skill missing-skill-105 · failed` 和清楚的 `skill not found`；SSE 是单次 `tool_call → error tool_result`，backend 唯一 WARN 是预期的工具失败审计，没有第二次调用或伪造成功。
- 五通道封口：session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-165430` 的真实 Flutter/managed gateway/Computer Use 录屏为 `276.158333s / 2784x1808 / 60fps`；`rig-check` 全绿；SSE、SQLite、LLM wire、backend/frontend 与画面一致，frontend 只有已知 recorder 启动诊断而无 Flutter/Dart/Unhandled 红线；rig-down 后进程清零。正式证据 `evidence/tool-105-formal-165430-green.md`。
- `judge.py` 写入 `G1/F2/A5/C4/G2`，COVERAGE `TOOL-105` 为 `✓✓✓✓✓`，中央账本 `555→560 judgments`；`gap-too-fast`、`pass-burst`、`discovery-collapse` 已以 existing raw-result 展开、missing 负路径和五通道复审说明 ack，`alarms.py check` clean。第十一批当前 **25 / 50**，下一原子前线为 `TOOL-106 create_skill`；未到 50 格不跑统一长门禁、不提交。

# 2026-08-04 16:52 · TOOL-104 activate_skill 正式收口，20/50

- 首轮真实红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-164045` 暴露托管模型将 `arguments` 从公开 schema 的 `array<string>` 编成 JSON 数组字符串；旧执行层正确拒绝，App 显示失败卡，模型随后改发原生数组并重复执行。红证据 `evidence/tool-104-red-stringified-arguments.md` 保留，不计绿。Computer Use 当轮还用带换行的 `type_text` 编写 fixture，造成 prompt 分裂，作为仪器噪声单独记录。
- stop-and-fix 增加窄兼容解码：原生数组和完整 JSON 数组字符串可用，null/省略仍可选；普通字符串、数字、对象、混合数组和非法编码明确拒绝，不做静默拆词。同步 `activate_test.go` 与 skill 领域文档，定向 Go 测试通过。
- 正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-164732` 使用新 binary、真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和录屏。LLM wire 实际发字符串化数组但只执行一次；App 只有一张成功 `Activated skill activation-104` 卡，显示 `Audience: $audience`、`First positional: design`、`All positional: design review`，没有红色失败/重试卡。`$audience` 保持字面量是因为 fixture 没有 `arguments: audience` frontmatter，不属于本格缺陷。
- 五通道封口：`rig-check.sh` 全部通过；screen recording `198.910000s / 2784x1808 / 60fps`；SSE 为单次 tool-call/result/touchpoint/assistant close，SQLite/工具结果一致；backend 无 WARN/ERROR/panic/fatal，frontend 只有已知 recorder 启动诊断而无 Flutter/Dart/Unhandled 红线；rig-down 后进程与录屏均封口。正式证据 `evidence/tool-104-formal-164732-green.md`。
- `judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE `TOOL-104` 为 `✓✓✓✓✓`，中央账本 `550→555 judgments`；`gap-too-fast` 与 `discovery-collapse` 按红绿双轮和五通道复审说明 ack，`alarms.py check` clean。第十一批当前 **20 / 50**，下一原子前线为 `TOOL-105 get_skill`；未到 50 格不跑统一长门禁、不提交。

# 2026-08-04 16:36 · TOOL-103 get_mcp_call 正式收口，15/50

- 首轮红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-163003` 真实走完 `get_mcp_call` 读回路径，但模型连续把记录里的 opaque `callId` 从 `...bfa41` 抄成 `...bba41`。后端正确返回 `mcp call not found`，App 显示红色失败卷宗，LLM 还错误声称已逐字复制；红证据 `evidence/tool-103-red-opaque-id-copy.md` 保留，不计绿。这是模型抄写负路径，不擅自改 API 做模糊匹配。
- 正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-163620` 使用真实 Context7 历史调用，在干净台架中以 verbatim JSON 参数调用 `get_mcp_call` 一次。App 显示 `Opened MCP-call record · Completed · 2.0s`，dossier 展示 id、serverId、tool、status、triggeredBy、input、output、elapsedMs 与安全脱敏字段；SQLite 目标行为 `ok/chat/1990ms`，SSE messages 记录 exact tool argument、tool_result open/close 和 durable close，LLM tap 记录相同参数与结果。
- 五通道封口：`rig-check.sh` 收台前通过；window recording `72.616667s / 2784x1808 / 60fps`；正式绿 backend journal 无 WARN/ERROR/panic/fatal，frontend console 无 Dart/Unhandled 红线，LLM upstream 全链路经 llmtap。正式证据 `evidence/tool-103-formal-163620-green.md`，红证据另存。
- `judge.py` 已写入 `G1/F2/A5/C4/G2`，COVERAGE `TOOL-103` 为 `✓✓✓✓✓`，中央账本 `545→550 judgments`；五格写入触发的 `gap-too-fast` 与 `discovery-collapse` 已依据负路径、正式绿 session、原始五通道证据和录屏复审并 ack，`alarms.py check` 为 `clean (550 judgments)`。
- 第十一批当前 **15 / 50**，下一原子前线 `TOOL-104 activate_skill`；未到 50 格不跑统一长门禁、不提交。

# 2026-08-04 16:17 · TOOL-102 search_mcp_calls 正式收口，10/50

- 首轮真实红 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-160132` 冻结托管模型发送 `limit:"1"` 后后端类型错误、模型重复发送 `limit:1` 的产品红：用户要求 exactly once，但 App 出现失败卡和成功卡。红证据 `evidence/tool-102-formal-160132-red-stringified-limit-retry.md` 保留，不计绿；同一 session 也确认 MCP 服务返回 `IsError=false` 的业务文本应保持 `status=ok`，不由产品猜测改成 failed。
- stop-and-fix 在 `search_mcp_calls` 执行解码层复用现有 `search_handler_calls` / `search_activations` 先例：原生整数和精确十进制字符串可用，浮点、数组、布尔、对象和非整数文本拒绝；schema 描述、MCP 领域文档和单测同步。定向 Go 回归、`make -C docs verify`、gofmt、diff check 通过。
- 正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-161720` 从 fresh onboarding 和真实 Context7 安装开始，完成合法/空参数两次真实 `resolve-library-id`、一次 `search_mcp_calls(limit=1)` 与一次 `nextCursor` 翻页。App 卡片显示一条有界记录、`hasMore=true`、`okCount:2/failedCount:0`，第二页唯一更旧记录后 `hasMore=false`；SQLite 两行均 `status=ok`，SSE/LLM/backend/frontend 与画面一致，无失败重试卡。
- 五通道封口：`rig-check.sh` 收台前全绿，screen recording `255.123333s / 2784x1808 / 60fps`，ssetap/llmtap/backend/frontend/Flutter runner 归属完整；正式证据 `evidence/tool-102-formal-161720-green.md`，账本复审 `tool-102-ledger-alarm-reaudit.md`。`judge.py` 写入 `G1/F2/A5/C4/G2`，COVERAGE `TOOL-102` 为 `✓✓✓✓✓`，中央账本 `540→545 judgments`；警报已复审 ack，`alarms.py check` 为 `clean (545 judgments)`。
- 第十一批当前 **10 / 50**，下一原子前线 `TOOL-103 get_mcp_call`；未到 50 格不跑统一长门禁、不提交。

# 2026-08-04 16:00 · TOOL-101 reconnect_mcp 正式收口，5/50

- 三次真实红均保留并驱动修复：`152538` 缺少结构化 `connectedAt`，`153910` 暴露 label/value 形状，`154256` 暴露 Markdown 加粗标签跨 chunk 的 vague placeholder 泄漏；三份红证据不计绿。
- 正式绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-155203` 从 fresh onboarding 和真实 Context7 安装/Allow 开始；外部终止 MCP 进程组后，真实 App 一次 reconnect 成功恢复 `disconnected → connecting → ready`，结构化卡片显示 `connected`、2 tools 与本地化 `Connected at · 2026-08-04 15:54`，正文明确指向 MCP status card。
- 第二次 reconnect 未形成重复执行；`missing-server-101` 只产生一张明确失败卡与 `mcp server not found`，没有 retry。后端只留下这条预期负路径 WARN，没有外部 kill 的权限警告；前端无 Flutter/Dart/RenderFlex/Unhandled 红线。
- 五通道封口：window recording `203.746667s / 2784x1808 / 60fps`；SSE messages durable `1..37`、notifications `1..6` 单调，entities 捕获生命周期信号；LLM tap 观察到的 upstream responses 全 HTTP 200；`rig-check` 收台前通过全部五个物理观察器，`rig-down` 后进程清零。正式证据 `evidence/tool-101-formal-155203-green.md`。
- `go test ./internal/app/loop ./internal/infra/sandbox ./internal/app/mcp ./internal/app/tool/mcp`、Flutter 生态测试 `13/13`、gofmt、生成 i18n、diff check 全绿。anchors 10/10 重校后，`judge.py` 写入 `G1/F2/A5/C4/G2`，COVERAGE `TOOL-101` 为 `✓✓✓✓✓`，中央账本 `535→540 judgments`。
- 五格批量写入触发 `gap-too-fast` 与 `discovery-collapse`；已依据三份红证据、正式绿 session、五通道日志和 `tool-101-ledger-alarm-reaudit.md` 复审并 ack，正式 `alarms.py check` 为 `clean (540 judgments)`。第十一批当前 **5 / 50**，下一原子前线 `TOOL-102 search_mcp_calls`；未到 50 格不跑统一长门禁、不提交。

# 2026-08-04 · TOOL-101 reconnect_mcp 首轮红冻结与 stop-and-fix

- 真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-152538` 从新 workspace onboarding 开始，安装 `io.github.upstash/context7` 后由台架外部终止旧 MCP 进程，再在真实 App 中严格执行一次 `reconnect_mcp(name=context7)`。重连成功，实体状态为 `disconnected → connecting → ready`，SSE 有对应 status signal/notification，REST 与 tool result 均为 ready、2 tools，LLM wire 全 HTTP 200。
- 逐帧产品复核发现红：最终助手表格把 `Connected at` 渲成 `the recorded time`；结构化 MCP status card 没有展示后端已有的 `connectedAt`，用户无法知道重连完成时点。红证据 `evidence/tool-101-formal-152538-red-vague-connected-at.md` 已封存，TOOL-101 未写 `judge.py`，COVERAGE 仍为 `·····`。
- stop-and-fix 保持全局 raw ISO 脱敏边界：MCP 表格改为明确指向状态卡，状态卡新增本地化绝对连接时间；Unix Sandbox cleanup 与 shell 回收器一致，在外部断连/进程组形状竞态时对 direct child 做幂等 fallback。同步 backend MCP/sandbox、frontend chat 文档和 i18n。
- 回归已通过：`go test ./internal/app/loop ./internal/infra/sandbox ./internal/app/mcp ./internal/app/tool/mcp`、Sandbox 外部整组终止后再次 cleanup 测试、`flutter test test/features/chat/ui/tool_card_ecosystem_test.dart`（13 项）、`dart run slang`、`gofmt`、`git diff --check`。当前台架已收台，原始 journals/录屏/evidence 保留；下一步重新起 rig，用新 binary 完成成功重连、missing-name 失败不重试、最终 UI 与五通道健康复核。
- 第二次新 binary session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-153910` 的安装 Allow 已完成，但逐帧发现安装结果是 label/value 形状而非 Markdown 表格，仍显示 `Connected at: the recorded time`；红证据 `evidence/tool-101-formal-153910-red-bullet-connected-at.md` 已封存，台架已收台，不计绿。随后将规则提升为 label/value 与表格双形状，并新增跨 chunk 回归；`go test ./internal/app/loop -count=1` 通过。必须再用新 binary 复验，不能把单测或前两次红 session 当作绿证据。

# 2026-08-04 15:05 · TOOL-099/100 修复后正式成功，等待五级账本写入

- 最终 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-144146` 使用修复后二进制、真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journals；录屏 `1172.000000s / 2784x1808 / 60fps`，台架已由 `rig-down.sh` 收台。
- `TOOL-099 install_mcp_server`：用户在危险 gate 点击 Allow 后，`io.github.upstash/context7` 安装成功；UI 显示 `Allowed · connected · 2 tools`，前端不再把 canonical `ready` 错投影为 disconnected。修复后的前一 session 已完成一次 `search_tools` 和一次 `mcp__context7__resolve-library-id`，返回 5 条 Flutter matches；无失败 retry。
- `TOOL-100 uninstall_mcp_server`：模型只发一次 `{"name":"context7"}`；真实 UI 先显示 Dangerous、完整后果和 Awaiting approval，用户点击 Allow 后严格形成 `tool_call(dangerous) → interaction → resolved(Allow) → tool_result`。最终只有一张成功卡、一个 `context7 Deleted` activity，SQLite 为 soft-delete，工具与 resident process 消失，无第二次调用、无矛盾卡片。
- 五通道封口：SSE messages durable `1..32`、notifications `1..6` 单调唯一，entity `connecting → ready`；LLM 18 个响应状态全 200；backend 1265 行与 frontend log 无 panic/fatal/error/warn/exception 红线；rig-down 后无 Context7/MCP 残留进程。绿证据分别为 `tool-099-formal-144146-green.md`、`tool-100-formal-144146-green.md`，前序红证据不删除。
- anchors 已通过 10/10 校准，定向 Go/Flutter 回归和 diff check 通过。当前正式账本仍为 525；下一动作是按 `G1/F2/A5/C4/G2` 分别写入 TOOL-099 与 TOOL-100 十格，随后复核并 ack 新警报；满第十批 50/50 前不跑统一长门禁、不提交。

# 2026-08-04 15:06 · TOOL-099 install_mcp_server 五级账本通过，45/50

- 绿证据 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-144146/evidence/tool-099-formal-144146-green.md` 经 judge 写入 `G1/F2/A5/C4/G2`，`TOOL-099` 行为 `✓✓✓✓✓`。
- 中央账本由 525 增至 **530 judgments**。`TOOL-100 uninstall_mcp_server` 已有同一最终 session 的完整危险 gate/Allow/单次 mutation/soft-delete/无残留证据，但尚未写账；写完后第十批正好 50/50，再执行统一长门禁。

# 2026-08-04 15:07 · TOOL-100 uninstall_mcp_server 五级账本通过，第十批 50/50

- 绿证据 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-144146/evidence/tool-100-formal-144146-green.md` 经 judge 写入 `G1/F2/A5/C4/G2`，`TOOL-100` 行为 `✓✓✓✓✓`。
- 中央账本由 530 增至 **535 judgments**；第十批 `TOOL-091..100` 达到 **50 / 50**。产品格完成，统一长门禁尚未开始；下一步先跑警报检查/复核，再跑完整验证、残留进程检查和工作树审计。

# 2026-08-04 15:16 · 第十批统一长门禁通过并提交 `553fa150`

- `alarms.py check`：`clean (535 judgments on record)`；gap/pass-burst/discovery-collapse 均依据 `tool-099-100-ledger-alarm-reaudit.md` 复审并 ack。
- `make verify`：backend、frontend、docs、demo 全绿；backend `mise exec -- go test ./...` 与 testend `mise exec -- go test ./...` 全绿。
- anchors `10/10`、`git diff --check`、COVERAGE `TOOL-091..100` 全部 `✓✓✓✓✓`、台架/Context7 残留进程为空；第十批长门禁完成。
- 本批已提交为 `553fa150`，包含本批验收修复、回归测试、台架清册和同步文档；下一原子前线为 `TOOL-101 reconnect_mcp`，Goal 仍 active。

# 2026-08-04 14:38 · TOOL-099 cleanup 暴露 uninstall 无 gate + 模型重试红

- 同一真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-143238` 先已完成修复后的 context7 success：卡片 `Allowed · connected · 2 tools`，dynamic `search_tools` 后一次 `mcp__context7__resolve-library-id` 返回 5 条 Flutter matches；SSE durable 到 `38`，Activity `1 touched · 1 executed`，后端/LLM/frontend redline clean。
- 清理请求明确要求 uninstall exactly once、do not retry。模型先以 `{"name":"io.github.upstash/context7"}` 调用，结果 `mcp server not found`；该 destructive call 的 wire danger 是 `safe`，没有 interaction。随后模型自行换成 `{"name":"context7"}` 再次调用，成功停止进程并删除配置；UI 留下失败 MCP error 卡、成功 Uninstalled 卡和 `context7 Deleted`，模型还在正文承认违反 exactly-once。
- 红证据为 `evidence/tool-099-formal-143238-red-uninstall-no-gate-retry.md`，录屏 `297.000000s / 2784x1808 / 60fps`；台架已收台，不写 judge/COVERAGE。
- stop-and-fix：`UninstallServer.MinimumDanger() = dangerous`；Description/canonical summary 说清永久删配置、停进程、工具失效、必须短名且不准猜名重试；`RemoveServer` 接受对应 registry name 确定性别名。同步 MCP/loop 领域文档；Go `internal/app/mcp`、`internal/app/tool/mcp`、`internal/app/tool`、`internal/app/loop` 全绿，`gofmt` 与 `git diff --check` 通过。
- 下一步：修复后二进制真实重跑 uninstall，先确认 gate 再决定是否继续 action-time Allow；验证一次调用、失败名不重试、成功后 server/tool 恢复不可用与最终 UI 真相，再考虑 TOOL-099 五格写账。

# 2026-08-04 14:31 · TOOL-099 Allow success path exposes ready/disconnected projection red

- 新 binary formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-142537` 在收到 action-time `Allow` 后真实安装 `io.github.upstash/context7`；真实 Flutter App、受管 gateway、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal 与录屏均保留，`screen.mov` 为 `164.860000s / 2784x1808 / 60fps`。
- 五通道交叉事实：MCP 子进程 stderr 报 `Context7 Documentation MCP Server v3.2.5 running on stdio`；entities 为 `disconnected → connecting → ready`；notifications 有 `mcp.installed`；messages/tool result 返回 `status=ready`、2 个工具；touchpoint 为 `created`。但 durable tool card 显示 `Allowed · disconnected · 2 tools`，助手正文说 `ready`。这是产品真相投影红，不计 `TOOL-099` 任何绿格。
- 红证据 `evidence/tool-099-formal-142537-red-ready-disconnected.md` 已封存。台架已收台；没有继续动态调用或卸载，避免在修复前扩大成功路径的证据边界。
- stop-and-fix：前端仅把历史 `connected` 当健康，错过后端 canonical `ready`，并把可调用 `degraded` 误判为失败。现在统一为 `ready` 正常、`degraded` 警告、`connected` 兼容、其余非可调用态失败；中英文 i18n、widget regression、chat 文档已同步。`mise exec -- dart run slang`、`dart format`、Flutter 生态 `13/13`、Go loop/tool/mcp/mcp-app 四包全绿，`git diff --check` 通过。
- 当前仍不写 `judge.py`、不改 `TOOL-099` COVERAGE、不跑第十批长门禁、不提交；下一步必须新 binary 真实重跑同一 Allow success，再验证 dynamic tool discovery/call 与 uninstall cleanup。

# 2026-08-04 10:46 · TOOL-099 修复后危险 gate Deny formal，当前仍未绿

- 新 binary formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-104247` 从 onboarding 起真实启动 Flutter App、受管 gateway、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal 和录屏；收台后 `screen.mov` 为 `88.993333s / 2784x1808 / 60fps`。
- 同一无 env prompt 的 wire 为 `danger:"dangerous"`，UI 显示完整 `Dangerous · Awaiting your approval` 和持久化外部能力 canonical summary；点击安全 `Deny` 后 SSE 严格为 `tool_call → interaction → resolved → tool_result`，结果是拒绝文本，无 install execution、无半安装行。助手准确说明缺失 env 未知，因为工具在校验前被拒绝，不伪造早先红场景的 `ENTRA_CLIENT_ID`。
- `rig-check.sh` 五通道全绿；SSE durable messages `1..14`，backend 175 行、frontend 19 行、LLM 18 个状态，红线扫描为空。证据为 `evidence/tool-099-formal-104247-red-deny-gate.md`，只证明恢复后的负路径，不计 `TOOL-099` 绿格。
- 后续成功路径必须在得到 action-time confirmation 后点击 `Allow`，再核对真实 server row、连接状态、动态工具 `search_tools`/调用、卸载清理；当前不写 `judge.py`、不改 COVERAGE、不跑第十批统一长门禁、不提交。

# 2026-08-04 10:46 · TOOL-099 context7 成功路径停在 action-time Allow

- formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-104745` 已启动真实 App、受管 gateway、Computer Use、五通道台架；无凭证 `io.github.upstash/context7` 路径确实到达 `Dangerous · Awaiting your approval`。
- 未点击 `Allow`/`Always allow`，故没有 install、connection、dynamic tool discovery 或 cleanup 证据；录屏 `119.278333s / 2784x1808 / 60fps` 与 journals 已封存，证据 `tool-099-formal-104745-awaiting-action-time-allow.md` 明确不计绿。
- 台架已安全收台，当前暂停原因仅为缺少这一次安装动作的明确 action-time 用户确认；恢复后从该成功 gate 继续，不跳过 `TOOL-099`，不写 `judge.py`，不改 COVERAGE，不提交。

# 2026-08-04 10:46 · TOOL-099 install_mcp_server 静态危险 floor 修复，当前仍红

- 封口 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-103221`：真实 Flutter App、真实受管 gateway、Computer Use、backend/frontend journal、三路 SSE witness、LLM tap 与 `451.045000s / 2784x1808 / 60fps` 录屏均保留。
- 这次真实 wire 的 `tool_call` 是 `danger:"cautious"`，没有 interaction；随后直接执行缺 env 校验，SSE 返回 `required environment variables missing (missing=[ENTRA_CLIENT_ID])`。因缺 env 没有服务行/半安装副作用，但这不是安全证明。红证据为 `evidence/tool-099-formal-103221-red-missing-danger-floor.md`，不计绿。
- stop-and-fix：`InstallServer.MinimumDanger() = dangerous`；canonical gate summary 明确持久化配置、常驻进程/外部连接、新能力与加密凭证；破坏性/静态 floor 清册、真实 MCP adapter 文案测试、loop 通用 canonical summary 测试和 MCP/loop 领域契约同步。`gofmt`、`go test -count=1 ./internal/app/loop ./internal/app/tool ./internal/app/tool/mcp ./internal/app/mcp` 全绿。
- 后续：重建台架后以同一缺 env prompt 重跑，必须看到 `Dangerous · Awaiting your approval` 与 interaction，再在获得 action-time confirmation 后才可测试 Allow/成功安装；当前不写 `judge.py`，不改 `TOOL-099` COVERAGE，不跑第十批统一长门禁，不提交。

# 2026-08-04 10:24 · TOOL-099 安装错误投影 stop-and-fix，40/50

- 静态核对真实后端错误面：`InstallFromRegistry` 对缺失 required env 返回 `MCP_ENV_MISSING`，`details.missing` 保留精确变量名；进入 loop 后用户可见文本为 `required environment variables missing (missing=[ENTRA_CLIENT_ID])`，不是 JSON `status`。
- 首轮真实 App 已走到 `install_mcp_server` 的危险确认层；未获得 action-time `Allow` 前通过 Computer Use 点击 `Deny`，确认没有安装、没有服务行、没有成功回执。该路径只证明安全拒绝，不计 `TOOL-099` 任何绿格。
- 发现并修复前端 MCP 生命周期卡的失败分类缺口：纯文本安装/重连错误现在红色回执、自动展开且保留缺失变量；卸载成功的普通文本不误判。同步 `docs/references/frontend/features/chat.md`、后端 MCP 领域说明和本页前线状态。
- 逐帧 widget 回归又发现同一纯文本错误在族体和底盘重复出现；stop-and-fix 让失败帧的错误由底盘唯一承载，JSON 状态失败仍保留结构化状态体。`ChatToolCard` 真实 `status=error` 夹具现在断言红色错误回执、自动展开和缺失变量只出现一次。
- loop 线缆回归 `TestExecuteTool_UserErrorDetailsAreVisible` 锁定 `executeTool` 返回的 `out` 与 `errMsg` 都保留 `ENTRA_CLIENT_ID`，避免领域错误到聊天 tool_result 之间丢失可行动细节。
- 验证：`mise exec -- flutter test test/features/chat/ui/tool_card_ecosystem_test.dart` 全部 `13/13`；`mise exec -- go test -count=1 ./internal/app/tool/mcp ./internal/app/mcp ./internal/app/loop` 全绿，其中 `TestInstall_MissingEnv` 锁定 `details.missing` 精确变量名与 0 行落盘，`TestExecuteTool_UserErrorDetailsAreVisible` 锁定 loop 两个错误出口；`git diff --check` 通过。未写 judge、未改 COVERAGE、未触发 50 格长门禁。
- 下一动作：用户在 App 确认安装动作后，重新跑 EnterpriseMCP 无 env 的真实缺失变量路径，再跑带 `ENTRA_CLIENT_ID` 的真实安装/连接或明确失败路径；五通道、录像、UI 和清理齐全后才决定 `TOOL-099` 五格。

# 2026-08-04 10:28 · TOOL-098 list_mcp_marketplace 正式通过，40/50

- formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-100552` 使用全新 workspace、真实 Flutter App、真实受管 gateway、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal；录屏 `385.805000s / 2784x1808 / 60fps`。
- 三条真实路径完成：`query="database query"` 返回 4 个 installable server，逐 server 卡片显示 full name/description/runtime/required-env 数量，正文区分 required/optional env；`zzz_unfindable_capability_987` 返回 0，UI 提供 broaden/single keyword/no-query/capability 四类恢复建议；无 query 返回 96，卡片显示 `first 30 of 96`，点击进入有界 JSON tree（count 96、servers 96）。无失败卡、retry 或死链。
- 五通道一致：SSE 三流连接，messages durable `1..48`、notifications `1..6` 单调唯一；三个 chat body 各只发一次 marketplace call，HTTP 全 200；backend 427 行/frontend 16 行，红线扫描为空；`rig-check` 五观察器全绿。一次 Computer Use 30s observer timeout 后重置 kernel，最终 AX/画面重新获取，作为仪器事件记录而非产品红。
- 前端补充市场卡回归，`dart analyze` 与生态/记忆 widget 测试 `24/24` 全绿；`git diff --check` 通过。正式证据 `tool-098-formal-100552-green.md`。
- `judge.py` 写入 `TOOL-098=list_mcp_marketplace` 的 `G1/F2/A5/C4/G2`，中央账本 `520→525 judgments`，COVERAGE 行 `✓✓✓✓✓`。五格批量写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 anchors `10/10`、三条路径、正式录屏和复审 `tool-098-ledger-alarm-reaudit.md` ack，`alarms.py check` clean；三条验收 conversation 已 DELETE=204、列表为空，evidence/journal/录像保留。下一原子前线 `TOOL-099 install_mcp_server`。

# 2026-08-04 10:03 · TOOL-097 get_model_config 正式通过，35/50

- 首轮 formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-094444` 冻结为产品红：真实后端/LLM wire 返回完整配置，但 durable tool card 只有数量和模型名 chip，用户无法直接核验 key 健康、脱敏值、端点、默认 key 关联和能力边界。红证据 `tool-097-formal-094444-red-thin-card.md` 保留，不计绿。
- stop-and-fix 在前端 `modelConfigBody` 增加默认角色与安全 key 名关联、API key provider/masked/status、端点、bounded model capability table 和 native option chips；不渲染 `apiKeyId`/密文；中英文 i18n 与 privacy/widget regression 同步。
- formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-095429` 使用真实 Flutter App、真实受管 gateway、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal 重跑。录屏 `173.423333s / 2784x1808 / 60fps`；最终展开卡显示六个默认角色、`Anselm Free / anselm / ins_ab0...82c6 / ok`、endpoint、`anselm-auto / 1M / 16.4k / image · video` 和 native option，无 raw JSON、opaque key、剪裁或跳变。
- 五通道一致：SSE 三流各连接一次，messages durable `1..14`、notifications `1..2`，一次 tool call/result；REST/SQLite、tool result、LLM wire、UI 对齐，frontend/backend 红线为空，`rig-check` 五观察器全绿。正式证据为 `tool-097-formal-095429-green.md`，账本复审为 `tool-097-ledger-alarm-reaudit.md`。
- `judge.py` 写入 `TOOL-097=get_model_config` 的 `G1/F2/A5/C4/G2`，中央账本 `515→520 judgments`，COVERAGE 行 `✓✓✓✓✓`。五格批量写账触发的 `gap-too-fast` 与 `discovery-collapse` 已以 anchors `10/10`、红证据/修复链/正式 session 重审并 ack，`alarms.py check` clean；验收 conversations 已 DELETE=204、列表为空，evidence/journal/录像保留。下一原子前线 `TOOL-098 list_mcp_marketplace`。

# 2026-08-04 09:42 · TOOL-096 forget_memory 正式 Allow/Already-gone 通过，30/50

- 复用修复后的真实 binary 和 formal workspace，启动真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 与窗口录制；`rig-check.sh` 在收台前通过五个物理观察器，最终 `screen.mov` 为 `114.498333s / 2784x1808 / 60fps`。
- 首轮红证据仍保留：`danger=cautious` 的 hosted tool call 绕过了不可逆删除的人闸。stop-and-fix 已加入 `ForgetMemory.MinimumDanger() = dangerous`、不可绕过的 canonical summary、Go 回归测试和同步文档；此前 fixed deny session 证明 existing/missing 两条路径 Deny 均无副作用。
- 本次得到 action-time 授权后真实点击 `Allow`：UI 先显示明确的 `Dangerous / Awaiting your approval` 和“不可逆、无恢复操作”，随后显示 `Forgot`；REST memory list 为空、目标 GET=404。新对话再次调用同一工具并批准后，UI 显示中性 `Already gone`，tool result 为 `not found (already gone?)`，没有第二条 `memory.deleted` 通知。
- 五通道交叉核对：两条 conversation 各一次 `forget_memory`，SSE 均为 `tool_call → interaction → resolved → tool_result`；真实删除只产生一条 `memory.deleted`，messages durable 到 seq 28；LLM wire、REST、UI、backend/frontend journal 一致且红线扫描为空。证据为 `sessions/20260804-093819/evidence/tool-096-formal-093819-green.md`，账本复审为 `tool-096-ledger-alarm-reaudit.md`。
- anchors `10/10` 后写入 `G1/F2/A5/C4/G2`，`TOOL-096` 行变为 `✓✓✓✓✓`；五格写账触发 `gap-too-fast` 与 `discovery-collapse`，已按红证据、修复链、正式 session 和复审记录 ack，`alarms.py check` 为 `clean (515 judgments)`。`gen_coverage.py` 重建为 848 rows，验收夹具 conversation 已 DELETE=204、列表为空，memory 已 404。
- 第十批由 **25 / 50** 推进至 **30 / 50**；按批次纪律不提前跑统一长门禁、不提交。下一原子前线：`TOOL-097 get_model_config`。

# 2026-08-03 20:09 · TOOL-096 forget_memory 首轮红后修复，正式重跑完成 deny/approval 边界，25/50

- 首轮 formal `/private/tmp/anselm-rig-formal-20260803-195946` 发现不可逆 `forget_memory` 只收到 hosted model 的 `danger=cautious`，未开人闸便真实删除 memory；红证据 `tool-096-formal-195946-red-missing-danger-floor.md` 保留，不计绿。
- stop-and-fix 为 `ForgetMemory.MinimumDanger() = dangerous`、canonical gate summary 明确“不可撤销、无恢复操作”、破坏性工具总测试和 gate summary 测试，并同步 memory 领域文档与工具清册；定向 Go tests 全绿。
- 修复后 formal `/private/tmp/anselm-rig-formal-20260803-200420` 真实验证 existing-memory 与 missing-memory 两条请求均显示 `Dangerous · Awaiting your approval`；两次 Deny 均无副作用，REST 证明现有 memory 保留。五通道、录屏 `214.911667s / 2784x1808 / 60fps`、anchors 10/10、backend/frontend scan 和 rig-check 均通过。
- 随后异步根门禁 `make verify` 完整跑完 backend/frontend/docs/demo；frontend 四组测试均通过（最后一组含 perf 组 `+915`），root verify 临时日志已按成功路径清理，`git diff --check` 通过。
- 成功 `Allow` 是不可逆动作，尚未得到 action-time confirmation，故不执行、不写 `judge.py`，`TOOL-096` 不进 COVERAGE 绿格；第十批仍 **25 / 50**，账本仍 **510 judgments**，下一动作仍为 `TOOL-096`。

# 2026-08-03 19:55 · 第十批 TOOL-095 write_memory 正式通过，25/50

- 正向 create：真实 App 要求模型用一次 canonical `write_memory` 保存 exact slug/description/body；REST 最终为 `source=ai,pinned=false`，UI 展示可展开 `Memorized … · 1 lines` 卡片，正文与 description 可读，无 raw JSON。
- 正向 update：先以真实 API 建立 `source=user,pinned=true` 的用户策展记忆；新对话中模型一次用同名 `write_memory` 更新 description/body。REST 证明新正文已落盘，但 `source=user` 与 `pinned=true` 均保留，模型没有额外工具调用。
- 负向 slug：真实 App 要求 exact invalid name `Invalid Memory 095` 且禁止归一化；模型原样调用一次，后端返回 `Cannot save memory...invalid`，UI 显示红色 `Not saved` 与规则，未创建行、未 retry。
- formal session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-194919` 使用真实 Flutter App、真实受管 gateway、Computer Use、三路 SSE、LLM tap、backend/frontend journal；录屏 `211.295000s / 2784x1808 / 60fps`，messages `1..42`、notifications `1..9` 连续，LLM 24 条状态全 200，五通道无未解释运行时红线。正式证据为 `evidence/tool-095-formal-194919-green.md`。
- 定向回归：backend memory/tool/chat Go tests、Flutter `tool_card_memory_web_test.dart`、`git diff --check` 全部通过；三条 acceptance conversation 与两个 memory 均真实 DELETE=204、列表为空，最后 workspace 因 last-workspace 约束保留。
- `judge.py` 写入 `TOOL-095=G1/F2/A5/C4/G2`，中央账本 505→**510 judgments**；五格写入触发的 `gap-too-fast`/`pass-burst`/`discovery-collapse` 以 anchors 10/10、formal session 和复审记录 `evidence/tool-095-ledger-alarm-reaudit.md` 逐格复核并 ack，`alarms.py check` clean。下一前线 `TOOL-096 forget_memory`，第十批 **25 / 50**，不提前跑统一长门禁、不提交。

# 2026-08-03 19:47 · 第十批 TOOL-094 read_memory 正式通过，20/50

- 正向 real App 路径：创建未置顶 `acceptance-read-memory` 后，在新对话要求模型读取。LLM 初始 system prompt 只有 name+description index，没有正文 token；模型一次精确调用 `read_memory({"name":"acceptance-read-memory"})`，UI 展示可展开的 source/description/排版正文记忆卡，用户得到精确 token 和 Tuesday review instruction。
- 负向 real App 路径：新对话要求对 `ghost-memory-094` 只调用一次 `read_memory`。后端返回权威 not-found，模型明确报告缺失、不编造；UI 显示中性灰 `Recalled ghost-memory-094 · Not found`，没有 retry、红色 incident 或第二次工具调用。
- formal session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-193847` 使用真实 Flutter App、真实受管 gateway、Computer Use、三路 SSE、LLM tap、backend/frontend journal；录屏 `258.178333s / 2784x1808 / 60fps`，messages `1..28`、notifications `1..5` 连续，LLM 18 条状态全 200，五通道无未解释运行时红线。正式证据为 `evidence/tool-094-formal-193847-green.md`。
- 定向回归：backend memory/tool/chat Go tests、Flutter `tool_card_memory_web_test.dart`、`git diff --check` 全部通过；fixture 两条 conversation 与 memory 均真实 DELETE=204、列表为空、memory GET=404，最后 workspace 因 last-workspace 约束保留。
- `judge.py` 写入 `TOOL-094=G1/F2/A5/C4/G2`，中央账本 500→**505 judgments**；五格写入触发的 `gap-too-fast`/`discovery-collapse` 以 anchors 10/10、formal session 和复审记录 `evidence/tool-094-ledger-alarm-reaudit.md` 逐格复核并 ack，`alarms.py check` clean。下一前线 `TOOL-095 write_memory`，第十批 **20 / 50**，不提前跑统一长门禁、不提交。

# 2026-08-03 19:33 · 第十批 TOOL-093 inspect_media 正式通过，15/50

- 首轮 formal `20260803-185851` 冻结为红：fresh media turn 的 hosted model 看不到 provider media part 对应的 opaque attachment ID，首次把 schema 示例 `att_...` 当成真实 ID 调用 `inspect_media`，后端返回 not found；用户目的虽然最终完成，但多付一次失败调用、等待/token 和幽灵 viewed touchpoint。红证据保留、不计绿。
- stop-and-fix：`backend/internal/app/chat/history.go` 增加只给模型看的 `<uploaded_attachments_for_tools>` 目录，按消息媒体顺序提供精确 ID，并明确 `read_attachment` 用 `id`、`inspect_media` 用 `attachmentId`；用户 bubble、持久化消息和 UI 不变。inspect_media 首行描述和 schema 字段移除可复制的示例值；新增 chat history、inspect description/schema regression test，同步 backend/frontend attachment/chat domain 文档与 tools extract。
- formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-191935` 使用修复后二进制、真实 Flutter App、真实受管 gateway、Computer Use、665.508333s 录屏和五通道台架完成六条产品路径：image default vision、tiles、crop、text query、audio range、video range。首个 image tool call 直接使用真实 ID，无 `list_attachments` 预探；后续每条路径均无失败卡、placeholder 参数、伪造 transcript/scene 或 crop 越界结论。
- 视频路径中模型在完成结果后重复发起一次完全相同的调用；loop 返回 `Duplicate tool call suppressed`，未二次执行、未二次审批，作为同回合幂等守卫正向证据保留。最终 UI 结果清楚、工具卡单一且可读。
- 五通道：`screen.mov` `665.508333s / 2784x1808 / 60fps`；SSE 408 frames，messages durable `1..97`、notifications `1..2` 连续；LLM `58×200/8×201`，精确 tool args/results 与 SQLite/UI 一致；backend/frontend error scan clean；live `rig-check` 五通道全绿，`rig-down` 干净收台。
- 正式证据为 `evidence/tool-093-formal-191935-green.md`，红证据为 `sessions/20260803-185851/`，账本复审为 `tool-093-ledger-alarm-reaudit.md`。以显式 `export RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 写入五级 `TOOL-093=G1/F2/A5/C4/G2`，中央账本由 495 增至 **500 judgments**；`gap-too-fast` 与 `discovery-collapse` 经红绿 session、修复测试、anchors 10/10 和五通道原始日志复审并 ack，`alarms.py check` 为 `clean (500 judgments)`。
- 第十批当前 **15 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线 `TOOL-094 read_memory`。

# 2026-08-03 18:55 · 第十批 TOOL-092 read_attachment 正式通过，10/50

- 首轮真实 red session `20260803-183532` 暴露 hosted caller 在已 `list_attachments` 后仍将 `read_attachment` 参数写成 `attachmentId`，后端正确返回 `id is required`，App 出现失败卡；该红证据保留、不计绿。
- stop-and-fix：schema/description 明确 canonical `id`，字段说明给出 `{"id":"att_..."}` 示例并显式排除 `attachmentId`；`readArgs` 对受管 caller 做窄兼容归一化 `attachmentId → id`，不改变 workspace/附件权限边界。新增 alias regression test，同步 attachment domain 文档和 tools extract。
- fixed formal session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-184402` 真实 App + 真实受管 gateway + Computer Use + 三路独立 SSE + LLM tap 完成：小文本精读、182KB Markdown `index/offset/query`、越界 offset、PNG media descriptor 四条路径；长文索引 `19 chunks / 145689 chars`，越界返回真实 `totalChars=145689` 与恢复建议，PNG 明确指向 `inspect_media`，无失败卡/溢出/伪造视觉结论。主录屏 `432.071667s / 2784x1808 / 60fps`。
- 五通道：messages durable `1..111`、notifications `1..2` 连续，entities 已连接；LLM 42×200/2×201，backend/frontend error scan 0；同数据目录重开 session `20260803-185153` 恢复 workspace、Recents、PNG 和成功 read 卡。证据 `evidence/tool-092-formal-184402-green.md`，重开 `evidence/tool-092-reopen.md`，账本复审 `tool-092-ledger-alarm-reaudit.md`。
- 账本 gate：formal `export RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 下写入 `TOOL-092=G1/F2/A5/C4/G2`，490→495 judgments；`gap-too-fast` 与 `discovery-collapse` 按红证据、修复测试、432s 真 session、长文/媒体负路径和 durable reopen 复审并 ack，`alarms.py check` 为 `clean (495 judgments)`。
- 当前第十批 **10 / 50**，未到 50 格不跑统一长门禁、不提交；下一原子前线 `TOOL-093 inspect_media`。

# 2026-08-03 18:31 · 第十批 TOOL-091 list_attachments 正式通过，5/50

- 首轮真实 session `20260803-180353` 暴露产品红：工具结果有精确 `createdAt`，但前端附件行忽略 kind/createdAt；模型正文把 timestamp 写成 `the recorded time`，看似报告字段但用户拿不到值。红证据 session 与录屏保留，不计绿。
- stop-and-fix：`list_attachments` description/schema 明确 `createdAt` 是 exact ISO 且精确值留在附件卡；`attachmentListRow` 展示 kind/MIME/size/localized createdAt；全局 opaque timestamp redaction 不放宽，附件表格单元格改为明确 `See the exact upload time in the attachment card.`。redactor 增加跨 provider chunk 的表头/数据行有界暂存及 direct/stream regression；同步 attachment/chat/frontend/extract 文档。
- 新 formal session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-182222` 从空数据目录真实 onboarding 重跑：空列表准确显示 empty；上传 91-byte plain-text fixture 后只调用一次 list，工具卡列出 filename/kind/MIME/size/本地化上传时间，正文指向卡片；切到 New chat 再从 Recents 重开，结果完整恢复。Computer Use 最终帧没有溢出、剪裁、红卡或视口跳变；录屏 `346.391667s / 2784x1808 / 60fps`。
- 五通道封口：SSE 三流连接，messages durable `1..29` 连续无 gap；LLM proof/install/models/chat 全 200，tool result/LLM wire/SQLite/UI 同一 live row；backend/frontend error scan clean。正式证据为 `evidence/tool-091-formal-182222-green.md`，终帧为 `tool-091-final.png`。
- 账本 gate：以显式 `export RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3` 写入 `TOOL-091=G1/F2/A5/C4/G2`，中央账本 **485→490**。`gap-too-fast` 与 `discovery-collapse` 经 anchors 10/10、五通道、SQLite、红证据和绿证据复审后 ack，正式 `alarms.py check` 为 `clean (490 judgments)`；复审记录为 `tool-091-ledger-alarm-reaudit.md`。
- 操作纪律补强：一次未 export 的试写误落默认 `~/.anselm-rig`，未作为正式依据；已销默认误警，并将“shell 必须 export RIG_HOME，不能只给单条命令环境前缀”补入 `testend/rig/README.md`。当前第十批 **5 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线 `TOOL-092 read_attachment`。

# 2026-08-03 18:02 · 用户授权后的 TOOL-090 fixture 清理、Goal 恢复检查

- `data-tool090b` 是上一轮隔离验收数据目录，live workspace `ws_488c4c04a60aaeb8` 中只剩 conversation `cv_3bd441a0d334aa00` 与 standalone document `doc_1b398ca1ba3b8394`；此前已删除的 root/child/deep document 保持 tombstone，不重复处理。
- 在独立本地 API cleanup session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-180108` 中，按用户授权真实调用 DELETE：conversation/document 均返回 `204`；随后同 workspace GET 均返回 `404`，`/conversations` 与 `/documents` 列表均为空。SQLite 软删审计保留，正式验收 session、screen.mov、SSE/LLM/backend/frontend journals 未删除。
- cleanup 台架已由 `rig-down.sh` 正常收台，无 backend/ssetap/Flutter/llmtap/recorder 残留。Goal API 当前为 `active`，没有创建重复 goal、没有伪造完成；下一原子前线仍为 `TOOL-091 list_attachments`。

# 2026-08-03 17:53 · 第九批统一长门禁通过并提交

- `testend/scenarios/TestContractDocsAtt_DocumentChildrenDuplicateMove` 首轮长门禁确定性失败：测试仍断言 `/documents?parentId` 一次返回 55 行；该断言与当前 `ListByParentPage`、`docs/references/backend/api.md` 的默认 50 + opaque cursor 契约冲突，未改生产行为。
- 修正 testend 契约测试为首页 50、cursor 续页 5、顺序保持、跨页无重复、非法 cursor 返回 `400 INVALID_REQUEST`，并明确由 `/documents/tree` 承担整树 metadata 一次加载；`gofmt` 后定向测试通过。
- 完整 `mise exec -- go test ./...`（testend，`scenarios 319.089s`）通过；根目录 `make verify` 的 backend/frontend/docs/demo 全部通过；backend 目录 `mise exec -- go test ./...` 全部通过；残留进程为空，锚点 10/10 重新校准解锁 4h，`alarms.py check` 为 clean，`git diff --check` 通过。
- 复核发现无 `RIG_HOME` 的命令会读到旧默认账本（20 条），并非本批账本；正式台架根 `/private/tmp/anselm-rig-formal-20260801-3` 的同源执行为 `10/10`、`clean (485 judgments on record)`。台架 README 已明确所有 judge/alarms/anchors 命令必须绑定同一个 `RIG_HOME`。
- 第九批 `TOOL-081..090` 五级裁决保持 **485 judgments / 50/50**，统一长门禁完成并提交为 `32b33499`，下一原子前线 `TOOL-091 list_attachments`。

# 2026-08-03 17:13 · 第九批 TOOL-090 delete_document 正式通过，50/50，长门禁进行中

- 首轮 formal `20260803-170003` 冻结为红：真实 App 的后端 `Document "doc_missing_delete_090" not found` 与最终 prose 都正确，但工具卡仍显示 `Deleted document`，并保留成功软删注记；红证据保留为 `tool-090-formal-170003-red-not-found.md`。
- stop-and-fix：前端增加 completed not-found payload 的确定性重分类，失败动词改为 `Delete document failed`，自动展开琥珀原始证据，失败体不再渲染 `soft-deleted, recoverable`；补充 parser/widget 回归并同步 Document/Chat 文档和工具抽取清册。
- formal green `20260803-170748` 使用新二进制、全新 onboarding、真实 Flutter App、真实受管 gateway、Computer Use、234.611667s 封口录像、backend/frontend journal、三路独立 SSE witness 和 LLM tap 重跑。正向 exact search + 一次 cascade delete 真正删除 root/child/deep 三行，Standalone 活着；负向一次 missing ID 无 mutation；Library 只显示 Standalone。SQLite/REST/UI/tool result/LLM wire 一致，SSE 298 frames、messages durable `1..36`、notifications `1..7` 单调、无 gap，LLM 全 200，backend/frontend 无未解释红线。正式证据为 `evidence/tool-090-formal-170748-green.md`。
- `judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，中央账本由 480 增至 **485 judgments**；`gap-too-fast` 与 `discovery-collapse` 按 10/10 anchor、红证据/修复测试/绿 session/五通道复审后 ack，复审记录为 `tool-090-ledger-alarm-reaudit.md`，`alarms.py check` 最终 `clean (485 judgments)`。第九批到达 **50 / 50**，当前进入统一长门禁，下一原子前线 `TOOL-091 list_attachments`。

# 2026-08-03 16:54 · 第九批 TOOL-089 move_document 正式通过，45/50

- formal `20260803-162904` 首轮冻结为红：真实 App 在 true-cycle 拒绝后重复同一 document/parent pair，且前端把 terminal duplicate 渲染为误导性的第二张 `Not run` 卡。红证据保留、不计绿。
- stop-and-fix：增加不改变 S18 五方法 `Tool` 接口的可选 `RepeatTerminaler`；per-Run ledger 区分安全失败可重试、危险/保护调用停回合和 terminal cycle rejection；前端只隐藏 terminal duplicate 噪声，durable/SSE/audit 仍保留；move 工具描述/schema、localized failure/cycle copy、后端/前端领域文档、工具抽取清册和 Go/Flutter 回归同步。
- formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-164319` 以修复后二进制、真实 onboarding、真实 Flutter App、受管 gateway、Computer Use、546.920000s 封口录像和五通道台架完成：一次 position 0 移入、一次 position 2 移回 root、一次单次 destination list、一次 true-cycle terminal reject。SQLite seq `3/4`、`9/10`、`12/13`、`18/19`、最终 parent/position/path 与 UI/tool result/wire 一致；SSE 452 frames、61 durable、无 gap；LLM 全 200；backend/frontend 无未解释红线。正式证据为 `evidence/tool-089-formal-164319-green.md`。
- `judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，中央账本由 475 增至 **480 judgments**；`gap-too-fast` 与 `discovery-collapse` 按 10/10 anchor 重校、红证据/修复测试/绿 session/五通道复审后 ack，复审记录为 `tool-089-ledger-alarm-reaudit.md`，`alarms.py check` 最终 `clean (480 judgments)`。正式 session、journals、LLM wire、SSE witness 和 screen.mov 保留；第九批 **45 / 50**，下一前线 `TOOL-090 delete_document`，未到第 50 格不跑统一长门禁、不提交。

# 2026-08-03 16:01 · 第九批 TOOL-088 edit_document 正式通过，40/50

- formal-150806、151705、152100、152600、153110、153603、154652 先后冻结为红：reasoning placeholder 泄漏、tags JSON 编码失败、同一意图拆成两次 edit、重复 search 失败循环、hosted provider 双重编码 tags、失败 search 后恢复不稳，以及 filesystem-shaped `path/pattern` 参数投给 `search_documents`。七份真实红证据均保留，不计绿。
- stop-and-fix：loop 增加 per-Run tool ledger，成功 safe call 只抑制重复而不结束回合，失败 safe call 保留 retry，危险/越界重复仍按保护规则停回合；`search_documents` 增加不读 filesystem 的窄 provider compatibility；`edit_document.tags` 接受精确一层 JSON 编码数组并拒绝任意字符串；prompt/schema 收紧为单一 canonical edit、完整 search 后逐字复制 opaque `doc_` ID。同步 loop/document/chat 测试、领域/API 文档与工具抽取清册，定向 Go tests、docs verify 和 diff check 通过。
- formal-155506 使用新二进制、真实 onboarding、真实 Flutter App、真实受管 gateway、Computer Use、140.740000s 录屏、backend/frontend journals、三路独立 SSE witness 和 LLM tap 重跑。root `/Release Atlas Final` 完整更新，child 路径随 rename 正确级联；wire 只有一次成功 search、一次成功 edit、一次成功 child search，无 retry/失败活动/重复 mutation。SQLite/REST、tool result、UI 和五通道一致；messages durable `1..27`、notifications `1..5` 连续，LLM 全 200，backend/frontend clean。正式证据为 `sessions/20260803-155506/evidence/tool-088-formal-155506-green-edit-document.md`。
- 台架收台后仅删除已隔离的 `discarded-tool088` 临时 fixture，正式 session、journal、LLM bodies/responses、SSE witness、frontend/backend log 和 `screen.mov` 保留。10/10 anchor 校准有效，`judge.py` 写入 `G1/F2/A5/C4/G2` 五格，中央账本由 470 增至 **475 judgments**；警报复审后 `alarms.py check` 为 `clean (475 judgments)`。第九批 **40 / 50**，下一前线 `TOOL-089 move_document`；未到第 50 格不跑统一长门禁、不提交。

# 2026-08-03 15:00 · 第九批 TOOL-087 create_document 正式通过，35/50

- formal-140938、142906、143806、144710 先后冻结为红：分别发现 placeholder ID 进入用户表格、首次 create 漏掉必填 name、先造空根再删除/编辑且同名子文档重复 mutation、以及用户明确提供的 description/tags 被模型静默漏传。四份真实红证据均保留，不计绿。
- stop-and-fix：system prompt 与 loop redactor 修复 placeholder 泄漏后，create_document 的 LLM schema 收紧为每次必传 name/description/content/tags；未提供后三者显式传空字符串/空数组，用户值必须在同一 canonical call 原样带上。同步 `backend/internal/app/tool/document/create.go`、document contract tests、工具抽取清册与 document domain 文档；定向 Go tests、docs verify、diff check 通过。
- formal-145421 使用新二进制、全新 data dir、真实 Flutter App、真实受管 gateway、Computer Use、窗口录屏、三路 SSE witness、LLM tap 和两类 journal 重跑。root `/Release Atlas` 与 child `/Release Atlas/Ship Checklist` 正确写入；root description/tags、child description、parentId 均与用户输入和 wire 一致。最终 UI 只显示两项 Created，无 retry/delete/edit/duplicate/failure；SSE durable messages/entities/notifications `1..26`/`1..4`/`1..4` 连续唯一；LLM 两次实际 create 全 HTTP 200；REST/SQLite/tool result/UI 一致，backend/frontend clean，录屏 `282.973333s`。正式证据为 `sessions/20260803-145421/evidence/tool-087-formal-145421-green-create-document.md`。
- 台架已收台，五通道 journals 与 screen.mov 保留。10/10 anchor 重校后，`judge.py` 写入 `G1/F2/A5/C4/G2`，中央账本由 465 增至 **470 judgments**；`gap-too-fast`/`discovery-collapse` 依据锚点、四份真实红证据、最终绿证据和五通道复审后 ack，`alarms.py check` 最终 `clean (470 judgments)`。第九批 **35 / 50**，下一前线 `TOOL-088 edit_document`；未到 50 格不跑统一长门禁、不提交。

# 2026-08-03 13:56 · 第九批 TOOL-086 read_document 正式通过，30/50

- 首轮真实 App 观察冻结两条产品红：formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-133944` 中 `search_documents` 的 query-required 空参数被前端 generic entity card 误呈为 `Listed document · failed`，且 hosted model 将 filesystem `path/pattern` 形状投给文档搜索；formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-134623` 中模型将 `Engineering Handbook` 路径误当作 `read_document.id`，留下可见 not-found 后才搜索重试。两份红证据均保留、不计绿。
- stop-and-fix：前端 `_entitySearch` 增加 `listWhenQueryEmpty` 开关，`search_documents` 固定走 query-required search channel，补 `entity_search_verb_test.dart` 并同步 Chat 文档；后端 `read_document` description/schema 明确必须逐字复制 `search_documents`/`list_documents` 返回的 opaque `doc_` ID，禁止名称或路径，补 `TestReadDocument_ContractRequiresOpaqueID` 与 document domain 文档。`gofmt`、`go test ./internal/app/tool/document`、Flutter entity-search 定向测试和 `git diff --check` 通过。
- formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-135027` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、连续录屏和五通道台架重跑：LLM wire 严格为 `search_documents(query)` → `search_tools` → `read_document(id=doc_0628e58b2f3d8c1d)`，无失败卡/retry；最终 UI 完整展示 path、description、tags、全部标题、中文注记和最终句，画面清楚。REST/SQLite、tool result 与 UI 逐字一致，messages durable `1..27` 连续，三流连接，LLM 全 200，backend/frontend 错误扫描 clean；录屏 `159.260000s / 2784x1808 / 60fps`。正式证据为 `evidence/tool-086-formal-135027-green-read-document.md`。
- `judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，中央账本由 455 增至 **460 judgments**；`gap-too-fast` 与 `discovery-collapse` 依据两份红证据、绿 session、五通道交叉核对和复审说明 `tool-086-ledger-alarm-reaudit.md` ack，`alarms.py check` 最终 `clean (460 judgments)`。独立 cleanup session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-135432` 将 root/child document 与 acceptance conversation DELETE=204、随后 GET=404，列表为空，台架收台。第九批 **30 / 50**，下一前线 `TOOL-087 create_document`；未到 50 格不跑统一长门禁、不提交。

# 2026-08-03 13:35 · 第九批 TOOL-085 list_documents 正式通过，25/50

- 首轮正式空目录路径在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-130911` 冻结为红：根列表成功后旧共享 LLM transport 的 60 秒响应头预算耗尽，真实 App 显示 `LLM_STREAM_ERROR`，没有给用户空目录结果；红证据 `evidence/tool-085-formal-130911-red-empty-folder-header-timeout.md` 保留、不计绿。
- stop-and-fix 将共享建连响应头预算提高到 120 秒，仅覆盖受管网关冷路由/上游唤醒；`ChatTurnSec`、流式 idle、`LLMStreamMaxSec` 未放宽。补 `TestNewHTTPClient_SeparatesSetupAndStreamingBudgets` 与 Chat domain 预算契约，`go test ./internal/infra/llm`、`git diff --check` 和 docs verify 通过。
- formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-132312` 重新 onboarding 并构造真实树：根 5 个、Projects 3 个子项、Large Collection 120 个直接子项、Empty Notebook 0 个子项。HTTP 三页 `40/40/40` 与游标真实正确；Computer Use 强制模型执行根列表 + 三页 cursor，最终 UI 明示 `complete:true`、`hasMore:false`、总数 120、首尾位置 0/119；独立空路径显示 `Listed document · empty` 并回答 zero documents。
- 五通道封口：`screen.mov` `418.840000s`；LLM tool args/results 与 REST 逐字一致且所有响应 200；SSE 三流均连接，两个 conversation durable seq 分别 `1..36`、`37..54` 连续；backend/frontend 错误扫描 clean。正式证据为 `evidence/tool-085-formal-132312-green-list-documents.md`。
- 五级 `TOOL-085=G1/F2/A5/C4/G2` 由 `judge.py` 写入 COVERAGE，中央账本从 450 增至 **455 judgments**。五格原子落账触发 `gap-too-fast`，历史尾窗无 fail 触发 `discovery-collapse`；两条均基于红/绿 session、五通道和夹具事实复审后 ack，复审为 `tool-085-ledger-alarm-reaudit.md`，`alarms.py check` 最终 `clean (455 judgments)`。第九批 **25 / 50**，下一前线 `TOOL-086 read_document`；未到第 50 格不跑统一长门禁、不提交。

# 2026-08-03 12:48 · 第九批 TOOL-084 search_documents 正式通过，20/50

- 首轮真实 App 路径冻结为红：formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-121222` 将 filesystem Grep 的 `path/pattern` 形状投给文档搜索；`121822` 暴露结果带 `hasMore/nextCursor` 但工具 schema 没有 cursor；`122316` 暴露 assistant 在同一 tool-call 消息中先输出用户可见 Page 3 文本，最终重复回答；`123034` 暴露 hybrid semantic-only recall 把 `Noisy Field Notes` 混进 `heliograph` 关键词结果；`123622` 暴露模型首轮不带 limit、先无界查询再重做分页。红证据均已保留，不计绿。
- stop-and-fix：`search_documents` 明确为文档库内容/标题检索，不接受 filesystem `path/pattern`；schema 与执行边界补齐 `query/limit/cursor`，要求显式上限必须在首调用携带，cursor 必须逐字续传；结果补 durable path/description/tags；文档关键词路径显式 `LexicalOnly`，不改变 RAG/omni 的 hybrid 语义；chat prompt 增加 tool-call assistant message 不得携带用户答案的单一回复规则。同步 Go/chat 测试、domain/API 文档与工具抽取清册。
- formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-124129` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、连续录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap 重跑。首调用 wire 为 `{"limit":1,"query":"heliograph"}`；第二、三页分别使用精确 cursor `eyJoIjoiY2UxNGM5MjM4NzRkIiwibyI6MX0` 与 `eyJoIjoiY2UxNGM5MjM4NzRkIiwibyI6Mn0`，总计 3 条目标文档，无 `Noisy Field Notes`，最终 UI 只出现一份答案且无失败卡/retry/重复 Page 3。
- 五通道封口：`screen.mov` `187.523333s`；SSE durable seq `1..48` 连续；LLM wire、tool result、REST/SQLite 与 UI 一致；backend/frontend 无 `error|exception|panic|fatal|assert` 未解释红线；fixture 清理 DELETE=204、GET=404、列表为空。`rig-check` 在运行中五通道全绿，随后 `rig-down` 干净收台并保留 journals。
- 证据为 `sessions/20260803-124129/evidence/tool-084-formal-124129-green-search-documents.txt`；账本复审为 `tool-084-ledger-alarm-reaudit.txt`。`judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，中央账本由 445 增至 **450 judgments**；`alarms.py check` 最终 `clean`，本轮告警均依据红证据、绿证据和复审说明 ack，不隐藏统计异常。第九批当前 **20 / 50**，下一前线 `TOOL-085 list_documents`；未到 50 格不跑统一长门禁、不提交。

# 2026-08-03 12:08 · 第九批 TOOL-083 search_firings 正式通过，15/50

- 首轮 formal-138 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-115803` 真实 App 冻结为红：hosted model 将 `limit` 发成 `"3"`，后端类型拒绝并留下可见失败活动/retry。formal-139 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-120111` 在 limit decoder 修复后又暴露模型把 `pattern` 发给 firing inbox，遗漏必填 `triggerId`，再次留下失败活动/retry；两份红证据均保留、不计绿。
- stop-and-fix：`search_firings` 执行边界接受 native integer 或 exact decimal integer string，公开 schema 仍为 integer；description/schema/validation 明确必须从 `search_triggers` 或工具卡逐字复制 exact opaque `triggerId`，不是 name/pattern/`the requested item`，并补 limit/shape/description/validation 回归测试。同步 API 文档与 `testend/rig/extracts/tools.md`。
- formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-120402` 真实新二进制 + Flutter App + 受管 gateway + Computer Use：no-status/started/skipped 三条有效查询均成功，结果 1/1/0；空 skipped 被正确解释为合法 no-match。最终 UI 无失败活动/retry，LLM wire 全 200；同批重复只读调用由 loop 幂等抑制，没有重复 repository 访问。五通道证据：screen.mov `141.861667s`，SSE messages durable `1..39`、notifications `1..2` 单调唯一，backend/frontend 无未解释红线。正式证据为 `evidence/tool-083-formal-120402-green.txt`。
- 五级 `TOOL-083=G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本从 440 增至 **445 judgments**。`gap-too-fast`、`pass-burst`、`discovery-collapse` 经两份红证据、修复测试、绿 session 和锚点复审后 ack，最终 `alarms.py check` clean；复审说明为 `tool-083-ledger-alarm-reaudit.txt`。第九批 **15 / 50**，下一前线 `TOOL-084`，未到 50 格不跑统一长门禁、不提交。

# 2026-08-03 11:56 · 第九批 TOOL-082 get_activation 正式通过，10/50

- formal `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-115120` 真实 Flutter App + 受管 gateway + Computer Use 直接读取历史 activation `tra_eb22f6013f7ea958`，并读取不存在 `tra_0000000000000000`。正向 200，负向 404；模型只发两次 `get_activation`，无 `search_activations`、retry 或其它工具。最终 UI 完整展示 fired/kind/payload/firingCount/returnValue/detail/createdAt，解释 manual fire 绕过 sensor condition 且 optional 字段缺席不应编造；负向只显示权威 not-found。
- 五通道：screen.mov `179.710000s`；SSE 三流连接，messages durable `1..18`、notifications `1..2` 单调唯一；LLM proof/chat 响应全 200；backend 只有刻意不存在 ID 的一条 WARN；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线。正式证据为 `evidence/tool-082-formal-115120-green.txt`。
- 五级 `TOOL-082=G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本从 435 增至 **440 judgments**。第一次连续 gate 命令在证据文件同步瞬间写入 L1-L4、拒绝 L5；确认文件非空后幂等补写 L5，没有绕过 gate。`gap-too-fast`/`discovery-collapse` 经本轮 session、负路径和既有红证据重审并 ack，最终 `alarms.py check` clean；复审说明为 `tool-082-ledger-alarm-reaudit.txt`。第九批 **10 / 50**，下一前线 `TOOL-083`，未到 50 格不跑统一长门禁、不提交。

# 2026-08-03 11:47 · 第九批 TOOL-081 search_activations 正式通过，5/50

- 首轮真实 App 观察冻结三条红：第一轮把 `firingCount` 说成 trigger 历史累计；第二轮把 `payload.manual=true` 说成 sensor CEL 阈值通过；第三轮修复语义后，hosted model 把 `firedOnly`/`limit` 发送成字符串，后端拒绝并在 UI 留下失败活动与 retry。三份红证据均保留、不计绿。
- stop-and-fix：`backend/internal/app/tool/trigger/activations.go` 明确逐行 per-activation workflow fan-out 与 manual bypass 语义；增加只接受 exact `"true"`/`"false"` 和十进制整数字符串的窄兼容，错误形状仍拒绝。同步 `manage_test.go`、trigger domain/API 文档和 `testend/rig/extracts/tools.md`；`go test ./internal/app/tool/trigger ./internal/app/loop`、`git diff --check` 通过。
- formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-113825` 使用新二进制、真实 Flutter App、真实受管 gateway、Computer Use、窗口录屏和五通道台架。最终 UI 正确解释 `firingCount=1` 是单条 activation 扇出 1 个 workflow；`manual=true` 绕过 CEL，不证明阈值为真；低值 sensor probes 为 `fired=false`。最终 LLM 请求序列只有 `search_triggers → search_activations`，没有失败请求/retry；screen.mov `314.906667s`，SSE durable seq 单调无重复，三流已连接，LLM chat/proof 响应全 200，backend/frontend 无未解释红线。一次 Computer Use wrapper 超时被单独记为观察器仪器事件，重启 kernel 后重新取得最终帧，不计产品红。
- 正式证据为 `sessions/20260803-113825/evidence/tool-081-formal-113825-green.txt`；五级 `TOOL-081=G1/F2/A5/C4/G2` 写入 COVERAGE，中央账本由 430 增至 **435 judgments**。`gap-too-fast` 与 `discovery-collapse` 经过 session、红证据和 10/10 anchor re-audit 后 ack，`alarms.py check` clean；复审说明为 `tool-081-ledger-alarm-reaudit.txt`。
- 允许删除后的清理 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-114620` 通过本地 API 将 workflow、trigger、function 和 4 条 acceptance conversation 全部 DELETE=204，GET=404、列表为空；SQLite 保留软删审计、57 activations/1 firing；台架进程已清零。第九批 **5 / 50**，下一前线 `TOOL-082`，未到 50 格不跑统一长门禁、不提交。

# 2026-08-03 10:49 · 第八批 TOOL-080 fire_trigger 正式通过，50/50 收口待统一长门禁

- 首轮真实暂停负向冻结为红：助手错误建议用 `edit_trigger` 清除 paused，但该工具不能 resume。红证据保留于 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-103209/evidence/tool-080-red-paused-wrong-resume-guidance.txt`，不计绿。
- stop-and-fix：同步 `FireTrigger` 描述、trigger domain docs、工具抽取清册，明确 `TRIGGER_PAUSED`、Resume control/`POST /api/v1/triggers/{id}:resume`，并明确 `edit_trigger` 不可恢复；补工具描述守卫测试。`go test -count=1 ./internal/app/tool/trigger ./internal/app/loop` 通过。
- formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-104036` 真实 active/paused 双路径：正向只调用一次 `fire_trigger`，产生 activation `tra_77b6353d19b9ba70`、一个 firing 和 completed flowrun `fr_1dfce2fbff3f084b`；暂停负向只调用一次，展示真实错误和正确 Resume 指引，无 retry、`trigger_workflow` 或 mutation。五通道证据：screen.mov `223.748333s / 2784x1808 / 60fps`，SSE 三流无 gap/error，LLM 响应全 200，backend 仅预期 paused WARN，frontend 无运行时红线。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-104036/evidence/tool-080-formal-green-fire-trigger.txt`。
- fixture 通过真实 API DELETE=204 清理，随后 GET=404、命名列表为空，activation/firing/flowrun 审计行保留。五级 `TOOL-080=G1/F2/A5/C4/G2` 写入 COVERAGE，中央账本 **430 judgments**，第八批 **50 / 50**；锚点 10/10 有效，`alarms.py check` clean。统一长门禁、完整 testend、工作树审计和提交已解锁，下一前线暂缓。
- 统一收口：根 `make verify` 的 backend/frontend/docs/demo 全绿，显式 `go test ./...` 全绿。第一次完整 testend 在 `TestContractChat_TouchpointSelfReportAndNameBorrow` 暴露旧 fixture 未处理 `delete_function` 的 dangerous gate；没有降低安全 floor，修改 testend 用例依次批准两道人闸，定向场景 `6.456s` 通过；第二次完整 `make testend` `310.401s` 全绿。收台后无 testend/llama 残留进程，`git diff --check` 与 `alarms.py check` clean；当前进入工作树审计与提交。

# 2026-08-03 10:29 · 第八批 TOOL-079 delete_trigger 正式通过，Popover AXTree 红线已修复

- 首轮 stop-and-fix 观察在打开/关闭模型 Popover 后发现 105 行 macOS `AXTree` 更新失败：`Failed to update ui::AXTree, error: 149 will not be in the tree and is not the new root`。画面表面正常但 accessibility tree 已退化，不能计绿；`frontend/lib/core/ui/an_popover.dart` 增加常驻 `Semantics(container:true, explicitChildNodes:true)` 边界，补 `an_menu_test.dart` 回归，并同步 chat feature/testend 文档。
- 修复验证：Popover 定向 Flutter test 14/14；`frontend/make verify` 5174 项；`docs/make verify`；`go test -count=1 ./internal/app/loop ./internal/app/tool/trigger ./internal/app/tool`；`git diff --check` 均通过。
- 负向 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-073913` 真实 Deny 后 trigger 主行仍存在、没有删除 touchpoint；正向 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-101120` 使用新二进制、真实 Flutter App、受管 gateway、Computer Use 和连续录屏完成 Allow。Gate 具体说明主行不可恢复、listener 停止、关系影响和审计历史保留；UI 只出现一次 `delete_trigger` 和一次 Allow，最终显示 `Deleted trigger ... · deleted`。
- 五通道交叉核对：`rig-check` 在运行中全绿；screen.mov 封口 `838.035000s / 2784x1808 / 60fps`；frontend journal 无 Flutter/Dart/RenderFlex/Unhandled 红线；backend journal 无 panic/FATAL/ERROR；SSE 三流已连接，messages durable `1..13` 连续；LLM wire 恰有一次 canonical delete call，所有网关响应 200。SQLite/REST 证明 `deleted_at` 审计保留、正常读取不可见、activation/firing 为 0、created/deleted touchpoint 成对存在；正式证据为 `evidence/tool-079-formal-green-delete-trigger.txt`。
- 五级 `TOOL-079=G1/F2/A5/C4/G2` 已由 `judge.py` 写入 COVERAGE，中央账本为 **425 judgments**。两条批量写账警报 (`gap-too-fast`、`discovery-collapse`) 均经红绿证据复审并 ack，`alarms.py check` 最终 clean；第八批推进到 **45 / 50**，下一前线 `TOOL-080 fire_trigger`，未到 50 格不跑统一长门禁、不提交。

# 2026-08-03 07:12 · 第八批 TOOL-078 edit_trigger 正式通过

- formal-136 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-065903` 首轮真实 App 冻结为红：hosted model 把 `create_trigger.config` 发成 JSON 字符串，后端拒绝，Flutter 活动岛出现失败卡，随后 retry 才成功。该错误历史保留，不计绿。
- stop-and-fix：`backend/internal/app/tool/trigger/build.go` 增加 create/edit 对称严格对象解码，接受原生 object 与精确 JSON 编码 object string，拒绝数组/标量/普通文本/坏 JSON；edit 复用 sensor output map→CEL 归一化。补 trigger Go 测试、工具描述、领域文档和清册同步。
- formal-137 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-070531` 新二进制真实 onboarding + 受管 gateway + Computer Use 重跑：create `acceptance_078_cron` 后一次 edit 改名/描述/表达式到 `*/15`，再更新到 `*/20`；最终 UI 无失败卡、retry 或 Settling 残留，SQLite 只有一条 `acceptance_078_cron_renamed`，config=`{"expression":"*/20 * * * *"}`，paused=0。模型最后一次虽在 reasoning 中说要字符串化，实际 wire 仍为 native object，已如实记录，不冒充字符串 wire 成功。
- 五通道：screen.mov `222.758333s`；rig-check 五通道在线且 D1 归属正确；SSE 432 帧，notifications durable `1..2`、messages durable `1..59` 单调唯一，三流均连接；LLM tap 36 条 journal、10 bodies、24 个有状态响应全 200；backend/frontend 错误扫描 clean。正式证据为 `evidence/tool-078-formal-137-green-edit-trigger.txt`。
- 五级 `TOOL-078=G1/F2/A5/C4/G2` 写入 COVERAGE，中央账本从 425 增至 **430 judgments**；批量写账触发 `gap-too-fast`，已用 formal-137 完整复核说明 ack，`alarms.py check` clean。第八批推进至 **40 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线 `TOOL-079 delete_trigger`。

## 2026-08-03 06:56 · 第八批 TOOL-077 create_trigger 正式通过

- formal-132 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-062539` 首轮真实 webhook 路径冻结为红：助手正文把 webhook endpoint 中的 opaque trigger id 脱敏成不可用的 `the requested item`，用户无法复制可工作的 URL。formal-133 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-063222` 暴露 sensor `config.output` 对象 map 被后端拒绝两次后才成功；formal-134 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-063932` 暴露 fsnotify 坏 config 触发 Flutter `String`→`Map` 强转异常，App 出现 `Something went wrong`。三份红证据已保留，不计绿。
- stop-and-fix：`redact.go` 改为让 webhook endpoint 的可用语义留在工具卡、而不让机器 id 污染助手正文；`create_trigger` 对自然语言 sensor output map 稳定转换为 CEL object literal；`tool_card_trigger.dart` 对坏 config/events 安全降级，失败卡显示真实后端错误而不回显敏感参数。补充 loop/trigger Go 测试、Flutter widget test、Dart analyze 及 backend/frontend domain docs；定向测试全绿。
- formal green `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-064904` 以新二进制、真实 onboarding、真实受管 gateway、Computer Use、连续窗口录屏、backend/frontend journal、三路 SSE witness 和 LLM tap 走通四种 source kind：sensor（真实搜索 function 后创建、5s、condition、total/healthy CEL output）、cron（`*/5 * * * *` 与 next fire）、webhook（`acceptance-077-hook-final`，精确 POST endpoint 只在 Activity card 出现）、fsnotify（绝对路径、create+modify、`*.json`）。所有创建一次成功，四张展开卡字段完整，最终 UI 无错误横幅。
- 五通道交叉核对：`rig-check` 运行中确认五通道在线且归属正确；screen.mov `297.055000s`；SSE 共 778 帧，messages durable 尾段 `102..116` 单调，entities/notifications 生命周期完整；backend 无 WARN/ERROR/panic/FATAL/tool failure，REST 与 SQLite 证明四条 trigger 的 config/outputs/paused/listening 真相；frontend 无 FlutterError/未处理异常/渲染错误；LLM wire 全部经过 tap。正式证据为 `evidence/tool-077-formal-135-green-four-trigger-kinds.txt`。
- 锚点校准因超过 4 小时先被 judge 正确拒绝，随后按 `anchors.py quiz/check` 完成 10/10 校准并解锁 4 小时窗口。五级 `TOOL-077=G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本从 420 增至 **425 judgments**；五格批量写账触发的 `gap-too-fast` 已以完整复核说明 ack，`alarms.py check` clean。第八批推进至 **35 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线 `TOOL-078 edit_trigger`。

## 2026-08-03 06:21 · 第八批 TOOL-076 get_trigger 正式通过

- formal-130 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-060503` 首轮真实 Flutter App + 受管网关 + Computer Use 冻结为红：`get_trigger` 成功后，助手正文复述真实 `trg_...` 内部 ID。红证据 `evidence/tool-076-formal-130-red-trigger-id-leak.txt` 保留且未计绿；根因是 `backend/internal/app/loop/redact.go` 的 opaque ID 前缀族没有覆盖当前 `trg_`。
- stop-and-fix：将 `trg` 加入所有实体 ID 的直接/流式 redaction 族，补充 `redact_test.go` 的直接路径与 provider chunk 拆分回归；同步 `docs/references/backend/domains/chat.md`。`mise exec -- gofmt`、`go test -count=1 ./internal/app/loop` 和 `git diff --check` 通过；rig-up 重新编译新二进制后才重跑。
- formal green session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-061313` 通过真实 onboarding 创建 workspace `TOOL-076 Trigger Observatory Fixed`，接入真实受管 gateway、Computer Use、连续窗口录屏、backend/frontend journal、三路 SSE witness 和 LLM tap。fixture 包含无监听 cron 与由 active workflow 监听的 webhook；暂停后再读 webhook，状态由 `listening=true` 正确变为 `false`。
- 三条真实 App 路径均只调用一次 `get_trigger`、无 retry：live webhook 显示 webhook/path/paused=false/refCount=1/listener=true；paused webhook 显示 paused=true/refCount=1/listener=false；全零不存在 ID 显示 not found。三条助手正文均不含 `trg_`，精确内部值只保留在相邻 tool card、SSE/LLM/审计线缆。
- 五通道交叉核对：录屏封口 `361.345000s`；messages durable `1..44`、notifications `1..8` 连续无 gap，entities 已连接；LLM challenge/install/models 与 6 个 chat completion 响应全 HTTP 200，业务 tool call 恰为 3 次 `get_trigger`；backend 无 panic/FATAL/未解释错误，唯一 WARN 是刻意不存在 ID 的 `trigger not found`；frontend 无 `Unhandled exception`、`FlutterError`、`Lost connection` 或断言红线，启动器既有 `open returned 1` 已单独标注。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-061313/evidence/tool-076-formal-131-green-trigger-get.txt`。
- 五级裁决 `TOOL-076=G1/F2/A5/C4/G2` 已由 `judge.py` 落账，中央账本从 415 增至 **420 judgments**。`gap-too-fast` 与 `discovery-collapse` 因五级裁决在同一真实证据包内原子写账而开启，均已带复核说明 ack，最终 `alarms.py check` clean。第八批推进至 **30 / 50**，未到第 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-077 create_trigger`。

## 2026-08-03 06:04 · 第八批 TOOL-075 search_triggers 正式通过

- formal-129 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-054338` 首轮真实 App 冻结为红：hosted model 发出 `pattern` 而不是公开 schema 的 `query`，旧执行边界静默忽略未知字段，工具结果退化为全量 3 条，App 显示 `Listed trigger · 3 found`。红证据 `tool-075-formal-129-red-pattern-ignored.txt` 保留且未计绿。
- formal-129 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-054842` 在兼容别名加入后再次冻结为红：别名已到达，但语义搜索把两个弱邻居与直接命中混在一起，App 仍显示 3 条。红证据 `tool-075-formal-129-red-semantic-broad.txt` 保留且未计绿。
- stop-and-fix：`backend/internal/app/tool/trigger/query.go` 接受 canonical `query` 与 hosted-model `pattern` 别名；先执行 `name/description/kind` 直接字段命中，只有无直接命中时才走 semantic fallback；`query_test.go` 覆盖 canonical/alias/query-wins/empty/malformed，工具抽取清册同步声明未知搜索键不得静默退化为全量列表。定向 `gofmt` 与 `go test -count=1 ./internal/app/tool/trigger` 通过。
- formal-129 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-055155` 使用真实 Flutter App、真实受管网关、Computer Use、连续录屏、backend/frontend journal、三路 SSE witness 和 LLM tap 重跑。fixture `trg_8273487be54a4c02` 为 `acceptance_webhookpulse_075`（webhook，`refCount=1`，`listening=true`），workflow `wf_af0805d20c0e8439` 引用它；真实 wire 发送 `{"path":"/","pattern":"webhookpulse"}`，业务工具只调用一次 `search_triggers`，无 `get_trigger`/retry。App 最终显示 `Listed trigger · 1 found`，助手准确报告名称、kind 和 listener live。
- 五通道：录屏 `242.068333s`；messages durable `1..14`、notifications `1..4` 单调唯一且无 gap；LLM challenge 与四个 chat completion 响应全 200；backend/frontend 无未解释红线；SQLite、tool result、SSE close、UI 和助手文本一致。正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-055155/evidence/tool-075-formal-129-green.txt`。
- 五级裁决 `TOOL-075=G1/F2/A5/C4/G2` 已由 `judge.py` 落账，中央账本从 410 增至 **415 judgments**。`gap-too-fast` 与 `discovery-collapse` 已用两次红证据和一次绿证据写复审说明并 ack，最终 `alarms.py check` 为 clean。第八批推进至 **25 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-076 get_trigger`。

## 2026-08-03 05:39 · 第八批 TOOL-074 decide_approval 正式通过

- 首轮真实路径在 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-052105` 冻结为红：真实 `decide_approval` 已返回成功，SQLite 和 entities durable `run_terminal` 均已显示 completed，但审批顶带仍停在 `Awaiting approval`，继续显示 `Approve/Reject`。红证据 `evidence/tool-074-formal-128-red-stale-approval-rail.txt` 保留，未计入绿账本。
- stop-and-fix：`frontend/lib/core/notice/notice_center.dart` 增加按 flowrun/node 收回可见和排队审批副本；`frontend/lib/features/notifications/state/notice_dispatcher.dart` 监听 durable entities `run_terminal`；`frontend/lib/app/app_shell.dart` 在本地审批决策期间保留 Approved/Rejected verdict，避免 terminal race 抹掉用户反馈。补充 NoticeCenter、dispatcher 回归测试，Flutter analyze 与定向测试全绿，并同步 notifications 领域文档。
- formal-128 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-053215` 使用新二进制、真实 Flutter App、真实受管网关、Computer Use、连续录屏、backend/frontend journal、三路 SSE witness 和 LLM tap 重跑。真实 run `fr_9ecfcdf874048091` 走通 `trigger → approval → publish`；模型业务工具序列为一次 `list_approval_inbox`、一次 lazy `search_tools`、一次精确 `decide_approval`，批准理由为 `fixed rail approved`，下游 marker 为 `TOOL074_APPROVED`。终帧显示 `Approved … · completed`，顶带和审批按钮均消失，无重复 mutation/retry/stale actionable copy。
- 五通道：screen.mov `171.458333s`；SSE messages durable `1..30`、entities `1..2`、notifications `1..3` 连续，entities 末帧为该 run 的 `run_terminal/completed`；LLM 五个请求/响应全 HTTP 200；backend 无 panic/FATAL/ERROR，frontend 无 `Unhandled exception`、`FlutterError`、`Lost connection` 或 AXTree 红线；SQLite start/hold/publish 全 completed、hold decision=`yes`、parked=0。证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-053215/evidence/tool-074-formal-128-green.txt`。
- 五级 `G1/F2/A5/C4/G2` 已由 `judge.py` 落账，中央账本从 405 增至 **410 judgments**。gap-too-fast、pass-burst、discovery-collapse 已逐条带真实 session 复审说明 ack，最终 `alarms.py check` clean。第八批推进至 **20 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线 `TOOL-075 search_triggers`。

## 2026-08-03 05:17 · 第八批 TOOL-073 list_approval_inbox 正式通过

- 真实夹具为 `trigger → approval`：run 头保持 `running`，approval 节点 `hold` 保持 `parked`；REST 收件箱先对证一行渲染提示和 deadline，证明收件箱查的是 parked 节点而不是 run 头状态。
- formal-127 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-051054` 通过真实 Flutter App、真实受管网关、Computer Use、连续录屏、backend/frontend journal、三路 SSE witness 和 LLM tap 完成。正向提示只允许一次 `list_approval_inbox`，wire 返回完整 `flowrunId/nodeId/ref/parkedAt`；工具卡展开后显示 `Approval / Summary / Waiting / run` 四列，`Checked · 1 awaiting`，没有把机器字段丢掉。解决审批后再次只调用一次工具，空路径返回 `count:0, parked:[]`，App 显示 `Checked · None awaiting`，助手没有编造行。
- 观察到助手正文用 `Current run` 而非复述 opaque flowrun id；这是仓内 redaction 规则要求，精确值保留在相邻工具卡、tool result 和 LLM wire，不构成数据或产品缺陷，因此没有源码修复。
- 五通道：screen.mov `256.773333s`；rig-check 五通道全绿；SSE messages durable `1..28` 连续，含 `approval_pending` 与 cleanup `run_terminal`；LLM 两次真实工具调用各一次，网关响应全 200；backend 无 panic/FATAL/ERROR，frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线；SQLite 收尾 run `completed`、parked=0、无重复 run。证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-051054/evidence/tool-073-formal-127-green.txt`。
- 五级 `G1/F2/A5/C4/G2` 已写入 COVERAGE，中央账本从 400 增至 **405 judgments**。本次集中落账触发三条统计警报，已用完整 session 和正负路径逐条复审并 ack，最终 `alarms.py check` clean。第八批由 **10 / 50** 推进至 **15 / 50**；未到 50 格不跑统一长门禁、不提交，下一前线 `TOOL-074 decide_approval`。

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

## 2026-08-03 04:46 · 第八批 TOOL-071 search_flowruns 正式收口

- formal-042059 的真实运行先冻结为红：中文前缀后的 redactor 使用 byte offset 切 rune，后端出现 `slice bounds` panic。修复为 byte-to-rune 边界转换并补 Unicode regression；formal-043147 又发现状态列表把多条运行写成 `the requested item`，formal-043651 进一步发现 durable close 前的 `seq=0` delta 仍会逐帧泄漏半截占位符。两轮均保留为红证据，不计绿。
- stop-and-fix 收紧 `search_flowruns` 的工具描述与 closed schema，结果行投影 `workflowName`，明确默认不自动调用 `get_flowrun`；状态占位符清理改为换行前整行缓冲，前端相邻工具卡展示 workflowName。`go test ./internal/app/loop ./internal/app/tool/workflow` 全绿，`docs/references/backend/domains/{chat,workflow}.md` 同步。
- formal-147 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-043918` 使用修复后二进制、真实 Flutter App、真实受管网关、Computer Use、连续录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap 重跑。用户请求只调用一次 `search_flowruns`，没有 `get_flowrun`、retry 或第二次 mutation；真实 fixture REST 为 3 completed、1 failed（`TOOL071_FAILURE_MARKER`）、1 running/approval parked。最终画面显示 `completed=3 / failed=1 / running=1`、合计 5 和 `Searched runs · 5`，无错误卡、详情卡、布局溢出或占位符。
- 录屏封口 `234.511667s / 2784x1808`，证据为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-043918/evidence/tool-071-formal-acceptance.md`。五通道交叉核对：messages durable `1..14`、notifications `1..2` 连续，三流均连接，SSE 全量无 `the requested item`/`the referenced item`，raw tool result 保留完整机器值；backend/frontend 无未解释红线；LLM wire 只有一次真实 `search_flowruns`，网关响应全 200。rig-down 已封口，进程清零。
- 锚点 10/10 仍在有效窗口内，`judge.py` 五格 `G1/F2/A5/C4/G2` 落账，中央账本由 `390` 增至 **395 judgments**。`gap-too-fast` 与 `discovery-collapse` 已按正式录屏、三轮前置红证据和五通道复审 ack，`alarms.py check` clean。第八批当前 **5 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线为 `TOOL-072 replay_flowrun`。
2026-08-03 05:02 · 第八批 TOOL-072 replay_flowrun 正式收口

- 前置真实 App session `20260803-044843` 发现产品红线：completed run 的真实拒绝结果落成 `status=error`，但 replay 工具卡仍显示成功动词 `Replayed run`，且错误由族体和底盘重复显示；该 session 不判绿。
- stop-and-fix：为 `replay_flowrun` 增加 `failedVerb`（`Replay not run` / `未执行重放`），设置 `ownsError=true` 避免重复错误，补双语 i18n、生成物、widget regression 和 `docs/references/frontend/features/chat.md`。`make gen` 与 `tool_card_flowrun_test.dart` 15/15 全绿。
- 修复后正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-045854` 真实 App 重跑 completed-run 拒绝路径；Computer Use 终帧为 `Replay not run fr_72aedca13… · failed`，错误只出现一次。LLM wire 一次 `replay_flowrun`，SSE messages `1..14` 连续且 tool_result `status=error`，backend 无未解释异常，frontend 无 Flutter/Dart/RenderFlex/Unhandled 红线；录屏 `152.226667s`。
- SQLite 对证：run `fr_72aedca131ce4031` 为 `completed/replay_count=1`，四节点 completed；flaky handler `failed=1, ok=1`，stable/finish function 各执行一次，已完成节点没有重跑。正向真实成功路径沿用 session `20260803-044843`，显示 `Replayed run … · Completed · 4 nodes`，marker `TOOL072_REPLAY_DONE`。
- 台架卫生：专用 workspace `ws_f68e2c882a19940f` 通过真实 workspace DELETE=204 清除；`ws_23d0c85d912ce656` 的 workflow/functions/handler/conversation 均 DELETE=204、GET=404，四类 live 列表为空，SQLite 主行保留 `deleted_at` 审计，最后保留一个空 workspace。
- 五级 `G1/F2/A5/C4/G2` 已落账，中央账本由 395 增至 **400 judgments**；`gap-too-fast`、`pass-burst`、`discovery-collapse` 均写复审结论后 ack，`alarms.py check` clean。第八批推进至 **10 / 50**，未到 50 格不跑统一长门禁、不提交；下一前线 `TOOL-073 list_approval_inbox`。证据：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260803-045854/evidence/tool-072-postfix-acceptance.md`。

## 2026-08-04 20:08 · 第十二批 TOOL-111 get_subagent_trace 正式收口，5/50

- 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-195749` 使用修复后二进制、真实 Flutter App、真实受管 gateway、Computer Use、三路独立 SSE witness、LLM tap、backend/frontend journal 和窗口录屏；`rig-down.sh` 已封口，录屏 `377.088333s / 2784x1808 / 60fps`。
- 负向路径真实覆盖无运行记录与未知 `subagentRunId`，均得到可解释的普通工具结果；正向只派发一次 `Subagent(Explore)`，子运行 `subagt_ef30ee8ffc46567e` 完成并持久化 5 个 block，随后无参列表和精确 ID 详情均真实回放。UI 展示运行状态、5 步轨迹、失败的 `Read` 结果与最终文本；稳定产品帧为 `frames/f000720.png`、`f000730.png`、`f000740.png`、`f000748.png`，收台后的黑帧明确排除。
- 五通道核对：SQLite 正向 subagent message 与 5 个 block 和 UI 对齐；messages durable seq `1..80`、notifications `1..5` 连续，seq=0 delta 未推进游标；LLM challenge/install/models/chat 全 200，wire 含 `Subagent`、无参 `get_subagent_trace` 和精确 ID 详情；backend 无 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Unhandled/AXTree 红线。唯一已知观察器启动噪声 `Failed to foreground app; open returned 1` 已单独披露，不计产品异常。
- 正式证据为 `evidence/TOOL-111.md`，警报复审为 `evidence/TOOL-111-ledger-alarm-reaudit.md`。锚点 `10/10`，`judge.py` 五格 `G1/F2/A5/C4/G2` 已写入，COVERAGE `TOOL-111=✓✓✓✓✓`；写入期间的 `gap-too-fast` 与 `discovery-collapse` 均以五通道、红/绿路径和复审说明串行 ack，最终 `alarms.py check` 为 `clean (590 judgments)`。批次十二推进至 **5 / 50**，不跑统一长门禁、不提交；下一前线为 `TOOL-112 search_conversations`。

## 2026-08-04 23:36 · 第十二批 TOOL-115 search_blocks 正式收口，25/50

- 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-232754` 使用新 binary、真实 macOS App、真实受管 gateway、Computer Use、217.091667s 录屏、backend/frontend journal、三路独立 SSE witness 和 LLM tap。全量 kind 检索一次返回 9 条 block，handler 筛选一次返回 3 条；无匹配一次给出下一步建议；空 query 一次给出 `search query is required`，没有 retry 或 mutation。
- 首轮红证据保留了三类真实产品问题：助手摘要泄漏 opaque ref、跨 SSE chunk 短暂露出占位符、hosted model 将 `kinds`/`limit` 字符串化导致后端拒绝。stop-and-fix 增加 search_blocks 专用摘要归一化、换行前缓冲、严格字符串化参数兼容，并强化同一调用必须携带用户过滤条件。修复后二次正式 session 的工具卡保留精确 ref，助手表格不泄露机器标识，9 条结果、分类汇总和无匹配/校验失败均清晰可读。
- 五通道：SQLite 与 tool result/UI 对齐；messages durable `1..42`、notifications `1..6` 单调，三路 SSE 已连接；`backend.log` 无 panic/ERROR/FATAL，唯一 WARN 是预期空 query 校验；frontend 无 Flutter/Dart/RenderFlex/Unhandled/Exception 红线，仅有已知启动器 `open returned 1`；LLM responses 全 200。录屏终帧为 `evidence/TOOL-115-final.jpg`，正式证据为 `evidence/TOOL-115.md`。
- 锚点 `10/10`，`judge.py` 五级 `G1/F2/A5/C4/G2` 已落账，中央账本由 605 增至 **610 judgments**，COVERAGE `TOOL-115=✓✓✓✓✓`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已用正式录屏、首轮红证据、修复后二次绿 session 和五通道证据复审并 ack，阈值未变，最终 `alarms.py check` 为 `clean (610 judgments)`。批次十二推进至 **25 / 50**，下一前线为 `TOOL-116 get_relations`；未到 50 格不跑统一长门禁、不提交。

## 2026-08-04 18:51 · 第十一批 TOOL-109 run_skill_script 正式收口

- 首次 formal `20260804-181950` 冻结为红：托管模型把 `args`/`timeoutSec` 发成字符串，后端正确拒绝并留下可见失败卡，模型随后重复调用；兼容层只接受精确 JSON 数组/十进制整数字符串，保留其它畸形形状拒绝。formal `20260804-183735` 再冻结为红：lazy 目录摘要只给出 `name, script`，模型先漏掉可选参数而按默认值执行，随后补调用。
- 修复后正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-184737` 继续暴露一轮真实产品问题：目录虽已显示 optional keys，但缺少 `name=skill slug` 与 `script=relative path` 语义映射，模型首轮漏掉 `name`，产生失败卡。stop-and-fix 将语义映射放入首行摘要并加回归测试；新 binary 重跑后正向只出现一次成功 `run_skill_script`，参数 `args=["alpha","beta"]`、`stdin=hello-109`、`timeoutSec=30` 贯穿 wire、SSE、沙箱 stdout 和 UI，最终回答严格为 `OK`。
- 同一正式 session 的两个负向路径：`scripts/ghost.py` 只失败一次并显示 `script not found in the skill directory`；`scripts/host.sh` 只失败一次并显示无 sandbox runtime、指向 bash；两者均无 retry、无副作用。`backend.log` 两条 WARN 都是预期业务失败，`frontend.log` 无 Flutter/AX/Unhandled/断连红线。
- `rig-check` 收台前五通道全绿；录屏封口、三路 SSE 均连接，三条 messages 对话各只有一个 `run_skill_script` tool call，LLM chat wire 全 200，backend/frontend/UI 与沙箱结果一致。正式证据为 `.../sessions/20260804-184737/evidence/TOOL-109.md`，警报复审为 `.../sessions/20260804-184737/evidence/tool-109-ledger-alarm-reaudit.md`。
- 锚点 10/10 校准通过，`judge.py` 五级 `G1/F2/A5/C4/G2` 已落账，中央账本由 575 增至 **580 judgments**。写入期间 `gap-too-fast` 与 `discovery-collapse` 各触发两次；两轮都用红证据、正式绿 session、五通道 journal 和锚点结果复审后 ack，最终 `alarms.py check` clean。第十一批推进至 **45 / 50**，下一前线 `TOOL-110 Subagent`；未到 50 格不跑统一长门禁、不提交。
## 2026-08-06 · TOOL-123 API Serve 根因修复，待部署实机复验

- 旧生产红证据保持有效：`animation-source-scaled.png` 对 `animation-first-frame.png` 的 `changedFrac=0.99601`，COVERAGE 仍为 `TOOL-123=·····`，中央账本仍为 645。
- 邻仓 `/Users/sunweilin/Developer/Anselm-API-Serve` 已将 T2V/I2V 拆为独立模型、应用端口、上游 wire 与冻结卡。I2V 钉死 `wan2.7-i2v-2026-04-25`、`input.media[type=first_frame]`、显式 720P，并由 `/models` 发布 `image_to_video=true`。
- API Serve 完整 `make verify` 通过：vet、build、全仓 race、integration e2e、golangci-lint、docs lint 全绿。该事实只证明源码可部署，不证明生产已生效或产品目的已达成。
- 下一步：部署后先用 `check_i2v_contract.py` 检查真实 `/models`；通过后重跑真实 App + 真实网关 + Computer Use + 五通道，重新测 exact first frame，再决定五级裁决。批次十三保持 10/50，不提前跑统一长门禁、不提交。
## 2026-08-07 17:16 · EP-047 GET /api/v1/workflows/{id} 五级收口，批次十八 5/50

- 产品目的：用户从 Entities 打开 Workflow 详情后，能理解 active version、生命周期、运行治理和完整 graph，并能在 fit/zoom、metadata、governance、alerts 之间连续检查；未知 ID 不显示空壳；节点/边计数必须是完整、舒服的本地化文案。
- 首轮真实红 session `/private/tmp/anselm-rig-ep047-workflow-detail-20260807/sessions/20260807-164931` 抓到 `Edge 4` 计数文案缺陷；第一次修复 session `/private/tmp/anselm-rig-ep047-workflow-detail-fix-20260807/sessions/20260807-170010` 又抓到 `Nodes: 5 nodes · 4 edges` 重复语义。两轮红帧均保留，不计绿。
- stop-and-fix 将计数行改成 i18n `Graph: 5 nodes · 4 edges` / `图：节点 5 · 边 4`，补 en/zh widget regression、generated strings 和实体文档；目标测试 `workflow_overview_test.dart` 10 项全绿。
- 最终 session `/private/tmp/anselm-rig-ep047-workflow-detail-fix2-20260807/sessions/20260807-170525` 由同一 conductor 托管真实 App、Computer Use、录屏、frontend console、backend、三路 SSE witness、LLM tap 与受管网关。真实 UI 画面显示 v1/inactive/serial、5 nodes/4 edges、`No alerts`，无空图、stale row、裁切、治理溢出、retry 或 error red surface；录屏 `425.373333s / 113537352 bytes`，rig-down 后进程归零。
- REST detail=200、未知 ID=`404 WORKFLOW_NOT_FOUND`、list/detail activeVersion 一致；SQLite 证明同一 workflow/v1/5 节点/4 边及 trigger/control/function 三条关系。backend 无应用 WARN/ERROR/panic/FATAL；SSE 三流连接且 durable signals 与构造动作一致；frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow 红线，仅记录两行已解释的 Flutter/macOS runner/IMK 环境消息；LLM challenge/install/models 全 200，本只读路径不虚构 completion。
- 正式证据为 `/private/tmp/anselm-rig-ep047-workflow-detail-fix2-20260807/sessions/20260807-170525/evidence/EP-047-workflow-detail-final-green.md`，账本复审为同目录 `EP-047-ledger-alarm-reaudit.md`。anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，正式账本 **895→900 judgments**，COVERAGE `EP-047=✓✓✓✓✓`；`gap-too-fast` 与 `discovery-collapse` 按独立复审 ack，阈值与算法未改，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 179 carried / 0 tombstones`。
- 批次十八当前 **5/50**；未满 50 格不跑统一长门禁、不提交。下一原子前线为 `EP-048 PATCH /api/v1/workflows/{id}`。

## 2026-08-08 04:52 · EP-070 POST /api/v1/flowruns/{id}/approvals/{node}:decide 正式收口，批次二十 20/50

- 产品目的：用户从 Scheduler Overview 或顶部 approval capsule 理解真实生产审批，能够展开理由、批准/拒绝，并看到 inbox、运行计数、下游节点和 run history 收敛；非法 decision、未知字段、重复决策和并发 first-wins 都必须诚实，拒绝不得执行 publish。
- 正式 session `/private/tmp/anselm-rig-ep070-approval-decision-20260808/sessions/20260808-043003` 使用同一 conductor 托管真实 Flutter App、Computer Use、连续录屏、frontend console、backend journal、三路独立 SSE witness、LLM tap 和真实 managed gateway；录屏 `788.638333s / 2784x1808 / 60fps`。运行中 `rig-check` 通过，`rig-down` 后 owned process/listener 归零。
- 修正版真实 webhook fixture 的 capability-check 为 `structurallyValid=true, resolved=true`。旧 test-only `trg_manual` 的悬空图引用保留为 setup 红证据，不计绿；旧错误 function/approval/workflow 按用户授权软删除，修正版 fixture 未删除。
- 四条真实路径：`fr_9671dd6aab7b6337` 填 `QA approved for REL-240` 后 approve，SQLite/REST 记录 `decision=yes + reason` 且 publish=`EP070-APPROVED`；`fr_890f4d3a58f14c19` 覆盖 `maybe`=`422 FLOWRUN_INVALID_DECISION`、未知字段=`400 INVALID_REQUEST`、reject、无下游和重复决策=`422 FLOWRUN_APPROVAL_NOT_PARKED`；`fr_de436f8c6f8a6f5a` 并发 yes/no 只有一个 `202` 胜者且 publish 只执行一次；`fr_abd2b9be79aba3a4` 从顶部胶囊 approve 并在 run history 收敛。
- Computer Use 逐帧未发现裁切、RenderFlex overflow、输入跳变、死 spinner、旧 CTA、重复错误或不符合直觉的视觉行为；理由字段等高、文字可见、按钮未被挤出。
- 五通道：backend 无应用 WARN/ERROR/panic/FATAL；frontend 只有已知 macOS runner 的 `Failed to foreground app; open returned 1`，无 Flutter/Dart/overflow 红线；SSE 三流连接，entities durable seq 到 `20`、notifications 到 `37`，park/decision 为契约规定的 `seq=0`，run_started/approval_pending/run_terminal 和下游节点均可交叉核对；LLM challenge/install/models 全 `200`，deterministic graph 无 completion。
- 正式证据为 `.../sessions/20260808-043003/evidence/EP-070-approval-decision-real-session.md`，独立 ledger re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-070-approval-decision-ledger-reaudit.md`。anchors `10/10`；`judge.py` `G1/F2/A5/C4/G2` 落账，中央账本 `1035→1040 judgments`，COVERAGE `EP-070=✓✓✓✓✓`。批量写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按红/绿边界和五通道独立复审后 ack，阈值、算法、法典和锚点未改；`alarms.py check`=`clean (1040)`，`gen_coverage.py --check`=`848 rows / 202 carried / 0 tombstones`。
- Flutter targeted 34 项、backend scheduler/workflow approval/capability、testend approval contract/parked-decide-resume 均通过。批次二十推进至 **20/50**，未到 50 格不跑统一长门禁、不提交；下一前线为 EP-071 `POST /api/v1/triggers`。

## 2026-08-08 05:27 · EP-071 POST /api/v1/triggers 正式收口，批次二十 25/50

- 产品目的：用户从聊天只创建一个 webhook trigger，指定名称、路径和描述并得到可用 ID；真实
  `create_trigger` 只执行一次，卡片提供精确、可复制的 ID 和 webhook 地址，未创建 workflow 或
  执行其它动作。cron/webhook/fsnotify/sensor 四类创建，以及 invalid kind、invalid cron、duplicate
  name、invalid config、missing sensor target、invalid interval 负路径均已真实探测。
- 两次真实红场次完整保留：首轮后端/tool result 有真实 ID，但助手散文成为占位词且折叠卡无独立
  ID；第二轮展开卡已有 ID 芯片，但 Markdown `Trigger ID` 二列表格仍露出 `the requested item`。
  stop-and-fix 增加普通行、表格行和跨 provider 分帧 redaction 规则，并在 `create_trigger` 卡片
  增加 ID chip；Go redaction tests 与 frontend card regression 通过。
- 最终 session `/private/tmp/anselm-rig-ep071-create-trigger-fixed2-20260808/sessions/20260808-052016`
  使用真实 Flutter App、Computer Use、连续录屏、frontend/backend journals、三路独立 SSE witness、
  LLM tap 和真实受管 gateway；录屏 `109.513333s`，`rig-check`/`rig-down` 通过，真实实体
  `trg_b265489d0a7681b3`。正文、tool result、SSE durable close、REST 和 UI 一致，展开卡显示
  `ID trg_b265489d0a7681b3` 可复制，正文明确指向相邻卡片且无 placeholder。
- 五通道：backend 无应用 WARN/ERROR/panic/FATAL；frontend/Terminal 只有已知 runner 启动提示，
  无 Flutter/Dart/overflow/exception；三路 SSE 均连接，LLM challenge/install/models 和三次 chat
  completion 全 `200`，health=`ok`。逐帧无状态跳变、截断、死 spinner、重复错误或不可发现 CTA。
- 正式证据为 `.../sessions/20260808-052016/evidence/EP-071-create-trigger-green.md`，账本复审为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-071-create-trigger-ledger-reaudit.md`。
  anchors `10/10`；`judge.py` 五格 `G1/F2/A5/C4/G2` 使账本 `1040→1045 judgments`，COVERAGE
  `EP-071=✓✓✓✓✓`。`gap-too-fast` 与 `discovery-collapse` 按红/绿证据和独立复审串行 ack，阈值/算法
  未改，`alarms.py check`=`clean (1045)`，`gen_coverage.py --check`=`848 rows / 203 carried / 0 tombstones`。
- 定向 trigger-card 测试 `7/7`，完整 Flutter suite `All tests passed!`，Dart format 与 `git diff --check`
  通过；旧 malformed fixture 按授权删除/软删除，修正版实体及全部红/绿证据保留。批次二十推进至
  **25/50**，未到 50 格不跑统一长门禁、不提交；下一前线为 EP-072 `GET /api/v1/triggers`。

## 2026-08-08 06:20 · EP-072 GET /api/v1/triggers 正式收口，批次二十 30/50

- 产品目的：实体海洋可展示全部 trigger，用户可沿 cursor 分页浏览并按名称子串搜索，且能从同一列表
  直观看懂 paused、refCount、listening、lastFiredAt 与 nextFireAt；本次真实 fixture 为 24 条、四种
  source kind，并覆盖已监听、已暂停、已触发、无 listener、分页、大小写不敏感命中和 no-match。
- 红 session `/private/tmp/anselm-rig-ep072-list-triggers-20260808/sessions/20260808-053235` 发现
  `?search=ep072-webhook-1` 与 `?search=does-not-exist` 均返回未过滤的 20/24 页面，前端已加载页内
  flatten 掩盖了跨页缺陷。前线冻结后修复 domain `ListFilter.Search`、handler query 透传和 store
  page/count 共用 `WhereLike`；新增 case-insensitive、过滤计数、空白与字面 `%` 的回归测试，并同步
  `docs/references/backend/api.md`。
- 绿 session `/private/tmp/anselm-rig-ep072-list-triggers-green2-20260808/sessions/20260808-054945`
  由同一 conductor 托管真实 Flutter App、Computer Use、连续录屏、frontend/backend journal、三路
  独立 SSE witness、LLM tap 和 managed gateway；`rig-check`/`rig-down` 均通过。REST 证明 page1=`24/20`
  且 `hasMore=true`、cursor page2=`4/4` 且 `hasMore=false`、命中=`1/1`、no-match=`0/0`；UI 逐帧确认
  24 行、sensor listening、paused cron、webhook last-fired 详情、精确搜索单行和清晰空态，无重复行、
  截断、死 spinner、输入跳变或隐藏 CTA。错误 sensor fixture 已在绿场次前修正，不计入绿证据。
- backend 无应用 WARN/ERROR/panic/FATAL；frontend/Terminal 只有已知 runner 启动提示
  `Failed to foreground app; open returned 1`，无 Flutter/Dart/RenderFlex/overflow/exception；三路 SSE
  均连接且 durable 序列连续，LLM tap 仅有该只读 endpoint 所需 bootstrap、没有伪造 completion，health=`ok`。
- 正式绿证据为 `/private/tmp/anselm-rig-ep072-list-triggers-green2-20260808/sessions/20260808-054945/evidence/EP-072-list-triggers-green.md`，
  红证据为 `/private/tmp/anselm-rig-ep072-list-triggers-20260808/sessions/20260808-053235/evidence/EP-072-list-triggers-red-search.md`，
  独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-072-list-triggers-ledger-reaudit.md`。
- anchors `10/10`；`judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，中央账本 `1045→1050 judgments`，
  `COVERAGE EP-072=✓✓✓✓✓`。批量写账触发的 `gap-too-fast` 与 `discovery-collapse` 经红/绿证据和独立
  复审后 ack，阈值、算法、法典和锚点未改；`alarms.py check`=`clean (1050)`，
  `gen_coverage.py --check`=`848 rows / 204 carried / 0 tombstones`。定向 Go/Flutter/API 验证与
  `git diff --check` 通过。批次二十推进至 **30/50**，未到第 50 格不跑统一长门禁、不提交；下一前线为
  EP-073 `GET /api/v1/triggers/{id}`。

## 2026-08-08 06:24 · EP-073 GET /api/v1/triggers/{id} 正式收口，批次二十 35/50

- 产品目的：用户打开单个 trigger 详情时，`refCount`、`listening`、`paused`、`lastFiredAt` 和
  `nextFireAt` 必须是 listener 生命周期的真实投影；冷的、未被 workflow 引用的 cron 不得显示一个
  不会发生的未来时间；详情页保持打开时，侧栏 Pause/Resume 后必须即时更新，不要求用户重新选择。
- 首轮红 session `/private/tmp/anselm-rig-ep073-get-trigger-20260808/sessions/20260808-060226`
  发现 `trg_5b623696ccc9cb37` 在 `refCount=0, listening=false` 时仍返回并显示
  `nextFireAt=2026-08-09T00:00:00+08:00`。这是向用户作出的不可能承诺，红证据已保留且不计绿。
- stop-and-fix：backend 仅为未暂停且 `Listening=true` 的 cron 计算 `nextFireAt`；frontend 对 stale DTO
  fail-closed；detail provider 订阅 trigger scope 的 ephemeral `status` signal，信号只触发 REST 重读，
  不从 payload patch 运行字段。新增 backend cold/hot listener 回归和 frontend scoped-status re-fetch 回归，
  同步 backend API 与 frontend contract 文档。
- 最终绿 session `/private/tmp/anselm-rig-ep073-get-trigger-20260808/sessions/20260808-061331` 由同一
  conductor 托管真实 App、Computer Use、录屏、frontend/backend journal、三路独立 SSE witness、LLM tap
  和 managed gateway；录屏 `145.996667s`，`rig-check`/`rig-down` 通过。真实 UI 在同一详情页点击
  `Resume` 后变为 `Listening: Yes / Listeners: 1 / Next fire: 2026-08-09 00:00`，再点击 `Pause`
  即时回到 `Listening: No / Next fire: —`；热/冷稳定帧无裁切、布局跳变、残留时间戳或隐藏 CTA。
- REST、SSE 与日志交叉核对：最终 `GET` 为 `paused=true, refCount=1, listening=false, nextFireAt` 缺席；
  `sse.jsonl` 独立记录 `status {paused:false}` 与 `status {paused:true}`；backend 无应用 WARN/ERROR/
  panic/FATAL；frontend 仅有已知 `Failed to foreground app; open returned 1` runner 噪声，无 Dart/Flutter/
  RenderFlex/overflow/exception；LLM journal 只有 readiness，因为本项是 deterministic REST、无模型调用。
  正式绿证据为 `.../sessions/20260808-061331/evidence/EP-073-get-trigger-green.md`，红证据为
  `.../sessions/20260808-060226/evidence/EP-073-get-trigger-red.md`，独立复审为
  `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-073-get-trigger-ledger-reaudit.md`。
- anchors `10/10`；`judge.py` 以 `G1/F2/A5/C4/G2` 写入五格，中央账本 `1050→1055 judgments`，
  `COVERAGE EP-073=✓✓✓✓✓`。写账触发的 `gap-too-fast` 与 `discovery-collapse` 已经独立复审并 ack，
  阈值、算法、法典和锚点未改；最终 `alarms.py check`=`clean (1055)`，
  `gen_coverage.py --check`=`848 rows / 205 carried / 0 tombstones`。定向 Go/Flutter/API tests、Dart
  format、gofmt、diff check 通过。批次二十推进至 **35/50**，未到 50 格不跑统一长门禁、不提交；下一前线
  为 EP-074 `PATCH /api/v1/triggers/{id}`。
## 2026-08-08 07:44 · EP-076 POST /api/v1/triggers/{id}:fire 五级收口，批次二十 42/50

- 产品目的：用户在真实 Trigger 详情点击 Fire 后得到即时反馈；Dispatch 可以短暂显示 pending，但必须在同一页面自动收敛到真实 started/skipped/superseded/shed 处置；Activation、Firing、Flowrun、SSE 与 SQLite 可追溯；暂停时 Fire 在点击前诚实 inert，并指向 Resume。
- 首轮真实 session `/private/tmp/anselm-rig-ep076-fire-20260808/sessions/20260808-071716` 冻结三条红：暂停态显示 `Idle` 且 Fire 仍可点击；手动 fire 的 `{manual:true}` 与仍读取 `start.name` 的 fixture graph 不相容，`fr_9e3ae7722a140bef` 真实失败；Dispatch 首次读到 pending 后不再重读，run 已 terminal 但画面 stale。红录屏与 SSE/backend/frontend journal 永久保留，不计绿。
- stop-and-fix：trigger header 显示 `Paused`、Fire inert 并给 Resume 提示；disposable workflow 改为无参 `sync_inventory` action；`FiringListNotifier` 在当前页仍有 pending 时每 500ms 重读同一 REST 页、按 id 替换行，进入终态立即停止；新增 fixture upsert 与 pending→started widget regression，更新 entities 文档。没有放宽 backend `TRIGGER_PAUSED` 或 firing status 契约。
- 最终 session `/private/tmp/anselm-rig-ep076-fire-20260808/sessions/20260808-073336` 使用同一 conductor 托管真实 App、Computer Use、窗口录像、backend journal、三路独立 SSE witness、真实 managed gateway 与 LLM tap；`rig-check` 运行中通过，`rig-down` 录屏封口 `434.098333s`，owned processes/listeners 归零。关键帧为 `dispatch-after-fire.png`、`dispatch-settled.png`、`trigger-paused-final.png`、`trigger-resumed-final.png`。
- REST/SQLite/SSE/UI 对证：`:fire=202`、activation `tra_1d399eb2587378fc` (`fired=true`, `firingCount=1`, `payload={manual:true}`)，firing `trf_789d0baf6b1f616` (`started`, flowrun `fr_957497ee81dcfba7`)，flowrun=`completed`；capability-check=`200` 且 `structurallyValid=true,resolved=true`。SSE 三流连接，entities durable seq `1..10` 单调；主 fire 为 ephemeral，随后同一 run 的 `run_started(seq=3)` 与 `run_terminal(completed,seq=4)` 均被 witness 记录；deterministic graph 的 LLM tap 只有 ready。
- 暂停负向同一 session 真实得到 `paused=true/listening=false`、App `Paused` + inert Fire，`:fire=422 TRIGGER_PAUSED` 且无新增实体；正确 `${endpoint}:resume` 后回到 `paused=false/listening=true`。不带花括号的 zsh endpoint 拼接 404 单独归类为仪器错误。backend/frontend/SSE/LLM journal=`524/18/32/1`，无未解释应用级 WARN/ERROR/panic/FATAL 或 Flutter/Dart/RenderFlex/Unhandled 红线；唯一平台噪声为已知 runner foreground 提示。
- 正式红/绿/复审证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-076-trigger-fire-{red,green,ledger-reaudit}.md`。anchors `10/10`；`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1065→1070 judgments`，`COVERAGE EP-076=✓✓✓✓✓`。写账打开 `gap-too-fast` 与 `discovery-collapse`，独立复审后 ack，阈值/算法/法典/锚点未改；最终 `alarms.py check`=`clean (1070)`，`gen_coverage.py --check`=`848 rows / 208 carried / 0 tombstones`。
- 定向 Dart analyze、12 项 trigger widget tests、trigger/handler/store Go tests、`git diff --check` 通过。批次二十由 **41/50→42/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-077 `POST /api/v1/triggers/{id}:pause`。
