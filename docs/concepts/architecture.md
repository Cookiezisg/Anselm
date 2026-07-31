---
id: DOC-001
type: concept
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2026-09-11
audience: [human, ai]
---

# Anselm 架构（愿景 · 分层 · 实体 · 引擎）

> 本文件是项目的**愿景 + 架构 + 路线**。代码规范、工程纪律、设计原则、N/D/E/S/T 系列见项目根 [`CLAUDE.md`](../../CLAUDE.md)（单一事实源）；文档规范见 [`GOVERNANCE.md`](../GOVERNANCE.md)。

---

## 1. 产品愿景

Anselm 是一个 **本地优先（local-first）的 Agentic Workflow Platform**，交付形态为 **Flutter 桌面 app**（macOS/Linux/Windows，Go 后端作 sidecar）、**单进程单用户**、SQLite 落盘——**不做 SaaS、不做多租户**。

用户用自然语言**构建**可复用的执行体、并把它们**编排**成工作流；工作流由一个**持久化执行引擎**驱动，崩溃可恢复、确定可重放。本地大模型窗口被充分利用（文档/记忆**直接注入、无 RAG**）。

两个核心心智贯穿全局：

- **Quadrinity（四项全能）**：任何能力都归属于 **Function / Handler / Agent / Workflow** 之一——构建的最小执行体。
- **Durable Execution（持久化执行）**：工作流执行 = **节点结果记忆化** + **解释器幂等重走**，崩溃从落库的节点结果恢复。

---

## 2. 分层架构（4 层 Clean Architecture）

依赖**自下而上**，单向：

```
transport  →  app  →  ( domain  ∪  infra/store )  →  infra/db
```

| 层 | 职责 | 关键约束 |
|---|---|---|
| **transport** (`internal/transport/httpapi`) | HTTP 边界：`handlers/`（业务、随 feature 增）+ `middleware/` `response/` `router/`（框架级、写一次） | 只翻译 HTTP ↔ app；不含业务逻辑 |
| **app** (`internal/app/*`) | Service 协调层：编排 domain + infra，承载业务流程 | 跨实体协作；DIP 端口注入、不硬依赖具体实现 |
| **domain** (`internal/domain/*`) | 纯业务：实体、Repository 接口、领域错误、规则 | **严禁 import 任何外部包**（含 ORM/cel-go）；纯 struct + 轻量 `db:"col"` tag |
| **infra** (`internal/infra/*`) | 技术实现：`store/<域>/`（实现 domain.Repository）、`db`、`llm`、`sandbox`、`crypto`、`mcp`、`stream`、`trigger`、`handler`、`fs` | `infra/store → domain`（实现接口）；`infra/db → 标准库` |
| **pkg** (`internal/pkg/*`) | 跨层纯工具：`orm`（自研 ORM）、`cel`、`idgen`、`reqctx`、`agentstate`、`pagination`、`fspath`、`pathguard`、`limits`、`tokencount`、`jsonrepair`、`wikilink`、`schema` | 无业务；被任意层消费、不反向依赖 |
| **bootstrap** (`internal/bootstrap`) | DI 总装：按依赖序装配全部 Service + 适配器 + 路由 + Boot/Shutdown | 唯一 import 全部包的地方；天然最后 |

**地基自研、不背框架**：

- **ORM = `pkg/orm`**（链式、类型安全、自动 `workspace_id` 双向隔离 + 软删 + 时间戳），driver = `glebarez/go-sqlite`（纯 Go `database/sql`，无 CGO）。domain **不带 ORM tag**。
- **LLM 客户端 = 自研 `infra/llm`**（各家原生流式客户端 + factory，无第三方 agent 框架）。
- **CEL = `pkg/cel`**（编译/求值/模板共享包，避免 infra→app 依赖）。

---

## 3. 实体地图

一切能力都是一个实体；实体按职责分层：

### 3.1 Quadrinity —— 构建的执行体

| 实体 | 前缀 | 是什么 | 版本模型 |
|---|---|---|---|
| **Function** | `fn_` | 无状态代码（跑完即弃） | 线性版本 + 自由 active 指针，无 pending/accept |
| **Handler** | `hd_` | 有状态 Python 类（常驻单例进程、保持状态） | 同上；edit/config 变更触发进程重启 |
| **Agent** | `ag_` | 配置好的 LLM worker（挂载 skill/mcp/document/fn/hd/model） | 同上 |
| **Workflow** | `wf_` | 静态编排图（DAG + 回边），按 id 引用其它实体 | 同上 |

Function/Handler 跑真实代码 → 经 **sandbox** 隔离运行；env 缺失由 **envfix**（utility LLM 看 stderr 改 deps 重试）自愈。

### 3.2 图节点实体 —— workflow 的 5 类节点各引用一类

工作流图 = **纯编排数据依赖图**，5 种节点、边 = payload 数据管道：

| 节点 | 引用 | 语义 |
|---|---|---|
| **trigger** | `trg_` | 入口信号源（独立实体，见 §4.3） |
| **action** | `fn_` / `hd_<id>.method` / `mcp:server/tool` | 一个 durable activity |
| **agent** | `ag_` | 一个配置好的 LLM worker |
| **control** | `ctl_` | CEL 路由逻辑（分支：when→port + emit） |
| **approval** | `apf_` | 人工审批渲染（`{{CEL}}` 模板 + 决策规则） |

`ctl_` / `apf_` 是把"逻辑坨"物化出来的 **AI 工作实体**（独立构建、版本化）。

### 3.3 挂载 / 协议实体

- **Skill** (`文件式`, 无 DB)：memory 近亲的文件式指令载体；`allowed-tools` = 危险**预授权**。
- **MCP** (`mcp_`)：Model Context Protocol 网桥（go-sdk）；对接 GitHub registry、stdio/sse/http 双 transport、动态 `mcp__server__tool` 暴露给 LLM。
- **Document** (`doc_`)：Notion 式树状文档库；@提及**冻结注入、无 RAG**。

### 3.4 对话运行时

- **Conversation** (`cv_`) → **Chat 引擎**（持久化 ReAct 主机）→ **Messages** (`msg_`/block) 落盘。
- **Attachment** (`att_`)：CAS 内容寻址存储 + 10 家 provider 多模态注入 + sandbox 本地提取。
- **Memory**（文件式）：跨对话长期事实（pinned 常驻 + 目录按需读）。
- **Todo**（TodoWrite）、**Subagent**（递归子对话，写父对话 messages 表）、**Contextmgr**（上下文压缩）。

### 3.5 横切 / 地基服务

**Catalog**（实体名录，给 LLM "有哪些实体"）· **Relation**（实体血缘有向图，4 动词 create/edit/equip/link——结构**终态**）· **Touchpoint**（对话触点台账 `tp_`：对话碰过的一切外部之物按 (对话,物,动词) 聚合落盘——@提及/附件/AI 创建·编辑·看过·执行·删除，写侧=chat Send + loop 工具咽喉双水龙头，读侧=分页 REST + messages 流 durable 信号；relation 答结构、touchpoint 答**历程**，右岛数据地基）· **Mention**（@引用快照）· **Model**（场景→provider/model）· **APIKey**（加密保险箱 + BYOK）· **WebSearch** · **Notification**（持久化通知）· **Workspace**（本地隔离单元）· **Sandbox**（三 runtime）· **Search**（统一检索：12 类实体投影进 FTS5/trigram BM25 + 内置 embedder 语义混合（RRF），四出口——人的综搜/垂搜 HTTP、LLM 的 `search_blocks` 积木面板、8 个垂搜工具换引擎、`Retrieve` RAG 取数口；嵌入引擎 = directInstaller 按需下的 llama-server + EmbeddingGemma 常驻子进程，缺席自动降纯词法。详见 [`domains/search.md`](../references/backend/domains/search.md)）。

### 3.5b 全模态产出（WRK-082）

媒体在系统里有**一种货币**:携 `attachmentId` 的 receipt。宪法是 [ADR 0014](../decisions/0014-mediaref-one-currency.md),四条不变量:

1. **一个值类型**——`pkg/mediaref` 的 `attachmentId` 文法(前端 `core/media/media_ref.dart` 是逐条孪生件)。它认**字符串形**,因为跨 workflow 节点 receipt 就是以文本流动的(agent 的终答成 `node.text`);文档正文另有 `anselm://media/<id>` 形,由同一份文法的 `CollectURIs` 认。
2. **一间库**——**五个产地**(chat 生成工具 / agent 的 `sys:` 挂载 / MCP 返回的二进制 / **fn·hd 沙箱产物** / 朗读)全部落 `attachments`,共用它已有的内容寻址去重、GC、播放租约、workspace 隔离与软删。

   第五个产地的两半是 function 与 handler——**仅有的两个以用户代码身份跑在 venv 沙箱里的产地**。这一个事实使它们与其余产地**种类不同**:别的都在进程内跑、手里有 workspace ctx 与附件库,**能自己铸 `attachmentId`**;沙箱里的用户代码不能,它能做的只有写下一个文件、然后**声明**它。故两者共用 `app/mediaartifact` 一个采集器(路径逃逸检查、内容嗅探、mime 白名单**三个安全决定只存一份**),只在 receipt 的 `source` 上区分。
   两者的目录粒度不同:function 是一次性 spawn,**一次运行就是那个单位**;handler 是长跑实例、一进程服务多次调用,故目录必须**随调用**穿过 stdio RPC,否则「这次**调用**的产物」根本不是一个良定义的集合。
3. **两个咽喉**——**产出**侧一律出 receipt(绝不出字节:一段 20 秒 1080p 是几十 MB,让它在 tool_result / frn 行 / SSE 帧里流动等于每次重放都再付一遍);**消费**侧一律经 `attachment.ToContentParts(ids, caps)`,三个入口(agent invoke payload / loop `MediaExpander` 的 tool_result / 附件文档注入)共用同一条,按解析出的模型模态门控——看不了图的模型只留文本 receipt(诚实降级)。
4. **一族卡**——前端 `AnMediaRefCard` 按**附件行的 mime** 分发(不按 receipt 自称、不按 url 猜),chat 工具卡 / flowrun 节点检查器 / 实体调试台 / approval 门 / 文档编辑器同吃这一族。

**生成是工具、不是第五个实体**(设计原则 #1 的封闭集不动):`generate_image` / `generate_speech` / `generate_video` 是 Tool,经 **CapabilityTools 缝**逐请求 resident 注入 chat、经 **`sys:` 第四挂载词法**进 agent 与 subagent。三者皆**诚实缺席**——运行期无可用路由时,整个工具不存在,而不是存在且必失败。视频是其中唯一的**长**工具:各家全异步,故它同步等完并经既有 `progress` 块流状态行(**不给百分比**,理由见 [ADR 0013](../decisions/0013-video-generation-synchronous-tool.md))。

**受管与 BYOK 的边界**：默认产品路径通过 device proof 使用已部署 Anselm API；provider secret、路由、成本账本、配额和部署都归 API Serve。主仓拥有 install、workspace 默认、附件/MediaRef、能力工具与本地业务真相。BYOK 负责文本和支持的多模态读取；生成工具只随受管 capability route 出现。完整接缝见 [`managed-gateway.md`](../references/backend/managed-gateway.md)，网关内部数字和 provider 选择不在主仓重复维护。

### 3.6 AI 工作会话

- **aispawn**：`:iterate`（面对实体，让 AI 改）/ `:triage`（面对执行记录，让 AI 诊断）——本质都是**开一个携带背景的普通对话**。
- **humanloop**：**内存阻塞**的人在环——`ask`（agent 反问用户）+ `danger`（危险工具执行前阻塞确认）。

---

## 4. 持久化执行引擎（Durable Execution）

工作流的**解释执行**由 `flowrun`（状态）+ `scheduler`（解释器）承载。

### 4.1 核心模型 —— 节点结果记忆化（非事件溯源）

引擎是**图解释器**、无用户代码可重放，唯一状态 = 「哪些 (节点,轮次) 完成了、result 是啥」。故采用 **DBOS / Conductor 式的节点结果记忆化**，**不是** Temporal 式的事件日志：

- **flowrun = 2 表**：`flowruns`(`fr_`，执行头：钉死的拓扑 + pin 闭包 + 状态) + `flowrun_nodes`(`frn_`，**唯一真相表**：每 (节点,轮次) 一行 + 记忆化 result)。
- **record-once**：`UNIQUE(flowrun_id, node_id, iteration)`，首写赢——重放抄已 completed 行、**绝不重跑**。
- **崩溃恢复 = 再调一次 `advance()`**：解释器读 frn 行 + 冻结图 → 算 ready → 跑 → upsert frn → 收敛到同一状态。

### 4.2 解释器（`scheduler`）

一个**幂等 `advance()`** 走图循环：

- **join = 从已落库决策重推活跃子图**（control/approval 的选择决定哪些边活），**无 skip 信号传播**；AND-join 与 control 分支后的 simple-merge 由同一规则统一。
- **回边 → iteration+1**（循环）；`MaxIterations` 封顶失控循环。
- **pin 钉死确定性**：`VersionID`（拓扑）+ `PinnedRefs`（引用实体的 active 版本闭包）冻结——运行中编辑任何实体都改不动在途 run。
- **执行生命周期**（workflow 5 动词）：`:trigger`（造 payload 跑一次）/ `:stage`（待命接下一次真实触发）/ `:activate`（上线监听）/ `:deactivate`（优雅下线）/ `:kill`（硬停 + 取消在途 run，经 ctx 打断阻塞节点）。
- **执行并发**（F174，[ADR 0007](../decisions/0007-scheduler-async-advance-pool.md)）：后台路径（firing-drain / Recover / 超时重驱）把 run 的 `advance()` **入队**到有界 worker 池（N=4），而非在单 drain goroutine 上内联跑——故一个慢节点不再 head-of-line 卡住后面的 run / workspace / 下一 tick / 审批超时。phase-1 claim/seed/overlap 决策仍严格顺序；手动 `:trigger`/`decide`/`replay` 仍同步内联。per-run guard 强制同 run 单飞；SQLite 单连接使写仍串行。

### 4.3 触发层（`trigger`）

trigger 是**独立信号源实体**：

- **引用计数生命周期**：≥1 个 active workflow 引用 → listener 才起；N workflow 共享一个 listener、fire 扇出。
- **4 source**：cron / webhook / fsnotify / sensor（绑 fn/hd + CEL 条件轮询）。
- **durable firing 收件箱**：persist-before-act + **单事务 claim**（claim firing + 建 run + 写首条记账，一个事务）保证幂等不丢。
- **唯一 durable timer**：approval 超时（`CheckTimeouts`）。

### 4.4 CEL 双轴

- 节点 `Input`：**node-addressable scope**（按 node id 读祖先 result）；create/edit 时**逐节点用「祖先 scoped env」编译**——引用非祖先节点 = 编译失败（祖先可见性 lint）。
- control `when`/`emit` + approval 模板：**input-rooted**。

---

## 5. SSE 实时协议（3 条流，永不再加）

全系统仅 **`messages` / `entities` / `notifications`** 三条流；前端启动即常驻全连，三流 **workspace 级、后端不过滤**（发完整 delta、前端自滤）。统一信封 `Envelope{seq, scope, id, frame}` + 四动词 frame（open/delta/close/signal）+ 通用 `Node{Type, Content}`。delta/tick 为 ephemeral（`seq=0`、不入 buffer、无背压）；open/close/signal 为 durable。

- **messages**：对话/loop 的流式过程（message → block → tool_call，E3 `parentBlockId` 嵌套渲 subagent 树）。
- **entities**：实体活动（构建 args delta / run 终端 / fire 信号）。
- **notifications**：持久化通知收件箱。

---

## 6. 沙箱与平台

- **Sandbox 运行时**：Python · Node · uv · dotnet 四个，由**自研 `directInstaller`** 在首次使用时直接从上游（python-build-standalone / nodejs.org / astral / dotnet）拉钉死版本 tarball、校验、解压到 `<dataDir>/sandbox/runtimes/`；Docker 为 docker-only 的 MCP 提供镜像式 runtime。统一双接口（image=runtime、容器=env）。**无 mise、无内嵌工具**（见 [`decisions/0001`](../decisions/0001-sandbox-runtime-direct-install.md)）；依赖管理（venv / npm / uv pip）由各 `EnvManager` 自理。搜索 embedder 的两件产物（`llamasrv` 二进制、`embedmodel` GGUF）走同一 installer 注册表与下载纪律（钉版本 + 钉 sha256 + HF 镜像备链）。
- **平台**：macOS arm64/amd64 · Linux arm64/amd64 · Windows amd64。**无 CGO、无 C 工具链、无 embed 预拉**——任意平台 `GOOS=x GOARCH=y go build ./cmd/server` 单条命令出二进制，运行时在目标机按需下。

---

## 7. 状态与路线

| 里程碑 | 形态 | 状态 |
|---|---|---|
| 后端（`backend/`，4 层架构 + Quadrinity + durable 引擎 + 全实体） | 编译/装配/启动/服务全通；单一后端 | ✅ 当前 |
| 前端地基（`frontend/`，Flutter 桌面端：sidecar + 契约层 + SSE gateway + 装配根 + i18n） | analyze + test 绿；见 [`decisions/0004`](../decisions/0004-frontend-flutter-architecture.md) | ✅ 当前 |
| 前端 features（按 app 形态铺各域屏、对接 `backend` 契约） | Chat、Entities、Library、Scheduler、Notifications、Settings 已接入唯一 AppShell；当前事实与验证入口见 `references/frontend/` | ✅ 已建立 |

> 旧版快照归档在 `version-0.2` git 分支。历史只在 git，不在本文档（**零历史包袱**）。

### 7.1 已立项待做（归档战役的溢出条目）

战役收口归档时，**尚未落地但已拍板要做**的条目落在这里——而不是留在 `archive/`（只读墓地，没人会去那里找 TODO）。
一条一行，注明来源战役，做完即删（**状态即重述**，不留「曾经待做」的痕迹）。

| 条目 | 来源 | 记 |
|---|---|---|
| fork skill 的 `model` / `effort` override | WRK-075 | subagent 的 `ModelResolver` 无 override 口；承袭显式 `conv.ModelOverride` 会越 `reqctx` 的 pkg→domain 边界，故当初延后（`subagent.go` 注释在案） |
| `POST /skills:install` 的 202 进度流 | WRK-075 | 当前同步阻塞 + 前端 spinner；大仓可选升级为 notifications 流进度 |
| node 运行时的 `package.json` deps | WRK-075 | 沙箱侧尚未支持 |
| skill `references/` 进搜索索引 | WRK-075 | 目录即真相后，references 下的文件仍不入全文检索 |

---

## 8. 非目标（本轮不做）

- ❌ **真实账号鉴权**：本地单用户桌面 app，无密码/session/多租户。隔离单元是 **workspace**（物理 `workspace_id` 列 + ORM 自动隔离）。
- ❌ **分布式执行机制**：单进程 local-first，不要 task queue / worker fleet / sharding / lease（durable 引擎刻意删掉这些分布式偶然复杂度）。
- ❌ **@提及走检索注入**：@提及仍是**冻结快照注入**、不经检索（统一搜索服务的 `Retrieve` 是给 agent 取数的显式口，不改变提及语义）。
- ❌ **外接向量库**（Chroma/Pinecone/Milvus）：单用户本地规模下 SQLite BLOB + 暴力余弦即 Flat 索引的标准答案。
- ❌ **workflow v2**：resume-mid-agent / 通用 durable timer / continue-as-new / overlap 缓冲——明确 v2。
