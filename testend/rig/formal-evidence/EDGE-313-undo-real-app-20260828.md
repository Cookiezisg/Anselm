# EDGE-313 · 编辑器 undo 全量重建真实 App L2

- 验收 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-225041`；隔离数据=`/private/tmp/anselm-data-edge313-physical-20260828-r3`；App PID=`5081`；window=`5591`；录屏由同一 manifest 归属并已正常收台，时长 `75.101667s`。
- 操作链由用户在真实 App 完成：基线正文为 `Original paragraph for undo.`，用户先粘贴 `EDITED`，再物理按下 macOS `Command+Z`。最终画面与 AX 均只保留原始正文；右侧元数据显示 `25 chars`、`28 B`。
- 后端真相交叉核对：基线 PATCH 响应 `256` bytes；粘贴后的 PATCH/GET 为 `262` bytes；撤销后的 PATCH/GET 回到 `256` bytes。没有通过脚本、数据库改写或 `set_value` 伪造撤销结果。
- SSE witness 同一 session 连接 `messages`、`entities`、`notifications` 三流；notifications 记录同一文档的连续 `seq=16,17,18`，其中两次 `document.updated` 对应编辑与撤销，未见缺口。
- frontend journal 只有正常 runner/Dart VM/系统 IMK 行，没有 `flutter error`、Dart 异常、RenderFlex、Unhandled 或 Null check 应用红线；backend 无 panic、fatal、error、warn。LLM tap 的 challenge/install/models 全部 `200`，三路流正常断开。
- 适用法典：`C1`（selection/edit recovery 的结构连续性）与 `F1`（持久数据、SSE、UI 五通道一致）；本格 L2 只裁决真实行为与数据真相，不把本证据冒充 L3-L5。
- 回归守卫：`AnEditor` 宿主 undo 测试纳入 focused editor/library/error 集合，共 `126` 项通过；`gen_coverage.py --check` 为 `848/848/0`。
