# SURF-062 · settings/rail-prefs

## 判定

`pass`。本项验证设置左岛的三段偏好目录（General / Notifications / Chat）、面板内容、设置项级搜索跳转与一次性洗亮，以及偏好写入后的真实回读。没有发现需要 stop-and-fix 的产品缺陷。

## 真实 App 路径

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-210545`
- Data: `/private/tmp/anselm-data-surf062-20260819-r1`
- Workspace: `ws_54a9a9eaa18dc054` (`Acceptance SURF-062`)
- App 从全新工作区 onboarding 创建完成后进入 Settings；左岛按 `Preferences`、`Resources`、`System` 三段展示目录，偏好段包含 `General`、`Notifications`、`Chat`。
- `General` 真实显示 Theme、UI zoom、三类字体、Language、Window & startup、Updates；`Notifications` 真实显示通知级别、OS / in-app 通知与 failures / approvals / attention 胶囊开关；`Chat` 真实显示 sidestage auto-open、send key、web fetch mode 与跳转 Models & keys 的入口。
- 搜索框使用真实键盘事件输入 `theme`，结果态只显示 `General` 与 `Theme`；点击 `Theme` 后跨回 General，搜索清空，目标行滚到浮层头之下并出现一次淡蓝洗亮。再次输入 `login`，点击 `Launch at login` 后滚到长页面对应行并洗亮。
- `Launch at login` 通过真实坐标开关从 off → on → off，AX 状态和画面均回读一致；非默认态出现 `Reset to default`，恢复默认后该动作消失。没有留下验收工作区的机器偏好污染。
- 目录与面板切换期间无截断、重叠、横向跳变；搜索跳转后的标题收进浮层头是既有折叠海洋规则，目标行始终完整坐在头带下方。

关键帧：

- `evidence/SURF-062-rail.png`
- `evidence/SURF-062-general.png`
- `evidence/SURF-062-notifications.png`
- `evidence/SURF-062-chat.png`
- `evidence/SURF-062-search-theme.png`
- `evidence/SURF-062-search-login.png`

## 五通道证据

1. **Frame**：`screen.mov` 最终录屏由 conductor 收束，时长 `257.628333s`；关键设置目录、三面板与两次搜索跳转帧已封存。
2. **Backend**：`backend.log`=`297` 行；无 panic / fatal / exception / stack trace 应用红线。
3. **SSE**：`sse.jsonl`=`4` 行；三条流由 ssetap 连接并受 rig-check 证明，设置路径没有产生实体/消息耐久事件，故无伪造业务帧。
4. **Frontend terminal**：`frontend.log`=`5` 行；仅启动信息与一个已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主噪声，无 Flutter / Dart / RenderFlex / RenderBox / assertion / unhandled 应用红线。
5. **LLM wire**：`llm.jsonl`=`10` 行，仅含 managed proof challenge / install / models 的真实 `200`；本项不触发模型调用，未伪造 completion。

台架收束后无 backend、Flutter App、SSE tap、LLM tap 或 recorder 残留进程；`rig-check` 在 App 运行期间证明五通道物理归属成立。

## 本地验证

- `mise exec -- flutter test test/features/settings/settings_catalog_gate_test.dart test/features/settings/settings_search_test.dart test/features/settings/settings_shell_test.dart`：通过。
- `mise exec -- dart analyze`：设置相关文件无问题。
- `python3 testend/rig/gen_coverage.py --check`：通过，848 rows，无 tombstone。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check`：clean。
- `git diff --check`：通过。

## 法条

- `G1`：偏好面板和设置项搜索均能从左岛目录发现，搜索结果提供面板与具体设置项两级入口。
- `F1`：目录、面板、搜索命中、洗亮目标与偏好回读均由真实 App 状态和台架日志互相印证。
- `B2`：三段目录与面板切换保持稳定；长页面搜索将目标置于浮层头带下，不遮挡目标行。
- `C4`：设置项名称、辅助说明、通知级别和开关状态均为可执行的人话，不用内部 key 替代用户概念。
