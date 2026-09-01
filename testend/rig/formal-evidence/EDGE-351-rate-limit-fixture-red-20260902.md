# EDGE-351 | 429 不动钱 | 台架红证据

## 红场原因

首次重跑 session=`/private/tmp/anselm-rig-formal-20260902-30/sessions/20260902-053623` 使用了
`quota-http` + `429`，但 llmtap 的旧 fixture 无论状态码都返回 `QUOTA_EXHAUSTED`。真实 App 因此显示额度耗尽；
这是台架契约错误，不是目标产品行为，未写入验收账本。

## 修复

`testend/cmd/llmtap/main.go` 现按网关语义区分：`429` 返回 `RATE_LIMITED`，`402` 仍返回
`QUOTA_EXHAUSTED`；`main_test.go` 已锁定两种响应体，`testend/rig/README.md` 同步说明。修复后重新启动
隔离台架并完成正式现场。

## 处置

该 session 已收台但不计入产品证据。保留本文件用于证明验收过程没有把错误 fixture 判绿。
