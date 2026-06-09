# Round 0060 — M7 中央装配 ① 适配器层 + 工具工厂（composition root 上半）

类型 / 目标：波次 5 收官后，**M7 把孤岛焊成能跑的 app**。审计结论：后端内聚健康（依赖方向/Schema/零死代码/契约漂移全绿），唯一大缺口 = composition root 几乎空白（`cmd/server/main.go` 52 行壳）。M7 拆 2 段，本轮（R0060）= **填 DIP 洞**（~11 个跨 Service 适配器 + 工具工厂），R0061 = bootstrap 总装 + router + SSE + boot/shutdown。

**架构决策（DI 标准）**：适配器放 **`internal/bootstrap/`**（composition root 包，import 所有 app/infra，无人 import 它故无环）——**不**放各 provider 包（否则 model 包要 import chat 的 port 类型 → app→app 环）。`cmd/server/main.go` 收薄、调 bootstrap。

## 已验证签名（亲 grep，不靠 agent 转述）

**消费侧 4 个 Bundle（都包 `llminfra.Client`+`llminfra.Request`）**：
- `chatapp.Bundle{Client, Request, Caps ContentCapabilities{Vision,NativeDocs}, Provider}`；端口 `ModelResolver{ResolveChat(ctx,*modeldomain.ModelRef)(Bundle,error); ResolveUtility(ctx)(Bundle,error)}`
- `contextmgr.Bundle{Client, Request}`；端口 `UtilityResolver{ResolveUtility(ctx)(Bundle,error)}` + `WindowResolver{ContextBudget(ctx,provider,modelID)(window,maxOutput int)}` + `ConversationSummary{GetSummary(ctx,id)(string,int64,error); SetSummary(ctx,id,summary,coversUpToSeq)error}`
- `subagent.Bundle{Client, Request, Provider}`；端口 `ModelResolver{Resolve(ctx)(Bundle,error)}` + `ToolsProvider{Tools()[]toolapp.Tool}`
- `agentapp.LLMBundle{Client, Request}`；端口 `LLMResolver{ResolveAgent(ctx,*modeldomain.ModelRef)(LLMBundle,error)}` + `KnowledgeProvider{BuildKnowledgePrefix(ctx,docIDs)(string,error)}`；注入经 `SetInvokeDeps(InvokeDeps{Resolver,Tools func()[]Tool,Knowledge})`

**model→Client 解析链（keystone，4 resolver 共享）**：
1. `model.Resolve(ctx, scenario, override *ModelRef, picker ModelPicker) (ModelRef, error)`——override 优先否则 picker.Pick(scenario)。`ModelRef{APIKeyID, ModelID, Options map[string]string}`。scenario ∈ {dialogue, utility, agent}。`ModelPicker{Pick(ctx,scenario)(ModelRef,error)}` 由 **workspace.Service** 实现。
2. `apikey.Service.ResolveCredentialsByID(ctx, apiKeyID) (apikeydomain.Credentials{Provider, Key〔明文〕, BaseURL, APIFormat}, error)`。
3. `llm.Factory.Build(llm.Config{Provider, APIFormat, ModelID, Key, BaseURL}) (Client, baseURL string, error)`（provider "mock" 短路 MockClient）。`llm.NewFactory()`。
4. `llm.Request{ModelID, Key, BaseURL:baseURL, Options:ref.Options}`（Options map[string]string 直传；MaxTokens=0 让 provider 自填）。

**caps + window**：
- **【as-built 修订】**原计划：ModelInfo 无 Vision/NativeDocs（deferred），chat Caps 先填 false。**实际**：审计发现这让 attachment 多模态（R0051-53）哑掉 → 用户拍板「最干净彻底」，**轮中插入 model-caps**：`modelSpec`/`ModelInfo`/`CapabilityView` += `Vision`/`NativeDocs`（caps 进 provider 自描述 spec 表，与 ctx/out 同源；7 表 + gemini 逐项**查官网**填——anthropic/gemini=vision+docs、openai/kimi-k2.x=vision、deepseek/qwen/zhipu/doubao 列出文本旗舰=否）。
- **合并冗余**：原计划 windowResolver + capsResolver 两适配器各查目录 → 合成**一个 `ModelInfoLookup`**（`CapabilityService.List` 找 (provider,modelID)）：contextmgr 取 (ContextWindow, MaxOutput)、chat `Bundle.Caps` 取 (Vision, NativeDocs)；未知 → 零（contextmgr 跳过压缩 / chat 保守降级）。见 commit d41c3bb1 + contract #42。

## 11 适配器清单（R0060 全量）

| # | 适配器 | 满足端口 | 实现 |
|---|---|---|---|
| 1 | **modelResolver 核** | （内部） | picker+keys+factory → `resolve(ctx,scenario,override)→(Client,Request,provider,err)` |
| 2 | chatModelResolver | chat.ModelResolver | ResolveChat=resolve(dialogue,override)+Caps{f,f}；ResolveUtility=resolve(utility,nil) |
| 3 | contextmgrUtility | contextmgr.UtilityResolver | resolve(utility,nil)→contextmgr.Bundle |
| 4 | subagentResolver | subagent.ModelResolver | resolve(dialogue,nil)→subagent.Bundle |
| 5 | agentResolver | agent.LLMResolver | ResolveAgent=resolve(agent,override)→LLMBundle |
| 6 | conversationSummary | contextmgr.ConversationSummary | conversation.Service.Get(→Summary/水位) + SetSummary |
| 7 | windowResolver | contextmgr.WindowResolver | CapabilityService/DescribeModels 查 (window,maxOutput) |
| 8 | attachmentRenderer | chat.AttachmentRenderer | attachment.ToContentParts 桥 caps → []llminfra.ContentPart ✅ |
| 9 | documentRenderer | chat.DocumentRenderer | document ResolveAttached + RenderAttachedAsXML ✅ |
| 10 | knowledgeProvider | agent.KnowledgeProvider | document GetBatch + RenderAttachedAsXML ✅ |
| 11 | dispatcher | scheduler.Dispatcher | RunAction→fn RunFunction/hd Call/mcp CallTool；RunAgent→ag InvokeAgent；toResultMap 扁平 ✅ |
| 12 | refResolver | workflow.RefResolver | 7 实体 Service 扇出→RefInfo（catalog 纯菜单不能解析，改直查实体）✅ |

~~外加 **toolFactory**：把 17 个 tool 包各 New + 分 Resident/Lazy → `tool.Toolset`。~~ **→ 折进 R0061**（纯装配非 DIP 适配器、吃全 16 Service 只在 Build 存在；分层已查实：Resident=filesystem/search/shell，Lazy=function/handler/agent/control/approval/workflow/trigger/document/memory/mcp/skill）。

## 本轮增量（R0060-keystone，先 commit）

#1-7（model resolver 核 + 4 wrapper + ConversationSummary + WindowResolver）——签名全验证、最耦合的 P0 keystone，独立编译可测。`internal/bootstrap/resolvers.go` + `conversation.go` + `window.go`。
**续（同轮 as-built）✅**：#8-10 renderer（commit eff32afe）+ #11 Dispatcher（4b60b439）+ #12 RefResolver（da9c3031）——签名全亲验、各带测试、bootstrap 包全绿。**toolFactory 折进 R0061**（用户拍板：纯装配非 DIP 适配器〔无类型桥接，构造器已返 `[]Tool`、Toolset 即 `[]Tool`〕、吃全 16 Service〔只在 Build 存在〕、dynamic-mcp/subagent/filtering 三特例耦合 Build 上下文）。**R0060 收官于 keystone + model-caps + 3 适配器；composition-root 适配器层完成，余总装归 R0061。**

**#12 RefResolver 误称纠正**：原计划写「catalog 查 ref→RefInfo」——但 catalog 是**纯菜单**（domain doc 明示「刻意不带 id / 调用句柄」），不能解析。as-built 改为**直查 7 个实体 Service**（fn/hd/ag/ctl/apf/trigger/mcp），各取 ActiveVersionID + 各 kind 附加项（hd MethodNames / ag AgentCallables / ctl BranchPorts）。**版本无关实体（trigger/mcp）语义**：存在=可用 → `HasActiveVersion=true`、空 `ActiveVersionID`（pin 记空 no-op、CapabilityCheck 不误报 phantom 缺版本）——用户确认 trigger 有意无版本（新老后端皆无 version 字段 / trigger_versions 表）。Dispatcher 结果 `toResultMap`：JSON 对象直通扁平（model B `node.field`）/ 标量→`{text}`（doc 21 §157-159）。

测试：modelResolver（mock factory + fake picker/keys → 验 scenario 路由 + Bundle 形状）；conversationSummary 往返；windowResolver 命中/未命中(0,0)。

验证：gofmt/build ./.../vet/test 绿（+1 包 bootstrap）。

是否更干净（自证）：① 适配器集中 composition root（避 app→app 环，DI 标准）；② 一个 modelResolver 核 4 consumer 共享（不重复解析链）；③ 真实 ResolveCredentialsByID + factory.Build 链（agent runLoop 此前也只有端口、无真实现，M7 首次焊上）；④ caps/window 的延后/降级诚实（Vision/NativeDocs=false、window 取不到跳过）；⑤ bootstrap 包可测（非 package main）。

遗留 / 下一步：R0061 = bootstrap.Build() 总装（按依赖序构造 21 Service + 注入适配器 + SetRelationSyncer/SetInvokeDeps + catalog source + relation Namer）+ router（24 handler Register + middleware Chain）+ 3 SSE Bus 分发 + boot 序列（scheduler.Recover/DrainFirings/ticker、trigger.Start、handler/mcp.Boot、sandbox.Restore）+ graceful shutdown + cmd/server/main.go 收薄。审计揪出的 error-codes `chatdomain.*` 命名 drift 在 R0061 接 chat 时一并对账。
