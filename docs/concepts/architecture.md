---
id: DOC-001
type: concept
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-02
review-due: 2026-09-01
audience: [human, ai]
---
# Backend 全新重写 — 契约优先 + 分层架构 + Agentic Workflow Platform

**创建于**：2026-04-22
**当前进度 / 开发日志**：[`docs/references/changelog.md`](../references/changelog.md)

**本文档定位**：**项目愿景 + 架构 + Phase 路线图**。**所有代码规范、工程纪律、设计原则、S/T 系列、工具纪律全部在项目根 [`CLAUDE.md`](../../CLAUDE.md)**。

---

## Strategy — 契约优先 + Durable Engine + Quadrinity 架构

1. **第一阶段 (已完成)**：地基与基础对话能力交付。
2. **第二阶段 (已完成)**：**Quadrinity (四项全能)** 架构确立。从单一的 Forge 域扩展为 Function, Handler, Workflow, Agent 四大能力支柱。
3. **第三阶段 (现状)**：**Durable Execution (持久化执行)** 引擎投产。引入 Durable Interpreter 和 Journal 机制，确保长流程任务的绝对可靠性。**当前重心转入前端**——按 [`frontend-prd.md`](./frontend-prd.md) + boilerplate 开发。

---

## 产品愿景

Forgify 目标是 **本地优先的 Agentic Workflow Platform**：用户通过自然语言编排工作流，工作流由多种专业节点构成，支持本地知识库挂载，由持久化执行引擎驱动运行。

### 核心能力清单

1. **意图识别 (Intent Routing)**：自动识别用户意图并分发至对应的功能模块。
2. **Durable Workflow 引擎**：基于 **Journal (流水账)** 的确定性重放引擎，支持跨进程重启、节点级重试与人工审批。
3. **5 核心节点模型**：收敛编排复杂度。支持 Trigger (信号)、Agent (决策)、Tool (执行)、Case (分支) 和 Approval (审批) 节点。
4. **本地文档库**：Notion-style 树状结构。通过 XML 注入实现 **LLM-ranked attach (无 RAG)**，充分利用本地大模型窗口优势。
5. **MCP 集成**：原生支持 Model Context Protocol，第三方能力即插即用。
6. **自动化调度**：支持 Cron 定时、文件变动 (fsnotify) 及 Webhook 物理材化触发。
7. **Quadrinity 锻造**：用户可自主编写 Function (无状态)、Handler (有状态)、Agent (智能体) 及 Workflow。

### 业界对标

| 产品 | 对标的能力 |
|---|---|
| **Dify** | 工作流 + 知识库 + Agent |
| **Coze** | Bot + 工作流 + 插件 / Skill |
| **Temporal** | 可靠的 Durable Execution 状态机 |
| **Langflow** | 可视化 LLM pipeline |

定位：**桌面版 + 中文场景优化** — 在锻造工具 + 离线运行上做差异化。

### LLM 客户端策略

Eino 框架已完全移除。改用完全自有的 `infra/llm` 包。

| 能力 | 方案 |
|---|---|
| LLM 流式客户端 | 自有 `infra/llm`（openai.go + anthropic.go + factory.go）|
| ReAct 循环 | `app/loop`（通用的共享引擎）；chat / subagent / Skill fork / workflow 节点都是调用方 |
| Tool 接口 | `app/tool/tool.go` 9 方法接口 + 标准字段注入（详见 CLAUDE.md §S18）|
| Workflow Engine | **Durable Interpreter**（ADR-016 自研实现）|
| Cron 调度 | `robfig/cron` |
| MCP 集成 | `modelcontextprotocol/go-sdk` v1.6 官方 SDK |
| Python 沙箱 | **PluginSandbox v2**（mise 嵌入式驱动）|

---

## Phase 路线图

**当前状态 / 任务细化** → [`docs/references/changelog.md`](../references/changelog.md)

| Phase | 主题 | 完成后产品形态 | 状态 |
|---|---|---|---|
| 0-1 | 地基 | 基础设施全就位 | ✅ 2026-04-23 |
| 2 | 基础对话 | ChatGPT 客户端 | ✅ 2026-04-25 |
| 3 | 工具锻造 | Trinity (Fn/Hd/Wf) 体验 | ✅ 2026-04-26 |
| 4 | 工作流 | **Durable Engine** + 13 类初始节点 | ✅ 2026-05-13 |
| 5 | 智能化与知识库| **Quadrinity** + Document + MCP + Memory | ✅ 2026-06-02 |
| 6 | 意图识别 | 终极版 Chat (意图 -> 工作流) | ⬜ 待开工 |

> Phase 6 原子切换（`backend-new/` → `backend/`）已在 Phase 2 收尾时内嵌完成（2026-04-25），不再单列。

### Phase 2 — 基础对话能力（已完成）

4 个 domain：`apikey`（凭证）+ `model`（场景 → provider/model 策略）+ `conversation`（对话 CRUD）+ `chat`（流式对话；Phase 2 时 `tools=nil`，Phase 3 起注入 system tools）。

**关键调用链**：
```
handler.SendMessage
  → chat.Send
      → model.PickForChat                       → (provider, modelID)
      → apikey.ResolveCredentials(provider)     → (key, baseURL)
      → llmFactory.Build(Config{...})           → llminfra.Client
      → buildHistory(ctx, convID, userMsgID)    → []LLMMessage
      → agentRun → client.Stream(Request)       → iter.Seq[StreamEvent] → SSE
```

### Phase 4 — 工作流与执行引擎 (Durable Engine)
完全自研的 **Durable Interpreter** (ADR-016) 取代了传统拓扑排序。支持回边循环、条件分支 (Skip Token 算法) 和分布式重放。
- **Journal 真相**：所有 Activity 结果记入 `flowrun_events` 表，支持断点“瞬移”恢复。
- **13 类节点**：涵盖 Trigger, Function, Handler, MCP, Skill, LLM, HTTP, Condition, Loop, Parallel, Approval, Wait, Variable。

### Phase 5 — 智能化、知识库与四项全能 (Quadrinity)
- **Quadrinity**：Agent 提升为一等公民实体，具备版本化 Prompt 和挂载能力。
- **Document**：Notion-style 树状文档库，支持 XML 注入实现 **LLM-ranked attach (无 RAG)**。
- **Memory**：跨对话长期事实库，支持 LLM 自管与用户 Pinned 策略。
- **Compaction**：自动摘要压缩算法，治理超长对话 Token 溢出。

### 跨 domain 协作图

```
                    ┌──────────────────┐
                    │ chat (智能编排)   │ ← Phase 6 终极
                    └────────┬─────────┘
              ┌──────────────┼──────────────┐
              ↓              ↓              ↓
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │ workflow │  │  quad-   │  │ document │  ← 中层"能力载体"
        └────┬─────┘  │  rinity  │  └────┬─────┘
             ↓        └────┬─────┘         ↓
        flowrun            │          子节点 tree
        scheduler          │          (Notion-style)
        trigger            │
                           ↓
                ┌──────────────────┐
                │ Agent / Function │
                │ Handler / Skill  │
                └──────────────────┘

       ┌─────────────────────────────────────────────────────┐
       │ 全程依赖：Phase 0-1 地基 + apikey / model / conversation│
       │ + crypto / events / db / logger / reqctx              │
       └─────────────────────────────────────────────────────┘
```

---

## 工程规范 → 见 CLAUDE.md

**所有代码规范、工程纪律、设计原则、契约宪法（N/D/E）、代码规范（S 系列）、测试规范（T 系列）、注释规范、包结构、包命名、文档同步纪律、开发期工具纪律——全部搬到项目根 [`CLAUDE.md`](../../CLAUDE.md)**。

理由：
- 单一事实源——规则改一处，避免 backend-design.md / CLAUDE.md 双份漂移
- Claude Code 自动加载 `CLAUDE.md` 进 context，确保代码改动时规则始终在线
- 本文件回归"项目说明书"定位（愿景、架构、Phase 路线、Verification），不再背规范

---

## Target Architecture (物理层级)

```
backend/
├── cmd/server/main.go              ← 入口，DI 组装
├── go.mod / go.sum
└── internal/
    ├── domain/                     ← 纯业务（无外部依赖）
    │   ├── agent/                  ← ✅ Agent 实体与 Version 规格 (Quadrinity)
    │   ├── apikey/                 ← ✅ 凭证加解密与 BYOK 路由
    │   ├── model/                  ← ✅ 场景 -> 模型分派策略
    │   ├── chat/                   ← ✅ Message + Block + Attachment (内容树)
    │   ├── function/               ← ✅ Function (无状态代码)
    │   ├── handler/                ← ✅ Handler (有状态类)
    │   ├── workflow/               ← ✅ 5 节点 DAG 规格 (CEL 驱动)
    │   ├── flowrun/                ← ✅ 执行实例与 Journal 模型 (ADR-018)
    │   ├── trigger/                ← ✅ 信号捕获与材化 (Inbox 模式)
    │   ├── ... (document, relation, memory, sandbox)
    │
    ├── app/                        ← Service 层 (协调层)
    │   ├── loop/                   ← ✅ 通用 ReAct 引擎 (Shared by Chat/Agent)
    │   ├── scheduler/              ← ✅ Durable Interpreter (ADR-016)
    │   ├── agent/                  ← ✅ Agent 管理与 Catalog 适配
    │   ├── chat/                   ← ✅ 对话管线与标题自动生成
    │   ├── function/               ← ✅ Function 生命周期与环境预热
    │   ├── handler/                ← ✅ Handler 实例管理与 RPC 驱动
    │   ├── workflow/               ← ✅ Workflow 锻造与 CEL 预编译
    │   ├── ...
    │
    ├── infra/                      ← 技术物理实现
    │   ├── db/                     ← ✅ modernc (纯 Go SQLite) + Journal 索引
    │   ├── store/                  ← ✅ 各领域实体持久化实现
    │   ├── llm/                    ← ✅ 自有 OpenAI/Anthropic 原生客户端
    │   ├── sandbox/                ← ✅ 嵌入式 Mise 与虚拟环境管理
    │   └── ...
```

`legacy/` 存放 V1.0/V1.1 的旧实现（Electron + Eino）作为参考。`testend/` 是开发期调试控制台（详见 [`testend-design.md`](./testend-design.md)）。

**依赖方向**：`transport → app → (domain ∪ infra/store)`、`infra/store → domain`（实现接口）、`infra/db → 标准库`、`domain` 不依赖任何人。

**`infra/db/` vs `infra/store/<domain>/` 的拆分**：
- `infra/db/` —通用 DB 底层（连接、迁移、schema_extras），与任何具体表无关
- `infra/store/<domain>/` —表相关的 CRUD（业务 aware），实现 `domain/<domain>.Repository`
- 同一个 domain 在 store 层的包名也叫 `<domain>`（如 `apikey`），调用方 import 时按 `<name><role>` 起别名（详见 CLAUDE.md §S13）

**类型策略**：domain 类型直接带 GORM tag（一份到底）；store 层不再做 entity↔row 转换。

**transport/httpapi 内部分层原则**：**稳定的（通用能力）和频繁变的（业务 handler）分开放**。
- `response/` `middleware/` 属于 HTTP 层框架级通用能力，写一次用很久
- `handlers/` 属于业务级代码，每加一个 feature 就新增/修改

> **`pagination/` 不在 httpapi 下**——cursor 编解码是与 HTTP 无关的纯工具，会被 `infra/store/*` 和 `transport/httpapi/handlers/*` 同时消费。把它放在 transport 下会迫使 store 层反向 import transport（破坏依赖方向 `transport → app → (domain ∪ infra/store)`），所以放在 `internal/pkg/pagination/`。

---

## 文档分册结构

本文件 + CLAUDE.md 是**稳定规范层**。其余按角色分三组：

| 文档 | 用途 | 推进节奏 |
|---|---|---|
| [`../../CLAUDE.md`](../../CLAUDE.md) | **代码规范、工程纪律、设计原则、契约宪法**——单一事实源 | 规则演化时改 |
| [`../references/backend/api.md`](../references/backend/api.md) | **全部 REST API 一眼索引** | 每 domain 开工时加一段 |
| [`../references/backend/database.md`](../references/backend/database.md) | **全部表一眼索引** | 同上 |
| [`../references/backend/error-codes.md`](../references/backend/error-codes.md) | **全部错误码一眼索引** | 同上 |
| [`../references/backend/events.md`](../references/backend/events.md) | **全部 SSE 事件一眼索引** | 涉及流式时加 |
| [`../references/backend/domains/<domain>.md`](../references/backend/domains/) | **每个 domain 详设计** | 每 domain 开工前写 |
| [`docs/references/changelog.md`](../references/changelog.md) | 开发日志 + 当前快照 + 任务清单 | 实时更新 |
| [`desktop-packaging-notes.md`](./desktop-packaging-notes.md) | 桌面端分发方向（Wails / 打包 / 常驻后台）| 大决策时改 |

**工作流**：
1. **开工前** → 填 `../references/backend/domains/<domain>.md` 详设计（含端到端推演 + 实现清单）
2. **实现中** → 同步更新 `../references/backend/*.md` 里该 domain 的索引段
3. **完成后** → 在 `docs/references/changelog.md` 加一行 dev log + 勾任务清单

---

## v1 平台支持声明

**全功能支持**：
- macOS arm64 / amd64 (System ≥ 10.15)
- Linux arm64 / amd64 (glibc based)
- Windows amd64 (10/11) — **Mise-embedded** 模式支持 Python/Node。

每平台 binary 通过 `go build` 单独构建。后端物理内嵌当前平台的 `mise` 二进制（~10MB），实现开箱即用的沙箱环境。

---

## Verification (审计与验证)

### 测试分级 (Axis)
1. **smoke**: 启动与地基冒烟。
2. **api**: 50+ 端点的物理 Round-trip。
3. **cross**: 跨域全链路 (Catalog / Interpreter / Subagent)。
4. **sse**: 三大流 (Eventlog / Notifications / Forge) 物理契约。
5. **lifecycle**: 真 Sandbox 环境同步与执行。
6. **errcodes**: 181 个 Sentinel 错误码全扫描。
7. **live**: 真实大模型烧 Token 测试。

### 覆盖矩阵 (2026-06-01 审计)
- **Total targets**: 450 (API + Errors + SSE + Seams)
- **Covered**: 89 (20%) — *当前重心在功能补完，覆盖率随版本稳步提升*。
- **准则**: 文档落后于代码实现即视为 Bug。发现不符立即停工修文档。

### 性能基准
- 流式对话 token latency < 旧版 110%
- 工具列表加载 < 500ms
- 工具搜索通过 LLM 排序，响应取决于上游 LLM（Phase 5 重新加 FTS5 时再加本地搜索基准）

### Schema 完整性
- `PRAGMA foreign_key_check` 零返回
- `PRAGMA integrity_check` 返回 `ok`

### 跨平台编译（modernc.org/sqlite 迁移后）
- `GOOS=darwin GOARCH=arm64 go build ./cmd/server`
- `GOOS=linux GOARCH=amd64 go build ./cmd/server`
- `GOOS=windows GOARCH=amd64 go build ./cmd/server`

三平台单条命令出二进制，约 24-25MB，无 CGO / 无 C 工具链需求。

---

## 非目标（本轮不做）

- ❌ 真实账号鉴权（密码 / session / token）—— 产品定位为本地单用户桌面 app（详见 [`desktop-packaging-notes.md`](./desktop-packaging-notes.md)），不计划做 SaaS 多租户。`X-Forgify-User-ID` header 是身份标识，无密码；middleware（`IdentifyUser` + `RequireUser`）只校验 id 存在，不验明身份。前端 onboarding 创建第一个 user 后把 id 存 localStorage，每次请求带回。无 magic id：unknown id → 401 / UNAUTH_NO_USER（前端 self-heal）；非 `/api/v1/users` / `/api/v1/health` 路由都要求带有效 id。后台任务遍历真实 users（0 user → no-op）
- ❌ Docker 沙箱 —— 保持 Python subprocess（`infra/sandbox/python.go`，30s 超时）。本地单用户场景下 Docker 是过度工程
- ❌ 前端类型生成工具链 —— 下轮前端 iteration 再接
- ~~❌ 前端代码改动~~ —— **已解除**：后端 Phase 0-4 定型后前端已进入开发阶段（按 [`frontend-prd.md`](./frontend-prd.md) + boilerplate；见 CLAUDE.md 末节"前端开发守则"）
