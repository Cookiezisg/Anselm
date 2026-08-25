# EDGE-085 pin 闭包冻结在途 run

- **结论**：pass（real black-box workflow）
- **验证目标**：run 起跑时钉住 function/control 版本；在 run 停泊或失败后编辑引用实体，继续原 run 仍解析旧版本，新 run 才采用新 active 版本。
- **Focused command**：`cd testend && mise exec -- go test ./scenarios -run 'TestWorkflow_ReplayKeepsOriginalFunctionPin|TestContractWorkflow_ControlRevertAndPinnedResolve' -count=1 -v`
- **结果**：两个真实 HTTP 场景 PASS。function v1 失败后编辑 v2，原 run replay 仍执行 v1 且失败，新 run 使用 v2 完成；control parked run 编辑后继续仍使用起跑时版本。测试日志中的 free-tier 失败是隔离 testend 的关闭端口，非场景失败。

Levels 2-5 are intentionally `na`: no independent formal frame/timing/beauty/discoverability evidence was captured for this backend pin boundary.
