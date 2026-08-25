# EDGE-115 暂停时 `:fire` 大声拒

- 结论：`pass`（L1 可验证行为）；L2-L5 按当前台架边界记 `na`，没有真实 Computer Use 视觉证据，不将其伪造为通过。
- 预期：已暂停的 trigger 无论从应用层手动 fire 还是 HTTP `:fire` 入口都必须拒绝；暂停跨硬重启保持有效；恢复后才允许下一次真实 cron 运行。

## 证据

应用层精确回归：

```text
cd backend && mise exec -- go test ./internal/app/trigger -run '^TestPause_GatesFiringAtTheSource$' -count=1 -race -v
PASS
```

该测试验证暂停后 source 已注销，`onReport` 不产生 activation/firing，`FireManual` 返回 `ErrPaused`。

真实产品路径：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestTrigger_PauseResume_CronGate$' -count=1 -v
--- PASS: TestTrigger_PauseResume_CronGate (71.12s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 71.450s
```

真实 HTTP `POST /api/v1/triggers/<id>:fire` 在 paused 状态返回 `422`；随后执行硬重启，跨下一个 cron 边界确认没有 flowrun/activation；恢复后下一次真实 cron fire 成功并记录 `origin=cron`。

## 判定边界

L2-L5 暂记 `na`：本格没有 Computer Use 帧、前端 console、完整 SSE tap 和可审计的发现性/美学证据。后续若补齐这些通道，必须重新裁决，不能把本次 L1 证据升级使用。
