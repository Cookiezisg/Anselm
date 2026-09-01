# EDGE-317 选区跨块缝隙：L5 ledger/alarm 独立复审

- judgment: `EDGE|选区跨块缝隙|L5|na|G1`
- formal session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-210113`
- primary evidence: `testend/rig/formal-evidence/EDGE-317-selection-block-gaps-l5-real-app-boundary-20260901.md`

## Independent re-audit

- `CODEX.md` 中存在 `G1`；本次以真实现场确认适用性边界，不把 G1 当作默认豁免。
- 真实 App 的 Library、焦点建立、跨块选区、格式条、离开/重开和稳定帧均可复查；L4 的 C1 证据也已
  以 `regions` 证明选区桥接为连续组件。
- backend、SSE、frontend、LLM journal 均非空，应用级红线已分类；`rig-check.sh` 五通道通过，
  `rig-down.sh` 完成录屏封口并收台 owned processes。
- SQLite 仍为三段原文，选择动作没有修改 durable 内容；没有用旧 session 或空 journal 替代现场。
- 锚点集重新校准 `10/10`，法典、阈值、五级标准和顺序门均未修改。

## Alarm disposition

`discovery-collapse` 因最近 50 条裁决 fail-share 为 `0.0%` 打开。复审确认跨块选区是普通文本选择
的排版正确性不变量，没有独立可发现入口；把内部 overlay 行为伪装成 G1 pass 才是标准下降。该结论
只适用于本项，复审记录完成后允许 ack。
