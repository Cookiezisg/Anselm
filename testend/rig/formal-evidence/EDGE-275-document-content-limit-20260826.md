# EDGE-275 · 文档超 1MB

## L1 focused evidence

- `testend/scenarios/contract_docs_att_test.go:TestContractDocsAtt_DocumentNameGuardsSoftDelete` 通过，超 1MB 正文返回 `413 DOCUMENT_CONTENT_TOO_LARGE`。
- 场景同时确认不会自动拆分，正常标题/软删与重名保护仍保持独立。

## 判定

L1=`E1`：超限原因与下一步边界明确，服务端硬拒绝而不是静默截断用户正文。L2-L5 本批未启动真实 App，记 `na`。
