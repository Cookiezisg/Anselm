# EDGE-257 · 账本 / 警报复核

首轮真实 App 发现并修复菜单英文阻断提示的截断，故该轮没有写绿账。修复后的真实 session
为 `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-203407`；稳定帧和红证据
分别为 `EDGE-257-dirty-switch-branch-fixed-20260831.jpg` 与
`EDGE-257-dirty-switch-branch-red-20260831.jpg`，五通道证据见
`EDGE-257-dirty-switch-branch-real-app-20260831.md`。

本次正式写 L2-L5 后，`discovery-collapse` 按原算法以近 50 条 live judgment 的低 fail-share
打开；L2、L3、L4、L5 后各自重新出现同一统计信号。四次均已逐级独立复核并 ack：复核了修复前后的
画面、完整录屏、focused 回归、backend/SSE/frontend/LLM journal 和 `rig-check`/`rig-down`，没有
修改阈值、曲线算法、CODEX、锚点、五级标准或顺序 gate。AX observer churn 另有 session-local
`evidence/frontend-ax-review.md` 归类记录，未被静默算作干净日志。

最终命令：

`RIG_HOME=/private/tmp/anselm-rig-formal-20260831-11 python3 testend/rig/alarms.py check`

结果为 `clean (171 live judgments; 4240 baseline judgments excluded from drift curves)`；写账不是
因为 fail-share 低而自动通过，而是因为真实证据已独立复审。最终锚点校准为 `10/10`，清册生成检查为
`848 rows / 848 carried judgments / 0 tombstones`。
