# Batch 83 · unified gate

日期：2026-08-29

## 批次

- 本批账本前线已完成 `50/50` 个新格；本批真实 App 复验均只把可证明的数据真相写入 L2，L3-L5 继续按证据边界保持 `na`。
- formal journal：`2011` 条 live judgments；`2300` 条 coverage baseline 不计入实时漂移曲线。
- `COVERAGE`：`848 rows / 848 carried judgments / 0 tombstones`。
- `P12` 的 400+ Journey 扩写仍按用户裁定推迟到二期；一期以 COVERAGE 清册为覆盖真相源。

## Verification

- `make verify`：backend、frontend、docs、demo 全部通过。
- `make -C backend testend`：全量黑盒场景通过，`348.444s`。
- `make -C backend verify`：Go format、build、vet、tests 全部通过。
- `make -C docs verify`：通过；保留 6 条既有 review-due/DTO drift warning，无阻断错误。
- `make -C frontend verify`：通过；`5446` 项测试全绿，analyzer `No issues found`。
- `python3 -m unittest discover -s testend/rig -p 'test*.py'`：`51/51` 通过。
- `anchors.py check`：`10/10`，校准通过并解锁。
- `alarms.py check`：clean（`2011 live judgments; 2300 baseline judgments excluded`）。
- `gen_coverage.py --check`：clean（`848 rows, 848 carried judgments, 0 tombstones`）。
- `git diff --check`、`bash -n testend/rig/*.sh`、全仓 tracked Go `gofmt` 检查：clean。
- formal process audit：无 `anselm-server`、`llama-server`、`flutter_tester`、`testend-bin`、`llmtap`、`ssetap` 或正式 App 残留；formal `current` link 已清除。

## Stop-and-fix

- 首次根门禁只发现合并改动中的 3 个 Dart 文件未格式化，以及 5 个 analyzer issue；已按仓库 formatter/analyzer 规则修复。
- 修复后重新执行 frontend verify 和根 `make verify`，均通过；没有降低法典、告警阈值、锚点或账本 gate。

## Boundary

- 统一门禁通过只证明本批代码、台架和账本的一致性，不把 L2 证据扩大为 L3 顺滑、L4 视觉 craft 或 L5 可发现性。
- 本证据只覆盖本批收口；未提交的另一团队业务/API Serve 改动未纳入本次 acceptance commit。
