# EDGE-277 · 文档改名子树级联

## L1 focused evidence

- `backend/internal/app/document/document_test.go:TestUpdate_PathCascade` 通过三层 path 级联。
- 黑盒 `TestContractDocsAtt_DocumentNameGuardsSoftDelete` 同批文档生命周期场景通过，读侧可见 materialized path。

## 判定

L1=`F1`：根改名后所有后裔 path 与树关系同步更新，不留下旧路径投影。L2-L5 本批未启动真实 App，记 `na`。
