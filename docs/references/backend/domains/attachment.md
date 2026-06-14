---
id: DOC-025
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-14
review-due: 2026-09-14
audience: [human, ai]
---

# attachment —— 对话附件（多模态摄取）

## 1. 定位 + 心智模型

用户上传的文件（图/PDF/Office/文本，≤50MB，`limitspkg` 默认值）：元数据行 + blob（`infra/fs/blob` 内容寻址 CAS：字节按 SHA-256 存盘 `<sha[:2]>/<sha>`，相同上传 dedup 成一份、`sha256` 列非唯一、多行可共享一 blob，删行后 blob 由 GC 按活跃 sha 保留集回收）。`KindFromMIME` 分 6 桶 image/document/text/audio/video/other（mime 主类型 + 文件扩展名兜底）。**渲染按模型能力门控**（chat 传 `Capabilities{Vision, NativeDocs}`）：图 → vision 模型给 image_url、否则占位；PDF/Office → `NativeDocs` 模型给 file part（PDF 原样递交、原生读，anthropic/openai/gemini）、否则 **sandbox 抽取文本内联**（`SandboxExtractor`：共享 python env 跑一次性抽取脚本、token 截断到 400K char，经 `Extractor` 端口 DIP——不认的 mime 返 `ATTACHMENT_EXTRACTION_UNSUPPORTED` 降级占位）；文本 → 直接内联；audio/video/other → 文字占位（extractor 后补）。缺失/不可读 blob 告警跳过、绝不让回合失败。附件 id 快照在 user 回合 Attrs（freeze-on-send 家族）。

## 2. 契约（引用）

端点（upload / get / download `:id/content` / delete 软删）→ [api.md](../api.md) · 表 `attachments`（软删；blob 在文件系统）→ [database.md](../database.md) · 码 `ATTACHMENT_*` 4(domain)+1(app extraction) → [error-codes.md](../error-codes.md) · ID：`att_`。被消费：chat（ToContentParts 渲染）。
