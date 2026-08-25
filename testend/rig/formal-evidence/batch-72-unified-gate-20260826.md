# Batch 72 · EDGE-241..250 unified gate

## Scope

`EDGE-241..250` 共 10 个边界、50 个账本格，全部按顺序落账为 `✓~~~~`：L1 为 focused regression
或已核对的真实证据，L2-L5 在本轮没有新的完整 App 五通道 session 时明确为 `na`。本批没有修改 CODEX、
警报阈值或锚点。

## Gate results

- 根 `make verify`：backend、frontend、docs、demo 全部通过。
- `make -C backend testend`：`github.com/sunweilin/anselm/testend/scenarios` 通过，`281.814s`。
- `python3 -m unittest discover -s testend/rig -p 'test_*.py' -v`：`51/51`，`OK`。
- `make -C backend verify`：通过。
- `make -C docs verify`：通过；仅仓库既有 6 条 review-due/DTO warning，无新增 failure。
- anchors：`10/10` calibration passed。
- alarms：`clean (1436 live judgments; 2300 baseline judgments excluded)`。
- `gen_coverage.py --check`：`848 rows / 747 carried judgments / 0 tombstones`。
- Python compile、全部 rig shell `bash -n`、backend `gofmt -l`、`git diff --check`：通过。
- testend/Flutter/llama/tap 进程收台审计：无残留。

## Result

批次七十二满足“50 格后统一门禁”的提交条件。下一原子前线为 `EDGE-251`；P12 的 400+ Journey
扩写仍按用户裁定推迟二期。
