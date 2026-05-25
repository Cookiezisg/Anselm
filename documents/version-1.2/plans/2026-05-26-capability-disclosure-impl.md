# 能力披露层重构 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 用 `superpowers:subagent-driven-development` 逐 task 执行(每 task 一个 fresh subagent + 两阶段 review)。步骤用 `- [ ]` 勾选跟踪。
> **权威设计源**:`capability-disclosure-design.md`(架构)+ `tool-rewrite-catalog.md`(64 工具 after 文本)。本计划只给执行顺序、TDD 步骤、关键代码与验证;具体工具文案以 catalog 为准。

**Goal:** 把 chat 一次请求的常驻 input 从 ~28k 降到 ~3.8k(且基本封顶),不改变 agent 能力与可见行为。

**Architecture:** 两层能力披露 —— catalog 统一「报菜名」(对象层)+ tools 常驻28/长尾6组按需 `activate_tools`(动作层);横切 `injectStandardFields` 去重 + Anthropic prompt caching。执行引擎/trigger_workflow 已存在(app/scheduler),本计划不碰。

**Tech Stack:** Go,4 层 clean arch,modernc sqlite,zap,Anthropic 原生 + OpenAI-compat LLM 客户端。测试 `make test-backend`(in-memory SQLite)+ `staticcheck ./...`。

**纪律:** 每 task 跑 `make test-backend` + `cd backend && go build ./... && staticcheck ./...`;`make verify` 在收尾跑。commit 全做完、测试绿后统一(投资人可见 main,不推半成品)。

---

## 依赖图

```
T1 去重 ──┐
T2 tool_conventions ──┤(T1 的长文案落点)
T3 InvokeTool 接口 ──┐
T4 补 source ────────┤
T5 mechanical 报菜名 ─┘
T6 AgentState 激活集 ─┐
T7 分组 + activate_tools ┤
T8 host.Tools(ctx)+loop ┘(核心,依赖 T6/T7)
T9 capabilities 段 (依赖 T5 菜单 + T7 分组)
T10 caching (独立)
T11-14 64 工具精简 (独立,依赖 T1 的壳约定)
T15 create/edit desc 参数约束 (依赖 T11-14)
T16 token 回归 + pipeline + 文档同步 (最后)
```

---

## Task 1 — injectStandardFields 去重

**Files:** Modify `backend/internal/app/tool/tool.go:80-145`、`backend/internal/app/tool/tool_test.go`

- [ ] **Step 1: 加失败测试** — 在 tool_test.go 加断言:注入后三字段仍在(壳),但每个 description ≤ 120 字符(证明长文案已移走)。

```go
func TestInjectStandardFields_DescriptionsAreSlim(t *testing.T) {
	params := json.RawMessage(`{"type":"object","properties":{"path":{"type":"string"}},"required":["path"]}`)
	result := injectStandardFields(params)
	var schema map[string]json.RawMessage
	json.Unmarshal(result, &schema)
	var props map[string]json.RawMessage
	json.Unmarshal(schema["properties"], &props)
	for _, f := range []string{"summary", "destructive", "execution_group"} {
		var field struct{ Description string `json:"description"` }
		json.Unmarshal(props[f], &field)
		if len(field.Description) > 120 {
			t.Errorf("%s description too long (%d chars); long text must live in tool_conventions", f, len(field.Description))
		}
	}
}
```

- [ ] **Step 2: 跑测试确认失败** — `cd backend && go test ./internal/app/tool/ -run TestInjectStandardFields_DescriptionsAreSlim` → FAIL(现 description ~290/~520 字符)。

- [ ] **Step 3: 改 injectStandardFields** — 三字段保留极简壳(不移出 schema,避免 LLM 不再传):

```go
	props["summary"] = json.RawMessage(`{"type":"string","description":"One sentence: what you're doing and why."}`)
	props["destructive"] = json.RawMessage(`{"type":"boolean","default":false,"description":"true if this call may be irreversible; see tool_conventions."}`)
	props["execution_group"] = json.RawMessage(`{"type":"integer","minimum":1,"description":"Parallel-batch id; see tool_conventions."}`)
```
保留三个 conflict-panic 检查、summary 入 required 的逻辑不变。`StripStandardFields` 不动。

- [ ] **Step 4: 跑测试** — `go test ./internal/app/tool/` → 全 PASS(旧测试因字段仍在而通过,新测试因 description 变短而通过)。

- [ ] **Step 5: commit** — `git add -A && git commit -m "refactor(tool): slim injectStandardFields — move standard-field guidance to tool_conventions"`

---

## Task 2 — tool_conventions system prompt 段

**Files:** Modify `backend/internal/app/chat/runner.go`(const + SystemPromptSections)、`runner_test.go`

- [ ] **Step 1: 加失败测试** — SystemPromptSections 应含一段 name="tool_conventions",内容覆盖 destructive/execution_group 语义。

- [ ] **Step 2: 跑测试确认失败**。

- [ ] **Step 3: 实现** — runner.go 加 const + 在 SystemPromptSections 里 base 之后插入:

```go
const toolConventionsSection = `Every tool call accepts three standard fields:
- summary (required): one sentence on what you're doing and why.
- destructive (optional): true if the call may be irreversible (delete, force-push, writes to external state); the user sees a warning.
- execution_group (optional, int): calls sharing a group run in parallel; different groups run in ascending order. Group only calls with no interdependence and no shared state. Omit when unsure.`
```
在 `out = append(out, PromptSection{Name: "base", ...})` 之后 append `{Name: "tool_conventions", Content: toolConventionsSection}`。导出 `ToolConventionsText()` 给 §18 inventory(对齐 BasePromptText 模式)。

- [ ] **Step 4: 跑测试** → PASS。
- [ ] **Step 5: commit** — `refactor(chat): add tool_conventions prompt section (standard fields, once)`

---

## Task 3 — CatalogSource.InvokeTool() 接口

**Files:** Modify `backend/internal/domain/catalog/source.go`;5 个 `internal/app/*/catalog_source.go`(function/handler/skill/mcp/document)

- [ ] **Step 1:** source.go 给 `CatalogSource` 接口加 `InvokeTool() string`(该类实体的调用工具名)。
- [ ] **Step 2:** 各 source 实现:function→`"run_function"`、handler→`"call_handler"`、skill→`"activate_skill"`、mcp→`"call_mcp_tool"`、document→`"read_document"`。
- [ ] **Step 3:** `cd backend && go build ./...` → 编译过(接口新方法全实现)。
- [ ] **Step 4: commit** — `feat(catalog): CatalogSource.InvokeTool() — entity-to-tool mapping for menu`

---

## Task 4 — 补 workflow / document catalog source 注册

**Files:** Create `backend/internal/app/workflow/catalog_source.go`;Modify `cmd/server/main.go:410-413`

- [ ] **Step 1: 失败测试** — `test/` 下加断言:catalog 含 workflow + document 条目(harness 建一个 workflow + document 后 catalog.Get 应见到)。
- [ ] **Step 2: 实现** — 照 `function/catalog_source.go` 写 `workflow/catalog_source.go`(Name="workflow",Granularity=PerItem,InvokeTool="trigger_workflow",ListItems 取 workflowService.ListAll)。main.go 加两行:`catalogService.RegisterSource(workflowService.AsCatalogSource())` + `catalogService.RegisterSource(documentService.AsCatalogSource())`。
- [ ] **Step 3:** `make test-backend` → PASS。
- [ ] **Step 4: commit** — `fix(catalog): register workflow + document sources (were missing from menu)`

---

## Task 5 — catalog mechanical 报菜名 + 截断

**Files:** Modify `backend/internal/app/catalog/mechanical.go`、`mechanical_test.go`

- [ ] **Step 1: 失败测试** — assemble 输出每行格式 `- name [invokeTool]: desc`;desc 截断到 ≤48 字符;空库返回 ""。
- [ ] **Step 2: 实现** — assemble 用 `gMap`/source 的 InvokeTool 渲染 `### <source> [<invokeTool>]` + `- **name**: <truncate(desc,48)>`;加 `truncate` helper。
- [ ] **Step 3:** `go test ./internal/app/catalog/` → PASS。
- [ ] **Step 4: commit** — `feat(catalog): mechanical menu — name + [invoke tool] + truncated desc`

---

## Task 6 — AgentState 激活集

**Files:** Create `backend/internal/pkg/agentstate/toolset.go`;`toolset_test.go`

- [ ] **Step 1: 失败测试** — ActivateGroup("forge") 后 ActivatedGroups() 含 "forge";去重;并发安全(仿 skill_test.go)。
- [ ] **Step 2: 实现** — 仿 `agentstate/skill.go` 的 mutex 模式:`activatedGroups map[string]bool` + `groupMu sync.Mutex` + `ActivateGroup(cat string)` + `ActivatedGroups() []string`(加到 AgentState struct)。
- [ ] **Step 3:** `go test ./internal/pkg/agentstate/` → PASS。
- [ ] **Step 4: commit** — `feat(agentstate): per-conversation activated tool-group set`

---

## Task 7 — 工具分组 + activate_tools 工具

**Files:** Create `backend/internal/app/tool/toolset/toolset.go`(或在 chat 内)、`activate_tools` 工具;Modify `cmd/server/main.go`、`chat.go SetTools`

- [ ] **Step 1: 失败测试** — activate_tools 工具:ValidateInput 拒绝非枚举 category;Execute 从 ctx 取 AgentState、调 ActivateGroup、返回该组工具名列表。
- [ ] **Step 2: 实现** —
  - 定义 `Toolset{ Resident []Tool; Lazy map[string][]Tool }`;按 §4.3 名单分组(常驻 28 / 长尾 function/handler/workflow/mcp/document/skill)。
  - 新 `activate_tools` 工具:`category` enum[function,handler,workflow,mcp,document,skill];Execute 调 `agentstatepkg.From(ctx).ActivateGroup(category)`,返回 `已加载 <category>: tool1, tool2…`。常驻。
  - chat.Service 改持 Toolset(`SetToolset`),保留 SetTools 兼容或替换。
- [ ] **Step 3:** `make test-backend` → PASS。
- [ ] **Step 4: commit** — `feat(tool): activate_tools meta-tool + resident/lazy grouping`

---

## Task 8 — host.Tools(ctx) + loop 每轮重算(核心)

**Files:** Modify `backend/internal/app/loop/loop.go`、`internal/app/chat/host.go`+`chat.go`、`internal/app/scheduler/dispatch_agent.go`、`internal/app/subagent/host.go`、`test/harness/harness.go`;`loop`+`chat` 测试

- [x] **Step 1: 失败测试** — loop 测试:step 1 调 activate_tools{handler} → step 2 的 req.Tools 含 edit_handler(step 1 不含),fake `llminfra.Client` 脚本驱动 + 真 `ActivateTools` tool;chat host 测试:无激活只 Resident,激活 function 后含 create_function 不含 edit_handler。
- [x] **Step 2: 实现** —
  - `loop.Host.Tools()` 改 `Tools(ctx context.Context) []toolapp.Tool`(三处实现:chatHost / agentHost / subagentHost)。
  - `chatHost.Tools(ctx)`:返回 `resident + 各 ActivatedGroups(ctx) 组`;无 AgentState 只返 resident。读 `s.toolset`,删除 stored-but-unread 的 `s.tools` 字段 + 未被调用的 `chat.Service.SetTools`。
  - loop.Run:删循环外 `baseReq.Tools = ...` + 循环外 byName;改为循环内每轮 `tools := host.Tools(ctx); req.Tools = ToLLMDefs(tools); byName := toolsByName(tools)`(byName 与本步 offer 集一致)。
  - agentHost / subagentHost 用固定预过滤切片,签名忽略 ctx。
- [x] **Step 3:** `make test-backend` → PASS;`staticcheck ./...` 触及文件零新增。
- [x] **Step 4: commit** — `feat(loop): on-demand tools — host.Tools(ctx) by activated groups + per-step recompute`

---

## Task 9 — capabilities system prompt 段(替换 catalog 段)

**Files:** Modify `backend/internal/app/chat/runner.go` SystemPromptSections;`runner_test.go`

- [ ] **Step 1: 失败测试** — capabilities 段含「工具组索引(function/handler/workflow/mcp/document/skill + 大小 + activate_tools 提示)」+ 资产菜名(取 catalog.GetForSystemPrompt)。
- [ ] **Step 2: 实现** — 把现有 `catalog` 段替换为 `capabilities` 段:静态工具组索引(来自 Toolset 的 Lazy keys+counts)+ 动态资产菜名(catalog 文本)。排在 tool_conventions 后。
- [ ] **Step 3:** `make test-backend` → PASS。
- [ ] **Step 4: commit** — `feat(chat): capabilities section — tool-group index + asset menu`

---

## Task 10 — Anthropic prompt caching

**Files:** Modify `backend/internal/infra/llm/anthropic.go`;`anthropic_test.go`

- [ ] **Step 1: 失败测试** — 构造带 tools + system 的 Request,序列化后最后一个 tool / system 末块带 `cache_control:{"type":"ephemeral"}`。
- [ ] **Step 2: 实现** — toAnthropicTools 给末个 tool、system 段末尾打 `cache_control`。确认 OpenAI 路径不受影响(自动前缀缓存)。
- [ ] **Step 3:** `go test ./internal/infra/llm/` → PASS。
- [ ] **Step 4: commit** — `feat(llm): mark tools+system as ephemeral cache prefix (anthropic)`

---

## Task 11-14 — 64 工具 Description/Parameters 精简(按 family 分 4 批)

**权威文案:** `tool-rewrite-catalog.md`。**注意对齐 c743840 规范化后的 op keys**(dependencies / nodeId / edgeId / camelCase),catalog 里 create_* 的 op 文案若用旧 key 需改新 key。

- **T11** function(9)、**T12** handler(10)、**T13** workflow(8,trigger_workflow 已精简免改)+ document(7)、**T14** mcp(7)+ skill(4)+ filesystem/search/shell/web(10)+ todo/ask/memory/subagent(9)

每批:
- [ ] Step 1: 照 catalog 改各工具的 `Description()` 与 schema const;Subagent enum、status enum、删 ID 格式提示等结构改动一并做。
- [ ] Step 2: `go test ./internal/app/tool/<families>/` → PASS(schema 仍合法 JSON;现有工具测试不破)。
- [ ] Step 3: commit — `refactor(tool): slim <family> descriptions/schemas per catalog`

---

## Task 15 — create/edit 工具 description 参数约束

**Files:** Modify `function/create.go`、`handler/create.go`、`workflow/create.go`(+ edit_* 三个)的 schema 中 `description` 参数说明

- [ ] Step 1: 把这些工具 schema 里实体 `description` 参数的说明改成 `"One short line (~15 chars) shown in the capability menu; keep it terse."`
- [ ] Step 2: `make test-backend` → PASS。
- [ ] Step 3: commit — `refactor(tool): instruct create/edit to write terse entity descriptions`

---

## Task 16 — token 回归 + pipeline + 文档同步

**Files:** Create token 回归测试;Modify pipeline 测试;同步文档

- [ ] **Step 1: token 回归** — 新测试:新号一条 "Hello",计算 system prompt 文本 + 常驻 tools 的 ToLLMDefs 字节,断言 `< 6000 token`(防回归膨胀)。
- [ ] **Step 2: pipeline**(fake LLM,`test/`)— 场景A:不 activate,常驻工具作答;场景B:fake LLM 先 activate_tools("handler") → 下一轮可见 edit_handler 并调用成功。
- [ ] **Step 3:** `make test-backend` + `cd backend && go build ./... && staticcheck ./...` + `make verify` 全绿。
- [ ] **Step 4: 文档同步(§S14)** — `capability-disclosure-design.md` §4.4(极简壳方案)/§6(文件位置 runner.go)/工具数 66;`service-design-documents/catalog.md` + `chat.md`(activate_tools/capabilities/InvokeTool);`service-contract-documents/`(activate_tools 契约);`progress-record.md` dev log(含本次 + 修掉的 4 个审计 bug);`CLAUDE.md` §S18 若 Tool 注册模式变。
- [ ] **Step 5: commit** — `test+docs: token regression guard + capability-disclosure pipeline + §S14 sync`

---

## Self-review checklist(写完即查)
- 每个 design doc 改动点都有对应 task ✔
- 无 placeholder(代码片段或明确引用 catalog/design doc)
- 类型一致:`Tools(ctx)` 签名在 T8 统一;`InvokeTool()` 在 T3 定义、T4/T5 消费;`ActivateGroup`/`ActivatedGroups` 在 T6 定义、T7/T8 消费
- scope:仅 token 治理;不碰 app/scheduler 执行引擎
