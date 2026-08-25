# EDGE-205 · 朗读缓存 LRU 淘汰

## 判定范围

本证据只覆盖 L1 功能正确性。独立真实 App、SSE、网关语音线缆和逐帧视觉 session 尚未为本格单独封存，不能把本地回归扩大解释为 L2-L5。

## 复现命令

```text
cd backend
mise exec -- go test ./internal/infra/store/attachment -run 'TestSpeechCache' -count=1 -race -v
```

结果：`PASS`。

## 观察

- `Put` 会在当前 workspace 内按 `last_used_at` 从旧到新淘汰，直到回到传入预算。
- 新写入的条目不会被自身淘汰，并返回被淘汰附件 ID，供上层软删除附件。
- `Lookup`、`Delete` 和淘汰扫描由 ORM 的 `workspace_id` 自动隔离。
- `TestSpeechCachePut_EvictsOnlyTheCurrentWorkspace` 以两个 workspace、各自不同缓存大小验证：`ws_1` 超预算只淘汰 `ws_1` 的旧附件，`ws_2` 的缓存保持可读。
- `TestSpeechCacheDelete_IsWorkspaceScopedAndIdempotent` 验证相同 cache key 的跨 workspace 行不会互删，重复删除幂等。

## 结论

L1 通过。L2-L5 暂不判定，等待后续正式台架 session。
