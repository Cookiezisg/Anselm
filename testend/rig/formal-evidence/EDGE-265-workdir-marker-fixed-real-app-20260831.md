# EDGE-265 · 切驻地落 marker 块 · 修复后真实 App 验收

## 现场

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-230948`
- workspace: `ws_8fe797430dcf8f75`
- conversation: `cv_c1e12d0949b1494e`
- folders: `/private/tmp/anselm-edge265-first`, `/private/tmp/anselm-edge265-second`
- final frame: `session/evidence/EDGE-265-workdir-marker-fixed.png`
- recording: `screen.mov` (`223.920000s`)

## Stop-and-fix

首轮真实 App 观察发现：后端已经落下 durable marker，驻地按钮和 rail 也立即更新，但当前打开的 transcript 不会立即重拉历史；用户必须离开再回来才能看到标记。这违反了“动作完成后当前时间线立即诚实”的产品直觉，因此停止推进。

修复为成功的驻地 PATCH 后，仅当当前 conversation stream 已存在时调用既有的 transcript resync/hydration 路径；不销毁活流，也不为未打开线程凭空创建 provider。新增 provider 回归测试锁住“无 transcript SSE 帧时主动重同步仍能读到 marker”。

## 真实产品路径

1. 启动真实 macOS App，使用真实 managed gateway 完成一轮聊天。
2. 在当前线程选择 `/private/tmp/anselm-edge265-second`，同一活动 transcript 立即显示 `Working directory → /private/tmp/anselm-edge265-second`。
3. 从最近目录切换到 `/private/tmp/anselm-edge265-first`，同一活动 transcript 立即显示 `Working directory /private/tmp/anselm-edge265-second → /private/tmp/anselm-edge265-first`。
4. 选择 `Leave working directory`，同一活动 transcript 立即显示 `Left the working directory /private/tmp/anselm-edge265-first`。
5. REST 历史与 SQLite durable rows 保留三条 marker；marker 的 `content` 为空，`attrs.kind/from/to` 与当前驻地投影一致。

## 五通道

- frame: Computer Use 逐次读取真实 App accessibility tree 与窗口画面；三次动作后的 marker 均在当前线程即时出现，最终帧保存于 session evidence。
- backend: sidecar 真实健康，`rig-check` D1 归属通过；marker PATCH/历史读取与驻地状态一致，无 panic/fatal。两条 WARN 是 23:12:58 主动停止无关搜索回合后的 context-canceled 记录，不属于驻地路径，且已由本证据明确解释。
- SSE: 独立 `ssetap` 三路连接并持续记录；驻地变更不伪造 transcript SSE 帧，marker 由 REST hydration 进入历史，符合 E1/E2。
- frontend: 真实 App 窗口录屏完成，三次 marker 无重开线程、无等待隐藏刷新；`frontend.log` 仅有 macOS IMK 系统诊断，无 Dart/Flutter/RenderFlex/overflow 红线。
- LLM wire: `llmtap` 真实记录 managed gateway challenge/install/models 与聊天请求，未绕过观察器。

## 五级判定

- L1 `F5`: backend focused/race 与 black-box 回归证明 marker 可由 durable history 重建。
- L2 `F2`: 真实 App、backend、SSE、frontend、LLM 五通道同一 session 绑定；三次变更的 UI 文本与 durable marker 的 `from/to` 一致。
- L3 `B2`: 修复前的“落库但当前视图不更新”跳变已消除；每次成功动作在当前 transcript 内即时出现对应 marker，不需离开/重开。
- L4 `C5`: marker 在真实 transcript 中以稳定的一行时间线 chrome 呈现，三种状态文本均完整，无截断、溢出或布局重排。
- L5 `G1`: 用户只需使用已有工作目录按钮和最近目录，不需要知道 SSE、hydration 或 durable rows；动作完成后当前时间线自然解释发生了什么。

## Local verification

- `mise exec -- dart format ...` passed.
- `flutter test test/features/chat/state/conversation_stream_provider_test.dart test/features/chat/ui/chat_work_dir_button_test.dart`: `35/35` passed.
- backend conversation focused normal/race and testend black-box focused normal/race passed before this real-App run.
- `rig-check` passed; `rig-down` passed; no new process remains.
