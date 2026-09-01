# EDGE-246 · discovery-collapse 独立警报复审

## 复审对象

L2 写账后 `alarms.py check` 打开 `discovery-collapse`：近 50 条 live judgment 的 fail 占比
为 `2.0%`，低于既定 `5%` 下限。该警报按机制视为可能的判断失灵信号，不能直接忽略。

## 独立核对

- 重新读取本条 sealed session `/private/tmp/anselm-rig-formal-20260831-20/sessions/20260831-184415` 及其正式归档副本；录屏、backend、SSE、frontend、LLM wire 和 proxy journal 均存在且非空。
- backend 原始 journal 逐条证明 `GET /api/v1/conversations` 的 `403` 与后续 `200`；proxy 只发生一次 `host_rewritten`，没有把 403 伪造为成功响应。
- Computer Use 重新核对错误态、Retry 后恢复态和录屏稳定尾帧；没有把安全拒绝误判为产品成功，亦没有发现错误页、空白、抖动、内部诊断泄漏或无限重试。
- `measure` 的恢复变化为用户点击 Retry 后 `100.0ms` 首反馈，变化区域为列表内容；没有用骨架或观察器变化充当业务完成。
- `anchors.py check` 保持 `10/10`；CODEX、五级标准、阈值、三条曲线算法、formal sequence、COVERAGE 和强制人工队列均未改变。

## 结论

这是连续五级账本写入造成的 cadence / low-fail-rate 信号，不是证据缺失，也不是通过率被人为抬高：本条 L2 的真实现场证据足以支持其 F2 判定。按原算法仅 ack 当前警报，不修改阈值、不删除失败、不借用旧证据，后续每次新增 judgment 仍重新计算。

## L3 追加复审

L3 写账后同一 `discovery-collapse` 按原阈值再次打开。复核确认新增裁决仍引用同一封存现场，
没有把静态 skeleton、观察器噪声或后台响应当作用户反馈；`measure` 的 `100.0ms` 变化来自
真实 Retry 后的列表恢复。警报仍是统计 cadence 信号，未发现标准或证据质量下降；只 ack 该
水位对应的警报，阈值和算法保持不变。

## L4 追加复审

L4 写账后的 `discovery-collapse` 仍由同一低 fail-share 阈值触发。逐帧复核错误态与恢复态：
侧栏、主 Shell、输入框和错误卡的边界保持稳定，错误卡文案完整，未见白闪、裁切、重排或
内部诊断泄漏；`frame-0274→0275` 的变化只发生在 Retry 之后。该警报不代表视觉证据不足，
按原机制 ack，未改 C4 或统计规则。

## L5 追加复审

L5 写账后最后一次 `discovery-collapse` 仍按原算法打开。可发现性复核确认用户只看到清晰的
列表错误说明和 `Try again`，不需要知道 Host、DNS、HTTP 或内部错误码；点击后列表恢复，
且错误态没有把主 Chat 入口藏掉。该结论来自真实 App 录屏和 AX 状态，不是从代码推断；按
原机制 ack，不修改 G1、阈值或顺序门。
