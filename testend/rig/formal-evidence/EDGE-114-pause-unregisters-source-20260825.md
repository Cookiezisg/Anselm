# EDGE-114 trigger 暂停在源头注销

- **结论**：pass（pause 注销 source listener，竞态报告被丢弃，resume 才重新注册）
- **验证目标**：cron、webhook、fsnotify、sensor 四类 trigger 在 pause 时都必须调用各自 source 的 `Unregister`，而不是仅在 fan-out 层过滤；真实 source 在重启后保持暂停，resume 后恢复监听。
- **Focused regression**：`cd backend && mise exec -- go test ./internal/app/trigger -run '^TestPause_UnregistersEverySourceKind$' -count=1 -race -v`
- **Product paths**：`cd testend && mise exec -- go test ./scenarios -run '^TestTrigger_(FsnotifyPauseRestartResume|SensorPauseRestartResume)$' -count=1 -v`
- **结果**：四种 kind 的 app regression 均断言 source 注销恰好一次并通过；真实 fsnotify 与 sensor 场景均通过 pause → hard restart → no new firing → resume → source recovery，未发现源头漏闸。

Levels 2-5 are intentionally `na`: the product paths prove source lifecycle behavior but did not include an independent Computer Use frame, timing capture, visual/beauty review, or discoverability session for this edge.
