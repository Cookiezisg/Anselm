---
id: WRK-086-LOG
type: working
status: active
owner: @weilin
created: 2026-07-31
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
landed-into:
---

# WRK-086 · 文档治理日志

> 仅追加已确认事实。猜测、计划和未复现问题留在 [`CHARTER.md`](CHARTER.md) 的批次/frontier，不写入本日志。

## 2026-07-31 · PREP-000 · Goal 启动基线

- 起点 commit：`43a7b17ee90b5227d4490657ede5bc6871b4642a`（`docs: record post-focus backend regression gate`）。
- tracked Markdown：161；`docs/` Markdown：150。
- `docs/` 分布：archive 56、references 44、working 26、decisions 20、root 2、how-to 1、concepts 1。
- 初始 `make -C docs verify` 在治理草稿产生前通过，带 1 条 warning：12 对 anchored DTO 完成镜像检查，21 个 anchor 因无同名 Go struct 跳过。此 warning 尚未裁决为缺陷。
- 已确认结构问题：
  - `docs/working/backend-evolution/archived/` 含 7 篇仍声明 `type: working / status: active` 的历史材料。
  - 当前受治理树可见重复 ID：`WRK-026` 与 `WRK-070`；另有 archive 与 working 重复，现有门禁不查唯一性。
  - `working/frontend/` 有 12 篇，其中多篇正文已明确写“全落/归档”，仍保持 active。
  - `docs/references/frontend/architecture.md` 仍称“重建中”；`concepts/architecture.md` 仍称右岛/人在环/工具卡在建。
  - 当前代码有 chat/entities/library/notifications/scheduler/settings 六个 feature，但缺完整 Chat、Scheduler current reference。
  - `frontend/README.md` 仍称 feature 是 future，和物理目录冲突。
  - `working/frontend/README.md` 同时承担协作规范、进展、路线与历史索引，且把已完成工作继续作为活入口。
  - 平台已落事实与未实施、具时效性的发行研究混在 `working/platform-foundation/`。
- Goal 启动前有 5 份未提交前端治理草稿，已在 CHARTER §8 隔离；必须在 G1 重新核对，不能计为完成证据。

## 2026-07-31 · G0-001 · 结构门禁与单一 archive

- `backend/cmd/docs` 新增低误报结构门禁：`DOC-NNN` / `WRK-NNN[-SLUG]` 语法、受治理区 ID 唯一、三个 frontmatter 日期格式、canonical 目录/type 对齐、`status: archived` 位置、working 必备 `landed-into`、working 私有 `archive|archived|legacy|old` 子树禁令。
- 新增 `main_test.go` 五组 fixture，分别校准合法树、重复 ID、type/status 错位、私有墓地/缺字段、非法 ID/日期；`go test ./cmd/docs` 与 `go vet ./cmd/docs` 通过。
- 新门禁首次对真实仓库打出 25 个错误：17 篇 working 缺 `landed-into`、7 篇旧 iteration 位于 `working/backend-evolution/archived/`、2 组重复 ID（重叠计数）。逐项修复后 `make -C docs verify` 恢复通过。
- 旧 iteration 七篇材料迁入唯一墓地 `docs/archive/backend-evolution-v1/`，保留历史 frontmatter 并标 `status: archived` / `landed-into`；current HISTORY、README 与 testend R23 链接已改到新路径。
- GOVERNANCE §3/§4/§5/§11 与 CLAUDE 文档门禁摘要同步到实际实现；同时纠正 GOVERNANCE 旧文中“ADR git 历史已机械校验”的不实陈述——该项仍靠人工清单。
- 当前唯一 warning 仍是 DTO 镜像覆盖统计（12 checked / 21 skipped），留待 G1/G5 依据类名投影语义逐项裁决。
