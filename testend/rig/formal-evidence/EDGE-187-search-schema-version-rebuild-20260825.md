# EDGE-187 fts_schema_version 不匹配

- 结论：`pass`（L1 boot schema-version rebuild contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：旧 schema 版本启动时必须清空全量派生搜索索引，写入当前版本，再从 live source 重建；旧词法
  命中和旧向量都不得泄漏到新索引。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/search \
  -run '^TestStart_RebuildsOnSchemaVersionMismatch$' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/search 1.581s
```

随后运行该包完整 race 回归：

```text
cd backend && mise exec -- go test ./internal/app/search -count=1 -race
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/search 1.360s
```

测试把 `fts_schema_version` 置为旧值 `0`，预置旧 lexical hit 与旧 embedding；启动后断言恰执行一次
`DropAll`、写入当前 `schemaVersion`、从 live document source 恢复投影，并断言旧 hits/embeddings 均为空。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成真实旧库启动与五通道 App 录制
L3 na: 没有本格独立 schema 重建等待与恢复反馈的 Computer Use 时序测量
L4 na: 没有本格独立索引重建期间状态与恢复结果的视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解 schema 重建状态的 discoverability session
```
