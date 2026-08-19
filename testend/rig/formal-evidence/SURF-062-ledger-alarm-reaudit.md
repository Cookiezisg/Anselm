# SURF-062 · 账本警报独立复审

复审时间：2026-08-19 21:12（Asia/Singapore）

## 复审对象

- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`
- formal ledger 在本项前 `2255` 条；本项五级裁决后为 `2260` 条。
- 本项 session=`sessions/20260819-210545`，证据=`sessions/20260819-210545/evidence/SURF-062-settings-rail-prefs-five-level.md`。
- 打开警报：`gap-too-fast`、`discovery-collapse`。

## 独立复读

- 从原始 `screen.mov` 与六张封存帧复读：设置三段目录、General / Notifications / Chat 三面板、`theme` 与 `login` 两次真实键入搜索、跨面板跳转、目标洗亮、启动项开关 on → off 均有对应画面。
- 从原始 journals 复读：backend=`297` 行无应用红线；frontend 仅已知 macOS IMK 宿主噪声；ssetap 在 rig-check 中证明三流已连接；llmtap 的 challenge/install/models 均为真实 `200`，没有伪造模型 completion。
- 复读本项五个 judge 记录：每个 level 的 law 均存在于 `CODEX.md`，level 2 证据位于同一 session 且 session manifest 与证据绑定一致；没有手工编辑 COVERAGE 或绕过 gate。
- 重新运行设置 catalog/search/shell gate：`42/42` 通过；Dart analyze 无问题；`gen_coverage.py --check` 与 `git diff --check` 通过。

## 警报处置

本次 `gap-too-fast` 是五个同一项 level 的账本写入连续发生造成的机械信号，不代表没有观察真实 App；但它仍然值得保留并要求独立复读。`discovery-collapse` 是最近窗口没有 fail 的统计信号，本项没有发现新产品 defect，不能靠改阈值或删除历史消除。

复审结论：本项证据足以维持五级 pass；本次仅销账，不修改 CODEX、阈值、标准或覆盖范围。后续每个批次仍必须接受同一组三曲线约束。
