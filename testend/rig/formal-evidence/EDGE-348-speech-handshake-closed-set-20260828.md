# EDGE-348 语音双工握手拒绝闭集

## 结论

`EDGE-348` 的 L2 真实产品验收通过。语音 WebSocket 握手期的网关拒绝现在只以闭集
产品 code 到达 Flutter，额度耗尽显示明确不可重试的产品提示；上游 message 不进入
用户面，也没有 recorder 生命周期异常。

## 红场与 stop-and-fix

- 首轮真实 App session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-001137`。
  真实语音链路可以录音，但握手期错误在 Flutter 侧只显示“语音输入已断开”，没有告诉用户
  额度原因。
- 修复为 WebSocket 客户端先完成本地升级，再发送
  `{"type":"error","code":"SPEECH_QUOTA_EXHAUSTED"}` 并关闭；普通 HTTP 仍返回
  N1 429/403/503。前端增加额度耗尽、限流、安装禁用三种状态，并让额度耗尽和安装禁用不生成
  可重试录音卡。
- 第一轮修复 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-002455`
  已抓到第二个真实缺陷：错误事件早于 recorder 初始化时触发
  `PlatformException(record, Recorder has not yet been created or has already been disposed.)`。
  该场不计绿；修复为启动窗口缓存错误码，待 recorder 建立后单次 teardown，并补延迟 permission
  回归测试。

## 最终绿场

- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-002700`。
- 真实 Flutter App + Computer Use 触发麦克风入口后，AX 与录屏均显示：
  `本月语音输入额度已用完，请在额度恢复后再试。`；输入框立即回到可操作空态，未显示上游
  散文，也没有错误的 retry 卡。
- channel 2 backend：`GET /api/v1/speech/asr` 完成本地 WebSocket 连接并正常收口，无
  `panic`、应用级 `WARN/ERROR` 或错误堆栈。
- channel 5 LLM wire：challenge `200`，`GET /v1/speech/asr` 的上游拒绝 `401`，响应体含
  `QUOTA_EXHAUSTED` fixture code；上游 message 没有进入 Flutter 用户面。
- channel 3 SSE witness：`notifications`、`messages`、`entities` 三流均连接，无缺流或断点；
  该次本地语音故障没有 durable 消息变更。
- channel 4 frontend console：只有 VM service 和 macOS IMK 系统噪声，没有
  `PlatformException`、`RenderFlex`、`Unhandled`、应用 `Exception` 或 fatal。
- channel 1：`screen.mov`=`39.990000s`，窗口录制正常收尾；`rig-check` 五通道通过，
  `rig-down` 无残留进程。

## 裁决边界

本证据只支持 L2 的真实目的与五通道真相层；没有把一次错误态验证冒充顺滑、视觉 craft 或
可发现性完成。因此 L3、L4、L5 保持 `na`。

法条：`F1`（UI、backend journal、SSE、LLM wire 与台架状态交叉核对）。
