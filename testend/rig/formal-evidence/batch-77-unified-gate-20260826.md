# Batch 77 · unified gate

## Batch

- `EDGE-291..300`，10 个边界 × 5 级 = 50 个账本格。
- formal journal=`3986`（2300 baseline + 1686 live）。
- `COVERAGE=848 rows / 797 carried judgments / 0 tombstones`。
- 十行均为 `✓~~~~`：L1 聚焦证据通过，L2-L5 因无真实 App/五通道 session 诚实记 `na`。

## Verification

- `make verify`：backend、frontend、docs、demo 全绿。
- `make -C backend testend`：全量黑盒通过，`317.876s`。
- `python3 -m unittest discover -s testend/rig -p 'test*.py'`：`Ran 51 tests ... OK`。
- `make -C backend verify`：Go test/build/vet/gofmt 全绿。
- `make -C docs verify`：文档验证通过，保留 6 条既有 review-due/drift warning。
- `python3 testend/rig/gen_coverage.py --check`：clean。
- `python3 testend/rig/anchors.py check .../anchor-quiz.json`：10/10，通过。
- `RIG_HOME=... python3 testend/rig/alarms.py check`：clean，1686 live judgments。
- `bash -n testend/rig/*.sh`、gofmt、`git diff --check`：clean。
- 进程名审计：无 `anselm-server`、`llama-server`、`testend-bin` 残留。

## Notes

rig 单测中的 drift fixture、sequence-policy refusal、i2v unavailable 是故意覆盖的失败/降级分支，最终 unittest 结果为 `OK`；没有把这些诊断输出误记为产品失败。
