# EDGE-117 `Edit` 与 `:pause` 并发/暂停期配置生效

- 结论：`pass`（L1 应用与真实 HTTP 行为）；L2-L5 按当前台架边界记 `na`，没有真实 Computer Use/视觉证据。
- 预期：暂停期间编辑不能偷偷重挂 source 或产生 firing；恢复时必须使用当前已编辑配置。

## 证据

应用层并发窗口回归：

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

真实 HTTP 路径在暂停后修改 sensor 的目标 function，硬重启确认暂停窗口无 activation/run；恢复后 source 重新注册并读取编辑后的目标，随后产生 sensor-origin run。日志中的 free-tier `127.0.0.1:1` provision skip 与 stale embedder 回收是测试环境预期噪声，不影响断言。

## 判定边界

L2-L5 暂记 `na`：本格没有独立录屏/逐帧、测量曲线、视觉美观和 discoverability 证据；真实 HTTP 场景只用于 L1 产品语义，不越级替代这些通道。
