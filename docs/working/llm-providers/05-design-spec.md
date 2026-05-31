---
id: WRK-002-05
type: working
status: archived
owner: @weilin
created: 2026-05-25
reviewed: 2026-05-30
review-due: never
audience: [human, ai]
landed-into: docs/concepts/architecture.md
---
# LLM Provider Adapters + Thinking + Capability Catalog — 设计 spec

> 日期 2026-05-29 · 状态:草稿待审 · 作者:Claude(brainstorming 收口)
> **调研依据**:`documents/version-1.2/working/llm-providers/{01-audit, 02-build-vs-adopt, 03-implementation-reference, 04-capability-catalog}.md`(体检 / 选型 / 施工图 / 能力目录)。
> **一句话**:把 LLM 层做成「每家一个完整 adapter + 一张能力目录(规则+实时读+用户覆盖)+ thinking 三态联合体」,顺手修 3 个真 bug + compaction 永远按 4K 压的 bug,全程零-key 黄金测试护栏。

---

## §1 目标 / 非目标

**目标**:
1. **配 key 配模型完美无 bug**——10 家直连 provider 都真能跑通(不是"理论能跑、没测过")。
2. **thinking 可配**——最细单元 `(key/provider, model, thinking-effort)`,各家按自己的能力适配(数值预算 / effort 枚举 / 二元开关)。
3. **上下文窗口正确感知**——能力目录提供 per-model 窗口,修掉 compaction 现在不分模型一律按 4K 压的 bug;Qwen/Ollama 的上下文模式可配。
4. **零-key 可验证**——每家黄金线格式测试 + httptest 回环,证明请求字节对、响应解析对。

**非目标(本期不做,明确延迟)**:
- ❌ 引入开源多厂商库 / 网关替代手写(`02` 已结论:无干净 Go 替代,手写是对的;长尾交 OpenRouter 兜底)。
- ❌ Checkpoint/Undo(§10.1 已砍)。
- ❌ thinking 的 token 计费精算 / 预算自动调参——本期只做"开/关/档位/预算值"的透传,不做智能调度。
- ❌ Anthropic prompt caching 的全量优化(已有 ephemeral 断点,保持现状)。
- ❌ OpenRouter BYOK 引导 UX 大改——保持现有 provider 入口,文案标注"云中转"即可(可单独小任务)。

---

## §2 架构总览

三大件 + 两个修复,挂在现有 4 层 clean arch 上:

```
能力目录 modelcaps (internal/pkg/modelcaps)  ← 新, 吃掉现有 contextmgr/modelmeta
   │  家族规则(静态) + 实时读(4家) + 用户覆盖
   │  供给: ① picker UI(经新端点) ② wire 编码(max_tokens/thinking 形状) ③ compaction 窗口
   ▼
Provider 接口 (internal/infra/llm)  ← 重构: 2 client+adapter → N 完整 adapter
   │  每家完整拥有 base/auth/BuildRequest(含thinking)/ParseStream/quirk
   │  transport.go 共享铁律(http/SSE扫描/sanitize)
   ▼
ModelRef 三维 {APIKeyID, ModelID, Thinking}  ← thinking 沿现有两层旅行
   │  model-config(scenario默认) + conv/node override + subagent继承
   ▼
消费: chat runner / scheduler dispatchers / contextmgr(compaction) / utility callsites
```

**为什么是这个形状**(对照调研):
- 每家完整 adapter:用户明确选择(`02`/对话),10 家有界;Anthropic & Gemini-native 本就该是独立实现(线格式根本不同)。
- 能力目录吃掉 modelmeta:避免两个并行的 model 元数据表(compaction 已有一个私有 modelmeta)。
- thinking 进 ModelRef:复用刚建好的两层机制,零新管线。

---

## §3 能力目录 modelcaps(新包)

**位置**:`internal/pkg/modelcaps/`(pkg 因为 apikey-app、infra/llm、contextmgr 三方都消费;**不可叫 catalog**——`internal/app/catalog` 已是 agent 工具菜单,会撞)。**吃掉** `internal/app/contextmgr/modelmeta.go`(现有 per-model 窗口注册表),contextmgr 改为消费 modelcaps。

**数据形状**(family-pattern 规则,抗月度漂移——`04` 全表):
```
type Cap struct {
    ContextWindow int            // 输入窗口 token(Ollama=用户 num_ctx)
    MaxOutput     int            // 输出上限
    Thinking      ThinkingShape  // none | effort | budget | toggle
    EffortValues  []string       // effort 形状时的合法值
    BudgetMin/Max int            // budget 形状时的范围
    ContextMode   string         // "" | "qwen_max_input" | "ollama_num_ctx"
}
type Rule struct { Pattern string; Cap Cap }   // 前缀匹配, 最具体优先
```

**三层解析**(治"月月烂"):
1. **静态家族规则表**(`04 §1` 全部 11 provider 的前缀规则)= 兜底。占位/未来名(`claude-opus-4-8`/`gemini-3.5-*`/`qwen3.7*`)继承家族机制。
2. **实时读覆盖**(4 家):Anthropic `/v1/models`(`capabilities.thinking`+`max_tokens`+`max_input_tokens`)、Gemini `models.get`(`inputTokenLimit`+`thinking` bool)、OpenRouter `/api/v1/models`(`context_length`+`supported_parameters`)、Ollama `/api/show`(`capabilities[]`+`model_info.<arch>.context_length`)。启动/key 验证时拉一次缓存,覆盖静态值。复用 `app/apikey/tester.go` 的 HTTP probe helpers。
3. **用户覆盖(本期做——跟不上月度更新时的逃生口)**:目录陈旧(新模型 + 静态规则猜错 + 又不在实时读那 4 家)时,用户在设置里手动改"这模型 thinking 形状 / 窗口"。存新表 `model_cap_overrides`(§7),覆盖永远最高优先级。**合并**:`modelcaps.Apply(base Cap, *CapOverride) Cap`(纯函数,override 的非空字段盖过 base);I/O(取 override + 实时读)由 `app/apikey` 持有(它已管 providers/tester/key 生命周期),对外出 `ResolveCapabilities(ctx, provider, modelID) Cap` + 列表给端点。优先级:**用户覆盖 > 实时读 > 静态规则**。

**关键家族规则**(摘自 `04`,完整见该文件):
- OpenAI `gpt-5.1*`→effort(none/low/med/high), `gpt-5.5*`→1M;DeepSeek `deepseek-v4*`→1M+toggle+effort(high/max);Anthropic `*-4-(7|8)`→1M原生+adaptive必须(manual budget→400),`sonnet-4-5/-4`→200K+budget(1M头已死);Gemini `2.5-*`→budget,`3*`→effort;Qwen→bool enable_thinking+budget(开thinking强制stream);GLM/Kimi→toggle;Doubao `1.6`→budget,`1.8+`→effort;OpenRouter→全 live;Ollama→窗口=num_ctx(默认4096坑)。

---

## §4 Provider 接口重构(infra/llm)

**保留(稳定契约,所有调用方依赖)**:`Client` 接口、`StreamEvent`/`Request`/`Response`/`LLMMessage` 类型(`llm.go`)、`Generate`/retry/`sanitizer`/`trace`/`mock`。唯一调用入口仍是 `llmclient.finishResolve` → `factory.Build`。

**最终架构(R1-R5 后)**:每个 provider 是完全自包含的独立文件，各自拥有完整的 `BuildRequest`(含 thinking 编码 + auth 头)和 `ParseStream`。`transport.go` 只保留 HTTP/SSE 铁律(`doRequest`/`scanSSELines`/`classifyHTTPError`)，零 provider 逻辑。没有"共享 OpenAI-compat wrapper"——初期 P2 引入的 `openAICompatProvider` 已在 R1-R5 重构中删除。

**Provider 接口**:
```go
type Provider interface {
    Name() string
    DefaultBaseURL() string
    BuildRequest(ctx context.Context, req Request) (*http.Request, error)
    ParseStream(ctx context.Context, resp *http.Response, req Request) iter.Seq[StreamEvent]
}
```
**文件**:`provider.go`(接口+注册表+`providerClient`)、`transport.go`(铁律:http do、scanSSELines 含跳 OpenRouter `:` 注释行、classifyHTTPError)、`openai.go`/`deepseek.go`/`anthropic.go`/`gemini.go`/`qwen.go`/`zhipu.go`/`moonshot.go`/`doubao.go`/`openrouter.go`/`ollama.go`/`custom.go` 各一个完整自包含实现。`openai.go` 还持有共享的 `oai*` wire types、`buildOpenAIBody`(测试工具)、`parseOpenAISSE`/`emitOpenAIChunk`/`clampEffort`/`deepseekMapEffort` 等内联原语。

**Gemini**:原生 `generateContent` provider（非 OpenAI-compat 垫片），reasoning-text readback + thoughtSignature round-trip（03 §5）。

**Request 加 thinking 字段**(`llm.go:110`):`Thinking *ThinkingSpec`(归一意图);各 adapter 的 `BuildRequest` 翻译成自己的线上形状(§5)。`Config`(factory.go:8)加 `APIFormat`(已有)+ thinking 不进 Config(走 Request)。

---

## §5 Thinking 端到端

**归一表示**(domain/model,进 ModelRef):
```go
type ThinkingSpec struct {
    Mode   string  // "auto" | "off" | "on"        ; auto=不发参数(向后兼容, 现有 ModelRef 零改)
    Effort string  // ""|"minimal"|"low"|"medium"|"high"|"xhigh"  (effort 家族)
    Budget int     // >0 时用(budget 家族)
}
type ModelRef struct { APIKeyID, ModelID string; Thinking *ThinkingSpec }  // 第三维
```

**各 adapter 翻译**(`03 §1` 主表,6 形):
- effort 家族(OpenAI/Gemini-3/OpenRouter/DeepSeek/Ollama/Doubao-1.8):映射到 `reasoning_effort`/`thinkingLevel`/`reasoning.effort`。
- budget 家族(Anthropic/Gemini-2.5/Qwen/Doubao-1.6):映射到 `thinking.budget_tokens`/`thinkingBudget`/`thinking_budget`。
- toggle 家族(GLM/Kimi):`thinking:{type:enabled/disabled}`。
- **守卫**(adapter 内强制):Qwen 开 thinking 强制 `stream:true`;Anthropic budget≥1024 且 <max_tokens 且省 temperature;Anthropic Opus 4.7/4.8 用 adaptive 而非 manual budget;OpenAI 推理模型用 `max_completion_tokens` 禁 temperature。

**Anthropic signature 全链路**(thinking 硬前置,`03 §4`):解析 `signature_delta` → 无损存到 reasoning 块 → 工具循环回传时原样带回(含 redacted_thinking 的 data)。否则 400。

**DeepSeek reasoning_content 回传**:普通 assistant 轮剥、带 tool_calls 轮保留(与 Anthropic 镜像)。

**插桩点(必改,非免费)**——`llmclient.finishResolve`(llmclient.go:110-137)现在丢弃除 apiKeyID+modelID 外一切:
- `Bundle`(llmclient.go:31)加 `Thinking`;
- `finishResolve` 把 `override.Thinking` 透传进 Bundle + Request;
- utility scenario 无 override → thinking 取自 ModelConfig 行(见 §7)。

---

## §6 三个真 bug(test-first,各在自己 adapter 修)

| bug | 文件:行 | 修法 |
|---|---|---|
| 🔴 Gemini chat 404 | `app/apikey/providers.go:43`(google base 缺 `/v1beta/openai`)覆盖了 `adapter.go:40` 正确值,经 `apikey.go:320` 回填 | providers.go google base 改对(或置空让 adapter 默认生效);`:test` 端点对齐;**dedicated adapter 走 native `generateContent`**(`03 §5`/`05` 建议:compat 面 reasoning write-only) |
| 🔴 Ollama base-path | `app/apikey/tester.go:248`(`/api/tags`)与 chat(`/v1/...`)共用一个 base_url,喂不了两头 | tester 持 root,`TrimSuffix("/v1")` 再拼 `/api/tags`;chat 用 root 拼 `/v1/chat/completions` |
| 🔴 custom anthropic 死路 | `domain/apikey/apikey.go:51` Credentials 无 `APIFormat` → `finishResolve`(llmclient.go:120)拿不到 → factory 落 OpenAI | Credentials 加 `APIFormat`;`ResolveCredentials*`(app/apikey)填充;`finishResolve` 透传进 Config |

---

## §7 数据模型 + DB

| 载体 | 现状 | thinking 改动 |
|---|---|---|
| `ModelConfig`(model_configs 表) | 扁平列 api_key_id/model_id | **加 `thinking` 列(AutoMigrate,TEXT/JSON)** —— per-scenario thinking 默认 |
| `conversation.model_override` | JSON blob(serializer:json) | **免费**——ModelRef 序列化自动含 thinking |
| workflow `NodeSpec.ModelOverride`(graph JSON) | JSON blob | **免费** |
| ref-scanner JSON 查询 | `json_extract(..,'$.apiKeyId')` / `LIKE '%"apiKeyId"%'` | **安全**(thinking 作 sibling 字段) |
| **用户能力覆盖** | 无 | **新表 `model_cap_overrides`**:`id(mco_<16hex>)`、`user_id`、`provider`、`model_id`、`thinking_shape *string`、`context_window *int`、`max_output *int`(均可空,只覆盖设了的)、created/updated/deleted_at、`UNIQUE(user_id,provider,model_id)`(D 系列)。`mco_` 前缀加进 §S15。 |

---

## §8 HTTP API

- **`PUT /model-configs/{scenario}`**:body + `UpsertInput`(app/model/model.go:45)+ handler(handlers/model.go:30)加 `thinking`;`Service.Upsert` 拷贝。
- **新 `GET /model-capabilities`**:返 `ResolveCapabilities` 合并后的目录(用户覆盖>实时读>静态;per provider/model 的 thinking 形状 + 窗口 + contextMode),供前端 capability-aware 渲染。**不扩 `/providers`**(粒度不同:providers 是 provider 级,caps 是 model 级)。
- **新 `PUT /model-capabilities/{provider}/{modelId}`**:写用户覆盖(body 含可空 thinking_shape/context_window/max_output)→ upsert `model_cap_overrides`(204/200);**新 `DELETE /model-capabilities/{provider}/{modelId}`**:清覆盖回落规则/实时读。errmap 视需要加 sentinel。
- **conv `:update`(PATCH)**:`ModelRef` 自动反序列化 thinking,**免费**(除非要 handler 级校验)。
- **workflow `set_node_model_override`**:`apply.go:357-375` 现在只抽 apiKeyID+modelID → **改成直接用已 parse 的 `ref`**(line 354 已 full unmarshal),thinking 即免费带上。

---

## §9 前端

**原则**(`05` frontend 调研):capability-driven 渲染,3 种控件按所选 model 的能力形状切。

- **新端点 hook**:`entities/model-config/api/model-config.ts` 加 `useModelCapabilities()`(读合并目录)+ `useSetModelCapabilityOverride()` / `useClearModelCapabilityOverride()`(写/清覆盖)+ `qk.modelCapabilities()`;`entities/model-config/model/` 加 `capabilityFor(provider, modelId)` selector(三处消费者统一解析)。
- **能力覆盖 UI**:展开卡(或 ApiKeys 区)给当前选中 model 一个「覆盖能力」小入口——改 thinking 形状 + 窗口,持久化到 override 端点。陈旧/猜错时用户自救,不用等发版。
- **types**:`ModelConfig`/`UpsertModelConfigBody` 加 thinking;`entities/conversation` 的 `ModelRef` 加 thinking(经 `@x/workflow` 自动波及 NodeSpec)。thinking 形状**与后端 `ThinkingSpec` 一致用扁平 `{mode:"auto"|"off"|"on", effort?, budget?}`**(不用判别联合)——「用哪个字段」由能力目录 `capabilityFor()` 决定(effort 家族填 effort、budget 家族填 budget、toggle 家族 mode on/off),值本身不自带 kind。
- **ModelDefaultsSection**(刚重建的展开卡):在 `set-mc-body` 的 (key,model) 两字段下加**第三行 thinking 控件**(capability 决定 slider/枚举/toggle);Qwen/Ollama 再条件显**上下文模式**;卡片 summary 加 thinking 小标。**级联 reset**:换 model 时 thinking 重置为新 model 默认(budget 值跨 model 无意义)。
- **ModelOverrideEditor + WorkflowEditor inspector**:thinking 控件**放在 KeyModelPicker 旁**(不进它的单字符串编码);`useWorkflowEdit.modelOverrideEq` **必须比较 thinking**(否则 thinking-only 改动 autosave 漏掉)。
- **Onboarding**:**保持极简,不暴露 thinking**(`05` 建议:onboarding 是"一次决定、直奔首聊";thinking 留 settings 调)。3 个 scenario 仍只播种 (apiKeyId, modelId),thinking 走后端默认/auto。
- **不碰**:Composer(无 model 控件);`entities/settings.reasoningDefault`(那是 reasoning 块折叠状态,**与 thinking 无关**,勿混)。

---

## §10 Compaction 窗口感知(真 bug 修复)

**现状 bug**(compaction 调研):`estimate.go:16` 调 `modelmeta.Lookup("","")` → 永远 fallback → **每个对话都按 usable=4000 token 压**,不管模型是 200K 还是 1M。`Calibrate`(吸收真实 usage token)建了但从未接线。

**修法**:
1. 把有效 `(provider, modelID)` 从 `runner.go:156`(`bc.Provider`/`bc.ModelID` 已在手)透传进 `MaybeCompact` → `estimate()`(扩 `ContextCompactor.MaybeCompact` 签名,chat/chat.go:94)。
2. `estimate.go:16` 的 `Lookup("","")` 换成 **modelcaps 查 catalog**(Ollama 用用户 num_ctx 而非理论上限)。
3. 阈值数学(Soft 0.70 / Hard 0.85)**零改**——usable 一对,"大窗晚压"自动成立。
4.(可选,正交)接线 `Calibrate(convID, result.TokensIn, estimate)` 让 char 启发式自校正。

---

## §11 测试策略(零-key 护栏)

- **L1 黄金线格式**:每 (provider, thinking 设置) 调 adapter `BuildRequest`,断言 JSON 字节对官方 curl(`03` 每节 golden 请求当夹具)。10 家全覆盖——补上现在"6 家共用 buildOpenAIBody、零 per-provider 断言"的缺口。
- **L2 httptest 回环**:本地假 server 返各家 golden SSE(含 reasoning/signature delta),`Request.BaseURL` 指过去,断言 `ParseStream` 对(抓 Gemini/Ollama base-url、各家 reasoning 字段差异)。
- **L3 Ollama 本地真飞**:`localhost:11434/v1`,gate `/api/tags`,`t.Skip` 兜底(遵 T3)。
- **pipeline**:`cross/` 加 thinking + 窗口-aware compaction 端到端;`errcodes/` 加新 sentinel sweep;`make matrix` 更新覆盖。

---

## §12 实施分期(建议给 plan)

- **P0 modelcaps 包**:家族规则表(`04`)+ Cap 类型 + 解析三层(先静态,实时读/override 后补)。吃掉 contextmgr/modelmeta。纯数据,解锁后续。
- **P1 三 bug + 黄金/httptest 骨架**(test-first):Gemini/Ollama/custom 钉成红→修绿。证明"都能跑"。
- **P2 Provider 接口重构**:infra/llm → N adapter,黄金测试护栏下做。Client 契约不变。
- **P3 thinking 端到端**:ModelRef+Config/Request+Bundle+finishResolve+per-adapter 编码+Anthropic signature+model_configs 列+handler+UpsertInput。
- **P4 能力端点 + 前端**:`/model-capabilities` GET(合并目录)+ PUT/DELETE(用户覆盖)+ hooks;`model_cap_overrides` 表 + `ResolveCapabilities` 合并(用户覆盖>实时读>静态);ModelDefaults capability-aware 控件 + 能力覆盖入口;onboarding 保持极简。
- **P5 compaction 窗口感知**:透传 model→MaybeCompact→modelcaps 查;(可选)接线 Calibrate。

每期独立可交付价值(原则 #1),依赖自下而上(#2)。

---

## §13 文档同步(§S14 + §F1)

涉及:`references/backend/domains/{model,chat,subagent,conversation,workflow}.md` + 新建 `modelcaps` 相关;`api-design.md`(新端点 + widened PUT)+ `database-design.md`(model_configs thinking 列)+ `error-codes.md`(新 sentinel);前端 `entity-types.md`(ModelRef/ModelConfig + capability 类型)+ `cross-cutting.md`(新 queryKey/hook)+ 对应 `references/frontend/slices/*`;`references/changelog.md` 全程;新规范进 `CLAUDE.md`。`04` 的窗口数据取代 `01` 零散提及。

---

## §14 风险 / 开放问题

- **版本漂移**:model 名月月变,本设计已用家族规则 + 实时读对冲;但实时读那 4 家的 API schema 也会变(Anthropic `capabilities` 是新的)——解析要容错、留静态兜底。
- **用户能力覆盖**:✅ **本期做**(用户定:单人项目跟不上月度更新时,手动覆盖是关键逃生口)。新表 `model_cap_overrides` + 合并 + 端点 + UI,在 P0(表+Apply)/P4(端点+UI)。范围克制:只覆盖 thinking 形状 + 窗口 + 输出上限三字段,可空。
- **Gemini native 切换工作量**:dedicated native adapter 比 compat 大(不同请求/响应 schema);P2 单列。compat base 修复(P1)先止血。
- **thinking 默认值**:每 scenario 的默认 thinking 设什么?倾向 `auto`(不发参数,模型自决,= 现状行为),用户显式调。
