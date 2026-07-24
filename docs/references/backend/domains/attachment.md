---
id: DOC-025
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-21
review-due: 2026-10-19
audience: [human, ai]
---

# attachment —— 对话附件（多模态摄取）

## 1. 定位 + 心智模型

用户上传的文件（图/PDF/Office/文本，≤50MB，`limitspkg` 默认值）：元数据行 + blob（`infra/fs/blob` 内容寻址 CAS：字节按 SHA-256 存盘 `<sha[:2]>/<sha>`，相同上传 dedup 成一份、`sha256` 列非唯一、多行可共享一 blob，删行后 blob 由 GC 按活跃 sha 保留集回收——GC 在 **boot 时**逐 workspace 跑（`bootstrap` forEachWorkspace，与其它 boot 对账同族），**非**删除时：删除时扫描会与在飞上传竞态（blob `Put` 先于行 `Create`，其间的并发 GC 会扫掉刚 Put 的 blob）；boot 无并发上传故无竞态。会话内孤儿累积、重启回收——有界，非跨重启无界）。`KindFromMIME` 分 6 桶 image/document/text/audio/video/other（mime 主类型 + 文件扩展名兜底）。**渲染按模型能力和单回合媒体额度门控**（chat 传 `Capabilities{Vision,Video,Audio,NativeDocs,MaxMediaParts,MaxMediaBytes}`）：普通 BYOK 的图 → vision 模型给内联 image_url；MP4 视频 → video 模型给内联 video_url；WAV/MP3 音频 → audio 模型给 input_audio；超能力、格式不符或额度耗尽均按原顺序降成明确文字占位而不丢附件。**内置 Anselm 网关是唯一例外**：resolver 还会传 install-bound `RemoteMedia` 目的地，图片和 MP4 先经 device-proof resumable upload 取得短期 HTTPS lease URL，再作为 `image_url`/`video_url` 交给上游；图片优先取媒体 worker 生成的 `model-default` 代理图（EXIF auto-orientation、最长边默认 2048、透明图保 PNG、普通图 JPEG），若代理尚未 ready 则本回合不阻塞、退回原件上传并让后台任务追上，后续 sampling/回合复用代理图。sidecar 仅在内存中按网关/install/规范 MIME/SHA-256 缓存 lease，离过期不足 30 秒自动重传刷新，故同一 ReAct 与后续历史重建都不重复上传同一可用字节（代理或原件），重启不保留 bearer token。上传/回执失败使本回合大声失败，绝不静默丢媒体。PDF/Office → `NativeDocs` 模型给 file part（PDF 原样递交、原生读，anthropic/openai/gemini）、否则 **sandbox 抽取文本内联**（`SandboxExtractor`：共享 python env 跑一次性抽取脚本、token 截断到 400K char，经 `Extractor` 端口 DIP——不认的 mime 返 `ATTACHMENT_EXTRACTION_UNSUPPORTED` 降级占位）；文本 → 直接内联；other → 文字占位。缺失/不可读 blob 告警跳过、绝不让回合失败。附件 id 快照在 user 回合 Attrs（freeze-on-send 家族）。

**LLM 工具 2 个**（薄适配、`Toolset.Lazy`，经 search_tools 浮现）：`list_attachments`（无参，列 ctx workspace 全活跃附件 `{id, filename, mime, kind, sizeBytes, createdAt}`，新→旧）发现；`read_attachment(id)` 重读——text/document 类经 `ToContentParts`（`Capabilities{Vision:false, NativeDocs:false}`，故 PDF/Office 抽成文本而非递交读不了的 file part）抽文本内联，image/audio/video/other 二进制返描述符（filename/mime/size + 不可文本抽取的提示，**不倾倒字节**），未知 id 转软失败串供 LLM 自纠。另作 **catalog source**（`AsCatalogSource`，组名 `attachment`）：把每个活跃附件报成 name(filename)+description(kind/mime/size) 条目，让 LLM 知道上传文件存在。两者都靠 `Service.List`（带完整元数据行，区别于 GC 用的 `ListLiveSHAs` 只投影 sha）。

## 2. 契约（引用）

端点（upload / get / download `:id/content` / delete 软删）→ [api.md](../api.md) · 表 `attachments`（软删；blob 在文件系统）与其可再生 `attachment_derivatives` / 任务条件化 `attachment_perceptions` 媒体工作表（均见 [database.md](../database.md)，后两者不持原件）· 码 `ATTACHMENT_*` 4(domain)+1(app extraction)+1(app tool `ATTACHMENT_ID_REQUIRED`) 及媒体工作 `MEDIA_INVALID_REQUEST`/`MEDIA_NOT_FOUND` → [error-codes.md](../error-codes.md) · ID：`att_`/`mdr_`/`mpr_`。被消费：chat（ToContentParts 渲染）、catalog（attachment source）、media worker（代理/感知产物）。
