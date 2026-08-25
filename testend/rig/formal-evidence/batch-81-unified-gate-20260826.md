# Batch 81 · unified gate

## Batch

- `EDGE-333..342`，10 个边界 × 5 级 = 50 个账本格。
- formal journal=`4186`（2300 baseline + 1886 live）。
- `COVERAGE=848 rows / 837 carried judgments / 0 tombstones`。
- 十行均为 `✓~~~~`：L1 focused/targeted evidence 通过，L2-L5 因无真实 App/五通道 session 诚实记 `na`。

## Verification

- `make verify`：backend、frontend、docs、demo 全绿。
- `make -C backend testend`：全量黑盒通过，`313.607s`。
- `python3 -m unittest discover -s testend/rig -p 'test*.py'`：`Ran 51 tests ... OK`。
- `make -C backend verify`：Go test/build/vet/gofmt 全绿。
- `make -C docs verify`：文档验证通过，保留 6 条既有 review-due/drift warning。
- `python3 testend/rig/gen_coverage.py --check`：clean。
- `RIG_HOME=... python3 testend/rig/anchors.py check .../anchor-quiz.json`：10/10，通过，校准解锁 4h。
- `RIG_HOME=... python3 testend/rig/alarms.py check`：clean，1886 live judgments。
- `bash -n testend/rig/*.sh`、gofmt、`git diff --check`：clean。
- 进程名审计：无 `anselm-server`、`llama-server`、`testend-bin` 残留。

## Notes

rig 单测中的 drift fixture、sequence-policy refusal、i2v unavailable 是故意覆盖的失败/降级分支，最终 unittest 为 `OK`。
本批仍不把仓内 focused/testend 结果冒充真实 App 五通道验收；L2-L5 的 `na` 保持诚实，待后续真实台架会话逐格复验。
