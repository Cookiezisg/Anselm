# SURF-098 账本警报独立复审

## 触发

SURF-098 五级裁决写入后，既有统计警报按设计打开：`gap-too-fast` 与 `discovery-collapse`。警报不是产品结论，必须先独立复审再 ack。

## 独立复核

- 重新读取修复后正式 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-064736` 的 screen/backend/SSE/frontend/LLM 五通道原始证据。
- 重新核对最终画面：`2 完成 / 1 失败`，三条日志主行均为中文状态词 `完成/失败`，旧的 `manual · failed` 只存在于修复前观察，不被绿证据覆盖。
- 重新核对真实红事实：fixture workflow 的 `entry.body.count` payload 失配仍在 SSE journal 中，且被明确写入本格证据；没有把它隐藏为“全绿”。
- 重新运行 focused Flutter suite、`rig-check.sh`、`rig-down.sh` 和 `gen_coverage.py --check`；锚点 `anchors.py check` 为 `10/10`，冻结 anchor hash 未变。
- `gap-too-fast` 的零秒间隔来自同一真实 session 完成观察后的五级 CLI 串行写账，不是无证据橡皮章；`discovery-collapse` 的零 fail 尾窗不被解释为全产品无缺陷，之前的真实 stop-and-fix 红事实与本 session 的 payload 红事实均保留。

## 裁定

两项警报均按既有机制串行 ack。没有修改阈值、统计算法、CODEX 法条、锚点集、覆盖序列或 ledger gate。下一格仍由 `COVERAGE.md` 的形式序列决定。
