# EDGE-189 Changed 队满丢事件

- 结论：`pass`（L1 non-blocking notifier + reconcile self-heal contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：批量写入打满非阻塞 Changed 队列时，业务调用立即返回且允许丢事件；启动/对账通过 stamps
  自愈恢复活实体并清除孤儿，不把索引丢事件伪装成永久成功。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/search \
  -run '^TestIndexer_QueueOverflowIsNonBlockingAndBootReconcileHeals$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/search 1.553s
```

随后运行该包完整 race 回归：

```text
cd backend && mise exec -- go test ./internal/app/search -count=1 -race
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/search 1.359s
```

测试先填满 `queueSize=1024`，再从真实 `Notifier.Changed` 发 live entity 变更并以 100ms 上限证明不阻塞；
随后启动单 worker 执行 reconcile，按 source/index stamps 重新投影被丢的 `fn_live`，同时把只在索引中的
`fn_orphan` 投影为空并删除。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成批量写入与 boot 对账的真实 App 五通道录制
L3 na: 没有本格独立队列满时业务反馈与恢复等待的 Computer Use 时序测量
L4 na: 没有本格独立批量写入降级与搜索恢复的视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解索引异步自愈状态的 discoverability session
```
