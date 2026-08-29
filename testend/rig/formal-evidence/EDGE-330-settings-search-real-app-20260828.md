# EDGE-330 · 设置项搜索索引漂移 · 真实 App L2

## 判定

`pass`。本格的可观察产品契约是：设置搜索索引与实际挂载行保持一致，用户可以从同一搜索框找到设置项、跳到正确面板与目标行，并在清空后回到完整目录。L1 的双向索引/anchor-mount gate 已在 `EDGE-330-settings-search-index-20260826.md` 记录；本证据补齐同一契约的真实 App L2。

## 正式 session

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-033249`
- Data: `/private/tmp/anselm-data-edge330-20260828-r2`
- Workspace: `ws_2bf2f8af742b6d14` (`EDGE-330 clean settings search`)
- 该 session 由正式 conductor 启动，`rig-check` 已在 App 运行期间通过；录屏与五通道日志在收台后封存。

## 真实产品路径

- 空查询显示 Preferences / Resources / System 三段完整目录。
- 输入 `zoom` 后按面板分组显示 General、Storage & logs、Shortcuts 的对应设置项；点击具体项跳到 Shortcuts 的目标行并清空搜索。
- 输入 `zzzqqxx` 后只显示一条 `No matching settings`，没有幽灵结果或旧目录残留；上一动作已经证明结果点击会清空查询并回到目录视图。
- 目标设置行在浮层头带下以等高蓝色洗亮，搜索随后清空，证明索引条目、面板归属、anchor 挂载和用户可见结果指向同一对象。
- 所有搜索动作使用真实键盘事件；没有用 `set_value` 代替用户输入回调。

## 五通道

1. **Frame**：该 session 的 `screen.mov` 由窗口 recorder 录制；Computer Use AX 状态记录了空目录、`zoom` 结果、目标跳转和 `No matching settings`。
2. **Backend**：`backend.log` 无 panic、fatal、布局或未解释应用红线。
3. **SSE**：`sse.jsonl` 记录三路真实连接；本路径只读，不伪造业务 durable frame。
4. **Frontend**：`frontend.log` 5 行，仅启动、Flutter VM 与已审阅 IMK host warning，无 Dart/Flutter assertion 或 overflow。
5. **LLM wire**：managed challenge/install/models 均为 200；该只读设置路径无 completion，不伪造模型调用。

## 本地验证与法条

- `settings_search_test.dart`、`settings_catalog_gate_test.dart`、`settings_shell_test.dart` 通过，包含索引唯一性、双语言文案、anchor 双向挂载、分组、空态、跳转和洗亮。
- `G1`：从空目录、结果、无匹配到结果点击后的清空恢复，入口和结果可被新用户理解。
- `F1`：真实结果分组、面板跳转、anchor 洗亮与录屏/AX 状态一致。

本格仅提升 L2；L3 的独立时延测量、L4 的本格 ROI/craft 取样、L5 的从零发现性走查未在本格单独判定，继续保持 `na`。
