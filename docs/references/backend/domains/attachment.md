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

大小上限来自当前 Limits，默认 50 MB。空文件与畸形 multipart 在边界拒绝。
Delete 只软删 metadata；blob 只有在该 workspace 内不再被任何 live row 引用时才可
回收。

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

`NativeDocs` 只授权 PDF 原生输入，不代表 Office/ODT/EPUB 都可直接交给模型。
非原生文档经共享 Python Sandbox 抽取 PDF、DOCX、XLSX、PPTX 等文本；不支持或损坏
时降级为说明。抽取结果最多内联 400,000 字符。

## 5. Managed 与 BYOK 媒体传输

BYOK 路由把有界媒体转为 provider adapter 可消费的内联 part。受管 Anselm 路由由
composition root 注入 `RemoteMedia`，经 device proof 把不可变字节暂存到 API Serve，
再传短期 HTTPS lease；Attachment 层不依赖具体网关客户端。

受管图片优先使用 Media worker 的 `model-default` 代理。代理尚未 ready 时可短暂等待，
随后退回原件且让后台继续处理。同一回合的重复 Attachment 只上传一次。

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

- `list_attachments`：按新到旧列 metadata，不读 blob；
- `read_attachment`：文本/文档支持索引、分页和 literal query；二进制只返回描述符；
- `inspect_media`：
  - image：有界代理/crop 进入默认视觉路由，或返回 tile map；
  - text/document：复用本地抽取并返回有界页、窗口或匹配；
  - audio/video：只返回本地 metadata capsule 与时间范围意图。

`inspect_media` 不伪造 transcript、OCR、scene 或 keyframe，也不把原始媒体写进 tool
result。图片检查继续使用默认 Anselm 模型解析；受管路由用短期 remote media，BYOK
使用有界 data URL。

Attachment 同时是 catalog source，使模型能先发现 filename/kind/MIME/size，再按需读取。

## 8. 契约

端点登记见 [`api.md`](../api.md)。Metadata、derivative、perception 与 speech cache
表见 [`database.md`](../database.md)；错误见 [`error-codes.md`](../error-codes.md)。
主要 ID 为 `att_`、`mdr_`、`mpr_`。

Attachment 是 durable 原件；derivative/perception/speech cache 是可再生数据。多模态在
Chat 与工具历史中的消费规则见 [`chat.md`](chat.md) 和
[`messages.md`](messages.md)，受管服务边界见
[`managed-gateway.md`](../managed-gateway.md)。
