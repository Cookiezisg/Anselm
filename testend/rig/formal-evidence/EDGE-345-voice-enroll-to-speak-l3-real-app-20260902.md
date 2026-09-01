# EDGE-345 | 音色登记→指名说话全链 | L3 真实 App 证据

## 判定

L3 通过，法典 `A4`：超过 1 秒的操作必须持续显示进度或状态文案。

本证据只覆盖本轮真实 App 的顺滑性等级，不把一次成功调用扩大为美学或可发现性结论。L2 的数据真相继续引用既有正式证据；L4/L5 仍由清册分别判定。

## 有效会话

- session：`/private/tmp/anselm-rig-formal-20260902-17/sessions/20260902-040120/`
- 数据目录：`/private/tmp/anselm-data-edge345-l3-20260902-r3`
- 上游：真实 `https://api.anselm.website`
- App：conductor 直接启动的 Flutter macOS App，录屏区域由窗口录制器独占
- 录屏：`screen.mov`，`3104x1848`，`60fps`，`361.696667s`
- 测试音频：由真实受管网关朗读固定测试句生成的 WAV，`218,924` bytes，约 `4.56s`；不是用户个人录音

## 用户目的与状态反馈

Computer Use 在真实 App 中完成以下连续动作：

1. 创建隔离 workspace，进入新对话并上传测试 WAV。
2. 输入“Register this uploaded audio as a cloned voice named acceptance-narrator-r3. Then read the sentence The acceptance chain is working in that voice.”并发送。
3. App 展示 `Awaiting confirmation` 和 `enroll_voice` 危险确认，用户点击 `Allow`。
4. 约 19 秒的网关登记期间，界面保留工具执行状态；登记完成后出现 `Called enroll_voice`，随后出现 `Synthesized speech`，最终显示 `The acceptance chain is working.` 与已保存音频附件。
5. 设置页的克隆音色列表显示 `acceptance-narrator-r3`，库存为 `1 of 2 slots free`。
6. 在真实 App 中删除该测试音色，确认层明确说明删除上游音色且费用不退；删除完成后列表显示 `No cloned voices yet`，库存恢复为 `2 of 2 slots free`。

这满足 `A4`：长操作不是静默等待，用户在确认、登记、合成和完成各阶段都能看到当前状态，并且回合最终可继续使用。

## 五通道互证

- **Channel 1 / 录屏**：录屏已由 `rig-down.sh` 正常封存；`ffprobe` 确认 60fps、窗口分辨率和完整时长，录制期间无外部窗口覆盖。
- **Channel 2 / backend**：同场 `backend.log` 的应用级 `WARN`、`ERROR`、`panic`、`fatal` 检索为空。
- **Channel 3 / SSE**：`sse.jsonl` 共 143 行；`messages` durable seq 为 `1..21`，`notifications` durable seq 为 `1..2`，两路均单调、无重复；消息链包含用户输入、`enroll_voice`、`generate_speech`、工具结果和最终 assistant close。
- **Channel 4 / frontend console**：`frontend.log` 只有正常 Dart VM service 启动行和已分类的 macOS IMK 宿主诊断；没有 Flutter、Dart、RenderFlex、Unhandled、Exception 或应用级 ERROR。
- **Channel 5 / LLM wire**：`POST /v1/media/uploads`、分片写入和 complete 分别成功；`POST /v1/voices` 返回 `200`；`POST /v1/audio/speech` 返回 `200` 且返回 `99,884` bytes；删除 `POST /v1/voices:delete` 返回 `204`。删除顺序为上游成功后本地删除，随后列表为空。

## 现场边界

上一轮使用纯音 WAV 得到上游 `400 invalid_request`，该输入不满足“单人干净语音参考”的接口前提，已停止并排除，不作为产品红线。随后本轮使用真实语音 WAV 完成同一流程；没有修改产品标准或降低 `A4` 阈值。
