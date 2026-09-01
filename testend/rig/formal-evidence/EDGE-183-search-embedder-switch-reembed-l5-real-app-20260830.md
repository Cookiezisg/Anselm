# EDGE-183 换 embedder 重嵌 · L5

- 结论：`pass`
- 法条：`G1`（新用户不读内部文档即可走到目标入口）
- 正式 session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-223728`

从真实 App 的普通 Chat 入口开始，用户只描述目标：“Find the note about an interface
that feels calm, coherent, and trustworthy. Explain why those qualities matter.” 用户
没有提及 Ollama、向量、重嵌、索引或内部 API。模型自行发现并使用 `search_documents`，
从不同措辞召回 `EDGE182 Semantic Recall Fixture`，再用 `read_document` 读取原文，
最终回答文档内容及其重要性。

这条路径验证了产品能力而非内部开关可见性：新用户知道的是“我想找到一份说明并理解
它”，而不是“我要操作 semantic search”。App 的真实画面与 messages SSE 的搜索、
读取、回答顺序一致，且没有把未找到时的诚实边界改成猜测。
