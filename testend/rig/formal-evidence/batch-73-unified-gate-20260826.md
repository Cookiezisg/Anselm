# Batch 73 · unified gate

日期：2026-08-26

## 账本与控制面

- 批次：`EDGE-251..260`，50/50 格，目标行均为 `✓~~~~`。
- formal journal：`3786`（2300 baseline + 1486 live）。
- `gen_coverage.py --check`：`848 rows / 757 carried judgments / 0 tombstones`。
- `anchors.py check`：10/10，formal rig judge 解锁。
- `alarms.py check`：clean。
- 独立警报复审：`batch-73-ledger-alarm-reaudit-20260826.md`。

## 工程门禁

- 根 `make verify`：backend、frontend、docs、demo 全部通过。
- `make -C backend testend`：通过，`337.821s`。
- `make -C backend verify`：通过。
- `make -C docs verify`：通过；仅报告仓内既有 6 条 review-due/DTO drift warning，本批未新增。
- rig Python unittest：`51/51` 通过。
- Python `py_compile`：通过。
- rig shell `bash -n`：通过。
- `git diff --check`：通过。
- 进程/工作树审计：提交前复核；不得遗留本批测试启动的 backend、sandbox 或 recorder 进程。

## 范围声明

本批 L2-L5 均为 `na`。统一门禁证明工程回归、黑盒契约与验收仪器本身健康，不替代后续真实桌面 App、真实受管网关、Computer Use 逐帧和五通道 session。P12 的 400+ Journey 扩写继续按用户裁定推迟二期。
