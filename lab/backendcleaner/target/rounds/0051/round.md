# Round 0051 — attachment 存储核心（波次 5 · M5.2 前置子模块 1/3）

类型 / 目标：多模态附件的**持久化层**——CAS blob 存储 + 元数据表 + 上传/下载/删/GC 端点。attachment 子模块第一轮（3 轮：R0051 存储 → R0052 多 provider 注入 → R0053 sandbox 提取）。用户要「完整支持所有模态」，研究后定主线（图/文本/PDF/Office）扎实做、音频/视频/OCR 留可插 Extractor 端口按需补。

依赖扫描：
- 上游就绪：pkg/orm（自动 ws 隔离 + 软删 + ErrConflict）、infra/fs（memory/skill 文件式 store 范式：`Store{base}` + `dir(ctx)` 用 RequireWorkspaceID + 原子 temp+rename）、idgen（att_，S15 已登记）、reqctx（RequireWorkspaceID）、transport（response helper + multipart）。
- 下游接口（消费者）：chat（M5.2）`ResolveToContentParts(att_ids)`；R0052 多 provider 注入 / R0053 sandbox 提取经 app 扩展。
- 考古：旧 backend attachment 内嵌在 chat domain（`chatdomain.Attachment{UserID,FileName,MimeType,SizeBytes,StoragePath}` + SaveAttachment/GetAttachment，5 个 ErrAttachment* 错误码）。本轮**提升为独立 attachment 域 + CAS 存储**，不照搬。

best-practice 研究（抄 LibreChat 最完整流水线 + 3 升级）：
- LibreChat（OSS 最全）：存储与处理解耦 → 类型路由（OCR>STT>解析>兜底）→ 提取 → token 截断 → 投递（vision/文本/RAG）；blob 存盘 + 元数据 DB；OCR/文档页确认「无 RAG，纯提取 + 直接注入 + fileTokenLimit」对齐 Forgify。
- 模态全貌（ChatGPT 512MB 全模态含音视频 / Claude 30MB·20 文件·图 8000²·PDF<100 页·无音视频）。
- **3 个 Forgify 升级**：① **CAS 内容寻址**（dedup+完整性，比 LibreChat 普通 uploads/ 强）② **sandbox 当本地提取引擎**（python pdfplumber/python-docx/whisper，离线、无云 OCR/API key，比 LibreChat 调 Mistral OCR 云 API 更 local-first）③ **中立 ContentPart + 各 provider 渲染器**（多家，LibreChat 基本只 OpenAI 格式）。

修改后完整逻辑（= domains/attachment.md DOC-307 §1-2-6-8 as-built）：
- **domain**：`Attachment`（att_ + sha256/filename/mime/size/kind + 软删 D1）+ `Kind` 6 类 + `KindFromMIME(mime,filename)`（剥 `;charset`、扩展名兜底）+ MaxBytes 50MB + 3 errorsdomain + `Repository`（Insert/Get/GetBatch/SoftDelete/ListLiveSHAs〔GC 保留集〕）。
- **infra/fs/blob**：CAS blob 存储 `<base>/workspaces/<ws>/blobs/<sha[:2]>/<sha>`，Put 内容寻址 dedup（已存 no-op）+ 原子写、Get/Exists、Sweep（孤儿 GC + 清残留 .tmp）、sha 进路径前校验 64 hex（防穿越）、ws 取自 ctx。
- **infra/store/attachment**：orm 元数据表（手写 DDL + partial 索引 idx_attachments_ws_sha；sha256 **不唯一** = dedup）+ Insert/Get/GetBatch/SoftDelete/ListLiveSHAs（去重 sha，软删-aware）。
- **app**：Service（Upload〔校验空/超限 → sha256 → blob.Put dedup → Insert，blob 先于行写〕/ Get / Download / Delete〔软删〕/ GC〔ListLiveSHAs → Sweep，按 sha refcount〕）+ BlobStore 端口（Put/Get/Exists/Sweep）。
- **handler**：4 端点（POST multipart〔MaxBytesReader + DetectContentType 嗅探〕/ GET 元数据 / GET content 原始字节 / DELETE）。

删除 / 合并：旧 chat 内嵌 attachment（chatdomain.Attachment + 5 ErrAttachment* 码）→ 独立 attachment 域。旧 `ATTACHMENT_TYPE_UNSUPPORTED`/`ATTACHMENT_PARSE_FAILED` 暂不实现（R0053 提取territory）。

契约变更（→ contract-changes #33）：domains/attachment.md 新（DOC-307）；database §2.2b attachments 表（att_ 已登记 S15）；api 4 端点（取代旧 `POST /attachments→chat.go` 占位）；error-codes §2.4b 独立 attachment 域（取代旧 chatdomain.ErrAttachment* 4 行，新 4 码 NOT_FOUND/TOO_LARGE/EMPTY/BAD_UPLOAD，留 EMPTY_CONTENT 给 chat）。

新实现要点：domain（Attachment + KindFromMIME + Repository）；infra/fs/blob（CAS + Sweep）；infra/store/attachment（orm + DDL）；app（Service + BlobStore 端口）；handler（multipart）。

新测试（全离线）：blob 9（Put/Get 往返、dedup 幂等、invalid sha、Get missing、Exists、Sweep 删孤儿/空目录 noop、ws 隔离、需 ws）+ store 6（往返+ws 戳、NotFound、GetBatch、软删 + 重删、**ListLiveSHAs 去重 + 软删-aware**〔2 行共享 sha 删一仍留〕、ws 隔离）+ app 8（往返+kind、kind 分类表、空/超限、dedup 同字节、删保留 blob、**GC 按 sha refcount**〔共享 blob 不被误删、孤儿删〕）= 真 store + 真 temp blob 端到端。

验证：gofmt clean / `go build ./...`（整仓）exit 0 / vet clean / `go test`（blob+store+app）全绿。

是否更干净（自证）：职责单一（存储层只存取字节 + 元数据，注入/提取分到 R0052/R0053）；CAS 让 dedup/完整性/GC 自然（按 sha refcount）；无多余抽象（BlobStore 4 法端口皆 app 实需）；blob 存盘不胀 SQLite；中立 Kind 为多 provider 注入预备。

覆盖状态（capability-ledger）：多模态附件的「持久化 + CAS dedup + 上传/下载/GC」能力落地；注入（R0052）+ 提取（R0053）随后。

遗留 / 下一步：**R0052 多 provider 注入**（中立 `ContentPart` 挂 llminfra.LLMMessage + anthropic/openai/gemini 渲染器 + model 目录加 vision flag + `ResolveToContentParts`〔图缩放编码/文本内联/PDF 原生透传〕+ capability 门控）→ **R0053 sandbox 提取**（PDF/Office python 提取 + token 限额；音频 Whisper/视频/OCR 经可插 Extractor 端口留插槽延后）。M7：handler 注册 + blob.New(forgify-home) + boot/ticker `:gc`。
