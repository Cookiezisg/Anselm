# EDGE-209 · 附件无自动保留线

## 判定范围

本证据覆盖 L1 附件生命周期与 blob 回收边界。独立真实 App、长时间积累、SSE、逐帧视觉和手动清理 discoverability session 尚未为本格封存。

## 复现命令

```text
cd backend
mise exec -- go test ./internal/app/attachment -run '^Test(Delete_KeepsBlobUntilGC|GC_RefcountBySHA)$' -count=1 -race -v
```

结果：`PASS`。

## 观察

- 普通附件不会因时间或上传流程被自动删除。
- 显式删除只软删 metadata，blob 在显式 GC 前仍存在。
- GC 只清理没有任何 live metadata 引用的 blob；共享 blob 仍被保留。

## 结论

L1 通过。L2-L5 暂不判定，等待后续正式台架 session。
