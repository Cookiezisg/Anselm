# EDGE-190 ledger alarm re-audit · 2026-08-31

`discovery-collapse` 在 EDGE-190 L2 写账后按原阈值打开：近 50 条 live judgment 中 fail 占比为
`2/50=4.0%`，低于 5%。这不是把当前产品判断为“无缺陷”的依据，按机制需要独立复审后才能继续。

- 本次新增 L2 绑定 session=`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260831-011939`，不是把之前有 utility 的 session 拼接过来。
- utility 缺席由 DELETE 200、API 回执缺少 `defaultUtility`、SQLite `default_utility=NULL` 三处确认；backend 同时记录 tier-1/tier-2 sifter 不可用并回退 index ranking。
- 五通道原始文件完整：录屏、backend journal、三路 SSE witness、frontend console、llm wire；`rig-check` 在封存前通过，历史 fail 保留在 journal 与证据目录。
- 真实 App 只展示一个 `search_blocks` 命中，`1 found` 与唯一 ref 一致；展开卡可见精确值，正文不再出现“这个输入”。
- 本次还修复并通过定向回归：两列表格中的 `引用 ID` 脱敏占位改为相邻结果卡指引；同一 wireable ref 的描述/代码索引片段按 ref 去重，避免同一积木重复显示。
- anchor 状态仍为 10/10，hash 未变且在有效窗口内；未修改报警阈值、算法、CODEX、锚点、五级标准或顺序 gate。

处置：仅按原机制 ack `discovery-collapse`，后续新增裁决继续重新计算三条漂移曲线。
