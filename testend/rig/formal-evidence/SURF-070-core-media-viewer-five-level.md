# SURF-070 · core/media-viewer

## 判定

`pass`。真实 macOS App 中完成媒体产物的端到端闭环：生成的图片可从工具产物卡进入全尺寸查看器；生成的视频可从海报启动真实原生播放器，显示真实画面、时间轴和控件，结束后可重播、可定位进度，并可进入同一套媒体查看器全屏播放。关闭后回到原会话，播放器状态和媒体元数据没有污染消息内容。没有发现需要 stop-and-fix 的功能、数据、视觉或可发现性缺陷。

本轮没有修改媒体代码。第一次观察到的灰色海报是播放器初始化中的中间帧；后续通过真实画面、`0:00 / 0:03`、`0:03 / 0:03`、重播、进度定位和全屏状态完成了反证，不能把初始化帧误判为失败，也不能把“附件已生成”误判成“用户能观看”。

## 真实 App 路径

- Clean session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-231808`
- Earlier production path with the same persisted media: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-225633`
- Data: `/private/tmp/anselm-data-surf070-20260819-r1`
- Workspace: `ws_3656d8ab6c6a28d2` (`Acceptance SURF-070`)
- Conversation: `cv_b5d4ca5ae61f1286` (`SURF-070 media viewer`)

真实走查步骤：

1. 用真实 managed gateway 生成 16:9 lighthouse 图片；工具卡显示已保存的 `MediaRef`、`1344×768` 和 `1.3 MB`。展开卡片后点 `View full size`，`RawDialogRoute` 显示 `Media viewer`、暗色 scrim、文件名/尺寸、关闭按钮和原图；关闭后回到会话。
2. 用真实 managed gateway 生成 3 秒 lighthouse 视频；工具卡显示 `generated-20260819-151042.mp4 · video/mp4 · 2.3 MB`，没有把生成回执伪装成可播放画面。
3. 点视频海报后，首次真实画面出现，播放器显示 `0:00 / 0:03`、暂停按钮、进度条和全屏按钮；等待到 `0:03 / 0:03` 后控件变为 `Replay`。
4. 点击进度条中段，真实时间回到 `0:01 / 0:03`，画面与位置同步；再次进入播放后允许暂停。
5. 在暂停位置进入 `Fullscreen`，同一 live controller 被送入媒体查看器；查看器显示视频、`0:01 / 0:03`、播放按钮和关闭按钮，查看器内部没有重复的全屏入口。关闭后回到会话，仍停在 `0:01 / 0:03`。
6. 所有 Computer Use 动作后都重新读取 accessibility tree；洁净会话中同一路径再次成功，没有依赖上一轮的内存态。

关键证据：

- 清洁会话连续录制：`screen.mov`，由 manifest 绑定到 Anselm 窗口 `53154`，区域 `80,40,1280,792`。
- 生成图/视频的上一轮完整工具链和媒体请求：`sessions/20260819-225633`。
- 后端对视频附件的真实响应：`GET /attachments/att_a325de7535d3934d/content` 返回 `200`，`Content-Length: 2451902`；Range `bytes=0-1023` 返回 `206`。
- 本地媒体文件经 `ffprobe` 确认为 H.264 High / AAC LC、1280×720、3.018005s，播放器不是靠空壳元数据通过。

## 五通道证据

1. **Frame**：洁净 session 的 `recording-lifecycle.json` 绑定同一 App 窗口；`screen.mov` 覆盖视频海报、真实画面、进度条终态、重播、进度定位、全屏查看器和关闭回归。上一轮 session 保留了生成工具卡、图片查看器和后端媒体读取的连续证据。
2. **Backend**：洁净 session 的 `backend.log` 有 `159` 行，无 WARN / ERROR / panic / FATAL；上一轮 session 记录生成产物、附件元数据和视频内容/Range 请求均为成功响应。视频附件的数据库行、大小、mime 和 sha256 与实际 blob 一致。
3. **SSE**：洁净 session 的独立 `ssetap` 发现并连接 `messages`、`notifications`、`entities` 三条流；该次重开只读已有 durable 对话，因此只有 discovery/connect 四行，没有伪造业务帧。上一轮生成回合的独立 witness 记录了 tool_result open/close、assistant close 和单调 durable seq，媒体生成事实与 UI 收尾一致。
4. **Frontend terminal**：洁净 session 的 `frontend.log` 只有 direct App、Flutter VM 和已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主噪声，无 Dart / Flutter / assertion / overflow / unhandled 红线；视频播放和全屏期间没有新增前端错误。
5. **LLM wire**：上一轮生成 session 的 `llm.jsonl` 记录真实 managed proof/install/models 与生成调用，图片和视频回执穿过 `llmtap`；洁净 session 的 `llm.jsonl` 保留 ready 事件，未把不需要发生的 completion 伪造为证据。

`rig-check` 在洁净 App 运行时通过：后端 PID 与 `:9083` listener 一致，ssetap/llmtap 端口归属正确，App PID 与窗口归属一致，录制区域无外部遮挡，五个通道 physically observing。

## 本地验证

- `mise exec -- flutter test test/core/media_viewer_test.dart test/core/media_cards_test.dart test/core/media_image_provider_test.dart test/core/media_ref_test.dart test/core/media_uri_test.dart test/core/ui/an_audio_attachment_card_test.dart`：通过，`35 tests`。
- 测试覆盖图片全尺寸查看器、独立关闭按钮、Escape 关闭、视频播放/暂停、结束后重播并 seek 到零、视频加载反馈、失败重试、惰性原生播放器、媒体 URI 和附件卡边界。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 bash testend/rig/rig-check.sh`：洁净 live session 通过，五通道 physically observing。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/alarms.py check`：`clean (2295 judgments on record)`。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/anchors.py check /private/tmp/anselm-rig-formal-20260801-3/anchor-answers-20260817-ep231.json`：10 anchors calibration passed，judge unlocked。

## 法条

- `F1`：UI 中的文件名、mime、尺寸、时长和播放进度与附件 REST/SQLite 行及真实 blob 对齐；没有用模型叙述代替媒体事实。
- `F2`：生成回合的 SSE tool_result open/close 和 assistant close 与 durable 对话一致；洁净重开只读既有行，未新增幽灵帧。
- `F3`：洁净后端和前端 journal 没有未解释红线；已知 IMK 宿主噪声单独归类，不遮蔽 Dart/Flutter 错误。
- `B2`：视频初始化从海报到真实画面没有把中间帧误当终态；播放、结束、重播、定位和查看器关闭均回到稳定布局，没有历史内容漂移或视口抢夺。
- `C4`：图片/视频卡、控件条和查看器使用统一圆角、scrim、间距与 chrome；全屏查看器没有重复全屏入口，进度条与媒体画幅视觉连续。
- `G1`：生成产物卡明确给出 `View full size`、视频海报给出播放入口、播放后出现进度/全屏控件；新用户无需读文档即可从产物走到观看目标。
