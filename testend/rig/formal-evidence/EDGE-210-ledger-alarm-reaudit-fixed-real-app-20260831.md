# EDGE-210 · 账本与警报独立复审

## 范围

EDGE-210 L2-L5 是同一产品路径的连续正式裁决，写入后触发 `gap-too-fast` 与
`discovery-collapse`。本复审只核对证据链，不改警报阈值、算法、法典、锚点或顺序 gate。

## 独立证据核对

- HTTP 402 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-142137`，
  录屏 `44.931667s`；流内 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-142343`，
  录屏 `28.458333s`。两者均由 `rig-check` 五通道检查并由 `rig-down` 正常封口。
- 两个 `llm.jsonl` 都记录真实 managed challenge/install/models 成功；分别只有一条明确的
  `fault_injected`，HTTP session 是 `402 QUOTA_EXHAUSTED`，stream session 是 `200
  BUDGET_EXHAUSTED`。故障注入边界在正式证据中明确，不被写成真实网关扣费耗尽。
- 两个 `sse.jsonl` 都有 messages/entities/notifications 三路连接和 clean disconnect；
  backend journal 没有 panic/WARN/ERROR/FATAL，frontend journal 没有 Flutter/Dart/布局红线。
- 两个最终帧都显示同一条可执行用户文案，未出现内部错误码、HTTP 状态、provider 原文或
  残留加载态。对应的 red run 和 stop-and-fix 记录在 `EDGE-210-quota-copy-red-20260831.md`。
- `frontend` 的 chat transcript widget test、i18n 生成和 llmtap quota fault contract test
  均已通过。

## 警报处置

连续裁决是一次真实现场完成后的四格账本写入，并非无证据批量盖章；`discovery-collapse` 的
fail-share 低于既定阈值是因为本项在修复后确实没有失败产品结果，不能反过来修改阈值。两条警报
均以本复审证据 ack，后续若再次触发，仍需新的独立复审。
