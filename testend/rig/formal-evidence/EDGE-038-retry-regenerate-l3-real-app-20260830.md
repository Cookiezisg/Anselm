# EDGE-038 · :retry 重生成分支 · L3 真实 App 顺滑验证

## 结论

`pass`，依据 CODEX `B2` 零跳变律。该结论覆盖 Retry 动作后的反馈、流式工具链期间的视口稳定性和
收尾后的静止段；不把 L4 craft 或 L5 discoverability 冒充为通过。

## Session

- Formal session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-161502`
- Screen recording: `screen.mov`, `3104x1844`, `60fps`, `135.640000s`, ffprobe 可读
- App window: `7918`; recorder PID `17621`; `rig-down.sh` 后 App、backend、ssetap、llmtap、recorder 均归零
- Conversation: `cv_88b1ef075f48a164`; workspace: `ws_bf9aed46483af41a`

## 逐帧观察与测量

1. Computer Use 先从真实 App 的当前 assistant 操作菜单打开 Retry，再点击实际的主 `Retry` 项；没有
   复用过期 element index。动作后菜单关闭，Composer 保持可用，界面进入 `thinking`，没有新增 user 行。
2. 以录屏时间轴中主 Retry 点击约 `46.0s` 对应的局部 60fps 帧 `480` 为动作帧，在
   `ROI=(350,100,2700,1600)` 抽取动作前后 25 秒：

   ```text
   threshold=0.00005 → feedbackFrame=486, latencyMs=100.0, changedFrac=0.00005
   threshold=0.001   → feedbackFrame=600, latencyMs=2000.0, changedFrac=0.00401
   threshold=0.01    → feedbackFrame=601, latencyMs=2016.7, changedFrac=0.02881
   ```

   低阈值的首反馈是动作反馈；高阈值的 2.0s 变化是 thinking/工具链内容首现，不是无反馈等待。
3. 关键帧复读确认：菜单收起后先出现 `thinking`，随后工具调用逐步出现在原位置，内容向下扩展但不把
   既有回答从视口中夺走；收尾后保留可继续输入的 Composer。
4. 在完成后的稳定尾段 `80s..100s` 以 `2fps` 抽取 40 帧，在同一 ROI 执行
   `measure diff -threshold 0.0005`，无输出；稳定段没有非用户触发的历史内容位移。

## 五通道交叉证据

- REST/DB: 新 assistant `msg_18211364958d9608` 为 `completed`，`retryOf=msg_e95d53244b2fd3fe`；
  上一版本 `msg_e95d53244b2fd3fe.supersededBy=msg_18211364958d9608`，没有新的 user turn。
- SSE: `sse.jsonl` 共 203 条记录；messages durable seq=`1..26` 单调，13 组 `open/close` 与 169 条
  delta；无 SSE error。通知和实体流均完成连接生命周期记录。
- Backend: `backend.log` 212 行，无 panic、FATAL、Unhandled 或应用级异常红线。
- Frontend: `frontend.log` 4 行，无 FlutterError、DartError、RenderFlex、Unhandled 或断言错误。
- LLM wire: challenge 与四次 chat completion 请求均 HTTP `200`；本轮真实 Retry 链没有失败重试风暴。

## 修复边界

本轮使用修复后的 `retryTargets`，故压缩 marker 只作为时间线锚点存在，不会在点击 Retry 后跳变成
重试对象。红缺陷和 L2 数据真相见 `EDGE-038-retry-regenerate-compaction-marker-red-20260830.md` 与
`EDGE-038-retry-regenerate-compaction-marker-fixed-20260830.md`。
