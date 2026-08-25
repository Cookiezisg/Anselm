# EDGE-123 暂停时 `nextFireAt` 缺席

- 结论：`pass`（L1 应用与真实 HTTP 投影）；L2-L5 按当前台架边界记 `na`。
- 预期：暂停 cron trigger 的读投影必须是 `paused=true`、`listening=false`，且完全省略 `nextFireAt`；提供未来时间戳会误导用户。

## 证据

应用层回归：

```text
cd backend && mise exec -- go test ./internal/app/trigger -run '^TestPause_GatesFiringAtTheSource$' -count=1 -race -v
--- PASS: TestPause_GatesFiringAtTheSource (0.03s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/app/trigger 1.798s
```

真实产品路径：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestTrigger_PauseResume_CronGate$' -count=1 -v
--- PASS: TestTrigger_PauseResume_CronGate (124.77s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 125.047s
```

真实 HTTP 读侧在暂停后返回 `paused=true`、`listening=false` 且 JSON 完全不含 `nextFireAt`；硬重启跨 cron 边界仍保持该投影且没有 run/activation，resume 后下一次真实 cron run 成功。测试环境 free-tier port-1 provision skip 与模型目录刷新日志是预期环境噪声。

## 判定边界

L2-L5 暂记 `na`：本格没有独立 Computer Use 逐帧、时延曲线、视觉美观和 discoverability 证据；HTTP 投影证据不越级替代这些通道。
