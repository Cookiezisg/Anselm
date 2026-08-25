# EDGE-342 · chat-only 模型的工具面

## L1 focused evidence

- `backend/internal/app/chat/chat_test.go` 通过：`tool_call=false` 的 chat-only 模型可用于对话，但收到的工具定义数为 0。
- `backend/internal/bootstrap/resolvers_test.go` 通过：chat-only 模型仍可解析为对话模型；工具/agent 路径不会把它误当成可执行工具模型。

## 判定

L1=`E4`：目录不丢弃可聊天模型，也不虚构其工具能力；产品面能聊天，工具入口不承诺必失败的能力。L2-L5 本批未启动真实 App，记 `na`。
