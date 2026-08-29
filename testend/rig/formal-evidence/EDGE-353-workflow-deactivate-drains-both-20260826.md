# EDGE-353 workflow 停用排空双类

- 判定对象：`:deactivate` 同时面对在飞 run 与已接受 pending firing 时，必须保持 draining，直到两类都结算后才进入 inactive。
- 证据：`go test -count=1 ./internal/app/workflow ./internal/infra/store/workflow ./internal/infra/store/flowrun ./internal/transport/httpapi/handlers` 全绿；testend `TestContractWorkflow_DeactivateDrainsToInactive` 与 `TestContractWorkflow_DeactivateDrainsAcceptedFiring` 全绿（`13.974s`）。
- 产品判断：停用不是“关开关后遗留后台运行”，也不会丢掉已接受的触发；用户可观察到 drain 完成后的 inactive 终态。
- 法条：F1、F2。
