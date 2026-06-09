---
id: DOC-307
type: reference
status: active
owner: @weilin
created: 2026-06-09
review-due: 2026-09-01
audience: [human, ai]
---
# Attachment Domain — 多模态附件（CAS 存储 + 多 provider 注入 + sandbox 提取）

> **核心职责**：用户上传到聊天回合的文件（图/PDF/Office/文本/音视频）的**持久化 + 进 LLM** 的完整通路。
> 抄 LibreChat 最完整的流水线骨架，加 3 个 Forgify 升级：**① CAS 内容寻址存储**（dedup+完整性）
> **② sandbox 当本地提取引擎**（不依赖云 OCR/API key，离线）**③ 中立 ContentPart + 各 provider 渲染器**（多家）。
> **无 RAG**（对齐 document 域决定）：大文档 = 抽文本 + token 限额截断 + 直接注入，非向量检索。
>
> **三轮交付**：**R0051 存储核心 ✅（本文档 as-built）** → R0052 多 provider 注入（中立 ContentPart + 渲染器 + vision 门控）→ R0053 sandbox 提取（PDF/Office；音频/视频/OCR 留插槽）。

---

## 1. 物理模型 (Data Anatomy)

### 1.1 `Attachment` 元数据行（att_，as-built R0051）
```go
type Attachment struct {
    ID          string     `db:"id,pk"`              // att_<16hex>
    WorkspaceID string     `db:"workspace_id,ws"`    // orm 自动隔离
    SHA256      string     `db:"sha256"`             // 内容寻址键 → CAS blob
    Filename    string     `db:"filename"`           // 显示名（blob 按 sha 寻址、非按名）
    MimeType    string     `db:"mime_type"`
    SizeBytes   int64      `db:"size_bytes"`
    Kind        string     `db:"kind"`               // image|document|text|audio|video|other
    CreatedAt   time.Time  `db:"created_at,created"`
    DeletedAt   *time.Time `db:"deleted_at,deleted"` // D1 软删
}
```
**字节绝不进 SQLite**：行只存元数据；blob 在文件系统。`sha256` **不唯一**——多行可共享一个 blob（dedup）。

### 1.2 CAS blob 存储（infra/fs/blob）
```
~/.forgify/workspaces/<wsID>/blobs/<sha[:2]>/<sha>
```
- 按 SHA-256 内容寻址、两字符分片；workspace id 取自 ctx（隔离），同 memory/skill 文件式 store 的缝。
- **Put 内容寻址 dedup**：blob 已存在则 no-op（相同字节哈希到同一路径）；原子 temp+rename。
- sha 进路径前校验为 64 位 hex（防穿越）。

---

## 2. 存储原理 (Storage Principles)

- **上传与发送解耦**：`POST /attachments → att_id`，消息引用 id（ChatGPT/Claude.ai/OpenAI/Anthropic 通用范式）。
- **blob 存盘、元数据进 DB**：字节绝不塞 SQLite（业界铁律；LibreChat/Open WebUI 同）。
- **内容寻址 dedup**：同一文件重传 = 一份 blob、多条 att_ 行。
- **软删 + GC**：删 = 软删行（留墓碑，D1）；`GC` 扫孤儿——blob 的 sha 无任何活跃行引用才删（**按 sha refcount**，dedup-aware）。
- **上限**：单文件 `MaxBytes = 50 MB`（对齐 OpenAI 单文件；Claude.ai 30 MB）。

---

## 3. 模态分类 (Kind)
`KindFromMIME(mime, filename)` 按 mime（剥 `; charset`）分类，application/octet-stream 用扩展名兜底：

| Kind | 触发 | 进 LLM 方式（R0052/R0053）|
|---|---|---|
| `image` | image/* · png/jpg/gif/webp/heic | vision 块（缩放到模型上限）|
| `document` | application/pdf · docx/xlsx/pptx/odt/epub | PDF 原生透传(capable 模型) 或 sandbox 抽文本 |
| `text` | text/* · json/xml/yaml/csv · 代码扩展名 | 内联文本（原生读）|
| `audio` | audio/* | **R0053 留插槽**：sandbox Whisper 转写（延后）|
| `video` | video/* | **不做**（抽帧重、价值低，Claude 也不做）|
| `other` | 其余 | 不透明（仅存储下载）|

---

## 4. LLM 注入（R0052，待建）
- 中立 `ContentPart`（text/image/document）挂到 `llminfra.LLMMessage`；**各 provider 客户端各自渲染**：anthropic `image/document` 块、openai `image_url/input_file`、gemini `inline_data`（11 家收敛 ~3 种 wire）。
- chat（M5.2）`ResolveToContentParts(att_ids)`：image→缩放+base64 编码、text→内联读、document(pdf)→capable 模型原生透传。
- **vision capability 门控**：model 目录加 `vision` flag；附图但模型不支持 → 优雅降级/提示。

## 5. 提取流水线（R0053，待建）—— sandbox 当本地引擎
- 路由优先级（抄 LibreChat）：OCR > STT > 文本解析 > 兜底。
- **主线**：PDF 文本 `pdfplumber` / Office `python-docx`·`openpyxl`·`python-pptx`，**全在 Forgify sandbox 跑 python**（离线、无云 OCR、无 API key）。
- **token 限额**：`fileTokenLimit`（默认 100K），全量提取、构造 prompt 时截断、保头部。
- **可插 `Extractor` 端口**：音频(Whisper)/视频/扫描 OCR(tesseract) 都是往此端口插一个 extractor，不动主干——按需补。

---

## 6. HTTP 端点（as-built R0051）

| Method | Path | 说明 |
|---|---|---|
| POST | `/api/v1/attachments` | multipart 上传（单 `file` 字段）→ 校验+算 sha+CAS 存+返 att_ |
| GET | `/api/v1/attachments/{id}` | 元数据 |
| GET | `/api/v1/attachments/{id}/content` | 原始字节（按存储 mime + Content-Disposition inline）|
| DELETE | `/api/v1/attachments/{id}` | 软删（blob 由 GC 回收）|

---

## 7. 跨域集成 (Interactions)
- **chat（M5.2）**：消息引用 `att_ids` → `ResolveToContentParts` → 进 loop/provider。
- **sandbox（R0053）**：提取引擎（python 提取脚本）。
- **model（R0052）**：vision capability flag。
- **无 RAG**：大文档抽文本 + token 限额 + 直接注入（对齐 document 域无向量检索）。
- **GC**：boot 或 ticker 定期 `:gc`（M7 接线）。

---

## 8. 错误字典 (Sentinels)

| Sentinel | HTTP | Wire Code | 备注 |
|---|---|---|---|
| `ErrNotFound` | 404 | `ATTACHMENT_NOT_FOUND` | id 不存在 / 已软删 / 跨 workspace |
| `ErrTooLarge` | 413 | `ATTACHMENT_TOO_LARGE` | 超 50 MB |
| `ErrEmpty` | 422 | `ATTACHMENT_EMPTY` | 空文件 |
| (handler) | 400/413 | `ATTACHMENT_BAD_UPLOAD` | multipart 缺 `file` 字段 / 读取失败 |
