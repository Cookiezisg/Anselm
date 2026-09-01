# EDGE-331 L5 账本警报独立复审

- alarm: `discovery-collapse`
- product session: `/private/tmp/anselm-rig-formal-20260901-14/sessions/20260901-233914`
- judgment under review: `EDGE|限额面板载入失败|L5|pass|G1`

## Independent checks

- L5 以普通用户目标复走入口，不使用 API、workspace ID、代理注入名或内部错误码：Settings 中可找到
  Advanced limits，错误态直接给出 Retry，点击后回到可操作字段；无需猜测、重启或阅读实现文档。
- 画面证据与 durable truth 对齐：app proxy journal 记录一次 503 和随后一次成功 forward，backend
  记录 schema/limits 成功，恢复态字段真实出现；没有把按钮点击本身冒充完成。
- 五通道与 rig lifecycle 已独立核对：真实 Computer Use/录屏、backend `431` 行、SSE 三流、frontend
  console、managed LLM wire、app proxy、manifest，以及通过的 `rig-check`/`rig-down` 全部存在。
- anchors `10/10`，G1 法条和顺序门未改；0% fail-share 只是统计警报，不是缺少发现性证据。

## Resolution

L5 可发现性证据独立成立，警报没有理由促使降低标准。未修改阈值、算法、法典、锚点、顺序门或 verdict，
允许按原规则 ack；未来任何真实失败仍必须进入红证据和修复流程。
