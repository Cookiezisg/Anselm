# EDGE-179 首用下载途中关停

- 结论：`pass`（L1 engine shutdown contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：builtin embedder 首次下载尚未完成时收到 SIGTERM，搜索引擎必须取消 installer context，在关停预算内返回，释放下载锁，并让上层继续关闭数据库；不能把 `db.Close` 无限阻塞在首用下载上。

## focused regression

```text
cd backend && mise exec -- go test ./internal/infra/search/engine \
  -run '^TestBuiltin_CloseBoundedDuringDownload$' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/search/engine 1.579s
```

`slowEnsurer` 在首次 `EnsureTool` 内无限等待并发出 entered 信号，模拟真实首用下载持有 engine mutex；
测试随后用 2 秒 timeout 调 `Builtin.Close`，断言 Close 在 3 秒测试预算内返回，且 installer 收到取消并
发出 released。该回归直接锁住 R14：Close 先取消 in-flight install，再等待/释放锁，不让 App shutdown
被模型下载拖死。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中做真实首用模型下载与五通道 App 录制
L3 na: 没有本格独立 SIGTERM→首个可见终态的 Computer Use 时序测量
L4 na: 没有本格独立下载中关停 UI 的视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解下载中关停反馈的 discoverability session
```
