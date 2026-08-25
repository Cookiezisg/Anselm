# SURF-114 ledger and alarm re-audit

## Evidence decision

本轮 5 格均以 session 终态证据裁决；两次 Computer Use 错误输入不计绿格，正向提及路径、workflow run、通用 stage 和 settled summary 均由五通道互证。

## Ledger integrity

- batch 47 在 SURF-113 后为 45/50；SURF-114 写入后达到 50/50。
- 未修改 CODEX 阈值、anchor 题集或 judge/alarm 逻辑。
- focused regression: `mise exec -- flutter test test/features/chat/state/stage_director_provider_test.dart --plain-name 'R-10 settles when the terminal arrives after receipt open but before receipt close'` 通过。

## Alarm handling

若本轮 5 格写入触发 `gap-too-fast`、`pass-burst` 或 `discovery-collapse`，只依据最终 session 的录屏、SSE/backend/frontend/LLM journals 和本地回归测试复核后串行 ack；不会把观察器 AX 噪声或 Computer Use 输入限制当成产品绿证据。
