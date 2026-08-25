# EDGE-255 · PageAsc collation 不一致

## L1 focused evidence

- `backend/internal/pkg/orm/page_asc_test.go:TestPageAsc_NOCASEOrderAndTiebreaker` 通过。
- `TestPageAsc_CursorWalk` 通过，验证 NOCASE 排序下跨页完整遍历与同键主键 tie-breaker。

## 判定

L1=`F1`：排序比较与游标比较使用同一 collation，分页不会因大小写顺序变化漏行或重复。L2-L5 本批未启动真实 App，记 `na`。
