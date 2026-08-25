# EDGE-200 attachment blob GC only at boot

- 结论：`pass`（L1 deletion/GC lifecycle invariant）；L2-L5 按当前独立台架边界记 `na`。
- 目标：删除附件行时不扫描或删除 blob；只有启动期按每个 workspace 的 live SHA 保留集清扫，避免与
  在飞上传的 `Put -> row Create` 顺序产生竞态。共享同一 SHA 的活跃附件必须继续保留，孤儿 blob 才能回收。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/attachment \
  -run '^(TestDelete_KeepsBlobUntilGC|TestGC_RefcountBySHA)$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/attachment 1.967s

cd backend && mise exec -- go test ./internal/infra/fs/blob \
  -run '^TestSweep_' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/fs/blob 1.623s

cd backend && mise exec -- go test ./internal/bootstrap \
  -run '^TestBuild_(ServesHealth|GuardsWorkspaceRoutes)$' \
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/bootstrap 3.082s
```

`Service.Delete` 只软删附件行，不触碰 blob。`Service.GC` 从仓库读取 live SHA 保留集后调用 blob
store 的 `Sweep`；共享 SHA 在仍有一条活跃行时保留，只有孤儿 blob 被删除。启动装配为每个 workspace
先执行 attachment GC，再启动 media worker；代码注释明确记录删除期不扫描的原因：上传先写 blob、后建
数据库行，删除期扫描会与该窗口竞态。启动期不存在这条在飞上传竞态。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成真实上传、删除、重启后的五通道 GC 录制
L3 na: 没有本格独立的磁盘占用、回收耗时和重启前后 blob 集合测量
L4 na: 没有本格独立的存储状态或回收结果 UI 视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解“删除后重启才回收”的 discoverability session
```

## source anchors

- `backend/internal/app/attachment/attachment.go`: Delete 与 GC 的职责边界
- `backend/internal/bootstrap/build.go`: 启动期按 workspace GC，完成后才启动 media worker
- `backend/internal/infra/fs/blob/blob.go`: live SHA keep-set sweep
