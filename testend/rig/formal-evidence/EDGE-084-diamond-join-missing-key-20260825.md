# EDGE-084 菱形 join 未守 has()

- **结论**：pass（scheduler regression）
- **验证目标**：静态 capability-check 允许汇合节点读取结构祖先；若运行时 control 选择另一分支，被跳过分支绑定空 map，未用 `has()` 的字段读取必须大声失败为 `no such key`，不得制造字段值。
- **代码变更**：新增 `TestWalk_DiamondJoinUnselectedBranchFailsLoudly`，只增加回归护栏，不改变产品逻辑。
- **Focused command**：`mise exec -- go test ./internal/app/scheduler -run 'TestWalk_(LoopOverflow_FencepostAtMaxPlusOne|DiamondJoinUnselectedBranchFailsLoudly)' -count=1 -race -v`
- **结果**：菱形分支测试 PASS；run 为 failed，错误保留 `field "r" ("fallback.missing")` 的缺失字段上下文。

Levels 2-5 are intentionally `na`: this deliberate author-responsibility runtime edge has no independent real-app frame, timing, beauty, or discoverability evidence.
