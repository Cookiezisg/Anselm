---
id: DOC-030
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-24
review-due: 2026-10-19
audience: [human, ai]
---

# 支撑服务十二域 —— workspace · apikey · freetier · model · websearch · catalog · mention · notification · aispawn · humanloop · contextmgr · entitystream

> 十二个微域合篇（各 100-900 行）。每节：定位 + 关键设计 + 契约引用。

## workspace —— 隔离根

唯一**没有** workspace_id 列的表（它就是 workspace 本身，全局表——这正是后台 `forEachWorkspace` 播种能在裸 ctx 列它的原因）。CRUD + 守"最后一个不能删"（`CANNOT_DELETE_LAST_WORKSPACE`）+ 语言校验 + auth 中间件的 `WorkspaceResolver` 端口（`Resolve`——校验 id 并返其 UI locale，使 **workspace.language 权威于 Accept-Language**：识别到 workspace 即覆盖头默认，assistant 按用户显式持久化语言回复，头仅作 onboarding 兜底；**单列读**——每请求都走此路,repo `Language` 只 Pluck language 列〔空结果即 ErrNotFound,存在性检查含在内〕,不再为一个字符串付整行 13 列反射 + 3 次 ModelRef JSON 反序列化,R3）。**Delete 级联销毁**（Reaper 端口、bootstrap 后注入）：杀全部 workflow 自动化（摘监听+取消在途 run，连手动 run 一并）→ 停常驻 handler 实例 + 断开 mcp → 清搜索索引 → 删盘上文件树（skills/memories）→ 删 ws 行（行消失即数据不可达+后台播种跳过；DB 实体行留作不可达遗留）。全程 Detached(目标 ws) ctx——删除请求可来自另一 workspace；best-effort。携带 per-workspace 模型默认（dialogue/utility/agent 三场景 ModelRef 列 + 默认搜索 key + `webFetchMode`——WebFetch 工具抓取方式，local=本机直 GET（默认，URL 不出本机）| jina=公共 reader（提取更好但 URL 发第三方）；PATCH 设置、Service 经 `WebFetchMode(ctx)` 供 tool/web 读、读不到一律收敛 local）。**Stats**（`GET {id}/stats`,WRK-062 S-11）：删除确认的内容盘点——store 一批相关标量子查询数 conversations/functions/handlers/agents/workflows/documents（滤软删）+ `runningFlowruns`（Log 表无软删、走 partial 索引数 running）；`generatingConversations` = chatapp `GeneratingIDs()` 内存在飞快照与本 ws 活行求交（`SetStatsPorts` 后注入,同 Reaper 模式）；`blobBytes` = blobfs `TotalBytes` 在 500ms ctx 预算内 walk `workspaces/<id>/blobs`,超时/未接线返 **-1**（诚实未知,绝不假 0）。路由属 workspaces 豁免前缀,handler 不依赖 header、app 层把 path id 铸进 ctx。码 7（`WORKSPACE_*` 6 + `CANNOT_DELETE_LAST_WORKSPACE`）；ID `ws_`。

## apikey —— 加密凭据管理

凭据自身生命周期：存（AES-GCM 整密文）、probe 连通性测试、按 id 发放（`KeyProvider`/`ProbeReader` 端口）。**刻意零 provider 语义**——选哪个 key、key 隐含什么模型，是 model/websearch 的事。**删除守卫**：`RefScanner` 端口（boot 注册，返 `[]apikeydomain.APIKeyRef`），Delete **聚合每个 scanner 的引用、非空即拒**（`API_KEY_IN_USE` 422，**`details.references` 带每个引用方 `{kind,id,name}`**——kind ∈ `scenario_default`/`search_default`/`agent_override`，前端据此指明去哪解引用，G4）；真实引用来源二——workspace 的三 scenario 默认模型 / 默认搜索 key（`workspace.ReferencesAPIKey`）+ agent active 版本的 modelOverride（`agent.ReferencesAPIKey`），均结构满足端口（仅为 ref 类型 import `domain/apikey`，不依赖 apikey app）、build_services 注入。probe 归档供 model 聚合解析。**旋转 key**（`PATCH` 带新 `key`）重置探测档案为 pending 后**自动重探一次**（有 tester 时，复用 `:test` 路径），200 带回解析后的 `testStatus`，免去「ok 但模型从选择器消失」的静默 pending；重探失败**不让 PATCH 失败**（旋转已成功，同 `CreateManaged` 脑裂取舍，G7）。**内置受管 provider（免费档网关 `anselm`）**：`ProviderMeta.Managed=true` 标记（`GET /providers` 暴露 `managed`，前端据此排除手动「添加 key」列表）；`CreateManaged` 直接播种探测档案（`test_status=ok` + 合成 `/models` body，**跳 live 探针**——否则「ok 但选择器无模型」死状态，且避开配额耗尽探针翻 key 的脑裂），受管行的 `key` 字段保存公开 `installId`（非凭证）、provider=`anselm`、base=`api.anselm.website/v1`；真实认证由 `infra/deviceproof.Transport` 用安装 Ed25519 私钥逐请求完成；`Update` **与 `Delete`** 对受管行均返 `API_KEY_IMMUTABLE`（422——DELETE 与 PATCH 对称守卫，WRK-062 S-1：受管 install id 行由后端拥有，删除会割裂安装身份与配额历史，零引用也不放行；Delete 先 Get 行判 Managed，再跑 `RefScanner`）。**custom provider 的 `apiFormat`** 在 `validateCreate` 经白名单校验（`openai-compatible`/`anthropic-compatible` 二选一，非法 → `API_KEY_API_FORMAT_INVALID` 400）——堵掉任意串静默落 OpenAI-compat 默认、走错方言（G9）。码 `API_KEY_*` 10；ID `aki_`。

## freetier —— 内置免费档凭证 + 配额代理

把每 workspace 接入 Anselm 网关（按内容能力自动分流的 OpenAI-wire gateway，`api.anselm.website/v1`）的内置免费档。**provisioner**（boot 的 `forEachWorkspace` + `workspace.SetOnCreated` 钩子覆盖 boot 后新建 ws，幂等 best-effort）首启加载/创建机器级 Ed25519 signer（seed 经 Encryptor 写 `$ANSELM_DATA_DIR/device-proof.key`，`0600`），签名 POST 网关 `/install` 登记 public key（另发**机器指纹 SHA-256**、绝不传裸序列号），同 key 幂等取得公开 `installId`，落一条受管 `anselm` api_key 行（经 apikey `CreateManaged`，跳 live 探针），**并把受管模型（`AnselmModelID`=`anselm-auto`）播成 workspace 三 scenario（dialogue/utility/agent）默认**（`workspace.SeedDefaultsIfUnset`——只填仍未设的 scenario、绝不覆盖用户显式选择；已开通路径也补播，故 key 早于播种的 ws 下次 boot 自愈其 NULL 默认），使一切开箱即解析。其 `/v1/models` 能力扩展按 route 明示：纯文本 DeepSeek 与原生图片/MP4 的 Qwen3.7 Plus 均为 1M input，产品 output cap 16,384，并动态给 availability；旧网关才回退同值静态档。音频协议已预留但当前不宣传。降级铁律：每个失败路径 log 并返 nil（无指纹 / install 失败 / 持久化冲突 / 播种失败），免费档缺席绝不挂 boot/onboarding。**手动重试口** `POST /freetier:provision`（S-7，`Provisioner.ProvisionNow`）：同一幂等 ensure 但**报告结果**——事后存在受管行返 `{provisioned:true}`（原有或新建）、开通降级返 false（状态非错误、不抛）；设置页免费档卡的「启用」按钮消费。**配额代理**（`QuotaReader`，`GET /freetier/quota`）：List 定位受管 anselm 行 → `ResolveCredentialsByID` 读其公开 `installId` → `QuotaClient` 由同一 proof transport 签名调用网关 `GET /v1/quota`（与 chat/models 同一设备私钥），返 `{limit,used,remaining,resetAt,available}`。客户端**无法直读**——Ed25519 私钥只在 Go sidecar 内、加密落盘且不进 Flutter/DB/header；proof 绑定 install、时间、server nonce、一次性 jti、method、authority+target 与 exact body hash，复制 id/抓包不可复用。无受管行 → `FREETIER_NOT_PROVISIONED`（404）；网关失败映射为对应 `LLM_*` 分类。码 `FREETIER_NOT_PROVISIONED` 1；无自有表无 ID（骑 apikey 的 `aki_` 受管行）。

## model —— 模型选择与能力

无存储：默认在 workspace 列、覆盖在实体字段。定义 `ModelRef` 值 + 三场景白名单（dialogue/utility/agent）+ **覆盖优先默认兜底**规则；`CapabilityService` 读 apikey 的 probe 归档、经各 provider 自描述的 `DescribeModels` 聚合模型目录（`vision/video/audio/nativeDocs` 与可选的单回合 `maxMediaParts/maxMediaBytes` 一起供 chat 附件门控和前端诚实展示）。每条持久化 ModelRef 的非空 `options` 都必须精确匹配该已探测 key/model 公开的 native knob 与值：未知字段→`MODEL_OPTION_UNSUPPORTED`，非法值→`MODEL_OPTION_VALUE_INVALID`；空 options 不要求目录命中，因此未探测/custom 模型仍可运行、却不会假装支持未知配置。**LLM 工具**：只读 `get_model_config`（`tool/model`，无参；投影三场景默认 ModelRef + 已配 key 的**脱敏**形（`KeyMasked`、绝不出明文）+ CapabilityService 可用模型的 context/output、text/multimodal route budget、模态位、media envelope 与 `nativeOptions` knobs）——使 agent 从真 workspace 配置答「我在用什么 / 这模型支持什么配置」、不必 grep 主机 FS（后者会泄露 `.env` 明文 key 并臆造假审计，F68）。码 `MODEL_*` 5。

## websearch —— 搜索配置词汇

最小 domain：provider 词汇（brave/serper/tavily/bocha）+ `SearchKeyPicker` 端口（workspace 选的搜索 key）。执行在 `tool/web`（BYOK 单 key 直连，无 provider 遍历）。

## catalog —— 能力总览（派生、不存）

按需聚合注册 source（function/handler/agent/skill/mcp/document/attachment…各自实现 `ListItems`）：`Summary`=注入 system prompt 的分组菜单文本；`Coverage`=结构化 source→ids 供 HTTP。**永不持久化、永不缓存**——每次现扫当前真相。容器实体（handler/mcp）带 `Members` 子单元列表。码 `CATALOG_ALL_SOURCES_FAILED`。

## mention —— @ 引用契约

纯契约包：`MentionType` 集（9 类：Quadrinity + document + trigger/control/approval + **skill**）+ `Resolver` 接口 + `Reference` 快照形状。**freeze-on-send**：发送时快照被 @ 实体内容进 user 回合 Attrs，实体后续变更不影响已发送语境。**@ 语义按类型分岔**：多数是**引用**（注入内容快照），**`@skill` 是激活**（WRK-076）——resolver 渲染 skill body 作快照（内容半），chat 在回合运行时经 `SkillPreauthorizer.PreauthorizeActiveSkill` 预授权其 allowed-tools（副作用半；fork skill 跳过、信任门照 B4）。各实体的 mention_resolver.go 实现并 boot 注册。

## notification —— 通知中心

任何模块经 `Emitter` 端口发 `<domain>.<action>`，**两档**（都是 notifications 流上的 durable 信号，SSE 推送 best-effort）：**`Emit`** 落 DB 行 **并**推帧（DB 行是真相、`GET /notifications` 兜回——失败 / AI 可能干的实体生命周期，值得用户事后在收件箱找到）；**`Broadcast`** 只推帧、**不落行**（高频对账回声：rail 重排 / documents 树刷新 / env 装配开始等，进收件箱即噪音；临时 `noti_` id 锚定帧、通知中心不留痕，其真相是实体自身状态、消费者收帧后重取实体 REST 行/整树）。逐事件的档位登记见 [`events.md`](../events.md)「notifications 流」节（⊞ Emit / ⤳ Broadcast）。前端列表 + 未读徽标（`WhereNull(read_at).Count`）——只数落行的档。集合级读态：`mark-all-read`（`WhereNull(read_at).Update(now)`）与其镜像 `mark-all-unread`（`WhereNotNull(read_at).Update(nil)`——清全部 read_at 回未读）皆纯 repo 委派、**不发帧**、204、幂等，徽标靠 unread-count 重取对账。两端点带**可选窗口 body** `{after?,before?}`（RFC3339）——`created_at` 上的半开窗 `[after, before)`（`windowed` 追加裸列谓词 `created_at >= ?` / `< ?`，flowrun `started_at` 窗的逐字翻版、界值 UTC、走 `idx_noti_ws_created`）；托盘据此把某时间组的「全部已读/未读」限在该组行，缺省字段=该界不设、**无 body 即整本账（向后兼容）**；非 RFC3339 界 422 `NOTIFICATION_INVALID_WINDOW`。码 `NOTIFICATION_*` 3；ID `noti_`。

## aispawn —— AI 工作对话引擎（:iterate / :triage）

两个动词都归结为"开一个预 seed 上下文的对话，让正常 chat loop 接管"：`iterate` seed 实体（function/handler/agent/workflow/document 经 mention 快照注入）+ 编辑指引；`triage` seed 一次失败执行的诊断上下文。返回 `conversationId`（N5）。码 `EMPTY_ITERATE_REQUEST`/`UNTRIAGEABLE_EXECUTION`。

## humanloop —— 人在环 broker

进程内 broker：`Request(ctx, req)` **阻塞**挂起 waiter（按 toolCallID 键）直到 `Resolve` 送达人的决定或 ctx 取消；`Surface` 回调（chat 注入）把待决请求推成 ephemeral 流信号；**内存 pending 表是重连重同步的真相源**；`Allow/IsAllowed` = approve_always 的会话级白名单（与 active skill 的 allowed-tools 同为预授权来源）。经 ctx（`WithBroker/From`）流进嵌套 agent 运行。无表无码（纯运行时）。

## contextmgr —— 对话压缩引擎

contextmgr 是 durable **回合边界**生产侧，和 loop 的**每次 sampling 前**即时治理互补。回合收尾读取 assistant `Attrs.contextUsage.lastPromptInputTokens/inputBudgetTokens`（绝不读整轮累计 `Message.InputTokens`）；最后一次 prompt 达 80%，或本轮发生过 prompt edit/checkpoint/recovery 时，执行：① **demote**（免 LLM）——全线程 tool_result 按新旧降 hot→warm（预览）→cold（占位），即使最新单个 assistant 回合内有很长工具链也能老化旧结果；② 仍超预算才 **summarize**——utility 模型摘最旧 span、增量并入 conversation.summary、推水位。最近 2 条 message 是 durable 摘要的逐字底线；loop 仍可在其 prompt-only 投影内清旧工具结果/做 checkpoint。**水位（summary_covers_up_to_seq）是幂等键**：崩溃在写 summary 与翻 archived 标记之间也不重复计数。写面最小：conversation 的 summary+水位 + blocks 的 ContextRole（投影、不改 Content）。**demote 只动 tool_result 是刻意的**：用户原话不截断，大粘贴交给诚实摘要，明确全文已不在上下文且需重发/重取。

## entitystream —— entities 流生产原语

SSE-C 的唯一生产 helper：向 Bridge 发实体锚定的节点（open→delta*→close 或点 Signal），scope = 实体（function/handler/agent/workflow/mcp/…）。所有实体面板的实时活动（run 终端/build 镜像/fire 信号/节点进度）都经它——**一个原语、十处复用**。nil Bridge 全程容忍（无流不影响业务）。ctx 注入（WithBridge/WithRunScope）供 loop 镜像 build 工具。
