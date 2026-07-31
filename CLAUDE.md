# Anselm — Agent 工作守则

> 任何 AI 编码代理进入本项目，均以本文件为工程纪律的唯一事实源。
> 文档入口见 [`docs/INDEX.md`](docs/INDEX.md)，文档治理规范见
> [`docs/GOVERNANCE.md`](docs/GOVERNANCE.md)。
>
> **交流语言**：对话回复一律使用中文；代码、标识符、协议字段和
> commit message 等技术产物按各自约定。

## 项目定义

Anselm 是本地优先的 Agentic Workflow Platform：

- Flutter 桌面客户端运行于 macOS、Linux、Windows；
- Go 后端作为单进程、单用户 sidecar，数据存入 SQLite；
- Function、Handler、Agent、Workflow（Quadrinity）承载能力；
- Durable Execution 通过节点结果记忆化和解释器幂等重走实现；
- 已部署的 Anselm API 提供受管模型与媒体能力，用户也可选择本地 BYOK。

当前系统已经覆盖对话、实体、工作流、调度、文档、工具、通知、搜索和
多模态输入/生成等产品路径。不要在本文件复制功能清单、模型目录、端点数量
或阶段进度；这些易变事实按下列入口查阅：

| 要了解 | 权威入口 |
|---|---|
| 系统心智、分层与主要数据流 | [`docs/concepts/architecture.md`](docs/concepts/architecture.md) |
| 后端当前能力与边界 | [`docs/references/backend/overview.md`](docs/references/backend/overview.md) |
| Anselm API 与本地 sidecar 的责任边界 | [`docs/references/backend/managed-gateway.md`](docs/references/backend/managed-gateway.md) |
| 前端当前产品与工程结构 | [`docs/references/frontend/overview.md`](docs/references/frontend/overview.md) |
| HTTP、数据库、错误码、事件 | [`docs/references/backend/`](docs/references/backend/) |
| 在研战役 | [`docs/working/`](docs/working/) |
| 已结束过程 | [`docs/archive/`](docs/archive/) 或 git 历史 |

后端采用四层 Clean Architecture，依赖方向为
`transport → app → (domain ∪ infra/store) → infra/db`；`domain` 不依赖
外部实现。基础设施以 `pkg/orm` 和纯 Go SQLite 为数据库底座。

## 设计原则（9 条，#9 最高优先级）

1. **Quadrinity 实体化**：能力必须归属于 Function、Handler、Agent、
   Workflow 之一；工具是执行能力，不是第五种实体。
2. **Durable 为魂**：工作流以 `flowrun_nodes` 的节点结果记忆化和解释器
   幂等重走实现恢复与重放，不以事件日志作为执行真相。
3. **依赖自下而上**：`domain` 严禁导入外部包；`app` 协调 domain 与
   infra；跨实体协作走 DIP 端口。
4. **后端契约是事实源**：后端 wire contract 与数据库结构是产品契约；
   reference 是代码的精确投影，前端 DTO 按契约镜像。
5. **端到端推演先行**：动工前走完整数据流，并列出跨域依赖与 relation 边。
6. **反校验剧场**：只保留有物理价值的校验，如 JSON、必填、
   `CHECK`、`UNIQUE`；不堆防御性空判断。
7. **零历史包袱，状态即重述**：没有已承诺的兼容面时不维护兼容层；
   状态文档只陈述当前事实，历史进入 git、ADR 或 `archive/`。
8. **复用与成熟实践优先**：先盘点 `pkg/`、`infra/` 和成熟依赖；遇到
   不确定问题先查官方资料与最佳实践。公共样板应强化地基，不在模块内复制。
9. **文档与代码物理同步**：代码改动必须在同一提交同步对应文档。
   文档落后于代码与编译失败同级。

## 契约宪法

### HTTP API（N 系列）

- **N1 Envelope**：成功为 `{"data": ...}`；失败为
  `{"error": {"code", "message", "details"}}`。
- **N2 状态码**：异步流使用 `202 Accepted`，无响应体成功使用
  `204 No Content`，SSE 游标淘汰使用 `410 Gone`。
- **N3 命名**：API 线缆使用 camelCase，数据库物理列使用 snake_case。
- **N4 分页**：无界集合必须支持 `cursor` 与 `limit`；有界资源、批查和
  派生投影只有在 [`api.md`](docs/references/backend/api.md) 明确登记后才可
  豁免游标分页，登记必须与实际参数及截断语义一致。
- **N5 动作后缀**：非 CRUD 动作用 `:action`。标准执行动词为
  Function `:run`、Handler `:call`、Agent `:invoke`、Workflow
  `:trigger`；AI 编辑与诊断使用 `:iterate`、`:triage` 并返回
  `conversationId`。

### 数据库（D 系列）

- **D1 删除语义**：业务表默认以 `deleted_at` 软删除；内容和执行日志不设
  软删除。物理删除例外必须先在
  [`database.md`](docs/references/backend/database.md) 立法。现有例外只有：
  `:replay` 清除失败节点以便幂等重走，以及按用户保留策略清理终态 run
  及其附属历史；`running`、`parked` 永不由保留任务删除。
- **D2 物理隔离**：除明确登记的全局配置外，业务表必须持有
  `workspace_id`，并由 `pkg/orm` 根据上下文双向隔离。
- **D3 唯一性**：`idx_frn_once` 保证 flowrun 节点只记录一次；
  `idx_trf_dedup` 保证 trigger firing 去重。

### SSE（E 系列）

- **E1 三条流**：系统只有 `messages`、`entities`、`notifications` 三条
  workspace 级常驻流；后端发送完整 delta，前端按 scope 自滤。
- **E2 帧耐久性**：delta、tick 等瞬时帧使用 `seq=0`，不进入 replay
  buffer；open、close、signal 等耐久帧进入 buffer，close 携带快照。
- **E3 嵌套**：messages 流以 `parentBlockId` 表达 subagent 递归树。

## 代码规范（S 系列）

- **S5 物理文件对齐**：transport handler 文件名对应 API 资源域，domain
  文件名对应 Repository 接口。
- **S9 确定性上下文**：跨层调用必须传 `ctx`；异步 finalize 使用 detached
  context，保留 workspace 种子且不继承请求取消。
- **S11 注释双语化**：需要解释的注释使用英文与中文两段，只解释 Why。
- **S13 导入别名**：`internal/` 包导入使用 `<name><role>` 别名，如
  `chatapp`、`workflowstore`。
- **S15 ID**：ID 采用 `<prefix>_<16hex>`；前缀全集登记在
  [`database.md`](docs/references/backend/database.md)，infra ID 不从消费
  实体 ID 派生。
- **S18 Tool**：Tool 实现 `Name`、`Description`、`Parameters`、
  `ValidateInput`、`Execute`；framework 注入并剥离 `summary`、`danger`、
  `execution_group`。危险等级同时衡量状态影响与成本：
  `safe` 只读或可逆且不额外付费，`cautious` 可恢复写入或小额计量付费，
  `dangerous` 不可逆、外部写入或值得逐次确认的付费。
- **S20 错误**：命名 sentinel 统一使用 `pkg/errors` 的
  `errorspkg.New(kind, code, message)`；稳定 wire code 采用
  `<ENTITY>_<REASON>`。标准库 `errors.Is/As` 与 `%w` 用于保留错误链；
  domain 将通用 infra 错误翻译为具体错误。
- **S22 工作区卫生**：仓库只保留源码和必要配置。构建产物、系统或编辑器
  文件不得入库。改变命令、工具或目录结构时，同提交同步 `.gitignore`、
  `Makefile`、`mise.toml` 的相关事实。

## 测试与门禁（T 系列）

- **T5 双层验收**：包内单元/集成测试覆盖局部行为；`testend/` 是独立
  module，以真实二进制和纯 HTTP/SSE 做黑盒验收。`make -C backend testend`
  默认使用 llmmock；`make -C backend evals` 只在显式开启时调用真实模型。
- **T5.1 契约改动查 testend**：修改端点、表、事件或错误码时，按事件或
  错误码的**域前缀**搜索并同步 `testend/`，再运行相关黑盒场景。只搜索完整
  事件名会漏掉集合断言。
- **T6 Fake LLM**：默认测试使用 `fake_llm`，不消耗模型额度。
- **局部门禁**：后端 `make -C backend verify`；前端
  `make -C frontend verify`；文档 `make -C docs verify`；web demo
  `make -C demo verify`。
- **根门禁**：推送前和战役收口运行 `make verify`。快速内环不是根门禁的
  替代。
- **真实验收**：`testend` 和 `evals` 不属于默认 `make verify`；涉及其
  契约或真实体验时按任务显式运行，并在日志记录环境、范围和证据。
- **工具链**：使用仓库的 mise 固定版本。裸系统工具与 mise 版本不一致时，
  以 `mise exec -- <command>` 执行。

## 前端开发守则

详细事实见 [`frontend/README.md`](frontend/README.md) 与
[`docs/references/frontend/`](docs/references/frontend/)。

- **分层**：`lib/core`（契约、网络、设计、SSE、进程等共享地基）→
  `lib/features/<domain>`（data/state/ui）→ `lib/app`（装配与 shell）。
  feature 之间不直接依赖；跨 feature 通过 core provider 或导航意图协作。
- **进程**：桌面 app 启动并监管 Go sidecar，经 localhost HTTP+SSE 通信；
  `/api/v1/health` 作为启动门控。开发时可用 `ANSELM_BACKEND_URL` 连接现有
  后端。
- **状态与实时**：Riverpod 管 server state；三条 SSE 流保持常驻。
  `SseGateway` 先按 scope demux；数据库行是真相，耐久帧推进游标，瞬时帧
  只更新临时视图。
- **契约**：`lib/core/contract` 的 freezed DTO 镜像后端 wire contract；
  封闭集才 seal，开放协议必须保留 unknown fallback。改变后端字段时同提交
  更新 Dart DTO 和 [`contract.md`](docs/references/frontend/contract.md)。
- **视觉与 i18n**：颜色、度量和字重走 design token；Dart 不硬编码用户可见
  中英文，文案进入 slang locale 文件。
- **启动面**：只保留 `make -C frontend gallery`、`app`、`demo` 三类入口；
  app 与 demo 共用 `AppShell`，差异通过数据源 override 与启动门控表达。
- **验证**：内环运行 `make -C frontend quick`；交付前运行
  `make -C frontend verify`。涉及桌面原生行为时补真机检查，不能以 widget
  test 代替可见体验。
- **开发流程**：先从后端代码与 reference 提取精确集成契约，再查相关官方
  资料和成熟实践，形成可验证的小步实现。若前端需求暴露后端缺口，必须明确
  扩展任务范围，并按 N/D/E/S/T 与文档同步规则一同交付。

## 文档纪律

完整规范以 [`docs/GOVERNANCE.md`](docs/GOVERNANCE.md) 为准。本节是每次
会话必须执行的常驻摘要。

### 三条铁律

1. **同步**：代码与对应文档在同一提交更新；否则改动未完成。
2. **触发即停**：发现文档与代码不符，先修正文档并记录 `[doc-fix]`，再续
   原任务。
3. **存疑即查**：先查 `GOVERNANCE.md`；规范缺口按设计原则处理，并补齐
   规范。

### 同步触发表

| 改动 | 必须同步 |
|---|---|
| API 端点 | `references/backend/api.md` + 对应 domain reference |
| DB 表或列 | `references/backend/database.md` + 对应 domain reference |
| error code | `references/backend/error-codes.md` + 对应 domain reference |
| SSE 事件 | `references/backend/events.md` + 对应 domain reference |
| 架构选型或取舍 | 新建或按治理规则 supersede `decisions/` 中的 ADR |
| 架构、实体、引擎或路线状态 | 整体重述 `concepts/architecture.md` 相关节 |
| N/D/E/S/T 或工程规则 | 整体重述本文件相关节 |
| 前端 DTO / envelope / 错误映射 | `references/frontend/contract.md` + 后端对应 reference |
| 前端分层、装配或 SSE gateway | `references/frontend/architecture.md` + 本节；需要取舍时新建 ADR |

`reference` 文档必须精确同步代码；本文件、`architecture.md` 和
`GOVERNANCE.md` 等状态文档必须整体重述当前事实，不能把新状态追加在旧状态
旁边。

### 完成前检查

- 对应 reference、concept 和前端投影是否已在同提交同步；
- 端点、字段、表、错误码和事件是否与代码一致；
- 新文档的 frontmatter、ID、类型、目录和生命周期是否合法；
- 移动或删除文档后是否修复全部链接；
- 是否避免篡改既有 ADR 的决定正文；
- working 结论是否落入稳定文档，填写 `landed-into` 后移入顶层
  `docs/archive/`；
- `make -C docs verify` 是否通过；
- 工作区是否只包含本任务有意修改的文件。
