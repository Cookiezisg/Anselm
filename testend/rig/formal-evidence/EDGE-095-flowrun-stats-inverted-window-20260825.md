# EDGE-095 flowrun-stats 倒挂窗

- **结论**：pass（flowrun stats window contract）
- **验证目标**：当 `until <= since` 时，统计端点和 store 都静默返回空窗口而非错误；非窗口字段（recent/lastRunAt）仍按既定语义保留。
- **Focused commands**：`cd backend && mise exec -- go test ./internal/infra/store/flowrun -run TestRunStats_UntilUpperBound -count=1 -race -v`；`cd testend && mise exec -- go test ./scenarios -run TestFlowrunStats_BatchProjection -count=1 -v`
- **结果**：真实 store regression 通过 inverted-window 断言，windowed totals/successRate/avgElapsedMs 为空而 recent/lastRunAt 保持；真实 HTTP scenario `TestFlowrunStats_BatchProjection` 通过，正常上界、未来 since、超限和坏参数分别保持既有 200/422 契约。testend 中 free-tier port-1 warning 是隔离 harness 的预期关闭端口，不是该场景失败。

Levels 2-5 are intentionally `na`: no independent real-app frame, timing, beauty, or discoverability capture was made for this scheduler statistics boundary.
