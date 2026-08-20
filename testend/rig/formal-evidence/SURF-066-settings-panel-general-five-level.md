# SURF-066 · settings/panel-general

## 判定

`pass`。真实 App 中完成通用设置的产品闭环：主题三档、受屏幕上限约束的六档缩放、三条字体轴、语言 UI/工作区双写、记住窗口、开机自启和自动检查更新。每个被改动的偏好都即时可见并在本轮结束前恢复默认；没有发现需要 stop-and-fix 的功能、数据或视觉缺陷。

缩放在当前屏幕上真实钳到 `1.1×`：`1.25×` 与 `1.5×` 以禁用视觉呈现，点击不改变当前值。代码路径由 `WindowZoom.maxFactor()`、`AnSegmentedOption.disabled` 和 `AnInteractive` 的 disabled semantics 共同守卫，避免用户误以为已应用不可容纳的档位。

## 真实 App 路径

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-214739`
- Data: `/private/tmp/anselm-data-surf066-20260819-r1`
- Workspace: `ws_60c1fd52053065b7` (`Acceptance SURF-066`)
- 全新 workspace onboarding 后进入 Settings → General；所有控件均以 Computer Use 新鲜 AX 树和真实点击驱动。
- 主题真实切换 `Dark → System → Light`；录屏帧确认近黑主题、系统主题和浅色主题都没有裁切或溢出。
- 缩放真实经过 `0.8× → 1.1×`，再点击不可容纳的 `1.5×`，值保持 `1.1×`；随后使用可见 `Reset to default` 回到 `1.0×`。
- 界面字体真实选择 `System` 后恢复 `Bundled`；内容字体真实选择 `Serif` 后恢复 `Sans (bundled)`；代码字体真实选择 `Fira Code` 后恢复 `JetBrains Mono`。
- 语言真实选择 `English → 简体中文 → System`。两次非默认语言切换均产生 workspace `PATCH 200`；最终 SQLite 真值为 `workspaces.language=en`。
- 记住窗口、开机自启、自动检查更新均真实完成 `off/on` 往返，并恢复到默认 `on/off/on`。

关键帧：

- `evidence/SURF-066-theme-dark.png`
- `evidence/SURF-066-theme-system.png`
- `evidence/SURF-066-zoom-min.png`
- `evidence/SURF-066-zoom-max.png`
- `evidence/SURF-066-font-menu-selection.png`
- `evidence/SURF-066-content-font-serif.png`
- `evidence/SURF-066-code-font-fira.png`
- `evidence/SURF-066-language-english.png`
- `evidence/SURF-066-language-chinese.png`
- `evidence/SURF-066-window-startup-visible.png`
- `evidence/SURF-066-defaults-before-switches.png`

## 五通道证据

1. **Frame**：`screen.mov` 由 conductor 正常收束，时长 `673.656667s`，`2560×1584 / 60fps`；设置切换、禁用缩放档、语言切换和恢复默认帧均已封存。
2. **Backend**：`backend.log`=`744` 行；无 WARN / ERROR / panic / FATAL / Exception / RenderFlex / RenderBox 应用红线。workspace `PATCH` 在 `21:52:10.596`、`21:52:31.090`、`21:57:04.364` 均为 `200`。
3. **SSE**：`sse.jsonl`=`8` 行；独立 witness 真实连接 `messages`、`entities`、`notifications` 三流并正常 EOF 收束。本路径没有业务 mutation，不虚构耐久帧。
4. **Frontend terminal**：`frontend.log`=`4` 行；仅正常启动、Flutter VM 与已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主噪声，无 Dart / Flutter / assertion / overflow / unhandled 红线。
5. **LLM wire**：`llm.jsonl`=`10` 行；managed proof challenge、install、models 真实返回 `200`。设置路径没有 LLM completion，不伪造 completion。

`rig-check` 在 App 运行期间证明同一 session 的五通道归属；`rig-down` 正常收束，进程与监听端口审计为零残留。

## 本地验证

- `mise exec -- flutter test test/features/settings/s1_panels_test.dart test/core/platform/window_zoom_test.dart test/core/settings/locale_boot_test.dart test/core/settings/settings_prefs_test.dart test/core/ui/an_interactive_test.dart`：通过，`38 tests`。
- `mise exec -- flutter test test/core/platform/window_zoom_test.dart test/core/settings/locale_boot_test.dart test/core/settings/settings_prefs_test.dart`：通过，`12 tests`。
- `python3 testend/rig/gen_coverage.py --check`：通过，848 rows，无 tombstone。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check`：执行五级写账后复核。
- `git diff --check`：通过。

## 法条

- `G1`：通用设置从 General 单面可发现；每个控制的当前值、禁用档和恢复入口都可见，无需猜测隐藏状态。
- `F1`：真实点击、AX 状态、workspace PATCH、SQLite 最终值和录屏帧一致；语言双写没有单边成功的假象。
- `B2`：缩放重排、下拉菜单、语言切换和长页滚动没有裁切、重叠、死控件或布局跳变；不可容纳档位保持惰性。
- `C4`：主题/字体/语言/启动开关的文案说明实际生效范围；修改态用统一蓝色边缘提示，重置使用同一设置行语法。
