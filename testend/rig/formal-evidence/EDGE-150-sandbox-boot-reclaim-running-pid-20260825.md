# EDGE-150 sandbox boot 回收 running_pid

- 结论：`pass`（L1 sandbox boot survivor/process-group reclaim 语义）；L2-L5 按当前台架边界记
  `na`。
- 预期：后端崩溃后 manifest 可能保留常驻子进程 PID。boot 必须真实收割记录 PID，并清掉
  `running_pid`；对于 uvx/npx 这类 wrapper，还必须杀掉同进程组的孙进程，不能留下不可见服务。

## focused real-process regressions

```text
cd backend && mise exec -- go test ./internal/app/sandbox -run '^TestRestoreOnBoot_Kills(SurvivorAndClearsManifest|GrandchildViaProcessGroup)$' -count=1 -race -v
=== RUN   TestRestoreOnBoot_KillsGrandchildViaProcessGroup
--- PASS: TestRestoreOnBoot_KillsGrandchildViaProcessGroup (0.03s)
=== RUN   TestRestoreOnBoot_KillsSurvivorAndClearsManifest
--- PASS: TestRestoreOnBoot_KillsSurvivorAndClearsManifest (0.02s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/sandbox 1.451s
```

第一条启动真实 `sleep`，把其 PID 写入 manifest，再执行 boot cleanup；`Wait` 立即返回被杀
错误，且 `ListEnvsWithRunningPID` 为空。第二条用独立进程组的 `sh` 模拟 wrapper，并派生同组
`sleep` 孙进程；boot reaper 后轮询孙进程的 `Signal(0)` 直到确认已不存在，证明使用整组
SIGKILL，而不是只杀组长。

## 判定边界

本格没有单独捕获完整真实 App 的 Computer Use 五通道 session，也没有独立视觉、等待时序或
discoverability 证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为真实进程/manifest/process-group focused 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
