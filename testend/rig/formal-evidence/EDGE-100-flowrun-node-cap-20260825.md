# EDGE-100 LLM 工具 flowrun 节点封顶

- **结论**：pass（LLM 工具投影封顶，REST 仍可取全量）
- **验证目标**：对数千行 loop run 调用 `get_flowrun` 时，工具结果不能把全部 node rows 倾倒进模型上下文；必须保留全部非 completed 行、最近 completed 尾巴，附真实 `nodeSummary`，并指向 REST 分页获取完整集合。耐久数据库行不得被工具投影截断。
- **Focused commands**：`cd backend && mise exec -- go test ./internal/app/tool/workflow -run 'Test(CapFlowrunNodes|CapFlowrunNodesAtMaxIterationsScale|GetFlowrunDescriptionStatesLargeRunProjection)' -count=1 -race -v`；`cd testend && mise exec -- go test ./scenarios -run '^TestWorkflow_DeepLoopPersistsEveryIteration$' -count=1 -v`
- **结果**：新增的 2001-row scale regression `-race` 通过，投影严格为 80 行，保留 failure/parked 两类非 completed 节点且 summary 的 total/shown/byStatus 正确；真实 HTTP 25 轮 loop 通过，REST 分页取回全部 52 行、每轮唯一、执行审计 join 完整。真实 testend 收台时 search health warning 是取消上下文噪声，不是场景失败。

Levels 2-5 are intentionally `na`: this cell verifies an LLM-context safety projection and REST data truth; no independent Computer Use frame, timing capture, visual/beauty review, or discoverability session was made.
