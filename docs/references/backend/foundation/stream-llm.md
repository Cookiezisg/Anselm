---
id: DOC-032
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-21
review-due: 2026-10-19
audience: [human, ai]
---

# stream + llm —— SSE 总线与 LLM 端口

## stream（domain 协议 + infra Bus）

**domain/stream 是传输协议**（与 messages 的内容模型刻意分离）：`Frame` 四型 open/delta/close/signal；`Scope{Kind, ID}` 实体锚定；**durable/ephemeral 双轨**（E2）——durable 帧（open/close/非 ephemeral signal）分 seq 入 replay 环，ephemeral 帧（delta/tick）seq=0 实时扇出、不入环、订阅者满则丢（token 级 delta 永不撑爆窗口/卡生产者）。close 带快照供 replay。

**infra/stream 是进程内 Bus**：一个类型实例化三次（messages/entities/notifications，E1）；per-workspace seq + replay 环；重连从续传游标重放（`Last-Event-ID` 头优先、否则 `?fromSeq` 查询参，缺/坏 → 0 仅实时），环已淘汰 → `SEQ_TOO_OLD`（410 Gone，前端全量重拉）。v1 按 workspace 全量推、前端自滤（E1 约定）。

## llm（provider 端口）

`Client` 单方法 `Stream(ctx, Request) iter.Seq[StreamEvent]`——全部 provider（anthropic/openai/google/deepseek/qwen/zhipu/moonshot/openrouter/ollama/custom/anselm，共 11 家）适配到同一事件流（text/reasoning delta、tool start/delta、finish 带 token 计数）。要点：
- **能力目录 follow models.dev（WRK-082 批A）**：六个贫 `/models` 家（openai/anthropic/deepseek/qwen/moonshot/zhipu）的能力数字与**模态数组**出自 `modelcatalog.json`（models.dev 裁剪快照,vendored 入库,`make update-model-catalog` 刷新;裁剪谓词 = `tool_call` ∧ 输出含 text ∧ id 不含 realtime）+ 运行时刷新（boot 后 30s 一次、24h TTL、失败静默留旧,缓存 `<dataDir>/modelcatalog/catalog.json` 优先于 vendored）。投影公式 **目录模态 ∧ 方言 partMask**（模型会读 PDF 但方言渲不了 file part 则不宣称——能力描述整条路）;旋钮仍按家手写（`knobRule` 前缀表,P4）。豆包（doubao）随 follow 整家撤除（P2）;gemini/openrouter（富 `/models`）与 ollama/custom 不经目录。
- **生成方言（WRK-082 批B/批C）**：`imagegen.go` 五方言(anselm/openai/google/qwen/zhipu)出图,`speechgen.go` **四条路只有三种 wire**——OpenAI 与智谱共用 `/audio/speech` 形(字段名逐字相同、响应裸字节)、DashScope 只有原生 `multimodal-generation` 形(嵌套 `input`、JSON + OSS URL,**无** OpenAI 兼容 TTS 端点)、Gemini 返 base64 **无头 PCM** 由本层自封 WAV。一切收敛到**一个**中间表示 **24kHz/16bit/mono PCM(WAV 容器)**:这不是偏好而是「切块再拼」的前提——各家单请求上限都远低于一条长消息(qwen3-tts ~500 字符、智谱 1024),故长文本必须切开再拼,而 PCM 靠字节拼接即重合、MP3 帧拼接会留听得见的缝;四家原生输出恰好全是此规格,整条流水线零重采样。`ParseWAV` **遍历 chunk 表**而非假定 44 字节头(真实编码器会夹带 LIST/fact,按固定偏移读会把元数据当样本);`ConcatAudio` 在 **PCM 层**重接(按字节追加两个 WAV 会在流中间留下第二个 RIFF 头,多数播放器就停在那儿),格式不一致**大声拒绝**而非静默变调。切块上限与默认音色**按家手写**(`SpeechChunkLimit`/`defaultVoiceFor`)——能力目录的 chat 谓词把纯 TTS 模型整个滤出了目录,**发现不了**;音色名不跨家通用(Cherry 只在 DashScope、coral 只在 OpenAI、Kore 只在 Gemini),故未设音色**按路由**解析。 **视频(批D)** 是本族唯一的**异步**模态:`videogen.go` 给**三个动词**(Submit/Poll/Fetch)而非一个,轮询循环共用、三动词各家不同。**两个方言而非三个**——OpenAI Videos API 已公告 2026-09-24 下线(代拍 D2),一个只剩八周寿命的 driver 会被建、被复审、被删掉却从没挣回成本。**产物是「可取回的引用」而不是 URL**:DashScope 返裸预签名 OSS URL(带 Authorization 反而**可能被拒**),Google 的文件 URI **必须**带 api key——「拿到 URL 就能下」对两家都不成立且方向相反,故 `VideoArtifact{URL, Headers}`。**不给进度百分比**:两家都只给状态字,而用「已耗时÷预估」合成会让进度条在 99% 停几分钟(Veo 官方区间 11s–6min),诚实的状态行胜过一个可被验证为假的进度条。轮询**爬**向厂商节奏(2s 起、×1.5 到上限):厂商文档给的间隔是**上限**、其限流建议说的正是上限,而固定首轮等待会让上游校验就失败的任务白付一整个周期的沉默。同家两形按模型分支(wan2.7 用 resolution+ratio、2.6 及更早用 size);不可能的组合(向 Veo 要 15 秒)**在客户端钳**到该路由做得到的长度、receipt 报**真正做出来**的那个。
- **sanitizer**：发送前守 `assistant.tool_calls ↔ tool` 配对——孤儿 tool_call 合成 stub 回复（LLM 看见被打断、严格 provider 不 400）。被取消的回合重续就靠它。
- **deepseek 全文本 parts 坍缩**：user 回合的 `Parts` 中无 image/video/audio 存活时（如附件被模型能力或媒体额度降级成文本占位）以 `\n\n` join **坍缩回字符串 `content`**——纯文本端点拒收数组形 `content`，且冻结附件逐回合重放，数组形会让该对话每一回合永远 400。任一原生媒体仍走 OpenAI-compatible 数组多模态形。
- **factory**：按 provider+key 构造 Client，返回 `(Client, 解析后 baseURL, error)`；`DescribeModels` 各 provider 自描述模型目录（model 域消费）。
- **anselm（内置免费档）**：`anselm.go` embed `deepseekProvider` 复用 OpenAI-compatible streaming/tools/reasoning wire，仅覆盖 identity/header 与模型描述。公开模型仅 `anselm-auto`；`/v1/models` 的 `anselm_capabilities` 明示两条 content route：纯文本 DeepSeek 与含原生图片/MP4 的 Qwen3.7 Plus 均为 1,000,000 input，产品输出 cap 16,384，并分别给 availability。主后端 probe 动态读取该扩展，旧网关无扩展时才用同值 fallback；当前 audio=false。`Request.ActiveInputBudgetTokens` 每次按实际 prompt 是否仍含 native media 选预算。`infra/deviceproof` 持一把加密落盘的 Ed25519 安装私钥；`Transport` 给 install/chat/quota/models probe 逐请求签 method + authority/target + exact body hash + server nonce/jti。网关 402 / 流内 `BUDGET_EXHAUSTED` → `ErrQuotaExhausted`；HTTP 或 SSE 内的结构化 `UPSTREAM_REJECTED.details.reason=context_length` → typed `RequestRejectedError`，供 loop 压缩重试，provider 原文不外泄。
- **mock**：`fake_llm` 脚本队列（T6——默认测试 0 token）。
- 码 `LLM_*` 6 + `MOCK_QUEUE_EMPTY` → [error-codes.md](../error-codes.md)。

**`app/modelclient` 是唯一的 model→client 解析链**：`Resolve(ctx, scenario, override, picker, keys, factory) → (Client, 预填 Request{ModelID/Key/BaseURL/Options}, provider)`。chat loop 之外的全部 LLM 消费方走它——bootstrap 四 resolver 核、search 精度链 sifter、envfix 依赖自愈、WebFetch 摘要器。**禁止手抄该链**：factory 第二返回值是解析后的 baseURL，若误接进 `Request.ModelID`，线缆 model 字段就变成 base url、静默杀死该 LLM 功能——故所有非 chat-loop 消费方一律走此函数，不各自拼解析。
