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
- **工具参数的两种线缆形（WRK-082 H9，真线缆抓取实证 2026-07-28）**：OpenAI 兼容流式把工具调用参数发成 `delta.tool_calls[].function.arguments`，而这个字段有**两种互不兼容的约定**——**真增量**（`{"aspect": "` → `square` → `"`）与**每片完整累积值**（`{"aspect": "` → `{"aspect": "square` → `{"aspect": "square"`）。**同一家供应商两种都发**：DashScope 旧共用新加坡域 `dashscope-intl.aliyuncs.com` 发增量，其**工作区专属**域 `<ws>.ap-southeast-1.maas.aliyuncs.com`（厂商迁移公告让你搬过去的那个）发累积值，同一个模型、同一个请求、只差一个线缆约定。把累积流拼接会得到 `{"aspect": "{"aspect": "square…`，于是**每一次**工具调用都 JSON 解析失败——损害是**全量而非局部**，agent 循环连续三轮全败后以 tool-error storm 中止，能力不是降级而是**死掉**。故 `toolargs.go` 的 `toolArgs.delta` 是这条方言**唯一**解析器里的归一层（H12-a 合并后只有一个 `toolCallState` 持它）：**前缀判别**——分片以已累积内容开头即视为累积值、只取新增后缀，否则按增量追加。两个方向都安全，因为对合法 JSON 而言真增量不可能把已累积的一切重述一遍（那会拼出 `{"a{"a…`，没有解析器收）。**地基化而非逐方言修**：八家原本各抄同一行，只修有复现的那一家等于留七把上了膛的枪——而**当时确实漏了一把**：`openai.go` 从没拿到这个修复，直到 H12-a 合并才随整份解析器一起补上。**仓库里每一份 fixture 都发增量**，故门禁全绿与真钱验收全绿时这里仍是坏的——守卫在 `toolargs_test.go` 把**两种形状**都钉死。
- **生成方言（WRK-082 批B/批C）**：`imagegen.go` 五方言(anselm/openai/google/qwen/zhipu)出图,`speechgen.go` **四条路只有三种 wire**——OpenAI 与智谱共用 `/audio/speech` 形(字段名逐字相同、响应裸字节)、DashScope 只有原生 `multimodal-generation` 形(嵌套 `input`、JSON + OSS URL,**无** OpenAI 兼容 TTS 端点)、Gemini 返 base64 **无头 PCM** 由本层自封 WAV。一切收敛到**一个**中间表示 **24kHz/16bit/mono PCM(WAV 容器)**:这不是偏好而是「切块再拼」的前提——各家单请求上限都远低于一条长消息(qwen3-tts ~500 字符、智谱 1024),故长文本必须切开再拼,而 PCM 靠字节拼接即重合、MP3 帧拼接会留听得见的缝;四家原生输出恰好全是此规格,整条流水线零重采样。`ParseWAV` **遍历 chunk 表**而非假定 44 字节头(真实编码器会夹带 LIST/fact,按固定偏移读会把元数据当样本);`ConcatAudio` 在 **PCM 层**重接(按字节追加两个 WAV 会在流中间留下第二个 RIFF 头,多数播放器就停在那儿),格式不一致**大声拒绝**而非静默变调。切块上限与默认音色**按家手写**(`SpeechChunkLimit`/`defaultVoiceFor`)——能力目录的 chat 谓词把纯 TTS 模型整个滤出了目录,**发现不了**;音色名不跨家通用(Cherry 只在 DashScope、coral 只在 OpenAI、Kore 只在 Gemini),故未设音色**按路由**解析。 **视频(批D)** 是本族唯一的**异步**模态:`videogen.go` 给**三个动词**(Submit/Poll/Fetch)而非一个,轮询循环共用、三动词各家不同。**两个方言而非三个**——OpenAI Videos API 已公告 2026-09-24 下线(代拍 D2),一个只剩八周寿命的 driver 会被建、被复审、被删掉却从没挣回成本。**产物是「可取回的引用」而不是 URL**:DashScope 返裸预签名 OSS URL(带 Authorization 反而**可能被拒**),Google 的文件 URI **必须**带 api key——「拿到 URL 就能下」对两家都不成立且方向相反,故 `VideoArtifact{URL, Headers}`。**不给进度百分比**:两家都只给状态字,而用「已耗时÷预估」合成会让进度条在 99% 停几分钟(Veo 官方区间 11s–6min),诚实的状态行胜过一个可被验证为假的进度条。轮询**爬**向厂商节奏(2s 起、×1.5 到上限):厂商文档给的间隔是**上限**、其限流建议说的正是上限,而固定首轮等待会让上游校验就失败的任务白付一整个周期的沉默。**生成 origin 从凭证派生、绝不硬编码**(2026-07-27 真机 401 教训):DashScope 有北京、新加坡与逐 workspace 三种域,一把 key 只在**其中一个**上有效而 key 本身不说是哪个;原生 API 与 compatible-mode 在**同一台主机**上、只差路径,故 `dashScopeNative` 把凭证聊天 base 的 `/compatible-mode/v1` 剥掉即得生成 origin——用户在哪个区,生成就在哪个区。硬编码会把新加坡的 key 送去北京、换回一个读作「你的 key 不对」的 401(回归守卫钉五种域形 + 空值回落**国际**域〔大陆账号到得了它,反之对国际 key 不成立〕)。同家两形按模型分支(wan2.7 用 resolution+ratio、2.6 及更早用 size);不可能的组合(向 Veo 要 15 秒)**在客户端钳**到该路由做得到的长度、receipt 报**真正做出来**的那个。
- **一条方言一份实现(H12-a)**:八家 OpenAI 兼容 provider(openai/deepseek/qwen/zhipu/moonshot/openrouter/ollama/custom)此前各持一份近乎相同的拷贝(约 3800 行),现在共用 `compat.go` 的 `compatProvider`,真实差异写进 `compatSpec` 五个字段——`baseURL` / `prepare`(仅 DeepSeek 的 reasoning_content round-trip 规则)/ `parts`(Ollama **根本不用** content part,图走消息级 `images` 裸 base64;Qwen 多 video+audio;OpenAI 多 file)/ `encode`(本家原生旋钮与 token 上限拼法)/ `toolChoice`(智谱不给 `"auto"` 就**根本不调工具**)。**旧注释的论证是真的、代价没人在数**:「重复是故意的,某家特性永不逼共享代码加分支」——但一处线缆修复要修 N 遍,而**漏掉一遍的那天是看不见的**(见上条 `openai.go`)。合并的代价用**两个守卫**买回来:①请求体是**超集** struct,故逐家 marshal 真请求、读**真实 JSON key**,断言没有哪一家把别家的旋钮带上线缆(反向验过:给智谱偷加 `verbosity` 立刻红);②`partMask` 与 part 编码器是**两处独立声明**,断言二者逐家一致——承诺 video 而编码器不写 = **静默丢弃**,抵达用户时是一个「没去看」一段从没发给它的视频的模型。
- **sanitizer**：发送前守 `assistant.tool_calls ↔ tool` 配对——孤儿 tool_call 合成 stub 回复（LLM 看见被打断、严格 provider 不 400）。被取消的回合重续就靠它。
- **deepseek 全文本 parts 坍缩**：user 回合的 `Parts` 中无 image/video/audio 存活时（如附件被模型能力或媒体额度降级成文本占位）以 `\n\n` join **坍缩回字符串 `content`**——纯文本端点拒收数组形 `content`，且冻结附件逐回合重放，数组形会让该对话每一回合永远 400。任一原生媒体仍走 OpenAI-compatible 数组多模态形。
- **factory**：按 provider+key 构造 Client，返回 `(Client, 解析后 baseURL, error)`；`DescribeModels` 各 provider 自描述模型目录（model 域消费）。
- **anselm（内置免费档）**：`anselm.go` embed `compatProvider`（以 DeepSeek 那份 spec 构造）复用 OpenAI-compatible streaming/tools/reasoning wire，仅覆盖 identity/header 与模型描述。公开模型仅 `anselm-auto`；`/v1/models` 的 `anselm_capabilities` 明示两条 content route：纯文本 DeepSeek 与含原生图片/MP4 的 Qwen3.7 Plus 均为 1,000,000 input，产品输出 cap 16,384，并分别给 availability。主后端 probe 动态读取该扩展，旧网关无扩展时才用同值 fallback；当前 audio=false。`Request.ActiveInputBudgetTokens` 每次按实际 prompt 是否仍含 native media 选预算。`infra/deviceproof` 持一把加密落盘的 Ed25519 安装私钥；`Transport` 给 install/chat/quota/models probe 逐请求签 method + authority/target + exact body hash + server nonce/jti。网关 402 / 流内 `BUDGET_EXHAUSTED` → `ErrQuotaExhausted`；HTTP 或 SSE 内的结构化 `UPSTREAM_REJECTED.details.reason=context_length` → typed `RequestRejectedError`，供 loop 压缩重试，provider 原文不外泄。
- **mock**：`fake_llm` 脚本队列（T6——默认测试 0 token）。
- 码 `LLM_*` 6 + `MOCK_QUEUE_EMPTY` → [error-codes.md](../error-codes.md)。

**`app/modelclient` 是唯一的 model→client 解析链**：`Resolve(ctx, scenario, override, picker, keys, factory) → (Client, 预填 Request{ModelID/Key/BaseURL/Options}, provider)`。chat loop 之外的全部 LLM 消费方走它——bootstrap 四 resolver 核、search 精度链 sifter、envfix 依赖自愈、WebFetch 摘要器。**禁止手抄该链**：factory 第二返回值是解析后的 baseURL，若误接进 `Request.ModelID`，线缆 model 字段就变成 base url、静默杀死该 LLM 功能——故所有非 chat-loop 消费方一律走此函数，不各自拼解析。
