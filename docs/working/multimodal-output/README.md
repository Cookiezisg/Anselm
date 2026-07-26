---
id: WRK-082
type: working
status: active
owner: "@weilin"
created: 2026-07-26
reviewed: 2026-07-27
review-due: 2026-10-25
audience: [human, ai]
landed-into:
---

# WRK-082 · 全模态平台:MediaRef 值类型、生成即工具与全执行面贯通

> **状态:方向与全部参数已由用户拍板(P1–P19,2026-07-26/27 四轮对话),本页无待决项,按 §10 批次施工。**
>
> **这是一个大 Goal**:A–G 八批、两仓全部完成、§0.2 终点验收七条全过才算收口——由自主循环推进,
> 以本页 + 会话任务清单 + git 为盘上真相,任何中断幂等续跑(施工中新拍板按「代拍」记入 §1.1,
> 用户可随时翻案,零包袱直接改)。
>
> 承接 WRK-078(1M 全模态**输入**,chat 侧已收口)。本战役把 Anselm 从「文本为主、chat 里能看图」
> 变成**全模态平台**:图/音/视频/文档,进出双向,执行面 + 编辑面全通。跨两仓:桌面端 + sidecar 在
> Anselm;受管免费档网关在 `Anselm-API-Serve`(它有自己的最高法与 GW-INV 登记册,对应 working 文档
> 落该仓 `docs/working/multimodal-generation.md`,两仓各过各的门禁)。

---

## §0 目标:媒体的一生、终点验收与四条不变量

### 0.1 一句话与媒体的一生

**Agent 不但看得懂图、听得懂话,还画得出图、说得出话、生得出视频;而且不只在 chat——agent /
subagent / workflow 的每个执行面、文档库的编辑面,媒体都进得来、出得去、看得见、渲得对。**
无论受管免费档还是自带任意一家 key;没那个能力的组合下,功能诚实地不出现,绝无「调了才失败」。

```
生(五个产地:chat 附件 · 生成工具 · MCP 结果 · fn/hd 产物 · 驻地文件)
→ 存(唯一一间库:media store,CAS 内容寻址)
→ 流(唯一值类型:MediaRef{id, mime, 尺寸/时长…},就是普通 JSON——
     流经 tool_result / frn 行 / CEL / agent payload / 文档,引擎零特判)
→ 看(唯一消费咽喉:LLM 装配处解引用 → ContentPart,按 models.dev 的
     modalities.input 门控;模型吃不下就诚实降级为文本占位,不假装)
→ 渲(唯一卡族:前端按 mime 分发的媒体卡,chat/侧幕/运行卷宗/调试台/approval/文档块同一族原语)
→ 说/听(ASR 进〔已有〕· TTS 出〔批C〕,语音闭环)
```

### 0.2 终点验收(七条,全过才算战役收口;逐条要真钱真线缆证据,P19)

1. chat 里「画一张……」→ 图渲在对话里、点开大图——**真钱真图**。
2. workflow 里 A 节点出图 → B 节点 agent **真的看见**(以库与 LLM 请求线缆为证,不采信模型自述)。
3. MCP 工具返图模型看得见(不再是 `[image: png]` 占位符);fn 跑 matplotlib 的图表产物能渲染、能被下游模型看见。
4. 任意回复可「朗读」;agent 能主动 TTS——**真钱真声**;重听同一条走缓存零计费。
5. 直连侧真生成一条视频,工具卡有诚实进度、不冻结对话。
6. agent 画图嵌进它写的文档;@该文档问模型,模型看见图(编辑器往返三保真、引用零漂移)。
7. 两仓 `make verify` 全绿、网关部署绿(`gh run` 可查)、文档按 #9 落定、本页 landed。

### 0.3 四条不变量(每一批的验收准绳)

1. **一个值类型**:`MediaRef` 是媒体在系统里流通的唯一货币(§3.3)。
2. **一间库**:五个产地生的媒体全落 media store,不建第二间。
3. **两个咽喉**:产出侧「字节入库、引用出门」写一次;消费侧「解引用 → ContentPart + 模态门控」写一次。
   新产地/新模态只是加 case,不再是战役。
4. **一族卡**:前端所有渲染面共用一个按 mime 分发的媒体卡原语,不做六套。

---

## §1 用户已拍板的决策(P1–P19,均有对话原话依据)

**2026-07-26 第一轮**:

| # | 决策 | 原话要点 |
|---|---|---|
| P1 | **直连侧能力目录无脑 follow models.dev**,不搞人工仲裁补丁表 | 「那个仓库说是啥我们就无脑follow就完了」 |
| P2 | **models.dev 没有的就撤**——豆包(provider 整家)随之撤下 | 「不支持豆包那我们就也撤下来呗」 |
| P3 | **运行时联网拉取可接受**(MCP 已是网络依赖先例) | 「需要网络无所谓啊」 |
| P4 | **旋钮(Knob)不折腾**:保留现状,不因迁移扩建也不阻塞迁移 | 「旋钮什么的其实也无所谓」 |
| P5 | **网关侧完全自家权威**,不 follow models.dev(计费/配额/路由指着这些数字) | 「API网关的完全按照我们自己搞的来」 |
| P6 | **输出多模态全都要**(图/语音/视频),不是只做出图 | 「我希望多模态全部都要」 |
| P7 | **自带 key 用户必须尽物理可能可用** | 「主要是担心用户配其他key能不能用」 |

**2026-07-26 第二轮**:

| # | 决策 | 为什么这个数/这个名 |
|---|---|---|
| P8 | **免费档生成配额**:图 **10 张/天/install**、TTS **5 万字符/天/install**、**视频不进免费档** | qwen-image ≈¥0.25/张 → 重度封顶 ¥2.5/天;qwen3-tts ≈¥1/万字符 → 封顶 ¥5/天;视频一条几毛到几块免费档扛不住,直连自费不限。均走既有 per-install 日子限额 + 月度总预算闸,不发明新机制 |
| P9 | **工具命名 `generate_image` / `generate_speech` / `generate_video`** | 既有 113 工具词法一律动词_名词 |
| P10 | **默认音色 Cherry**;工具留 `voice` 参数,设置页暂不开音色选择器。**朗读产物落盘缓存**:键=(内容哈希+音色),LRU 50MB | 重听同一条是高频动作而 TTS 是真钱 |
| P11 | **models.dev 刷新:启动后延迟 30s 异步拉一次 + 24h TTL,失败静默** | 绝不与启动门控抢网络/时序;目录变化是周级 |
| P12 | **图默认 1024×1024、`n` 恒 1**;工具参数三值枚举 `square/landscape/portrait`,方言层翻译具体分辨率 | 配额可预算;各家分辨率集不同,枚举在方言层翻译最干净 |

**2026-07-26/27 第三、四轮(本轮扩板:从「输出侧」升格为「全模态平台」)**:

| # | 决策 | 依据与后果 |
|---|---|---|
| P13 | **网关生成响应 URL 直通**:DashScope 生成结果本就是 OSS 签名 URL(24h 有效、无 key),网关做完配额/计费/journal 后把 URL 直通桌面端,客户端直接从上游 OSS 下载 | 用户:「URL直通的思路非常好」。服务器公网出方向仅 1Mbps(实测截图),1–3MiB base64 内联 = 11–30s/张,体验不成立;直通完全绕开水管。两条 GW-INV 新不变量:①直通 URL **可证明不含 key**(测试钉死);②**计费点在生成成功、不在客户端下载**(歧义照 full quote settle)。OpenAI-compat 形本有 `url` 响应形,契约站得住;b64 留兜底形 |
| P14 | **agent 获得生成工具走挂载词法扩展**:mount ref 新增 `sys:<tool>` 形(如 `sys:generate_image`),与 `fn_`/`hd_.method`/`mcp:` 并列;不做环境注入、不做布尔开关 | 环境注入让 agent 行为随 key 配置隐式漂移、打穿 pin 确定性;布尔开关是第二套挂载语义。`sys:` 在既有文法轨道上:可版本化、可回滚、可 pin,且接既有 mount-health 预检(无可用路由 → 「挂载不健康」诚实亮出) |
| P15 | **全模态贯通独立成批 B'**(插 B/C 之间):MediaRef 升格系统级值类型 + 消费咽喉 + `sys:` 挂载 + **MCP 媒体入口** + 前端引用卡族 | 揉进 B 则一批干两件性质不同的事;推到 C/D 后要回头补三种模态。插中间 = 对着「图」建好咽喉,音/视频自动继承。MCP 入口读码实证:`infra/mcp/client.go` `joinContent` 把 ImageContent/AudioContent 拍平成 `[image: png]` 占位符,模型永远看不见 |
| P16 | **fn/hd 媒体产物通道单列批 E**:先写沙箱产出约定 mini-spec(产出目录 + result 引用文法 + 大小上限 + 危险级),代拍后施工 | 第五个产地要设计沙箱侧约定,不塞进 B' 草草搞 |
| P17 | **文档库全模态进 scope,成批 F** | 用户:「文档我也想要」。核心场景:agent 画完图直接嵌进它在写的文档、@文档问模型模型看见图。super_editor 自带 ImageNode、markdown codec 有图语法,vendor 在自己手里 |
| P18 | **有意识排除**(写成否决项而非默默漏):通知携带媒体、记忆携带媒体 | 场景价值未明;MediaRef 文法上随时可后补,不欠架构债 |
| P19 | **真钱实测律 + 零包袱最高执行**:金标/真实 API 调用随便烧,「就是要用真实的去测」;mock/fake 全绿**不算收口**,每批验收必含真实调用证据。两仓未上线,零历史包袱按最高优先级——禁兼容层/迁移垫片/deprecation,直接删直接改;网关 push main(=自动部署到未上线服务器)本地全绿且有把握时可行 | 用户 0727 明确授权(「烧钱随便烧」「授予你非常大的权利」);仍留给用户:密钥增删轮换、买资源/续费支出、删用户真实数据 |

### 1.1 施工中代拍台账(每条注明依据,用户可随时翻案——零包袱,翻案即改)

| # | 代拍决策 | 依据 | 状态 |
|---|---|---|---|
| A1 | **目录范围谓词**:`tool_call` ∧ 输出含 text;另排除 id 含 `realtime`(今日 2 个) | P1 的「无脑 follow」不含把 embeddings/生图/ASR/MT/OCR 塞进聊天选择器(它们 `tool_call=false` 或输出无 text,机械落选);realtime 模型不讲 /chat/completions,列出即违背 §0「绝无调了才失败」 | ✅ 批A 已实施(`TrimUpstreamCatalog` + 谓词三轴守卫) |
| A2 | **目录收录 6 家全部 chat 模型**(非只旧表前缀);可见性 = key 探测结果 ∩ 目录 | 新模型随刷新自动出现正是 follow 的意义;可见集仍由用户的 key 真实服务的 /models 决定 | ✅ 批A 已实施 |
| A3 | **P2 既定后果逐 id 清单**(实测):`qwen3.5-omni-plus/flash`、`qwen-long`、`moonshot-v1-8k/32k/128k`、`glm-4-long`、`glm-4-flash`、`glm-5-turbo`、`gpt-3.5-turbo`(上游标 `tool_call=false`)从直连目录消失;豆包整家撤(后端 provider/前端品牌资产/web demo fixture 三处同批清零) | 上游缺席或谓词落选;方向已拍板知情(§2.3),此为完整清单 | 📋 事实记档 |
| A4 | **旋钮保守化**:目录新模型无手写 `knobRule` 命中 → 零旋钮(模型可用、无思考控件) | P4「旋钮不折腾」;未核实的族不猜 wire 词表 | ✅ 批A 已实施 |
| A5 | **方言掩码**(`partMask`):模态布尔投影 = 目录模态 ∧ 方言 wire 能力(例:kimi-k2.6 目录列 video、Moonshot 方言渲不了 video part → `Video=false`) | 「能力宣称必须描述整条路」——网关 `Multimodal.Available` 双半才真先例用在方言上;守卫 `TestDescribe_MaskGatesProjection` | ✅ 批A 已实施 |
| B1 | **网关上游走 DashScope 同步形**:`POST /api/v1/services/aigc/multimodal-generation/generation`(qwen-image-2.0 系,直接返 24h OSS URL)——**免掉整个任务轮询翻译层**;异步 text2image 形(qwen-image-plus)留 fallback 不实现 | 官方文档 2026-07 已把同步形标注为**推荐**且 §2.5 之前的「不走 OpenAI-compat、必须异步」判断已过时一半;同步形上游连接持有几十秒,给该路由单独设宽上游超时即可,比任务存储+轮询薄一个数量级 | 📋 批B 施工中,文档核准依据在案 |
| B2 | **真 key 实测被权限闸挡下,转晨间解锁**:SSH 上生产服务器被会话权限分类器拒(不绕);本地 .env 无 DASHSCOPE key | 形状已按官方文档四家核准(见 §2.5 修订);真线缆证据(URL 无 key/时延/账单行)等解锁后补——两条路任选:①本地 env 提供 `DASHSCOPE_API_KEY` ②给会话加 SSH 权限规则 | ⏸ 待用户晨间解锁 |
| B3 | **图像按张价先按工作假设入卡**:qwen-image ≈¥0.25/张 ≈ $0.035 = 35,000,000,000 pUSD/张,rate card 注释钉死「上线前对官方价页对账」 | 无真 key 无法读账单页实价;该价只影响 operator 自家钱包预算闸(reserve==settle 确定性成本),不影响上游真实计费;偏高偏低都只是预算余量问题 | ⏸ 与 B2 一并晨间对账 |
| B5 | **受管播种不填 video 场景**:`SeedDefaultsIfUnset` 跳过 ScenarioVideo | 免费档永不供视频(P8)——播了会显示一个永远路由不通的「已配置」默认 | ✅ 已实施(90d11426) |
| B6 | **生成模型候选目录手写**(小表:openai gpt-image 系 / google gemini-image 系 / qwen qwen-image 系 / zhipu cogview 系 + 各家默认 id),不走 models.dev | models.dev 生成侧覆盖残缺(alibaba 无 qwen-image 条目、zhipuai 无 cogview 条目,openai 的 gpt-image 又被 chat 谓词裁掉)——P1 的辖区是**聊天目录**,硬 follow 会砍掉三家真实能力,违背 P6/P7 | 📋 批B 施工中 |
| B7 | **MediaRef 落地形 = 附件引用 receipt**:生成产物经既有 `attachmentapp.Upload(bytes)` 落一等附件行(att_ id + CAS),tool_result 的 content string 内装 JSON receipt `{attachmentId, mime, width, height, source}`——不动块模型,前端复用 attachmentMetaProvider + AttachmentImageProvider 全渲染管线;**工具注入走 `DynamicTools(ctx)` 逐请求缝**(chat.Deps 既有,今日仅 MCP 用)实现诚实缺席——Toolset 是 boot 静态快照,key 热变更必须逐请求判可用性 | 侦察实证:附件域 Upload 即「bytes→记录」唯一入口、tool_result「string 装 JSON」是全族既定形(tool_receipts.dart 逐字钉)、工具层无 per-ctx 能力注入先例而 DynamicTools 缝现成 | 📋 批B 施工中 |
| B8 | **CapabilityTools 新缝(逐请求 resident)取代「lazy+发现」承载能力工具**:chat.Deps 加 `CapabilityTools func(ctx) []Tool`,host 每步在 resident 后直接并入(完整 schema 随请求),可用性上游过滤 | DynamicTools 的简介**不进** system prompt(读码实证 `toolsOverview` 只渲静态 Overview)——走 lazy 舞步模型不知道自己会画图;能力工具只有 1-3 个小 schema,常驻代价≈零而可见性=100% | ✅ 已实施(06f078d0);subagent 面留批B' |
| B4 | **品类日闸一个机制吃两批**:新表 `install_category_daily(install,category,day,units)`,图=张数、TTS=字符数同一 units 语义;`Limits.ImageDailyLimit` 默认 10(P8) | P8 说「走既有 per-install 日子限额」——读码后发现既有 `DailySublimit` 是**全请求混计**的日闸,表达不了「10 张图/天」;与其加临时列不如一次建品类通用机制(根修判据:批C 的 5 万字符/天零新机制直接落进同一张表) | 📋 批B 施工中 |

---

## §2 现状盘点(2026-07-26/27 实测/读码核实)

### 2.1 网关上游:输出全是纯文本

`Anselm-API-Serve/.env.example`:`TEXT_UPSTREAM_MODEL=deepseek-v4-flash`、
`MULTIMODAL_UPSTREAM_MODEL=qwen3.7-plus`(models.dev:`input:[text,image,video] → output:[text]`)。
**两条路由都能看不能画。** 同一阿里账号下生成模型是另一批:`qwen-image-2.0(-pro)`/`wan2.7-image`(图)、
`qwen3-tts-instruct-flash`/CosyVoice(语音)、`wan2.7` 系(视频,异步任务)。

### 2.2 直连侧静态表现状(backend `internal/infra/llm/`)

- 手写 `modelSpec` 静态表 **8 家**:openai / anthropic / deepseek / qwen / moonshot / zhipu /
  doubao / anselm(自家网关,不在迁移范围)。无静态表 4 家:gemini / openrouter(富 `/models`)、
  ollama / custom(查不到,永远兜底)——不受迁移影响。
- `modelSpec` 形状 `{prefix, ctx, out, knobs, vision bool, nativeDocs bool}`——单布尔不够用,
  qwen.go 为此长了补丁 `qwenNativeInputCaps`(逐前缀补 video/audio)。
- 聚合面:`GET /api/v1/model-capabilities`(`ModelInfo`)。

### 2.3 models.dev 实测(2026-07-26 拉取 api.json)

- MIT,anomalyco/models.dev,6081 星,活跃;172 providers / 5823 模型,api.json ≈3.1MB;
  TOML 入 git、PR + CI schema 校验。每模型:`modalities.{input,output}` 数组、`limit.{context,output}`、
  `attachment/reasoning/tool_call/…`、`cost`、`release_date`。**modalities 数组天然取代 vision 布尔 + 补丁函数。**
- 与 Qwen 手写表 diff:10 条中 5 条逐字一致;2 条数字打架(`qwen-turbo` ctx 131072 vs 上游 1M;
  `qwen3-max` out 32768 vs 65536)——follow 上游;3 条上游没有(`qwen3.5-omni-plus/flash`、`qwen-long`)——撤。
- **已知后果(P1+P2 代价,用户知情)**:omni 系从直连消失(产品语音主路走网关不受影响)、
  `qwen-long` 消失、豆包整家撤。我们 6 家(openai/anthropic/deepseek/alibaba/moonshotai/zhipuai)全收录。
  `cost` 字段不消费(P5)。

### 2.4 桌面端既有地基(全部复用,不重建)

- **工具框架**:S18 五方法接口,`internal/app/tool/<族>/` 二十余族 113 工具;summary/danger/execution_group
  框架注入。前端 113 工具逐卡谱系 + sidestage 舞台已建成。
- **scenario 默认模型**:workspace 已有 dialogue/utility/agent 三格(JSON 存,
  `PUT /api/v1/workspaces/{id}/default-models/{scenario}`)——image/speech/video 三格照抄此 pattern。
- **多模态注入管道**:`infra/llm` 的 `ContentPart` 五型(text/image_url/video_url/input_audio/file)
  + 11 家 provider 各自 wire 渲染——**输入侧地基现成,只缺喂它的第二个来源**(见 2.6)。
- **媒体落盘**:`infra/store/media`(附件域)输入侧在用;生成产物复用同一落盘。
- **block 七型 CHECK 封闭集不动**(§3.3):产物是 tool_result 携带的 MediaRef;`progress` 型承载长任务活进度。
- **E1 三条 SSE 永不再加**:生成进度走 messages 流 ephemeral 帧。
- 前端音频播放卡(A3 验过)、图片渲染管道、AnLastGood/流式增量军规——全部复用。

### 2.5 各家「用自己 key 能生成什么」(物理现实,2026-07 查证到方向级;施工时逐家对官方文档 + 真 key 实测核准)

**图像四家已于 2026-07-27 按官方文档逐家核准**(批B 第 0 步文档半;语音/视频形状仍为方向级,批C/D 各自核准):

| 厂商 | 图(已核准) | 语音 | 视频 | 备注 |
|---|---|---|---|---|
| 阿里 DashScope | ✅ **同步形官方推荐**:`POST https://{WorkspaceId}.<region>.maas.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation`(qwen-image-2.0 系;messages 形入参、`parameters.size/n`)→ 直接返 **24h OSS URL**;异步 text2image + `GET /api/v1/tasks/{id}` 仅 qwen-image(-plus);2.0 系 512²–2048² 任意总像素、n=1–6;plus 系固定档位、n 恒 1 | ✅ qwen3-tts(HTTP)/ CosyVoice(WS) | ✅ wan(异步:image-generation + poll,URL 24h) | 网关上游选同步形(代拍 B1);host 带 WorkspaceId(网关已有 `DASHSCOPE_WORKSPACE_ID` env,吻合) |
| OpenAI | ✅ `POST /v1/images/generations`(gpt-image 系)——**只返 `b64_json`,url 形不支持**(url 仅旧 DALL·E,60min) | ✅ `/v1/audio/speech` | ✅ Sora(异步) | 桌面直连方言解 b64 落库,无 URL 中转 |
| Gemini | ✅ `POST /v1beta/models/gemini-3.1-flash-image-preview:generateContent` + `responseModalities:["TEXT","IMAGE"]`,图在 `part.inlineData`(b64 + mimeType);2.5-flash-image 同形 | ✅ TTS 系 | ✅ Veo(异步) | **聊天 wire 内联出图**,方言在工具 Execute 内承载(§3.1) |
| 智谱 | ✅ images 形(cogview-4 系);返 **URL,有效期 30 天**;约 ¥0.06/张 | ✅ | ✅ CogVideoX | 最省事 |
| OpenRouter | 部分(代理 gemini-image 等) | ❌ | ❌ | 按 models.dev `modalities.output` 判 |
| Anthropic / DeepSeek / Moonshot / Ollama | ❌ | ❌ | ❌ | 物理现实,架构负责「死相好看」(§3.5) |

### 2.6 全执行面缺口(本轮读码实证——「全模态」真正的病灶,三条堵死的水管)

1. **agent 的工具面是配给制**:`app/agent/invoke.go` 的 tools 只有 `Mounts.Resolve(v.Tools)`
   (fn/hd.method/mcp),system prompt 钉死「只准用明确给你的工具」——批B 建好的生成工具,
   agent/workflow-agent/`:invoke` **够不着**。→ P14 `sys:` 挂载。
2. **agent/workflow 输入是瞎的**:`:invoke` payload 纯 JSON 文本;workflow 节点间流 JSON;
   `ContentPart` 注入只有 chat 附件管线在喂。fsnotify「新图落盘」→ agent 节点描述这张图,今天不可能。
   → §3.8 消费咽喉。
3. **MCP 结果媒体被拍平**:`infra/mcp/client.go` `joinContent` 把 ImageContent/AudioContent 渲成
   `[image: png]` 占位文本。→ 批B' MCP 入口。

**部署物理现实**:网关服务器(腾讯云 HK,ins-cf9mdito)2C2G、**公网出方向 1Mbps**——
media 内联转发上游(输入侧,ADR 0012)已在为此付时延;输出侧 base64 内联判为不可行,→ P13 URL 直通。
输入侧带宽照旧,记入 §11 风险不装看不见。

---

## §3 核心架构决策(骨架,每条都有为什么)

### 3.1 生成即工具,不追原生 interleaved 输出

(A)换原生「边聊边出图」聊天模型——等于换厂商,网关 DeepSeek/Qwen 聊天模型都不支持,**否决**;
(B)**生成是工具**:聊天模型照旧,Agent 调 `generate_image` 等 → 后端打生成 API → 产物落盘 →
渲进对话。选 B:与 Quadrinity「一切能力皆工具」同构;任何文本模型都能出图;计费独立、失败隔离;
工具卡/sidestage/danger 全部白拿。**唯一例外**:Gemini 直连出图物理上长在聊天 wire 里,其方言在
工具 Execute 内部用一次性单轮 generateContent 承载,对上层仍是工具。落 ADR(批G)。

### 3.2 跨 key 能力路由:scenario 新增 image / speech / video 三格

生成用哪把 key 与聊天解耦。照抄 dialogue/utility/agent pattern:`modeldomain` 加
`ScenarioImage/Speech/Video`,workspace JSON 加三格,`default-models/{scenario}` 端点自然覆盖。
候选下拉从 model-capabilities 过滤 `modalities.output`。受管档三格由网关路由兜底(用户零配置)。

### 3.3 MediaRef:系统级媒体值类型(不动 block 七型)

`MediaRef{mediaId, mime, width/height 或 durationMs, bytes, …}`——**结构化引用、非字节**。
它就是普通 JSON,因此:tool_result 携带它(chat 渲卡)、frn 行存它(过 CEL 流进下游节点)、
agent payload 带它、文档 markdown 以稳定 URI 序列化它(批F)。**不新增 block 类型**:改 CHECK
封闭集是 D 系列变更 + 前端 sealed DTO 连锁,输入侧附件已证明「引用 + 落盘」够用。
精确字段形在批B 施工时随 wire 定稿并落 reference;升格与文法辖区落 ADR(批B')。

### 3.4 能力目录双轨:直连 follow models.dev(P1),网关自家权威(P5)

- 直连 6 家:删手写表,`modelSpec` 布尔位改模态数组(`qwenNativeInputCaps` 消失);豆包整家撤(P2)。
- 数据形态:**vendored 快照入库**(裁到 6 家,几十 KB,源等价配置非产物)保底 + **运行时后台刷新**
  (数据目录缓存,24h TTL,失败静默用快照)——离线首启有完整目录。`make update-model-catalog` 刷快照。
- 旋钮保留手写(P4);`cost` 不消费(P5);gemini/openrouter/ollama/custom 维持现状。

### 3.5 工具按能力动态注入(诚实缺席)

某 scenario 无可用路由(受管档该能力关 && 无一把 key 的模型 `modalities.output` 命中)→ 该生成工具
**不注入给 LLM**;设置页对应格显示「无可用模型 + 怎么获得」。agent 侧同一原则经 mount-health 表达:
挂了 `sys:generate_image` 而无路由 → 预检亮「挂载当前无可用路由」。先例:网关 `Multimodal.Available`
双半才真——同一原则第三次应用。

### 3.6 网关新端点:OpenAI-compat 形 + URL 直通(P13)

`POST /v1/images/generations`、`POST /v1/audio/speech`。请求取 OpenAI 形(桌面端直连侧反正要实现,
一份 client 两处用);**响应主形是 `url`**(上游 OSS 签名链接直通,绕开 1Mbps 水管),b64 兜底。
网关内部翻译成 DashScope 自家异步形(提交→轮询→取 URL,超时上限设死;失败翻译成既有粗粒度错误枚举)。
device-proof 认证、配额、journal 全走既有轨道;计费「按张/按字符」价格卡照 `InputAudioSeconds`
非 token 单位先例。两条 GW-INV 新不变量见 P13。

### 3.7 `sys:` 挂载词法(P14)

mount ref 第四形:`sys:<tool_name>`,当前白名单 = 三个生成工具(封闭集,新成员逐个立法)。
解析进既有 `MountResolver`;版本化/回滚/pin 全在既有轨道;mount-health 接 §3.5。
chat 侧不受影响(环境制照旧)。

### 3.8 消费咽喉:装配处解引用 + 模态门控

loop 组装 LLM 消息的唯一咽喉处,认出 MediaRef(出现在 tool_result / agent 输入 payload /
文档注入内容中)→ 取字节 → 展开成对应 `ContentPart` → 按该次调用所用模型的 `modalities.input`
(批A 数据)门控:吃得下就注入,吃不下**诚实降级**为文本占位(`[图片:名称/尺寸——当前模型不支持
图像输入]`),绝不静默丢弃也绝不假装。写一次,chat/agent/subagent/workflow-agent 全体受益。

### 3.9 一族卡:前端 mime 分发的媒体卡原语

图卡(缩略图→点开大图)、音卡(播放器,A3 已有)、视频卡、兜底文件卡——一个原语按 mime 分发。
chat 工具卡、sidestage、scheduler 运行卷宗、右岛调试台、approval 渲染、(批F)文档块全部消费它。
守 RI 军规(恒挂翻参)与 AnLastGood 军规。

---

## §4 端到端数据流推演(设计原则 #5;施工时逐条对照)

**受管档 chat 出图主线**:

```
用户:「画一只戴帽子的猫」
→ chat runner(DeepSeek 文本路由)ReAct:LLM 调 generate_image{prompt, aspect}
→ generate 工具族:按 ScenarioImage 解析路由 → 受管行 → 网关 client
→ POST /v1/images/generations(device-proof 签名)
→ 网关:配额预检(10张/天 + 月度钱包双闸)→ 翻译 DashScope 异步任务:提交→轮询→拿 OSS URL
   → 计费(按张,生成成功即 settle)→ journal → **URL 直通**返回桌面端
→ 桌面端:从 OSS 下载字节 → 落 media store → tool_result 写 MediaRef
→ messages SSE close 帧带快照 → 前端工具卡渲缩略图,点开大图
→ LLM 收到 tool_result(MediaRef + 摘要文本),续答「画好了…」
```

**跨 key 直连出图**(P7 主场景):同链,路由解析改「ScenarioImage 显式配置 → 否则已探测 key 里
首个 `modalities.output` 含 image 的模型」;client 换对应家方言(OpenAI 形 / Gemini generateContent
形 / DashScope 异步形)。

**workflow 贯通线**(批B' 验收场景):

```
trigger(fsnotify:新图落盘)→ 节点A agent(挂 sys:generate_image 或直接引用输入图)
→ 节点A 的 frn.result 含 MediaRef → 边 payload → 节点B agent 的 Input CEL 引用它
→ agent host LoadHistory:消费咽喉认出 MediaRef → ContentPart(image)→ 模型真的看见
→ 节点B 输出 → …… → approval 节点渲染模板时媒体引用渲成图卡(人审带图)
```

**朗读**(批C):前端消息动作排「朗读」→ 桌面后端 TTS 端点(缓存键=内容哈希+音色,命中零计费)
→ 播放卡。不经 LLM、零 token。

**跨域依赖(relation 边)**:tool → modeldomain(scenario)→ apikey(路由)→ llm infra(方言)→
media store(落盘)→ messages/frn(引用流通)→ loop(消费咽喉)→ 前端 chat/settings/entities/
scheduler/library。

---

## §5 批A · models.dev 能力目录(先行,独立可交付)—— ✅ 已施工(2026-07-27)

> 落地形态:`internal/infra/llm/modelcatalog.{go,json}`(裁剪/校验/`catalogSpecs` + vendored
> 123 模型)+ `catalogrefresh.go`(30s 延迟 + 24h TTL + fail-silent,bootstrap 接 stop/done 惯例)
> + `cmd/modelcatalog` + 根 `make update-model-catalog`;六家 spec 表删除、`qwenNativeInputCaps`
> 删除、豆包三处(后端/前端/demo)清零。守卫:形状/谓词三轴/缓存优先级/掩码投影/失败静默/旋钮
> 前缀序。**真机核对项**(设置页 6 家数字与 models.dev 对照)留待下次 `make app` 一并复看。

1. `tools/`(或 `cmd/`)拉取裁剪脚本 + 根 `make update-model-catalog`:拉 api.json → 裁 6 家 →
   vendored JSON 入库(S22:源等价配置)。
2. `internal/infra/llm`:`modelSpec` 改形(vision/nativeDocs 布尔 → 输入/输出模态数组;ctx/out 照旧),
   6 家静态表改由 vendored JSON 载入;`qwenNativeInputCaps` 删;knobs 函数保留原样接回(P4)。
3. 运行时刷新:启动后 30s 延迟异步拉 → 校验形状 → 写数据目录缓存;载入优先级 缓存 > vendored;
   失败静默(日志一行)。**绝不影响启动路径**。
4. 豆包撤除:`doubao.go` 及注册、文档、i18n、前端 provider 列表同批删(P2/P19 零包袱,直接删)。
5. `ModelInfo` wire 不变(Vision/Video/Audio 布尔由模态数组投影,前端契约零感知);模态数组是否
   同时上 wire 由批B' 需要时再定(代拍记 §1.1)。
6. 测试:vendored 形状守卫(6 家在位/字段全)、载入优先级、豆包消失、`qwen3.7-plus` 模态投影、
   刷新失败静默。文档:`domains/`相关篇 + 四索引 + contract.md 同提交。

**验收**:根 `make verify` 全绿;app 设置页 6 家模型数字与 models.dev 一致;断网启动列表完整。

## §6 批B · 出图(输出侧第一仗;真 key 实证先行)—— 代码半 ✅ 已施工(2026-07-27)

> 落地清单:**网关**(`1e652a6`+`6381f1d`+`85ecf56`:钱层 InputImages 卡/品类日闸 0006/IMAGE_* 配置
> + app/image + 同步原生 client + handler + 能力面 `image_generation`,GW-INV-49/50/51,lint 净)·
> **桌面后端**(`06f078d0`:五方言 imagegen + tool/generate 路由三级 + CapabilityTools 缝〔代拍 B8〕)·
> **前端**(`67577fa4` 工具卡 + `04a0521a` 设置 image 格〔代拍 B9〕)· **testend**(`dcce59e8`:
> 诚实缺席 + 端到端字节往返两电池)。根 `make verify` 四门禁绿。
> **剩**:真钱真机半(B2 解锁后:真出一张、网关侧 e2e 整栈、B3 价格对账、gh push 部署)。

**第 0 步(P19)**:施工前先实证。**文档半已完成(2026-07-27)**——四家图像 API 按官方文档逐家
核准,证据落 §2.5 修订表 + 代拍 B1(网关走同步上游形);**真线缆半被权限闸挡下**(代拍 B2)——
SSH 上生产服务器被会话权限分类器拒,本地无 DashScope key,待晨间解锁后补:真出一张、验 URL 无
key/时延/journal 行。形状与实测冲突处以实测为准。

**网关**(`Anselm-API-Serve`,对应 working 文档在该仓):
- `POST /v1/images/generations`(OpenAI 形请求:prompt/size/n=1;响应主形 url,P13)。
- DashScope 异步翻译:提交→轮询→取 URL,整体超时设死;失败翻译既有粗粒度错误枚举(GW-INV 不破)。
- billing 按张价格卡;`IMAGE_ENABLED` 配置 + 能力面 `Image.RouteProfile`(双半才真);
  配额(P8:10 张/天/install)/journal/testend 照轨;两条新 GW-INV(P13)+ 守卫测试。

**桌面后端**:
- 新工具族 `internal/app/tool/generate/`:`generate_image`(S18 五方法;danger=safe;参数
  `prompt` + `aspect` 三值枚举,默认 square→1024²,`n` 恒 1,不暴露裸分辨率)。
- 路由解析(§3.2/§3.5)+ 三家直连方言:OpenAI 形(OpenAI/智谱共用)、Gemini generateContent 形、
  DashScope 异步形——各带 wire 单测(照输入侧 12 家 wire 断言矩阵做法)。
- 产物落 media store,tool_result 写 MediaRef(§3.3,字段形在此定稿并落 reference);错误全走 S20。

**前端**:
- `generate_image` 工具卡(生成中骨架→缩略图→点开大图,复用附件预览);sidestage image kind 登台;
  设置页 default-models 加 image 格(含诚实缺席态)。

**测试矩阵**:路由解析五电池(仅受管/仅直连/混合/无能力/显式配置)+ 3 方言 wire 断言 + testend
(llmmock:工具注入有无 × 成功/失败回合)+ 网关 testend + 前端 widget 五电池;
**金标(P19,不省)**:受管档真出一张图。

## §7 批B' · 全模态贯通·执行面(一次性地基;C/D 自动继承)—— 后端四件 ✅ 已施工(2026-07-27)

1. **MediaRef 升格** ✅ 代码半:`pkg/mediaref` 纯文法(Key=`attachmentId`/`att_<16hex>`/Collect
   ≤8 去重,守卫钉文法)。ADR 落批G。
2. **消费咽喉**(§3.8)✅ **四消费者全通**:payload 半(agent invoke:`Attachments+ContentCaps`
   展开进首条 user 消息)+ tool_result 半(loop 六号可选能力 `MediaExpander`——每步收 MediaRef、
   host 按解析模型模态展开、追加 user 消息只喂后续请求、不落盘;chatHost/agentHost〔兼 workflow-
   agent〕/subagentHost 三实现)。守卫:loop 展开双测 + agent payload 门控 + subagent 三态。
3. **`sys:` 挂载**(§3.7)✅:后端词法 + MountResolver 第四前缀 + mount-health;subagent 侧
   `SetMultimodal` 能力工具白名单前并入(11903cc0);前端 agent 概览四词法各读各的字形
   (`sys:`→capability,渲成通用 tool 行会藏起「这个 agent 能产媒体」),mount-health 段本就逐条
   报 healthy/reason、`sys:` 免费继承。**本项目无 agent 手编器**(agent 经 `:iterate` AI 编辑 +
   版本流转),故「挂载 UI」= 概览读得对 + 健康报得准,已全。
4. **MCP 媒体入口** ✅:`CallTool` 返 `(text,[]Media)`,app 层落一等附件 + receipt 追加
   (`source:"mcp_media"`),逐项 best-effort。
5. **前端引用卡族**(§3.9)✅:`core/media/` 三件——`media_ref`(后端 `pkg/mediaref` 的逐条孪生件,
   含字符串形)+ `media_source`(MediaSource 端口 + 成功才 keepAlive 的 meta provider;附件是**平台**
   资源,故各面读媒体不必 import chat)+ `media_cards`(`AnMediaRefCard` 按**附件行的 mime** 分发 +
   `AnMediaRefStrip.forPayload` 展开形)。**三个面已铺**:scheduler 运行卷宗节点 result(JSON 树下)
   / 实体右岛调试台 run result(**媒体在前、JSON 在后**——跑出了图,图就是答案)/ approval 门
   (**藏住产物的人闸不是闸**:只凭附件 id 点「这张图可以发吗」等于盖橡皮章)。`AttachmentImageProvider`
   随之从 chat 提到 core(features 互不依赖)。守卫十条(文法五 + 卡族五)。

**验收**:§4 workflow 贯通线 ✅ **黑盒真跑通**(`testend/scenarios/workflow_media_test.go`:painter
节点挂 `sys:generate_image` 画图 → 把 receipt 当终答交出 → viewer 节点经 CEL `paint.text` 收到 →
消费咽喉解引用 → **viewer 的模型请求里是原生 `image_url` + 生成图的 base64 真字节**,附件字节往返
逐字节相同。为此给 llmmock 加 `EchoLastToolResult`——静态脚本拼不出本次运行刚铸的附件 id,而真模型
本就会把 receipt 抄进终答;`pkg/mediaref` 同时认**字符串形** receipt,因为跨节点它就是这么走的);
**剩**:MCP 返图模型看得见(找一个真返图的 MCP server 实测)、`make verify` 全绿。

## §8 批C · 出语音(语音闭环收口)—— 网关钱层 ✅ 已施工(2026-07-27)

> **两段扇出调研已完成**(读码 + 联网四家官方文档),结论钉在下面;施工照契约、不照猜。

**调研的三条硬结论(推翻了原工单的两处假设)**:
1. **DashScope 没有 OpenAI 兼容 TTS 端点**(`/compatible-mode/v1/audio/speech` 不存在,三处独立
   证据含第三方 404 实测)。故 qwen3-tts **必须**写原生方言:`POST /api/v1/services/aigc/
   multimodal-generation/generation`,body 嵌套 `input{text,voice,language_type}`,响应是 **JSON
   带 OSS URL**(24h 过期)、需**二次 GET** 取字节;**无 `format` 参数**——固定 wav 24kHz/16bit/mono。
   → 原工单写的「OpenAI 形:input/voice/format」对**网关上游**不成立,`format` 从网关线缆去掉。
2. **方言可共用一份**:OpenAI 与智谱 GLM 的 `/audio/speech` 字段名逐字相同、响应同为裸字节,
   一个 client + per-provider 能力描述子即可;Gemini 是第三种(base64 裸 PCM,**要自封 44 字节
   RIFF 头**)。故直连侧是 **3 个方言**而非 4 个。
3. **内部中间表示统一 24kHz/16-bit/mono PCM**:四家原生输出恰好全是这个规格,于是「解容器→PCM→
   切块拼接→统一封 WAV」全程**零重采样**;而长文本必须切块(qwen3-tts 单请求 ~500 字符、GLM 1024),
   **PCM 拼接是纯字节 concat,MP3 帧拼接会留 gapless 缝隙**——这条是格式选型的决定性理由。

**代拍**(记 §1.1):**C1** 品类拒绝改 typed error 而非每品类一个 sentinel · **C2** 价格卡
`qwen3-tts-flash-assumed-2026-07-27` @14e6 pUSD/字符(¥1/万字符第三方数,官方页 JS 渲染取不到,
债由 `assumed` 保持可见,与 B3 同一笔晨间对账) · **C3** 网关线缆去掉 `format`(上游根本不支持,
留着是让契约替代码撒谎) · **C4** 计费单位 = `utf8.RuneCountInString(input)` · **C5** **切块在
桌面端、不在网关**——网关恒守「一请求=一预留=一结算」,网关内切块会让一次预留覆盖 N 次上游调用、
把 GW-INV-50 极力避免的「歧义上游」重新引进来。

**已施工(`c566612`)**:billing `InputCharacters` + 卡 + `NewCharactersPlan`/`CharactersCost` ·
quota `CategorySpeech` + `SpeechDailyLimit` + **带品类名的 typed 拒绝** · quotastore 两个 case
(gate 2c 与 rollback 本体零改动) · config 四键 + fail-fast · `TTS_UNAVAILABLE`/
`TTS_QUOTA_EXHAUSTED`(**避开已被实时 ASR 占用的 `SPEECH_UNAVAILABLE`**) · GW-INV-52/53。

**网关侧已全**(`c566612` 钱层 + `9d0d8e6` 服务层):`infra/upstream/ttsgen`(与 imagegen 共用
端点、请求嵌套 `input{text,voice}`、响应 `output.audio.url` **直通并归一到 https**〔代拍 C6:上游
可能返 http 的 OSS URL,而本系统两端都拒明文取产物;OSS 预签名不覆盖 scheme,真钱冒烟出 403 即
此假设被推翻〕)· `app/tts`(**不叫 app/speech**——那个包名已是实时 ASR)· `handlers/business/audio`
(`POST /v1/audio/speech`,input ≤500 rune、voice 只界形状不校验目录、**显式拒 `format`**)·
router 四处 · bootstrap 无条件构造 · `speech_generation` 能力位。`make verify` 全绿,GW-INV-54。

> **注意一处与原设计的偏离**:调研原建议「网关二次 GET 取字节」,实际按 **P13 URL 直通**做——
> 与图像同一条契约,网关从不持有产物字节,故一篇长文的音频不会变成网关的内存与出口流量。

**剩**:
- 桌面 ✅ 已施工:`infra/llm/speechgen`(三方言 + `BuildWAV`/`ParseWAV`〔**遍历 chunk 表**,真实
  编码器会夹带 LIST/fact〕/`ConcatAudio`〔**PCM 层**重接,字节追加会留第二个 RIFF 头〕+
  `SplitSpeechText` 句读切块)· `tool/generate` **提取共享选路法则** `resolveIn`/`routeIn`(图像与
  语音只差场景、provider 表、无路 sentinel 三样)+ `speechProviders` 手写表 + `defaultVoiceFor`
  **按路由**解析(音色名不跨家通用,一个全局默认会在四家里的三家打出 400)+ `generate/speech.go`
  工具 + `GenerateTools` 追加一项(chat 注入与 agent 挂载自动接住)。守卫 12 格。
- **朗读 + 缓存** ✅ 已施工(后端):`app/readaloud` + `POST /read-aloud:read` +
  `GET /read-aloud/availability`。刻意**不是**工具(工具调用要花 token 和一个回合,去做一件按钮
  已经毫无歧义表达过的事);返回**附件**而非字节,播放复用既有 playback-lease 一等路径。
  **要害:探测发生在合成之前**——`SpeechRouteIdentity` 不打上游就答出路由身份,故重听根本走不到
  provider(合成后再探同样正确、同样花钱,而那恰是本功能绝不能做的事)。键含音色与 provider/model
  (只按文本做键会让换了音色的用户永远听到旧音色)。`speech_cache` 是 **D1 第三个物理删例外**、
  已在 database.md 立法(派生数据、可重建、淘汰是目的;被淘汰行的附件按 D1 软删)。守卫七格,每格
  数**上游调用次数**。前端 ✅:消息动作排喇叭按钮(**以插槽下沉成独立叶子**——在 transcript 的**行** build 里 watch 可用性
  与播放两个 provider,会让两者任一变化就重建每个已落定回合,BuildSpy 闸当场抓到;插槽是叶子、爆炸半径
  是一个小图标)+ 复用**同一个**播放控制器与 playback-lease(一个播放器、一套加载/播放态)+
  `generate_speech` 工具卡(体就是 transcript 渲已发语音那张卡)+ 跨族 receipt 互斥守卫。
- **设置面板** ✅:图像/语音两个生成场景行**参数化成一格** `_GenScenarioRow`(两者只差 provider 表
  与措辞,抄第二份正是两者会开始表现不同的地方——后端在 `resolveIn` 上做了同一个判断);语音表镜像
  后端 `speechProviders`,**能画的 key 未必能说话**,故两行各自独立过滤。守卫三格。
- **testend 黑盒** ✅:诚实缺席(无能说话的 key 时 tools 列表与 availability 双双否认)· 工具端到端
  (注入 → 上游真收到文本 → 一等音频附件字节往返 → receipt 进模型下一轮视野)· **朗读钱断言**
  (重听 `SpeechInputs()` **次数不变**——两种情形响应体一模一样,故悄悄付两次钱的缓存能满足关于音频的
  每一条断言;同场景另证朗读**零 token**:chat 模型一次都没被调用)· 越界输入在花钱之前被拒。
  mock 返 **真 RIFF 流**而非随便字节:桌面在 PCM 层重接,假载荷会让多块测试因错误的理由通过。
- **金标**:真合成一句;缓存命中零计费以 journal 为证(待晨间 key 解锁)。

## §9 批D · 出视频(长任务形态;网关零活)—— 否决项已立 ADR(2026-07-27)

> **[ADR 0013](../../decisions/0013-video-generation-synchronous-tool.md) 已写**:同步等完 + progress 块,
> 两个否决项(挂 durable flowrun / 提交后台+通知送达)连同**什么会推翻它们**一并记档。要点两条:
> ①引擎为工作流而生,把聊天回合里的一个工具变成可记忆化节点要发明三个真问题,全部由同步等完免掉;
> ②离场形态会**割裂产物与上下文**——视频到达时那轮对话已结束,模型再也看不到它,不变量③当场断掉。
>
> **代拍 D1**:**V1 视频产物渲文件卡、不内联播放**。核实过前端今天对 `kind=video` 只有文件卡(带 video
> 字形)、无播放器;内联播放要引入桌面视频栈(`media_kit`/`video_player` 的原生依赖),那是一次独立的
> 依赖决策,不该搭在本批里。文件卡诚实说明它是什么、多大、可在外部打开。**此条建议晨间过目**——它是
> 唯一一处「能力建成但用户看不到成品」的地方。

- **调研实证推翻一处计划**:三家里 **Sora 已公告 2026-09-24 下线**(代拍 D2 不做),而两家在产的
  **都不报进度百分比**——故原计划的「前端工具卡真进度条」不成立,改为**诚实状态行**(合成的进度条会在
  99% 停几分钟,Veo 官方区间 11s–6min)。
- **V1 形态** ✅ 已施工:`infra/llm/videogen.go` 两方言 × 三动词(Submit/Poll/Fetch)+ `tool/generate`
  轮询循环 + `generate_video` 工具。progress 走既有 `loop.ToolProgress`(不加流、不加块型)。
  **产物是「可取回的引用」不是 URL**(DashScope 裸签名 URL 带 Authorization 可能被拒、Google 必须带
  key——方向相反的同一个陷阱)。轮询**爬**向厂商节奏(2s 起 ×1.5 到上限)。守卫四格。
- **视频不进免费档**(P8):网关不开路由;`generate_video` 只在直连侧按 §3.5 注入,自费不限。
- 产物 mp4 落盘,视频卡复用附件视频渲染。**金标**:直连真生成一条。

## §10 批E · fn/hd 媒体产物通道(第五个产地)

### mini-spec(代拍 E1–E4,2026-07-27;读码后定)

**读码所得**:function 在 venv 沙箱里跑 `main.py`,driver 把函数自己的 `print()` 引到 stderr、
把返回值 `json.dumps` 到**干净 stdout**;`ExecutionResult.Output` 就是那份 JSON 解出来的 `any`。
`SpawnOpts.Cwd` 已存在(skill 脚本用它解析兄弟文件)。函数**拿不到** attachment store——它没有
workspace ctx、没有 HTTP、没有 blob 路径,故它**不可能**自己铸出 `attachmentId`。这一条决定了下面
四条的全部形状。

**E1 · 产出目录 = 每次运行一个 `ANSELM_OUT` 临时目录**。spawn 前建一个 run 级空目录、经环境变量
`ANSELM_OUT` 告诉函数,并设为 `Cwd`;函数把媒体写进去(`plt.savefig("chart.png")` 即可,无需知道
绝对路径)。运行结束**整目录删**。**为何不用驻地或数据目录**:那两处是用户的真实文件,一个函数
往里写产物等于让它在用户的工作树里拉屎;而 run 级临时目录让「哪些是这次运行的产物」有一个物理上
无歧义的答案。

**E2 · 引用文法 = 显式声明 `{"$media": "<相对路径>"}`**,由采集器**就地替换**成既有 MediaRef
receipt(`{attachmentId, filename, mime, sizeBytes, source:"function_artifact"}`)。
```python
def plot(rows: list) -> dict:
    plt.savefig("chart.png")
    return {"chart": {"$media": "chart.png"}, "n": len(rows)}
```
→ 下游拿到的是 `{"chart": {"attachmentId":"att_…", …}, "n": 12}`。**为何是替换而非追加**:替换让
产物**留在它本来的那个键上**——`node.chart` 就是那张图,而不是「结果里有个 chart 字段,另外还有个
平级的 artifacts 数组要你自己对应」。也正因如此,不变量①③④全部免费继承:MediaRef 一出现,消费咽喉、
一族卡、workflow 边全都已经认识它。

**E3 · 上限与白名单**:单件 ≤ **32MiB**(与 `imageMaxBytes` 同档)、单次运行 ≤ **8 件**(与
`mediaref.MaxRefs` 同数,因为下游本就只展开这么多)。mime 由**内容嗅探**(`http.DetectContentType`)
决定、**不信扩展名**;白名单 = `image/* · audio/* · video/* · application/pdf`。越界/不在白名单:
该件**不采集**,并在执行 logs 里写一行说明——**绝不静默丢**,也绝不因为一件产物废掉整次执行。

**E4 · 采集时机 = 显式声明,不扫目录**。扫目录会把 matplotlib 的字体缓存、`__pycache__`、中间
文件全变成产物,而且它**答不出「这张图属于结果里的哪个字段」**——而那恰是 E2 要的东西。显式声明
的代价是函数作者要多写一个 `{"$media": …}`,收益是产物有名字、有位置、有归属。

**路径解析 fail-closed**:声明里的路径经 `fspath.Inside(outDir, …)` 判定,越界即拒(逐组件 Stat、
`filepath.Rel` 先挡兄弟目录前缀陷阱)——函数是用户代码,它声明 `../../.ssh/id_rsa` 是必然会发生的事。

**施工** ✅ function 侧已建(2026-07-27):`app/function/artifacts.go` 采集器 + `SandboxAdapter.Run`
接 `ANSELM_OUT`/cwd + bootstrap 注入 attachment store。守卫七格,其中两条是**安全**格而非功能格
(路径逃逸拒在打开任何东西之前、内容嗅探不信扩展名)。**剩**:handler 侧同形接线 + 真机验收
(matplotlib 出图表的 fn,右岛调试台渲出图、workflow 下游 agent 看得见)。

## §11 批F · 文档库全模态(编辑面收口)

1. **值形**:文档内媒体 = MediaRef,markdown 稳定 URI 形(如 `![alt](anselm://media/<id>)`);
   **codec 三保真守卫扩到含媒体往返**(写→编辑→存,引用零漂移)。
2. **编辑器**:图走 super_editor 自带 ImageNode;音/视频自定块渲 §3.9 同一族卡;slash 命令
   (`/图片` 等);拖入/粘贴复用 chat 附件上传管线(上传即入库即有引用)。
3. **补丁协议**:ADR 0009 节点级增量补丁认媒体节点(插入/删除/替换引用)。
4. **AI 侧**:`create_document`/`edit_document` 内容文法认 MediaRef——agent 画完图直接嵌进在写的文档。
5. **@提及注入**:文档冻结注入 chat 时经**同一消费咽喉**解引用 + 模态门控——@带图表的文档问模型,
   模型看见图,全模态自动成立。
6. **右岛连带**:媒体不计字数、字节计大小;大纲/反链不受影响(防 L16 形状的派生值陈旧)。

**验收**:终点验收第 6 条全链真机跑通;`make -C frontend verify` 全绿(编辑器矩阵含媒体块五电池)。

## §12 批G · 收口

ADR 补齐(3.1 生成即工具 + 批D 否决项;MediaRef 值类型;P13 URL 直通——网关侧 ADR 落网关仓);
四索引 / `references/frontend/contract.md` / CLAUDE.md / architecture.md **整体重述**;
ACCEPTANCE-GUIDE 追加真机清单(诚实律:未跑写未跑);终点验收七条(§0.2)逐条核证据;
本页填 `landed-into` 移 archive;网关仓 working 同步 landed。

---

## §13 测试与验收纪律(全战役通用)

- **P19 真钱实测律**:每批验收必含真实调用证据(线缆抓包/journal 行/真产物),mock 绿不算收口。
- 每批四步铁律:读码扇出 + 联网对官方文档核准(§2.5 只到方向级)→ working 更新 → 拍板/代拍 →
  单一作者建 → 对抗复审 → 真机验收。
- 守卫先证红(WRK-083 遗产);测试按「覆盖整类」建,不钉单例。
- 契约改动同提交按域前缀搜 testend(T5.1);两仓 `make verify` 各自全绿;文档 #9 同提交。
- 网关侧:动代码前先对 GW-INV 登记册;深夜施工 push main 前本地门禁全绿 + `gh run` 盯部署结果。

## §14 施工序与依赖

| 批 | 内容 | 前置 |
|---|---|---|
| A | models.dev 目录 + 豆包撤(§5) | 无 |
| B | 出图:真 key 实证 + 网关 + 工具 + 三方言 + 前端卡(§6) | A(能力路由要模态数组) |
| B' | 全模态贯通·执行面(§7) | B(MediaRef 已立形) |
| C | 出语音(§8) | B'(继承贯通) |
| D | 出视频(§9) | B'(继承贯通) |
| E | fn/hd 媒体产物(§10) | B'(mini-spec 可提前写) |
| F | 文档库全模态(§11) | B'(文法与卡族) |
| G | 收口(§12) | A–F |

```
A ──► B ──► B' ──┬──► C ──► D
                 ├──► E
                 └──► F
                        全部 ──► G
```

A→B→B' **严格串行**(地基没干透不并行);C/D/E/F 原则串行推进,真要提速按多会话纪律开
worktree 并行,但每仓同一时刻只一个作者会话。

## §15 风险与已知代价(诚实台账)

- ~~DashScope 异步翻译层是批B 最大工作量~~ **已消解**(代拍 B1):官方同步形直接返 URL,网关免任务轮询层;残余风险仅剩「同步上游连接持有几十秒」的超时配置。
- **super_editor 音/视频自定块**是批F 最大不确定点(ImageNode 自带,音视频块自建;vendor 在手,可扩)。
- **输入侧带宽照旧**:URL 直通只救输出;3MiB 图上行内联转发仍走 1Mbps——接受慢或某天升带宽,记档不藏。
- **models.dev 数据错**:follow 上游意味着跟着错;能力侧靠社区修,上下文侧有 modelprofile
  撞墙学习兜底(已知情接受)。omni/qwen-long 从直连消失、豆包撤(§2.3)。
- **运行时刷新**是首个「启动后后台网络任务」:绝不影响启动路径(§5.3 fail-silent)。
- 各家生成 API 形状查证仅到方向级:批B 第 0 步真 key 实证 + 逐家官方文档核准,冲突以实测为准。
