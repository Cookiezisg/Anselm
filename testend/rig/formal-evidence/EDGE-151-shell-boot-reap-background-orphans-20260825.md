# EDGE-151 shell boot 回收 run_in_background 孤儿

- 结论：`pass`（L1 shell boot orphan/process-group reclaim 语义）；L2-L5 按当前台架边界记
  `na`。
- 预期：后端被 `SIGKILL` 等非优雅退出打断后，`run_in_background` 留下的 pid 清单必须在
  下一次 boot 被读取，按负 pgid 收割整组进程；pid 已死亡时无害，PID 被无辜进程复用时不能
  误杀，并且清理后不留下旧清单。

## focused real-process regressions

```text
cd backend && mise exec -- go test ./internal/app/tool/shell ./internal/bootstrap \
  -run 'ReapStaleOnBoot|ShutdownReapsBackgroundShellProcs' -count=1 -race -v
=== RUN   TestReapStaleOnBoot_CrashPath_KillsWorkerGroup
--- PASS: TestReapStaleOnBoot_CrashPath_KillsWorkerGroup (0.08s)
=== RUN   TestReapStaleOnBoot_ZombieLeaderGroupStillReaped
--- PASS: TestReapStaleOnBoot_ZombieLeaderGroupStillReaped (0.08s)
=== RUN   TestReapStaleOnBoot_SparesRecycledNonLeaderPid
--- PASS: TestReapStaleOnBoot_SparesRecycledNonLeaderPid (0.02s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/tool/shell 2.043s
=== RUN   TestApp_ShutdownReapsBackgroundShellProcs
--- PASS: TestApp_ShutdownReapsBackgroundShellProcs (0.52s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/bootstrap 3.332s
```

这组测试覆盖实际 `run_in_background` 进程组、组长已成为 zombie 但组内仍有成员、以及 pid
被无辜进程复用三条危险路径；bootstrap 测试再从应用启动/关闭装配层验证清单回收，而不是
只测纯函数。

## 判定边界

本格没有单独捕获完整真实 App 的 Computer Use 五通道 session，也没有独立视觉、等待时序或
discoverability 证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为真实进程/清单/进程组 focused 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
