# Batch 80 · unified gate

## Batch

- `EDGE-321..324`、`EDGE-327..332`，10 个边界 × 5 级 = 50 个账本格；`EDGE-325/326` 已在先前批次完整收口。
- formal journal=`4136`（2300 baseline + 1836 live）。
- `COVERAGE=848 rows / 827 carried judgments / 0 tombstones`。
- 十行均为 `✓~~~~`：L1 聚焦证据通过，L2-L5 因无真实 App/五通道 session 诚实记 `na`。

## Verification

- `make verify`：backend、frontend、docs、demo 全绿。
- `make -C backend testend`：全量黑盒通过，`313.560s`。
- `python3 -m unittest discover -s testend/rig -p 'test*.py'`：`Ran 51 tests ... OK`。
- `make -C backend verify`：Go test/build/vet/gofmt 全绿。
- `make -C docs verify`：文档验证通过，保留 6 条既有 review-due/drift warning。
- `python3 testend/rig/gen_coverage.py --check`：clean。
- `RIG_HOME=... python3 testend/rig/anchors.py check .../anchor-quiz.json`：10/10，通过，校准解锁 4h。
- `RIG_HOME=... python3 testend/rig/alarms.py check`：clean，1836 live judgments。
- `bash -n testend/rig/*.sh`、gofmt、`git diff --check`：clean。
- 进程名审计：无 `anselm-server`、`llama-server`、`testend-bin` 残留。

## Notes

rig 单测中的 drift fixture、sequence-policy refusal、i2v unavailable 是故意覆盖的失败/降级分支，最终 unittest 为 `OK`。
本批所有 L2-L5 都保留为 `na`，统一门禁只证明仓内实现与账本纪律通过，不宣称真实 App 五通道验收已经完成。
