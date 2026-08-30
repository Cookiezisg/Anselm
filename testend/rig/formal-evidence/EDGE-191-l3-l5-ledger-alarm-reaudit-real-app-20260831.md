# EDGE-191 L3-L5 ledger/alarm re-audit · real App · 2026-08-31

本轮 `EDGE|附件 sandbox 提取路径` 的 L3、L4、L5 都来自独立真实 session=`20260831-015322`，不是把 L2 的附件事实重复冒充为体验结论。

- L3=`A4`：证据单独记录 assistant-open、首个 reasoning、首个 text 和完成时间，并确认录屏中存在进行态；没有把 17.46 秒完成时间冒充 A1，也没有隐瞒 Computer Use 输入归一化风险。
- L4=`C4`：证据引用该 session 的真实 `screen.mov` 尾帧 `/private/tmp/edge191-fixed3-final.png`，只判断附件卡、回答行、间距、无遮挡和错误卡缺席等成品关系。
- L5=`G1`：证据只判断普通 Chat 中附件入口、原生文件选择器、附件 chip 与人类可理解的结果路径；不把 extractor、SSE 或 LLM tap 的实现入口当成用户发现性。
- `rig-check` 已在收台前通过全部五通道，`rig-down` 已完成录屏封存且无残留台架进程；LLM wire 无工具调用，SSE 有完整消息生命周期，frontend 无 Flutter/Dart 异常。
- `gap-too-fast` 与 `discovery-collapse` 是连续写入三层判断触发的原算法警报。复审没有降低阈值、修改算法、改变 CODEX、重校 anchors 或绕过顺序 gate；仅对本次真实证据和该两项具体实例做 ack。输入符号归一化作为残余风险保留，不作为绿格理由。

处置：按原机制 ack 两个 alarm；后续判断从新的 evidence watermark 继续。
