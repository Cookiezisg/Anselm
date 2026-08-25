# EDGE-153 env 在用时删除

- 结论：`pass`（L1 sandbox deletion guard）；L2-L5 按当前台架边界记 `na`。
- 预期：正在被 resident 实例占用的 env 收到 DELETE 时必须返回 `409 SANDBOX_ENV_IN_USE`，
  保留 env、running PID 和 owner lock；不能为了完成删除而静默杀进程或删目录。停止后再次
  删除才允许成功。

## focused service and atomic sibling regressions

```text
cd backend && mise exec -- go test ./internal/app/sandbox \
  -run '^(TestDestroy_RejectsRunningEnv|TestDestroyOwners_PreflightsRunningEnvBeforeDeletingSibling)$' \
  -count=1 -race -v
=== RUN   TestDestroy_RejectsRunningEnv
--- PASS: TestDestroy_RejectsRunningEnv (0.02s)
=== RUN   TestDestroyOwners_PreflightsRunningEnvBeforeDeletingSibling
--- PASS: TestDestroyOwners_PreflightsRunningEnvBeforeDeletingSibling (0.02s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/sandbox 1.451s
```

第一条确认 running PID、env row 和 owner lock 在拒删后都保留，清掉 PID 后才可删；第二条
确认 reset-all 遇到 running sibling 会在删除任何 idle sibling 前整体拒绝，不留下半成功状态。

## real HTTP product path

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestContractPlatform_SandboxGovernanceEdges$' -count=1 -v -timeout 600s
--- PASS: TestContractPlatform_SandboxGovernanceEdges (4.39s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 4.969s
```

真实 testend 先物化 function env，通过 SQLite 只把该真实 env 标成 resident PID，再从产品
HTTP DELETE 观察 `409/SANDBOX_ENV_IN_USE`；另一 workspace 仍可读到 env。清掉 PID 后同一
产品 DELETE 返回 204，随后两 workspace 都读到 404，重复 DELETE 仍是明确 404。

## 判定边界

本格没有独立完整 App Computer Use 五通道 session，也没有独立视觉、等待时序或 discoverability
证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为 service/HTTP sandbox 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
