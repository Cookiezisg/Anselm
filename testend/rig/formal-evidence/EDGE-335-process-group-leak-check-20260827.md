# EDGE-335 testend 进程组泄漏自检复验

本次重跑完整 `backend/make testend`，而非只执行某个单测：

`make testend` → `ok github.com/sunweilin/anselm/testend/scenarios 292.290s`

测试期间并发启动了多个真实 backend、sandbox 和 `llama-server` 进程；结束后进行独立进程审计，未发现
`testend-bin`、`anselm-server`、`llama-server` 残留，也没有遗留 pid 文件。该结果证明 harness 的
优雅停止、进程组 SIGKILL 兜底和轮询泄漏自检仍然有效；若有成员在收台后存活，cleanup 会以显式测试失败
报告而不是保持绿色。

该行原有 L1/F3 保持不变；L2-L5 需要真实 App 产品场景，不能用 testend 基础设施测试冒充，故本次不新增
账本判决或 50 格计数。
