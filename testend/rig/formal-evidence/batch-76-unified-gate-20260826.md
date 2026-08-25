# Batch 76 · unified gate

## 批次范围

- 单格：`EDGE-281..290`，50 个账本格，目标行均为 `✓~~~~`。
- formal journal：`3936`（2300 baseline + 1636 live）。
- 清册：`848 rows / 787 carried judgments / 0 tombstones`。
- anchors：`10/10`；最终 `alarms.py check` 为 clean。
- L2-L5：全部明确 `na`；本批没有真实 App/Computer Use/五通道 session，未冒充五级绿。

## 统一门禁结果

- 根目录 `make verify`：backend、frontend、docs、demo 全部通过。
- `make -C backend testend`：`322.971s`，`github.com/sunweilin/anselm/testend/scenarios` 通过。
- `make -C backend verify`：Go build、test、vet、gofmt 全部通过。
- `make -C docs verify`：documentation verified；仅保留仓库既有 6 条 review-due/DTO warning，无新增失败。
- `python3 -m unittest discover -s testend/rig -p 'test*.py'`：`51 tests`，`OK`。其中 drift、sequence policy、i2v unavailable 是测试内部的预期拒绝分支，最终总结果为 OK。
- `python3 testend/rig/gen_coverage.py --check`：clean。
- `anchors.py check`：calibration passed，10 anchors。
- `alarms.py check`：clean（1636 live judgments，baseline excluded from drift curves）。
- `gofmt`、`testend/rig/*.sh bash -n`、`git diff --check`：clean。
- 测试/台架进程审计：无残留 `anselm-testend`、`anselm-rig`、backend server、tap 或 Flutter runner。

本批没有源代码修复；工作树审计通过后，提交批次证据与 working 当前前线文档。
