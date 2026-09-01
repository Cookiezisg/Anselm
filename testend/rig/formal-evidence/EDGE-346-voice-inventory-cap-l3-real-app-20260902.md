# EDGE-346 | 音色库存 2 槽上限 | L3 真实 App 证据

## 判定

L3 通过，法典 `A4`：超过 1 秒的操作必须持续显示进度或状态文案。

本格验证的是“已满时仍能明确完成拒绝并继续操作”，不是把库存拒绝伪装成成功。

## 有效会话

- session：`/private/tmp/anselm-rig-formal-20260902-18/sessions/20260902-041857/`
- 数据目录：`/private/tmp/anselm-data-edge346-l3-20260902-r1`
- 上游：真实 `https://api.anselm.website`
- App：conductor 直接启动的 Flutter macOS App，窗口录屏独占
- 录屏：`screen.mov`，`3104x1848`，`60fps`，`626.266667s`
- 夹具：已验证的 `anselm-voice-reference-r3.wav`，约 219 KB；不是用户个人数据

## 用户目的与反馈

Computer Use 在真实 App 中完成：

1. 创建隔离 workspace，通过 Composer 的文件选择器上传语音夹具。
2. 分别请求登记 `edge346-l3-first` 与 `edge346-l3-second`，两次都经过危险确认并最终显示 `Called enroll_voice`。
3. 设置页显示两条音色，并明确显示 `Both slots are taken — delete one to make room.`。
4. 再上传同一夹具，请求登记 `edge346-l3-third`，确认后工具卡明确显示 `Allowed`、参数、`Error` 和 `voice inventory is full — delete a voice to make room`。
5. 失败回合收尾后 Composer 重新可用；随后在设置页逐条删除测试音色，最终显示 `No cloned voices yet` 与 `2 of 2 slots free`。

第三次拒绝不是静默等待：确认层、`Calling…`/工具状态、失败卡和可继续输入状态都可见，用户知道下一步是删除一个音色，而不是反复重试。

## 五通道互证

- **Channel 1 / 录屏**：`ffprobe` 可读，`h264 / 3104x1848 / 60fps / 626.266667s`；窗口录制器正常封口，无外部覆盖。
- **Channel 2 / backend**：唯一应用级 WARN 是预期的 `tool execute failed`，内容为库存已满；无 panic、fatal 或异常崩溃。两次删除本地 REST 均为 `204`。
- **Channel 3 / SSE**：`sse.jsonl` 共 294 行；messages durable seq 为 `1..51`，51 个唯一值且单调；notifications durable seq 为 `1..2`，无重复。第三次工具结果以 durable error close 落盘。
- **Channel 4 / frontend console**：仅有正常 Dart VM、TSM/IMK 宿主诊断；Flutter、Dart、RenderFlex、Unhandled、Exception、panic、fatal 检索为空。
- **Channel 5 / LLM wire**：网关收到两次 `POST /v1/voices` 并返回 `200`，未收到第三次登记请求；第三次只经过本地工具执行并在库存预检处失败。随后两次 `POST /v1/voices:delete` 均返回 `204`。

## 边界

“库存已满”是预期业务终态，backend 的一条 WARN 被保留为真实审计事实；它不是前端错误，也没有用清理动作掩盖拒绝路径。
