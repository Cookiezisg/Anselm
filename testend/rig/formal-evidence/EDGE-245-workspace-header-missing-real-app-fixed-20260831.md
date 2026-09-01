# EDGE-245 workspace 头缺失：真实 App 复验

日期：2026-08-31

## 现场

- session：`/private/tmp/anselm-rig-formal-20260831-19/sessions/20260831-182639`
- 数据副本：`/private/tmp/anselm-edge245-data-fixed3`
- 目标：真实 macOS App 经 App API proxy 启动；仅对第一次带 workspace header 的 `GET /api/v1/conversations` 剥离 `X-Anselm-Workspace-ID`。
- `rig-check.sh` 在收台前通过：backend D1、三路 SSE、managed LLM tap、真实 App、窗口录屏和 proxy 归属均通过。

## 五通道证据

1. **画面**：`screen.mov` 为 3104x1844、60fps、47.531667s 的真实窗口录屏。Computer Use 收台前读到 `Chat`、`Recents 1`、`演示对话`、`演示工作台`，最终处于可交互 Chat 壳，不是错误页或空白页。
2. **后端**：`backend.log` 中目标请求先返回 `401`（18:27:20.510，104 bytes），随后正常返回 `200`（18:27:20.511，320 bytes）；恢复期间重复请求的 401 之后同样返回 200（18:27:23.147）。健康探针持续 200，未出现 panic、WARN 或 ERROR。
3. **SSE**：`sse.jsonl` 证明 `notifications`、`messages`、`entities` 三路均连接；本旅程没有发送消息，因此没有伪造 durable frame 证据。收台为 EOF 后正常停止。
4. **前端终端**：`frontend.log` 只有三条明确的 `waiting for workspace selection`，没有 `DioException`、`Unhandled exception`、`FlutterError` 或 `Lost connection`。workspace 被清空期间的 SSE 401 被归类为正常重连状态，不再泄漏底层异常堆栈。
5. **LLM 线缆**：`llmtap.log` 与 `llm.jsonl` 均在线且完整；本旅程不需要调用模型，故没有把无调用误报为模型成功。

## 测量与判断

- 10fps 抽帧目录：`/private/tmp/edge245-frames-19-10fps`。
- `measure latency -action 0` 首个像素变化为 `100.0ms`，变化区域是骨架加载动画；这不是把骨架误算成业务完成，而是证明操作后立即有可见反馈。
- `measure diff` 找到语义切换为 `frame-0048.png → frame-0049.png`，`changedFrac=0.02069`，包围盒为 `(76,138)-(372,320)`，即侧栏从骨架切换为真实会话列表；切换后画面稳定，没有错误页、跳白或布局塌陷。
- 后端 401/200、proxy 的唯一 `workspace_header_dropped`、前端恢复日志和录屏最终状态互相对应，证明不是只测了客户端假状态。

## 代码修复

- `frontend/lib/core/net/api_client.dart`：`UNAUTH_NO_WORKSPACE` 清理活动 workspace。
- `frontend/lib/app/workspace_gate.dart`：活动 workspace 清空后使 durable workspace bootstrap 失效，重新从 workspace 名册解析，不留在误导性的 rail error。
- `frontend/lib/core/sse/sse_connection.dart`：workspace 选择过渡期间的 401 记录为等待重选；其他 401 仍保留原始错误。
- 对应单测：`frontend/test/core/net/api_client_test.dart`、`frontend/test/core/sse/sse_connection_test.dart`、`frontend/test/app/workspace_gate_test.dart`。

## 法条映射

- L1：`F1`，middleware/router focused contract 已先行通过。
- L2：`F2`，同一 sealed rig session 的真实后端 401/200、三路 SSE、前端、录屏、LLM tap 五通道交叉核验。
- L3：`A4`，骨架加载持续提供反馈，语义恢复在录屏中完成；无静默等待。
- L4：`C4`，侧栏恢复只发生一次明确的局部替换，稳定尾帧的间距、圆角和信息层级保持一致。
- L5：`G1`，用户无需阅读内部错误码；恢复后的 Chat、Recents 和会话入口以产品命名直接可见。

