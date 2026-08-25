# EDGE-276 · 并发同父建文档

## L1 focused evidence

- `backend/internal/app/document/document_test.go:TestCreate_ConcurrentPositionsDistinct` 通过。
- `testend/scenarios/contract_docs_att_test.go:TestContractDocsAtt_DocumentChildrenDuplicateMove` 通过，兄弟分页与 position 顺序稳定。

## 判定

L1=`F1`：同父并发创建由单事务 max-sibling 分配 distinct position，树投影不撞位。L2-L5 本批未启动真实 App，记 `na`。
