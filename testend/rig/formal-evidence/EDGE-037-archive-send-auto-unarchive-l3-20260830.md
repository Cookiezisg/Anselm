# EDGE-037 · 归档对话发消息自动解档 · L3

## 结论

`pass`，依据 `B2` 零跳变律。该结论只覆盖归档线程发送后的真实 App 顺滑度与稳定视觉，不替代 L2 的数据真相裁决，也不把 L4/L5 冒充为通过。

## Session

- Formal session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-154644`
- Screen recording: `screen.mov`, `3104x1844`, `60fps`, `108.475s`, ffprobe 可读
- App window: `7862`; recorder PID `14780`; session 收台后五个进程组均归零
- 录屏局部抽帧: `evidence/edge037-l3-60fps-v2/`, 发送动作附近 `68s..76s`
- 人工动作时间（Computer Use bridge）: 点击前确认 AX 树中的 composer 值为 `EDGE037 L3 archive restore probe`，真实键盘输入后重新读取 AX 树确认；随后点击当前 send button

## 观察与测量

1. 在 UI 中开启 `Show archived`，打开目标 archived conversation。发送前，composer 中的真实值已经可见，未复用旧 AX index 写入。
2. 点击发送后，录屏在首个 60fps 帧出现用户气泡与 `thinking` 状态；对局部 ROI `350,100,2700,1600` 执行：

   ```text
   measure latency -fps 60 -action 176 -threshold 0.00005
   {"feedbackFrame":177,"latencyMs":16.7,"changedFrac":0.00008}
   ```

   该低阈值只用于确认即时反馈存在。较高阈值的首个明显内容变化为 `frame=217`、`683.3ms`、`changedFrac=0.00112`，与模型首批正文渲染相符，不影响“点击后有即时状态”的判断。
3. 录屏中发送后用户消息保持在视口中，思考状态原地出现，回复逐步向下展开；约 30 秒稳定段内没有历史消息漂移、视口被夺、composer 重排或晚到背景跳变。2fps 长段 diff 的变化只出现在发送/内容首现窗口，稳定尾段无异常变化。
4. 收尾画面保留完整的用户消息、回答和可继续输入的 composer；没有错误卡、空白页或残留 generating 状态。

## 五通道交叉证据

- REST: `GET /conversations/cv_88b1ef075f48a164` 收尾为 `archived=false`, `isGenerating=false`；messages 中包含本轮用户输入与 completed assistant。
- SSE: messages durable `seq=1..8` 单调，包含本轮 `open → delta → close`；notifications 记录归档线程的 `archived → unarchived`。
- Backend: session journal 无应用级 `WARN`/`ERROR`/panic/FATAL；启动时 fixture 的预期 `409` 不计入产品错误。
- Frontend: 无 `FlutterError`、`DartError`、`RenderFlex` 或应用级异常；仅有已知宿主 IMK 诊断。
- LLM wire: challenge 与本轮 chat 请求/响应均成功，chat response status `200`，请求体与 UI 本轮输入一致。

## 边界

本证据不判定归档入口本身的视觉 craft，也不判定 L4 美学或 L5 可发现性；L2 已由同 session 的 `EDGE-037-archive-send-auto-unarchive.md` 独立裁决。Computer Use 的 `set_value` 曾在上一 session 与 Flutter controller 脱节，本 session 已改用真实键盘路径并留存输入前后的 AX 证据。
