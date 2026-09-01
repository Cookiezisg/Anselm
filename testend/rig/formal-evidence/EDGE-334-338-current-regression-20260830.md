# EDGE-334..338 · 当前代码自动回归复验

日期：2026-08-30

本记录只证明当前代码的自动回归仍然通过，不把测试台架结果扩大为真实 App 的产品等级。

## 复验

- `EDGE-334`：`testend/scenarios` 的 `TestContractChat_CrashSweepOrphans`、`TestWorkflow_CrashRecovery`、`TestAttachmentPreparation_CrashRequeuesInterruptedWork`、`TestP4bRail_GeneratingNoResidueAfterCrash` 均使用 harness 的真实 `Kill9`，全部 `PASS`，总计 `64.286s`。
- `EDGE-335` 与 `EDGE-337`：`mise exec -- go test ./harness -count=1 -race -v` 通过，`TestReapStaleScratchUsesPIDLiveness` 与 `TestPrunePIDFilesKeepsRuntimeFilesOnly` 均通过。
- `EDGE-338`：`TestContractPlatform_FreetierQuota` 通过；关闭回环网关返回 `FREETIER_NOT_PROVISIONED`，未登记真实 install，真实配额分支按隔离契约跳过。
- 相邻自动前线回归：后端 `apikey/voice/generate/speech/readaloud/chat/conversation/workflow/infra/llm` 的 `-race` 测试通过；黑盒生成/语音缺席、ChatFork、workflow deactivate 三组通过；前端 provider market、Vertex credential、voices card、transcript、tool gate、speech input 共 `86` 项通过。

## 判定边界

现有 COVERAGE 的 `L1` 证据保持有效；本次没有新增账本格，也没有把 `EDGE-334..338` 的 L2-L5 provisional 格改写为 `pass` 或未经充分理由的 `na`。这些行仍需依照顺序门完成适用性裁决，或在真实 App/五通道现场补齐，而不是用自动测试代替。
