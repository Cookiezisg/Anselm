# EDGE-278 · 文档 Move 防环

## L1 focused evidence

- `backend/internal/app/document/document_test.go:TestMove_CycleGuard` 通过。
- `testend/scenarios/contract_docs_att_test.go:TestContractDocsAtt_DocumentChildrenDuplicateMove` 通过，父节点移到自身后裔时返回 `422 DOCUMENT_INVALID_PARENT` 且不变更树。

## 判定

L1=`E1`：循环原因大声表达，非法 Move 不产生部分持久化。L2-L5 本批未启动真实 App，记 `na`。
