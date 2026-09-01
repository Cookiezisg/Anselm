# EDGE-180 embedder 孤儿回收：L3 真实时序

- 结论：`pass`。
- 第一段录屏：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-215722/screen.mov`，时长 `78.105s`；崩溃后的稳定错误帧保存在该 session 的 `frames-edge180/crash-*.png`。
- 第二段录屏：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-215934/screen.mov`，时长 `48.571667s`；恢复后的稳定 Chat 帧保存在该 session 的 `frames-edge180/recovered-*.png`。

第一段真实搜索启动 embedder 后对 backend 发送 `SIGKILL`。Computer Use 观察到 App 从正常 Chat 收敛为 `Can't reach the local engine` 错误门并给出 `Retry`，不是继续假装服务健康；独立 backend/SSE journal 同时显示 sidecar 已断开。第二段重新启动后，真实搜索在回收旧 PID 后返回结果，旧 PID `62153` 消失，新 PID `62689` 进入 ready，且没有等待模型重新下载。

恢复后真实 App 的稳定画面回到正常 Chat，frontend console 只有启动时的 Dart VM service 行，没有 `FlutterError`、`DartError`、`RenderFlex`、`Unhandled Exception` 或 `overflow`。该时序由 backend 日志、PID 进程观测、REST 响应、SSE 连接和两段录屏交叉核对。

判定依据：`CODEX B2`。本格测的是崩溃到可见终态以及恢复到可用结果的时序，不将 L2 的“数据一致”重复算作顺滑。
