# EDGE-011 · execution_group 并发与结果顺序

## Verification

`runToolsWithLedger` 为每个输入调用预分配独立下标槽；同一 `execution_group` 由 goroutine 并行执行，
结束后按原调用序拍平，避免并发完成顺序污染 transcript。新增 `TestRunTools_SameExecutionGroupActuallyRunsConcurrently`
使用两个屏障工具：只有两个工具都已开始后才释放执行，并断言最终 block 顺序仍为 `a`、`b`。

验证结果：

```text
go test ./internal/app/loop -run 'TestRunTools_(ResultsIndexAligned|SameExecutionGroupActuallyRunsConcurrently)' -count=1  PASS
go test -race ./internal/app/loop -run 'TestRunTools_(ResultsIndexAligned|SameExecutionGroupActuallyRunsConcurrently)' -count=1  PASS
```

## Five-level applicability

- L1 `pass`: 同组确实并行、每个结果回到对应输入下标且 race detector 无报告；测量法
  `measure:edge011-parallel-index-order`。
- L2 `na`: 本条是 loop 内部并发/顺序不变量，本轮没有为它单独启动真实 managed gateway 五通道 session。
- L3 `na`: 没有真实 App 录屏和动作到首反馈时延测量；单元测试不冒充逐帧流畅度证据。
- L4 `na`: 并发拍平是内部执行协议，没有独立的视觉几何/动效表面；工具卡视觉由相应 chat tool-card
  旅程覆盖。
- L5 `na`: execution group 不是用户可导航的入口，而是模型与 loop 之间的内部调度字段。
