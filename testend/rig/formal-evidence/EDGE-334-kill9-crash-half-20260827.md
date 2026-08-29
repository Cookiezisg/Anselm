# EDGE-334 Kill9 崩溃半场复验

本次按 `EDGE-334` 的台架契约直接重跑真实 `testend` harness，不把优雅 SIGTERM 当作崩溃替身，也不把这条
testend 基础设施路径伪装成真实 App 五级产品验收。

执行命令：

`mise exec -- go test ./scenarios -run 'TestContractChat_CrashSweepOrphans|TestWorkflow_CrashRecovery|TestAttachmentPreparation_CrashRequeuesInterruptedWork|TestP4bRail_GeneratingNoResidueAfterCrash' -count=1 -v`

结果：四项全部 `PASS`，总耗时约 `64.046s`。输出实际观察到：

- chat 崩溃后启动执行 `swept orphaned non-terminal turns`；
- workflow 崩溃后恢复并保留已完成节点，不重复执行；
- attachment preparation 崩溃后记录 `requeued interrupted work`；
- generating rail 崩溃后无残留运行状态，sandbox/embedder 进程被收容。

这次复验确认 `Kill9` 仍是不可软化的崩溃路径。该行原有 L1/F5 保持不变，L2-L5 仍无真实 App 证据，未伪造
新判决，也未增加当前 50 格批次计数。
