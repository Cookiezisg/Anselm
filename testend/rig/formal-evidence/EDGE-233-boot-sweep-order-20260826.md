# EDGE-233 · boot 顺序 SweepMisfires

## L1 focused evidence

- `backend/internal/app/workflow/execution_test.go:TestReattachActive_UsesReplayPath` 通过 boot replay 路径重挂 active workflow；通过。
- `backend/internal/app/trigger/misfire_test.go` 的 SweepMisfires 幂等、暂停/监听状态与 watermark 回归均通过。
- `backend/internal/bootstrap/build.go` 的 boot 顺序明确先 `ReattachActive`，再按 workspace 调 `SweepMisfires`；该顺序与测试路径一致。

## 判定

L1=`F5`：重启后的监听状态先恢复，misfire 扫描不在空监听表上制造假账。L2-L5 本轮没有真实重启 App 五通道 session，记 `na`。
