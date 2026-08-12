---
id: WRK-093
type: working
status: active
owner: "@weilin"
created: 2026-08-01
reviewed: 2026-08-09
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

## 当前前线（2026-08-12，EP-213 已完成，批次三十三 50/50；统一长门禁已通过）

EP-213 `DELETE /api/v1/api-keys/{id}` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。用户对精确对象
`EP-213 UI Delete Positive` 授权后，最终点击前重新读取确认框，确认永久删除文案、对象名和 `Cancel/Delete` 按钮没有漂移；
真实 Delete 后 UI 稳定只剩受管 `Anselm Free`。`daily-rule` 是历史 EP-192 Memory fixture，未被借用。

正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-154423` 的真实 backend 记录目标 DELETE=`204`，
立即 list 只剩 managed，重复 DELETE=`404 API_KEY_NOT_FOUND`；SQLite unscoped tombstone 保留审计身份，secret、掩码、连接配置
和 probe 材料全部清空。证据为 session 内 `EP-213-apikey-delete-final-green.md`、`EP-213-visual-measurement.md` 和
`EP-213-delete-final-settled.jpeg`。

五通道已封口：`rig-check`/`rig-down` 通过且进程/监听器收台；录屏可读；backend 无应用 panic/FATAL/WARN/ERROR；frontend
无 Flutter/Dart/RenderFlex/overflow/Unhandled 红线，仅已知 IMK host 噪声；三路 SSE 均连接，API-key 设置按 REST reread 契约
不虚构 lifecycle durable frame；llmtap 仅证明真实 managed bootstrap，不虚构 completion。因录屏没有可信 click-frame 对齐，
L3 保守使用 `A4`，不冒充 `A1`。

正式五级裁决为 `G1 / F1 / A4 / C4 / G2`，formal ledger `1760→1765 judgments`，anchors=`10/10`，
`gen_coverage.py --check`=`848/346/0`，`alarms.py check`=`clean (1765)`；`gap-too-fast` 与 `discovery-collapse`
均由独立复审记录 ack，未改阈值、算法、法典、锚点或 gate。

本次收账又发现台架自身的并发丢写：五条裁决进入 journal，但清册曾丢掉 EP-213 L1。已 stop-and-fix `judge.py`，以
`RIG_HOME/judge.lock` 串行保护去重、清册更新和 journal 追加，并让已有 journal 的重试能修复半步写入；并发与幂等回归
`python3 -m unittest testend/rig/test_judge.py -v` 全绿，EP-213 清册已由脚本 replay 恢复为 `✓✓✓✓✓`。该台架红线已记录在
`LOG.md`，不能再把 journal 条数单独当作清册完成证明。

批次三十三已由 `45→50/50`。统一长门禁已通过：`make verify`、完整 `make -C backend testend`（`292.983s`）、账本/清册/锚点/警报和本批 Go 定向回归均为绿。工作树审计已确认搜索线改动与本批边界分离；本批已提交 `4d304b3c`，前线推进到 EP-215。

EP-212 `PATCH /api/v1/api-keys/{id}` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。
产品目的不是只得到一个 `200`，而是让用户安全维护 BYOK：改名、改/清空可选 Base URL、轮换 secret，
secret 留空时保留旧值，探测失败不回滚修改，受管 Anselm 行保持锁定，workspace 和加密存储不串线。

首轮真实 App 红场 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-131319` 暴露了真实
产品缺陷：编辑表单把空 Base URL 映射成省略字段，后端因此保留旧 URL；该场冻结、不计绿。stop-and-fix
让编辑路径显式发送 `baseUrl: ''`，保留新增路径的 null 省略语义，并补 Flutter S-3 回归；19 个 settings
测试及相关 Go/testend/Flutter 定向测试通过。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-132645` 的录屏为
`145.063333s / 2788x1812 / 60fps`，由同一 conductor 托管 App、Computer Use、backend/frontend
journals、三路独立 SSE witness、llmtap 和真实 `https://api.anselm.website`；`rig-check`/`rig-down`
通过且 owned processes/listeners 归零。真实 UI 显示 populated URL，清空且未触碰 secret 后保存，回到
列表显示空 URL、managed lock 和绿色 probe 状态；没有 stale URL、重复行、死 spinner、错误面或布局跳变。

五通道闭合：backend 记录 PATCH→list→`:test`→list，坏 OpenAI endpoint 的 probe failure 仍返回 `200`
但 durable `testStatus=error`；显式 `baseUrl:""` 落 SQLite `base_url=''`，empty PATCH 不刷新 `updatedAt`，
managed/cross-workspace/whitespace/unknown-field 负向矩阵分别得到 `API_KEY_IMMUTABLE`、
`API_KEY_NOT_FOUND`、`API_KEY_VALUE_REQUIRED`、`INVALID_REQUEST`，加密列无 plaintext leak。SSE 三流为
两个 workspace 全部连接且无 gap；当前没有 API-key 生命周期帧，设置页按 REST reread 收敛；frontend 无
Dart/Flutter/RenderFlex/Unhandled 红线，仅已知 IMK host 噪声；LLM tap 观察到真实 managed proof/quota
`200`，本 endpoint slice 没有 completion，未虚构。

正式按 `G1 / F1 / A4 / C4 / G2` 写入 `COVERAGE EP-212=✓✓✓✓✓`；证据、红场和独立账本复审分别为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-132645/evidence/EP-212-apikey-patch-green.md`、
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-131319/evidence/EP-212-apikey-patch-red-baseurl-clear.md`、
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-212-apikey-patch-ledger-reaudit.md`。正式 ledger
`1750→1755 judgments`，anchors `10/10`，`gen_coverage.py --check`=`848/344/0`，`alarms.py check`=
`clean (1755)`；写账触发的 `gap-too-fast` 与 `discovery-collapse` 已按原阈值独立复审并 ack，未改阈值、
算法、法典、锚点或 gate。本批由 `35→40/50`，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-213
`DELETE /api/v1/api-keys/{id}`。

EP-211 `GET /api/v1/api-keys` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。
产品目的不是只读到一个 JSON，而是让用户在 `Settings → Models & keys` 看到当前 workspace 的
完整 key 清单：managed/BYOK 分离、值脱敏、状态可读，切换 workspace 后不残留上一 workspace
的凭证。真实 App 在 Alpha 看到 managed 与 mock 两行，切到 Beta 只看到 managed，再切回 Alpha
mock 行恢复；列表没有重复行、死 spinner 或错误面。

正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-130114` 的录屏为
`267.125000s / 2784x1808`，窗口级录制由同一 conductor 托管；`rig-check` 通过，`rig-down` 后
owned processes/listeners 全部归零。backend 的激活/列表、分页、过滤、空结果、坏 cursor、非法
limit 和缺失 workspace 矩阵均完成，应用级 WARN/ERROR/panic/FATAL 为零；frontend 无 Dart/Flutter/
RenderFlex/Unhandled/runtime 红线；Alpha/Beta 各自接通 messages/entities/notifications 六条 SSE
连接；managed gateway proof/quota 为真实 `200`。API key 列表是 REST 重读契约，当前事件登记没有
api-key 生命周期帧，未把“无帧”误判为丢事件。SQLite 对证了 Alpha managed+mock、Beta managed
以及加密存储和 masked projection。

本格没有把稀疏抽帧冒充 A1 首帧测量：后端激活/列表耗时为 `0–1ms`，录像只用于确认稳定视觉态和
workspace 交替结果；因此五级裁决为 `measure:apikey-list-purpose / F1 / A4 / C4 / G1`。正式证据
为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-130114/evidence/EP-211-apikey-list-green.md`，
独立警报复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-211-apikey-list-ledger-reaudit.md`。

正式 ledger `1745→1750 judgments`，anchors `10/10`，`COVERAGE EP-211=✓✓✓✓✓`，
`gen_coverage.py --check`=`848/343/0`，`alarms.py check`=`clean (1750)`；五级写账触发的
`gap-too-fast`、`pass-burst` 与 `discovery-collapse` 已按独立复审逐条 ack，未改阈值、算法、法典、
锚点或 gate。本批由 `30→35/50`，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-212
`PATCH /api/v1/api-keys/{id}`。

EP-210 `POST /api/v1/api-keys` 已完成真实 App、真实受管 gateway、Computer Use 和五通道验收。
产品目的不是只创建一行 key，而是让新用户从 `Settings → Models & keys → Add key` 找到 provider、提交
凭证、看到真实探测结果，并确认 managed 与 BYOK 分开、展示脱敏且 workspace 不串线。真实 App 搜索
`mock` 后只留下 `Mock (dev)`，保存并自动 probe 后列表出现 managed 与 mock 两行绿状态；非法 provider、
空 key 均得到明确 400 且不增加数据库行，Beta 列表没有 Alpha 的 mock key。

正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-124305` 的录屏为
`376.210000s / 2784x1808`，窗口级录制由同一 conductor 托管；`rig-check` 通过，`rig-down` 后
owned processes/listeners 全部归零。backend 无应用 WARN/ERROR/panic/FATAL，frontend 只有已知
IMK/launcher 噪声；Alpha/Beta 各自接通 messages/entities/notifications 六条 SSE 连接；managed
gateway challenge/install/models/quota 为 200。API key 生命周期没有 SSE 帧符合当前事件注册表，
设置页用 REST 重读收敛，未把“无帧”误判为丢事件。SQLite 证明 key 加密存储、masked projection 和
workspace 隔离。

本格没有把稀疏抽帧冒充 A1 首帧测量：backend `create 201 → probe 200 → final list 200` 的真实
关键路径为 `95ms`，测量注记明确说明录像检查了无死 spinner/重复行/错误面但没有精确 click frame；
因此五级裁决为 `measure:apikey-create-purpose / F1 / A4 / C4 / G1`。正式证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-210-apikey-create-green.md`，测量为
`EP-210-apikey-create-measurement.md`，独立警报复审为 `EP-210-apikey-create-ledger-reaudit.md`。

正式 ledger `1740→1745 judgments`，anchors `10/10`，`COVERAGE EP-210=✓✓✓✓✓`，
`gen_coverage.py --check`=`848/342/0`，`alarms.py check`=`clean (1745)`；写账触发的
`gap-too-fast` 与 `discovery-collapse` 已按独立复审串行 ack，未改阈值、算法、法典、锚点或 gate。
本批由 `25→30/50`，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-211 `GET /api/v1/api-keys`。

EP-209 `POST /api/v1/workspaces/{id}:activate` 已完成真实 App、真实受管 gateway、Computer Use
和五通道验收。产品目的不是只看到 `200`，而是确认 workspace subject、`lastUsedAt`、对话隔离、
切回恢复和真实聊天目的共同成立：创建 Alpha/Beta，Beta→Alpha→Beta→Alpha，Alpha 真实回复
`ALPHA-CONTEXT-209-FIXED`，Beta 页面没有 Alpha transcript，切回 Alpha 后历史恢复且无重复 user bubble。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-120306` 暴露
`_ReadAloudSlot` build-phase Riverpod `setState()/markNeedsBuild()` 红线，已冻结不计绿。修复将
workspace-bound media/read-aloud provider 首次 dirty refresh 移出 widget build，补 provider-settle、
workspace hot-switch/bootstrap、settings key invalidation 与 chat transcript 回归，并同步 chat
contract 文档。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260811-122342` 的录屏为
`391.225000s / 2784x1808 / 60fps`，`rig-check` 在创建、切换、真实聊天前后通过，`rig-down` 后
owned processes 全部归零。backend 无应用 WARN/ERROR/panic/FATAL；frontend 只有已知 IMK host 噪声；
两个 workspace 各接通 messages/entities/notifications，Alpha messages durable `1..8`、notifications
`1..2` 单调唯一，Beta 无 Alpha durable 帧；managed challenge/install/models 和两次 chat completion
全为 `200`。证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-209-workspace-activate-fixed-green.md`，
独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-209-workspace-activate-ledger-reaudit.md`。

正式 ledger `1735→1740 judgments`，anchors `10/10`，`COVERAGE EP-209=✓✓✓✓✓`，
`gen_coverage.py --check`=`848/341/0`，`alarms.py check`=`clean (1740)`；本批由 `20→25/50`，
未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-210。

### 历史状态快照（EP-127，批次二十五 50/50，统一长门禁已通过）

EP-127 `POST /api/v1/mcp-servers/{name}/tools/{tool}:invoke` 已完成真实 App 安装 stdio MCP、真实受管 gateway、Computer Use 和
五通道验收。REST 覆盖成功、MCP tool error、未知 tool、坏 JSON、错误 action、未知 server；连续三次失败真实翻到 `degraded`，
下一次成功恢复 `ready`，entities SSE 观察到状态信号，单 Call logs/stderr、SQLite 和 App Call history `5 ok / 8 failed` 一致。

stop-and-fix 先后修复两处真实红：ready 恢复后旧 `lastError` 不应继续作为红色活动错误；13 条调用历史不应撑爆固定详情 pane。
前者保留 API 历史诊断、前端只在 `failed/degraded` 显示错误条并补 test，后者改为 `SingleChildScrollView` 并补 20 行长列表 test。
最终 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-065857` 录屏 `119.625000s / 2784x1808 / 60fps`，顶部/尾部
截图、旧红观察、REST/SQLite、五通道 journal 均在 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-127-mcp-invoke-final.md` 指向的
证据中；临时 fixture/data 已按授权移入 Trash，正式 session 保留。

账本 `1325→1330 judgments`，`G1/F2/A5/C4/G2`，anchors `10/10`，`COVERAGE EP-127=✓✓✓✓✓`，两条统计警报按独立复审 ack 后
`alarms.py check` clean。批次二十五已 **50/50**；统一长门禁已通过：根目录 `make verify` 四组全绿，`make -C backend testend`
全量通过（307.330s），EP-127 定向回归、coverage/anchor/diff 守卫均通过。当前只剩选择性工作树审计和 commit，门禁已完成但仍不推进
EP-128。

### 历史状态快照（EP-125，批次二十五 40/50）

EP-125 `GET /api/v1/mcp-servers/{name}/stderr` 的 bounded-tail 验收已封存于
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-061239`，录屏 `375.708333s`、`data.size=262144`、unknown `404`，
账本 `1315→1320`；当前前线以 EP-126 整体重述为准。

### 历史状态快照（EP-119，批次二十五 10/50）

EP-119 `DELETE /api/v1/skills/{name}/files/{path...}` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道验收。
首轮真实 App 的外部先删竞态暴露产品红：App 收到 `404 SKILL_FILE_NOT_FOUND` 后只显示泛化 `Action failed`，保留幽灵行和
失效预览。stop-and-fix 让所有删除 API 失败都刷新文件树，stale 404 回到 skill 概览并显示已删除/已刷新文案，其他失败显示
带路径的重试文案；中英文、错误常量和 widget 回归同步完成。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-043659` 完成真实附属删除、嵌套删除、取消确认、
manifest 保护、重复删除和外部先删竞态。最终 REST 列表只有 `SKILL.md` 164 bytes 与 `scripts/run.py` 39 bytes；终帧
`evidence/EP-119-final.png` 显示 `2 files` 和 skill 概览，无幽灵行。录屏 `364.575000s` 已由 `rig-down` 封片，backend D1
`:8864` 无应用红线，SSE notifications durable `1..8` 单调，managed gateway challenge/install/models 全 200；frontend
无 Flutter/Dart/RenderFlex/Unhandled/overflow/lost-device 应用红线，AX 观察复核了完整竞态提示和最终文件树。

正式证据为
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-043659/evidence/EP-119-skill-file-delete-final-green.md`，独立警报复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-119-skill-file-delete-ledger-reaudit.md`。正式账本 `1285→1290 judgments`，
`G1/F2/A1/C4/G2`，anchors `10/10`，`COVERAGE EP-119=✓✓✓✓✓`，集中写账触发的两条警报已按原阈值复审并 ack，最终
`alarms.py check`=`clean (1290 judgments on record)`；临时数据按授权 `trash` 清理，清理记录留在 session evidence。

批次二十五由 **0→10/50**；未满 50 格不跑统一长门禁、不提交。下一原子前线为 EP-120
`GET /api/v1/mcp-servers`。

### 历史状态快照（EP-116，批次二十四 45/50）

EP-116 `GET /api/v1/skills/{name}/files` 已完成真实文件树、删除后选中态和 provenance sidecar 的五通道验收；固定绿
session 为 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-022720`，账本 `1270→1275`，COVERAGE 五格全绿，
批次当时 `45/50`。当前前线以 EP-117 整体重述为准。

### 历史状态快照（EP-115，批次二十四 40/50）

EP-115 `POST /api/v1/skills:install` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道验收。
真实 App 从 source 预览后只安装新的合法 `ep115-new`；已有 `ep115-existing` 显示 installed 且不可选，坏 manifest
不可选。安装后的 Library、正文、2 个文件、provenance 和 `Pre-approval pending` 与 REST/SQLite 对齐；no-force existing
和新 skill 重放只返回 skip，force 则显示 v2 正文与 replacement 文件，并且只发一次 update signal。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-021859` 的 durable SSE seq `16..20` 单调，
覆盖 setup/create/update/delete；删除专用实体后 App 清掉当前选中详情并回到 `Untitled`。正式证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-115-skill-install-final-green.md`，警报复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-115-skill-install-ledger-reaudit.md`。

正式账本 `1265→1270 judgments`，`G1/F2/A5/C4/G2`，anchors `10/10`，`COVERAGE EP-115=✓✓✓✓✓`，
`gen_coverage.py --check`=`848/247/0`，最终 `alarms.py check` clean。source fixture/runtime 已按授权清理。
该格使批次二十四达到 **40/50**；当前前线以 EP-116 整体重述为准。

### 历史状态快照（EP-114，批次二十四 35/50）

EP-114 `POST /api/v1/skills:inspect-source` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道验收。
首轮红因已有 `commit-helper` 被 UI 默认选中但 no-force install 实际只会跳过；修复后默认仅选择
`installable && !alreadyExists`，已有项保留可见但禁用，且文案明确说明已在库中。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-020745` 逐帧验证非法候选原因、已有项状态、
新项 allowed-tools、选择开关和禁用安装按钮；API `200` 与 UI 完全一致，Cancel 后 skills 列表无新增，SSE 无伪造写帧。
正式证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-114-skill-inspect-final-green.md`，红证据保留。

正式账本 `1260→1265 judgments`，`G1/F2/A5/C4/G2`，anchors `10/10`，`COVERAGE EP-114=✓✓✓✓✓`，
`gen_coverage.py --check`=`848/246/0`；警报复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-114-skill-inspect-ledger-reaudit.md`，最终 `alarms.py check` clean。
source fixture/runtime 已按授权清理。批次二十四当前 **35/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为
EP-115 `POST /api/v1/skills:install`。

### 历史状态快照（EP-113，批次二十四 30/50）

EP-113 `POST /api/v1/skills/{name}:approve-tools` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道
验收。产品目的不是收到 `200`，而是第三方 Skill 的 allowed-tools 信任门必须明确由用户打开，首次授权只产生一次
真实 `skill.updated`，重复点击、网络重试和公开 API 重放都必须幂等，不制造假的生命周期信号。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-013940` 冻结为红：首次 App 授权
产生 `seq=17 skill.updated`，但重复 API 调用仍返回 `200` 时又产生 `seq=18 skill.updated`，即 REST no-op 却伪造
durable signal。stop-and-fix 在 `backend/internal/app/skill/install.go` 让已批准状态直接返回当前实体，补
`TestApproveTools_IsIdempotentAfterApproval` 和 Skill domain 文档，首次授权与安装/更新单事件回归仍保留。

固定绿 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-014829` 由真实 source fixture 走完
Inspect、Install、App pending→active 审批、重复公开 API、未知/本地 Skill 负向矩阵。App 待授权/已授权静态帧与 AX
树一致且稳定；首次授权只有 `seq=17 skill.updated`，重复请求前后 `updatedAt`、`toolsApproved` 完全一致且没有第二个
SSE 更新事件。最终录屏 `189.115000s / 2784x1808`，正式证据为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-113-skill-approve-final-green.md`，红证据与 ledger re-audit
均保留。

定向 Go/race、`git diff --check` 全绿；formal ledger `1255→1260 judgments`，`G1/F2/A5/C4/G2`，anchors `10/10`，
`COVERAGE EP-113=✓✓✓✓✓`，`gen_coverage.py --check`=`848/245/0`。集中写账打开的两条警报已按
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-113-skill-approve-ledger-reaudit.md` 独立复审并 ack，最终
`alarms.py check`=`clean (1260)`；未改阈值、算法、法典或锚点。

本轮 source fixture/runtime 已按用户授权删除，formal session、录像、journals 和证据保留。批次二十四当前 **30/50**；
未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-114 `POST /api/v1/skills:inspect-source`。

### 历史状态快照（EP-112，批次二十四 25/50）

EP-112 `POST /api/v1/skills/{name}:update` 已完成真实 Flutter App、真实受管 gateway、Computer Use 和五通道
验收。产品目的不是收到 `200`，而是上游 skill 更新后，中心正文、文件树、描述、provenance、allowed-tools 信任状态、
通知和失败保护必须同代一致；本地改动非 force 时要明确阻断，force 更新也不能静默丢失未改变的信任配置。

首轮真实 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-011139` 冻结为红：后端 metadata、
文件树和 provenance 已到 v2，但中心 native editor 仍是 v1 正文和已删除 guide，通知还重复发出 `skill.created`+
`skill.updated`。stop-and-fix 重置正文变化时的内部 editor generation、保留页面滚动/大纲壳并阻断旧实例延迟保存，
同时让一次安装/更新只发一个正确的 lifecycle event；Go/Flutter 回归和 frontend library 文档已同步。

固定 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260809-012412` 重跑 v1→v2、local drift 409、
Force update 正负路径。最终录屏 `405.186667s / 2784x1808`，中心与右岛一起切到 v2，3 文件收敛为 2 文件，
`Read` pre-approval 保持；无 stale body、重复 mutation、loading 残留或 Flutter runtime 红线。backend、SSE、frontend、
LLM wire 和 UI/REST 对证，正式绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-final-green.md`，
红证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-red.md`。

定向 Go/race/Flutter、`make -C docs verify` 和 `git diff --check` 全绿；formal ledger `1250→1255 judgments`，
`G1/F2/A5/C4/G2`，anchors `10/10`，COVERAGE `EP-112=✓✓✓✓✓`，`gen_coverage.py --check`=`848/244/0`。
集中写账打开的两条警报已按 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-112-skill-update-ledger-reaudit.md`
复审并 ack，最终 `alarms.py check`=`clean (1255)`；未改阈值、算法、法典或锚点。

本轮本地 source fixture/runtime 已按用户授权删除，formal session、录像、journals 和证据保留。当时批次二十四为 **25/50**；
未到第 50 格不跑统一长门禁、不提交；随后前线进入 EP-113 `POST /api/v1/skills/{name}:approve-tools`。

### 历史状态快照（EP-111，批次二十四 20/50）

EP-111 `POST /api/v1/skills/{name}:activate` 已完成真实 App、真实受管 gateway、Computer Use 和五通道
验收。最终 session `/private/tmp/anselm-rig-ep111-skill-activate-20260808/sessions/20260809-005230` 的
正确 tap wiring 通过 `rig-check`；Computer Use 实时画面完成一次 fork 激活并输出诚实歧义结果，没有扩搜、
越界读取、用户不可解释的失败或视觉跳变。录屏 `156.808333s / 2784x1808 / 60fps`，三路 SSE 连接同一 workspace，
messages durable seq `1..41` 单调，backend 仅有预期范围拒绝 WARN，frontend 无 Flutter/Dart runtime 红线，
LLM proof/chat 成功。

代码已把 fork Explore 隔离从 prompt 提升为确定性 scope error：无 workdir 只读精确绝对路径，有 workdir
所有 filesystem search 必须在挂载根内；fork 成功后 run-local `TurnControl` 移除父回合工具 schema并跳过
AutoActivator，模型若仍发 tool call 则不查找、不执行，以 `TURN_TOOLS_DISABLED` 收尾。未知 agent
`422 SKILL_FORK_AGENT_TYPE_INVALID`、旧坏清单 fail-closed、失败 fork 不污染 active skill 均已由定向测试和
真实路径锁定。精确路径 session `003714` 与晚发工具对抗 session `004327` 作为补充证据；旧 prompt-only、
旧 tap wiring、ReplayKit 重影均保留为负/仪器证据，不能改判为成功。

正式账本 `1245→1250 judgments`，anchors `10/10`，alarms clean，COVERAGE `848 rows / 247 carried /
0 tombstones`。批次二十四当前 **20/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 COVERAGE
下一行。
临时 `ep111-inline` / `ep111-fork` 已按授权清理，均为 `DELETE 204→GET 404`，文件树和
relations 无残留；formal cleanup evidence 位于
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-111-fixture-cleanup.md`。formal anchor 答卷因临时清理
误删已恢复并重新校准 10/10，未绕过或放宽 gate。

### 历史状态快照（EP-110，批次二十四 15/50）

EP-110 `DELETE /api/v1/skills/{name}` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。用户目的不是收到一个 `204`，而是删除一个带 3 个文件和 1 个 function binding 的 skill 后，Library、REST、文件系统、relation、SSE、workspace 隔离和选中态必须一起回到可解释的真相。

真实 App 路径打开 `ep110-delete-tree`，右岛显示 `3 files · 1 bindings`，从 row actions 打开 `Delete this skill?` 确认框并按授权删除；rail 移除 fixture，中心回到空 `Untitled`，无残留详情。删除后 REST 的 skill/files 均为 `404 SKILL_NOT_FOUND`，列表只剩两个 seeded skills，文件树与 equip relation 均清空；缺 workspace、非法名、未知/重复目标和跨 workspace 的负向矩阵也已实际核对。

最终 session `/private/tmp/anselm-rig-ep110-skill-delete-20260808/sessions/20260808-231300` 录屏 `217.530000s`；三路 SSE durable notifications seq `16..19` 单调，backend/frontend 无应用红线，主 workspace gateway challenge/install/models 全 `200`。隔离 workspace 立即删除导致的 install cancellation 是预期生命周期清理，不作为主路径结果。完整证据为 session `evidence/EP-110-final-green.md`，正式指针为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-110-skill-delete-final-green.md`，独立复审为 `EP-110-approval-ledger-reaudit.md`。

定向 Go、race 和 Flutter 测试全绿（Flutter 57 tests），formal ledger `1240→1245 judgments`，`G1/F2/A5/C4/G2`、anchors `10/10`，正式 `alarms.py check` clean，`gen_coverage.py --check`=`848 rows / 242 carried / 0 tombstones`。首个无 `RIG_HOME` 前缀的默认账本写入已排除，正式裁决只认 explicit formal root。批次二十四当前 **15/50**；未满批不跑统一长门禁、不提交。下一原子前线为 EP-111 `POST /api/v1/skills/{name}:activate`。

### 历史状态快照（EP-107，批次二十三 50/50）

EP-107 `POST /api/v1/skills` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。产品目的不是只得到 `201`，而是让用户在真实 Chat 中用自然语言创建一个完整 skill，并让工具 schema、REST、持久化、SSE、Library Properties、Activity 和删除后的 UI 真相一致。

本格先后冻结并修复两条真实产品红：Chat `create_skill` schema 遗漏 `userInvocable`，修复后补严格 bool 解码、映射、schema/description、测试和 domain 文档；修复后的真实 Chat session `/private/tmp/anselm-rig-ep107-skill-create-rerun-20260808/sessions/20260808-215429` 以一次真实工具调用创建 `ep107-chat-notes-v2`，REST/LLM wire/UI 均确认 `userInvocable:true`、`disableModelInvocation:true`、`allowedTools:["Read"]`。随后真实删除回归发现外部删除当前选中 skill 后中心详情残留，修复 `LibraryOcean` 的已见 skill 驱逐逻辑并补中英文文案和 2 个前端回归测试。

最终真实 session `/private/tmp/anselm-rig-ep107-skill-create-rerun2-20260808/sessions/20260808-215933` 删除 `ep107-delete-live2` 后，HTTP 为 `204`、随后 GET 为 `404 SKILL_NOT_FOUND`、workspace `ep107-*` fixture 为 0；真实 App rail 移除、中心回到 `Untitled` 并显示 `This skill was deleted`，SSE notifications durable `seq=19` 为 `skill.deleted`。最终录屏 `259.116667s` 已封片，五通道 `rig-check` 全绿，日志无应用红线；Chat session 另保留真实 gateway completion wire。

定向验证通过：`mise exec -- go test ./internal/app/tool/skill -count=1`；`mise exec -- flutter test test/features/library/deleted_page_eviction_test.dart test/features/library/library_test.dart`（51 tests）；anchors `10/10`；`gen_coverage.py --check`=`848 rows / 239 carried / 0 tombstones`。formal ledger 由 `1225→1230 judgments`，法条为 `G1/F2/A5/C4/G2`，COVERAGE `EP-107=✓✓✓✓✓`；独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-107-skill-create-ledger-reaudit.md` 后 `alarms.py check`=`clean`，未改阈值/算法/法典/锚点。完整证据为最终 session 的 `evidence/EP-107-skill-create-final-green.md`，正式副本位于 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-107-skill-create-final-green.md`。

批次二十三已 **50/50**。本次 loop 的下一动作是统一长门禁和提交：完整 `make verify`、完整 `go test ./...`、已修场景回归、工作树审计；全绿并提交后，才将 EP-108 `GET /api/v1/skills/{name}` 设为下一原子前线。此门禁之前不启动 EP-108。

### 历史状态快照（EP-105，批次二十三 40/50）

EP-105 `GET /api/v1/approvals/{id}/versions/{version}` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。
产品目的不是返回一条 JSON，而是让用户按数字或 opaque ID读取指定历史快照，且版本必须属于 URL 父 Approval；未知、跨父和畸形输入
必须大声失败，软删主行后 immutable history 仍可读。固定 session `/private/tmp/anselm-rig-ep105-approval-version-get-20260808/sessions/20260808-212032`
覆盖 A(v1/v2/v3) 与 B(v1)：正向 numeric/opaque 均为 `200`，负向均得到明确 `APPROVAL_VERSION_NOT_FOUND`，缺 workspace 为 `401`，删除后
实体 `404` 但 A v2/v3 仍 `200`；SQLite 保留全部版本。

真实 App 从 Entities → Approval A → Versions 查看 v3 active、v2 diff 和完整历史；删除 A/B 的 durable signal 让 App 回到 Overview，rail 清空，Parts `2→0`。
五通道收台全绿，录屏 `213.058333s / 2784x1808 / 60fps`，notifications durable seq `16..21` 单调唯一。完整证据为同 session
`evidence/EP-105-approval-version-get-final-green.md`，正式指针为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-105-approval-version-get-final-green.md`。

账本使用 formal `RIG_HOME` 按 `G1/F1/B2/C5/G2` 将 `1215→1220 judgments` 写入五格；anchors `10/10`，独立复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-105-approval-version-get-ledger-reaudit.md`，警报复审后
`alarms.py check`=`clean (1220 judgments on record)`，`gen_coverage.py --check`=`848 rows / 237 carried / 0 tombstones`，
EP-105=`✓✓✓✓✓`。批次二十三当前 **40/50**；未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-106 `GET /api/v1/skills`。

## 历史前线（2026-08-08，EP-102 收口，批次二十三 25/50）

EP-102 `POST /api/v1/approvals/{id}:revert` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。
用户目的不是收到 `200`，而是把 Approval 历史版本设为 active 后，让 Overview、Versions、Activity、REST、SQLite 和 SSE
保持同一个真相，非法版本输入大声失败，不能切错版本或留下脏状态。

首轮真实 session `/private/tmp/anselm-rig-ep102-approval-revert-20260808/sessions/20260808-201325` 冻结为红：
正常点击版本动作触发 selectable 子树重建时，Flutter `MultiSelectableSelectionContainerDelegate` 抛出真实
`Concurrent modification during iteration`。stop-and-fix 将 `frontend/lib/core/ui/an_interactive.dart` 的 selection
region focus handoff 延后一个 frame并加脱离守卫，新增 selectable 重建回归；`flutter test` 6/6、定向 analyze 通过。

固定真实 session `/private/tmp/anselm-rig-ep102-approval-revert-fixed-20260808/sessions/20260808-202631` 重跑 v2→v1、
外部 REST v1→v2 resync、UI 再 v2→v1，最终 Overview/Versions/REST/SSE/SQLite 一致，无异常、重复 mutation、裁切或视口跳变。
负向覆盖未知版本 `999→404 APPROVAL_VERSION_NOT_FOUND` 和字符串版本 `"1"→400 INVALID_REQUEST`；录屏 `304.298333s` 已封片。

五通道证据为 `/private/tmp/anselm-rig-ep102-approval-revert-fixed-20260808/sessions/20260808-202631/evidence/EP-102-approval-revert-final-green.md`：
backend 无应用红线，frontend 仅有已分类 AXTree 观察器消息且无运行时 exception，三路 ssetap durable seq 单调并记录 reverted/deleted，
REST/SQLite/UI 对证，llmtap 真实 managed gateway bootstrap 全 200。用户授权 cleanup 已完成 `DELETE 204→GET 404`、列表总数 0，
仅一条 `approval.deleted`；清理证据同 session `EP-102-fixture-cleanup.md`。

正式账本使用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`，五级 `G1/F2/A5/C4/G2` 由 `1200→1205`，anchors 10/10，
独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-102-approval-revert-ledger-reaudit.md` 后 alarms clean；
`gen_coverage.py --check` 为 `848 rows / 234 carried / 0 tombstones`，EP-102=`✓✓✓✓✓`。批次二十三当前 **25/50**；
未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-103 `POST /api/v1/approvals/{id}:iterate`。

## 历史前线（2026-08-08，EP-101 收口，批次二十三 20/50）

EP-101 `POST /api/v1/approvals/{id}:edit` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。
用户目的不是“接口成功”，而是从 Approval 的 `Edit with AI` 入口完成一次完整 replacement：新增
`refundReason:string`，精确替换模板，并保留未改变的 `allowReason=true`、`timeout=4h`、
`timeoutBehavior=reject`，用户不能看到失败后 retry 的半成品旅程。

首轮真实 session `/private/tmp/anselm-rig-ep101-approval-edit-20260808/sessions/20260808-193907`
冻结为红：模型遗漏 unchanged `allowReason`，后端正确拒绝，App 显示红色工具卡后才 retry 成功。stop-and-fix
强化 `edit_approval` description/schema，要求先读当前 Approval 并复制所有 required fields；补工具测试，
同步 Approval domain 文档，没有放宽后端完整替换契约。

固定真实 session `/private/tmp/anselm-rig-ep101-approval-edit-fixed-20260808/sessions/20260808-195118`
重跑通过：一次工具调用产生 v3，REST/SSE/LLM wire/UI 均为三字段输入、精确模板、`allowReason=true`、
`4h`、`reject`。终帧显示完整请求、单一成功工具卡、齐全字段表、最终摘要和 `Edited ×2` 活动，
无红卡、裁切、loading 残留、输入/视口跳变或重复 mutation。中文 `type_text` 的字符丢失已明确作为
Computer Use 输入层限制；精确意图使用 ASCII 等价请求在正常 composer 重走，未把丢字结果冒充通过。

五通道与收台证据冻结于
`/private/tmp/anselm-rig-ep101-approval-edit-fixed-20260808/sessions/20260808-195118/evidence/EP-101-approval-edit-final-green.md`：
backend/frontend 无应用红线，SSE 最终 durable close 为 messages `56/59/63/64`、notifications
`20 approval.edited`，LLM wire 有完整 required payload，录屏已由 `rig-down.sh` 封片。用户授权的
临时 Approval cleanup 已完成 `DELETE 204 → GET 404`、列表为空，SSE 仅一条 `approval.deleted`。

正式账本使用 `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`，五级
`G1/F2/A5/C4/G2` 使 `1195→1200 judgments`，anchors `10/10`；独立 alarm re-audit 为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-101-approval-edit-ledger-reaudit.md`，
`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 233 carried / 0 tombstones`。
默认 RIG_HOME 的错路由副本保留作审计，正式工作记录只认 formal ledger。批次二十三当前 **20/50**；
未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-102 `POST /api/v1/approvals/{id}:revert`。

## 历史前线（2026-08-08，EP-100 收口，批次二十三 15/50）

EP-100 `DELETE /api/v1/approvals/{id}` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。产品目标是从活动目录移除 Approval、清理关系边、保留 immutable version history，并让依赖 workflow 保持可见且可修复，而不是只看 `204`。

固定 session `/private/tmp/anselm-rig-ep100-approval-delete-20260808/sessions/20260808-192034` 的真实路径打开 Approval 删除确认并确认删除；Approval 从 rail/Parts 消失，关系图清边，通知指出 `1 reference dangling`，workflow graph/editor 保留原始 ref。REST 覆盖 `204`、删除后 `404`、版本历史保留、workflow/capability missing-ref、关系清理、重复/未知、缺 workspace、cross-owner 和同名复用；SQLite 证明软删主行、三条版本保留且无悬空关系边。录屏 `494.890000s` 已封口。

五通道对证：backend 652 行无应用红线；frontend 18 行只有已知 launcher 噪声；ssetap 三流均连接，主 notifications durable seq `16..24` 单调；llmtap 真实指向 `https://api.anselm.website` 且 bootstrap 全 200；rig-check 前后全绿、rig-down 正常。用户授权的独立 cleanup `/private/tmp/anselm-rig-ep100-cleanup-20260808/sessions/20260808-192941` 已删除依赖 workflow、trigger 和辅助 workspace，均 `204→404`，主 workspace 与证据保留。

正式绿证据为 `/private/tmp/anselm-rig-ep100-approval-delete-20260808/sessions/20260808-192034/evidence/EP-100-approval-delete-final-green.md`，独立账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-100-approval-delete-ledger-reaudit.md`。`judge.py` 按 `G1/F2/A5/C4/G2` 将账本 `1190→1195 judgments`，COVERAGE `EP-100=✓✓✓✓✓`，anchors `10/10`；两条统计警报经复审 ack，未改阈值/算法/法典/锚点，`alarms.py check`=`clean (1195)`，`gen_coverage.py --check`=`848 rows / 232 carried / 0 tombstones`。本格无产品源代码变更；pytest 缺失已如实记录，不伪报通过。批次二十三当前 **15/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-101 `POST /api/v1/approvals/{id}:edit`。

## 历史前线（2026-08-08，EP-098 收口，批次二十三 5/50）

EP-098 已完成 Approval 单读的 activeVersion 完整性、悬空/空指针 fail-closed、workspace 隔离和真实 App Versions/Overview 验收；固定 session `/private/tmp/anselm-rig-ep098-approval-get-fixed-20260808/sessions/20260808-185307` 录屏 `292.263333s`，正式账本 `1180→1185`，COVERAGE 五级全绿，cleanup 和独立警报复审均已完成。当前恢复不得把批次计数回退到 EP-098。

## 历史前线（2026-08-08，EP-097 收口并提交，批次二十二 50/50）

## 历史前线（2026-08-08，EP-096 收口，批次二十二 45/50）

EP-096 `POST /api/v1/approvals` 已完成真实 App、真实受管 Anselm gateway、Computer Use 和五通道验收。用户目的不是得到
一个成功状态码，而是自然语言创建带输入类型、reason、timeout 和 timeout behavior 的审批表单后，正文、Activity、审批预览、
REST、SQLite 与 SSE 必须一致且可继续使用。

首轮真实 App 发现红：真实受管模型把 `2h` 编码为 `"7200"`，旧边界先失败，随后模型重试成功，UI 同时显示失败工具行、
`Draft unsaved · nothing was created` 和成功卡片。红证据为
`/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-175421/evidence/EP-096-approval-create-red.md`。
stop-and-fix 在工具边界只兼容精确整数秒字符串/整数并归一化为 duration（`7200`→`2h`），公开 HTTP/domain 契约仍拒绝
零、负数、小数和坏形状；补正负解码、tool execution、domain/handler tests 并同步 approval reference。定向 Go tests 通过。

固定 session `/private/tmp/anselm-rig-ep096-approval-create-20260808/sessions/20260808-180647` 由同一 conductor 托管
真实 App、Computer Use、`28438` 窗口 `132.026667s` 录像、backend/frontend journal、三路独立 SSE witness、managed
gateway 和 LLM tap。最终 UI 只有成功文本、Created v1、单一 Created Activity 与完整 approval preview：inputs、`2h`、
自动 reject、reason 和 Approve/Reject 均可见，没有失败行、矛盾文案、裁切、重叠、loading 残留或跳变。五通道无未解释
backend/frontend 错误，SSE durable seq 单调，LLM upstream 全 200 且真实参数仍为 `"timeout":"7200"`；HTTP/SQLite 均为
`apf_c07e5096237e71db` v1 `2h/reject`。绿证据为同 session `EP-096-approval-create-final-green.md`。

用户授权的 cleanup 已完成：独立 session `/private/tmp/anselm-rig-ep096-cleanup-20260808/sessions/20260808-181438` 通过
API 删除三条审批和三条验收对话，DELETE `204×6`、exact GET `404×6`、列表无 `ep096-*`；SQLite 主行保留 `deleted_at`，
三条 immutable v1 version 保留，证据、journals、录像未删。清理证据为 `EP-096-fixture-cleanup.md`。

正式账本 `1170→1175 judgments`，按 `G1/F2/A5/C4/G2`，COVERAGE `EP-096=✓✓✓✓✓`，anchors=10/10；独立复审记录为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-096-approval-create-ledger-reaudit.md`。统计警报已按复审后 ack，
没有改阈值/算法/法典/锚点；formal home 的 `alarms.py check`=`clean (1175)`，`gen_coverage.py --check`=`848 rows /
228 carried / 0 tombstones`。批次二十二由 **40/50→45/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为
EP-097 `GET /api/v1/approvals`。

## 历史前线（2026-08-08，EP-092 收口，批次二十二 25/50）

EP-092 `POST /api/v1/controls/{id}:revert` 已完成真实 App、受管 gateway、Computer Use 和五通道验收：只移动
Control active pointer 到 v1，保留 name/description、不铸造新版本且保留 v2 历史。固定 session
`/private/tmp/anselm-rig-ep092-control-revert-20260808/sessions/20260808-162625`，录屏 `474.791667s`；HTTP
矩阵覆盖 v2/v1 成功回退及 zero/unknown 版本 404，SQLite/REST/UI/SSE 一致，cleanup 后 App 收敛到
`0 entities, 0 relations`。账本 `1150→1155`，COVERAGE 五级全绿，anchors=10/10，`alarms.py check`=`clean (1155)`，
清册 `848/224/0`；错误 shell quoting 只作为无副作用 harness 证据保留。

## 历史前线（2026-08-08，EP-091 收口，批次二十二 20/50）

EP-091 `POST /api/v1/controls/{id}:edit` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
用户目的不是“得到一个新版本”，而是只改变明确要求的路由条件，同时保留输入声明、port、emit 与 catch-all；
托管模型等值的 JSON 数组编码要能执行，显式清空要有语义，坏输入要在 mutation 前拒绝。最终真实画面显示
active v5、`score:number`、approve `input.score >= 0.96`、review default 与两侧 emit。

首轮真实 AI 编辑冻结出两层产品红：托管模型把 `inputs`/`branches` 作为精确 JSON 数组字符串传入，旧工具边界
按原生数组解码失败；更严重的是模型省略可选 `inputs` 时，旧 `edit_control` 生成了 `inputs:null` 的 v3，擦除
原有 `score` 输入声明。红证据永久保留；stop-and-fix 在 AI 工具、领域服务和 HTTP handler 共同加入 presence
语义：省略保留 active declaration，显式 `[]` 才清空；原生数组和精确 JSON 数组字符串均有明确解码边界，坏
字符串/object/non-array 不猜测。服务层与工具层回归测试、Control API/domain 文档同步。

固定 session `/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-161138` 的录屏为
`388.893333s / 2784x1808`。v2 基线经真实 App 确认后，Edit with AI 创建 v4 并保留 score 声明；LLM wire
`00006_v1_chat_completions.bin` 证实真实托管模型传入 stringified inputs。HTTP 省略 inputs 创建 v5 仍保留
score；malformed `inputs` 返回 `400 INVALID_REQUEST` 且随后 GET 证明没有部分 mutation。Computer Use 最终逐帧
确认 Control 详情无裁切、重叠、跳变或残留 loading。

REST/SQLite/SSE/UI/LLM 对证：三路 SSE 均连接，messages durable `1..35`、notifications durable `1..5` 严格
单调，entities 完成连接；backend 494 行无应用 WARN/ERROR/FATAL/panic/tool execute failed，frontend 18 行无
Flutter/Dart/RenderFlex/Unhandled 红线；challenge 与 5 次真实 chat completion 全 200。rig-check 收台前确认
五通道物理归属，rig-down 后无残留进程。

正式证据为 `/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-161138/evidence/EP-091-control-edit-final-green.md`，
红证据为 `/private/tmp/anselm-rig-ep091-control-edit-20260808/sessions/20260808-160105/evidence/EP-091-control-edit-red-inputs-erased.md`，
独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-091-control-edit-ledger-reaudit.md`。`judge.py`
按 `G1/F2/A5/C4/G2` 将账本 `1145→1150 judgments`，`COVERAGE EP-091=✓✓✓✓✓`，anchors=10/10。两条统计警报已按
复审记录 ack，未改阈值、算法、法典或锚点；`alarms.py check`=`clean (1150)`，`gen_coverage.py --check`=
`848 rows / 223 carried / 0 tombstones`。批次二十二由 **15/50→20/50**，未到 50 格不跑统一长门禁、不提交；
下一原子前线为 EP-092 `POST /api/v1/controls/{id}:revert`。

## 历史前线（2026-08-08，EP-090 收口，批次二十二 15/50）

EP-090 `DELETE /api/v1/controls/{id}` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
用户目的不是拿到一个 `204`，而是删除后 rail、Parts 和关系图都与 REST/DB 真相收敛，被删实体和关系边消失，
存活 workflow 保留，历史版本保留，悬空引用由 capability-check 明确呈现，重复/未知删除可解释失败。固定切片
同时删除同类 Approval 以检查依赖通知对称性；Approval coverage 单格由 EP-100 管理，不在此重复计数。

首轮真实 session 冻结出产品红：后端删除和 `/relgraph` 已正确变成 `4 relations`，但真实 App 等待约 `2.5s`
仍呈 `8 entities, 6 relations`，保留已删除 Control/Approval ghost nodes。修复在 `EntityRepository` 增加不裁剪
实体种类的 workspace-wide durable `relationSignals()`；`relGraphProvider` 监听该脉冲和 lifecycle resync，
删除及聚合依赖通知用 `300ms` 合并刷新。ephemeral 帧不失效 durable snapshot，Fixture 与 3 项 provider 守卫同步，
Flutter 定向 15 项全通过。

红证据为 `/private/tmp/anselm-rig-ep090-control-delete-20260808/sessions/20260808-152528/evidence/EP-090-control-delete-red.md`；
固定 session `/private/tmp/anselm-rig-ep090-control-delete-fixed-20260808/sessions/20260808-153741` 的录屏为
`98.700000s / 2784x1808 / 60fps`。创建后真实 App 从 `6/4` 收敛到 `14/10`，删除后从 REST 的 `12/8` 收敛到
`12/8`；Control/Approval rail 消失、Parts 回到 0、剩余节点保留。Control/Approval delete `204`，exact GET/
重复 DELETE `404`，版本历史保留，capability-check 明确悬空引用。notifications durable `1..8` 连续，backend
195 行无应用红线，frontend 18 行无 Flutter runtime 红线，三流连接且 rig-check/rig-down 干净；确定性 REST/UI
切片没有伪造 LLM completion，llmtap 只保留真实 ready/wiring 记录。

正式证据为 `/private/tmp/anselm-rig-ep090-control-delete-fixed-20260808/sessions/20260808-153741/evidence/EP-090-control-delete-final-green.md`，
独立复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-090-control-delete-ledger-reaudit.md`；`judge.py`
按 `G1/F2/A5/C4/G2` 将账本 `1140→1145 judgments`，`COVERAGE EP-090=✓✓✓✓✓`，anchors=10/10。两条统计警报已按
复审记录 ack，未改阈值、算法、法典或锚点；`alarms.py check`=`clean (1145)`，`gen_coverage.py --check`=
`848 rows / 222 carried / 0 tombstones`。批次二十二由 **10/50→15/50**，未到 50 格不跑统一长门禁、不提交；
下一原子前线为 EP-091。

## 历史前线（2026-08-08，EP-089 收口，批次二十二 10/50）

EP-089 `PATCH /api/v1/controls/{id}` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
真实用户目的不是“收到一个 200”，而是修改 Control 的 name/description 后，详情与列表准确反映变化，同时
空 patch/等值 patch 可以安全重试而不伪造一次修改。固定版创建真实 Control `ctl_e5e6640b7767de8f`，
实际 patch 后 App 详情显示 `EP089 Control Patched`、新 description、v1、inputs 和 ordered routing branches；
版本线没有被 metadata patch 改写。

首轮真实 session 冻结出产品红：空 `PATCH {}` 虽返回 200，却刷新 `updatedAt` 并发出 `control.updated` durable
notification。stop-and-fix 让 Control 的 UpdateMeta 先比较实际值，no-op 直接返回，不 Save、不刷新时间、不 publish；
同类 Approval 同步修复。API/domain 文档写明该契约，Control/Approval app 测试直接用 recording notifier 锁定
空 patch 与等值 patch 不写盘、不发事件。修复前红证据永久保留在
`/private/tmp/anselm-rig-ep089-control-patch-20260808/sessions/20260808-150028/evidence/EP-089-control-patch-red.md`。

固定 session `/private/tmp/anselm-rig-ep089-control-patch-fixed-20260808/sessions/20260808-151021` 由同一 conductor
托管真实 Flutter App、Computer Use、录屏、frontend/backend journal、三路独立 SSE witness、managed gateway 和
LLM tap；录屏 `401.523333s / 2784x1808 / 60fps`。Control 实际 patch、空 patch、等值 patch，Approval 实际
description patch、空 patch、等值 patch，正负 HTTP 矩阵及删除清理均已完成。SSE notifications durable seq
`1..6` 严格为 Control created/updated、Approval created/updated、两次 deleted；no-op 没有幽灵帧。删除后真实
Overview 显示两类 rail 无残留、Parts 0、关系图 0 entities/0 relations，空态文案完整。

REST/SQLite/SSE/UI 对证：Control/Approval no-op 的 `updatedAt` 分别保持不变，实际变化各只发一条 updated；
invalid name、unknown field、unknown id、缺 workspace header 均返回预期 422/400/404/401；DELETE=204 后 exact
GET=404、live lists=0、workspace 保留。backend 511 行无应用 WARN/ERROR/panic/FATAL，frontend 19 行无 Flutter
runtime 红线，managed challenge/install/models 全 200，三流连接且无 gap，rig-check/rig-down 干净收台。

正式证据为 `/private/tmp/anselm-rig-ep089-control-patch-fixed-20260808/sessions/20260808-151021/evidence/EP-089-control-patch-final-green.md`，独立账本复审为
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-089-control-patch-ledger-reaudit.md`；`judge.py` 按
`G1/F2/A5/C4/G2` 将正式账本 `1135→1140 judgments`，`COVERAGE EP-089=✓✓✓✓✓`，anchors=10/10。集中写账
触发的 `gap-too-fast`/`discovery-collapse` 已经独立重读红绿 session、REST、SSE、backend/frontend/LLM、UI
和单元测试后 ack，未改阈值、算法、法典或锚点；`alarms.py check`=`clean (1140)`，`gen_coverage.py --check`=
`848 rows / 221 carried / 0 tombstones`。

批次二十二当前 **10/50**，未达到 50 格，因此不运行统一长门禁、不提交。EP-089 的 backend 修复、测试、契约文档、
红绿证据、工作记录和 COVERAGE ledger 留在当前工作树，随批次二十二第 50 格统一提交。下一原子前线为 EP-090。

## 历史前线（2026-08-08 13:35，EP-086 收口，批次二十一 45/50）

EP-086 `POST /api/v1/controls` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
首轮真实路径发现未知 input type `money` 被接受并渲染；stop-and-fix 增加 `CONTROL_INVALID_INPUTS`，
create/edit 在持久化前校验 schema，并补 domain/app 回归。固定 session
`/private/tmp/anselm-rig-ep086-control-20260808-fixed/sessions/20260808-132726` 覆盖空名、空分支、
缺 catchall、非法 CEL、未知类型、重复字段名、合法创建和重复名称：422/201/409 语义均正确。

真实详情逐帧显示输入类型、三条条件/默认路由和 emit keys；REST、SQLite、SSE 和 UI 对齐，清理后
control DELETE=204→GET=404、workspace 保留、tombstone/version/通知保留且 relations=0。录屏
`166.691667s`，三路 durable SSE 无 gap，managed challenge/install/models 全 200，frontend/backend 无
未解释应用红线，rig-check/rig-down 干净收台。正式账本 `1120→1125`，anchors=10/10，COVERAGE
EP-086=✓✓✓✓✓，独立复审后 `alarms.py check` clean (1125)，`gen_coverage.py --check`=`848/218/0`。

批次二十一当时 **45/50**，未到 50 格不跑统一长门禁、不提交。EP-086 的代码、测试、文档和证据随第 50 格
统一提交；下一原子前线为 EP-087 `GET /api/v1/controls`。

## 历史前线（2026-08-08 13:10，EP-085 收口，批次二十一 40/50）

EP-085 ANY /api/v1/webhooks/{triggerId}/{path...} 已完成真实 App、受管 Anselm gateway、Computer Use
和五通道验收。外部请求覆盖 wrong method、HMAC bad/valid/duplicate/different/text、plain-secret
missing/wrong/header/query、path edit 前后；用户在同一 Trigger 详情里看到 URL/Copy、签名算法与 header、
Listening、Last fired、Activity 和 Dispatch，plain-secret 详情补充 X-Webhook-Secret header 或
?token= query 的双语引导且不泄露 secret。重复 body 只增加 Activation 审计，不重复 Firing/run。

首轮真实路径捕获了 Overview 外部 fire 后仍显示 Last fired: never 的产品红；修复为 fire signal 触发 REST
truth refresh 并失效 observability projection。第二轮捕获 plain-secret 认证载体不可发现；补引导后
最终 session /private/tmp/anselm-rig-ep085-webhook-20260808-final/sessions/20260808-125703 重跑
通过。录屏 539.071667s，rig-check/rig-down 通过，SSE notifications/entities/messages 全连接且
durable seq 1..10、1..12 无 gap，frontend/backend 无未解释应用红线，managed challenge/install/models
全 200；确定性 webhook slice 没有伪造 LLM completion。SQLite、REST、UI、SSE 对证，fixture 清理均
DELETE=204→GET=404，workspace 保留。

正式证据为 /private/tmp/anselm-rig-ep085-webhook-20260808-final/sessions/20260808-125703/evidence/EP-085-webhook-real-session.md，
ledger re-audit 为 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-085-webhook-ledger-reaudit.md；
anchors=10/10，账本 1115→1120，COVERAGE EP-085=✓✓✓✓✓。两条集中写账警报按独立复审 ack，阈值/算法/
法典/锚点未改，alarms.py check=clean (1120)。

批次二十一当前 40/50，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-086
POST /api/v1/controls。

## 历史前线（2026-08-08 12:38，EP-084 收口，批次二十一 35/50）

EP-084 `GET /api/v1/trigger-schedule` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道
验收。真实 Scheduler Overview 同时呈现 dense/sparse future cron、paused lane、无 workflow 的 trigger
和无可预测下一次触发的 webhook；未来窗口达到 cap 时显示独立截断句，成功时间格可以打开 run/operations
表面，hover card 展示小时内真实运行与 honest overflow。9 条真实 cron 运行均完成，cleanup 后 App 由
durable delete 通知收敛到 `No automation yet`。

本轮 setup-only session 因复用数据库残留旧 gateway wiring 被 `rig-check` 拒绝，保留为仪器红证据；fresh
data session 才是正式产品证据。最终 session `/private/tmp/anselm-rig-ep084-schedule-20260808-retry/sessions/20260808-122252`
录屏 `667.105000s`，由同一 conductor 托管 App、Computer Use、窗口录制、frontend/backend journal、三路
SSE witness、managed gateway 和 LLM tap，`rig-check`/封口/`rig-down` 通过且收台干净。SSE=`73` 条，entities
durable `1..20`、notifications durable `1..27`；backend/frontend 无应用级红线，LLM challenge/install/models
全 200，唯一已知平台噪声是 Flutter runner foreground warning。视觉帧复核了 Overview、hover card、暂停/截断
语义和清理后的空状态。

正式证据 `/private/tmp/anselm-rig-ep084-schedule-20260808-retry/sessions/20260808-122252/evidence/EP-084-schedule-real-session.md`，
ledger re-audit `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-084-trigger-schedule-ledger-reaudit.md`；
10 个 fixture 均 `DELETE=204→GET=404`，workspace 未删。定向 Go 黑盒 2 项、Scheduler KPI/Overview Flutter
回归 65 项通过；anchors=`10/10`，账本 `1110→1115`，`COVERAGE EP-084=✓✓✓✓✓`，两条集中写账警报经独立
复审 ack，`alarms.py check`=`clean (1115)`，`gen_coverage.py --check`=`848 rows / 216 carried / 0 tombstones`。

批次二十一当时 **35/50**，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-085
`ANY /api/v1/webhooks/{triggerId}/{path...}`。

## 历史前线（2026-08-08 10:57，EP-081 v8 收口，批次二十一 20/50）

EP-081 `GET /api/v1/trigger-activations/{id}` 已完成真实 App、受管 Anselm gateway、Computer
Use 和五通道验收。用户从 Chat 要求读取具体 activation：模型一次成功调用 `get_activation`，正文
对 ID/时间使用诚实的 adjacent-card 指向，展开 tool dossier 可复制 Activation ID、Trigger ID、
Created at 精确值；kind、fired、payload、firingCount 可读，没有失败重试卡或假字段。v4/v5 的表格
chunk、v6 的中文表头、v7 的列表式 reasoning 红帧均保留；v8 以字段别名、camelCase 整行保持和
stream/durable 双重脱敏关闭所有可见占位词。

正式 v8 session `/private/tmp/anselm-rig-ep081-fixed-v8-20260808/sessions/20260808-105255` 的录屏可读、
时长 `72.693333s / 2784x1808`；同一 conductor 托管 App、Computer Use、录屏、
frontend/backend journal、三路 SSE witness、managed gateway 和 LLM tap，`rig-check`/封口/`rig-down`
通过且收台干净。SSE witness `50` 条记录（messages/entities/notifications=`44/1/5`），messages
durable seq=`1..14`，entities fire signal 与 LLM activationId 对齐；产品可见 delta/close 无
`the requested item` / `the recorded time`，backend/frontend 无应用级红线。

正式红/绿/复审证据为 v4-v7 session 与 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-081-trigger-activation-{green-v8,ledger-reaudit-v8}.md`。
v8 临时 trigger/conversation 均真实 `DELETE=204`、后续 `GET=404`，session 仍保留。anchors=`10/10`，
账本 `1095→1100`，`COVERAGE EP-081=✓✓✓✓✓`，`alarms.py check`=`clean (1100)`，
`gen_coverage.py --check`=`848/213/0`；红问题、修复和警报复审均已留档，阈值/算法/法典/锚点未改。

批次二十一当前 **20/50**，未到 50 格不跑统一长门禁、不提交。EP-079/EP-081 activation
修复与本轮文档同步仍在当前工作树，随第 50 格统一提交。下一原子前线为 EP-082
`GET /api/v1/firings`。

## 历史前线（2026-08-08 07:56，EP-077 收口，批次二十 47/50）

EP-077 `POST /api/v1/triggers/{id}:pause` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
真实路径为 Entities rail → Trigger More actions → Pause：详情显示 `Paused / Listening: No`，引用仍为 1，
Fire inert；暂停期间 REST `:fire` 返回 `422 TRIGGER_PAUSED` 且不产生新 activation/firing/flowrun。
同一处 Resume 后详情回到 `Listening / Listening: Yes`，恢复后的 sensor source 真实生成
`tra_217e69d5737b4a0c → trf_e1ce88be0f712109 → fr_6aeac3da976cacbb`，flowrun completed。

正式 session `/private/tmp/anselm-rig-ep077-pause-20260808/sessions/20260808-074937` 录屏
`207.725000s / 2784x1808 / 60fps`；关键帧为 `evidence/trigger-paused-final.png`、
`evidence/trigger-resumed-final.png`。三路 SSE 均连接，entities status true/false、fire、
run_started(seq=3)、run_terminal(seq=4) 均可重读，REST/SQLite/UI 对齐；backend/frontend/LLM journal
`254/32/1`，无应用级红线，AXTree churn 有 session review，LLM ready-only 符合 deterministic graph。
`rig-check`、录屏封口、`rig-down`、Go/Flutter 定向验证、Dart analyze 和 diff check 通过。

正式红/绿/复审证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-077-trigger-pause-{red,green,ledger-reaudit}.md`；
anchors=`10/10`，`judge.py` 五格 `G1/F2/A5/C4/G2` 使账本 `1070→1075 judgments`，
`COVERAGE EP-077=✓✓✓✓✓`；集中写账触发的两条警报已按独立复审 ack，阈值、算法、法典和锚点未改，
`alarms.py check`=`clean (1075)`，`gen_coverage.py --check`=`848/209/0`。台架 shell 拼接与 AX review
问题均留有审计记录，不计产品红。

批次二十当前 **47/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-078
`POST /api/v1/triggers/{id}:resume`。

## 历史前线（2026-08-08 07:10，EP-075 收口，批次二十 41/50）

EP-075 `DELETE /api/v1/triggers/{id}` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。
首轮 generic 删除确认没有解释 listener 和 workflow 依赖后果，真实红帧保留；修复后，触发器确认框 fresh 读取
`GET /api/v1/relgraph`，列出入向 `equip/link` 使用者，明确说明会停止监听并让 workflow 需要修复，关系读取失败
则不继续删除。中英文 i18n、实体 rail regression 和 frontend/backend events 文档已同步。

最终 session `/private/tmp/anselm-rig-ep075-delete-20260808/sessions/20260808-070205` 的真实路径为：
Entities rail → Trigger detail (`Listening: Yes / Listeners: 1`) → More actions → Delete → 专用确认框 → Delete；
随后详情回 Overview，Trigger `24→23`、Parts `24→23`、关系图 `10→8`，Notifications 托盘显示 trigger deleted
与 dangling dependency。录屏 `308.340000s / 2784x1808 / 60fps`，关键帧在 session frames 目录。

REST/SQLite/SSE/UI 对证：DELETE=`204`、exact GET=`404 TRIGGER_NOT_FOUND`、list=`23` 且 deleted id 缺席；tombstone、5
activation、5 firing 保留，删除后无新 activation/firing；relgraph 无 deleted id 边；引用 workflow capability-check
诚实报告缺失 trigger。ssetap 三流均连接，entities/notifications durable seq 为 `1..2/1..2` 且单调，含
`trigger.deleted`/`relation.dependency_broken`；LLM tap ready-only。frontend 两条固定 AXTree observer churn 已按
session review 分流，静置不增长且无 Dart/FlutterError/RenderFlex/Unhandled；backend 无应用级 WARN/ERROR/panic/FATAL。

正式绿证据为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-075-trigger-delete-green.md`，红证据为同目录
`EP-075-trigger-delete-red.md`，独立复审为 `EP-075-trigger-delete-ledger-reaudit.md`。锚点 `10/10` 后，`judge.py`
按 `G1/F2/A5/C4/G2` 将账本 `1060→1065 judgments`，COVERAGE `EP-075=✓✓✓✓✓`；集中写账触发的两条统计警报
已按独立复审 ack，`alarms.py check`=`clean (1065)`，`gen_coverage.py --check`=`848/207/0`，阈值、算法、法典和
锚点未改。Dart analyze、实体 rail 30 项 Flutter 测试、trigger/relation/http handler Go 测试、diff check 均通过。

批次二十当前 **41/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-076
`POST /api/v1/triggers/{id}:fire`。

## 历史前线（2026-08-08 06:24，EP-073 收口，批次二十 35/50）

最终绿 session `/private/tmp/anselm-rig-ep073-get-trigger-20260808/sessions/20260808-061331` 的
Computer Use 在同一详情页完成 `No/— → Yes/2026-08-09 00:00 → No/—`，无重新选择；最终 REST 为
`paused=true, refCount=1, listening=false, nextFireAt` 缺席。`sse.jsonl` 独立记录同一 trigger 作用域
的 `status {paused:false}` 和 `status {paused:true}`；backend 无应用红线，frontend 只有已知 runner
启动提示，稳定 hot/cold 帧无布局跳变或残留时间戳，LLM tap 为 deterministic endpoint 的 readiness-only。
正式绿证据、红证据和独立复审分别为：
`/private/tmp/anselm-rig-ep073-get-trigger-20260808/sessions/20260808-061331/evidence/EP-073-get-trigger-green.md`、
`/private/tmp/anselm-rig-ep073-get-trigger-20260808/sessions/20260808-060226/evidence/EP-073-get-trigger-red.md`、
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-073-get-trigger-ledger-reaudit.md`。

锚点 `10/10`，五级 `G1/F2/A5/C4/G2` 已写入中央账本 `1050→1055 judgments`，`COVERAGE EP-073=✓✓✓✓✓`；
两条统计警报已按红/绿证据和独立复审 ack，阈值/算法/法典/锚点未改，`alarms.py check`=`clean (1055)`，
`gen_coverage.py --check`=`848/205/0`。定向 Go/Flutter/API 验证、Dart format、gofmt 和 diff check 通过。
批次二十当前 **35/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-074
`PATCH /api/v1/triggers/{id}`。

## 历史前线（2026-08-08 04:52，EP-070 收口，批次二十 20/50）

EP-070 `POST /api/v1/flowruns/{id}/approvals/{node}:decide` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。用户能从 Scheduler Overview 或顶部 approval capsule 理解真实生产审批、展开理由、批准/拒绝，并看到 inbox、运行计数、下游节点和 run history 收敛；非法 decision、未知字段、重复决策和并发 first-wins 均有诚实边界，拒绝不会执行 publish。

正式 session `/private/tmp/anselm-rig-ep070-approval-decision-20260808/sessions/20260808-043003` 的录屏为 `788.638333s / 2784x1808 / 60fps`，manifest 归属 backend、Flutter runner、recorder、三路独立 SSE witness 与 LLM tap；运行中 `rig-check` 通过，`rig-down` 后无 owned process/listener 残留。修正版真实 webhook fixture capability-check 为 `structurallyValid=true, resolved=true`；旧 test-only `trg_manual` 构造只保留 setup 红证据。

真实路径为：`fr_9671dd6aab7b6337` 填理由后 approve 并执行 publish；`fr_890f4d3a58f14c19` 覆盖 maybe=`422`、未知字段=`400`、reject、无下游和重复决策=`422`；`fr_de436f8c6f8a6f5a` 并发 yes/no 只有一个 `202` 胜者且 publish 只执行一次；`fr_abd2b9be79aba3a4` 从顶部胶囊 approve 并在 run history 收敛。REST/SQLite 与 UI 一致，Computer Use 逐帧无裁切、RenderFlex overflow、跳变、死 spinner、旧 CTA 或重复错误。正式证据为 `.../sessions/20260808-043003/evidence/EP-070-approval-decision-real-session.md`，ledger re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-070-approval-decision-ledger-reaudit.md`。

五通道均有证据：backend 无应用 WARN/ERROR/panic/FATAL，frontend 无 Flutter/Dart/overflow 红线，SSE 三流连接且 entities durable seq 到 `20`、notifications 到 `37`，park/decision 按契约为 `seq=0`，LLM challenge/install/models 全 `200`；确定性 graph 无 LLM completion。anchors `10/10`，`judge.py` `G1/F2/A5/C4/G2` 使账本 `1035→1040`，COVERAGE `EP-070=✓✓✓✓✓`，`alarms.py check`=`clean (1040)`，`gen_coverage.py --check`=`848/202/0`，阈值、算法、法典和锚点未改。

批次二十当前 **20/50**；未到第 50 格不跑统一长门禁、不提交。下一原子前线为 EP-071 `POST /api/v1/triggers`。

## 历史前线（EP-069，批次二十 15/50）

EP-069 `GET /api/v1/flowrun-matrix` 已完成真实 App、受管 Anselm gateway、Computer Use 和五通道验收。Scheduler 矩阵真实呈现 completed、failed、running/awaiting-approval、sparse/not-reached 四类状态；红格可打开精确失败 dossier，等待列可打开 Gantt/approval，Failed/Waiting/All 筛选与矩阵一致，逐帧没有裁切、溢出、跳变、死 spinner 或错误 CTA。

正式固定 session `/private/tmp/anselm-rig-ep069-flowrun-matrix-fixed-20260808/sessions/20260808-041832` 的录屏为 `293.975000s`，最终 backend/frontend/SSE/LLM journal 为 `402/18/18/1`，三路 SSE 均接通，managed gateway wiring 在线，`rig-check` 与 `rig-down` 通过且无 owned process/listener 残留。REST/SQLite 对证了 newest-first、ghost/空结果、重复去重、blank-only `400`、51-ID `422`、running/terminal elapsed 边界和每个 node 状态。

首轮真实清理发现并修复 scheduler rail 不消费 durable `notifications` 的 `workflow.deleted` 生命周期帧，导致 REST 已空时 UI 仍显示已删 workflow；新增 notification refetch 和回归测试，固定 session 真实收敛到 `No automation yet`。签名错误只作为可解释的 fixture failure 保留。证据为固定 session `evidence/EP-069-flowrun-matrix-real-session.md`，ledger re-audit 为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-069-flowrun-matrix-ledger-reaudit.md`；`judge.py` `G1/F2/A5/C4/G2` 使账本 `1030→1035`，COVERAGE `EP-069=✓✓✓✓✓`，anchors `10/10`，两条批量写账警报复审 ack 后 `alarms.py check` clean(1035)。

批次二十当时 **15/50**；下一原子前线为 EP-070 `POST /api/v1/flowruns/{id}/approvals/{node}:decide`。

## 历史前线（EP-068，批次二十 10/50）

EP-068 `GET /api/v1/flowrun-stats` 已完成五级验收。真实用户在 Scheduler Overview 看到 Running/Waiting/Failed/Next fire，构造真实 cron 停机跨刻度后看到 Missed KPI 与 schedule lane 的 `2 missed`，打开 workflow 详情看到真实 cron runs、矩阵、成功率和平均耗时。REST 覆盖 workspace totals、byWorkflow 顺序与 ghost、future/倒挂窗口、recent clamp、ID cap、坏时间和 missed；SQLite 保留 `2 missed + 3 started` firing 与 run/node 审计，三路 SSE 和 frontend/backend/LLM journal 无应用红线。

正式 session `/private/tmp/anselm-rig-ep068-flowrun-stats-fixed-20260808/sessions/20260808-035335`，证据 `/private/tmp/anselm-rig-ep068-flowrun-stats-fixed-20260808/sessions/20260808-035335/evidence/EP-068-flowrun-stats-real-session.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-068-flowrun-stats-ledger-reaudit.md`；账本 `1025→1030`，COVERAGE `EP-068=✓✓✓✓✓`，anchors `10/10`，`alarms.py check`=`clean (1030)`，阈值/算法未改。targeted scheduler unit/black-box 均绿，授权 cleanup `204×6→404×6`，tombstone 和审计保留。批次二十当前 **10/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-069 `GET /api/v1/flowrun-matrix`。

## 历史前线（EP-067，批次二十 5/50）

EP-067 `GET /api/v1/flowrun-inbox` 已完成五级验收。真实用户在 Scheduler 与通知托盘都能发现 parked approval，看到流程名、`Awaiting approval`、`human`、渲染问题、`1h left` 和 Approve/Reject；Approve、带理由 Reject、非法 decision、未知字段和重复决策均有正确的真实结果，决策后 UI 立即回到 `No approvals waiting on you.` / `Nothing is running right now.`，无死卡或旧 CTA。

正式 session `/private/tmp/anselm-rig-ep067-flowrun-inbox-20260808/sessions/20260808-033401` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journals、三路 SSE witness 和 LLM tap；录屏 `205.191667s / 2784x1808 / 60fps`。首轮 session 抓到 approval capsule 在异步长问题进入时真实 `RenderFlex overflowed by 18 pixels`，已直接修复为重新测量问题高度并用内容级溢出保护，补回归后最终 session clean。

REST/SQLite/SSE/UI 对证：`fr_30b3f4d1e090ee0d` 经真实 App Approve 为 `completed/decision=yes`；`fr_68dae31075077ccd` 经通知托盘填写理由并 Reject 为 `completed/decision=no`；`fr_86ea343f844bfb69` 的 `maybe`=`422 FLOWRUN_INVALID_DECISION`、未知字段=`400 INVALID_REQUEST` 且两次拒绝不消费 parked 行，随后正常决策收口；重复决策=`422`。最终 inbox=`{parked:[]}`，三条 run 各一个 terminal。entities durable `1..6`、notifications `1..3` 连续，三流均连接，deterministic graph 不伪造 LLM completion。

正式证据 `/private/tmp/anselm-rig-ep067-flowrun-inbox-20260808/sessions/20260808-033401/evidence/EP-067-flowrun-inbox-real-session.md`，ledger re-audit `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-067-flowrun-inbox-ledger-reaudit.md`；账本 `1020→1025 judgments`，COVERAGE `EP-067=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1025)，三曲线阈值和算法未改。cleanup 为 workflow/approval `204×2→404×2`，tombstone/version/run/node 保留、relations=0、seeded entities 未动。`gen_coverage.py --check`=`848/199/0`，targeted Flutter `81` 项和 `flutter analyze` 全绿。

批次二十当前 **5/50**，未到第 50 格不跑统一长门禁、不提交；下一原子前线为 EP-068 `GET /api/v1/flowrun-stats`。

## 历史前线（EP-065，批次十九 45/50）

EP-065 `POST /api/v1/flowruns/{id}:replay` 已完成五级验收。真实用户在 Scheduler 打开失败 run，查看失败节点和 traceback，确认 `Re-runs 1 failed nodes · reuses 2 completed results.`，然后在同一 dossier 中看到 `Replay #1`、四节点 completed、finish 输出和 Overview 的 `Failed · 24h 0`；完成 run 再次 replay 返回 `422 FLOWRUN_NOT_REPLAYABLE`，没有第二次 mutation。

正式 session `/private/tmp/anselm-rig-ep065-flowrun-replay-fixed-20260808/sessions/20260808-021122` 由同一 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journals、三路 SSE witness、真实 gateway LLM tap；录屏 `147.960000s / 2784x1808 / 60fps`。真实 webhook graph 为 `webhook → function → flaky handler → finish function`，capability-check clean。早先 test-only `trg_manual` 探索因悬空引用被排除，不计绿。

REST/SQLite/UI 对证：`POST /flowruns`=`201`，直接 replay=`202`，同 run `replayCount=1`、`flaky.n=2`、`finish.final=2`、四节点完成；第二次 replay=`422 FLOWRUN_NOT_REPLAYABLE`。每个 run 的 stable/finish 只执行一次，flaky 为一次 failed 加一次 replay success，completed nodes 被复用。backend/frontend/SSE/LLM journals 为 `296/18/48/10`，notifications `16..32`、entities `7..18` 单调，gateway challenge/install/models 全 200，无应用级未解释红线；失败 dossier、确认框、成功 inspector 和 Overview 逐帧无视觉缺陷。

正式证据 `/private/tmp/anselm-rig-ep065-flowrun-replay-fixed-20260808/sessions/20260808-021122/evidence/EP-065-flowrun-replay-final-green.md`，API probe 同目录 `EP-065-flowrun-replay-api-probes.md`，cleanup `/private/tmp/anselm-rig-ep065-cleanup-fixed-20260808/sessions/20260808-021437/evidence/EP-065-flowrun-replay-cleanup.md`。账本 `1010→1015 judgments` 按 `G1/F2/A5/C4/G2` 写入，COVERAGE `EP-065=✓✓✓✓✓`，anchors `10/10`；两条统计警报按原阈值独立复审并 ack，`alarms.py check` clean(1015)，`gen_coverage.py --check`=`848/197/0`。按授权 cleanup `204×5→404×5`，tombstone/version/run/node/execution 审计保留、relations=0、seeded entities 未动。批次十九当前 **45/50**，未到 50 格不跑统一长门禁、不提交；下一前线 EP-066 `POST /api/v1/flowruns/{id}:cancel`。

## 历史前线快照（EP-064，批次十九 40/50）

EP-064 `GET /api/v1/flowruns/{id}/activity` 已完成五级验收。真实用户在 Scheduler 打开完成 run，看到 function、handler、agent、MCP 四类真实执行组成的 Gantt，逐节点查看 output、排队/执行时长和 execution log；activity API 四表聚合、keyset 分页、空 run 和错误边界与 UI/SQLite 一致。

最终 session `/private/tmp/anselm-rig-ep064-flowrun-activity-20260808b/sessions/20260808-014240` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路独立 SSE witness、真实 gateway LLM tap；录屏 `475.320000s / 2784x1808`，绑定窗口 id `26407`。真实 run `fr_c322e8cac2176f65` 返回 `function 29ms → handler 0ms → agent 9707ms → mcp 3ms` 四行，全部 `ok` 且 `readyAt ≤ startedAt`；`limit=2` 两页无重无漏，trigger-only run 返回空数组，坏 cursor/zero limit/ghost run 分别为 `MALFORMED_CURSOR`/`INVALID_REQUEST`/`FLOWRUN_NOT_FOUND`。SQLite 对证 `flowrun_nodes=5` 与四张执行表各 1 行。

真实画面显示 `Done`、`9.8s`、`queued 0ms`、`ran 9.7s`、`v3 · pinned version`、`5 nodes · Completed 5`；Gantt 长 agent 条比例诚实，agent/MCP Inspector 均有 output 与 execution log ID。五通道 journal：backend 623 行、frontend 17 行、SSE 118 行、LLM 16 行；entities durable 到 14、notifications 到 22，真实 gateway `/v1/chat/completions` 200，前后端无未解释应用红线，`rig-check` 和 `rig-down` 通过。

本格没有产品源代码修复；清理第一命令只因 zsh 变量错误请求 `/api/v1/` 并全部 404，逐条绝对 URL 重跑后 DELETE `204×4`、exact GET `404×4`，属于台架命令错误，不计产品红。正式证据 `/private/tmp/anselm-rig-ep064-flowrun-activity-20260808b/sessions/20260808-014240/evidence/EP-064-flowrun-activity-real-session.md`，cleanup `/private/tmp/anselm-rig-ep064-cleanup-20260808/sessions/20260808-015120/evidence/EP-064-flowrun-activity-cleanup.md`；真实 run/审计保留，seeded entities 未动，relations=0。

正式账本 `1005→1010 judgments`，五级 `G1/F2/A5/C4/G2`，COVERAGE `EP-064=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1010)，清册 `848 rows / 196 carried / 0 tombstones`；gap-too-fast/discovery-collapse 按本格独立复核 ack，阈值和算法不变。批次十九当前 **40/50**，未到 50 格不跑统一长门禁、不提交；下一前线 EP-065 `POST /api/v1/flowruns/{id}:replay`。

## 历史前线快照（EP-063，批次十九 35/50）

EP-063 `GET /api/v1/flowruns/{id}` 已完成五级验收。真实用户从 Scheduler 进入完成 run inspector，看到 Manual/Done、pinned version、`26 nodes · Completed 26`，首屏受界限显示部分节点，点击 `Show remaining 14` 后展开全部 26 个节点，再点击 node25 查看 output `{"ok":true}` 和 Completed execution log；没有重复、截断、死 loading 或无界倾倒。

最终 session `/private/tmp/anselm-rig-ep063-flowrun-get-20260808/sessions/20260808-012500` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路独立 SSE witness、真实 gateway LLM tap；录屏 `438.676667s / 2784x1808`，绑定窗口 id `26377`。API `limit=10` 三页为 `10+10+6`，节点 `node25..node16`、`node15..node06`、`node05..node01,start` 严格 newest-first、无重叠，三页 header 同一 run；unknown run、坏 cursor、`limit=0`、`limit=51` 和 cross-workspace lookup 均按契约处理。REST/SQLite/UI 一致，26 nodes/25 executions 全部 completed。

五通道证据：backend 590 行、frontend 18 行、SSE 124 行、LLM 16 行；entities durable `7..60`、notifications `16..19` 分 stream 连续单调，frontend/backend 无应用级未解释红线，受管网关 challenge/install/models 全 200，deterministic function workflow 不伪造 completion。`rig-check` 五通道全绿，`rig-down` 无残留；正式证据 `/private/tmp/anselm-rig-ep063-flowrun-get-20260808/sessions/20260808-012500/evidence/EP-063-flowrun-get-real-session.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-063-flowrun-get-ledger-reaudit.md`。

正式账本 `1000→1005 judgments`，五级 `G1/F2/A5/C4/G2`，COVERAGE `EP-063=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1005)；集中写账的 gap-too-fast 已独立复审 ack，阈值和算法不变，清册 `848 rows / 195 carried / 0 tombstones`。按用户授权 cleanup `/private/tmp/anselm-rig-ep063-cleanup-20260808/sessions/20260808-013308` 删除 workflow/function/隔离 workspace，DELETE `204×3`、精确 GET `404×3`，主 workspace 保留，SQLite 保留 run/node/execution/version 审计且 relations=0。批次十九当前 **35/50**，未到 50 格不跑统一长门禁、不提交；下一前线 EP-064 `GET /api/v1/flowruns/{id}/activity`。

## 历史前线快照（EP-062，批次十九 30/50）

EP-062 `POST /api/v1/flowruns` 已完成五级验收。真实用户从 `Entities → ep062-manual-run` 进入 workflow debugger，点击 `Trigger` 后看到 `Done`、`Completed 2`、`107ms` 和 `accepted: true / source: ui`，再由 `Open run →` 到 Scheduler inspector 查看 Manual origin、queued/ran timing、pinned version 和 execution log。API 侧单 trigger、multi trigger 显式 `entryNode=t2`、unknown/malformed/invalid entry 负路径均与 handler 契约一致。

最终 session `/private/tmp/anselm-rig-ep062-flowrun-start-20260808/sessions/20260808-005702` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路 SSE witness、真实 gateway LLM tap；录屏 `1293.626667s / 2784x1808 / 60fps`。REST/SQLite/SSE/UI 交叉证明 `fr_0f741423bace74b4`、`fr_764f18dec3c769b1`、`fr_d7ea4365f1097af6`、`fr_8e32ab2d25642afb` 的状态、节点、输出和版本 pin 一致；负矩阵明确返回 `FLOWRUN_INVALID_ENTRY`、`INVALID_REQUEST`、`WORKFLOW_NOT_FOUND`，不创建幽灵 run。

五通道证据：backend 1582 行、frontend 20 行、SSE 87 行/55 durable frame、LLM 10 行；真实 UI run 的 entities durable seq `37/39/40` 为 `run_started/function close/run_terminal(completed)`，frontend/backend 无未解释应用红线，managed gateway challenge/install/models 全 200。最终帧、AX 树、API probe、session evidence 和 cleanup proof 均已封存；首轮 shell fixture SyntaxError 与 AX set_value 限制已明确分类为构造/仪器问题，不计产品缺陷。

正式账本 `995→1000`，五级 `G1/F2/A5/C4/G2`，COVERAGE `EP-062=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(1000)，清册 `848 rows / 194 carried / 0 tombstones`。集中写账触发的 `gap-too-fast` 已独立复审 ack，阈值和算法不变。按用户授权的独立 cleanup `/private/tmp/anselm-rig-ep062-cleanup-20260808/sessions/20260808-011934` 已删除 2 workflow、1 function，DELETE `204×3`、exact GET `404×3`、live workflow list 空；SQLite 保留 tombstone、3 versions、8 flowruns、8 function executions，relations=0，seeded 数据未动。批次十九当前 **30/50**，未到 50 不跑统一长门禁、不提交；下一前线 EP-063 `GET /api/v1/flowruns/{id}`。

## 历史前线快照（EP-061，批次十九 25/50）

EP-061 `GET /api/v1/flowruns` 已完成五级验收。Workflow detail 的 Runs cockpit 真实走 keyset `20→28`；Scheduler 真实走 offset `29` 行、1/2/3 页及 Manual/Webhook 来源筛选；失败 workflow、Waiting approval、Running 和 Cancelled inspector 均可达且状态、traceback、Replay/Cancel/approval CTA 与 REST 一致。

最终 session `/private/tmp/anselm-rig-ep061-flowruns-20260808/sessions/20260808-003250` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路 SSE witness、真实 gateway LLM tap；录屏 `630.583333s / 2784x1808 / 60fps`。API/SQLite 证明 cursor/offset 无重叠且顺序一致，半开时间窗、非法筛选、未知复合筛选和 completed/failed/running/cancelled 桶均正确；工作区 fixture 最终 34 条 flowrun 为 `30 completed / 2 failed / 2 cancelled`，主 workflow 29 条完成历史。

五通道证据：backend 915 行、frontend 17 行、SSE 111 行/107 frame、LLM 10 行；notifications `16..37`、entities `7..77` durable seq 单调，受管网关 challenge/install/models 全 200，无虚构 completion；frontend/backend 无未解释应用红线，`rig-check` 和 `rig-down` 通过。正式证据、API probe、SSE summary 和 final frame 均在 session evidence 中，账本复审为 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-061-flowruns-ledger-reaudit.md`。

正式账本 `990→995`，五级 `G1/F2/A5/C4/G2`，COVERAGE `EP-061=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(995)，清册 `848 rows / 193 carried / 0 tombstones`。`gap-too-fast` 仅按独立复审 ack，阈值和算法不变；本格没有产品源代码修复，针对性 Go/Flutter、coverage 和 diff 检查通过。按用户授权的独立 cleanup `/private/tmp/anselm-rig-ep061-cleanup-20260808/sessions/20260808-004956` 已删除 5 workflow、5 trigger、1 approval、1 function，全部 `204→404`，live lists 空，relations=0，34 flowruns/8 versions/4 firings 保留，seeded 数据未动。批次十九当前 **25/50**，未到 50 不跑统一长门禁、不提交；下一前线 EP-062。

## 历史前线快照（EP-060，批次十九 20/50）

EP-060 `GET /api/v1/workflows/{id}/versions/{version}` 已完成五级验收。首轮真实 session
`/private/tmp/anselm-rig-ep060-workflow-version-20260808/sessions/20260808-001344` 发现并保留真实跨父泄漏：A 的 opaque version ID 放到 B 的 URL 仍返回 A 的 graph。修复新增父级 `(workflow_id,id)` 查询，保持 scheduler 的全局 pinned 读取不变，并补 store/app/handler regression。

固定 session `/private/tmp/anselm-rig-ep060-workflow-version-fixed-20260808/sessions/20260808-001940`
由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路 SSE
witness、真实 gateway LLM tap。真实 App 在 `Entities → Workflow → Versions` 显示 v2 展开、v1→v2
diff、完整 trigger graph，最终录屏 `106.916667s / 2784x1808 / 60fps`；backend/frontend 无未解释
红线。REST 证明 A 自有数字/opaque 均 200，B 读取 A opaque、B v2、A 的 0/-1/999/unknown 均
`404 WORKFLOW_VERSION_NOT_FOUND`；SSE notifications durable `16,17,18` 单调，LLM readiness
challenge/install/models 全 200，read-only 路径不虚构 completion；`rig-check`、`rig-down` 通过。

独立 cleanup `/private/tmp/anselm-rig-ep060-cleanup-20260808/sessions/20260808-002310` DELETE
workflow/trigger=`204×4`、后续 GET=`404×4`、live lists 为空；SQLite 保留两条 workflow tombstone、
3 条版本历史、两条 trigger tombstone、fixture relations=0，seeded `演示对话` 未动。正式证据
`.../evidence/EP-060-workflow-version-final-green.md`，账本复审
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-060-workflow-version-ledger-reaudit.md`；
账本 `985→990`，COVERAGE `EP-060=✓✓✓✓✓`，anchors `10/10`，alarms clean(990)，清册
`848 rows / 192 carried / 0 tombstones`。批次十九当前 **20/50**，未到 50 不跑统一长门禁、不提交；
下一原子前线为 EP-061 `GET /api/v1/flowruns`。

## 历史前线快照（EP-059，批次十九 15/50）

EP-059 `GET /api/v1/workflows/{id}/versions` 已完成五级验收。真实用户从 Entities 找到 `ep059-workflow-versions`，进入 Versions tab，首屏看到 v22..v3 与明确的 `Load more`，点击后追加 v2、v1；首行 v22 自动展开，差异、版本号、时间和变更原因可读，追加无重复且完成后无死控件。

真实 session `/private/tmp/anselm-rig-ep059-workflow-versions-20260808/sessions/20260807-235745` 由 conductor 托管真实 Flutter App、Computer Use、窗口录制、frontend/backend journal、三路独立 SSE witness、真实 gateway LLM tap；录像 `251.178333s / 2784x1808 / 60fps`，最终帧显示 v15..v1。fixture workflow `wf_e6a23f5c4c1e6ad0`、trigger `trg_dc40065b733c5085` 通过 21 次真实 `:edit` 形成 v1..v22。

REST/SQLite/SSE/UI 交叉一致：分页页 1 为 `22..3`、页 2 为 `2..1` 严格无重叠；数字和 opaque ID 单读均指向 v22；`limit=0` 为 `400 INVALID_REQUEST`，坏 cursor 为 `400 MALFORMED_CURSOR`；SQLite 保留 22 个版本行；notifications durable seq `16..37` 严格单调无 gap；backend/frontend 无未解释运行期红线；`rig-check`、`rig-down` 全部通过，收台无残留。

正式证据 `/private/tmp/anselm-rig-ep059-workflow-versions-20260808/sessions/20260807-235745/evidence/EP-059-workflow-versions-final-green.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-059-ledger-alarm-reaudit.md`；五级 `G1/F2/A5/C4/G2` 已写入，账本 `980→985`，COVERAGE 为 `EP-059=✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(985)，清册 `848 rows / 191 carried / 0 tombstones`。集中写账触发的 `gap-too-fast` 已独立复审并 ack，阈值和算法未变。

独立 cleanup `/private/tmp/anselm-rig-ep059-cleanup-20260808/sessions/20260808-000634` 已按用户授权软删 workflow/trigger：DELETE `204×2`、GET `404×2`、live lists 为空、22 个版本行和主行 deleted_at 保留、relations=0、seeded `演示对话` 未动。批次十九当前 **15/50**，未满 50 格不跑统一长门禁、不提交；下一前线为 EP-060。

## 历史前线快照（EP-058，批次十九 10/50）

EP-058 `POST /api/v1/workflows/{id}:iterate` 已完成五级验收。真实用户从 Workflow 行选择 `Edit with AI` 后进入持久 AI 编辑对话；模型读取精确 workflow、trigger、relations 和 agent，再用一次 canonical `edit_workflow` 将图从 v1 改到 v2。首轮、fixed2、fixed3 的真实红 session 分别保留了 malformed target/ops、重复 trigger/error 展示和空参 trigger 调用；这些红证据不计绿。最终 fixed4 中第一次 answer 输入失败形成 `Empty answer`，也保留为红观察；重新提交明确请求后 App 最终稳定显示 v2、`entry → summarize` 和三条成功 Activity，无红卡/retry/duplicate mutation。

最终 session `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed4-20260807/sessions/20260807-233816` 由同一 conductor 托管真实 Flutter App、Computer Use、录屏、frontend/backend journal、三路独立 SSE、真实 gateway LLM tap。录屏封口 `571.585000s / 2784x1808 / 60fps`；messages durable `1..94`、entities `7..8`、notifications `16..19` 无 gap；LLM chat responses 全 200，backend/frontend 无未解释应用红线，REST/SQLite 与 UI、tool result、SSE、LLM wire 一致。whitespace request 的 `400 EMPTY_ITERATE_REQUEST` 和 missing workflow 的 `404 WORKFLOW_NOT_FOUND` 均无新 conversation。

正式绿证据 `/private/tmp/anselm-rig-ep058-workflow-iterate-fixed4-20260807/sessions/20260807-233816/evidence/EP-058-workflow-iterate-final-green.md`、ledger/alarm 复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-058-ledger-alarm-reaudit.md` 已封存；账本 `975→980` 按 `G1/F2/A5/C4/G2` 写入五格，COVERAGE EP-058=`✓✓✓✓✓`，anchors 10/10，`alarms.py check` clean(980)，`gen_coverage.py --check` 为 `848 rows / 190 carried / 0 tombstones`。按用户授权的独立无 App cleanup 已删除 conversation/workflow/trigger，DELETE `204×3`、GET `404×3`、版本/消息审计保留、relations=0、seeded 对话未动、收台无残留。批次十九当前 **10/50**，未到 50 格不跑统一长门禁、不提交。下一原子前线为 EP-059 `GET /api/v1/workflows/{id}/versions`。

## 历史前线快照（EP-056，批次十八 50/50）

EP-056 `POST /api/v1/workflows/{id}:revert` 已完成五级验收。真实用户在 Workflow Versions 页面从 v3 依次选择 v2、v1 的 `Set active`，header、绿色 active marker 和历史 diff 均即时一致；版本历史不被删除、不产生 v4，非法 version `999`/`0` 均明确返回 `404 WORKFLOW_VERSION_NOT_FOUND`。

最终 session `/private/tmp/anselm-rig-ep056-workflow-revert-20260807/sessions/20260807-214211` 由 conductor 托管真实 Flutter App、Computer Use、录屏、frontend console、backend、三路独立 SSE、LLM tap 和受管网关。录屏 `338.140000s / 2784x1808 / 60fps`，关键帧和五通道证据已封存；backend `459` 行、frontend `76` 行无未解释应用红线，notifications durable seq `16..20` 单调无 gap，收台后 owned process groups 归零。

正式绿证据 `/private/tmp/anselm-rig-ep056-workflow-revert-20260807/sessions/20260807-214211/evidence/EP-056-workflow-revert-final-green.md`、ledger/alarm 独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-056-workflow-revert-ledger-alarm-reaudit.md` 已封存；账本 `965→970` 按 `G1/F2/A1/C4/G2` 五格，COVERAGE EP-056=`✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(970)，`gen_coverage.py --check` 为 `848 rows / 188 carried / 0 tombstones`。

批次十八 50/50 后统一门禁一次完成：`make verify` 的 backend/frontend/docs/demo 全绿；完整 `go test -count=1 -timeout 20m ./...` 全绿；本批修复场景前端定向回归 `79` 项与 analyze 全绿；`make -C backend testend` 全绿（`testend/scenarios 298.841s`），未放宽阈值。按用户授权的无 App cleanup session `/private/tmp/anselm-rig-ep056-cleanup-20260807/sessions/20260807-220655` 已删除专用 workflow/trigger，版本 history 保留、relations=0、收台无残留。下一原子前线为 EP-057 `POST /api/v1/workflows/{id}:capability-check`。

## 历史前线快照（EP-055，批次十八 45/50）

EP-055 `POST /api/v1/workflows/{id}:edit` 首轮抓到旧 viewport 未 fit 和全屏编辑路由没有 notice host 两个产品缺陷；stop-and-fix 后 pristine viewport 会在结构变更后 fit，用户主动变换的 viewport 保持，结构化 `WORKFLOW_INVALID_GRAPH` 在顶层可见。最终真实 session、REST/SQLite/SSE、前端运行期、ledger/alarm 和 cleanup 证据均已封存；COVERAGE `EP-055=✓✓✓✓✓`，账本 `955→960` 红、`960→965` 绿，批次由 `40/50→45/50`。

## 历史前线快照（EP-053，批次十八 35/50）

EP-053 `POST /api/v1/workflows/{id}:deactivate` 已完成五级验收：真实用户从 Workflow 详情 Activate 后用真实 webhook 把流程停在 approval，在不离开 Runs 面板的情况下 Deactivate；App 明确呈现 `draining`，在途 parked run 不被杀掉，approval 决策完成后自动收口到 `inactive`。停用后的 webhook 返回 404，重复 Deactivate 为 200 且不重复 listener/run/history。首轮无产品缺陷；错误 capability 探针和错误 llmtap 端口 session 均被排除，不进入正式绿证据。

最终 session `/private/tmp/anselm-rig-ep053-workflow-deactivate-20260807/sessions/20260807-200724` 由 conductor 托管真实 Flutter App、Computer Use、录屏、frontend console、backend、三路独立 SSE witness、LLM tap 和受管网关。真实画面 `inactive → active / Listening → webhook park → draining → approval yes → inactive`；录屏 `360.425000s / 2784x1808 / 60fps`，两张关键帧已封存。REST/SQLite 证明最终 workflow inactive、trigger 不监听，保留一条 completed webhook flowrun、两个 completed node、一个 firing、两类 v1 history；关系在清理后为 0。

五通道封口：backend `476` 行无应用红线；frontend `114` 行，其中 96 条已逐条归类为固定 AXTree bridge tooling pattern，未知模式仍 fail-closed；SSE 记录 `active → draining → inactive` 与 `run_started(seq=1) → run_terminal(seq=2,completed)` 并正常 EOF；LLM 仅 readiness，不虚构 completion。正式账本 `940→945`，COVERAGE EP-053=`✓✓✓✓✓`，anchors `10/10`，`alarms.py check` clean(945)，`gen_coverage.py --check` 为 `848 rows / 185 carried / 0 tombstones`。正式绿证据和 ledger/alarm 复审均已写入 `/private/tmp/anselm-rig-formal-20260801-3/evidence/`。

按用户授权，独立无 App cleanup session `/private/tmp/anselm-rig-ep053-final-cleanup-20260807/sessions/20260807-201616` 已删除本格三件专用夹具：DELETE `204×3`、后续 GET `404×3`、flowruns `200`；软删除主行、flowrun/node/firing/version history 保留，关系边为 0，收台后无残留进程。批次十八由 **30/50→35/50**，未到 50 格不跑统一长门禁、不提交；下一原子前线为 EP-054 `POST /api/v1/workflows/{id}:kill`。

## 历史前线快照（EP-050，批次十八 20/50）

**状态修订。** `POST /api/v1/workflows/{id}:trigger` 已在真实 App、Computer Use、受管网关和五通道台架下完成：用户从 Scheduler workflow 详情页发现 `Run now`，空 body 手动执行后得到 toast、绿色 run、Matrix 与详情入口；第二次带 payload 的真实请求在 UI 中汇聚为第二条绿色 Manual run。workflow 保持 inactive，trigger 仍 `never fired`，证明手动执行与监听触发没有混淆；错误 payload 返回 `400 INVALID_REQUEST` 且不创建 run。

正式 session `/private/tmp/anselm-rig-ep050-workflow-trigger-20260807/sessions/20260807-180921` 录屏 `427.206667s / 2784x1808 / 60fps`，backend 549 行、frontend 17 行、LLM ready-only，三路 SSE 全连接并记录 entities durable seq `1..4`，收台无残留。REST/SQLite 交叉证明 `fr_e87daec34cb74b0a` 与 `fr_58e12b1ffac09e2e` 均 completed、manual、pinned v1；payload 在 trigger node result 中原样保留。前端唯一启动阶段 Flutter runner `open returned 1` 已单独记录，不作为运行期错误豁免；未知前端错误仍 fail-closed。

正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-workflow-trigger-final-green.md`，前端运行期复核 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-frontend-runtime-review.md`，警报复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-050-ledger-alarm-reaudit.md`。anchors `10/10` 后按 `G1/F2/A5/C4/G2` 写入 `COVERAGE` 为 `✓✓✓✓✓`，正式账本 `910→915 judgments`；集中写账触发的两条统计警报已独立复审并 ack，阈值与算法未修改，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 182 carried / 0 tombstones`。EP-050 没有源代码修复。批次十八当前 **20/50**，未到 50 格不运行统一长门禁、不提交；下一原子前线为 `EP-051 POST /api/v1/workflows/{id}:stage`。

## 历史前线快照（EP-048，批次十八 10/50）

**状态修订。** `PATCH /api/v1/workflows/{id}` 已在真实 App、Computer Use、受管网关和五通道台架下完成：首轮静态治理卡红证据、第一修复菜单文案截断红证据均保留；
最终 binary 的治理卡下拉完整显示五种策略及短解释，真实选择 `Keep latest` 后 wire 值为 `buffer_one`，详情回读稳定，v1/active version 不变。
REST PATCH/GET 均 200，SQLite 版本数为 1，notifications 收到 durable `workflow.updated`；最终 session
`/private/tmp/anselm-rig-ep048-workflow-patch-fix-20260807/sessions/20260807-173308` 五通道齐全，录屏已封口，收台无残留，frontend/backend 无未解释应用级红线。
正式账本 `900→905 judgments`，COVERAGE `EP-048=✓✓✓✓✓`，anchors `10/10`；两条统计警报经独立复审 ack 后 `alarms.py check clean`，
`gen_coverage.py --check` 为 `848 rows / 180 carried / 0 tombstones`。

批次十八当前 **10/50**。本格运行了 `make gen`、Workflow overview Flutter 11 项回归、目标 Flutter analyze、Workflow app/handler Go tests 与格式/差异检查；
未到 50 格，不运行统一长门禁、不提交。下一原子前线为 `EP-049 DELETE /api/v1/workflows/{id}`。

## 历史前线快照（EP-045，批次十七 45/50；以下旧段为历史快照）

**历史状态修订。** `POST /api/v1/workflows` 已完成真实 Chat → trigger search → 单次 create mutation → inactive workflow 产品路径。
用户输入提交前由 Computer Use AX 核对，最终 workflow 只有一个既有 trigger 节点，description/tags/changeReason、版本和 inactive
状态在 UI、REST、SQLite、SSE 与 LLM wire 上一致；稳定态没有失败卡、retry 或 duplicate trigger。

两轮红场次永久保留且不冒充绿：`/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-152351` 的输入注入丢下划线/标点，
模型随后发不支持的扁平 `nodeId/triggerId`；`.../sessions/20260807-153602` 的输入保真已通过，但模型先发 `nodes`/`edges` graph snapshot，
真实 UI 留下 `create_workflow Failed` 与 `Draft unsaved` 后才自修。stop-and-fix 在边界加入两种精确兼容：trigger shorthand 仅无冲突地
做 `nodeId→node.id`、`triggerId→node.ref` 且限制 `kind=trigger`；精确 `nodes`+`edges` snapshot 只映射已观察的 `type/triggerId→kind/ref`
并展开 add_node/add_edge。未知键、缺数组、冲突、错误 kind 和其它对象仍拒绝；schema、domain、tools 清册与 decoder/Execute 回归一并同步。

最终绿 session `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-154617` 由 conductor 托管真实 Flutter App、Computer Use、
窗口 recorder、frontend console、backend journal、三路独立 SSE、LLM tap 和受管网关；模型先查 `ep045-snapshot-trigger-green`，再一次成功调用
`create_workflow`，无失败/重试。UI 结果表展示 `ep045-snapshot-digest`、描述、三枚 tags、既有 trigger、`Inactive (deactivated)`、v1；Activity
只有 Created。后端 workflow `wf_64daa9eefc827154` 的图为唯一 trigger `trg_f3b9a6e64e4a68e9`，edges 为空；三流有 tool/build/`workflow.created`/
touchpoint，前端无应用级 Dart/Flutter/RenderFlex/Unhandled/overflow 红线，LLM proof/chat 全经 `https://api.anselm.website`，收台无残留。

正式证据见 `/private/tmp/anselm-rig-ep045-workflow-create-20260807/sessions/20260807-154617/evidence/EP-045-workflow-create-final-green.md`，
红证据同目录两份，独立复核见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-045-workflow-create-ledger-reaudit.md`。anchors `10/10` 后按
`G1/F2/A1/C4/G2` 写账，COVERAGE `EP-045=✓✓✓✓✓`，账本 **885→890 judgments**；两条统计警报按复核 ack，阈值算法未改，
`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 177 carried / 0 tombstones`。

批次十七当前 **45/50**；未满 50 格不跑统一长门禁、不提交；机械清册下一原子前线为 `EP-046 GET /api/v1/workflows`。

## 历史前线快照（EP-044，批次十七 40/50）

**状态修订。** `GET /api/v1/agent-executions/{id}` 已完成真实 Agent Logs 单执行详情产品路径：列表保持轻量，用户首次展开
历史行时真实懒取单条详情，能看到版本、provider/model、输入输出、耗时和完整 transcript；详情不会被后续 durable close
重取意外降级成摘要，也不要求再次调用模型。

首个真实红 session `/private/tmp/anselm-rig-ep044-agent-execution-detail-20260807/sessions/20260807-150221` 证明旧实现
只有列表投影：展开后没有 transcript，也没有 `GET /api/v1/agent-executions/{id}`。stop-and-fix 新增 repository 单读、Agent
行首次展开 lazy fetch、共享 transcript hydration 与既有 `BlockTreeView`，并补齐版本/耗时/开始结束时间和已加载详情保留。
红 session 与红证据保留，不计绿。

最终真实绿 session `/private/tmp/anselm-rig-ep044-agent-execution-detail-20260807/sessions/20260807-150928`：Computer Use
从 Agent → Logs → 最新 `manual · ok` 行展开，看到 `agv_96efb03aec9f0423`、`3617ms`、时间字段、`Trace · 2 steps`；点击
Reasoning 后五步 reasoning 完整可读，最终 `1764` text 保持可见。真实 backend journal 记录单条详情 GET `200 / 1159 bytes`，
列表与单读边界清楚；SQLite、REST transcript 与 UI 匹配。

五通道：screen `121.028333s / 2784x1808 / 60fps`；backend 无应用 WARN/ERROR/panic/fatal/4xx/5xx；SSE 三流均连接、正常收台；
frontend 无 Dart/Flutter/RenderFlex/Unhandled/overflow 应用红线，仅保留已知 macOS launcher foreground 噪声；LLM tap 真实连接
`https://api.anselm.website`，本历史读取路径不虚构新的 completion；`rig-check` 通过、`rig-down` 封口且进程归零。正式证据见
`/private/tmp/anselm-rig-ep044-agent-execution-detail-20260807/sessions/20260807-150928/evidence/EP-044-agent-execution-detail-final-green.md`，
独立复核见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-044-agent-execution-detail-ledger-reaudit.md`。anchors `10/10` 后按
`G1/F2/A1/C4/G2` 写入，账本 **880→885 judgments**，COVERAGE `EP-044=✓✓✓✓✓`；两条统计警报经独立复核 ack，阈值与算法未修改，
`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 176 carried / 0 tombstones`。

批次十七当前 **40/50**；未到 50 格，不跑统一长门禁、不提交；机械清册下一原子前线为
`EP-045 POST /api/v1/workflows`。

## 历史前线快照（EP-043，批次十七 35/50）

**历史状态。** `GET /api/v1/agents/{id}/executions` 已完成真实 Agent Logs 产品路径：完整执行历史、aggregates、展开详情、分页和
外部执行实时收口均与右侧运行台一致。首个真实 session 发现未知父 Agent 错误返回 `200` 空历史；修复后重跑又发现已打开 Logs
不跟随外部 18 次执行，右岛为 21 而 Logs 仍为 3。两条红 session 均保留；stop-and-fix 增加父实体预检，以及 Logs 对 durable
`FrameClose` 的去抖 REST 重取、展开行保留、最近可信快照和 load-more 游标竞态保护，并补测试/文档。

最终真实 session `/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-144741`：真实 REST `:invoke` 输入
`number=42` 穿过 `https://api.anselm.website` 后返回 `agx_2bb96a87c0d3ce15` / `ok` / `1764`；已打开 Logs 不刷新即从
`21 Done / 0 Failed` 变为 `22 Done / 0 Failed`，右岛同步 `22 total runs · last ok 3.6s`，最新行置顶、可展开且详情显示真实 ID、输入、
输出、provider/model 和 `Use this input`。REST 页为 `20+2` 无重叠、aggregate `22/22/0`；failed 空筛选、非法 status `422`、未知父 `404`
均诚实。

五通道：screen `183.773333s / 2784x1808 / 60fps`；backend `254` 行无应用红线；SSE 三流均连接，Agent scope 为真实
`open → seq=0 delta → durable close`；frontend `18` 行无 Dart/Flutter/RenderFlex/Unhandled/overflow 应用红线，仅保留 raw journal
中的已知 macOS launcher foreground 噪声；LLM tap proof/chat HTTP 200；`rig-check` 通过、`rig-down` 封口且进程归零。正式证据见
`/private/tmp/anselm-rig-ep043-agent-executions-20260807/sessions/20260807-144741/evidence/EP-043-agent-executions-final-green.md`，
独立复核见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-043-agent-executions-ledger-reaudit.md`。anchors `10/10` 后按
`G1/F2/A1/C4/G2` 写入，账本 **875→880 judgments**，COVERAGE `EP-043=✓✓✓✓✓`；两条统计警报经独立复核 ack，阈值与算法未修改，
`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 175 carried / 0 tombstones`。
批次十七当前 **35/50**，未到 50 格，不跑统一长门禁、不提交；机械清册下一原子前线为
`EP-044 GET /api/v1/agent-executions/{id}`。

## 历史前线快照（EP-042，批次十七 30/50）

**状态修订。** `GET /api/v1/agents/{id}/versions/{version}` 已完成真实 Agent Versions 单版本产品路径：数字版本和
opaque `agv_` 版本 ID 都只能解析到路径中的 Agent，跨父版本和未知父 Agent 均明确 not-found。首个真实负路径发现
opaque ID 走全局查找，另一 Agent 的 v4 与未知父 Agent 错误返回 200；stop-and-fix 增加 parent-scoped repository lookup，
app 先校验父 Agent，数字/opaque 共用边界，并补 store/app 回归测试与 API/domain 文档。红 session
`/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-141645` 保留，不进入绿判。

固定版真实 session `/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-142043`：自有数字/opaque v4、
自有数字 v1 为 200；跨父数字/opaque v4 为 404 `AGENT_VERSION_NOT_FOUND`；未知父数字/opaque 为 404 `AGENT_NOT_FOUND`；
自有未知版本为 404 `AGENT_VERSION_NOT_FOUND`。Computer Use 看到 v4→v3、v3→v2 diff、v1 完整 prompt 和 earliest version，
无裁切、重叠、stale row 或错误归属；SQLite 为 active v4、版本 `[4,3,2,1]`。

五通道封口：screen `129.010000s / 2784x1808 / 60fps`，backend `196` 行无应用红线，frontend `18` 行无 Flutter/Dart/
RenderFlex/Unhandled/overflow/失联红线，SSE 三流连接并正常收台，因只读 GET 无 durable mutation frame；LLM tap 真实绑定
`https://api.anselm.website`，仅记录 ready、不虚构 completion。正式证据见
`/private/tmp/anselm-rig-ep042-agent-version-detail-20260807/sessions/20260807-142043/evidence/EP-042-agent-version-detail-final-green.md`，
独立复核见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-042-agent-version-detail-ledger-reaudit.md`。
anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **870→875 judgments**，COVERAGE `EP-042=✓✓✓✓✓`；统计警报经逐条复核
ack，阈值与算法未修改，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 174 carried / 0 tombstones`。
批次十七当前 **30/50**，未到 50 格，不跑统一长门禁、不提交；机械清册下一原子前线为
`EP-043 GET /api/v1/agents/{id}/executions`。

## 历史前线快照（EP-041，批次十七 25/50）

**历史状态。** `GET /api/v1/agents/{id}/versions` 已完成真实 Agent Versions 产品路径：真实 App 展示 active v4、v3/v2/v1 历史、可展开 diff 和
`v1 · earliest version`，REST 分页 `[4,3]`/`[2,1]`、数字/opaque v4 与 UI/SQLite 严格一致。首个正确接线 session 发现未知父 Agent 被错误返回为
`200` 空历史；已按 stop-and-fix 修复 `ListVersions` 的父实体预检，补回归测试和 API/domain 文档，再以新 binary 重跑得到 `404 AGENT_NOT_FOUND`。
前一条 `8806` 接线错误和修复前红 session 均保留，未进入绿判。

绿 session `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140622`：screen `256.180000s / 2784x1808 / 60fps`，backend `320` 行无应用红线，
frontend `18` 行无 Flutter/Dart/RenderFlex/Unhandled/overflow/失联红线，SSE 三流均连接并正常收台，LLM tap 真实绑定 `https://api.anselm.website`；本只读 GET 不产生
completion 或伪造 durable mutation frame。录屏关键帧、REST 负边界、SQLite `active v4 + [4,3,2,1]` 与原生 Computer Use 树均已在证据文件交叉复核。

正式证据见 `/private/tmp/anselm-rig-ep041-agent-versions-fixed-20260807/sessions/20260807-140622/evidence/EP-041-agent-versions-final-green.md`，独立复核见
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-041-agent-versions-ledger-reaudit.md`。anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **865→870 judgments**，
COVERAGE `EP-041=✓✓✓✓✓`；两条统计警报经独立复核 ack，阈值与算法未修改，`alarms.py check` clean，`gen_coverage.py --check` 为
`848 rows / 173 carried judgments / 0 tombstones`。批次十七当前 **25/50**，未到 50 格，不跑统一长门禁、不提交；机械清册已确认 EP-040 的五级裁决仍有效，
下一原子前线为 `EP-042 GET /api/v1/agents/{id}/versions/{version}`。

## 历史前线快照（EP-039，批次十七 20/50）

**历史状态。** `POST /api/v1/agents/{id}:iterate` 已完成真实 Agent `Edit with AI` 产品路径：真实 App
从 Agent 行菜单创建可识别的 AI 编辑对话，seed 自动命名并读取 v3 配置；用户 follow-up 只产生一次
规范 `edit_agent`，铸造 v4 `agv_1890517a41cdc11b` 并立即 active。Versions 显示可读 `v3 → v4` diff，
mount、inputs/outputs 和其它字段保留；随后 v4 真实 invoke 返回 `{"receipt":"EP039","total":0}`。

空 request 只返回 `400 EMPTY_ITERATE_REQUEST`，未知 Agent 只返回 `404 AGENT_NOT_FOUND`；前后 conversation
数均保持 1，无 v5、retry、部分写入或幻影会话。最终 session
`/private/tmp/anselm-rig-ep039-agent-iterate-20260807/sessions/20260807-134539` 的五通道全部封口：
screen `301.048333s / 2784x1808 / 60fps`；backend `422` 行无应用红线；SSE notifications `1..3`、
messages `1..35`、entities `1..10` 连续无 gap；frontend `20` 行无 Flutter/Dart/RenderFlex/Unhandled/
overflow/失联红线，仅有已审计的 macOS launcher/IMK 平台噪声；LLM tap 真实连接
`https://api.anselm.website`，8 次 completion 响应全 200。UI、REST、SQLite、SSE、wire 和录屏关键帧对 v4、
会话标题和最新 execution `agx_c7ec1079661121` 一致；rig-down 后进程组归零。

正式证据见 `/private/tmp/anselm-rig-ep039-agent-iterate-20260807/sessions/20260807-134539/evidence/EP-039-agent-iterate-final-green.md`，独立复核见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-039-agent-iterate-ledger-reaudit.md`。
anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **860→865 judgments**，COVERAGE `EP-039=✓✓✓✓✓`；
两条统计警报经独立复核 ack，阈值与算法未修改，`alarms.py check` clean，`gen_coverage.py --check` 为
`848 rows / 172 carried judgments / 0 tombstones`。批次十七当前 **20/50**，未到 50 格，不跑统一长门禁、
不提交；机械清册已确认 EP-040 的五级裁决存在且无需重复写账，下一前线为
`EP-041 GET /api/v1/agents/{id}/versions`。

## 历史前线快照（EP-038，批次十七 15/50）

EP-038 的完整证据、五通道事实和批次位置保留在
`README.md §5.2` 的历史快照与 `LOG.md`；COVERAGE 当前行和正式账本均已封口为 `✓✓✓✓✓ / 860 judgments`。

## 历史前线快照（EP-037，批次十七 10/50）

**状态修订。** `POST /api/v1/agents/{id}:revert` 已完成真实 Agent 版本回退路径。真实 App 在 Versions
中展示 v1/v2 diff 和 active 标记；用户先将 v2 回退到 v1，再在 v2 active 下通过受管网关运行
`subtotal=100,tax=10` 得到 `total=110`，最后在结果仍可见时切回 v1。最终右岛清掉旧版本的瞬态
Trace/Result，但保留最新 Recent 审计行；版本历史和 active 指针都可读且一致。

真实负路径对 `version=999` 只发一次 HTTP 请求，返回 `404 AGENT_VERSION_NOT_FOUND`；没有 retry、v3
或指针突变。最终 session `/private/tmp/anselm-rig-ep037-agent-revert-20260807/sessions/20260807-132025`
的录屏、backend、三路 SSE、Flutter console 和受管网关 LLM tap 全部封口：screen `427.071667s / 2784x1808 /
60fps`；backend 546 行无应用红线；notifications durable `1..4`、entities `1..10` 单调；LLM
proof/chat status 全 200；SQLite/REST/UI/SSE/wire 对 `total=110` 和最终 active v1 一致。frontend 的
固定 AXTree 旧节点提示由 session-scoped review 明示为观察器噪声，三秒静置不增长，未知 AX 或 Flutter
runtime 错误仍硬失败；rig-down 后进程组归零。

正式证据见 `/private/tmp/anselm-rig-ep037-agent-revert-20260807/sessions/20260807-132025/evidence/EP-037-agent-revert-final-green.md`，独立复审见 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-037-agent-revert-ledger-reaudit.md`。
anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **850→855 judgments**，COVERAGE `EP-037=✓✓✓✓✓`；
两条统计警报经独立复审 ack，阈值未放宽，`alarms.py check` clean，`gen_coverage.py --check` 为
`848 rows / 170 carried judgments / 0 tombstones`。批次十七历史位置 **10/50**；下一原子已由 EP-038 接续。

## 历史前线快照（EP-036，批次十七 5/50）

**状态修订。** `POST /api/v1/agents/{id}:invoke` 已完成真实 Agent 调用路径。真实用户从 Agent 详情
点击 Invoke 后立即看到 `Cancel`/`Waiting for output...`，本地 UI 示例正常完成；随后在旧结果仍可见时
从 REST 发起 `subtotal=400,tax=60` 的独立调用，右岛切换为新的 observed run，trace、Result 与
Recent 均显示同一笔 `total=460`，不再混入旧 `total=0`。

首轮真实路径发现 stale-result 产品缺陷，已在前端执行面板加入 durable close 后账本重取和 settled
面板的顶层 observed-run reset，并补 controller 测试与实体文档。最终 session
`/private/tmp/anselm-rig-ep036-agent-invoke-20260807/sessions/20260807-131105` 的录屏、backend、
三路 SSE、Flutter console 和受管网关 LLM tap 全部封口：screen `177.275000s / 2784x1808 / 60fps`；
backend 240 行无应用级红线；frontend 17 行无 Flutter/Dart/RenderFlex/Unhandled；entities durable
seq `11..20` 单调；LLM `400/60` 请求与 `460` 响应均为 200；SQLite 最新 execution `ok / 460 / 8432ms`。
UI/REST/SQLite/SSE/wire 一致，rig-down 后进程组归零。正式证据见
`/private/tmp/anselm-rig-ep036-agent-invoke-20260807/sessions/20260807-131105/evidence/EP-036-agent-invoke-final-green.md`，独立复审见
`/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-036-agent-invoke-ledger-reaudit.md`。

anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **845→850 judgments**，COVERAGE `EP-036=✓✓✓✓✓`；
两条统计警报经独立复审 ack，阈值未放宽，`alarms.py check` clean，`gen_coverage.py --check` 为
`848 rows / 169 carried judgments / 0 tombstones`。批次十七当前 **5/50**，未到 50 格，不跑统一长门禁、
不提交；下一前线为 `EP-037 POST /api/v1/agents/{id}:revert`。并发外部调用撞在另一本地飞行中的边界
未由本格声称覆盖。

## 历史前线快照（EP-035，批次十六 50/50，统一门禁已通过）

**状态修订。** `DELETE /api/v1/agents/{id}` 已完成真实 Agent 删除路径：More actions → 明确不可逆确认 → DELETE=204；目标从 active catalog 和 rail 消失，选区回到 Overview，关系边清空，版本审计保留，重复删除无第二次副作用。

真实 session `/private/tmp/anselm-rig-ep035-agent-delete-20260807/sessions/20260807-114742` 由 conductor 托管真实 App、Computer Use、窗口录屏、frontend console、backend、三路 SSE witness 和受管网关 tap。删除前 Agent `ag_4e200525b2c3d63a` 有一条 equip 边；最终画面 Agent=46、目标行消失、无 stale detail/blank pane、关系图 0/0。Cancel-only preflight 和错误 tap 归属的失败尝试均保持在独立 session，不冒充绿证据。

逐帧复核保留删除后的标准 `AnCountUp` 首次揭示：右岛约 0.5 秒从 0 到 46，rail 权威徽标已经是 46，最终卡片、REST、SQLite 一致；中间帧和前端 AXTree session review 见正式 session evidence。五通道封口为录屏 `325.161667s / 2784x1808 / 60fps`、backend `411` 行无应用红线、SSE 三流连接且 notifications seq 1 `agent.deleted` 无 gap、frontend `26` 行仅两条已复核标准 AXTree 观测器噪声、LLM tap ready-only（确定性删除不虚构 completion），收台无残留。

正式绿证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-035-agent-delete-final-green.md`；独立账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-035-agent-delete-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入 **EP-035=✓✓✓✓✓**，账本 **840→845 judgments**，集中写账两条统计警报经独立复审 ack 且阈值未放宽，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 168 carried judgments / 0 tombstones`。

批次十六已 **50/50**。统一门禁已通过：根目录 `make verify` 全绿（含 backend 完整 `go test ./...`、frontend、docs、demo），完整 testend `mise exec -- go test -count=1 -timeout 20m ./...` 全绿，`make -C backend testend` 全绿；后端 Agent/实体专项、Flutter 实体专项、gofmt、diff、coverage、alarms 均通过，验收台架进程组归零。工作树审计通过，本批次代码、测试与工作记录一并提交固化；下一原子前线为 `EP-036`。

## 历史前线快照（EP-032，批次十六 30/50）

**状态修订。** EP-032 `GET /api/v1/agents` 已完成真实 Agent 列表路径。首轮真实 App `/private/tmp/anselm-rig-ep032-agent-list-input-20260806/sessions/20260806-162636` 抓到 rail/Overview 首屏显示 40、翻页后变 45 的真实总数缺陷；stop-and-fix 增加不改变 N4 body 的 `X-Anselm-Total-Count`，前端 rail/Overview 消费精确 header，并让 durable lifecycle 总数刷新不落后于 DB。中间 session 因复用受管 key 旁路旧 tap 被 D1/channel-5 门禁拒绿；最终 `/private/tmp/anselm-rig-ep032-agent-list-count-fixed-20260806/sessions/20260806-165306` 由最新 binary、真实 App、Computer Use、录屏、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关重跑通过。

最终真实 UI 首屏 45，真实 alpha 搜索 2，五次 Backspace 恢复 45，滚动三页后仍 45；REST 为 20/20/5、45 唯一项、无 overlap，header total `45/2/1/0`，N4 body 无 `total`；SQLite live count 45。录屏 `72.431667s / 2784x1808 / 60fps`，backend 162 行、frontend 19 行、SSE 8 行、LLM witness 1 行，应用红线扫描干净，收台无残留。

正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-032-agent-list-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-032-agent-list-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **820→825 judgments**，COVERAGE `EP-032=✓✓✓✓✓`，两条统计警报按独立复审 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 164 carried judgments / 0 tombstones`。批次十六由 **25→30 / 50**，未满 50 格，不运行统一长门禁、不提交，下一原子前线为 `EP-033 GET /api/v1/agents/{id}`。

## 历史前线快照（EP-031，批次十六 25/50）

**状态修订。** EP-031 `POST /api/v1/agents` 已完成真实 Agent 创建路径。首轮真实 App session `/private/tmp/anselm-rig-ep031-agent-create-20260806/sessions/20260806-154305` 发现 hosted model 将 `tags` 发成 JSON 数组字符串，旧执行边界拒绝并显示真实失败卡；中间修复 session `/private/tmp/anselm-rig-ep031-agent-create-fixed-20260806/sessions/20260806-155712` 又发现流式脱敏孤立 `)`，两轮红证据均保留。stop-and-fix 加入窄 tags 兼容、ID-labelled parenthetical 流式保持和回归测试。

固定 session `/private/tmp/anselm-rig-ep031-agent-create-final-20260806/sessions/20260806-160242` 重跑通过：首次 create 返回 `ag_e093c9019b049a4e` v1，最终文案不含 opaque ID、placeholder 或孤立标点；Computer Use 看到 Created agent 卡、完整 prompt/description/tags、Viewed agent 活动和稳定的 Activity 右岛。模型追加一次安全 `get_agent` 读取，无第二次 create；该行为已在正式证据中明示。

正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-031-agent-create-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-031-agent-create-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入，账本 **815→820 judgments**，COVERAGE `EP-031=✓✓✓✓✓`，两条统计警报按独立复审 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 163 carried judgments / 0 tombstones`。批次十六由 **20→25 / 50**，未满 50 格，不运行统一长门禁、不提交，下一原子前线为 `EP-032 GET /api/v1/agents`。

## 历史前线快照（EP-030，批次十六 20/50）

EP-030 的 Handler Logs 单调用详情红绿证据、五级账本与独立复审仍保留在 README §5.2 和正式 evidence 中；以上 EP-031 状态为当前恢复真相。

## 历史前线快照（EP-029，批次十六 15/50）

EP-029 的 `data.calls=null` 红证据、`response.Paged` 修复、最终五通道 session、五级账本和独立复审均保留在 README §5.2 与正式证据中；以上 EP-030 状态为当前恢复真相。

## 历史前线快照（EP-028，批次十六 10/50）

EP-028 的重复 `handler.config_cleared` 红证据、changed 保护修复、最终五通道 session 和 `800→805` 五级账本均保留在 README §5.2 与正式证据中；以上 EP-029 状态为当前恢复真相。

## 历史前线快照（EP-027，批次十六 5/50）

**状态修订。** EP-027 `PUT /api/v1/handlers/{id}/config` 已完成真实 JSON Merge Patch、实例重启、敏感键保留、可选键删除/默认值回落，以及真实 Chat `update_handler_config` 产品路径。固定 session `/private/tmp/anselm-rig-ep027-handler-config-20260806/sessions/20260806-142114` 由 conductor 托管真实 App、Computer Use、录屏、frontend console、backend journal、三路独立 SSE witness、LLM tap 和受管网关；录屏 `583.983333s / 2784x1808`，backend `598` 行，无应用 panic/fatal/WARN/ERROR；messages/entities/notifications durable 序列为 `1..66`、`7..8`、`16..30` 且单调，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，LLM 严格回合只出现 `update_handler_config`。REST 与 SQLite 证明 `prefix=delta`、`prefix=null` 回落 `default-prefix` 且 `secret_seen=true`，GET 始终只显示 `api_key=********`；App 画面显示 schema、配置活动和最终结果，无 secret 泄漏、裁切、重叠或视觉跳变。

正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-027-handler-config-update-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-027-handler-config-update-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，账本 **795→800 judgments**，COVERAGE `EP-027=✓✓✓✓✓`，alarms clean。早期 `...dball` 是台架 URL 构造错误，探索性 Chat 的额外 `state()` 也已由严格重跑隔离；两者均保留在证据而未冒充绿路径。`gen_coverage.py --check` 应为 `848 rows / 159 carried judgments / 0 tombstones`。批次十六由 **0→5 / 50**，未满 50 格不运行统一长门禁、不提交；下一原子前线为 `EP-028 DELETE /api/v1/handlers/{id}/config`。

## 历史前线快照（EP-026，批次十五 50/50）

**状态修订。** EP-026 `GET /api/v1/handlers/{id}/config` 已完成真实配置、未配置、敏感值掩码和未知 Handler 边界。固定 session `/private/tmp/anselm-rig-ep026-handler-config-20260806/sessions/20260806-134441` 由 conductor 托管真实 App、Computer Use、录屏、frontend console、backend journal、三路 SSE witness、LLM tap 和受管网关；配置 Handler 返回 `200`/`ready`/`api_key=********`，未配置 Handler 返回 `200`/`unconfigured`/`missingConfig=[api_key]`，未知 ID 返回 `404 HANDLER_NOT_FOUND`。App 画面显示 configured 与 unconfigured 的真实状态和 schema，无 secret 泄漏、裁切、重叠或跳变。首次 PUT 探针的 `405` 是测试命令遗漏显式 `-X PUT` 的台架错误，补正后产品 PUT 为 `204`，不计产品红。

录屏 `245.513333s / 2784x1808`；backend 无应用 WARN/ERROR/panic，三路 SSE durable seq 单调，frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，受管网关 challenge/install/models 全 `200`；REST/SQLite/UI/SSE/secret scan 交叉一致，收台无残留。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-026-handler-config-final-green.md`，独立复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-026-handler-config-ledger-reaudit.md`；anchors `10/10` 后按 `G1/F2/A1/C4/G2` 写入五级裁决，账本 **790→795 judgments**，COVERAGE `EP-026=✓✓✓✓✓`，alarms clean，gen coverage 为 `848 rows / 158 carried judgments / 0 tombstones`。批次十五由 45→50，统一长门禁已通过：根目录 `make verify`、`make -C backend testend`（305.314s）、`testend` 全包（359.770s）、Handler 后端专项、实体详情 Flutter `7/7`、gofmt/diff 均通过，testend 进程组归零；批次已提交 `6ffc44bb`。下一原子前线为 EP-027。

## 历史前线快照（EP-025，批次十五 45/50）

**状态修订。** EP-025 `GET /api/v1/handlers/{id}/versions/{version}` 首轮真实路径发现跨父 opaque version ID 泄漏：A 读取 B 的 `hdv_...` 返回 B 的版本。stop-and-fix 增加 parent-scoped repository lookup，使数字版本与 opaque 版本详情都受 URL 中父 Handler 约束，并补 store/app/transport/black-box 回归与 Handler domain 文档。固定 session `/private/tmp/anselm-rig-ep025-handler-version-get-fixed-20260806/sessions/20260806-133348` 用新 binary 真实重跑：A 自有数字/opaque 200，A 读取 B opaque、未知数字和未知 opaque 均为 404 `HANDLER_VERSION_NOT_FOUND`，B 自有 opaque 仍 200；Computer Use 画面显示正确 owner 的 v1/stopped/ready/active/source/change reason 和完整代码，无错归属或视觉跳变。红 session `/private/tmp/anselm-rig-ep025-handler-version-get-20260806/sessions/20260806-132936` 保留；固定录屏 186.876667s/30MB，backend 无 WARN/ERROR/panic，三路 SSE durable seq 单调，frontend 无应用级 Flutter/Dart/RenderFlex/Unhandled 红线，受管网关 bootstrap 全 200。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-025-handler-version-final-green.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-025-handler-version-ledger-reaudit.md`；五级 `G1/F2/A1/C4/G2` 使账本 785→790 judgments，anchors 10/10，统计警报按原阈值独立复审并 ack，alarms.py check clean，gen_coverage.py --check 为 848 rows / 157 carried judgments / 0 tombstones。批次十五由 40→45 / 50，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-026。

## 历史前线快照（EP-024，批次十五 40/50）

EP-024 `GET /api/v1/handlers/{id}/versions` 的 22 版本分页、续页、active/diff/earliest 展开和滚动检查已完成，真实录屏、三路 SSE、backend/frontend、受管网关和 SQLite 证据均已封存；正式账本 780→785，COVERAGE EP-024=✓✓✓✓✓，批次十五由 35→40。以上仅作追溯，当前以前一段 EP-025 状态修订为准。

## 历史前线快照（EP-023，批次十五 35/50）

以下段落仅保留 EP-023 的当时状态，当前恢复以前一段 EP-024 状态修订、README §5.2、LOG 最新条目和 COVERAGE 当前行作为真相。

**状态修订。** EP-023 POST /api/v1/handlers/{id}:iterate 已在真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成 Handler actions → Edit with AI → ask-user → AI edit → v2 完整产品旅程。首轮真实路径暴露 legacy set_methods 被归一为既有 status 的 add_method，后端真实拒绝 method "status" already exists；红 session 与错误卡永久保留。stop-and-fix 使 edit normalization 读取 active method 名称，既有方法用 update_method、新方法才用 add_method，并补单测与 tool description。固定 session /private/tmp/anselm-rig-ep023-handler-iterate-fixed-20260806/sessions/20260806-130116 由 conductor 托管真实 App、窗口录制、frontend console、backend journal、三路 SSE witness 和 LLM tap；最终只发一个 canonical update_method，App 显示 v2、最终说明和 Activity 1 touched，REST/SQLite active 指针为 v2，消息块保留完整工具链。录屏 400.173333s，三路 durable frame 单调且 close 快照与数据库一致，受管网关 challenge/install/models 与 chat completions 全 200，固定路径无应用级 WARN/ERROR/panic 或 Flutter/Dart/RenderFlex/Unhandled 红线；macOS runner/IMK host 噪声已独立隔离。正式证据 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-023-handler-iterate-final-green.md，账本复审 /private/tmp/anselm-rig-formal-20260801-3/evidence/EP-023-handler-iterate-ledger-reaudit.md；五级 G1/F2/A1/C4/G2 使账本 775→780 judgments，anchors 10/10，两个原阈值警报独立复审并 ack，alarms.py check clean，gen_coverage.py --check 为 848 rows / 155 carried judgments / 0 tombstones。批次十五由 30→35 / 50，未满 50 格不跑统一长门禁、不提交；下一原子前线为 EP-024。

## 历史前线快照（EP-022，批次十五 30/50）

以下段落仅保留 EP-022 的当时状态，当前恢复以前一段 EP-023 状态修订、LOG 最新条目和 COVERAGE 当前行作为真相。

**状态修订。** EP-022 `POST /api/v1/handlers/{id}:edit` 已在真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成成功与非法 method 编辑路径。`hd_f3d9a96f278672d0` 从 v1 `hdv_98ffb76322048024` 开始，真实 App 首次 Call 后显示 `v1 · running`；真实 HTTP `:edit` 用 canonical `update_method` 铸造 v2 `hdv_6ff081d3ae49ebf6`，环境 ready 并重启 resident。App 同步显示 `v2 · running`/`ready`/新代码，旧 v1 结果被清掉而 Recent 保留；随后真实 Call 返回 `{"edited":true,"revision":"v2"}`，Recent 为 2。非法 `does_not_exist` 返回 `422 HANDLER_OP_INVALID` 与具体缺失原因，版本仍只有 v1/v2、active v2、无 v3/副作用。最终 session `/private/tmp/anselm-rig-ep022-handler-edit-20260806/sessions/20260806-123828` 录屏 `191.498333s / 2784x1808 / 60fps`；REST/SQLite 证明两次调用钉住不同 resident instance，三路 SSE 全连接且 durable seq 无 gap，网关 challenge/install/models 全 200，backend/frontend 无未解释应用红线，收台无残留。Flutter 启动器的单条 foreground warning 已在证据中隔离为仪器噪声，未知错误仍 fail-closed。正式证据 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-022-handler-edit-final-green.md`，账本复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-022-handler-edit-ledger-reaudit.md`；五级 `G1/F2/A1/C4/G2` 使账本 **770→775 judgments**，anchors `10/10`，两条警报按原阈值独立复审并 ack，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 154 carried judgments / 0 tombstones`。批次十五由 **25→30 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-023`。

**历史快照（EP-021）。** EP-021 `POST /api/v1/handlers/{id}:revert` 的首轮真实路径暴露 v1 标题下残留 v2 结果的产品真相红线；stop-and-fix 后 active version 变化会清掉瞬时结果并保留 durable Recent。最终真实 session 显示 v1 running/ready、旧结果消失，随后 v1 Call 成功；REST/SQLite、SSE、录屏、五通道和 controller `10/10` 已交叉证明，账本为 770，警报 clean。该段仅供追溯，当前恢复以前述 EP-022 状态为准。

以下 EP-020 及更早状态段仅保留作历史快照，恢复执行以上述状态修订、README §5.2、LOG 最新条目和 COVERAGE 当前行作为真相。

**历史快照（EP-020）。** EP-020 `POST /api/v1/handlers/{id}:restart` 已在最终新构建真实 App、受管 Anselm 网关、Computer Use 和五通道台架下完成成功/失败路径。首轮真实 Call 成功后发现 UI 仍显示 `v1 · stopped`，而 REST/SQLite 已是 `runtimeState=running`；stop-and-fix 在 Handler call 收尾后重新读取 server-owned detail。最终 session `/private/tmp/anselm-rig-ep020-handler-restart-fixed-20260806/sessions/20260806-120431` 显示首次 Call 后 `v1 · running`、`ready`、`Done`，Restart 原地完成且不升版本，第二次 Call 的 Recent 为 2；REST/SQLite 为同一 active version `hdv_b075d14eefb8e00f`、两个真实 resident instance `hdi_51fd8207eeaa0161`/`hdi_da984cee7bc1fdf`、两次成功调用。未配置必填 `token` 的负 Handler 真实 Restart 显示 `restart failed · View`，后端为 `422 HANDLER_CONFIG_INCOMPLETE`，无假实例/假调用。录屏 `200.308333s / 2784x1808 / 60fps`；SSE 成功 durable seq `16`、失败 seq `20..22`，无 gap；backend/frontend/LLM tap 均由同一 manifest 归属，网关 challenge/install/models 全 200，AXTree bridge churn 已作工具噪声复核，应用红线扫描干净，收台无残留。正式证据 `EP-020-handler-restart-green.md`，独立账本复审 `EP-020-handler-restart-ledger-reaudit.md`；定向 controller `9/9` 与目标 analyze 通过，账本 **760→765 judgments**，anchors `10/10`，`alarms.py check` clean，`gen_coverage.py --check` 为 `848 rows / 152 carried judgments / 0 tombstones`。批次十五由 **15→20 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-021`。

以下 EP-019 及更早状态段仅保留作历史快照，恢复执行以上述状态修订、README §5.2、LOG 最新条目和 COVERAGE 当前行作为真相。

**历史快照（EP-019）。** EP-019 已在最终新构建真实 App、受管网关、Computer Use 和五通道台架下完成 Handler `:call` 成功/失败路径。首轮失败先暴露结构化错误 details 被 UI 丢弃，第二轮又暴露 traceback 被 JSON 转义；修复后最终画面显示 `Done`/stdout/结构化结果，失败画面显示 `Failed`/错误码/用户 stdout，并按真实换行显示 `error` 与 Python traceback。最终 session `/private/tmp/anselm-rig-ep019-handler-call-final-20260806/sessions/20260806-114857` 的录屏为 `176.410000s / 2784x1808 / 60fps`；REST/SQLite 为同一 resident、v1、`1 ok/1 failed` 审计，SSE entities open/delta/close 与 backend 200/502 对齐，LLM challenge/install/models 全 200，frontend/backend 无未解释红线，收台无残留进程。正式证据 `EP-019-green.md`，独立警报复审 `/private/tmp/anselm-rig-formal-20260801-3/evidence/EP-019-handler-call-ledger-reaudit.md`；账本 **755→760 judgments**，anchors `10/10`，警报按原阈值复审 ack 后 clean。批次十五由 **10→15 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-020 POST /api/v1/handlers/{id}:restart`。

**状态修订。** EP-018 已在真实 App、受管网关、Computer Use 和五通道台架下完成：取消确认不改变 Handler，确认后 `order_desk` 从活动目录消失、详情回 Overview、计数 `1→0`；HTTP `204→GET 404`，重复 DELETE 为 `HANDLER_NOT_FOUND`，版本历史保留，SQLite `deleted_at` 落真，sandbox env 与关系边清理。录屏 `246.323333s / 2784x1808 / 60fps`，notifications durable `16,17` 连续为 `sandbox.env_deleted`→`handler.deleted`，frontend/backend 无未解释红线；正式证据为 `EP-018-green.md`，警报复审为 `EP-018-ledger-reaudit.md`，正式账本 **750→755 judgments**，anchors `10/10`，`alarms.py check` clean。批次十五当前 **10 / 50**，下一原子前线为 `EP-019 POST /api/v1/handlers/{id}:call`。下方原 EP-017 状态段仅保留作过程快照。

**状态修订。** EP-017 后续发现 description/tags 保存失败误用“名称保存失败”文案，已补齐 `metaSaveFailed` 双语文案并同步 Function/Workflow 同类异常路径。新 binary 的真实 session `/private/tmp/anselm-rig-ep017-handler-patch-20260806/sessions/20260806-111449` 已从空 meta 完成 Computer Use 编辑，最终值为 `rechecked metadata`/`recheck-tag`，录屏 `159.730000s / 2784x1808 / 60fps`，notifications durable `1..3` 无 gap，SQLite 保持单一 v1，resident `bump` 成功，frontend/backend 无未解释应用红线。最终证据为 `EP-017-recheck-green.md`，复审为 `EP-017-recheck-ledger-reaudit.md`；正式账本 **745→750 judgments**，anchors `10/10`，`alarms.py check` clean。批次十五仍为 **5 / 50**，下一原子前线为 `EP-018 DELETE /api/v1/handlers/{id}`。下方原 `当前更新` 长段中的 `745` 与旧 EP-017 证据仅保留作过程快照。

**当前更新。** 第九批 `TOOL-081..090`、第十批 `TOOL-091..100`、第十一批 `TOOL-101..110` 和第十二批 `TOOL-111..120` 均已完成 50/50，并分别提交 `32b33499`、`553fa150`、`de146b72`、`91cdd51c`。`TOOL-121 generate_video`、`TOOL-122 edit_image`、`TOOL-123 animate_image`、`TOOL-124 enroll_voice`、`EP-001 POST /api/v1/functions`、`EP-002 GET /api/v1/functions`、`EP-003 GET /api/v1/functions/{id}`、`EP-004 PATCH /api/v1/functions/{id}`、`EP-005 DELETE /api/v1/functions/{id}`、`EP-006 POST /api/v1/functions/{id}:run`、`EP-007 POST /api/v1/functions/{id}:revert`、`EP-008 POST /api/v1/functions/{id}:edit`、`EP-009 POST /api/v1/functions/{id}:iterate`、`EP-010 GET /api/v1/functions/{id}/versions`、`EP-011 GET /api/v1/functions/{id}/versions/{version}`、`EP-012 GET /api/v1/functions/{id}/executions`、`EP-013 GET /api/v1/function-executions/{id}`、`EP-014 POST /api/v1/handlers`、`EP-015 GET /api/v1/handlers`、`EP-016 GET /api/v1/handlers/{id}` 与 `EP-017 PATCH /api/v1/handlers/{id}` 均已完成五级裁决，正式账本为 **745 judgments**，anchors `10/10`；EP-017 的红绿证据已按原阈值独立复审并 ack，`alarms.py check` clean。批次十三和批次十四均已完成 **50 / 50** 并通过统一长门禁、完整 testend、警报复核和工作树审计；批次十五当前 **5 / 50**，未满 50 格不跑统一长门禁、不提交；下一原子前线为 `EP-018 DELETE /api/v1/handlers/{id}`。

EP-016 的真实 session `/private/tmp/anselm-rig-ep016-handler-get-20260806/sessions/20260806-100548` 验证了 Handler 详情的完整用户目的：Computer Use 画面显示名称、v1、stopped、unconfigured、activeVersion、Python 3.12、必填 sensitive `api_key`、默认 `region`、`ping` 方法和 source；REST/SQLite 证明 configState、runtimeState、missingConfig、schema 与未知 ID 404 一致。封口录像 `292.240000s / 2784x1808 / 60fps`，三路 SSE、backend journal、frontend console、LLM tap 均由同一 manifest 归属，durable entities `7..8`、notifications `16..20` 无 gap；DELETE=204 后 GET=404，env 已回收。正式证据 `EP-016-green.md`，警报复审 `EP-016-alarm-reaudit.md`；账本 **735→740 judgments**，批次十四 **45→50 / 50**。

EP-017 的首轮真实画面冻结为红：Handler Overview 没有可编辑 description，也没有 tags 入口。stop-and-fix 后真实 Computer Use 从空 meta 输入 description 与 tag，Enter 提交、Escape 收束，最终画面显示 canonical meta、`v1 · running`、`ready`；PATCH 不升版本、不重启 resident。REST/SQLite、`handler.updated` SSE durable `1..4`、backend/frontend journal、LLM tap 与 559.990000s 封口录像交叉一致，非法名称 400 和未知 Handler 404 也已验证。正式证据 `EP-017-green.md`，账本 **740→745 judgments**，复审 `EP-017-ledger-reaudit.md`，anchors `10/10`、`alarms.py check clean`；批次十五 **0→5 / 50**，未满批不跑统一长门禁、不提交；下一原子前线为 `EP-018 DELETE /api/v1/handlers/{id}`。

EP-012 的红 session `/private/tmp/anselm-rig-ep012-functions-20260806/sessions/20260806-075245` 暴露 Overview 以最近 5 条推导总数为 `5 today`、Logs 使用 UTC 直出的问题；fixed session `/private/tmp/anselm-rig-ep012-functions-20260806-fixed/sessions/20260806-080821` 通过 `totalCount` 聚合和 `DateTime.toLocal()` 修复后真实显示 22 total、18 Done/4 Failed、本地时间，并完成失败展开与 Load more 22 行。五通道封口、SQLite 22 条执行审计、DELETE=204→GET=404 和证据文件均已保存；单条 logs 的详情懒加载已由 EP-013 完成，不把列表聚合误称为详情交付。

EP-013 的真实 session `/private/tmp/anselm-rig-ep013-functions-20260806/sessions/20260806-082436` 验证了轻列表到完整详情的用户路径：2 条真实执行（1 ok/1 failed），单详情 REST 对成功与失败均返回完整 input/output/error/logs/timing，未知 ID 为 404；Computer Use 在 Logs 面板展开失败行看到 traceback 与 logs，成功行的 accessibility state 也含完整日志。录屏 `346.728333s / 2784x1808` 可读，SSE 三流记录 run/error/delete，LLM proof/install/models 全 200，backend/frontend 无应用红线；DELETE=204 清理后 SQLite 为 `live_functions=0/deleted_functions=2/execution_rows=2`。正式证据 `EP-013-green.md`，复审 `EP-013-ledger-alarm-reaudit.md`；正式账本 **720→725 judgments**，批次十四 **30→35 / 50**，下一原子前线为 `EP-014 POST /api/v1/handlers`。

EP-014 的真实 session `/private/tmp/anselm-rig-ep014-handlers-20260806-compat9/sessions/20260806-093450` 在 stop-and-fix 后完成 Handler 创建：legacy op 形状先由后端有限翻译到 canonical `add_method`，compat8 又发现脱敏 ID 行留下空行导致 Flutter 表格隐藏 `ping` 方法，随后改为物理移除不可用行并补流式/durable 回归，compat9 画面才稳定显示名称、Python 3.12、`ping` 返回 `{pong: true}`、v1 与“未调用该方法”说明。REST 为 `201/400/200`，SQLite 保留版本/env/调用审计，清理为 `DELETE=204 → GET=404`；录屏 `189.793333s` 可读，三流 durable seq 单调无 gap，llmtap 全 200，backend/frontend 无未解释红线。正式证据 `EP-014-green.md`，复审 `EP-014-alarm-reaudit.md`；账本 **725→730 judgments**，批次十四 **35→40 / 50**，下一原子前线为 `EP-015 GET /api/v1/handlers`。

EP-015 的主 session `/private/tmp/anselm-rig-ep015-handlers-20260806/sessions/20260806-094604` 用 44 个真实 Handler 加 seed 行走通了实体 rail 的 `20+20+5` 续页与 45 行边界；真实输入 `ep015-handler-3` 返回 10 条 `39→30`，独立空输入 session `/private/tmp/anselm-rig-ep015-handlers-20260806/sessions/20260806-095453` 显示精确 `No entities match your search.`。REST 交叉核验 cursor/search/empty/`limit=0` 400，清理 44 行 `DELETE=204`、GET=404，SQLite 保留 44 个版本并回收临时 env。录屏均由 conductor 封口且 ffprobe 可读，主 SSE durable entities `7..94`、notifications `16..147` 无 gap，三流均连接，llmtap bootstrap 全 200，backend/frontend 无未解释红线；Computer Use `set_value` 隐藏值串接单列为仪器限制。正式证据 `EP-015-green.md`，空态补证 `EP-015-empty-search.md`，复审 `EP-015-alarm-reaudit.md`；账本 **730→735 judgments**，批次十四 **40→45 / 50**，下一原子前线为 `EP-016 GET /api/v1/handlers/{id}`。

`EP-011` 首轮真实 App 发现 A 读取 B opaque version ID 的跨父泄漏，且代码审查发现显式版本执行同样缺 parent scope；fixed session 通过 parent-scoped repository lookup、真实 Versions 页面、A/B REST 正负边界、显式 A run、SQLite 软删审计和五通道收台完成复验。UI 的 v2 active、真实 change reason、`+1 −1` diff、v1 earliest/full code 均无截断、错归属或跳变；A/B own ID 与数字版本为 200，cross-parent/unknown 为 404，DELETE=204 后 GET=404，录屏 `284.375s / 2784x1808 / 60fps`，SSE durable entities `1..6`、notifications `1..14` 单调，llmtap bootstrap 三个真实 HTTP 200。正式证据 `EP-011-green.md`，警报复审 `EP-011-ledger-alarm-reaudit.md`；账本 **710→715 judgments**，下一原子前线为 `EP-012`。

`EP-007 POST /api/v1/functions/{id}:revert` 的真实 App session `/private/tmp/anselm-rig-ep007-functions-20260806/sessions/20260806-060152` 完成 Versions 面板中的 v2→v1 `Set active` 回退：UI 保留 v1/v2 历史且 active、运行结果均切到 v1；REST 参数执行、非法 v99、SQLite active/version/execution/notification、`function.reverted` SSE durable 帧与 backend journal 对齐。清理 session 真实 DELETE=204、GET=404、live list 为空，soft-delete 与 `function.deleted` 也对齐。三路 SSE、frontend console、LLM tap 与屏幕录像由同一 manifest 归属；Computer Use 参数编辑器绕过回调的输入现象未作为产品绿证据。正式证据与警报复审分别为 `EP-007-function-revert.md`、`EP-007-ledger-alarm-reaudit.md`。

`EP-008 POST /api/v1/functions/{id}:edit` 的 fixed3 session `/private/tmp/anselm-rig-ep008-functions-20260806-fixed3/sessions/20260806-064400` 真实完成 v1→v2 单次编辑，UI/REST/SQLite/SSE/LLM/frontend/backend 五通道一致；最终录屏 174.058333s，三流 durable seq 为 messages `1..42`、entities `1..8`、notifications `1..9`，LLM 20/20 HTTP 200，无错误卡或 opaque placeholder。首轮 Version ID 占位泄漏和 fixed2 畸形 ops 500 均保留为红证据；修复跨 chunk 脱敏与 `ParseOps` 结构化 `422 FUNCTION_OP_INVALID` 后重跑。空 ops 只重建 env、不铸 v3；Function/conversation 已真实清理。正式证据与警报复审分别为 `EP-008-green.md`、`EP-008-ledger-alarm-reaudit.md`；下一原子前线为 `EP-009`。

`EP-009 POST /api/v1/functions/{id}:iterate` 的 fixed3 session `/private/tmp/anselm-rig-ep009-functions-20260806-fixed3/sessions/20260806-070454` 完成真实 Function 的 `Edit with AI` 用户路径。首轮 generic opening/title 红证据保留；stop-and-fix 后固定请求带实体名称，chat rail/header 可识别，助手读取同一 Function 并进入可继续编辑的 composer。空/空白请求、未知 Function、malformed JSON 均在创建 conversation 前拒绝；REST/SQLite、mention/touchpoint、三路 SSE、backend/frontend、LLM wire 和录屏交叉一致。录屏 `408.985000s / 2784x1808 / 60fps`，messages/entities/notifications durable seq `1..18`、`1..2`、`1..8` 单调，LLM 12 个响应全 200，清理 DELETE=204→GET=404。精确已知 AXTree tooling noise 由 session-scoped `frontend-ax-review.md` 解释，`rig-check.sh` 对未知 AX/Dart/Flutter/runtime 错误仍硬失败。正式证据与警报复审分别为 `EP-009-green.md`、`EP-009-ledger-alarm-reaudit.md`；五级裁决使中央账本 **700→705 judgments**，COVERAGE `EP-009=✓✓✓✓✓`，批次十四 **10→15 / 50**，下一原子前线为 `EP-010 GET /api/v1/functions/{id}/versions`。

`EP-010 GET /api/v1/functions/{id}/versions` 在 session `/private/tmp/anselm-rig-ep010-functions-20260806/sessions/20260806-072203` 真实构造 v1→v21 并走完 Versions 页面：首屏 20 条、cursor 续页 v1、active v21、真实 change reason/code diff、v1 earliest 展开；REST/SQLite/SSE/UI 真值一致。`limit=0/abc` 与坏 cursor 的负边界分别返回 `INVALID_REQUEST`/`MALFORMED_CURSOR`；删除后主实体 404、live list 移除，版本历史按审计约定保留。封口录像 `456.258333s / 2784x1808 / 60fps`，三流均连接，entities durable `1..42`、notifications durable `1..85` 单调，delta seq=0，backend/frontend 无未解释红线，llmtap bootstrap 真实 HTTP 200。正式证据 `EP-010-green.md`，警报复审 `EP-010-ledger-alarm-reaudit.md`；五级裁决使中央账本 **705→710 judgments**，批次十四 **15→20 / 50**，下一原子前线为 `EP-011 GET /api/v1/functions/{id}/versions/{version}`。

EP-005 的红线、修复和证据在 `README.md` §5.2 与 formal evidence 中已完整记录：真实实体 rail 删除路径先冻结旧确认文案，再修复为明确不可撤销后重跑；后端 `204`、REST `404`/列表缺席、SQLite soft-delete/version/env/relation 真相、notifications seq `1..2` 与 UI 终态一致。前端只保留两条静态、5 秒不增长的已知 AXTree 观察器噪声；默认账本错路由与正式账本重放均有独立审计。

`EP-006 POST /api/v1/functions/{id}:run` 的最终 session `/private/tmp/anselm-rig-ep006-functions-20260806/sessions/20260806-053154` 已封口 528.990000s。正向 Example → Run 两次成功，UI/REST/SQLite/backend 对齐；负向真实输入 `A` 显示 JSON 校验错误并禁用 Run，点击不产生执行。三路 SSE 在动作前均已连接；ready env 的同步 Function run 按实现不发布实体/消息帧，零帧是预期，未见断连或异常帧。前端仅静态 IMK 系统噪声，LLM tap 仅 ready；临时 fixture 由真实 DELETE=204、GET=404、列表为空清理。正式证据为 `/private/tmp/anselm-rig-ep006-functions-20260806/sessions/20260806-053154/evidence/EP-006-real-app.md`，账本复审为 `EP-006-ledger-alarm-reaudit.md`；该格已随批次十三收口。

API Serve 修复提交 `0d06f6e58615fec2fd04e3c15d16aea2edaf4aef` 已成功通过 CI `31029509745` 与 production deploy `31029785594`，公网 healthz 为 `200`，设备证明边界按契约返回 `401`。真实受管 `/models` 明示 I2V 后才进入 App 轮次；部署成功不替代产品验收。

`EP-002 GET /api/v1/functions` 的最终五通道 session 为 `/private/tmp/anselm-rig-ep002-functions-20260806/sessions/20260806-034541`：真实 App 中用 45 个真实 Function fixture 验证 `20+20+5` 分页、cursor continuation、filtered search、非法/上限 limit 和实体 rail 的 20→40→45 加载；no-match 空白 rail 已 stop-and-fix 为本地化解释。`EP-003 GET /api/v1/functions/{id}` 随后在 session `/private/tmp/anselm-rig-ep003-functions-20260806/sessions/20260806-035647` 完成真实实体详情、active version、代码/接口/环境元数据和 `FUNCTION_NOT_FOUND` 负路径；录屏 `163.976667s`，backend/frontend 无未解释应用红线，三路 SSE durable seq 单调，LLM completed responses 全 HTTP 200。EP-003 正式证据为 `ep-003-function-get-green.md`，账本复审为 `ep-003-ledger-reaudit.md`。下方旧 EP-001 及更早段落均为历史快照，恢复只以上述当前前线、`LOG.md` 和 COVERAGE 为准。

`TOOL-123` 的真实 App session `/private/tmp/anselm-rig-tool123-live-20260806/sessions/20260806-020305` 完成静态图→危险批准→I2V提交/轮询/媒体上传→5秒MP4→播放结束→重播→全屏→退出全屏；首帧 `changedFrac=0.1009`，源图构图保持。647.886667s 屏幕录像、backend、三路 SSE、frontend console、LLM tap 和 `measure compare` 证据齐全，正式证据为 `sessions/20260806-020305/evidence/tool-123-animate-image-formal-20260806.md`。

上一 session `/private/tmp/anselm-rig-tool123-live-20260806/sessions/20260806-015946` 的 AXTree 红证据仍保留；修复后二进制的 loading/error/retry 反馈由 34 项媒体定向测试和 `flutter analyze` 锁定。五级写账后的 `gap-too-fast` 与 `discovery-collapse` 通过独立复审文件 ack，阈值未放宽。一次未 export `RIG_HOME` 的 L1 误写到默认旧账本已留审计并重放到正式根；正式账本才是本战役水位。

`TOOL-124 enroll_voice` 的真实 App session `/private/tmp/anselm-rig-tool124-live-20260806/sessions/20260806-022721` 完成短参考音频生成、有限库存解释、危险登记人闸批准、网关登记、登记音色复用生成、Settings 库存核对和真实删除清理；参考音频 `att_353b3737368b9dbf` 为 157484 bytes/3.280000s，复用音频 `att_e06c667a3db58ac3` 为 169004 bytes/3.520000s，网关句柄与本地音色行 ID 的创建/使用/删除边界一致。587.738333s 录屏、backend/frontend journal、三路 SSE witness、LLM tap、SQLite/REST 证据齐全；messages durable `1..52`、notifications `1..2` 单调，实体流已连接，frontend/backend 无未解释 runtime 红线。英文主路径完成；Computer Use 中文输入丢失被记录为仪器限制，不计产品红线。

TOOL-124 首轮冻结了 Settings 将音色 GET 失败伪装成空库存的问题；修复为明确错误状态与 Retry，补双语文案、fixture failure hook、`voices_card_test.dart` 6/6 和 settings 文档规则。正式五级 `G1/F2/A5/C4/G2` 已写账，中央账本 **655 judgments**，anchors `10/10`，两项统计警报经独立复审后 clean。

`EP-001` 的真实 App 前置红会话发现三条问题：外层 `ops` JSON 字符串化、嵌套 I/O schema 形状不兼容、成功正文把 ID 渲染成 `the requested item`。红证据均保留；修复后正式 session `/private/tmp/anselm-rig-ep001-green3-20260806/sessions/20260806-030648` 只执行一次创建，规范化参数落入 SQLite/SSE，函数 v1 与环境 `ready` 一致，展开工具卡可复制精确 ID，正文无坏占位。五通道录屏 `337.441667s`，三流 durable seq 单调，LLM/HTTP 全 200，frontend/backend 无未解释应用红线，证据与警报复审分别为 `evidence/ep-001-formal-green-provider-shapes.md`、`evidence/ep-001-ledger-alarm-reaudit.md`。正式账本 **655→660**，批次十三 **20→25 / 50**，下一原子前线为 `EP-002 GET /api/v1/functions`。

代码审查随后发现通用 provider 参数归一化的 `argumentRepair` 错误借用了 `get_flowrun` 原因，且 `edit_function` 的畸形 `ops` 只在执行阶段失败；两项均已 stop-and-fix 并补回归。最终代码重跑 session `/private/tmp/anselm-rig-ep001-auditfix-20260806/sessions/20260806-032244` 的真实 provider wire 仍为外层字符串 `ops`，但 durable/SSE 已规范化为四项 native ops，attrs 为 `provider arguments normalized by tool boundary`；函数 v1/env `ready`，真实 `100 °C → 212 °F`，screen.mov `200.358333s` 可读，messages/entities/notifications durable seq 分别 `1..26`、`1..2`、`1..5` 单调，LLM 全 200，backend/frontend 无未解释应用红线。最终证据为 `evidence/ep-001-audit-fix-green.md`，警报复审为 `evidence/ep-001-auditfix-ledger-reaudit.md`；五级重验证使账本 **660→665**，覆盖批次仍 **25 / 50**，下一前线不变。

`TOOL-113` 的首轮正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-220707` 保留了真实 SSE 中间帧的 `lastMessageAt → the recorded time` 红线；修复后 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-221418` 已由新 binary、真实 App、受管 gateway、Computer Use 和五通道台架复验。三次 cursor 调用取回三页，目标 text delta/close、UI、REST/tool result 和五通道一致；录屏 `162.765s / 2784x1808 / 60fps`，frontend/backend 无未解释红线，LLM wire 全 200。正式证据 `evidence/TOOL-113.md`，警报复审 `evidence/tool-113-ledger-alarm-reaudit.md`，anchors 10/10，最终 `alarms.py check` 为 `clean (600 judgments)`。

`TOOL-114` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-222259` 完成当前对话 rename/pin/unpin/archive/自动解档/显式解档以及空标题拒绝；六个 tool-call/result 对与 notifications 状态顺序逐帧一致，空标题没有 retry 或 mutation。录屏 `411.743333s / 2784x1808 / 60fps`，messages `1..96`、notifications `1..6` 单调，三路 SSE 连接，frontend 无 runtime 红线，backend 只有预期 validation WARN，LLM chat response 全 200。正式证据 `evidence/TOOL-114.md`，警报复审 `evidence/tool-114-ledger-alarm-reaudit.md`，anchors 10/10，最终 `alarms.py check` 为 `clean (605 judgments)`。

`TOOL-115` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260804-232754` 完成全量 kind 检索、handler 筛选、无匹配和空 query 四条真实 App 路径；一次调用约束、精确 ref 卡片、自然语言脱敏、字符串化 hosted 参数兼容、明确 validation failure 和无 mutation 均由 SQLite/SSE/UI/LLM/backend/frontend 五通道交叉核对。首轮泄漏和参数形状红证据保留，修复后二次 session 才判绿；录屏 `217.091667s / 2784x1808`，messages `1..42`、notifications `1..6` 单调，frontend 无运行时红线，backend 只有预期空 query WARN，LLM responses 全 200。正式证据 `evidence/TOOL-115.md`，警报复审 `evidence/tool-115-ledger-alarm-reaudit.md`，anchors 10/10，五级 `G1/F2/A5/C4/G2` 已落账，最终 `alarms.py check` 为 `clean (610 judgments)`。

`TOOL-116` 首轮 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-014547` 冻结了真实端点展示泄露 `(fromId: deploy-helper)` 与中间 SSE 裸占位符；stop-and-fix 让关系表识别起点/终点列，并在 delta/close 统一去除机器字段，精确 ref 仅留工具卡与审计面。修复后二次 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-015059` 真实 App 只调用一次 `get_relations`，终帧显示 `技能 deploy-helper → 函数 greet`；assistant-only SSE 禁词扫描为空，五通道与 `rig-check`/`rig-down` 通过，证据 `evidence/TOOL-116.md`，警报复审 `tool-116-ledger-alarm-reaudit.md`，anchors 10/10，最终 `alarms.py check` 为 `clean (615 judgments)`。

`TOOL-117` 正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-020051` 完成 local 正向摘要、local JS shell 降级、loopback 安全拒绝和 Chat 设置切换 Jina 后的动态页面摘要；UI、SQLite、SSE、LLM wire、backend/frontend journal 与 336.700000s 录屏一致。messages durable `1..62`、notifications `1..2` 单调，LLM 28 个 HTTP response 全 200，五通道收台与 anchors 10/10 通过；证据 `evidence/TOOL-117.md`，警报复审 `tool-117-ledger-alarm-reaudit.md`，`alarms.py check` 为 `clean (620 judgments)`。

`TOOL-118` 首轮真实正向路径暴露 managed model 把 `limit` 发成字符串，修复后又由抽帧发现 Markdown 错误代码块横向裁切；两条红线均保留并在新 binary 上 stop-and-fix。正式 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260805-023835` 重跑成功结果与 provider 401 失败：成功一次 WebSearch 返回两条有序结果和 `truncated:true`，失败一次 WebSearch 显示完整 401 且助手代码块自动换行；messages durable `1..40`、notifications `1..4` 单调，LLM body 无 validation retry，backend 仅预期 WARN，frontend 无异常，录屏 `244.275000s / 2784x1808 / 60fps`。证据 `evidence/TOOL-118.md`，警报复审 `tool-118-ledger-alarm-reaudit.md`，anchors `10/10`，五级已落账，`alarms.py check` 为 `clean (625 judgments)`。

`TOOL-119` 首轮红证据来自媒体标签脱敏泄露和生成图卡横竖版占位跳变；修复后二进制在真实 App、受管 gateway、Computer Use、三路 SSE witness、LLM tap、backend/frontend journal 和 60fps 录屏下完成 landscape 生图。最终真实 tool call 只调用一次 `generate_image`，wire 只做一次图片生成、一次媒体上传；SQLite、tool result、SSE 和 UI 对证，画面显示 `1344×768` 与真实附件。正式证据 `evidence/TOOL-119.md`，警报复审 `evidence/tool-119-ledger-alarm-reaudit.md`，anchors `10/10`，五级 `G1/F2/A5/C4/G2` 已落账，最终 `alarms.py check` 为 `clean (630 judgments)`。

该段以下既有 TOOL-116 及更早描述均为历史过程记录；恢复执行只以上述当前前线、`README.md` §5.2、`LOG.md` 最新条目和 COVERAGE 当前行为真相。

统一长门禁首轮由旧的“一次返回 55 个子节点”契约断言失败；按现行 `/documents` cursor 分页实现修正 testend，保留 `/documents/tree` 一次整树 metadata 断言。第十一批收口时完整 `make testend` 又冻结了一个真实前置问题：`install_mcp_server` 的不可绕过 danger gate 没有被 chat 验收剧本处理，导致回合正确停在 `streaming`；场景现已逐次断言并批准两道人闸，定向场景与完整 testend `go test ./...`（scenarios 292.290s）均通过。最终 `make verify` 四门全绿，backend gate、锚点 10/10、警报 clean、diff check 均通过；批次已提交 `de146b72`。

**历史快照。** 第九批已完成统一长门禁并提交 `32b33499`；第十批 `TOOL-091..100` 已完成 **50 / 50** 并提交 `553fa150`；第十一批 `TOOL-101..110` 已完成 **50 / 50**，完整 testend、`make verify`、锚点与警报复核通过并提交 `de146b72`。当时中央账本为 `595 judgments`，批次十二为 **10 / 50**，下一原子前线为 `TOOL-113 list_conversations`；该段仅供追溯，当前前线以上方整体重述为准。

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
