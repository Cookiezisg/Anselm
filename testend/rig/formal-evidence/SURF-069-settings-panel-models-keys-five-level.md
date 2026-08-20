# SURF-069 · settings/panel-models-keys

## 判定

`pass`。真实 macOS App 中完成 Models & keys 的只读产品闭环：受管免费档卡、克隆音色空库存、受管密钥行、六类场景默认模型和搜索密钥空态均可发现；所有可变的模型选择器都逐一展开并关闭，当前值与可选值边界清楚，刷新动作穿过真实后端和 Anselm 网关。没有发现需要 stop-and-fix 的功能、数据、视觉或可发现性缺陷。

本轮没有点击 Add key，也没有选择或删除任何资源：这些动作会改变密钥或库存状态，当前验收目标是确认面板的真实可见性、能力边界和刷新真相，不为制造变更而制造变更。

## 真实 App 路径

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-224143`
- Data: `/private/tmp/anselm-data-surf069-20260819-r1`
- Workspace: `ws_b3a9e6654c009416` (`Acceptance SURF-069`)
- 全新 workspace onboarding 后进入 Settings → Models & keys；每次 Computer Use 动作后重新读取完整 accessibility tree。
- 免费档卡显示 `Anselm Free · Auto multimodal`、`0 / 1B` 和明确的 reset 时间；点击 Refresh 后仍保持同一权威状态。
- 克隆音色空态显示“Ask the assistant to enroll one from an audio attachment.”以及 `2 of 2 slots free`。该卡紧贴免费档卡，使用 slot/inventory 语义而非会随时间恢复的日配额语义。
- Model keys 区域显示受管 `Anselm Free` 行、`Managed · anselm · ins_...` 和绿色在线状态；`Add key` 作为明确入口可发现，但本轮未进入凭证写入流程。
- Scenario default models 中 Dialogue、Utility、Agent、Image generation、Speech synthesis、Video generation 六行均显示 `anselm-auto · Anselm Free`。每个 Change 入口真实展开后再关闭；Dialogue/Utility/Agent 显示 `Anselm Auto / Gateway-managed`，图像、语音、视频显示 `Anselm Free (gateway managed)`，没有把生成能力误当成普通对话模型。
- 点击 Refresh model list 后能力目录刷新并回到稳定的六行默认状态；Search keys 区域明确显示 `Not set` 和“只有通过 probe 的 key 才提供”的空态说明。

关键帧：

- `evidence/SURF-069-models-keys-top.jpeg`
- `evidence/SURF-069-models-keys-scenarios.jpeg`
- 连续录制：`screen.mov`，`518.718333s`，绑定同一 Anselm 窗口区域。

## 五通道证据

1. **Frame**：`recording-lifecycle.json` 绑定同一 App 窗口；`screen.mov` 覆盖 onboarding、Models & keys 初态、免费档与音色空态、受管密钥、六个场景选择器和搜索 key 空态。两张关键帧保存在本 session evidence 目录。
2. **Backend**：`backend.log`=`593` 行；无 WARN / ERROR / panic / FATAL。真实记录免费档 provision `200`、model capabilities `200`、quota refresh `200` 和 workspace 读回。
3. **SSE**：`sse.jsonl`=`8` 行；独立 witness 在 workspace 创建后自动发现并连接 `messages`、`entities`、`notifications` 三流，停机时正常记录断开。该路径全部是设置读取/刷新，没有实体或消息写入，因此没有伪造 durable 业务帧。
4. **Frontend terminal**：`frontend.log`=`4` 行；仅 direct App 启动、Flutter VM 和已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主噪声，无 Dart / Flutter / assertion / overflow / unhandled 红线。
5. **LLM wire**：`llm.jsonl`=`16` 行；managed proof challenge、install、models 和 quota 请求均经 `llmtap`，实际响应为 `200`。本路径不需要 completion，不把没有发生的 completion 当作证据。

`rig-check` 在 App 运行时通过五通道物理归属检查；随后 `rig-down` 完成收束，录制正常封存，未发现 backend、ssetap、llmtap、App 或 recorder 残留进程。

## 本地验证

- `mise exec -- flutter test test/features/settings/s2_models_keys_test.dart test/features/settings/voices_card_test.dart test/features/settings/settings_demo_fixture_test.dart test/features/settings/settings_shell_test.dart`：通过，`55 tests`。
- 测试覆盖受管免费档未开通/开通/配额刷新失败、能力缺席、按能力过滤的生成 key、六类默认模型选择、managed key 锁定、Search key 空态、音色库存空/满/删除/失败/竞态以及设置面板导航。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 bash testend/rig/rig-check.sh`：App 运行时通过，五通道 physically observing。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 bash testend/rig/rig-down.sh`：通过，录制和 journals 保留，进程组清空。

## 法条

- `G1`：Models & keys 在 Settings → Resources 下直接可发现；免费档、音色、密钥、场景默认和 Search keys 以产品目的分区，刷新与 Change 入口邻近其对象。
- `F1`：App 可见状态、backend 请求、网关 wire、SQLite workspace/defaults 和三条 SSE 连接事实一致；读操作无虚构写入。
- `B2`：面板滚动、选择器展开/关闭和刷新均回到稳定布局；没有 loading 残留、布局跳变、错位或未恢复的 busy 状态。
- `C4`：`Auto`、`Gateway-managed`、`Managed`、`slots free`、`Not set` 和“只提供 probe-OK search key”的边界文案让用户知道下一步，而不暗示音色库存会自动恢复。
- `G1`：六类场景的独立 Change 入口、Add key、Refresh、Search key 空态和受管行均无需猜测隐藏路径；生成场景可选值明确区分于对话场景。
