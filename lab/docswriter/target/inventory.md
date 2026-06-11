# 全量模块清单 —— 每个模块都有归属（模块意识、全面覆盖）

> 文档树在 `docs/references/backend/`。**索引**（枚举）+ **domains/**（业务实体+服务）+ **foundation/**（地基/引擎/infra/工具）。
> 新增 `foundation/` 子目录 → 写时同步更新 `GOVERNANCE.md §5` 目录地图。
> 「归并」= 该模块的机制并进它紧耦合的那篇（如 handler stdio RPC 进 handler.md），不单独成篇——避免一个模块拆成两篇。

## 0. 索引文件（5，纯枚举、单一事实源）

| 文件 | 枚举什么 |
|---|---|
| `api.md` | 每个 REST 端点（method/path → handler / 一句语义） |
| `database.md` | 每张表 schema + 列 + 索引 + **ID 前缀注册表（S15）** |
| `events.md` | 3 条 SSE 流 + frame 四动词 + node 词表 |
| `error-codes.md` | 每个错误码（Go sentinel → wire code → HTTP → 场景） |
| `changelog.md` | dev log（log 类型、仅追加；未来用） |

## 1. domains/ —— 业务实体 + 服务（~33）

| 类 | 模块 → `domains/*.md` |
|---|---|
| **Quadrinity 执行体** | function · handler · agent · workflow |
| **图节点实体** | trigger · control · approval |
| **durable 引擎** | flowrun · scheduler |
| **挂载/协议** | skill · mcp · document |
| **对话运行时** | conversation · chat · messages · attachment · memory · todo · subagent |
| **横切服务** | catalog · relation · mention · model · apikey · websearch · notification · workspace · sandbox |
| **AI 工作会话** | aispawn · humanloop |
| **其余 app 服务** | contextmgr · envfix · entitystream |

> 紧耦合 infra 归并进对应 domain 文档 §机制：handler stdio RPC → handler.md · trigger 4 listeners → trigger.md · sandbox 自研 directInstaller/docker/runtimes → sandbox.md · attachment blob CAS → attachment.md · mcp go-sdk transport → mcp.md。

## 2. foundation/ —— 地基 / 引擎 / infra / 工具（~13）

| 类 | 模块 → `foundation/*.md` | 覆盖 |
|---|---|---|
| **自研地基** | orm | `pkg/orm`——链式 + 自动 workspace 隔离 + 软删 + 时间戳；去 GORM |
| | cel | `pkg/cel`——编译/求值/模板共享包 |
| | reqctx | `pkg/reqctx` + `pkg/agentstate`——ctx 种子（workspace/conversation/messageID/agentstate） |
| | pkg-utils | `pkg/{idgen,jsonrepair,pagination,pathguard,fspath,tokencount,wikilink,limits,schema}` 总览（各一段） |
| **共享引擎** | loop | `app/loop`——共享 ReAct 引擎（chat/agent/subagent/workflow 都是调用方）+ danger 门 |
| | tool | `app/tool` 5 方法接口 + 三字段注入 + `toolset` 懒加载/search_tools；内置工具组（filesystem/search/shell/web/ask）总览 |
| | errors | `domain/errors`——`errorsdomain.New(kind,code,msg)` 错误框架（Kind→HTTP + wire code） |
| **infra** | llm | `infra/llm`——自研各家原生流式客户端 + factory |
| | db | `infra/db`——sqlite open/migrate（glebarez/go-sqlite） |
| | stream | `infra/stream` + `domain/stream`——3 实例 SSE Bus（信封/四动词/replay 环/seq） |
| | crypto | `infra/crypto` + `domain/crypto`——AES-GCM 落盘加密 |
| **transport** | transport | `transport/httpapi`——router/middleware（workspace identify/require）/response（Envelope/SSE/分页）/handlers 组织 |
| **装配** | bootstrap | `internal/bootstrap`——DI 装配根 + App Boot/Serve/优雅关停（P8，最懂全局时评） |

> **显式豁免（不评审、不成篇）**：`infra/logger`（zap 薄封装，无设计面）。`infra/fs/*` 不豁免——`blob`→attachment / `skill`→skill / `memory`→memory 各归并。

## 3. 对账（covering 前每个代码模块都 ☑）

`internal/` 共 **130 个 Go 包**（domain 28 · app 49 含 tool · infra 35 · pkg 13 · transport 4 · bootstrap 1）。covering 前**逐包勾**：评审项 / 折叠进某项 / 显式豁免，无遗漏。折叠规则见 `order.md`。

## 规模

5 索引 + ~33 domains + ~14 foundation/装配（含 bootstrap）≈ **52 篇**。全面但不碎——紧耦合 infra 归并、微 pkg 合并总览、logger 豁免，避免一模块拆两篇 / 30 行噪声篇。
