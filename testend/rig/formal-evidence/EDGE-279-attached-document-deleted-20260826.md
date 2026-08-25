# EDGE-279 · 对话挂载的文档被删

## L1 focused evidence

- `backend/internal/app/document/document_test.go:TestRenderAttachedAsXML_MissingWarning` 通过：缺失 doc 生成 `missing="true"` 可见警告，不静默丢 grounding。
- `testend/scenarios/contract_docs_att_test.go:TestContractDocsAtt_DocumentAttachScopeAndIterate` 通过挂载 eager 校验与文档作用域；未知文档不会被当作可用内容。

## 判定

L1=`E4`：挂载文档消失后模型收到诚实缺失标记，回合不因历史脏引用整体崩溃。L2-L5 本批未启动真实 App，记 `na`。
