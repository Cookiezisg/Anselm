---
id: DOC-025
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2026-09-11
audience: [human, ai]
---

# attachment —— 对话附件（多模态摄取）

## 1. 定位 + 心智模型

用户上传的文件（图/PDF/Office/文本，≤50MB）：元数据行 + blob（`infra/fs` 文件存储）。`KindFromMIME` 粗分 image/document/text。**渲染按模型能力门控**（chat 传 `Capabilities{Vision, NativeDocs}`）：图 → vision 模型给 image_url、否则占位；PDF/Office → 原生支持给文档、否则 **sandbox 抽取文本内联**（`SandboxExtractor`：共享 python env 跑一次性抽取脚本，经 `Extractor` 端口 DIP——不认的 mime 返 `ATTACHMENT_EXTRACTION_UNSUPPORTED` 降级占位）；文本 → 直接内联。附件 id 快照在 user 回合 Attrs（freeze-on-send 家族）。

## 2. 契约（引用）

端点（upload/get/download）→ [api.md](../api.md) · 表 `attachments`（软删；blob 在文件系统）→ [database.md](../database.md) · 码 `ATTACHMENT_*` 3+1 → [error-codes.md](../error-codes.md) · ID：`att_`。被消费：chat（ToContentParts 渲染）。
