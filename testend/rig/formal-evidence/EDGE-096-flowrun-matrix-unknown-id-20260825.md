# EDGE-096 flowrun-matrix 未知 id

- **结论**：pass（flowrun matrix isolation and empty shape）
- **验证目标**：异 workspace 或不存在的 flowrun id 静默缺席，不泄漏也不报错；混合请求只返回当前 workspace 已知列；全未知返回 `cols=[]/rows=[]/cells=[]`，不是 `null`。
- **Focused commands**：`cd backend && mise exec -- go test ./internal/infra/store/flowrun ./internal/app/scheduler -run 'Test(RunMatrix_IsolationAndEmptyShape|RunMatrix_BareCtxRejected|RunMatrix_EmptyIDsRejected|RunMatrix_DedupPreservesOrder)' -count=1 -race -v`；`cd testend && mise exec -- go test ./scenarios -run TestFlowrunMatrix_Grid -count=1 -v`
- **结果**：store isolation/empty shape、bare context rejection、app input guards 全通过；真实 HTTP scenario 通过已知+未知、全未知空三列表、空参数、上限和去重边界。testend 的 search shutdown warning 是 harness 取消时的预期收台噪声，不是场景失败。

Levels 2-5 are intentionally `na`: no independent real-app frame, timing, beauty, or discoverability capture was made for this scheduler projection boundary.
