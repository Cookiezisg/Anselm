---
id: WRK-086-LOG
type: working
status: active
owner: @weilin
created: 2026-07-31
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
landed-into:
---

# WRK-086 · 文档治理日志

> 仅追加已确认事实。猜测、计划和未复现问题留在 [`CHARTER.md`](CHARTER.md) 的批次/frontier，不写入本日志。

## 2026-07-31 · PREP-000 · Goal 启动基线

- 起点 commit：`43a7b17ee90b5227d4490657ede5bc6871b4642a`（`docs: record post-focus backend regression gate`）。
- tracked Markdown：161；`docs/` Markdown：150。
- `docs/` 分布：archive 56、references 44、working 26、decisions 20、root 2、how-to 1、concepts 1。
- 初始 `make -C docs verify` 在治理草稿产生前通过，带 1 条 warning：12 对 anchored DTO 完成镜像检查，21 个 anchor 因无同名 Go struct 跳过。此 warning 尚未裁决为缺陷。
- 已确认结构问题：
  - `docs/working/backend-evolution/archived/` 含 7 篇仍声明 `type: working / status: active` 的历史材料。
  - 当前受治理树可见重复 ID：`WRK-026` 与 `WRK-070`；另有 archive 与 working 重复，现有门禁不查唯一性。
  - `working/frontend/` 有 12 篇，其中多篇正文已明确写“全落/归档”，仍保持 active。
  - `docs/references/frontend/architecture.md` 仍称“重建中”；`concepts/architecture.md` 仍称右岛/人在环/工具卡在建。
  - 当前代码有 chat/entities/library/notifications/scheduler/settings 六个 feature，但缺完整 Chat、Scheduler current reference。
  - `frontend/README.md` 仍称 feature 是 future，和物理目录冲突。
  - `working/frontend/README.md` 同时承担协作规范、进展、路线与历史索引，且把已完成工作继续作为活入口。
  - 平台已落事实与未实施、具时效性的发行研究混在 `working/platform-foundation/`。
- Goal 启动前有 5 份未提交前端治理草稿，已在 CHARTER §8 隔离；必须在 G1 重新核对，不能计为完成证据。

## 2026-07-31 · G0-001 · 结构门禁与单一 archive

- `backend/cmd/docs` 新增低误报结构门禁：`DOC-NNN` / `WRK-NNN[-SLUG]` 语法、受治理区 ID 唯一、三个 frontmatter 日期格式、canonical 目录/type 对齐、`status: archived` 位置、working 必备 `landed-into`、working 私有 `archive|archived|legacy|old` 子树禁令。
- 新增 `main_test.go` 五组 fixture，分别校准合法树、重复 ID、type/status 错位、私有墓地/缺字段、非法 ID/日期；`go test ./cmd/docs` 与 `go vet ./cmd/docs` 通过。
- 新门禁首次对真实仓库打出 25 个错误：17 篇 working 缺 `landed-into`、7 篇旧 iteration 位于 `working/backend-evolution/archived/`、2 组重复 ID（重叠计数）。逐项修复后 `make -C docs verify` 恢复通过。
- 旧 iteration 七篇材料迁入唯一墓地 `docs/archive/backend-evolution-v1/`，保留历史 frontmatter 并标 `status: archived` / `landed-into`；current HISTORY、README 与 testend R23 链接已改到新路径。
- GOVERNANCE §3/§4/§5/§11 与 CLAUDE 文档门禁摘要同步到实际实现；同时纠正 GOVERNANCE 旧文中“ADR git 历史已机械校验”的不实陈述——该项仍靠人工清单。
- 当前唯一 warning 仍是 DTO 镜像覆盖统计（12 checked / 21 skipped），留待 G1/G5 依据类名投影语义逐项裁决。

## 2026-07-31 · G1-001 · 前端入口、缺失事实源与施工面退役

- 逐项核对 `frontend/lib/app/router.dart`、`app_shell.dart`、六个 `features/*`、`core/*`、三平台宿主、`pubspec.yaml`、前端 Makefile 与测试目录；确认产品当前有 Chat、Entities、Library、Scheduler 四个业务海洋、Settings 设置海洋与 Notifications 跨壳能力。
- 新增 Chat、Scheduler 与平台层 current reference；重述前端 overview、architecture、Entities reference 与 `frontend/README.md`，修正旧文中的 `features/documents`、`/documents/*`、显式 `/chat` landing、旧海洋数量和“重建中/在建”描述。
- 路由事实已对齐：壳内 canonical 路由为 `/chat/:id`、`/library/:id`、`/library/skill/:name`、Scheduler 三级路由；`/scheduler/runs/:frId` 是 run-id 中继；Entities 关系图与 workflow 编辑器是两个壳外全屏页。
- 已完成的 12 篇前端施工材料全部填入 current 落点并迁入 `docs/archive/frontend-construction/`：Chat 主迭代、工具卡三册、Entities/Workflow、右岛两轮、Scheduler、sidestage 与旧 working hub。`docs/working/frontend/` 已物理消失。
- CLAUDE、INDEX、concept architecture 与 design-system 的 active 入口已改指 current reference，不再把已完成施工日志当当前协作入口。
- 代码核对发现 `frontend/lib/app/app_shell.dart` 仍有把已存在海洋称作“未建/即将推出”的源代码注释。它不改变运行时，但属于产品代码，按 CHARTER 的授权边界只登记、不在文档战役中修改。
- 验证：`make -C docs verify` 通过；`backend/` 下 `go test ./cmd/docs` 通过；active 文档中已无 `working/frontend`、旧 `/documents/*` 路由或“前端重建中”命中。DTO 镜像覆盖 warning 保持 12 checked / 21 skipped，未被隐藏。
- 本批只完成 G1 的入口、核心 current 面与归档；contract、design-system、Library、Notifications、Settings、Chat sidestage 的可读性与历史噪音仍需继续做 G1 对抗精炼，不能据此宣称 G1 完成。

## 2026-07-31 · G1-002 · 前端 current reference 全面精炼

- 重新按实际代码边界整体重述 contract、design-system、Library、Notifications、Settings 与 Chat sidestage；删除 current 文档里的施工批次、日期裁决流水、旧方案回顾、一次性测试数量和“全落/收官”陈述。
- contract 现在只维护 wire 投影地图、信封/分页、开放/封闭词表、消息版本语义和高风险三态；生成文件与完整类型清单由 `core/contract/` 自身承担，不在文档复制易漂移数量。
- design-system 现在只维护 token/原语/feature 的层级、选择表、三岛语法、焦点/a11y、流式/媒体纪律与验证入口；完整导出清单以 `core/ui/ui.dart` 为机械事实。
- 六个真实 feature 均有 current 入口：Chat、Entities、Library、Scheduler、Notifications、Settings；Chat 右岛因跨工具/运行/人在环复杂度保留独立 current reference。
- 高风险词扫描在 active 前端 reference 中只剩 Scheduler 对“占位冒充事实”的否定句，无施工状态命中；旧 `/documents/*`、`features/documents` 与 `working/frontend` 引用为零。
- 复核所有文档声明的测试目录/文件；修正重写时误换的 DOC ID（Library 保持 DOC-052、Chat sidestage 保持 DOC-051）与不存在的媒体测试目录。
- 验证：`make -C docs verify` 通过，`git diff --check` 通过；warning 仍为 12 个 DTO mirror pair checked / 21 个无同名 Go struct 的 anchor skipped。
- G1 完成。仍发现的 `app_shell.dart` 过时产品代码注释继续作为未授权代码 finding 保留，不影响 current 文档事实。

## 2026-07-31 · G2-001 · 已部署 API Serve 责任边界与易漂移复制收口

- 只读核对同级 `Anselm-API-Serve` 的 AGENTS、CLAUDE、INDEX/GOVERNANCE、中英文 README、deploy 文件树、公开 backend references、近期提交与当前工作树；该仓有用户正在收尾的未提交治理/实现改动，本战役未写入、未暂存、未提交其中任何文件。
- 主仓代码确认默认 managed base 由 `infra/llm/anselm.go` 持有，空配置直达生产 API，`ANSELM_GATEWAY_URL` 只作显式覆盖；`app/freetier`、`infra/deviceproof`、managed media/ASR/generation 客户端共同证明本地 sidecar 与部署服务已完整接缝。
- 主仓 backend-evolution 的真实 live 记录已在 2026-07-29 通过 managed provision/probe、`anselm-auto` 默认中文 chat 与终态，证明默认产品路径不要求本机 provider secret。
- 新增 `references/backend/managed-gateway.md`：本仓只登记 install/device-proof、managed 行、workspace 默认、附件/MediaRef、loopback API 与 BYOK 本地职责；API Serve 独占 provider secret、路由、费率/账本、部署/回滚/监控。明确默认路径不需要任何用户 provider key，`DASHSCOPE_API_KEY` / `ANSELM_DASHSCOPE_BASE` 不属于主仓启动配置。
- `foundation/stream-llm.md` 与 `domains/support-services.md` 整体重述，删除主仓对网关内部 provider 名单、模型数字、生成方言历史和配额实现的复制；managed/BYOK 只保留公开产品边界并链接新 reference。
- backend overview、concept architecture、INDEX 同步新边界；overview、database、error-codes 去掉易漂移的域/handler/provider/错误码手工总数。error registry 仍由 `cmd/docs/drift.go` 对具体 code 双向严格校验。
- `make -C docs verify` 通过；四索引漂移检测保持 error code 双向、event 双向/族、endpoint 资源词与 table 双向覆盖，warning 仍仅 DTO mirror 12 checked / 21 skipped。裸 shell `go test ./cmd/docs` 因系统 go1.26.2 与项目缓存/标准库 go1.25.11 混用失败；改用仓库锁定工具链 `mise exec -- go test ./cmd/docs`（go1.25.11）通过，确认是环境选择而非代码失败。
- G2 尚未完成：当前 backend reference 仍有大量 WRK/工单/批次历史标签，且 CLAUDE 当前快照复制了 API Serve 内部 provider 数字；后续批次必须继续整体重述，不能把本节视为 G2 完成。

## 2026-07-31 · G2-002 · 工程宪法恢复为稳定事实源

- 整体重述根 `CLAUDE.md`：保留项目定义、9 条设计原则、N/D/E/S/T 契约、前端守则和文档纪律，删除前后端施工流水、WRK 标签、provider/model/工具数量、一次性性能数字、真钱实验过程及 API Serve 内部实现复制。
- 当前能力改为短地图：系统架构、后端、前端、managed gateway、契约索引、working 与 archive 各指向唯一权威入口；多模态仍明确属于当前产品路径，具体机制由 backend/frontend reference 与 ADR 承担。
- 修正前端物理分层为 `lib/core → lib/features → lib/app`，删除不存在的 `shared/core`、`sse-gateway.md` 和强制多 agent 扇出流程；任务可按实际执行环境选择协作方式，不再由项目宪法硬编码代理编排。
- 同步重述 GOVERNANCE 的常驻执行层措辞、前端 canonical 文档地图与同步触发表；ADR 规则现在区分“不可改原决定正文”和“允许生命周期/前向元数据”，消除 §6 与收尾清单互相冲突。
- 验证：`make -C docs verify` 与 `git diff --check` 通过；warning 仍仅为 DTO mirror 12 checked / 21 skipped。
- G2 仍未完成：`concepts/architecture.md` 及 backend 四索引、domains、foundation 仍需逐篇清除建造史并复核当前代码。

## 2026-07-31 · G2-003 · 架构总览恢复为纯当前心智

- 整体重述 `concepts/architecture.md`，从“愿景 + 当前架构 + WRK 施工说明 + 战役溢出 TODO + 历史路线”混合体收敛为产品边界、系统边界、后端分层、实体模型、durable execution、主要端到端路径、实时协议与非目标。
- 删除来源战役表、旧版快照提示、已立项待做和一次性实现/性能数字；未完成工作只允许进入有生命周期的 `working/`。
- 多模态提升为独立系统级数据流：MediaRef 单一引用、Attachment 单一存储、能力门控的统一消费、前端统一呈现，并明确贯穿 Chat、Agent、Subagent、Workflow、approval、文档和实体调试面。
- 架构图明确本地 sidecar、BYOK、已部署 Anselm API 与 provider 的边界；默认受管路径不要求本机 provider key。
- 验证：`make -C docs verify`、`git diff --check` 和 architecture/CLAUDE 高风险施工词扫描通过；DTO warning 未变化。

## 2026-07-31 · G2-004 · 事件索引重建与 API 通则收敛

- 从 stream producer、notification emitter 与现有 wire 语义重建 `events.md`：保留三流、四 frame、durable/ephemeral、node.type、Emit/Broadcast、完整事件族及 entities/messages 挂载，删除施工批次、事故编号和阶段复盘。
- notification 事件仍由 drift checker 逐项核对；重写后没有通过放宽 checker 隐藏缺项。
- `api.md` 的通则从超长施工说明收敛为 envelope、分页/投影、实体/复合响应、同步/异步动作和状态变更的稳定规则；同步更新 review 日期。
- 验证：`make -C docs verify` 通过，证明事件代码登记与端点资源覆盖未因精炼丢失；DTO warning 未变化。
- API 各域正文及 database/error-code 索引仍有施工历史，本批不宣称四索引完成。

## 2026-07-31 · G2-005 · 数据库与错误码索引去历史化

- 从现行 store schema 重建 `database.md`：完整保留物理表名、关键列、封闭集、索引不变量、ID 前缀、SQLite rebuild 规则和 durable 删除边界，删除迁移批次、事故编号、一次性 benchmark 与 UI 施工裁决。
- 修正文档内部的 D1 自相矛盾：durable 业务/日志真相只有 replay failed-node 与 terminal-run retention 两个物理删除例外；search、media derivative/perception、speech cache 明确属于可再生派生数据，其淘汰不新增 durable truth 的第三个例外。
- 多模态数据库契约保留 Attachment 来源/归属、MediaRef 消费边界、derivative/perception 收敛键、voice 上游指针和先上游后本地删除次序。
- `error-codes.md` 保留全量 code 表与当前 details/触发语义，去掉 WRK、工单、事故编号和真钱调试叙事；未改任何 code、HTTP status 或稳定 message。
- 验证：`make -C docs verify`、`mise exec -- go test ./cmd/docs`、`git diff --check` 通过；表名与错误码继续由 drift checker 双向核对，DTO warning 未变化。

## 2026-07-31 · G2-006 · API 核心契约精炼

- 精炼 API 通则、SSE 入口、workflow capability check、flowrun 列表/详情/activity/cancel/inbox/stats/matrix、trigger/firing/schedule、MCP plan 与 search reindex；保留 method/path、分页、query、response、错误码和并发语义，删除来源工单与事故编号。
- `GET /flowruns` 现在直接并列 keyset/offset 两种互斥形状和完整过滤词表；stats/matrix 保留 cancelled、replay、wall-clock 与稀疏格阵的当前语义，不再用施工故事解释。
- API 通则精炼后 drift gate 立即发现 `entities` 资源词只存在于被删旧句；新增显式三条 SSE 端点登记后门禁恢复通过，证明本批使用机械反馈修复真实覆盖缺口。
- 验证：`make -C docs verify` 与 `git diff --check` 通过，DTO warning 未变化。
- API 支撑域与系统/可观测性仍是两个超长混合段，保留为下一批明确 frontier；本批不宣称 api.md 完成。

## 2026-07-31 · G2-007 · Durable 引擎 reference 重建

- 按 `app/scheduler`、`domain/flowrun`、store schema 与已登记 API 整体重述 `foundation/scheduler-flowrun.md`。
- 当前文档分离 record-once、walk、手动/firing 创建、approval、replay/cancel、终态/attention、worker pool、boot context、retention、API 与 dispatch；删除工单编号、事故复盘、benchmark 和重复的整页 API 文法。
- 保留关键正确性边界：graph/ref 双 pin、handler/MCP 活态例外、节点终态写、first-wins、cancelled parked 行只能出现在 cancelled run、被打断节点不写 failed、replay/retention 两个 durable truth 删除例外、background ctx 逐 workspace 播种。
- 验证：`make -C docs verify`、`git diff --check` 与该文档施工词扫描通过；DTO warning 未变化。

## 2026-07-31 · G2-008 · Trigger 与 Workflow current reference 重建

- 从现行 listener registry、firing inbox、misfire sweep、workflow graph、capability check、版本与执行生命周期重建 Trigger 和 Workflow 两篇域文档，删除施工工单、事故编号、批次结论与旧实现叙事。
- Trigger 保留 persist-before-act、listener 引用计数与 fence、pause/resume、misfire 水位/hotSince/容差尾带、live/missed 共键、catchup-one、四类 source payload 与 dedup 契约；明确 missed 等中性终态及其 API 投影。
- Workflow 保留五类节点、CEL 可见性、capability problems/warnings、五种 overlap policy、stage/activate 门禁、active graph 入口重绑、pin closure、draining/kill/delete 与 approval inbox 语义；明确 overlap policy 只管真实 firing，显式 run-now 不经过该策略。
- 两篇文档均从“实现史解释当前行为”收敛为定位、状态、正确性边界、动作、契约与跨域集成；精确端点、表和错误码继续引用四个机械索引，不在域文档复制清单。
- 验证：`make -C docs verify`、`git diff --check` 与两篇文档施工词扫描通过；DTO warning 未变化。

## 2026-07-31 · G2-009 · Function、Handler 与 Agent current reference 重建

- 按现行 domain/app/infra 执行咽喉重建三个 callable entity reference，删除 Quadrinity 施工口吻、批次标签、事故编号、修复故事和易漂移的文件/工具/错误码数量。
- Function 现在集中说明不可变版本、per-version env、ops 构建、envfix 诚实失败、隔离运行、墙钟、三路日志、Execution 溯源及显式媒体产物声明；保留 env 被 GC 后按版本快照重建一次的恢复边界。
- Handler 现在集中说明加密 init config、类装配、单例/单飞实例管理、串行 RPC、管道取消即 crashed、config/code 变更的重启语义、失败 spawn 记账、secret 双面清洗及逐调用媒体目录。
- Agent 现在集中说明声明式版本、四类 ToolRef、严格绑定工具宇宙、create/edit eager validation、mount-health、knowledge/skill、统一 Invoke、transcript、多模态 input/tool-result 展开、结构化 outputs、HumanLoop 与 Workflow step replay。
- 交叉核对并修正三类物理 ID：Function execution `fne_`、Handler call `hcl_` / env `hdenv_` / instance `hdi_`、Agent execution `agx_`；mount health 明确为 HTTP 投影，不误列入 LLM 工具。
- 验证：`make -C docs verify`、`git diff --check` 与三篇文档施工词扫描通过；DTO warning 未变化。

## 2026-07-31 · G2-010 · Conversation、Messages、Chat 与 Subagent 主链重建

- 从现行 Conversation 主行、Message/Block domain、Chat queue/host/history/retry/fork 与 Subagent host 重建用户体验主链四篇 reference，删除工作包、事故编号、实现演进和重复段落。
- Messages 统一登记七类 Block、Message/Block 生命周期、tool-call/result 时序、context role、Subagent 嵌套、retry 双向版本指针及六类读面；明确 progress/marker/compaction 不进入 LLM history。
- Conversation 统一登记 durable 配置、运行投影、未读、auto-title、fork 前缀/ID remap/summary 水位、workdir 活投影与分组，以及 switch/create-branch/add-worktree 三个受限 git 动作。
- Chat 统一登记 per-conversation queue、detached turn context、SQL 最小化历史、逐步动态工具、runtime-profile 上下文恢复、三路多模态消费、detached finalize/orphan sweep、retry 线缆与 Fork/read projections。
- Subagent 明确为父对话内的深度 1 运行机制：无独立表，内部 trace 落 sub-message，父历史只见最终 tool result；general-purpose 可继承真实可用的生成能力，Explore/Plan 继续保持只读。
- 校验门禁发现重写时误用了 MCP 的 `DOC-020`；从提交前版本恢复 Conversation 的稳定 ID `DOC-023` 后通过，证明 ID 唯一检查有效拦截了人工改写错误。
- 验证：`make -C docs verify`、`git diff --check` 与四篇文档施工词扫描通过；DTO warning 未变化。

## 2026-07-31 · G2-011 · HTTP API 索引全量重建

- 从全部 HTTP handler 的 `Register` 路由与 action dispatcher 重新生成 API 心智结构，不再保留“核心区较新、支撑域/系统区是一行超长施工史”的混合状态。
- 按 Streams、Callable entities、Workflow execution、Graph authoring、Knowledge/Conversation、Media/Memory、Discovery、Workspace/Model/Managed service、Sandbox、Notifications/Settings、System/Storage 分组登记公开 method/path。
- 补齐并显式登记 attachment playback/preparation、Conversation workdir groups/git actions、sandbox conversation env reset、storage compact、read-aloud、voice、free-tier provision、execution triage 与 system data-dir 等容易被大段正文淹没的端点。
- Flowrun 复杂统计从逐字段立法长文收敛为端点、分页/窗口、批查上限与关键聚合语义；完整运行正确性转交 `scheduler-flowrun.md`、`workflow.md` 与 `trigger.md`，API 索引只承担 wire 注册职责。
- 代码复核修正一次重写误述：`POST /search:reindex` 是无可轮询产物的 fire-and-forget，返回 204，不是 `202 {id}`。
- 验证：`make -C docs verify`、`git diff --check` 与 API 施工词扫描通过；route resource drift gate 继续通过，DTO warning 未变化。

## 2026-07-31 · G2-012 · MCP、Skill 与 Search 能力发现链重建

- 从 MCP connection/install/OAuth/call、Skill file/install/activation 与 Search indexer/semantic engine 重建三篇 current reference，删除市场条目数量、供应商逐项故事、事故阈值推导、批次标签和实现文件计数。
- MCP 保留 encrypted config、内存连接状态、stdio/remote、curated plan、Required env、OAuth discovery/DCR/PKCE/refresh、dynamic tools、统一 Call 记账与多模态 MediaRef 边界；供应商纳入取舍继续由 ADR 0006 承担。
- Skill 保留 file-is-truth、frontmatter 保真、双层 name 规则、`os.Root` 文件守卫、inline/fork/@/Agent Guide 四种消费、tarball 安装护栏、provenance/hash/trust gate 与 script sandbox。
- Search 保留 source projection、非阻塞通知 + boot reconcile、Conversation anchor 增量、force-reconcile reindex、FTS/短词 fallback、cursor query hash、semantic 自动降级、embedding backfill/cache 与 search_blocks/Retrieve 边界。
- 代码复核修正 API 对 reindex 的措辞：当前实现重新排队所有 live entities、就地覆盖并清孤儿，不先 purge workspace；同时修正 MCP Call 稳定 ID 为 `mcl_`。
- 验证：`make -C docs verify`、`git diff --check` 与本批施工词扫描通过；DTO warning 未变化。

## 2026-07-31 · G2-013 · 后端基础设施 reference 重建

- 从现行 `app/loop`、Sandbox、request context、ORM、Bootstrap 与平台 packages 重建六篇 foundation reference；删除施工工单、事故复盘、过时数字和源码级长篇转录，保留跨域必须共同理解的不变量。
- Loop 统一登记 ReAct step、Host 能力、动态 tools/blocks、上下文 checkpoint、HumanLoop workdir 闸、多模态 tool result 与终止错误；Sandbox 统一登记 runtime/env/process group、恢复和 envfix；request context 与 ORM 明确 workspace 缺席、越权和 filter 缺失是不同错误边界。
- Bootstrap 代码反查修正启动次序：Scheduler pool 必须先于 Recover；Media worker 必须晚于逐 workspace Attachment/Media GC；Shutdown 明确 Scheduler、Search、MCP/Handler、Media、Sandbox、Shell 与 DB 的依赖顺序。
- HTTP chain 代码反查补回 `RequireLoopbackHost`、`RequireBearerToken` 和最内层 404/405 Envelope；workspace 豁免集补全 version、attachment playback 与 webhook 的不同授权来源。
- `app/search` 实现确认 reindex 是 force reconcile，而 HTTP handler 注释仍写“purge + rebuild”；这是产品代码注释漂移，按 CHARTER 授权边界只登记，不在文档战役中修改。
- 验证：`make -C docs verify`、`git diff --check` 与六篇文档施工词扫描通过；扫描仅命中 SQLite schema migration 与“尚未产生 block”的当前机制语义，DTO warning 仍为 12 checked / 21 skipped。

## 2026-07-31 · G2-014 · 后端支撑域与多模态入口重建

- 重建 Attachment、Document、Control、Approval、Relation、Touchpoint、Memory 与 Todo 八篇 current reference；全部稳定 DOC ID 保持不变。
- Attachment 从单行超长实现史重构为存储生命周期、溯源/MediaRef、能力门控的模型输入、managed/BYOK 传输、preparation/playback、LLM 工具与 durable/derived 边界；明确多模态共用 `att_` 与 receipt，贯穿 Chat、Agent、Subagent、Workflow 和工具结果。
- Attachment 代码反查确认工具结果只展开 `originToolCallId` 等于当前调用的媒体；受管 staging 格式闭集、模型额度降级、PDF 原生边界、Office sandbox 抽取、图片代理、短期播放 lease 与 inspect_media 的 bounded-evidence 语义均写入 current 文档。
- Document 重述树、path、position、duplicate、subtree delete、显式单篇挂载、missing grounding、wikilink 与 Search 回退；Control/Approval 重述不可变版本、author-time CEL、pinned runtime、port/timeout/parked inbox。
- Relation 与 Touchpoint 明确“当前结构终态”与“Conversation 历程聚合”的分工；删除影响、依赖断裂通知、工具目录穷尽性门禁、显示名快照与 messages Signal 均保留。
- Memory 与 Todo 分别收敛为跨对话文件事实和逐执行 scope 的短期清单，明确 pinned 策展不可被内容 Upsert 覆盖、Todo reminder 不污染历史且 todo_read 可读全完成清单。
- 发现两处未授权产品代码注释漂移：Attachment domain 顶层仍称 provenance “尚不执行”，但 `originToolCallId` 已强制；另一个映射注释仍称 audio/video 抽取为未来插件，但 `ToContentParts` 已支持能力门控的原生音视频。仅登记，未改代码。
- 验证：`make -C docs verify`、`git diff --check` 与八篇施工词扫描通过；扫描命中仅是“阶段/尚未”在 Boot/ready 当前机制中的普通语义，DTO warning 未变化。

## 2026-07-31 · G2-015 · 后端与 API Serve 边界阶段验收

- 重新盘点 backend reference：四索引、23 篇 domain/foundation、overview 与 managed gateway 边界均已在 2026-07-31 按现行代码审阅；每篇 domain/foundation 均有真实 package 或明确跨域平台归属，没有指向已删除实现。
- 对抗扫描 `WRK/工单/Phase/批次/施工/旧版/事故/真钱/实测` 后，backend current reference 仅剩 `TODO_*` 稳定错误码及“本轮”作为运行时单次处理语义；无施工历史或阶段状态残留。
- 复读 CLAUDE、concept architecture、backend overview 与 managed gateway：四者一致声明本地单用户 sidecar、Quadrinity、durable execution、系统级多模态、默认 managed 路径、可选 BYOK，以及本地与已部署 API Serve 的 secret/运维责任边界。
- 四索引继续由 docs checker 对 error code、event、endpoint resource 与 table 做代码漂移核对；本阶段没有通过减少登记或放松门禁换取通过。
- 验证：`make -C docs verify`、`mise exec -- go test ./cmd/docs` 与 `git diff --check` 通过；唯一 warning 仍是 DTO mirror 12 checked / 21 skipped，已持续显式保留。
- G2 完成。G3 开始处理 working/archive 生命周期；`backend-evolution` 的 CURRENT/FRONTIER/LOG/HISTORY 分工将在该阶段单独验收。
