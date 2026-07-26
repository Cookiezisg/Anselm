---
id: WRK-082
type: working
status: active
owner: "@weilin"
created: 2026-07-26
reviewed: 2026-07-26
review-due: 2026-10-24
audience: [human, ai]
landed-into:
---

# WRK-082 · 全模态输出:生成即工具、跨 key 能力路由与 models.dev 能力目录

> **状态:方向与全部细节参数均已由用户拍板(2026-07-26 两轮对话,§1 P1–P12),
> 本页无待决项,按 §10 批次施工。**
>
> 本战役承接 WRK-078(1M 全模态**输入**)——输入侧已收口(图/视频/音频进得来),本战役解决
> **输出侧**(图/语音/视频出得去)+ 顺带落地已拍板的 **models.dev 能力目录**改造。
> 跨两仓:桌面端 + sidecar 在 Anselm;受管免费档网关在 `Anselm-API-Serve`。

---

## §0 一句话与最终体验

**Agent 不但看得懂图、听得懂话,还画得出图、说得出话、(最终)生得出视频**——无论用户走
Anselm 受管免费档还是自带任何一家的 key;没那个能力的 key 组合下,功能诚实地不出现,
而非调用后失败。

用户最终感知:

1. 对话里说「画一张……」,Agent 调工具出图,图直接渲在对话里,可点开大图。
2. 任意回复可以「朗读」;Agent 也能主动生成语音(TTS)。
3. (后期)能生成短视频,生成过程有诚实进度,不冻结对话。
4. 聊天模型与生成模型**解耦**:拿 Anthropic 聊天 + OpenAI key 出图,完全成立。
5. 只配了无生成能力的 key(如仅 DeepSeek):生成工具不出现、设置页明说原因——绝无
   「调了才失败」。
6. 直连模型目录(能力/上下文/模态)不再依赖手抄静态表,follow 社区维护的 models.dev。

---

## §1 用户已拍板的决策(2026-07-26,均有对话原话依据)

| # | 决策 | 原话要点 |
|---|---|---|
| P1 | **直连侧能力目录无脑 follow models.dev**,不搞人工仲裁补丁表 | 「那个仓库说是啥我们就无脑follow就完了」 |
| P2 | **models.dev 没有的就撤**——豆包(provider 整家)随之撤下 | 「不支持豆包那我们就也撤下来呗」 |
| P3 | **运行时联网拉取可接受**(MCP 已是网络依赖先例) | 「需要网络无所谓啊」 |
| P4 | **旋钮(Knob)不折腾**:保留现状,不因迁移扩建也不阻塞迁移 | 「旋钮什么的其实也无所谓」 |
| P5 | **网关侧完全自家权威**,不 follow models.dev(计费/配额/路由指着这些数字) | 「API网关的完全按照我们自己搞的来」 |
| P6 | **输出多模态全都要**(图/语音/视频),不是只做出图 | 「我希望多模态全部都要」 |
| P7 | **自带 key 用户必须尽物理可能可用**——这是用户点名的主要担心 | 「主要是担心用户配其他key能不能用」 |

**同日第二轮拍板(原 §11 五个开放问题,已全部消解——本页无待决项)**:

| # | 决策 | 为什么这个数/这个名 |
|---|---|---|
| P8 | **免费档生成配额**:图 **10 张/天/install**、TTS **5 万字符/天/install**、**视频不进免费档** | qwen-image ≈¥0.25/张 → 重度封顶 ¥2.5/天;qwen3-tts ≈¥1/万字符 → 封顶 ¥5/天(朗读一条长回复才两三千字符,正常用碰不到线);视频一条几毛到几块,免费档扛不住,直连自费不限。均走既有 per-install 日子限额 + 月度总预算闸,不发明新机制 |
| P9 | **工具命名 `generate_image` / `generate_speech` / `generate_video`** | 既有 113 工具词法一律**动词_名词**(`create_agent`/`fire_trigger`/`forget_memory`/`ask_user`)。初稿的 `image_generate` 是名词开头、不合词法,故反过来 |
| P10 | **默认音色 Cherry**(DashScope 默认,中英双语自然);工具留 `voice` 参数,设置页**暂不开**音色选择器。**朗读产物落盘缓存**:键=(内容哈希 + 音色),LRU 50MB | 重听同一条是高频动作而 TTS 是真钱;即播即弃 = 让用户为同一句话反复付费 |
| P11 | **models.dev 刷新:启动后延迟 30s 异步拉一次 + 24h TTL,失败静默** | 延迟 30s 是为绝不与启动门控抢网络/抢时序;模型目录变化是**周**级的,24h 足够新鲜 |
| P12 | **图默认 1024×1024、`n` 恒为 1**;工具参数给三值枚举 `square/landscape/portrait`,由各家方言层翻译成自家具体分辨率 | 不给 LLM 开多张口子 → 配额可预算;各家支持的分辨率集不同,枚举在方言层翻译最干净,且 Agent 仍能按内容选横竖 |

---

## §2 现状盘点(2026-07-26 实测/读码核实)

### 2.1 网关上游:输出全是纯文本

`Anselm-API-Serve/.env.example`:`TEXT_UPSTREAM_MODEL=deepseek-v4-flash`、
`MULTIMODAL_UPSTREAM_MODEL=qwen3.7-plus`。查 models.dev:`qwen3.7-plus` =
`input:[text,image,video] → output:[text]`。**两条路由都能看不能画。**
同一阿里账号下生成模型是**另一批模型**:`qwen-image-2.0(-pro)`/`wan2.7-image`(图)、
`qwen3-tts-instruct-flash`/CosyVoice(语音)、`wan2.7` 系(视频,异步任务)。

### 2.2 直连侧静态表现状(backend `internal/infra/llm/`)

- 有手写 `modelSpec` 静态表的 **8 家**:openai / anthropic / deepseek / qwen / moonshot /
  zhipu / doubao / anselm(自家网关,不在本战役范围)。
- **无**静态表 4 家:gemini / openrouter(富 `/models`,自带能力)、ollama / custom(天生
  查不到,永远兜底)——这 4 家不受 models.dev 迁移影响。
- `modelSpec` 形状:`{prefix, ctx, out, knobs, vision bool, nativeDocs bool}`——**单布尔
  vision 不够用**,qwen.go 为此长了补丁函数 `qwenNativeInputCaps`(逐前缀补 video/audio)。
- 聚合面:`GET /api/v1/model-capabilities`(`ModelInfo`:ContextWindow/MaxOutput/Vision/
  Video/Audio/NativeDocs/Knobs…)。

### 2.3 models.dev 实测(2026-07-26 拉取 `https://models.dev/api.json`)

- MIT 协议,anomalyco/models.dev,6081 星,前一日仍有提交;172 providers、5823 模型,
  api.json 约 3.1MB。TOML 入 git、PR + CI schema 校验。
- 每模型字段:`modalities.{input,output}`(text/image/audio/video/pdf 数组)、
  `limit.{context,output}`、`attachment/reasoning/tool_call/structured_output/temperature`、
  `cost`、`release_date/last_updated`。**`modalities` 数组天然取代 vision 布尔 +
  qwenNativeInputCaps 补丁。**
- 与我们 Qwen 手写表逐条 diff:10 条中 **5 条逐字一致**;2 条数字打架
  (`qwen-turbo` ctx 我们 131072 vs 上游 1M;`qwen3-max` out 我们 32768 vs 上游 65536);
  3 条它没有(`qwen3.5-omni-plus/flash`、`qwen-long`)。
- **已知后果(P1+P2 的代价,用户知情)**:follow 后 `qwen3.5-omni` 系从直连列表消失
  (唯一原生听音频的直连模型;产品语音主路走网关不受影响)、`qwen-long` 消失、豆包整家撤。
- 我们 6 家(openai/anthropic/deepseek/alibaba(qwen)/moonshotai/zhipuai)**全部收录**;
  豆包缺席。`cost` 字段**不拿来计费**(网关计费是自家权威,P5;直连本就不经我们计费)。

### 2.4 桌面端既有地基(输出侧全是现成的)

- **工具框架**:S18 五方法接口,按族分目录 `internal/app/tool/<族>/`(现有 agent/approval/
  ask/attachment/blocks/…/web/workflow 二十余族、113 工具);summary/danger/execution_group
  由 Framework 注入。前端 113 工具逐卡谱系 + sidestage 舞台已建成。
- **按 scenario 默认模型**:workspace 已有 dialogue/utility/agent 三格(JSON 存,
  `PUT /api/v1/workspaces/{id}/default-models/{scenario}`)——**新格照抄此 pattern**。
- **媒体落盘**:`internal/infra/store/media`(附件域)输入侧在用;生成产物复用同一落盘。
- **block 七型是 CHECK 封闭集**(text/reasoning/tool_call/tool_result/compaction/progress/
  marker)——本战役**不动它**(§3.3)。`progress` 型正好承载长任务活进度。
- **E1 三条 SSE 永不再加**——生成进度走 messages 流 ephemeral 帧,不新开流。
- 前端音频播放卡(A3 验过)、图片渲染管道(输入侧)、AnLastGood/流式增量军规——全部复用。

### 2.5 各家「用自己 key 能生成什么」(物理现实,2026-07 查证)

| 厂商 | 图 | 语音 | 视频 | 备注 |
|---|---|---|---|---|
| OpenAI | ✅ gpt-image 系 `/v1/images/generations` | ✅ `/v1/audio/speech` | ✅ Sora(异步) | 标准形 |
| Gemini | ✅ image 系模型经 `generateContent` + `responseModalities:["TEXT","IMAGE"]`,图在 `part.inlineData` base64 | ✅ TTS 系 | ✅ Veo(异步) | **聊天 wire 内联出图**,非独立端点 |
| 阿里 DashScope | ✅ qwen-image / wan | ✅ qwen3-tts(HTTP)/ CosyVoice(WS) | ✅ wan(异步) | 图像生成**不走** OpenAI-compat `/images/generations`,是自家异步任务形(LiteLLM 同样绕不开,单独适配) |
| 智谱 | ✅ CogView-4,OpenAI-compat `images.generations` | ✅ | ✅ CogVideoX | 最省事 |
| OpenRouter | 部分(代理 gemini-image 等) | ❌ | ❌ | 按 models.dev `modalities.output` 判 |
| Anthropic / DeepSeek / Moonshot / Ollama | ❌ 压根没有 | ❌ | ❌ | **物理现实,架构改不了** |

P7 的诚实答案:**没货的家就是不能生成;架构负责「有货的顺、没货的死相好看」**(§3.5)。

---

## §3 核心架构决策(本战役的骨架,每条都有为什么)

### 3.1 生成即工具,不追原生 interleaved 输出

两条业界路线:(A)换成原生「边聊边出图」的聊天模型(gemini-image/gpt-image 系)——对我们
等于换厂商,网关 DeepSeek/Qwen 聊天模型都不支持,**否决**;(B)**生成是工具**:聊天模型照旧,
Agent 调 `generate_image` 等工具 → 后端打生成 API → 产物落盘 → 渲进对话(ChatGPT+DALL·E
模式)。选 **B**。理由:与 Quadrinity「一切能力皆工具」同构;任何文本模型都能出图;计费独立、
失败隔离;工具卡/sidestage/danger 自报全部白拿。**唯一例外**:Gemini 直连的出图物理上就长在
聊天 wire 里(2.5),其 provider 方言在工具 Execute 内部用「一次性单轮 generateContent」调用
承载,对上层仍呈现为工具——路线不因它分叉。落 ADR 一篇钉死(§10 批E)。

### 3.2 跨 key 能力路由:scenario 新增 image / speech / video 三格

生成工具用哪把 key,与聊天用哪把 key **解耦**。照抄现有 dialogue/utility/agent pattern:
`modeldomain` 加 `ScenarioImage/ScenarioSpeech/ScenarioVideo`,workspace JSON 加三格,
`default-models/{scenario}` 端点自然覆盖。候选下拉从 model-capabilities 过滤
`modalities.output` 含对应模态的模型。受管档三格由网关路由兜底(用户零配置)。

### 3.3 不动 block 七型封闭集:产物是 tool_result 携带的媒体引用

生成图/音频作为 `tool_result` 里的结构化引用(mediaId + mime + 尺寸),前端按引用渲染
图片卡/播放卡。**不新增 block 类型**——改 CHECK 封闭集是 D 系列变更 + 前端 sealed DTO 连锁,
成本高且无必要;输入侧附件已证明「引用 + 落盘」模式够用。

### 3.4 能力目录双轨:直连 follow models.dev(P1),网关自家权威(P5)

- 直连 6 家:删手写 `modelSpec` 表,换 models.dev 数据;`modelSpec` 布尔位改成模态数组
  (`qwenNativeInputCaps` 补丁随之消失);豆包整家撤(P2)。
- 数据形态(P3 允许联网,仍要离线兜底):**vendored 快照入库**(裁到我们 6 家,几十 KB)
  作为保底 + **运行时后台刷新**(缓存进数据目录,TTL 级,失败静默用快照)——app 离线首启
  也有完整目录,联网则自动更新。`make update-model-catalog` 刷新 vendored 快照。
- 旋钮:保留现有手写 knob 函数不动(P4);models.dev 的 `reasoning_options` 太弱,不接。
- `cost` 字段不消费(计费权威性,P5)。
- gemini/openrouter(富 `/models`)与 ollama/custom(查不到)维持现状,不受影响。

### 3.5 工具按能力动态注入(诚实缺席)

某 scenario 无可用路由(受管档对应能力关闭 && 无一把 key 的模型 `modalities.output` 命中)
→ 该生成工具**不注入给 LLM**(模型不会幻觉调用必失败的工具),设置页对应格显示「无可用模型 +
怎么获得」。先例:网关 `Multimodal.Available` 双半才真(「可用性必须描述整条路」),这是同一
原则第二次应用。

### 3.6 网关新端点用 OpenAI-compat 形状

`POST /v1/images/generations`、`POST /v1/audio/speech`(视频见 §8)。理由:桌面端直连侧
反正要实现 OpenAI 形方言(OpenAI/智谱同形),网关取同形 = 桌面端一份 client 两处用;网关
内部再翻译成 DashScope 自家异步形(这层复杂度只网关侧付一次)。device-proof 认证、配额、
journal 全走既有轨道;计费加「按张/按秒」价格卡——`billing` 已有非 token 单位先例
(`InputAudioSeconds`),照抄。

---

## §4 端到端数据流推演(设计原则 #5,开工前必走)

**受管档出图主线**:

```
用户:「画一只戴帽子的猫」
→ chat runner(DeepSeek 文本路由)ReAct:LLM 决定调 generate_image{prompt,aspect}
→ 工具族 generate:按 ScenarioImage 解析路由 → 受管行 → 网关 client
→ POST /v1/images/generations(device-proof 签名)
→ 网关:配额预检 → 翻译成 DashScope qwen-image 异步任务 → 提交→轮询→取回图字节
   → 计费(按张价格卡)→ journal → **base64 响应**返回桌面端
   (出站方向无 ADR 0011/0012 的回拉难题;尺寸 1–3MiB 级可控)
→ 桌面端:图字节落 media store(复用附件域落盘)→ tool_result 写媒体引用
→ messages SSE close 帧带快照 → 前端 tool 卡渲缩略图,点开大图
→ LLM 收到 tool_result(引用 + 摘要文本),续答「画好了…」
```

**跨 key 直连出图**(P7 主场景):同链,路由解析改为「ScenarioImage 显式配置 → 否则在已
探测 key 里挑首个 `modalities.output` 含 image 的模型」;网关 client 换成对应家方言
(OpenAI 形 / Gemini generateContent 形 / DashScope 异步形)。
**跨域依赖(relation 边)**:tool → modeldomain(scenario)→ apikey(路由解析)→
llm infra(生成方言)→ media store(落盘)→ messages(引用)→ 前端 chat/settings。
**朗读**(§7):不经 LLM——前端消息动作排「朗读」→ 桌面后端 TTS 端点 → 播放卡,同一条
speech 路由,零 token。

---

## §5 批A · models.dev 能力目录(先行,独立可交付)

1. `tools/`(或 `cmd/`)加拉取裁剪脚本 + 根 `make update-model-catalog`:拉 api.json →
   裁到 6 家 → 生成 vendored JSON(入库,S22:这是**源等价配置**,非构建产物)。
2. `internal/infra/llm`:`modelSpec` 改形(vision/nativeDocs 布尔 → 输入/输出模态数组;
   ctx/out 照旧),6 家静态表改由 vendored JSON 载入;`qwenNativeInputCaps` 删除;
   knobs 函数保留原样接回(P4)。
3. 运行时刷新:后台低频拉 api.json → 校验形状 → 写数据目录缓存;载入优先级
   缓存 > vendored;失败静默(日志一行)。**绝不因刷新失败影响启动**。
4. 豆包撤除:`doubao.go` 及注册、文档、i18n、前端 provider 列表同批删(P2;#7 零包袱,
   直接删不留兼容)。
5. `ModelInfo` wire 不变(Vision/Video/Audio 布尔由模态数组投影,前端契约零感知);
   `model-capabilities` 文档与 `contract.md` 同批核对。
6. 测试:diff 守卫(vendored JSON 形状/6 家在位)、载入优先级、豆包消失、`qwen3.7-plus`
   模态投影正确。文档:`domains/` 相关篇 + 四索引 + 本页台账。

**验收**:`make verify` 全绿;app 设置页 6 家模型列表数字与 models.dev 一致;断网启动列表完整。

---

## §6 批B · 出图(价值最直、管道最短,输出侧第一仗)

**网关**(`Anselm-API-Serve`):
- `POST /v1/images/generations`(OpenAI-compat 请求形:prompt/size/n=1;响应 b64_json)。
- 上游 DashScope qwen-image 异步任务:提交→轮询→下载,整体超时上限设死;失败翻译成既有
  粗粒度错误枚举(GW-INV 系列不破)。
- billing 加图像价格卡(按张,单位先例照 ASR 秒);IMAGE_ENABLED 配置 + 能力面
  `Image.RouteProfile`(Available = key && enabled,双半才真);配额/journal/testend 照轨。

**桌面后端**:
- 新工具族 `internal/app/tool/generate/`:`generate_image`(S18 五方法;danger=safe;
  参数 `prompt` + `aspect` 三值枚举 `square/landscape/portrait`,默认 square→1024²、
  `n` 恒 1,不暴露裸分辨率——P9/P12)。
- 路由解析(§3.2/§3.5)+ 三家直连方言:OpenAI 形(OpenAI/智谱共用)、Gemini
  generateContent 形、DashScope 异步形——各带 wire 单测(照输入侧 12 家 wire 断言矩阵的
  既有做法)。
- 产物落 media store,`tool_result` 结构化引用(§3.3);错误全走 S20。

**前端**:
- `generate_image` 工具卡:生成中骨架 → 缩略图;点开大图查看(复用附件预览);sidestage
  给 image kind 登台形态;设置页 default-models 面板加 image 格(含「无可用模型」诚实态)。

**测试矩阵**:后端单测(路由解析 5 电池:仅受管/仅直连/混合/无能力/显式配置)+ 3 方言 wire
断言 + testend(llmmock:工具注入有无 × 成功/失败回合)+ 网关 testend + 前端 widget 五电池;
金标(EVALS 门控):受管档真出一张图。

---

## §7 批C · 出语音(补上 TTS = 语音闭环收口)

- 网关:`POST /v1/audio/speech`(OpenAI-compat:input/voice/format→音频字节),上游
  qwen3-tts-instruct-flash **HTTP 非实时形**(录音输入侧已有 WS ASR,输出侧不需要实时流,
  HTTP 简单得多);计费按字符/秒价格卡;SPEECH 能力面同双半原则。
- 桌面:`generate_speech` 工具(Agent 主动出语音)+ **朗读入口**(消息动作排加一项,
  不经 LLM 直打 TTS,零 token,§4);产物 = 既有音频播放卡(A3 验过),零新 UI 原语。
  默认音色 **Cherry**,工具留 `voice` 参数但设置页暂不开选择器(P10)。
- **朗读缓存**(P10):产物落盘,键=(消息内容哈希 + 音色),LRU 50MB——重听不重复计费。
- 直连方言:OpenAI `/audio/speech` 形(OpenAI/智谱)+ DashScope 形;无 TTS 的家照 §3.5
  缺席。

---

## §8 批D · 出视频(最后做,唯一真设计难点:长任务)

各家全是**异步任务 API**(wan/Sora/Veo:提交→分钟级→取回),与图/语音的秒级同步完全不同:

- **V1 形态拍板建议**:工具 Execute 内「提交 + 轮询」**同步等完**,期间经 messages 流
  ephemeral 帧持续推 `progress`(block 七型现成的 progress 型 + E2 ephemeral,不加流不加型),
  前端工具卡渲真进度条。30 分钟 `timeout.chatTurnSec` 顶棚远大于分钟级生成,够用。
- **明确不做**(记入 ADR 的否决项):把视频生成挂 durable flowrun 引擎、或「提交后台 +
  通知送达」的离场形态——那是把 chat 工具改造成异步作业系统,V1 复杂度不值;若真出现
  10 分钟级生成需求再立新 ADR。
- **视频不进受管免费档**(P8:一条几毛到几块,免费档扛不住)——网关不开视频路由;
  `generate_video` 只在直连侧(OpenAI Sora / 智谱 CogVideoX / DashScope wan)按 §3.5
  能力注入,用户自费不限量。
- 产物 mp4 落盘,视频卡复用附件视频渲染。

---

## §9 测试与验收纪律(全战役通用)

- 每批遵守前端迭代铁律四步:读码扇出 → 联网 best practice(§2.5 的 API 形状**施工时须
  再对官方文档核准一次**,本页查证仅到方向级)→ working 更新 → 拍板 → 建 → 对抗复审 →
  真机截图。
- 契约改动必搜 testend(T5.1 按域前缀);两仓 `make verify` 各自全绿;文档 #9 同提交。
- 金标(EVALS 门控烧钱):受管出图一张、TTS 一句、(批D)直连视频一条。
- 真机验收清单随批追加到 `app-hardening/ACCEPTANCE-GUIDE.md` 同款诚实律:未跑就写未跑。

## §10 施工序

| 批 | 内容 | 前置 |
|---|---|---|
| A | models.dev 目录 + 豆包撤除(§5) | 无,独立可交付 |
| B | 出图:网关端点 + 工具 + 三方言 + 前端卡(§6) | A(能力路由要模态数组) |
| C | 出语音:TTS 端点 + 工具 + 朗读(§7) | B(同模子复制) |
| D | 出视频:长任务形态(§8) | B/C 稳定后 |
| E | ADR(生成即工具 + 长任务否决项)+ 四索引/契约/CLAUDE.md 重述 + 本页 landed | A–D |

## §11 风险与已知代价(诚实台账)

- omni/qwen-long 从直连消失、豆包撤(§2.3,用户知情接受)。
- models.dev 数字打架处(qwen-turbo/qwen3-max)follow 后以上游为准——若上游错,直连用户
  拿到错误上限;**上下文侧有 modelprofile 撞墙学习兜底**(预算只会被真实证据收紧),能力侧
  错标 = 该家该功能错开/错关,靠社区修数据。
- DashScope 图像 API 是自家异步形,网关翻译层是批B最大工作量;各家生成 API 形状仅查证到
  方向级,施工时逐家再核(§9)。
- 运行时刷新引入首个「启动后后台网络任务」,必须绝不影响启动路径(§5.3 fail-silent)。
