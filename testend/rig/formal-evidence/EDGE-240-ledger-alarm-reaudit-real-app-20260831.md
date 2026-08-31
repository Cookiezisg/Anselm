# EDGE-240 · 账本与警报独立复审

复审对象是正式 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-165453`，以及本次
新增的 `EDGE|ADD COLUMN 结果幂等` 四条裁决。复审没有修改告警阈值、曲线算法、CODEX、锚点、五级标准或
顺序门。

- `gap-too-fast` 是统计保护信号：四格写账发生在真实旧库两次 App 启动、SQLite schema/数据/完整性核验、
  Computer Use 稳定帧、`rig-check` 和 `rig-down` 之后；审计动作不是把四次 CLI 调用当作产品观看时间。
- `discovery-collapse` 是统计保护信号：本格的 L3-L5 明确属于后台 migration 的适用性边界，不是自动把
  未观察等级写绿；L2 由同一真实 App session 的 F1 证据承担，三个 `na` 各有独立理由。
- 复核 session manifest、封口录屏、frontend/backend journal、三路 SSE、LLM journal、数据库列/索引/行数和
  `integrity_check`/`foreign_key_check`，没有发现与裁决矛盾的红线。frontend 中唯一 WARN 是已知 sandbox
  限制导致本地 search embedder fallback，本场未发起聊天，不影响迁移判断。

结论：两条警报均为预期的统计保护信号，可以仅对本次新增水位执行 `alarms.py ack`；继续保持原阈值和
五级标准。
