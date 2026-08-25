# EDGE-122 fsnotify 秒桶去重

- 结论：`pass`（L1 应用不变量与真实 HTTP 产品路径）；L2-L5 按当前台架边界记 `na`。
- 预期：同一 path+operation 在同一 UTC 秒内的编辑器事件突发共享 dedup key；下一秒或不同 path/operation 必须产生新 key；过滤后的事件才进入 durable firing。

## 证据

应用层精确回归：

```text
cd backend && mise exec -- go test ./internal/infra/trigger/fsnotify -run '^TestDedupKey_UsesPathOperationAndSecondBucket$' -count=1 -race -v
--- PASS: TestDedupKey_UsesPathOperationAndSecondBucket (0.00s)
PASS
ok   github.com/sunweilin/anselm/backend/internal/infra/trigger/fsnotify 1.577s
```

真实产品路径：

```text
cd testend && mise exec -- go test ./scenarios -run '^TestTrigger_FsnotifyFiltersCreateEvents$' -count=1 -v
--- PASS: TestTrigger_FsnotifyFiltersCreateEvents (11.16s)
PASS
ok   github.com/sunweilin/anselm/testend/scenarios 11.447s
```

回归锁定 dedup key 的 path/operation/second bucket 三个维度；真实 HTTP fsnotify 场景锁定不匹配扩展名和 modify 不产生第二个 run，唯一匹配 create 产生一条 activation/firing/run，并保留规范化小写 `eventKind`。

## 判定边界

L2-L5 暂记 `na`：本格没有独立 Computer Use 逐帧、时延曲线、视觉美观和 discoverability 证据；应用与 HTTP 证据不越级替代这些通道。
