# EDGE-178 · L4 ledger/alarm re-audit

- `judge.py` 已以 `C4` 写入 `搜索 embedder 缺席降级` 的 L4；法条存在于 `CODEX.md`，L4 证据、
  稳定帧副本和五通道 session 均绑定 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-205857`。
- `discovery-collapse` 的触发仍是近 50 个裁决 fail share 为 `4.0%`，低于 `5%`。复审不把低
  fail share 当作产品清洁证明，也不将串行 ledger 写入导致的统计信号隐藏掉。
- L4 的实际范围已逐条复核：真实 Chat 稳定帧中的正文层级、列表缩进、行内 code 胶囊、island/card/
  pill 圆角层级、Composer 内缩、长标题省略和无 clipping/overlap 均有记录；L3 的 `measure diff`
  稳定段只作为动态证据，未被重复包装成 craft 数字。
- 复审确认设置页没有 search/embedder 控件，故本次 `C4` 不宣称入口可发现，也不替 L5 填格；L5
  仍开放。没有修改 alarm 阈值、算法、CODEX、anchor set、ledger sequence 或 coverage generator。
- `anchors.py check` 重新通过 `10/10`，允许按原阈值 ack `discovery-collapse` 并继续下一格。
