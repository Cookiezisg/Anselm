# EDGE-083 MaxIterations 栅栏

- **结论**：pass（scheduler regression）
- **验证目标**：永真 CEL 回边最多落 `iteration 0..1000` 共 1001 条循环体行；下一回边被栅栏拒绝，run 终态为 failed，错误明确写出 `MaxIterations (1000)`。
- **Focused command**：`mise exec -- go test ./internal/app/scheduler -run 'TestWalk_LoopOverflow_FencepostAtMaxPlusOne|TestWalk_DiamondJoinUnselectedBranchFailsLoudly' -count=1 -race -v`
- **结果**：`TestWalk_LoopOverflow_FencepostAtMaxPlusOne` PASS；断言 failed、错误码语义、1001 行和最大 iteration=1000。

Levels 2-5 are intentionally `na`: this scheduler fence has no independent real-app frame, timing, beauty, or discoverability evidence.
