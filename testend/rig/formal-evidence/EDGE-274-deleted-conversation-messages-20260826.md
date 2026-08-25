# EDGE-274 · 立碑线程读消息

## L1 focused evidence

- `backend/internal/app/conversation/conversation_test.go:TestDelete_EmitsAndPurges` 通过，删除后业务行被立碑/清理且事件语义保留。
- 对已删除 conversation 读取 messages 的端点路径由现有 conversation not-found 契约返回 `404 CONVERSATION_NOT_FOUND`，不伪造空线程。

## 判定

L1=`F1`：删除态、消息读侧和 API 错误语义一致，客户端不会把墓碑误渲成一个空对话。L2-L5 本批未启动真实 App，记 `na`。
