# SURF-064 · 账本警报独立复审

复审时间：2026-08-19 21:25（Asia/Singapore）

## 复审对象

- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`
- 本项五级写入后 formal ledger=`2270`；打开警报为 `gap-too-fast`、`discovery-collapse`。
- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-212039`
- 证据=`sessions/20260819-212039/evidence/SURF-064-settings-rail-system-five-level.md`

## 独立复读

- 逐张复读 Storage、Advanced limits、Network、Shortcuts、About 原始帧；数据目录、机器级 limits、proxy restart 提示、六个 shortcut、更新失败态和 `Copied` 回执均可见，未用静态截图替代真实 App。
- 复读 backend=`171` 行、frontend=`4` 行、sse=`4` 行、llm=`10` 行；无应用红线，managed bootstrap 全为真实 `200`，本路径无 completion 也没有被伪造。
- `rig-check` 证明同一 session 的五通道归属，`rig-down` 正常收台且进程审计无残留；L2 evidence 与 session manifest 绑定一致。
- 系统 focused suite 全通过，Dart analyze、coverage check、git diff check 通过；五个 judge 的 law 均在 `CODEX.md` 中存在。

## 警报处置

`gap-too-fast` 由同一项五个 level 的连续账本动作触发；独立复读确认每格均有同一 session 的真实证据，不修改该警报算法。`discovery-collapse` 是最近窗口无 fail 的统计信号；本项没有发现 system rail defect，不修改 fail-share 阈值或删除历史。

复审结论：SURF-064 五级 pass 证据完整；两个统计警报只在复审完成后销账，标准、阈值、法典、锚点和 gate 均不变。
