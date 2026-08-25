# SURF-095 i18n/diff 调查与账本重审

## Stop-and-fix

静态源码审查确认版本差异的 7 个键均从 `AnVersionDiff` 与版本手风琴真实调用；中文源资源原先把 `diff` 内部名词直出，并使用偏电报化的 `只显变更` 与半角括号。修复为 `展开差异`、`收起差异`、`仅显示变更`、`展开全部（$n 行）`，并重新运行 slang 生成器。双语 locale 回归、`AnVersionDiff`、version tab 聚焦测试共 `43` 项通过。

## Real App evidence

Session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-060117` 使用全新数据目录与真实 macOS App。通过 REST 只构造一个 v2 版本后，Computer Use 在实体版本页完成：

- v2 默认打开，v1 → v2 差异、变更说明、+1 −2、红删绿增均可见；
- v1 更多操作菜单实际显示 `收起差异`、`展开全部（3 行）`、`设为活跃版本`；
- 点击整份显示后再次打开菜单，实际显示 `收起差异`、`仅显示变更`、`设为活跃版本`；
- 最终抽帧 `sessions/20260825-060117/evidence/frames/SURF-095-final.png` 与 `screen.mov` 均无裁切、重排、重叠、白闪或交互跳变。

## Five channels

- Screen: `139.673333s`, `2784x1808`, H.264，录制绑定 Anselm window `1639`。
- Backend: `249` 行，D1 为 PID `81042` 持有 `:8742`，health 通过，无应用 WARN/ERROR/panic/FATAL/Exception。
- SSE: notifications durable `16..18`、entities durable `7..8` 连续；messages 本场景无 durable mutation，三流均连接并 clean EOF。
- Frontend: `19` 行，无 Dart/Flutter/RenderFlex/RenderBox/Unhandled 应用红线；固定 AXTree bridge 观察器签名已在 session `evidence/frontend-ax-review.md` 审阅，未知签名仍 fail-closed。
- LLM wire: 真实 `https://api.anselm.website` 的 challenge/install/models 全部 `200`；该确定性实体路径无 chat completion 需求，不伪造 completion 证据。

`rig-check.sh` 经过 AX session review 后通过，`rig-down.sh` 正常收台且无残留进程。五格按 `G1/F1/B2/C4/G1` 写入账本。

## Alarm re-audit

五次串行写账会触发 `gap-too-fast`，当前 50 格没有 fail 会触发 `discovery-collapse`。本次真实观察持续约 140 秒且保留五通道、录屏、静态测试和 AX 复核证据；锚点重新校准 `10/10`。两条警报按既有流程复审并 ack，未修改阈值、算法、法典或锚点。
