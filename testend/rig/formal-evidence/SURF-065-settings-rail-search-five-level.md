# SURF-065 · settings/rail-search

## 判定

`pass`。本项验证 Settings 左岛同一搜索框的双视图闭环：空查询为三段目录，有查询为设置项级结果；同时覆盖无匹配、面板级入口、跨面板具体项命中、滚动定位、一次性洗亮与清空恢复。没有发现需要 stop-and-fix 的产品缺陷。

## 真实 App 路径

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-212554`
- Data: `/private/tmp/anselm-data-surf065-20260819-r1`
- Workspace: `ws_53a147068c051721` (`Acceptance SURF-065`)
- 全新 workspace onboarding 后进入 Settings；由于设置面板是机器级持久状态，真实重启后的初始面板为上轮留下的 About，这也证明没有把 workspace reset 错当 machine preferences reset。
- 空查询真实显示完整三段 Preferences / Resources / System 目录；输入 `zzzz` 后只显示一条 `No matching settings`，没有幽灵结果或残留目录行；真实删除字符清空后目录完整恢复。
- 输入 `zoom` 后结果按面板分组，真实显示 `General → UI zoom`、`Storage & logs → Reset local preferences`、`Shortcuts → Zoom in / Zoom out / Reset zoom`。点击 `Shortcuts` 面板头只跳面板并清空搜索；再次输入 `zoom`，点击 `Reset zoom` 后搜索清空、Shortcuts 面板保持，目标行滚到浮层头带下并以等高蓝色洗亮。
- 所有动作均用真实键盘事件和新鲜 AX 树驱动；没有用 `set_value` 代替用户输入回调。

关键帧：

- `evidence/SURF-065-no-match.png`
- `evidence/SURF-065-directory.png`
- `evidence/SURF-065-cross-panel-results.png`
- `evidence/SURF-065-item-jump.png`

## 五通道证据

1. **Frame**：`screen.mov` 由 conductor 正常收束，最终时长 `127.786667s`；无匹配、目录恢复、跨面板结果和洗亮定位帧已封存。
2. **Backend**：`backend.log`=`176` 行；无 panic / fatal / exception / stack trace / RenderFlex / RenderBox 应用红线。
3. **SSE**：`sse.jsonl`=`4` 行；三条流真实连接，本路径没有业务 mutation，不伪造耐久业务帧。
4. **Frontend terminal**：`frontend.log`=`5` 行；仅正常启动、Flutter VM 与已知 macOS 输入法宿主噪声，无 Flutter / Dart / assertion / overflow / unhandled 红线。
5. **LLM wire**：`llm.jsonl`=`10` 行，managed proof challenge / install / models 真实返回 `200`；设置搜索路径没有 LLM completion，不伪造 completion。

`rig-check` 在 App 运行期间证明同一 session 的五通道归属；rig-down 正常收束，进程审计无 App/backend/tap/recorder 残留。

## 本地验证

- `mise exec -- flutter test test/features/settings/settings_search_test.dart test/features/settings/settings_catalog_gate_test.dart test/features/settings/settings_shell_test.dart`：通过。
- 设置搜索/目录相关 focused tests 与 `dart analyze`：通过。
- `python3 testend/rig/gen_coverage.py --check`：通过，848 rows，无 tombstone。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check`：clean。
- `git diff --check`：通过。

## 法条

- `G1`：空目录、结果列表、无匹配和清空恢复都能从同一搜索框发现，不需要用户猜隐藏入口。
- `F1`：结果分组、面板切换、具体 anchor、目标洗亮与真实 AX/录屏状态一致。
- `B2`：跨面板搜索不会留下旧目录/旧详情，长页目标滚动后行高连续、无遮挡。
- `C4`：无匹配使用单一安静提示，结果使用用户设置名称，跳转后反馈明确而不泄漏内部 key。
