---
id: WRK-078
type: working
status: active
owner: "@weilin"
created: 2026-07-23
reviewed: 2026-07-24
review-due: 2026-10-21
audience: [human, ai]
landed-into:
---

# WRK-078 · 1M 全模态 Agent：上下文、媒体摄取、Qwen 路由与语音交互

> **状态：核心方向已由用户拍板，按 §12 顺序施工。**
>
> 本战役横跨两个仓库：桌面端 + 本地 sidecar 位于 Anselm；公网免费档网关位于
> `Anselm-API-Serve`。任何一端单独完成都不构成产品能力上线。

---

## §0 一句话与最终体验

Anselm 的主 Agent 始终在真实 1M 对话上下文中工作：纯文本走 DeepSeek V4 Flash，图片/视频走
Qwen3.7-plus；音频由 Qwen3.5 Omni 做一次任务相关的感知，再把可回溯证据交给 1M 主 Agent。媒体原件
只保存和上传一次，后续 ReAct sampling 默认只携文本证据，不重复传输/计费原始媒体。空 composer 的
发送位变成麦克风，实时听写结束后落成可编辑文本。

用户最终感知：

1. 不再因本地估算提前收到 `input too large`。
2. 文本、图片、视频对话都按 1M 能力治理，而非被历史 256K 档位压住。
3. 一张图片、一段录音或一个视频不会在 Agent 每次工具续步时重新上传和重新计费。
4. 小媒体近乎无感；大媒体有诚实的“准备 → 理解 → 就绪”进度，不以模糊的“文件太大”拒绝。
5. 麦克风用于流式听写，停止后可以修改再发送；原始音频理解仍作为正式多模态附件存在。
6. 主 Agent 不因语音出现而退化为 64K Omni 会话，工具能力、长期记忆和压缩治理保持一致。
7. 默认只有一个 `Anselm Auto` 选择：网关自行选择真实 route；只有显式进入外部模型 API Key 模式的高级用户才选择模型和配置。

---

## §1 目标、非目标与术语

### 1.1 必须达成

| 目标 | 完成定义 |
|---|---|
| 真实窗口 | 网关与桌面端发布 provider 的真实 route-specific context；无固定 256K 假上限 |
| 自动治理 | sampling 前整理、provider 权威超限后压缩重试；正常用户永远不需要手动 compact |
| 强 Agent | 压缩保留决策、约束、未完成事项、引用和精确重取线索；工具结果可按需重读 |
| 全模态 | 图片、视频、音频及混合输入均有明确、可测试的能力路线 |
| 媒体一次性 | 原件本地 CAS 单存；远端一次上传/短期租约；Agent 循环不重复携带媒体 |
| 可回溯感知 | 感知结果带页码、时间戳、帧、区域、置信/不确定点，Agent 可重新取证 |
| 语音输入 | 桌面三平台录音、实时 partial/final 转写、取消、断线恢复、离线 fallback |
| 成本诚实 | Qwen 文本/图像/视频/音频分项费率与 usage 入账；预算预留不漏算也不过度拒绝 |
| 模型配置诚实 | 普通用户只使用 Anselm Auto；外部模型 API Key 的表单只显示该模型已确认支持的原生配置，专家可提交受控 native JSON |
| 生产质量 | 单元/集成/testend/真机/故障注入/性能/隐私门禁齐全，文档与代码同提交 |

### 1.2 明确不做

- 不把 `qwen3.5-omni-plus` 虚报为 1M；其 64K 是感知模型物理事实。
- 不让 Flutter 持有阿里、DeepSeek 或网关 operator key。
- 不让客户端提交任意远程媒体 URL；继续防 SSRF、下载放大与 MIME 欺骗。
- 不把 1M 理解为无限二进制 body；上下文、传输字节、并发、时长、成本是四组不同护栏。
- 不默认永久上传用户原件到公网网关；原件长期真相留在本地。
- 不默认语音停止即发送；误识别必须给用户一次编辑确认。
- 不用全双工 speech-to-speech 模型替换工具型主 Agent；语音只是 I/O，不是能力降级开关。
- 不在本战役做语音输出/TTS；它只是 assistant 文本朗读，后续可作为独立 UX 增强，不进入多模态输入与 Agent 能力验收。
- 不新增第四条常驻 SSE；语音使用一次性 WebSocket 会话，媒体准备走现有消息流或请求状态。
- 不保留 Kimi 的永久 fallback、双写或兼容分支；迁移验收后物理删除 Kimi。

### 1.3 术语

| 术语 | 含义 |
|---|---|
| 原件 `original` | 用户选择/录制的不可变字节，本地 CAS 真相 |
| 推理代理 `proxy` | 面向模型的压缩/转码/裁剪版本，可再生 |
| 感知产物 `perception` | OCR、转写、关键帧、场景、声音事件等结构化结果 |
| 证据包 `evidence capsule` | 主 Agent 消费的有界文本/JSON，含原件重取坐标 |
| 媒体租约 `media lease` | 公网临时媒体对象及过期时间；绝非长期云存储 |
| 主 Agent | 执行 ReAct、工具调用、长期对话和最终回答的 1M 模型 |
| 感知器 | 一次性读取原生媒体并产证据的 Qwen 模型；不拥有完整对话 |
| housekeeping | 丢弃/标记可重取的旧 tool result 等低损整理 |
| checkpoint | 将旧 prompt 前缀折成结构化 continuation state |

---

## §2 当前物理事实与问题定性

### 2.1 Anselm 主仓

- 附件原件已进入本地内容寻址 CAS；消息只冻结 attachment id，持久层方向正确。
- composer 的文件选择、粘贴、拖放都读取完整字节并立即上传，当前没有推理代理生成步骤。
- `attachment.Service.ToContentParts` 每次构建 LLM 历史都会读取 blob：
  - image → 原始 data URL；
  - MP4 → 原始 data URL；
  - WAV/MP3 → 完整 base64；
  - native document → 完整 base64；
  - 非 native document → 最多约 400K 字符抽取文本内联。
- 只要带附件的 user message 仍位于活跃 prompt，每次 sampling 都可能重新读取、编码、传输并计费媒体。
  一次十步 ReAct 不是“一次媒体调用”，而可能成为十次。
- Qwen provider 已独立拥有 wire/stream parser，但当前 user content renderer 只承载 text + image；
  video/audio 尚未接入该 provider。
- attachment 能力模型已有 `Vision/Video/Audio/NativeDocs/MaxMedia*`，可作为新摄取层的消费端，不需推倒
  attachment 域。
- 上下文治理已有正在收口的实现：
  - provider 权威 hard limit；
  - estimate 只触发 prompt editing、不本地拒绝；
  - route-aware text/multimodal budget；
  - 旧 tool result 标记化；
  - semantic continuation checkpoint；
  - confirmed overflow 透明压缩重试；
  - 回合边界 durable summary + watermark。
- 上述上下文改动仍在当前 worktree，尚未作为本战役的已验收基线宣告完成。

### 2.2 Anselm-API-Serve 网关

- 公开模型为 `anselm-auto`；客户端 model 不是 provider selector。
- 纯文本当前走 `deepseek-v4-flash`；任意图片/视频当前走 `qwen3.7-plus`；合法音频固定
  `AUDIO_UNAVAILABLE`。
- text 与 visual route 都发布 1M；产品输出 cap 当前为 16,384。
- 媒体只接受 user role 内联 base64：JPEG/PNG/WebP、MP4、WAV/MP3。远程 URL/file/PDF 被拒。
- 生产请求体上限 8 MiB，最多 8 个媒体 part、3 MiB decoded media。这防止服务被炸，却也让大量正常
  相片、视频无法进入能力路线。
- input estimate 已只用于成本报价，不再作为 context admission gate；provider 400/413/422 归一。
- provider、账本 CHECK、rate card、metrics、readiness、dashboard 和文档均只把 `deepseek|qwen` 视为运行时闭集成员。

### 2.3 已完成外部能力验证

- 新加坡区域 key 已在本机和现有服务器分别真实调用：
  - `qwen3.7-plus`：HTTP 200，文本输出正常；
  - `qwen3.5-omni-plus`：强制 stream 路线 HTTP 200，文本输出正常。
- 外部模型 API Key 模式保留用户填写的完整 provider endpoint；新加坡工作区使用
  `https://{WorkspaceId}.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1`，不会被 Qwen
  adapter 改写成公共 China endpoint。该 URL 是 workspace 标识而非 secret；API key 仍只进本地
  sidecar 的加密凭证存储。
- key、网络、TLS、区域和两个模型的调用权限均已证实；测试未把 key 写入代码、文件或环境配置。
- 正式上线仍必须换用未在聊天中出现过的新 key，并存入服务器 secret。

### 2.4 四类“炸”

| 维度 | 当前风险 | 不能混为一谈的事实 |
|---|---|---|
| 带宽 | 原件 + base64（约 +33%）在 sampling 中重复 | byte cap 不能代表 token cap |
| Token | 图按像素、音频按时长、视频按帧/时长、文档按文字计 | 压文件体积不一定等比降 token |
| 上下文 | 历史媒体/大 tool result 反复进入每次请求 | 1M 是上限，不是应被重复低价值内容填满的目标 |
| 延迟 | 上传、解码、视觉/音频 encoder、模型推理逐步叠加 | streaming 只能改善感知，不能消除重复工作 |

---

## §3 最终架构与不可破坏的不变量

### 3.1 Anselm Auto 的内部模型路线

下表是网关的内部路由合同，不是给普通用户的 model picker。产品默认只显示一个不可替换的
`Anselm Auto`；网关按输入模态、任务、可用性与成本选择实际 route，并发布该 route 的权威能力和预算。
用户只有显式进入外部模型 API Key 高级模式才选择外部 provider/model。

| 本次具体输入 | 感知阶段 | 主 Agent | 对话预算 |
|---|---|---|---|
| 纯文本 | 无 | DeepSeek V4 Flash | 1M route |
| 麦克风听写 | Qwen3-ASR Realtime → 文本 | DeepSeek V4 Flash | 1M route |
| 图片 | 任务相关视觉证据；必要时复查裁剪 | Qwen3.7-plus | 1M route |
| 视频 | 关键帧/音轨/相关片段证据 | Qwen3.7-plus | 1M route |
| 原始音频 | Qwen3.5 Omni 音频证据 | DeepSeek V4 Flash | 主 Agent 1M；感知器 64K |
| 图片/视频 + 音频 | Omni 产音频证据 | Qwen3.7-plus 看视觉 + 音频证据 | 主 Agent 1M |
| 文档 | 解析、索引、相关块/分层总结 | DeepSeek 或 Qwen3.7（按剩余媒体） | 1M route |

### 3.2 端到端数据流

```text
Flutter 选择/录制
  → loopback sidecar
  → 本地 original CAS（sha256 去重）
  → media ingestion
       ├─ proxy（缩放/转码/裁剪）
       ├─ index（页/帧/时间/段落）
       └─ perception（OCR/ASR/场景/声音）
  → task-conditioned evidence capsule
  → 1M main-agent ReAct
       ├─ 默认只看 capsule
       └─ 证据不足时 inspect_media 精确重取
  → text response
```

免费档远端链：

```text
sidecar proxy/片段
  → device-proof 临时上传
  → media lease / opaque handle
  → 网关选择 Qwen perception 或 Qwen3.7
  → 上游取短期签名对象
  → 结算完成即删 / TTL 兜底回收
```

### 3.3 十条不变量

1. **DB 行是真相**：message 永久只引用 attachment id；不把 base64 写消息块。
2. **原件本地唯一**：公网只见 proxy 或目标片段，除非用户任务物理要求原件。
3. **每媒体每任务一次感知**：同一 ReAct 回合不重复附带原生媒体。
4. **证据可回溯**：任何有损摘要必须带可重取的 attachment id + 页/时/帧/区域。
5. **Agent 可质疑证据**：提供 `inspect_media`，不强迫主 Agent 相信一次摘要。
6. **窗口诚实**：1M 只发布给真实 1M route；Omni 64K 不伪装。
7. **provider 是 hard-limit 权威**：本地 estimate 永不作拒绝闸。
8. **安全护栏保留**：context 放开不等于 body、并发、时长、成本无限。
9. **密钥不下沉 UI**：Flutter 只连 loopback；sidecar/网关持凭据。
10. **内容不进观测面**：日志、metrics label、审计、错误均不含媒体、prompt、转写或签名 URL。

---

## §4 1M 上下文治理

### 4.1 “完整利用”的定义

完整利用不是每轮硬塞到 1,000,000 token，而是：

- Anselm Auto 按网关发布的 route profile 使用真实预算，不再用 256K 或 UTF-8 estimate 提前拒绝；
- 外部模型 API Key 下的模型初始不宣称知道窗口、不设本地 admission 闸；
- 外部模型第一次**自然**触到上游上下文限制时，在没有输出 token 或工具副作用的同一步内透明压缩并重试；
- 成功 usage 与自然 overflow 只形成“观察到的安全 prompt 预算”，不伪装为模型宣传窗口；
- estimate/footprint 仅是跨请求可比较的内部尺子，绝不是硬限制权威；
- 大多数对话在需要前不做有损压缩；
- 超限时自动治理并继续同一步，不把内部容量错误抛给用户。

### 4.2 sampling 前分层治理

建议最终水位（Phase C0/C1.5 用真实 eval 调优，数字不是未经验证的常量）：

| profile 状态/水位 | 动作 | 信息损失 |
|---|---|---|
| Anselm Auto authoritative，或外部模型已学习且高置信：低于安全线 | 不动 | 无 |
| 已知安全线附近 | housekeeping：旧可重取 tool result → marker，保留最近完整工具组 | 近似无；可精确重取 |
| 已知安全线附近仍不够 | semantic continuation checkpoint，目标回落到有足够恢复余量的位置 | 有损但结构化、可重取 |
| 外部模型未知/低置信 | 不因本地窗口猜测压缩；完整尝试 | 无 |
| provider overflow | 对同一 sampling 做 recovery checkpoint 后透明重试一次 | 同上 |
| recovery 仍 overflow | 仅当最新不可分输入自身过大才诚实失败，并给可操作建议 | 不撒谎 |

对 Anselm Auto，网关 profile 给出 route-specific 安全线；对外部模型，安全线从“最大成功足迹”与
“最小上下文超限足迹”的保守区间收敛。route/model/config 变化、长期未使用或发现更低失败点时必须降低
置信度，不可永久相信旧样本。

### 4.3 checkpoint 必须保留

- 用户目标、明确约束、已拍板决策；
- 当前计划与每项状态；
- 已修改文件、关键符号、未提交差异；
- 工具调用的事实结论，而非大段原始输出；
- 错误与已证伪路径；
- 未完成事项、阻塞、下一步；
- attachment/document/entity 的稳定 id；
- 媒体证据引用坐标；
- “摘要有损、需要精确值时重取”的明确声明。

### 4.4 上下文遥测

assistant message 的 `attrs.contextUsage` 分开记录：

- 当前 sampling 真实/预测 input；
- active route 与 budget；
- system/history/tools/media proxy 各自 footprint；
- cleared tool bytes；
- housekeeping/checkpoint/recovery 次数和模式；
- provider reported usage；
- profile source、置信度、最大成功与最小失败足迹（均无内容）；
- 清洗后的上下文错误分类及是否透明恢复；
- 不记录任何内容正文。

UI 默认不展示工程数字；诊断面板和导出诊断包可读取。

### 4.5 Model profile 与配置 contract

能力与配置分开建模。普通聊天固定为 `Anselm Auto`，不显示 model picker 或 provider 参数；网关下发
权威 route profile。外部模型 API Key 模式先选择 provider/key/model，再取得当前有效 profile：

1. 能力三态：`confirmed`、`unsupported`、`unknown`；普通表单只展示 `confirmed` 字段；
2. 配置 schema 是 provider-native 的 typed option map，字段可含 model/模式条件，例如
   `enable_thinking`、`thinking_budget`、`reasoning_effort`；不制造跨 provider 的伪统一 effort；
3. 表单与受控 `nativeSettings` JSON 是同一状态。JSON 可覆盖表单字段，但禁止覆盖 model、认证、URL、
   messages、tools 或其他请求骨架；
4. schema 来源按优先级：Anselm gateway route profile → provider 可读元数据 → adapter 的安全家族默认
   → 用户 profile override → 运行时成功/失败观测；未知能力不承诺；
5. 用户显式 JSON 报参数不支持时，记录该模型/配置组合的负能力，但不得悄悄删除用户参数后重试。

---

## §5 Media Ingestion：原件、派生物与感知

### 5.1 通用摄取状态机

```text
selected
  → hashing
  → stored-original
  → deriving
  → indexed
  → ready

任一步 → failed(retryable | terminal)
取消 → cancel + 清临时产物
```

发送可以在本地 original 已落盘后立即接受；需要媒体证据的 assistant 回合在后台进入“正在准备/理解”，
不让 composer 阻塞在一个无响应上传按钮上。

### 5.2 图片

派生物：

- `thumbnail`：UI 用，约 320 logical px；
- `model-default`：纠正 EXIF orientation、剥离 metadata、长边约 2048；
- `model-detail`：按裁剪区域从原件生成，不长期预建。

编码策略：

- 照片：高质量 WebP/JPEG，质量由 SSIM/视觉回归确定；
- 文字截图、图表、代码：PNG 或 lossless WebP，禁止有损压糊文字；
- 超长页面：切 tile + OCR 索引，Agent 按区域取图；
- 动图：保留时间语义，转短视频/关键帧，不静默只取首帧。

图片 token 更接近像素网格而非 JPEG 大小；降分辨率既省 token 也省 encoder 时间。不得为了省字节把
关键文字变得不可读。

### 5.3 音频

两条产品路线：

1. **听写**：PCM stream → ASR；final 文本进入草稿，音频即销毁。
2. **音频附件**：original 保留；生成 speech proxy、转写、时间戳、语言、说话内容、非语言声音、情绪/
   语气与不确定点。

编码：

- Flutter → sidecar：PCM16/16k/mono，保证三平台稳定；
- sidecar → realtime ASR：优先 Opus（若跨平台编码验证通过），否则 PCM；
- speech proxy：面向语音的低码率版本；
- 音乐/环境声分析不得套 speech 低码率，按任务从原件截取高保真片段。

### 5.4 视频

默认不把整部 MP4 塞进主 Agent：

1. probe 元数据；
2. 场景切分；
3. 关键帧 + 时间轴；
4. 音轨提取和转写；
5. OCR/字幕；
6. 依据用户问题选择片段/帧；
7. 只在短片或时序问题确需整段时做一次原生视频感知。

长视频 capsule 至少包含：

- 总览；
- 章节/镜头时间范围；
- 音频转写索引；
- 画面事件；
- 人物/对象稳定引用；
- 不确定点；
- 可复查的 `start/end/frame`。

### 5.5 PDF、Office、文本

- 解析一次，保留页码、标题层级、表格、代码块和图片位置；
- 内容分块 + 本地索引，普通提问只取相关块；
- 整文总结走 map/reduce，不把 400K 字符一次内联；
- 扫描 PDF 走 OCR，明确标出 OCR 置信和页码；
- 原生文档输入只在模型确实更优且成本合理时使用一次；
- 主 Agent 永远持 document/attachment id，可经工具精确取页/段。

### 5.6 感知证据包

草案：

```json
{
  "attachmentId": "att_...",
  "sourceSha256": "...",
  "task": "用户本轮问题",
  "summary": "...",
  "transcript": [
    {"startMs": 1200, "endMs": 4600, "speaker": null, "text": "..."}
  ],
  "observations": [
    {"kind": "visual|audio|ocr|document", "at": "00:14.2|page:7|crop:x,y,w,h", "text": "..."}
  ],
  "uncertainties": ["..."],
  "recommendedRechecks": [
    {"startMs": 13000, "endMs": 19000, "reason": "..."}
  ]
}
```

capsule 是 prompt 投影，不应成为不可变真理。原件或 source sha 变化时所有派生缓存失效；用户问题不同可
复用通用索引，但 task-conditioned observations 需按 task hash 区分。

### 5.7 `inspect_media` 工具

主 Agent 在以下情况主动调用：

- capsule 明示不确定；
- 用户追问细节；
- 需要读小字、比较两个区域；
- 需要音色/背景声而非转写；
- 需要验证视频某个时间范围；
- capsule 与其它证据冲突。

输入草案：

```json
{
  "attachmentId": "att_...",
  "question": "...",
  "page": 7,
  "startMs": 13000,
  "endMs": 19000,
  "crop": {"x": 0.1, "y": 0.2, "width": 0.4, "height": 0.3},
  "detail": "default|high"
}
```

工具必须有界：时间段、页数、像素、输出 token 均有上限；超界时返回可自纠的建议，而非倾倒原件。

当前落地状态（2026-07-24）：image v1 已接入工具层。`inspect_media` 对 image 附件生成有界 `model-default`
v2 代理/normalized crop，走默认 dialogue 视觉路由，受管 Anselm 网关优先传短期 HTTPS URL，结果只回 JSON
文本证据；document page、audio/video time range 仍在后续 M2/M3。

---

## §6 一次性媒体传输

### 6.1 目标协议

聊天 completion 不再携带大块 base64。精确 wire 在 Phase M1 拍板，但必须满足：

1. sidecar 上传 proxy/目标片段一次，使用 device proof；
2. 网关返回 opaque `mediaId` + expiry + sha；
3. completion 只引用网关签发的 handle；
4. 网关只解析归属于当前 install、未过期、MIME/magic 已验证的 handle；
5. 网关给 Qwen 短期可取 URL或 provider file handle；
6. settlement/取消后删除，TTL 和定期 GC 双保险；
7. 不接受客户端任意 URL。

### 6.2 存储姿态

- 本地 original：长期、workspace 隔离、CAS 去重；
- 网关：只存 proxy/片段，install 隔离，不跨用户 dedup 暴露侧信道；
- 对象存储：private bucket、服务端加密、新加坡同区域、短签名 URL；
- URL/signature 不进 access log、error、audit 或 metrics；
- 取消、失败、超时均释放租约；
- 网关重启后 GC 能发现并清除遗留对象。

### 6.3 为什么不能只调大 body cap

- base64 仍有 33% 膨胀和多次内存拷贝；
- 每次 sampling 仍重复发送；
- Go/反代/provider 都要重新解析；
- 不能断点续传；
- 视频很快越过合理 body 上限；
- context 与 transport 仍耦合。

body cap 继续作为小请求/恶意输入护栏，不承担媒体传输职责。

---

## §7 网关 Qwen 视觉 route

### 7.1 目标 provider 集

- `deepseek`：纯文本主路线；
- `qwen`：图片/视频主路线、Omni 音频感知、ASR；

### 7.2 能力发布

`anselm_capabilities` 升级为能表达至少四个 profile：

- text agent：1M；
- visual agent：Qwen3.7-plus，1M；
- audio perception：Qwen3.5-omni-plus，64K；
- speech realtime：ASR availability。

桌面端只把前两者当作主 Agent input budget。不能把 perception window 写进 conversation budget。

**产品边界（已裁定）**：Realtime ASR 是 Anselm 受管默认模型的专属输入能力。只有当前 dialogue
route 解析为内置 `anselm` 时，composer 才发布 microphone 状态；它经网关使用受管 Qwen 凭证、统一
quota/ledger 和 device proof。任何 BYOK/custom route 均不探测、不猜测、不显示录音按钮，更不把用户
音频交给未经明确适配的第三方 key。切换模型期间按新 route 即时重算资格；已有可编辑文字不受影响。

### 7.3 Qwen adapter

必须独立实现并测试：

- text/image/video/audio content part；
- Qwen3.7 与 Qwen3.5 Omni 的 `stream` 约束；
- `modalities` 与 text-only output；
- `enable_thinking` 显式控制，避免简单请求产生大量默认 reasoning token；
- reasoning/content/tool_call/usage SSE；
- flat error envelope 与 200-in-stream error；
- provider overflow 分类；
- cancel、timeout、连接中断；
- remote handle/file URL；
- max output 与实际 reserve 对齐。

### 7.4 计费与预算

- rate card 按模型、区域、输入档位、模态区分；
- Qwen3.7-plus 256K 以上的阶梯价必须进入 reserve；
- Omni 区分 text/image/video/audio usage；
- ASR 按官方时长或 token 口径入账；
- 先 pessimistic reserve，收到 usage 后 settle，多退少补；
- 双阶段“感知 + 主 Agent”是两笔真实成本；
- quota 与 global budget 不得因两阶段并发而 oversell；
- provider/model 不进入高基数 metrics label，模型细节留 ledger。

### 7.5 部署顺序

1. 服务器添加新 Qwen secret 和非敏感配置；
2. readiness 探针通过；
3. shadow/canary 仅跑固定金标，不接真实用户内容；
4. 开视觉路线；
5. 验证 ledger、错误率、首 token、媒体准备时长；
6. 开音频 perception；
7. 更新 dashboard、文档和回滚 bundle；
8. 旧二进制回滚时必须与对应 DB/config 一起回滚，禁止只换 symlink。

---

## §8 麦克风听写 UX

### 8.1 composer 按钮优先级

| 优先级 | 状态 | 右侧 |
|---:|---|---|
| 1 | Agent generating | stop generation |
| 2 | recording | stop recording |
| 3 | finalizing/fallback transcribing/uploading | spinner，disabled |
| 4 | 有文字或 ready attachment | send |
| 5 | 完全空且当前 dialogue route 是受管 `anselm` | microphone |
| 6 | 完全空但为 BYOK/custom route | disabled mic（不占发送位；显示明确原因） |

附件是 payload；“无文字但有附件”必须显示 send。

### 8.2 交互

1. 首次点击才请求麦克风权限；
2. 本地录音立即开始，远端 WebSocket 并行建立，最多缓冲 1–2 秒；
3. composer 从 pill 展成 card：
   - 左：取消；
   - 中：实时 transcript 为主，波形 + 时长为辅；
   - 右：停止；
4. committed transcript 正常墨色，partial 浅色；
5. `Esc` 取消并销毁；`Enter` 停止；
6. 停止后 `commit`，进入 finalizing；
7. final 写入普通可编辑草稿，按钮变 send；
8. 默认不自动发送。

### 8.3 实时协议

- Flutter 用成熟 `record` 包，读取 PCM stream + amplitude；
- Flutter 只连 loopback sidecar；
- sidecar 只建一次性 WebSocket 到 Anselm 网关；网关以受管 Qwen 凭证代理，桌面端绝不持有或使用
  BYOK key 做 ASR；
- Qwen3-ASR Realtime 使用 Manual mode；partial/final 原路返回；
- 该 WebSocket 是一次性请求会话，不是第四条常驻 SSE；
- partial 状态独立于 `ChatDrafts`，约 50–100ms 合帧；
- final 才写 `TextEditingController` 和 draft。

### 8.4 容错

| 故障 | 用户体验 |
|---|---|
| 权限未决定 | 按钮 loading，不假装已录 |
| 权限拒绝 | 顶带说明 + “打开系统设置”，回 idle |
| 无麦克风 | 明确设备错误，可重试 |
| WebSocket 未连 | 本地继续录，显示“正在连接” |
| 中途断线 | 重连一次；失败则停止 partial、保留本地音频 |
| stop 后实时结果失败 | 自动离线 ASR |
| 离线 ASR 也失败 | 临时卡：重试转写 / 删除；不吞录音 |
| 用户取消 | 终止 capture/socket，删内存/临时文件 |
| app 退出/崩溃 | 启动 GC 清临时录音；不自动恢复私密音频 |

### 8.5 平台

- macOS：`NSMicrophoneUsageDescription` + debug/release audio-input entitlement；
- Windows：设备缺失/被占用/隐私设置路径；
- Linux：`parecord/pactl/ffmpeg` 前置的产品安装与诊断；
- 三平台测试暂停/恢复、设备切换、蓝牙、系统睡眠、应用失焦；
- reduced-motion 下波形不做高频动画，但仍显示电平/时长。

---

## §9 原始音频附件 UX

麦克风主按钮只做听写，避免“这次是打字还是发语音文件”的歧义。原始音频通过附件入口：

- 选择现有音频；
- 后续可在附件菜单增加“录制为音频附件”，不得靠桌面端难发现的长按手势。

发送泡：

- 显示音频卡、时长、大小、转写状态；
- 支持本地播放；
- 感知中显示“正在理解音频”；
- Agent 回答引用时间戳可点击跳到对应位置；
- capsule 已有而原件离线/删除时，明确“可读既有证据，无法重新听取原件”。

---

## §10 语音输出与未来语音模式

本战役不做语音输出。消息朗读本质是 assistant 文本 → TTS → 本地播放，不改变主 Agent、上下文治理或多模态输入链路；它后续应作为独立 UX 增强排期，而不是绑进本次 1M 全模态输入战役。

未来如果单独做，范围只应是 assistant 消息的 speaker 按钮、暂停/停止、voice/speed、短期缓存和 quota；完整 full-duplex speech-to-speech 仍需另行拍板。

---

## §11 数据模型与契约草案

> 本节只定义语义，施工时以代码 + `references/` 精确契约为准。任何字段/端点变更必须同提交更新
> api/database/error-codes/events/domain/frontend contract。

### 11.1 主仓建议新增

`attachment_derivatives`：

- workspace_id；
- attachment_id；
- derivative kind；
- source sha / params hash / derivative sha；
- MIME / bytes / width / height / duration；
- local blob ref；
- created_at；
- `(attachment_id, kind, params_hash)` 唯一。

`attachment_perceptions`：

- workspace_id；
- attachment_id / source sha；
- perception kind；
- model/provider；
- task hash；
- capsule JSON；
- input/output usage；
- created_at；
- source sha 变化即不命中。

不建议把不断增长的派生字段堆进 `attachments` 主表。

### 11.2 主仓 API/实时

候选端点：

- 查询 attachment preparation/perception；
- 请求/重试 perception；
- 按范围读取 derivative；
- 一次性 speech transcription WebSocket。

attachment/assistant 的准备进度优先复用 `messages` SSE 的 ephemeral block/progress 语义；不新增全局流。

### 11.3 网关 API

候选能力：

- device-proof multipart/resumable media upload；
- media lease status/delete；
- completion 引用 opaque media handle；
- realtime speech WebSocket；
- quota 返回分项/聚合成本；
- `/models` 发布 route capability v2。

媒体 lease id 必须高熵、install 绑定、有 TTL，且不可从 sha 推导。

### 11.4 错误语义

需要稳定区分：

- 本地读文件失败；
- 不支持的容器/codec；
- 媒体准备失败；
- 转码失败；
- 感知失败；
- realtime 断线；
- 权限拒绝；
- provider 拒绝；
- context overflow；
- request/body/media safety cap；
- quota/budget；
- lease expired/ownership mismatch。

用户文案必须告诉“下一步能做什么”，不能把所有情况归成 `LLM_STREAM_ERROR`。

---

## §12 执行顺序

> 每阶段只有在代码、文档、自动门禁和规定的真实验证全部完成后，下一阶段才开工。允许同阶段内部并行，
> 不允许跨依赖抢跑。

### C0 · 基线、金标与拍板

**目标**：先建立可量化基线，冻结本 working 的关键决策。

- 用户 review §15；
- 建媒体金标集：照片/文字截图/长图/PDF/Office/短视频/长视频/纯语音/音乐/混合媒体；
- 建 1M 长对话和长单回合 eval；
- 量当前每 sampling：body bytes、prompt usage、首 token、总时长、费用；
- 为 Kimi 当前路线留一次只读基线，迁移后不保留实现；
- 明确 Qwen workspace-specific domain、正式新 key、预算；
- 确定 proxy 质量阈值、租约 TTL、语音最长时长；
- 产出 ADR 清单。

**出口**：基线报告 + 用户拍板 + fixture 可重复。

### C1 · 收口现有上下文治理

**目标**：先彻底解决 `input too large`，使后续媒体链有可靠 Agent 宿主。

- 审查并完成当前 worktree 的 context changes；
- sampling route-aware budget；
- housekeeping/checkpoint/provider-overflow recovery；
- utility/primary/deterministic 三层 checkpoint；
- durable summary/watermark；
- `contextUsage` 观测；
- 长对话、长 tool result、不可分大输入测试；
- 调整 80/90/target 水位；
- 主仓 reference/concept/CLAUDE 当前状态同步。

**出口**：纯文本 1M 压力测试中不出现可自动恢复的用户可见 overflow。

### C1.5 · Runtime model profile、自然撞墙与动态配置

**目标**：让 Anselm Auto 有网关权威能力合同，让未知外部模型不靠静态窗口表也能透明恢复并逐步收敛。

**2026-07-24 实施进度**：

- 已落地：外部模型 profile 以 endpoint / 加密凭证版本 / model / text-or-multimodal / config 的不透明指纹隔离；只存数值足迹，绝不存 prompt、附件、原始上游报错或明文 key。
- 已落地：外部模型不再把静态目录的 context window 当主动压缩预算；首个真实且无输出/无工具副作用的 context overflow 走同一步透明 checkpoint 重试。只有该重试成功后，才产生带 30% 余量、30 天 TTL 的软预算；密钥轮换、端点/模型/配置/模态变更天然换画像，后续更低 overflow 只会收紧预算。
- 已落地：`contextUsage` 留下 overflow/recovery 的安全测量；未分类的上游 HTTP body 不再透传到用户面。Anselm Auto 仍唯一使用网关 `anselm_capabilities` 的 route profile（文本与图片/视频均为 1M）。
- 已落地：Flutter 已解析并呈现 text / media 两条 input limit，而不是把一个泛化窗口误作全部事实。
- 待验收：真实“首次自然恢复 → 学习后稳定治理”金标已加 `EVALS_NATURAL_OVERFLOW=1` 双门，但当前本机无 `EVALS_KEY` / `DEEPSEEK_API_KEY`，故安全跳过、未产生计费；补齐本地环境后必须跑一次。
- 已落地：默认设置页把 Anselm Auto 分离为无参数的网关模式；只有显式选择外部模型才进入凭证/模型/已确认 native knob。所有 workspace default、agent override、conversation override 的非空 options 均在写时匹配精确已探测 key/model 的公开 knob 与值，未知或非法参数显式失败，adapter 不再静默丢设置。
- 已落地：外部模型的高级 native JSON 编辑器与通用 knob 表单双向同步；JSON 只能携带当前已探测 model 公开的 string 旋钮和值，前端立即拒绝 `model`、认证、URL、messages、tools、stream 等非契约字段，服务端仍作同一验证。
- 已落地：`get_model_config` 工具返回可用模型的 context/output、text/multimodal route budget、模态位、media envelope 与 `nativeOptions` knobs，使 Agent 能从真实配置回答“这个模型支持什么配置”，而不是猜外部文档。
- 已落地：HTTP 与 HTTP 200/SSE 流内的 provider 拒绝统一经闭集 reason 判别；识别到 context-length 时同样进入无输出、无工具副作用的透明 checkpoint 重试，未识别的上游文本只在进程内判别后丢弃，用户面仅见脱敏 provider error。
- 待完成：对仍无法以闭集 reason 判别的异常，评估是否需要独立、无上下文且不携带原始错误文本的二次诊断；默认不猜测、不重试。
- 待验收：单元/黑盒已覆盖主路径；真实外部模型“首次自然恢复 → 后续稳定治理”金标仍需本机补齐 key 后烧一次。

**出口**：未知外部模型不因本地猜测被拒绝；自然 overflow 对用户透明恢复；Anselm Auto 与外部模型模式都只暴露
诚实的能力/配置；没有可恢复的用户可见上下文错误。

### C2 · 主仓 Qwen 能力补齐

**目标**：Anselm 能诚实描述并编码 Qwen3.7/Omni。

- 已落地（第一、二块）：Qwen compatible-mode renderer 现原生编码 `video_url` 与 `input_audio`；视频保持 data/public URL，音频按官方 `{data,format}` 形状带 data URL（`audio/mpeg` 正确映射为 Qwen 所需的 `mp3`）。目录诚实发布 `qwen3.7-plus` 的 1M/64K、图片/视频输入，`qwen3.5-omni-*` 的 64K、图片/视频/音频输入；Omni 未公开统一 text max-output 数字时保持未知，绝不杜撰。wire/capability 测试锁定，尚未宣称媒体一次性上传或放开 transport body。

- Qwen specs：1M Qwen3.7、64K Omni、max output、vision/video/audio；
- Qwen content renderer 支持 video/audio；
- stream/modalities/thinking/tool/usage/error；
- attachment caps 与 provider specs 一致；
- 外部模型 API Key 下的 Qwen 新加坡 domain；
- provider 单元/集成金标。已新增显式付费的 C2 黑盒金标：须提供 `EVALS_KEY`、
  `EVALS_BASE_URL=https://{WorkspaceId}.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1`，再运行
  `EVALS_PROVIDER=qwen make -C backend qwen-evals`。它校验固定图/MP4/WAV 素材、分别真实调用
  Qwen3.7 图像/视频、Omni 音频，并确认 Qwen3.7 工具调用后有 `tool_result` 与最终续答；没有本机
  secret 时安全跳过，绝不以静态测试冒充真实调用。

**出口**：本地外部模型 API Key 下的 Qwen 可分别完成图、视频、音频和工具 continuation。

### C3 · 网关 Qwen 视觉 route

**目标**：公网免费档 route 与账本完成迁移。

- 已落地：provider adapter/registry、rate card/ledger/reserve/settle、config/env/readiness/dashboard/metrics；
  初始 DB migration 只允许当前闭集 `deepseek|gemini|qwen`；e2e、race、故障注入、文档与部署构建脚本均已通过。
- 已落地：Anselm 静态 fallback 与 synthetic probe 的 visual profile 均为 1M。
- 已验收：2026-07-24 已通过两轮 GitHub CI 及生产级 race / integration / fuzz / coverage / docs / lint / vuln
  门禁；因项目未上线，已从受确认的部署工作流中一次性清除旧 Kimi-era SQLite 状态，生产 Qwen 版网关完成
  双本机 gate、公开 `/healthz` 及静态站点 smoke，均为成功。`/v1/models` 未携带 device proof 返回 401，符合
  鉴权合同。
- 待验收：使用新 device install/proof 进行真实 Qwen text/visual 计费链与模型目录 smoke；真实运行时继续使用
  version 1 的 text/multimodal route profiles，音频 capability v2 随 M3 才发布。

**出口**：text/visual route 都真实可用；视觉 profile 发布 1M；账本对账为零差异。

### M0 · Media Ingestion 领域地基

**目标**：建立原件/派生/感知三层，不先改漂亮 UI。

- 已落地（2026-07-24，地基第一块）：新增独立 `media` domain 与 SQLite 的
  `attachment_derivatives` / `attachment_perceptions`。每条记录以 workspace、attachment、kind、
  source SHA、canonical params hash 为身份；感知再加 task hash、provider、model。task 仅落 SHA-256，
  不把用户问题、原件、原始上游回复写入台账。唯一索引在并发冲突时收敛到同一条 pending work；source、参数、
  task 或模型任一变化都会产生新 work，而非误复用旧结果。启动装配已接入，但尚未改变聊天的 inline-media wire。
- 已验证：应用层对无序 map 参数生成同一 canonical JSON hash；store 层覆盖 exact reuse、参数/source/task/
  model 失效和 workspace 隔离；`go test ./...` 通过。
- 已落地（worker 骨架）：派生产物写入独立 media CAS，绝不与原件共用 attachment GC；单 worker 仅领取
  pending、ready 记录绝不重跑；优雅关闭把中断项退回 pending，硬崩遗留 running 在下次 boot 归还；媒体 GC
  严格发生在 worker 启动前，避免“写入 artifact、尚未提交 ready 行”时被误删。当前没有配置具体图片/文档/
  音视频 processor，故这一步不会悄悄改变现有附件/聊天行为。
- concrete processor、用户取消/retry API、进度模型；
- 磁盘配额和清理；
- fake processor 测试。

**出口**：同一附件重复请求不重算，参数/source 改变准确失效。

### M1 · 一次性媒体上传与 lease

**目标**：聊天请求退出大 base64 时代。

- 已落地（网关）：device-proof create → strict-offset raw chunk → complete 的可恢复 staging protocol；SQLite
  upload/lease 状态机、私有 staging file、TTL/crash recovery/GC、opaque install-bound lease，以及仅供
  上游拉取的短期 HMAC fetch URL。该 endpoint 不接受客户端上传 proof 的替代品，且不可用/过期 token 一律
  归并为无信息泄露的 not-found。
- 已落地（sidecar 主路径）：受管 Anselm 路由的图片与 MP4 走上述 protocol，聊天 request 只留下 expiring
  HTTPS URL；客户端校验每一 chunk 的 server offset，拒绝错误确认；lease 仅在进程内按网关/install/MIME/SHA
  缓存，离过期 30 秒自动刷新，因此同一 ReAct 与后续聊天的历史重建都不重复上传同一原件。普通 BYOK 不猜测支持
  该私有协议，保留各自 provider 的原生 inline wire。
- 已落地（ambiguous PUT recovery）：网关受 device proof 保护的 upload-status 返回 open cursor；sidecar 在
  chunk 响应中断、无法确定服务端是否 fsync 时先读 cursor，再从已确认 offset 继续，绝不盲重放。
- 已落地（cancel/delete）：受 proof 保护的 DELETE 先 durable abort 再删私有暂存字节；sidecar 对上传失败或
  caller cancel 使用独立的一秒有界上下文 best-effort 回收，cleanup 失败绝不覆盖原始错误，网关 TTL/GC 仍作兜底。
- 已落地（MIME 与审计）：complete 从 staged bytes magic 重验 PNG/JPEG/WebP/MP4/WAV/MP3；metrics 仅使用固定
  route label，日志硬脱敏涵盖 `fetchPath`/URL/query capability，绝不记录 lease token、原始媒体或 prompt。
- 待落地：部署时启用网关媒体配置后的真实端到端抓包。

**当前出口**：单次十步 ReAct 对同一媒体只上传一次；本地主聊天 wire 无重复 base64。M1 完整出口仍要求跨回合
lease refresh/reuse 与生产 E2E 验证。

### M2 · 图片与文档优化

**目标**：先落确定性最高、用户最常用的媒体族。

- 已落地（图片代理）：`ImageProcessor` 接入 media worker，支持 `thumbnail` / `model-default` /
  `model-detail` 三类派生图；执行参数以 canonical `params_json` 落表、`params_hash` 仍作身份，故 crop/detail
  能被 worker 精确复现而不把用户任务文本写入表。处理链使用成熟 imaging 库：EXIF auto-orientation、normalized
  crop、透明图保 PNG。`model-default` v2 会按样本色彩和长宽比做确定性分型：照片按最长边 2048 生成 JPEG；
  截图/透明图/低色彩多样性图优先保 PNG；长图按 1536×8192 封顶，避免把可读宽度压碎。内置 Anselm
  网关发送图片时优先上传 ready 的 `model-default` 代理图；代理未 ready 时本回合最多短暂等待本地 worker
  产出，超时/失败才退回原件上传并让后台任务继续追上，后续 sampling/回合复用代理图。
- 已落地（图片重取）：`inspect_media` lazy tool 支持 image 附件按 `attachmentId + question + crop/detail`
  做一次受控视觉检查；工具内部发送有界代理图，主对话只收到 JSON 文本证据。触点目录按
  `attachmentId` 记录 viewed，方便右侧岛/审计知道 agent 复看了哪个附件。
- 已落地（准备状态）：`POST /attachments` 与 `GET /attachments/{id}` 返回 `preparation` 侧车；image
  上传/查询会认领 `model-default` 代理 work 并暴露 `pending/running/ready/failed`，非 image 为
  `not_required`，侧车异常降级 `unavailable` 且不影响原始附件可发送。
- 已落地（文档工具分页）：`read_attachment` 对 text/document 默认只返回 80K 字符页，最大 120K，
  截断时给 `nextOffset`；agent 不再因一次重读旧 PDF/文本把 400K 抽取内容重新塞进主上下文。
- OCR/tiles；
- document parse/chunk/index/map-reduce；
- `inspect_media` 的 document page 能力；
- 视觉/文档质量与 token/延迟 A/B。

**出口**：金标准确率不退化，媒体 bytes/token/时延显著下降。

### M3 · 音频与视频感知

**目标**：用 evidence capsule 取代主循环反复原生媒体。

- audio proxy/ASR/non-speech/prosody；
- video probe/scene/keyframe/audio/OCR/timeline；
- task-conditioned perception；
- capsule cache；
- `inspect_media` time range；
- mixed audio + visual orchestration；
- 感知进度进入现有消息 UI。

**出口**：主 Agent 每个 sampling 不含原始音视频；引用可跳页/帧/时间并复查。

### V0 · Realtime ASR 后端链

**目标**：先让没有 UI 的、仅受管默认模型可用的协议在故障注入下可靠。

- sidecar speech WebSocket；
- gateway device-proof speech proxy；
- Qwen3-ASR Manual mode；
- partial/final/commit/cancel；
- heartbeat、timeout、重连；
- 本地 buffer + offline fallback；
- quota/ledger；
- eligibility contract：仅 `anselm` dialogue route 发布能力，BYOK/custom 一律 unavailable；
- fake upstream 与真 key eval。

**出口**：三类断网、取消、超时、权限前置均不丢最终可恢复状态。

### V1 · composer 麦克风 UI

**目标**：落 §8 完整交互。

- `record` 集成与平台权限；
- composer 状态机；
- transcript/波形/时长；
- final→editable draft；
- i18n/a11y/reduced motion；
- attachment/generating/landing/docked 优先级；
- 根据当前 dialogue route 即时显示/隐藏 microphone；BYOK/custom 显示不可用原因而不发起探测；
- gallery specimen + widget matrix；
- macOS/Windows/Linux 真机。

**出口**：一分钟中英混合听写、取消、断网 fallback、权限拒绝全程无误发送/吞内容。

### V2 · 原始音频附件体验

**目标**：音频不是一个“generic file”。

- 音频卡、播放、时间轴；
- 感知状态；
- 时间戳引用跳转；
- 录制为音频附件入口；
- 原件删除/离线的诚实降级。

**出口**：语音听写和原始音频理解心智不混淆。

### H0 · 全链硬化与战役收口

- 两仓全量 verify；
- 主仓 testend 相关域；
- 网关 race/e2e/fuzz/security/rollback；
- 1M 长跑、媒体并发、断网、磁盘满、provider 429/5xx/overflow；
- 性能与成本基线对比；
- 隐私/日志抽检；
- 正式 key rotation；
- 当前形态提取进 `concepts/`、`references/`、ADR、CLAUDE；
- 填本篇 `landed-into`，移入 archive。

---

## §13 测试与验收矩阵

### 13.1 上下文

- 0/80/90/99% 水位；
- 单个巨大 user input；
- 单个巨大 tool result；
- 多轮小工具累积；
- tool-call 协议跨 checkpoint 完整；
- summary + watermark 崩溃点；
- provider 首次 overflow、压缩后成功；
- recovery 后仍失败；
- text→media→text route budget 切换；
- usage 缺失/异常；
- utility 不可用。

### 13.2 媒体

- MIME/扩展名/magic 不一致；
- EXIF 旋转、透明图、CMYK、超长图、动画；
- 扫描 PDF、表格、代码、混合语言；
- 无音轨/多音轨/可变帧率/损坏视频；
- 静音、噪声、方言、中英混说、音乐；
- 同 sha 重复上传、跨 workspace 隔离；
- derivation 取消/崩溃/重启；
- lease 过期、越权、重复 delete；
- provider fetch 迟到；
- 原件在感知后删除；
- capsule 与原件冲突后的复查。

### 13.3 composer/语音

- empty/text/attachment/uploading/generating/recording/finalizing；
- landing 与已有 conversation；
- IME composition；
- permission allow/deny/restricted；
- 无设备、设备被占用、录音中拔设备；
- start 前断网、中途断网、stop 后断网；
- cancel 与 late partial/final；
- rapid double tap；
- conversation switch/app background/window close；
- reduced motion/a11y/键盘；
- 5 分钟上限与内存；
- fallback 后编辑再发送。

### 13.4 网关/计费

- 每模型/模态/价格档 reserve；
- 感知 + 主 Agent 双账；
- usage settle、多退少补；
- cancel/timeout/open ledger recovery；
- 多 key breaker；
- install quota/global budget 并发；
- body cap 与 media lease cap 分离；
- 原始 provider error 不泄漏；
- secret/media/prompt redaction；
- deploy/rollback DB 兼容单元。

### 13.5 必须真实验证

- 本机 + 现有服务器最小真调用；
- macOS 真麦克风；
- Windows/Linux release 构建与录音 smoke；
- 至少一张文字截图、一份扫描 PDF、一段视频、一段环境声；
- 长对话真实 provider eval；
- 网关 production-like TLS/device-proof/对象存储链；
- 成本后台与本地 ledger 对账。

---

## §14 SLO、隐私与运营

### 14.1 初始 SLO（C0 用基线调整）

| 指标 | 目标 |
|---|---|
| 麦克风点击到本地录音态 | ≤150ms |
| 首个 partial transcript | 正常网络 P50 ≤1s，P95 ≤2s |
| stop 到 final 草稿 | P50 ≤700ms，P95 ≤2s；fallback 另计 |
| 小图片准备 | P95 ≤1s |
| 媒体重复上传 | 同 attachment/task 的正常 ReAct = 0 |
| 自动 overflow 恢复 | 用户不可见成功率 ≥99%（不可分输入除外） |
| lease 清理 | settlement 后即时；TTL 到期后一个 GC 周期内 |
| 内容泄漏 | log/metric/audit = 0 |

### 14.2 诊断指标

低基数 metrics：

- route/provider；
- media kind；
- derive/perception outcome；
- ASR outcome；
- context action；
- lease lifecycle；
- latency histogram；
- bytes/tokens/cost aggregate。

禁止 label：

- model id（保留现有低基数纪律）；
- install/workspace/conversation/attachment id；
- filename、MIME 原串；
- prompt/transcript/media；
- URL、IP、key。

### 14.3 用户控制

- workspace 设置可关闭云端媒体感知；
- 明确显示本次媒体将被发送到模型 provider；
- 删除 attachment 同时安排派生物/感知缓存清理；
- 数据导出说明 original/derivative/perception 的范围；
- 出厂重置覆盖所有本地媒体真相；
- 免费档 server lease 不构成长存备份。

---

## §15 待用户 review / 拍板

| # | 建议默认 | 待确认 |
|---:|---|---|
| 1 | 主路由采用 §3.1：DeepSeek text、Qwen3.7 visual、Omni perception | 是否确认 |
| 2 | Qwen 是唯一视觉主 route，无 fallback | 已确认 |
| 3 | text/visual 主 Agent 均发布真实 1M；Omni 明示 64K 感知器 | 是否确认 |
| 4 | Anselm Auto 用网关 profile；外部模型自然撞墙透明恢复并学习安全预算，高置信后才主动治理 | 已确认 |
| 5 | 原件长期只在本地；公网只放 proxy/片段短租约 | 是否确认 |
| 6 | 图片默认长边约 2048；文字截图优先无损 | 是否确认 |
| 7 | 长视频默认关键帧+音轨+按需片段，不整段反复送 | 是否确认 |
| 8 | 麦克风主按钮=听写，停止后可编辑，不自动发送 | 是否确认 |
| 9 | 原始音频通过附件/“录制为音频附件”，不靠长按麦克风 | 是否确认 |
| 10 | 本战役不做语音输出；消息朗读/TTS 后续独立排期 | 已确认 |
| 11 | 免费档媒体使用新加坡 private object storage 短租约 | 是否确认/指定存储 |
| 12 | working 的执行顺序 C0→C1→C1.5→C2→C3→M0…H0 | 已确认 |
| 13 | 默认 UI 只显示 Anselm Auto；外部模型 API Key 模式才显示 provider/model picker | 已确认 |
| 14 | 外部模型配置表单完全由有效 capability/config profile 驱动；专家可填受控 native JSON | 已确认 |

---

## §16 完成定义与文档落点

战役完成必须同时满足：

- §1.1 全部目标；
- §3.3 十条不变量有自动守卫；
- §12 所有已拍板阶段完成；
- §13 测试矩阵无未解释红项；
- 两仓门禁和真实验证通过；
- Qwen 视觉 route 已作为唯一实现；
- 正式新 key 已轮换；
- 旧 base64 媒体主路径删除；
- 当前事实同步到：
  - `CLAUDE.md`；
  - `docs/concepts/architecture.md`；
  - `docs/references/backend/{api,database,error-codes,events}.md`；
  - `docs/references/backend/domains/{attachment,chat,messages,support-services}.md`；
  - `docs/references/backend/foundation/{loop,stream-llm}.md`；
  - `docs/references/frontend/{architecture,contract,design-system}.md`；
  - `docs/references/frontend/features/chat.md`；
  - 新 ADR；
  - `Anselm-API-Serve` 对应 concept/reference/ADR/README/config。
- 本篇填 `landed-into` 后移入 `docs/archive/`。

---

## §17 外部事实源

- Qwen3.7-plus：text/image/video、1M context、64K max output  
  <https://www.alibabacloud.com/help/en/model-studio/vision-model>
- Qwen3.5 Omni：图/视频/音频混合输入、音频/视频时长与 OpenAI-compatible wire  
  <https://www.alibabacloud.com/help/en/model-studio/qwen-omni>
- Qwen-ASR Realtime：WebSocket、Manual/VAD、partial/final/commit  
  <https://www.alibabacloud.com/help/en/model-studio/qwen-asr-realtime-interaction-process>
- Qwen Omni Realtime：WebSocket/WebRTC、音频 token、会话限制、未来语音输出能力  
  <https://www.alibabacloud.com/help/en/model-studio/realtime>
- 阿里模型价格：Qwen3.7、Omni、ASR/TTS 的区域与模态价格  
  <https://www.alibabacloud.com/help/en/model-studio/model-pricing>
- Flutter `record`：三桌面平台、PCM stream、amplitude、权限配置  
  <https://pub.dev/packages/record>
- Apple 麦克风权限  
  <https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSMicrophoneUsageDescription>
