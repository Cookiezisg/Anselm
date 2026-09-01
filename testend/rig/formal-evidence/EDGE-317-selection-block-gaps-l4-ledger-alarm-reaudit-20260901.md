# EDGE-317 选区跨块缝隙：L4 ledger/alarm 独立复审

- judgment: `EDGE|选区跨块缝隙|L4|pass|C1`
- formal session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-210113`
- primary evidence: `testend/rig/formal-evidence/EDGE-317-selection-block-gaps-l4-real-app-20260901.md`

## Independent re-audit

- `CODEX.md` 中存在并适用于跨块连续选区的 `C1`；没有修改法条、测量阈值或五级标准。
- 主证据包含真实 App 的焦点建立、三次 `Shift+Down`、稳定选区帧、离开/重开路径，以及 `regions` 主连续组件
  测量，不是静态截图或旧 L3 证据复用。
- backend、SSE、frontend、LLM journal 均非空；frontend 的 IMK 信息已分类，未隐藏应用级异常。
- durable SQLite 仍为三段 fixture 原文；真实选区没有破坏文档内容。
- `rig-check.sh` 五通道通过，`rig-down.sh` 完成录屏封口和 owned process 收台；锚点重新校准 `10/10`。

## Alarm disposition

新增裁决后 `discovery-collapse` 因最近 50 条裁决 fail-share 为 `0.0%` 打开。复审确认 C1 的跨块视觉
连续性、组件测量、动作窗口边界、五通道和 durable 证据均真实存在，未以 `na`、旧 baseline 或空 journal
制造绿格。该警报是标准漂移检查，不代表本格产品失败；复审完成后允许 ack。
