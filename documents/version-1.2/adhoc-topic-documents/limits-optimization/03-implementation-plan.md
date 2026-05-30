# 03 — 实施计划(P0–P3)

> **For agentic workers:** REQUIRED SUB-SKILL: `superpowers:subagent-driven-development` 或 `superpowers:executing-plans`。步骤用 `- [ ]` 跟踪。
> **每个 task 执行前必读**:对应裁决与"为什么"在 [`01-optimize-decisions.md`](./01-optimize-decisions.md)(§①–⑤);可配项的存储/UI 在 [`02-advanced-settings-ui.md`](./02-advanced-settings-ui.md);原则在 [`00`](./00-overview.md)。

**Goal:** 把桶 3 的不合理 hardcode 优化掉,统一到「高 ceiling + 诚实失败态 + 用户可中断 + 真实信号驱动」,并把可调项做成前端「高级能力」区。顺带修 5 个真 bug。

**Architecture:** 4 阶段,**先止血→再诚实→再换机制→最后配置化**,依赖自下而上。P0 零行为契约变更(只止截断/崩溃);P1 改失败态契约;P2 换超时/历史机制;P3 settings 往返 + 注入 + 前端 + live overlay。

**Tech Stack:** Go 1.25 / GORM / modernc sqlite;React 18 TS strict / FSD / TanStack Query。测试 `make unit` `make mock` `make web` `make lint-frontend`,`staticcheck ./...`,发布门禁 `make verify`(含 5 平台 vet+build + matrix audit)。

> **每阶段收尾**:`cd backend && go build ./... && staticcheck ./...` + `make unit` + `make mock` 绿;改了 errcode/endpoint/event 跑 `make matrix`;按各 task 的 doc-sync 同步文档 + `progress-record.md` dev log(§S14/§F1)。

---

## 文件结构(decomposition)

**新建**
- `backend/internal/infra/settings/limits.go` — `Limits` 结构 + `DefaultLimits` + 填充/校验(P3)
- `backend/internal/transport/httpapi/handlers/settings.go` — `GET/PUT /settings/limits`(P3)
- `frontend/src/entities/settings/api/{useLimits,useUpdateLimits}.ts` + `model/types.ts` 加 `Limits`(P3)
- `frontend/src/features/settings/ui/AdvancedCapabilitiesSection.tsx`(P3)
- `frontend/src/i18n/locales/{zh,en}/settings.json` 加 `advanced.*`(P3)

**修改(关键)**
- `infra/llm/transport.go`(SSE buffer P0;idle-timeout P2)、`anthropic.go`(兜底 P0;thinking P1;SSE buffer P0)、`gemini.go`(thinking P1)、`provider.go`(idle reset P2)
- `pkg/modelcaps/modelcaps.go`(兜底 MaxOutput P0)
- `app/tool/function/{search.go,get_execution.go,search_executions.go}`、`handler/{search.go,get_call.go}`、`mcp/search.go`、`skill/search.go`(top-N P0;truncateJSON P0;get_* 统一 P0)
- `domain/chat/chat.go`(`StopReasonMaxSteps` P1)、`app/loop/loop.go`(失败态 P1)、`app/chat/runner.go`+`history.go`(maxSteps/turn 读注入 P3;history 200→2000 P2)
- `app/contextmgr/estimate.go`(nil-resolver WARN P1)
- `app/scheduler/retry.go`(节点超时 P2)、`dispatch_agent.go`(workflow 例外失败态 P1)
- `infra/handler/client.go`+`domain/handler/method.go`(RPC timeout P2)
- `app/mcp/mcp.go`(CallTool 超时 P2)
- `app/subagent/spawn.go`(StopReason 映射 P1)
- `cmd/server/main.go`(注入 limits getter P3)
- 前端:`SettingsModal`、`shared/api/queryKeys.ts`、`app/sse`/chat 页(撞顶「继续」按钮 P1)

---

# P0 — 止血(零行为契约变更,直接止截断/崩溃)

### Task P0.1: SSE 单行 buffer 抬高(bug #3)
**Files:** `infra/llm/transport.go`、`anthropic.go`
- [ ] 加 `const maxSSELineBytes = 8 << 20`(命名常量,8MB)
- [ ] `scanSSELines` 与 `parseAnthropicSSE` 的 `bufio.NewScanner` 后加 `sc.Buffer(make([]byte, 0, 64*1024), maxSSELineBytes)`
- [ ] 测试:喂一条 >64KB 的 `data:` 行,断言流不 abort、事件完整解析
- [ ] Verify:`make unit`(llm 包)+ `staticcheck`

### Task P0.2: 输出兜底 8192/8096 → 64000(§②)
**Files:** `pkg/modelcaps/modelcaps.go`、`infra/llm/anthropic.go`
- [ ] `modelcaps.go:131` fallback `MaxOutput 8192 → 64000`(`ContextWindow 32768` 不变)
- [ ] `anthropic.go:21` `anthropicDefaultMaxTokens 8096 → 64000`
- [ ] golden/modelcaps 测试更新断言
- [ ] Verify:`make unit`

### Task P0.3: `truncateJSON` 修非法 JSON(bug #2)
**Files:** `app/tool/function/search_executions.go`(helper 源)+ 7 处调用
- [ ] 抽一个共享 helper:截**结构内字符串值**保 envelope 合法,或明确以纯文本 snippet 返回并标 `truncated:true`
- [ ] 7 处(function/handler/workflow/mcp/skill 的 search_executions + function/handler 的 get_*)改用
- [ ] 测试:断言所有预览/详情输出是合法 JSON 或明确纯文本
- [ ] Verify:`make unit` + `make mock`

### Task P0.4: search top-N 抬高(§④)
**Files:** `tool/function/search.go`、`handler/search.go`、`mcp/search.go`、`skill/search.go`
- [ ] function/handler:默认 `3→10`,最多 `5→50`
- [ ] mcp 默认 `5→10`;skill 默认 `3→8`(max 不变)
- [ ] 测试:>10 候选时返回数符合新默认
- [ ] Verify:`make mock`

### Task P0.5: `get_*_execution` 去语义截断 + 统一(§④)
**Files:** `tool/function/get_execution.go`、`handler/get_call.go`(+ workflow/mcp/skill 对齐)
- [ ] function/handler 的 `4096B` 截断 → 改为统一 `256KB` 防御上限;超出按 JSON 边界优雅截 + 附 `offset`/取回提示
- [ ] 5 个 `get_*_execution` 统一策略(workflow/mcp/skill 已不截 → 加同一 256KB 上限)
- [ ] Verify:`make mock`

**P0 收尾**:`go build ./... && staticcheck ./...`、`make unit`、`make mock` 绿。Doc-sync:`forge_redesign/08-executions.md §7.1`(预览/详情策略)+ `service-design-documents/{function,handler}.md` + `progress-record.md`(`[opt] P0 止血`)。

---

# P1 — 诚实失败态(改终止契约)

### Task P1.1: 循环撞顶不再谎报(bug #1,§①)
**Files:** `domain/chat/chat.go`、`app/loop/loop.go`、`app/subagent/spawn.go`、`app/scheduler/dispatch_agent.go`、前端 chat 页
- [ ] `domain/chat/chat.go` 加 `StopReasonMaxSteps = "max_steps"`(进枚举/CHECK)
- [ ] `loop/loop.go:182` 步数耗尽:写**非成功终态**(`StatusIncomplete` 新增,或复用 `StatusError`)+ `stop_reason=max_steps` + errCode `MAX_STEPS_REACHED`;不再冒充 `max_tokens`/`completed`
- [ ] `subagent/spawn.go:167` 映射切到新 `StopReasonMaxSteps`(已有 `StatusMaxTurns`,清理冒充)
- [ ] `dispatch_agent.go`:workflow agent 节点撞顶 → flowrun 节点 `failed`/`incomplete`(**例外:cap 保留**,但失败态诚实)
- [ ] 前端:撞顶**大声提示** + 一键「继续」(带历史重入,= re-enqueue)
- [ ] 测试:`make mock` 造步数耗尽场景,断言状态非 `completed`、stop_reason=`max_steps`
- [ ] Doc-sync:`chat.md` + `subagent.md` + `error-codes.md`(`MAX_STEPS_REACHED`)+ `errcodes/sweep_pipeline_test.go` 加 case + `// covers:` + `make matrix`;`frontend-design-documents/feature-chat`(继续按钮)

### Task P1.2: 模型自报 hit max_tokens → surface(§②缺口)
**Files:** `app/loop/loop.go`、`app/loop/stream.go`
- [ ] `stop_reason==max_tokens`(模型真截断)时 emit 通知/UI 徽章;可选 auto-continue ≤2 轮("从中断处继续")
- [ ] 测试:fake LLM 返回 `max_tokens` finish,断言 surface
- [ ] Doc-sync:`chat.md`、`progress-record.md`

### Task P1.3: 压缩 nil-resolver 告警(bug #5)
**Files:** `app/contextmgr/estimate.go`、`cmd/server/main.go`/`harness`
- [ ] `capFor == nil` 时 WARN 日志 + 启动断言(防 200K/1M 模型按 32K 压)
- [ ] Verify:`make unit`(contextmgr)

### Task P1.4: thinking budget 修(bug #4,§②)
**Files:** `infra/llm/anthropic.go`、`gemini.go`
- [ ] Anthropic:去掉 `8192` thinking 顶(从 `BudgetMax` 派生);**Opus 4.7/4.8 走 adaptive `effort`,不发手填 `budget_tokens`**
- [ ] Gemini:fallback `8192 → -1`(动态)
- [ ] golden 测试更新
- [ ] Verify:`make unit`(llm)

**P1 收尾**:同上 + `make matrix`(新 errcode)。Doc-sync:`chat.md`/`subagent.md`/`compaction.md`/`error-codes.md`/`api-design.md`(若状态码涉及)+ `progress-record.md`(`[opt] P1 诚实失败态`)。

---

# P2 — 换机制(超时 / 历史)

### Task P2.1: LLM 120s 总墙钟 → idle-timeout(§⑤,最关键)
**Files:** `infra/llm/transport.go`、`provider.go`
- [ ] `newSharedHTTPClient`:`Timeout = 0`;`Transport = &http.Transport{ DialContext:(&net.Dialer{Timeout:10s,KeepAlive:30s}).DialContext, TLSHandshakeTimeout:10s, ResponseHeaderTimeout:60s }`
- [ ] `providerClient.Stream`(provider.go:38-56)包 idle guard:`timer := time.AfterFunc(idle, cancel)`,每 `range ParseStream` 事件 `timer.Reset(idle)`;`idle` 读注入(默认 100s,见 P3)
- [ ] 测试:httptest 模拟"持续吐 token 但总时长 >120s"→ 不被 kill;"开流后静默 >idle"→ 被 cancel
- [ ] Doc-sync:**新建** `llm-providers/` 流式超时设计注 + `progress-record.md`

### Task P2.2: `maxHistoryMessages` 去语义边界(§③)
**Files:** `app/chat/history.go`
- [ ] `200 → 2000`(纯 I/O 上限)+ 注释说明"语义边界由 token 预算 + compaction 负责,这只是防一次性读爆"
- [ ] 测试:`make mock` 造 >200 消息对话,断言早期 user 轮次经 summary 仍在 context(不被盲砍)
- [ ] Doc-sync:`chat.md`、`compaction.md`

### Task P2.3: scheduler 节点默认超时(§⑤)
**Files:** `app/scheduler/retry.go`
- [ ] `defaultTimeouts`:llm/function/handler/skill/mcp → `0`(不强加,靠 ctx + 节点自身传输);**http 保 30s**;approval 7d 不变
- [ ] 测试:长跑 function 节点(>60s)在无显式 `NodeSpec.Timeout` 时不被 scheduler kill
- [ ] Doc-sync:`scheduler.md`(或 `service-design-documents` 对应)

### Task P2.4: handler RPC 实现 `MethodSpec.Timeout`(§⑤)
**Files:** `infra/handler/client.go`、`domain/handler/method.go`
- [ ] `doCall`:`spec.Timeout>0` 才 `ctx, cancel = WithTimeout(...)`;`0`=无(改 method.go:22 注释:0=无 Go cap,靠 ctx/用户)
- [ ] 超时映射 `ErrInstanceRPCTimeout` + `CallStatusTimeout`(均已存在);streaming 方法按 `MsgProgress` idle reset
- [ ] 测试:hang 的 mock 方法在 `Timeout>0` 时返 timeout
- [ ] Doc-sync:`handler.md`、`error-codes.md`(确认 `ErrInstanceRPCTimeout` 已登记)

### Task P2.5: mcp CallTool 超时 + warm/cold 可恢复
**Files:** `app/mcp/mcp.go`、`app/loop/history.go`
- [ ] `defaultCallTimeout 30s → 180s`(读注入,可配)
- [ ] `projectToolResultContent`:warm/cold 占位符塞 `block.<id>`("full result at block …, fetch to retrieve")
- [ ] Doc-sync:`mcp.md`、`compaction.md`

**P2 收尾**:`make unit` + `make mock` + `make sandbox`(handler RPC 涉及真 sandbox)+ `staticcheck`。`progress-record.md`(`[opt] P2 换机制`)。

---

# P3 — 配置化 + 优雅化(settings 往返 + 注入 + 前端 + live overlay)

### Task P3.1: 后端 `Limits` + read/write 端点(§[`02`](./02-advanced-settings-ui.md))
**Files:** `infra/settings/limits.go`、`infra/settings/settings.go`、`transport/httpapi/handlers/settings.go`、router/deps
- [ ] `Limits` 结构 + `DefaultLimits` + zero→默认 填充 + 校验
- [ ] `settings.Limits()` getter + `UpdateLimits(patch)` 原子写 `settings.json`(0600,watcher reload)
- [ ] `GET/PUT /api/v1/settings/limits`(envelope,camelCase,N6 upsert 200,非法 400)+ errmap
- [ ] 测试:`api/settings/settings_pipeline_test.go` happy + 非法;`// covers: GET|PUT /api/v1/settings/limits` + `make matrix`
- [ ] Doc-sync:`api-design.md` + `service-design-documents`(settings)+ `progress-record.md`

### Task P3.2: 注入(DIP getter)到各消费方(§[`02`](./02-advanced-settings-ui.md) §2)
**Files:** `cmd/server/main.go`、`harness`、chat/loop/subagent/llm/contextmgr/scheduler/mcp/tool 各注入点
- [ ] 把 `func() Limits` getter 注入(沿用 `CapabilityResolver` 注入范式);各处把上面阶段写死的默认改读 getter
- [ ] 测试:改 limits 后下一 turn 即时生效(热重载)
- [ ] Verify:`make unit` + `make mock`

### Task P3.3: 前端「高级能力」区(§[`02`](./02-advanced-settings-ui.md) §3)
**Files:** `entities/settings/api/*` + `model/types.ts`、`features/settings/ui/AdvancedCapabilitiesSection.tsx`、`SettingsModal`、`shared/api/queryKeys.ts`、`i18n/locales/{zh,en}/settings.json`
- [ ] `useLimits`/`useUpdateLimits` + `Limits` 类型 + `qk.settingsLimits()`
- [ ] `AdvancedCapabilitiesSection`(默认折叠 + 警示 + 分组输入 + 单项/全部恢复默认),挂 SettingsModal 底部;组件零业务决策
- [ ] i18n `settings.advanced.*` 全量 zh/en
- [ ] Verify:`make lint-frontend`(eslint+tsc+steiger)+ `make test-frontend`
- [ ] Doc-sync:`frontend-prd.md §17` + `entity-types.md` + `cross-cutting.md` + `fsd-layers.md` + `frontend-design-documents/feature-settings.md`

### Task P3.4: live capability overlay 接通(§②,06-impl-plan P5.4)
**Files:** `app/apikey/capabilities.go`、各 provider `/models` 读取
- [ ] Anthropic `/v1/models`、Gemini `models.get`、OpenRouter `/api/v1/models`、Ollama `/api/show` 读真 `max_tokens`/window 叠加到 modelcaps(静态规则之上、user override 之下)
- [ ] 测试:gate `RequireDeepSeekKey` 式或 fake;`make unit`
- [ ] Doc-sync:`llm-providers/06-implementation-plan.md P5.4` 勾 ✅ + `04-capability-catalog.md`

### Task P3.5(可选): budget-based 终止 / Bash head+tail / per-conv 阈值
- [ ] 按需:per-turn token/cost 预算(Pydantic-AI/SDK 式)作为 maxSteps 的更优替代;Bash `capOutput` 改 head+tail 中段截
- [ ] 标记为后续增强,不阻塞 P0–P4

**P3 收尾**:`make verify`(5 平台 vet+build + lintprompts + matrix audit + mock)+ `make lint-frontend` + `make test-frontend` + `wails dev` 冒烟。Doc-sync 全量(上各 task)+ `CLAUDE.md`(若"限制可配"成为新规范,加一行)+ `progress-record.md`(`[opt] P3 配置化完工`)。

---

## 验证矩阵(每阶段门禁)

| 阶段 | 命令 |
|---|---|
| P0 | `go build ./... && staticcheck ./...` · `make unit` · `make mock` |
| P1 | 上 + `make matrix`(新 errcode) |
| P2 | 上 + `make sandbox`(handler RPC) |
| P3 | `make verify` · `make lint-frontend` · `make test-frontend` · `wails dev` 冒烟 |
