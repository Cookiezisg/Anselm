---
id: DOC-025
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Attachment

## 1. 定位

Attachment 是产品内所有上传文件与工具媒体产物的统一入口。它把：

- workspace 隔离的元数据行；
- 按 SHA-256 内容寻址的 blob；
- 文件类型、来源和执行溯源；
- 模型无关的 LLM content parts；
- 前端下载、音频播放与媒体准备状态

收敛到同一个 `att_` 身份。Chat、Agent、Subagent、Workflow 和工具结果都复用这条
路径，不各自定义图片、音频或文档线缆。

## 2. 存储与生命周期

上传先写 blob、再写 metadata，保证成功的行不会指向缺失字节。相同内容共享一份
CAS blob，但可有多条 Attachment 行。文件名只用于显示，落库前取 basename。

文件按 MIME 和扩展名归为：

```text
image | document | text | audio | video | other
```

大小上限来自当前 Limits，默认 50 MB。空文件与畸形 multipart 在边界拒绝；超过请求体上限
返回 `ATTACHMENT_TOO_LARGE`，损坏边界、非 multipart 或缺少 `file` 字段返回
`ATTACHMENT_BAD_UPLOAD`，不把两种用户动作混成同一条提示。大文件 multipart 可能落临时文件，
请求结束时清理该临时文件，不把重复上传变成长期 `/tmp` 泄漏。
Delete 只软删 metadata；blob 只有在该 workspace 内不再被任何 live row 引用时才可
回收。

`GET /attachments/{id}/content` 与 bearerless playback fetch 都用标准 MIME serializer 生成
`Content-Disposition`；用户文件名中的控制字符、引号、反斜杠和 Unicode 不得破坏 header 或
预览/下载。原始内容端点同时由标准库提供完整字节、`Range`/`Content-Range`、条件请求和
`416` 边界语义。

Blob GC 在 Boot 的逐 workspace 对账阶段执行，而不在 Delete 时执行。原因是上传存在
`blob Put → metadata Insert` 窗口；删除时并发 sweep 会把尚未落行的新 blob 误判为
孤儿。Boot 时没有并发上传，这条顺序由 Bootstrap 保证。

## 3. 溯源与 MediaRef

每条 Attachment 可记录：

- `source`：用户上传为空，工具产物使用生成方名称；
- `originConversationId`；
- `originFlowrunId`；
- `originToolCallId`。

`source` 与执行归属用于审计；工具结果的自动媒体展开还强制
`originToolCallId == 当前 tool call`。因此第三方工具不能仅靠在文本中猜中同 workspace
的 Attachment ID，就把别的文件注入模型。

工具通过唯一 receipt 传递媒体：

```json
{"attachmentId":"att_..."}
```

receipt 的解析规则由 `pkg/mediaref` 承担。工具结果咽喉只展开本次调用自己铸造的
附件；`read_attachment` 与 `inspect_media` 对既有附件的回显不会再次把原始字节灌回
主对话。

## 4. 模型输入融合

`ToContentParts(ids, capabilities)` 保持调用方顺序，并按实际模型能力决定原生输入或
文字降级：

| Kind | 能力满足时 | 能力不足或额度耗尽 |
|---|---|---|
| image | `image_url` | 点名文件的文字说明 |
| video | MP4 → `video_url` | 文字说明 |
| audio | WAV/MP3 → `input_audio` | 文字说明 |
| document | PDF 且 NativeDocs → file part | 本地抽取文本 |
| text | 直接内联文本 | 同左 |
| other | — | 不透明文件说明 |

单回合还受 `MaxMediaParts`、`MaxMediaBytes` 与 `MaxDistinctMediaKinds` 约束。超过限制
的项目在原位置变成说明，不让 provider 以 400 拒掉整轮。缺失行或不可读 blob 也会
留下可见说明，不静默消失。

额度说明中的带引号文件名来自附件原始顺序，是模型输入中的权威事实。助手回答“哪个
文件被省略”时必须逐字复制该文件名，不能从“第 N 张”、附件 ID、前一轮或命名规律
反推或改名；说明只应陈述该文件未进入本轮原生媒体输入，不得声称检查过其像素。

`NativeDocs` 只授权 PDF 原生输入，不代表 Office/ODT/EPUB 都可直接交给模型。
非原生文档经共享 Python Sandbox 抽取 PDF、DOCX、XLSX、PPTX 等文本；不支持或损坏
时降级为说明。抽取结果最多内联 400,000 字符。

## 5. Managed 与 BYOK 媒体传输

BYOK 路由把有界媒体转为 provider adapter 可消费的内联 part。受管 Anselm 路由由
composition root 注入 `RemoteMedia`，经 device proof 把不可变字节暂存到 API Serve，
再传短期 HTTPS lease；Attachment 层不依赖具体网关客户端。

受管图片优先使用 Media worker 的 `model-default` 代理。代理尚未 ready 时可短暂等待，
随后退回原件且让后台继续处理。同一回合的重复 Attachment 只上传一次。媒体 envelope
以**最终要 staging 的代理/原件字节**计量，而不是以原始附件行计量；代理可能比压缩原图更大，
此时在本地变成 size-budget 注记且不创建 lease，不能把错误推迟到网关 400。

受管 staging 接受的闭集为 JPEG/PNG/WebP、MP4、WAV/MP3。上传被归为 image、但网关不
接受且本地无法生成代理的格式，会降级为明确说明；真正的 staging/回执失败则使本轮
大声失败，不能假装模型看到了媒体。

## 6. 媒体准备与播放

Upload/Get 响应可附 `preparation` 侧车。图片对应 `model-default` 任务，状态包含
pending/running/ready/failed/cancelled、phase、可取消/重试标志、产物尺寸/MIME 和错误码。
非图片为 `not_required`；媒体服务不可用时 metadata 仍成功返回，侧车标为 unavailable。

前端音频播放先在受 bearer 与 workspace 保护的端点签发短期 lease，再使用高熵 token
访问 bearerless playback URL。播放 URL 是一次性消费、默认五分钟有效，并绑定签发时的
workspace 与 Attachment；只有 audio kind 可签发。

## 7. LLM 工具

- `list_attachments`：按新到旧列 metadata，不读 blob；每行的 `createdAt` 是精确 ISO-8601 上传时点，并在相邻附件卡中展示。用户询问上传时间时，正文应指向该精确卡片，不能编造、规范化或用「记录时间」等占位话术冒充字段值；
- `read_attachment`：文本/文档支持索引、分页和 literal query；二进制只返回描述符。规范参数键是 `id`；受管模型误用 `attachmentId` 时后端兼容这一别名，但工具描述和 schema 以 `id` 为唯一 canonical wire key；
- `inspect_media`：
  - image：有界代理/crop 进入默认视觉路由，代理超 envelope 但原图可交付时退回原图；两者都超限时返回结构化说明而不发起上游请求，或返回 tile map；
  - text/document：复用本地抽取并返回有界页、窗口或匹配；
  - audio/video：只返回本地 metadata capsule 与时间范围意图。

若用户附件投影已经明确写出文本无法抽取，Chat 应把该投影视为权威限制，不再调用
`inspect_media` 重试同一文档；应直接说明格式不受支持或文件不可读，并给出转换格式或粘贴文本的
替代路径。该规则不覆盖音频理解、图像/视频检查，或已经成功抽取文本的文档。
用户已经明确询问附件内容、抽取结果、截断或限制时，应直接回答投影中已有事实；不能先泛泛确认
“已收到附件”再反问下一步。

用户在本回合上传的附件 ID 会按媒体顺序进入模型专用的
`<uploaded_attachments_for_tools>` 目录；模型必须逐字复制其中的精确 ID，不能复制
schema 的示例值。`read_attachment` 使用 canonical `id`，`inspect_media` 使用
`attachmentId`，因此新上传的附件无需先调用 `list_attachments` 才能检查。

`inspect_media` 不伪造 transcript、OCR、scene 或 keyframe，也不把原始媒体写进 tool
result。图片检查继续使用默认 Anselm 模型解析；受管路由用短期 remote media，BYOK
使用有界 data URL。

受管聊天的 image/video part 只携带网关签发的相对 lease 路径
(`/v1/media/leases/{id}/content?...`)，不携带 scheme、host 或 base64。`MediaClient` 与
`ToContentParts` 与 `inspect_media` 两层都 fail-closed 拒绝绝对路径，防止错误装配把 provider 指向客户端提供的
任意 origin；BYOK 仍使用 data URL。

Attachment 同时是 catalog source，使模型能先发现 filename/kind/MIME/size，再按需读取。

## 8. 契约

端点登记见 [`api.md`](../api.md)。Metadata、derivative、perception 与 speech cache
表见 [`database.md`](../database.md)；错误见 [`error-codes.md`](../error-codes.md)。
主要 ID 为 `att_`、`mdr_`、`mpr_`。

Attachment 是 durable 原件；derivative/perception/speech cache 是可再生数据。多模态在
Chat 与工具历史中的消费规则见 [`chat.md`](chat.md) 和
[`messages.md`](messages.md)，受管服务边界见
[`managed-gateway.md`](../managed-gateway.md)。

朗读命中 `speech_cache` 后仍须验证其 `attachment_id` 指向的原件存在。若已明确返回
`ATTACHMENT_NOT_FOUND`，服务端先幂等清除这条陈旧映射，再合成并回写新的朗读附件，避免
唯一键冲突把同一文本永久降级成每次重新计费；普通存储故障不得被误判为附件丢失，也不得
静默删除缓存映射。

`speech_cache.last_used_at` 是 LRU 的真实排序依据：新行由 `Put` 显式写入当前时间；启动时
会幂等把旧版本留下的 Go 零时间回填为该行 `created_at`，避免升级后把旧缓存误判为最久未使用。
