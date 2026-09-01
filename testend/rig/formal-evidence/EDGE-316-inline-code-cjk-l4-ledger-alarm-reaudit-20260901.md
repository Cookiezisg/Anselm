# EDGE-316 行内代码 CJK 断盒：L4 ledger/alarm 独立复审

- judgment: `EDGE|行内代码 CJK 断盒|L4|pass|C1`
- formal session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-205403`
- primary evidence: `testend/rig/formal-evidence/EDGE-316-inline-code-cjk-l4-real-app-20260901.md`

## Independent re-audit

- `CODEX.md` 中存在且适用于连续灰底几何的 `C1`；没有修改法条、阈值或判定算法。
- 主证据指向真实 App 录屏、稳定帧和 ROI diff，且把 Library 导航引起的变化与静止段分开；不是单张截图或
  既有 L2/L3 证据的重复引用。
- backend、三路 SSE、frontend 和 LLM journal 均有非空记录，应用红线扫描结果已写明；无模型 completion
  的本地阅读事实没有被冒充成模型证据。
- SQLite 最终原文、字数和字节数与 UI/fixture 一致；没有重开后内容漂移。
- `rig-check.sh` 五通道通过，`rig-down.sh` 已完成录屏封口和 owned process 收台；锚点重新校准 `10/10`。

## Alarm disposition

新增裁决后 `discovery-collapse` 因最近 50 条裁决 fail-share 为 `0.0%` 打开。复审确认 C1 的视觉
连续性、稳定帧、动作测量、五通道与 durable 证据均真实存在，未用 `na`、旧 baseline 或空 journal
制造绿格；该警报是标准漂移检查而非产品失败。复审完成后允许 ack，并继续由顺序门推进。
