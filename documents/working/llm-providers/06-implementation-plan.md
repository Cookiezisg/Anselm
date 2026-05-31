# LLM Provider Adapters + Thinking + Capability Catalog — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development(推荐)或 superpowers:executing-plans。步骤用 `- [ ]` 跟踪。
> **每个 task 执行前必读**:对应 provider 的精确字节夹具在 `03-implementation-reference.md`,家族规则在 `04-capability-catalog.md`,整体设计在 `05-design-spec.md`。本计划不重复抄那些字节(DRY)——task 里写 "用 03 §N 的 golden 请求" 即指那份精确内容,不是占位符。

**Goal:** LLM 层做成「每家完整 adapter + 能力目录 + thinking 三态」,修 3 个真 bug + compaction 一律按 4K 压的 bug,全程零-key 黄金测试护栏。

**Architecture:** 6 个构建阶段(非分期交付,连续一轮做完):P0 modelcaps 数据底座 → P1 三 bug 修复(test-first,现结构)→ P2 Provider 接口重构 + 每家黄金/httptest 测试 → P3 thinking 端到端 → P4 能力端点 + 前端 → P5 compaction 窗口感知。依赖严格自下而上。

**Tech Stack:** Go 1.25 / GORM / modernc sqlite;React 18 TS strict / FSD / TanStack Query;测试 `make unit` `make mock` `make web`,前端 vitest,`staticcheck ./...`。

> **诚实天花板**:无 key 下"无 bug"= 3 确认 bug 修掉 + 每家请求字节对官方 curl + 响应解析对 + DeepSeek/Ollama 真跑。其余 8 家是线格式级证明,非真飞。

---

## 文件结构(decomposition 锁定)

**新建**:
- `backend/internal/pkg/modelcaps/modelcaps.go` — Cap/Rule/CapOverride 类型 + 家族规则表 + Lookup + Apply(合并)
- `backend/internal/pkg/modelcaps/modelcaps_test.go`
- `backend/internal/domain/model/modelcapoverride.go` — `ModelCapOverride` 实体(`mco_` 前缀)+ 仓储接口
- `backend/internal/infra/store/modelcapoverride/modelcapoverride.go` — GORM store
- `backend/internal/app/apikey/capabilities.go` — `ResolveCapabilities`(静态⊕实时读⊕用户覆盖)+ override CRUD
- `backend/internal/infra/llm/provider.go` — Provider 接口 + 注册表
- `backend/internal/infra/llm/transport.go` — 共享铁律(http do / SSE 扫描 / sanitize 复用)
- `backend/internal/infra/llm/{openai,deepseek,anthropic,gemini,qwen,zhipu,moonshot,doubao,openrouter,ollama,custom}.go` — 每家完整 adapter(openai.go/anthropic.go 现存,重构)
- `backend/internal/infra/llm/golden/<provider>_golden_test.go` — 每家黄金线格式 + httptest 回环
- `backend/internal/transport/httpapi/handlers/capabilities.go` — `GET /model-capabilities` + `PUT/DELETE /model-capabilities/{provider}/{modelId}`(用户覆盖)
- `frontend/src/entities/model-config/model/capability.ts` — capabilityFor selector + 类型

**修改(关键)**:
- `backend/internal/domain/model/model.go` — ModelRef +Thinking, ModelConfig +Thinking 列
- `backend/internal/pkg/llmclient/llmclient.go` — Bundle +Thinking, finishResolve 透传
- `backend/internal/infra/llm/llm.go` — Request +Thinking;`factory.go` — Config +APIFormat 用上, Build 改走 Provider 注册表
- `backend/internal/domain/apikey/apikey.go` — Credentials +APIFormat
- `backend/internal/app/apikey/{apikey.go,providers.go,tester.go}` — 3 bug
- `backend/internal/app/contextmgr/{estimate.go,contextmgr.go}` + 删 `modelmeta.go`
- `backend/internal/app/chat/chat.go` + `runner.go` — MaybeCompact 签名带 model
- `backend/internal/transport/httpapi/handlers/model.go` — PUT body +thinking
- `backend/internal/app/workflow/apply.go` — 节点 override 抽取带 thinking
- 前端:`ModelDefaultsSection.tsx`、`ModelOverrideEditor.tsx`、`WorkflowEditor.tsx`+`useWorkflowEdit.ts`、`entities/model-config` & `entities/conversation` types、`shared/api/queryKeys.ts`

---

# P0 — modelcaps 数据底座

### Task P0.1: Cap/Rule 类型 + 家族规则表

**Files:** Create `backend/internal/pkg/modelcaps/modelcaps.go`, `..._test.go`

- [ ] **Step 1: 写失败测试** —— `modelcaps_test.go`

```go
package modelcaps

import "testing"

func TestLookup_DeepSeekV4_ToggleEffort1M(t *testing.T) {
	c := Lookup("deepseek", "deepseek-v4-pro")
	if c.ContextWindow != 1_000_000 { t.Fatalf("window=%d want 1M", c.ContextWindow) }
	if c.Thinking != ShapeEffort { t.Fatalf("shape=%v want effort", c.Thinking) }
}

func TestLookup_ClaudeOpus48_AdaptiveEffort1M(t *testing.T) {
	c := Lookup("anthropic", "claude-opus-4-8")
	if c.ContextWindow != 1_000_000 { t.Fatalf("window=%d", c.ContextWindow) }
	if c.Thinking != ShapeEffort { t.Fatalf("shape=%v want effort(adaptive)", c.Thinking) }
}

func TestLookup_Sonnet45_200K_Budget(t *testing.T) {
	c := Lookup("anthropic", "claude-sonnet-4-5")
	if c.ContextWindow != 200_000 { t.Fatalf("window=%d want 200K", c.ContextWindow) }
	if c.Thinking != ShapeBudget { t.Fatalf("shape=%v want budget", c.Thinking) }
}

func TestLookup_Unknown_Fallback(t *testing.T) {
	c := Lookup("deepseek", "totally-new-model-2099")
	if c.ContextWindow == 0 { t.Fatal("fallback must give a nonzero window") }
}
```

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `cd backend && go test ./internal/pkg/modelcaps/ -run TestLookup -v`
Expected: FAIL（包/符号未定义）

- [ ] **Step 3: 实现 modelcaps.go** —— 类型 + 全 11 provider 家族规则表(数值/形状逐条照抄 `04 §1` 的表;每行一个 Rule;最具体前缀优先)

```go
// Package modelcaps is the per-(provider,model) capability catalog: context
// window + thinking-knob shape, as durable family-pattern rules.
//
// Package modelcaps 是 per-(provider,model) 能力目录:上下文窗口 + thinking
// 形状,按抗漂移的家族前缀规则组织。吃掉原 contextmgr/modelmeta。
package modelcaps

import "strings"

type ThinkingShape int

const (
	ShapeNone ThinkingShape = iota
	ShapeEffort   // reasoning_effort / thinkingLevel / reasoning.effort
	ShapeBudget   // thinking.budget_tokens / thinkingBudget / thinking_budget
	ShapeToggle   // thinking:{type:enabled/disabled}
)

type Cap struct {
	ContextWindow int           // 输入窗口 token(Ollama = 用户 num_ctx)
	MaxOutput     int
	Thinking      ThinkingShape
	EffortValues  []string      // ShapeEffort 时合法值
	BudgetMin     int
	BudgetMax     int
	ContextMode   string        // "" | "qwen_max_input" | "ollama_num_ctx"
}

type rule struct {
	provider string
	prefix   string // model-id 前缀,小写
	cap      Cap
}

// rules: 最具体 prefix 在前,Lookup 取首个匹配。数值见 04-capability-catalog.md §1。
var rules = []rule{
	// Anthropic（代际边界 4.6）
	{"anthropic", "claude-opus-4-7", Cap{1_000_000, 128_000, ShapeEffort, []string{"low", "medium", "high"}, 0, 0, ""}},
	{"anthropic", "claude-opus-4-8", Cap{1_000_000, 128_000, ShapeEffort, []string{"low", "medium", "high"}, 0, 0, ""}},
	{"anthropic", "claude-opus-4-6", Cap{1_000_000, 128_000, ShapeEffort, []string{"low", "medium", "high"}, 0, 0, ""}},
	{"anthropic", "claude-sonnet-4-6", Cap{1_000_000, 64_000, ShapeEffort, []string{"low", "medium", "high"}, 0, 0, ""}},
	{"anthropic", "claude-sonnet-4", Cap{200_000, 64_000, ShapeBudget, nil, 1024, 64_000, ""}}, // 含 -4-5
	{"anthropic", "claude-haiku-4", Cap{200_000, 64_000, ShapeBudget, nil, 1024, 64_000, ""}},
	{"anthropic", "claude-opus-4", Cap{200_000, 64_000, ShapeBudget, nil, 1024, 64_000, ""}}, // -4/-4-1/-4-5
	{"anthropic", "claude", Cap{200_000, 32_000, ShapeBudget, nil, 1024, 32_000, ""}},          // 兜底
	// OpenAI
	{"openai", "gpt-5.5", Cap{1_000_000, 128_000, ShapeEffort, []string{"none", "low", "medium", "high", "xhigh"}, 0, 0, ""}},
	{"openai", "gpt-5.2", Cap{400_000, 128_000, ShapeEffort, []string{"none", "low", "medium", "high", "xhigh"}, 0, 0, ""}},
	{"openai", "gpt-5.1", Cap{400_000, 128_000, ShapeEffort, []string{"none", "low", "medium", "high"}, 0, 0, ""}},
	{"openai", "gpt-5", Cap{400_000, 128_000, ShapeEffort, []string{"minimal", "low", "medium", "high"}, 0, 0, ""}},
	{"openai", "o", Cap{200_000, 100_000, ShapeEffort, []string{"low", "medium", "high"}, 0, 0, ""}}, // o1/o3/o4
	{"openai", "gpt-4", Cap{128_000, 16_000, ShapeNone, nil, 0, 0, ""}},
	// DeepSeek
	{"deepseek", "deepseek-v4", Cap{1_000_000, 384_000, ShapeEffort, []string{"high", "max"}, 0, 0, ""}},
	{"deepseek", "deepseek-reasoner", Cap{128_000, 64_000, ShapeEffort, []string{"high", "max"}, 0, 0, ""}},
	{"deepseek", "deepseek", Cap{128_000, 64_000, ShapeNone, nil, 0, 0, ""}},
	// Gemini（2.5=budget / 3.x=effort）
	{"google", "gemini-2.5-pro", Cap{1_048_576, 65_536, ShapeBudget, nil, 128, 32_768, ""}},
	{"google", "gemini-2.5-flash-lite", Cap{1_048_576, 65_536, ShapeBudget, nil, 0, 24_576, ""}},
	{"google", "gemini-2.5-flash", Cap{1_048_576, 65_536, ShapeBudget, nil, 0, 24_576, ""}},
	{"google", "gemini-2.5", Cap{1_048_576, 65_536, ShapeBudget, nil, 0, 32_768, ""}},
	{"google", "gemini-3", Cap{1_000_000, 64_000, ShapeEffort, []string{"minimal", "low", "medium", "high"}, 0, 0, ""}},
	{"google", "gemini", Cap{1_000_000, 64_000, ShapeEffort, []string{"minimal", "low", "medium", "high"}, 0, 0, ""}},
	// Qwen（bool enable_thinking + budget;开 thinking 强制 stream → 用 ShapeBudget 表 budget 维 + ContextMode）
	{"qwen", "qwen3-max", Cap{262_144, 32_768, ShapeBudget, nil, 0, 81_920, ""}},
	{"qwen", "qwen-long", Cap{10_000_000, 32_768, ShapeNone, nil, 0, 0, ""}},
	{"qwen", "qwen-turbo", Cap{1_000_000, 16_384, ShapeBudget, nil, 0, 38_912, "qwen_max_input"}},
	{"qwen", "qwen", Cap{1_000_000, 32_768, ShapeBudget, nil, 0, 81_920, "qwen_max_input"}},
	// 智谱 GLM（toggle）
	{"zhipu", "glm-4.6", Cap{200_000, 128_000, ShapeToggle, nil, 0, 0, ""}},
	{"zhipu", "glm-4.5", Cap{131_072, 96_000, ShapeToggle, nil, 0, 0, ""}},
	{"zhipu", "glm", Cap{200_000, 128_000, ShapeToggle, nil, 0, 0, ""}},
	// Moonshot Kimi（toggle / model-id）
	{"moonshot", "kimi-k2-thinking", Cap{262_144, 32_768, ShapeToggle, nil, 0, 0, ""}},
	{"moonshot", "kimi-k2", Cap{262_144, 32_768, ShapeToggle, nil, 0, 0, ""}},
	{"moonshot", "moonshot-v1-128k", Cap{131_072, 32_768, ShapeNone, nil, 0, 0, ""}},
	{"moonshot", "moonshot-v1-32k", Cap{32_768, 32_768, ShapeNone, nil, 0, 0, ""}},
	{"moonshot", "moonshot-v1", Cap{8_192, 32_768, ShapeNone, nil, 0, 0, ""}},
	// Doubao（1.6=budget / 1.8+=effort）
	{"doubao", "doubao-seed-1-8", Cap{256_000, 64_000, ShapeEffort, []string{"no_think", "low", "medium", "high"}, 0, 0, ""}},
	{"doubao", "doubao-seed-2", Cap{256_000, 64_000, ShapeEffort, []string{"no_think", "low", "medium", "high"}, 0, 0, ""}},
	{"doubao", "doubao-seed-1-6", Cap{256_000, 16_000, ShapeBudget, nil, 0, 32_768, ""}},
	{"doubao", "doubao", Cap{256_000, 16_000, ShapeBudget, nil, 0, 32_768, ""}},
	// OpenRouter / Ollama 主要走实时读;静态兜底:
	{"openrouter", "", Cap{128_000, 32_000, ShapeEffort, []string{"none", "low", "medium", "high"}, 0, 0, ""}},
	{"ollama", "", Cap{4_096, 0, ShapeEffort, []string{"none", "low", "medium", "high"}, 0, 0, "ollama_num_ctx"}},
}

var fallback = Cap{ContextWindow: 32_768, MaxOutput: 8_192, Thinking: ShapeNone}

// Lookup returns the capability for (provider, modelID) by most-specific
// prefix; falls back to a conservative default when unknown.
//
// Lookup 按最具体前缀返回能力;未知时给保守兜底。
func Lookup(provider, modelID string) Cap {
	id := strings.ToLower(modelID)
	for _, r := range rules {
		if r.provider != provider {
			continue
		}
		if r.prefix == "" || strings.HasPrefix(id, r.prefix) {
			return r.cap
		}
	}
	return fallback
}
```

- [ ] **Step 4: 跑测试确认 PASS**

Run: `cd backend && go test ./internal/pkg/modelcaps/ -v && staticcheck ./internal/pkg/modelcaps/`
Expected: PASS;staticcheck 干净

- [ ] **Step 5: Commit**

```bash
git add backend/internal/pkg/modelcaps/
git commit -m "feat(modelcaps): per-(provider,model) capability catalog with family rules"
git push origin main
```

> 注:实时读(Anthropic/Gemini/OpenRouter/Ollama)overlay 留到 P4 增量加(ResolveCapabilities 内);P0 立静态规则 + 用户覆盖(P0.2)。`modelmeta` 的删除在 P5 完成(此刻并存,无冲突)。

### Task P0.2: 用户能力覆盖(表 + Apply 合并 + ResolveCapabilities)

**Files:** Create `domain/model/modelcapoverride.go`、`infra/store/modelcapoverride/modelcapoverride.go`、`app/apikey/capabilities.go`;Modify `modelcaps.go`(+CapOverride+Apply)、`cmd/server/main.go`(AutoMigrate + 装配)、`CLAUDE.md §S15`(+`mco_` 前缀)

- [ ] **Step 1: 写失败测试** —— ① `modelcaps_test.go`:`Apply(base, &CapOverride{Thinking:&shapeNone})` 只盖 Thinking、窗口仍来自 base;nil overlay 原样返回。② `modelcapoverride` store 测试:Upsert→Get round-trip(in-memory sqlite,T2)。③ `capabilities_test.go`:`ResolveCapabilities` 对有 override 的 (provider,model) 返合并值、无 override 返静态规则值。
- [ ] **Step 2:** Run `cd backend && go test ./internal/pkg/modelcaps/ ./internal/infra/store/modelcapoverride/ ./internal/app/apikey/ -run 'Apply|Override|ResolveCapabilities' -v` → FAIL
- [ ] **Step 3: 实现** ——
  - `modelcaps.go` 加 `type CapOverride struct { Thinking *ThinkingShape; ContextWindow, MaxOutput *int }` + `func Apply(base Cap, o *CapOverride) Cap`(o 非空字段盖 base,o=nil 返 base)。
  - `domain/model/modelcapoverride.go`:`ModelCapOverride{ID(mco_), UserID, Provider, ModelID, ThinkingShape *string, ContextWindow *int, MaxOutput *int, timestamps, deleted_at}` + gorm `uniqueIndex` on (user_id,provider,model_id) + 仓储接口 `Upsert/Get/List/Delete`。
  - `infra/store/modelcapoverride`:GORM 实现(UserID-scoped,软删,§D1/D2/D5)。
  - `app/apikey/capabilities.go`:`ResolveCapabilities(ctx, provider, modelID) modelcaps.Cap` = `modelcaps.Apply(modelcaps.Lookup(provider, modelID), overrideStore.Get(...))`(实时读 overlay 占位,P4 填);+ `SetOverride/ClearOverride/ListCapabilities`。
  - `main.go`:`db.AutoMigrate(&ModelCapOverride{})` + 装配 store→capabilities service。`§S15` 加 `mco_`。
- [ ] **Step 4:** Run → PASS;`make unit` 绿;`staticcheck ./...`
- [ ] **Step 5:** Commit `feat(modelcaps): user capability override (table + Apply merge + ResolveCapabilities)` + push

---

# P1 — 三个真 bug(test-first,现结构)

### Task P1.1: Gemini base-url 404

**Files:** Modify `backend/internal/app/apikey/providers.go:43`;Test `backend/internal/app/apikey/apikey_test.go`(或新建 resolve 测试)

- [ ] **Step 1: 写失败测试** —— ResolveCredentialsByID 对空 base 的 google key 应给带 `/v1beta/openai` 的 base(或给空让 adapter 默认接管)。断言 resolved base **不等于** 裸 `https://generativelanguage.googleapis.com`。
- [ ] **Step 2:** Run `cd backend && go test ./internal/app/apikey/ -run TestResolve.*Gemini -v` → FAIL
- [ ] **Step 3: 实现** —— `providers.go:43` google 的 `DefaultBaseURL` 改为 `"https://generativelanguage.googleapis.com/v1beta/openai"`(与 adapter.go:40 一致);确认 `tester.go` 的 google list-models 测试端点与运行时一致(若不一致一并对齐)。
- [ ] **Step 4:** Run 同上 → PASS;`make unit` 绿
- [ ] **Step 5:** Commit `fix(apikey): gemini base-url missing /v1beta/openai → chat 404` + push

### Task P1.2: Ollama base-path 矛盾

**Files:** Modify `backend/internal/app/apikey/tester.go:248`;Test 同包

- [ ] **Step 1: 写失败测试** —— `testOllamaTags` 对 base=`http://x:11434/v1` 应打到 `http://x:11434/api/tags`(剥 `/v1`),不是 `…/v1/api/tags`。用 httptest server 断言收到的 path。
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3: 实现** —— tester 拼 tags 前 `base = strings.TrimSuffix(base, "/v1")`;chat 路径(openai client)不变(用户填 `…/v1`)。
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** Commit `fix(apikey): ollama base-path — strip /v1 before /api/tags` + push

### Task P1.3: custom anthropic-compatible 死路(APIFormat 透传)

**Files:** Modify `domain/apikey/apikey.go:51`(Credentials +APIFormat)、`app/apikey/apikey.go`(ResolveCredentials* 填充)、`pkg/llmclient/llmclient.go:120`(finishResolve 透传 Config.APIFormat);Test `internal/infra/llm/factory_test.go` 或 llmclient 测试

- [ ] **Step 1: 写失败测试** —— 一个 provider=custom、APIFormat=anthropic-compatible 的 key 经 ResolveCredentialsByID → finishResolve → factory.Build 应得到 anthropic client(不是 openai)。断言走 anthropic 线。
- [ ] **Step 2:** Run → FAIL（APIFormat 丢失 → 落 openai）
- [ ] **Step 3: 实现** —— `Credentials` 加 `APIFormat string`;`ResolveCredentials` + `ResolveCredentialsByID` 拷 `k.APIFormat`;`finishResolve` 建 Config 时带 `APIFormat: creds.APIFormat`。
- [ ] **Step 4:** Run → PASS;`make unit` 绿
- [ ] **Step 5:** Commit `fix(llmclient): thread APIFormat to factory — custom anthropic-compat was dead` + push

> P1 完:`make unit` + `make mock` 全绿。3 个确认坏的 provider 路径修通(Gemini/Ollama/custom)。

---

# P2 — Provider 接口重构 + 每家黄金测试

> 这是最大块。**每个 provider 一个 task**:实现完整 adapter + 该家黄金线格式测试(L1)+ httptest 回环(L2)。字节/形状照 `03-implementation-reference.md` 对应节。先做接口+transport+DeepSeek 范例,再逐家。

### Task P2.0: Provider 接口 + transport 铁律 + 注册表

**Files:** Create `provider.go`、`transport.go`;Modify `factory.go`(Build 改走注册表)、`llm.go`(Request +Thinking 占位字段,先不填语义)

- [ ] **Step 1:** 写测试 —— 注册表能按 provider 名返回对应 Provider;未知 provider 返 openai 兜底。
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3: 实现** —— `Provider` 接口(见 05 §4)、`registry map[string]Provider`、`transport.go` 抽出共享 `doHTTP`/`scanSSE`(含跳 `:` 注释行)/复用 `SanitizeMessages`;`factory.Build` 改为查注册表得 Provider、保留 `Client` 包装兼容现有调用方。
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** Commit `refactor(llm): Provider interface + shared transport + registry` + push

### Task P2.1–P2.11: 逐家 adapter + 黄金测试

对以下每家,一个 task,5 步(写黄金测试→FAIL→实现 adapter→PASS→commit)。**夹具 = `03-implementation-reference.md` 对应节的 golden 请求 + SSE**:

- [ ] **P2.1 DeepSeek**(范例,最先做)—— `deepseek.go` + golden(03 §3)。L1 断言 BuildRequest JSON == 03 §3 golden 请求;L2 httptest 返 03 §3 SSE,断言 reasoning_content 先于 content 解析。reasoning_content 回传规则(普通轮剥/tool 轮留)。
- [ ] **P2.2 OpenAI** —— `openai.go`(03 §2);max_completion_tokens、推理模型禁 temperature。
- [ ] **P2.3 Anthropic** —— `anthropic.go`(03 §4);native /v1/messages、system 顶层、tool_result 排序、signature 解析(thinking 回传留 P3)、max_tokens 去硬编码。
- [x] **P2.4 Gemini(native)**(R4 交付)—— `gemini.go` `geminiProvider` 走 `streamGenerateContent?alt=sse`(model 在 URL 路径)+ `x-goog-api-key`;BuildRequest 映射 contents(user→user/assistant→model/tool→user+functionResponse)、systemInstruction、tools.functionDeclarations、generationConfig.thinkingConfig(on→budget+includeThoughts / off→budget:0 / auto→省略);ParseStream 解析 thought:true parts(带 thoughtSignature→EventReasoning.Signature)、functionCall(完整 args 一次 emit)、usageMetadata(candidates+thoughts 合计 OutputTokens)。base 改 `…/v1beta`(`providers.go` + `tester.go` 探针归约到 `/v1beta/models`);删 compat shim + `encodeThinkingGeminiCompat`/`encodeThinkingOpenAI`。functionResponse 按函数名(从前序 tool_call 反查)+id 配对。
- [ ] **P2.5 Qwen** —— `qwen.go`(03 §6);flat error envelope `{code,message}` 解析。
- [ ] **P2.6 Zhipu GLM** —— `zhipu.go`(03 §7);tool_choice 只 auto、finish_reason sensitive/network_error。
- [ ] **P2.7 Moonshot** —— `moonshot.go`(03 §8);reasoning_content(下划线)、双路 thinking。
- [ ] **P2.8 Doubao** —— `doubao.go`(03 §9);顶层 thinking、/models 不探(硬编码)。
- [ ] **P2.9 OpenRouter** —— `openrouter.go`(03 §10);跳 `:` 心跳行、reasoning_details。
- [ ] **P2.10 Ollama** —— `ollama.go`(03 §11);/v1 reasoning(无下划线)、base-path、带工具不强制关 stream。
- [ ] **P2.11 custom** —— `custom.go`;按 APIFormat 委托 openai/anthropic builder。

每家 commit `feat(llm): <provider> full adapter + golden/httptest tests` + push。

> P2 完:`make unit` 全绿;10 家请求字节对官方文档、响应解析对(零 key)。`make mock` 绿。

---

# P3 — thinking 端到端

### Task P3.1: ThinkingSpec 类型 + ModelRef 第三维

**Files:** Modify `domain/model/model.go`(ModelRef +Thinking, ModelConfig +Thinking 列)

- [ ] **Step 1:** 写测试 —— ModelRef JSON round-trip 带 thinking;空 thinking = nil(向后兼容)。
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** 加 `ThinkingSpec{Mode, Effort string; Budget int}`(扁平,05 §5);ModelRef +`Thinking *ThinkingSpec json:"thinking,omitempty"`;ModelConfig +`Thinking *ThinkingSpec gorm:"serializer:json"` 列。
- [ ] **Step 4:** Run → PASS;`make unit`(AutoMigrate 加列幂等)
- [ ] **Step 5:** Commit `feat(model): ModelRef/ModelConfig gain ThinkingSpec` + push

### Task P3.2: Bundle + Config + Request 透传 thinking

**Files:** Modify `pkg/llmclient/llmclient.go`(Bundle +Thinking, finishResolve 透传)、`infra/llm/llm.go`(Request.Thinking 已占位,语义接上)

- [ ] **Step 1:** 写测试 —— ResolveDialogueWithOverride 带 thinking 的 override → Bundle.Thinking 非空 → 传入 Request.Thinking。
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** Bundle +`Thinking *modeldomain.ThinkingSpec`;finishResolve 从 override/config 取 thinking 塞 Bundle;dispatchers/runner 建 Request 时带上。
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** Commit `feat(llmclient): thread ThinkingSpec through Bundle→Request` + push

### Task P3.3–P3.5: 各 adapter thinking 编码(按家族分组)

- [ ] **P3.3 effort 家族** —— openai/gemini-3/openrouter/deepseek/ollama/doubao-1.8 的 BuildRequest 把 `Request.Thinking`(经 modelcaps 判形状)编码成各自 effort 字段。黄金测试加 "thinking on" 变体。
- [ ] **P3.4 budget 家族** —— anthropic/gemini-2.5/qwen/doubao-1.6;Anthropic budget<max_tokens 守卫 + Opus4.7/4.8 走 adaptive;Qwen 开 thinking 强制 stream。
- [ ] **P3.5 toggle 家族** —— glm/kimi `thinking:{type}`。
每组 commit + push。

### Task P3.6: Anthropic signature 全链路

**Files:** Modify `anthropic.go`(解析 signature_delta、回传带 signature)、loop/history 相关

- [ ] **Step 1:** 写测试 —— 工具循环中 assistant thinking 块带 signature 原样回传;缺则该测试模拟 400。
- [ ] **Step 2-4:** 解析 signature_delta → 存 reasoning 块 → 重放带回。
- [ ] **Step 5:** Commit `feat(llm/anthropic): signature round-trip for extended thinking + tools` + push

### Task P3.7: PUT /model-configs + workflow op 带 thinking

**Files:** `handlers/model.go`(body+UpsertInput)、`app/model/model.go`(Upsert 拷)、`app/workflow/apply.go:357`(直接用已 parse 的 ref)

- [ ] 5 步 TDD;Commit `feat(api): model-config + node override carry thinking` + push

> P3 完:thinking 端到端可设可发;`make unit`+`make mock` 绿;黄金测试覆盖每家 thinking-on 变体。

---

# P4 — 能力端点 + 前端

### Task P4.1: /model-capabilities 端点(GET 合并目录 + PUT/DELETE 覆盖)+ 实时读 overlay

**Files:** Create `handlers/capabilities.go`;Modify router、`app/apikey/capabilities.go`(填 P0.2 占位的实时读 overlay)

- [ ] 5 步 TDD ——
  - `GET /model-capabilities` 返 `ListCapabilities`(静态⊕实时读⊕用户覆盖;provider→model→{thinking 形状, window, contextMode})。
  - `PUT /model-capabilities/{provider}/{modelId}` → `SetOverride`(body 可空 thinking_shape/context_window/max_output)→ 200;`DELETE` → `ClearOverride` → 204。
  - `capabilities.go` 填实时读 overlay:4 家(Anthropic `/v1/models`、Gemini `models.get`、OpenRouter `/api/v1/models`、Ollama `/api/show`)复用 tester.go probe helpers,容错(读不到回落静态)。
  - Commit `feat(api): /model-capabilities GET+PUT+DELETE + live overlay` + push

### Task P4.2: 前端 entity 类型 + capability hook

**Files:** `entities/model-config/model/types.ts`(ModelConfig/UpsertModelConfigBody +thinking 扁平 {mode,effort?,budget?};+Capability/CapOverride 类型)、`entities/conversation/model/types.ts`(ModelRef +thinking)、`model-config/api/model-config.ts`(+useModelCapabilities/+useSetModelCapabilityOverride/+useClearModelCapabilityOverride)、`model/capability.ts`(capabilityFor)、`shared/api/queryKeys.ts`(+modelCapabilities)

- [ ] vitest TDD;Commit + push

### Task P4.3: ModelDefaultsSection thinking 控件

**Files:** `features/settings/ui/ModelDefaultsSection.tsx`(+thinking 第三行,capability 决定 slider/枚举/toggle;换 model reset thinking;Qwen/Ollama 条件显 context-mode)

- [ ] vitest TDD(扩现有 ModelDefaultsSection.test.tsx);Commit + push

### Task P4.4: ModelOverrideEditor + WorkflowEditor thinking

**Files:** `features/conversation-model-override/ui/ModelOverrideEditor.tsx`、`features/workflow-edit/ui/WorkflowEditor.tsx` + `model/useWorkflowEdit.ts`(**modelOverrideEq 必须比 thinking**)

- [ ] vitest TDD;Commit + push

### Task P4.5: 能力覆盖 UI(跟不上更新时的逃生口)

**Files:** `features/settings/ui/`(新小组件 `ModelCapOverrideEditor.tsx` 或并入展开卡)

- [ ] vitest TDD —— 当前选中 model 旁一个「覆盖能力」入口:改 thinking 形状(none/effort/budget/toggle)+ 窗口 + 输出上限,调 `useSetModelCapabilityOverride`;「恢复默认」调 clear。改完 ModelDefaults/override 控件即按新形状渲染(`capabilityFor` 走合并目录)。Commit `feat(settings): per-model capability override UI` + push

> Onboarding **不改**(保持极简,05 §9)。testend ModelConfigs.tsx 若 thinking 列做了可顺带加(可选)。
> P4 完:`make web` + `make lint-frontend` 绿;`wails dev` 冒烟看 settings 卡 + 覆盖入口。

---

# P5 — compaction 窗口感知 + 删 modelmeta

### Task P5.1: MaybeCompact 带 model + 查 modelcaps

**Files:** Modify `app/chat/chat.go:94`(ContextCompactor.MaybeCompact 签名 +provider,model)、`app/chat/runner.go:156`(传 bc.Provider/bc.ModelID)、`app/contextmgr/estimate.go:16`(换 modelcaps.Lookup)、删 `app/contextmgr/modelmeta.go`

- [ ] **Step 1: 写失败测试** —— estimate 对 claude-sonnet-4-5 给 usable≈181K(200K−maxout−buffer),不是 4000。
- [ ] **Step 2:** Run `cd backend && go test ./internal/app/contextmgr/ -v` → FAIL（现在永远 4000）
- [ ] **Step 3: 实现** —— 签名加 `(provider, modelID string)`;compactor 经 DIP 注入 `capResolver func(provider, modelID) modelcaps.Cap`(main.go 接到 `app/apikey.ResolveCapabilities`,**所以用户覆盖/Ollama num_ctx 自动生效**,且 contextmgr 不反向依赖 app/apikey);`estimate.go:16` 改用 `m.capResolver(provider, modelID)` 取 ContextWindow/MaxOutput;删 modelmeta.go + 其 import。
- [ ] **Step 4:** Run → PASS;`make unit`+`make mock` 绿
- [ ] **Step 5:** Commit `fix(contextmgr): window-aware compaction via modelcaps (was 4K for all)` + push

### Task P5.2(可选): 接线 Calibrate

- [ ] runner 把 `result.TokensIn` 喂 `compactor.Calibrate(convID, tokensIn, estimate)` 让 char 启发式自校正。Commit + push

> P5 完:大窗模型晚压;Ollama 按 num_ctx 不溢出。

---

# 收尾

### Task FINAL: 全量验证 + 文档同步

- [ ] `make verify`(vet×5 + build×5 + lintprompts + matrix audit + pipeline mock 全绿)
- [ ] `make web` + `make lint-frontend` 绿
- [ ](若有 key)`make live` DeepSeek;本地 `make` Ollama smoke
- [ ] 文档同步(§S14+§F1,05 §13):service-design / api-design / database-design / error-codes / 前端 entity-types / cross-cutting / 各 design doc / progress-record；`make matrix`
- [ ] Commit `docs: sync for provider adapters + thinking + modelcaps` + push

---

## R1-R5 后续重构说明（2026-05-30）

P2 的初始结果是「一个共享 `openAICompatProvider` + per-provider `beforeRequest`/`thinkingEncoder` 钩子」。R1-R5 对此做了彻底重构：

- **每个 provider 完全自包含**：openai / deepseek / qwen / zhipu / moonshot / doubao / openrouter / ollama / custom 各自持有完整 `BuildRequest`（含 thinking 编码）和 `ParseStream`，逻辑写到各家官方 API 标准，无共享 mega-builder 依赖。
- **Gemini 原生化**：`google` 迁移到原生 `generateContent` provider（gemini.go），替代 OpenAI-compat 垫片；reasoning-text readback + thoughtSignature round-trip（03 §5）。
- **共享 `openAICompatProvider` 已删除**：struct、`newOpenAICompatProvider`、`beforeRequest`/`thinkingEncoder` 钩子字段、`deepseekBeforeRequest` 包级函数全部删除；`transport.go` 只保留 HTTP/SSE 铁律。
- **测试已同步**：原依赖 `newOpenAICompatProvider` 的 golden 测试改用 `newOpenAIProvider()`；deepseekBeforeRequest 单元测试改驱动 `deepseekProvider.BuildRequest` 直接验证 wire body；staticcheck U1000 无报告。

---

## Self-Review

**Spec 覆盖**:05 §3 modelcaps(三层含用户覆盖)→P0.1+P0.2;§4 Provider→P2;§5 thinking→P3;§6 三 bug→P1;§7 DB(含 model_cap_overrides 表)→P0.2+P3.1+P3.7;§8 API(含 /model-capabilities GET+PUT+DELETE)→P3.7+P4.1;§9 前端(含覆盖 UI)→P4(P4.1-P4.5);§10 compaction(用户覆盖经注入 resolver 生效)→P5;§11 测试→P2 黄金/httptest 贯穿。✅ 无遗漏。
**Placeholder**:per-provider 字节用 "03 §N golden" 引用(精确内容存在,非占位);adapter 逐家 task 化。
**类型一致**:ThinkingSpec 扁平 {Mode,Effort,Budget} 后端;前端 {mode,effort?,budget?} 一致(05 §9 已统一);modelcaps.Cap.Thinking=ShapeXxx 贯穿 P0→P3 adapter 选形。
