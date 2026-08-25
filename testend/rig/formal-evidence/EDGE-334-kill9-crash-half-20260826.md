# EDGE-334 · testend Kill9 崩溃半场

## L1 focused evidence

- `testend/scenarios` targeted run 通过：`TestContractChat_CrashSweepOrphans`、`TestWorkflow_CrashRecovery`、`TestAttachmentPreparation_CrashRequeuesInterruptedWork`、`TestP4bRail_GeneratingNoResidueAfterCrash` 均使用 harness 的真实 `Kill9` 路径。
- `make -C backend testend` 全量通过，未把 SIGTERM 优雅链替代为崩溃模拟。

## 判定

L1=`F5`：硬崩溃现场保留到下一次启动，恢复/清扫以持久数据为依据，不被优雅收台提前抹掉。L2-L5 本批未启动真实 App，记 `na`。
