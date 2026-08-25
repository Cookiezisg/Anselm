# EDGE-089 draining 最后一个 run 结算

- **结论**：pass（real black-box workflow）
- **验证目标**：对有在途 approval run 的 active workflow 执行 `:deactivate`，状态先变 draining、不杀 run；人工决策使最后 run 结算后，workflow 才收口 inactive。
- **Focused command**：`cd testend && mise exec -- go test ./scenarios -run 'TestContractWorkflow_DeactivateDrainsToInactive' -count=1 -v`
- **结果**：真实 HTTP 场景 PASS；deactivate 返回 draining，run 保持 running，决策后 run completed，workflow 最终 inactive。

Levels 2-5 are intentionally `na`: no independent formal frame/timing/beauty/discoverability evidence was captured for this lifecycle scenario.
