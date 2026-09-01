# EDGE-230 · 账本与告警独立复审

复审对象：`EDGE|ParseWAV 遍历 chunk 表` L2  ；裁决 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-132910-edge230`

## 复审结论

- 本次 L2 裁决由 `judge.py` 写入，法条=`measure:edge230-parse-wav-chunks`，证据文件位于同一 session 的 `evidence/`，不是手工编辑 COVERAGE。
- session manifest 的绝对 `session` 身份与 `--session` 一致；`screen.mov` 可读，三条 SSE 均有 connect，`backend.log`、`frontend.log`、`sse.jsonl`、`llm.jsonl` 均非空。
- 真实 managed gateway 的 3 个 `/v1/audio/speech` 响应均为 `200`，llmtap 记录 3 次显式 `wav_metadata_injected`；每次只增加 `24` bytes，响应 chunk 顺序为 `fmt/LIST/fact/data`。
- 三块实际 PCM 合计 `3,149,760` bytes；最终 durable WAV 的 `data` 区也是 `3,149,760` bytes，且仅有 1 个 `RIFF` 与 1 个 `data` chunk。真实 App 终态显示约 `65s` 音频附件。
- 第一轮注入器误判真实 `data` 长度哨兵并未被写绿；红证据、修复单测和第二轮全新 session 均在盘上。

因此 `gap-too-fast` 是近期正式裁决间隔短于法定 `25s` 的速率告警，`discovery-collapse` 是最近 50 条无 fail 的统计告警；两者均不否定本次证据真实性，也没有改变阈值、算法、法典、锚点或顺序门。复审后可以按原 id 销账。
