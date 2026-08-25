# EDGE-186 :reindex 并发与就地重建

- 结论：`pass`（L1 reindex single-flight/in-place contract + real HTTP reindex）；L2-L5 按当前独立台架边界记 `na`。
- 预期：同一 workspace 的第二次 reindex 必须返回 `SEARCH_REINDEX_RUNNING`，不并发重建；无关 workspace
  不应被错误阻塞；重建采用就地 force-reconcile，不先 purge 造成搜索空窗。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/search \
  -run '^(TestReindex_ConflictWhileRunning|TestReindex_PerWorkspaceLock|TestReindex_ForceRebuildsInPlaceNoPurge)$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/search 1.584s
```

focused 回归覆盖：同一 workspace 在飞时第二次冲突；`ws_a` 在飞不阻塞 `ws_b`；reindex 完成后锁可再次
取得；force-reconcile 不调用 `PurgeWorkspace`，因此不存在旧索引被清空的中间窗口。

## real black-box regression

```text
cd testend && mise exec -- go test ./scenarios \
  -run '^TestSearch_ReindexAndSettings$' -count=1 -v -timeout 600s
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 6.496s
```

真实 HTTP 场景创建 function，先确认索引命中，调用 `/api/v1/search:reindex` 得到 204，再确认命中恢复，
并继续完成 settings/off/Ollama fallback 对照。日志中的 `127.0.0.1:1` free-tier warning 是刻意无网关
fixture，服务仍正常优雅关停。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成真实并发 reindex 与五通道 App 录制
L3 na: 没有本格独立重建期间搜索/冲突反馈的 Computer Use 时序测量
L4 na: 没有本格独立 reindex 状态与空窗避免的视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解 reindex 单飞状态的 discoverability session
```
