# EDGE-118 暂停期间的 Edit 何时生效

- 结论：`pass`（L1 应用与真实 HTTP 行为）；L2-L5 按当前台架边界记 `na`。
- 预期：暂停 → Edit 修改 cron/config 时不热更新；`:resume` 使用当前配置重新注册，不能继续使用旧配置或提前触发。

## 证据

应用层配置时序回归：

```text
cd backend && mise exec -- go test ./internal/app/trigger -run '^TestEdit_WhilePaused_DefersConfigToResume$' -count=1 -race -v
--- PASS: TestEdit_WhilePaused_DefersConfigToResume (0.03s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/trigger 1.563s
```

真实产品路径：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestTrigger_SensorPauseRestartResume$' -count=1 -v
--- PASS: TestTrigger_SensorPauseRestartResume (16.50s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 17.142s
```

该真实路径暂停 sensor、硬重启并在暂停期间编辑目标 function；暂停窗口保持无 activation/run，恢复后 source 用编辑后的配置重新注册并成功触发新的 sensor-origin run。

## 判定边界

L2-L5 暂记 `na`：本格没有独立 Computer Use 逐帧、测量、视觉美观与 discoverability 证据；真实 HTTP 只用于确认时序语义。
