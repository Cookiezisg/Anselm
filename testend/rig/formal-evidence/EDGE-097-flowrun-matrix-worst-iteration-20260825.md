# EDGE-097 matrix 多迭代最坏处置

- **结论**：pass（flowrun matrix iteration projection）
- **验证目标**：同一 loop 节点多轮中，`failed` 永远压过后续 `completed`；`parked` 压过 `completed`；cancelled 是中性而非绿/红，并保留 run 的真实终态。
- **Focused commands**：`cd backend && mise exec -- go test ./internal/infra/store/flowrun -run 'TestRunMatrix_(IterationsAggregateWorstWins|CancelledRankIsNeutralNotGreenNotRed|ParkedOutranksCompletedAndTieTakesLatest)' -count=1 -race -v`；`cd testend && mise exec -- go test ./scenarios -run TestFlowrunMatrix_Grid -count=1 -v`
- **结果**：store `-race` 三个 rank/iteration regression 通过；真实 HTTP matrix scenario 通过，跨多轮矩阵状态没有把历史失败洗成成功。收台时 search health warning 是 testend 取消时的预期噪声，不是 scenario failure。

Levels 2-5 are intentionally `na`: no independent real-app frame, timing, beauty, or discoverability capture was made for this scheduler projection invariant.
