# SURF-063 · 账本警报独立复审

复审时间：2026-08-19 21:19（Asia/Singapore）

## 复审对象

- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`
- 本项五级写入后 formal ledger=`2265`；打开警报为 `gap-too-fast`、`discovery-collapse`。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-211359`
- 证据=`sessions/20260819-211359/evidence/SURF-063-settings-rail-resources-five-level.md`

## 独立复读

- 逐张复读 Models & keys、MCP loading/settled marketplace、Memory empty、Sandbox empty、Workspaces 五张原始帧；五个面板的可见状态和证据文字一致，没有把 loading、settled-empty、managed identity 或当前 workspace 混为一谈。
- 复读 backend=`196` 行、frontend=`4` 行、sse=`4` 行、llm=`13` 行；没有应用红线，llmtap 的 challenge/install/models 为真实 `200`，资源路径没有伪造 completion。
- `rig-check` 已证明同一 session 的五通道归属；`rig-down` 正常完成录屏并清理 App/backend/tap/recorder。
- 资源 focused suite=`77/77` 全通过，Dart analyze、coverage check、git diff check 通过；五个 judge 的 law 均存在于 `CODEX.md`，L2 evidence 在同一 sealed session 内。

## 警报处置

`gap-too-fast` 由连续写入同一项五个 level 的账本动作触发；这不能替代复审，故本文件保留原始警报并重新核读证据。`discovery-collapse` 是最近窗口没有 fail；本项复读没有发现资源目录级 defect，不能修改 fail-share 阈值或删除历史。

复审结论：SURF-063 的五级 pass 证据完整，两个统计警报仅在独立复审完成后销账；标准、阈值、法典、锚点和 gate 均不变。
