# Anselm 文档索引

> AI 会话入口。先读本文，再循链接。**文档规范见 [`GOVERNANCE.md`](GOVERNANCE.md)（强制）。**

## 找什么去哪

| 要找 | 去 |
|---|---|
| **后端整体怎么组成、怎么流动（第 0 篇）** | `references/backend/overview.md` |
| 系统架构 / 路线 / 愿景 | `concepts/architecture.md` |
| 工程纪律 + 代码规则（S/T/N/D/E） | `../CLAUDE.md` |
| **HTTP 端点 / DB 表 / 错误码 / SSE 事件**（四索引，与代码逐字同步） | `references/backend/{api,database,error-codes,events}.md` |
| 某个域怎么设计的（心智模型 / 生命周期 / 坑） | `references/backend/domains/<域>.md` |
| 地基与引擎（orm / reqctx / **scheduler-flowrun** / loop / stream-llm / sandbox / bootstrap / 小件） | `references/backend/foundation/` |
| **前端怎么组成、怎么流动（第 0 篇）** | `references/frontend/overview.md` |
| **前端怎么协作 / 到哪了 / 去哪走（一站式 hub）** | `working/frontend/README.md` |
| 架构决策（直装运行时 / 统一错误类型 / API 契约标准化 / 前端 Flutter 架构 / 工具链 mise / MCP 市场白名单 / scheduler 异步 Advance 池） | `decisions/000{1,2,3,4,5,6,7}-*.md` |
| 数据目录 / 备份 / 跨机迁移 | `how-to/data-migration.md` |
| 全功能黑盒验收套件（make testend / evals） | `references/testend/overview.md` |

## 后端文档体系

**先读 [overview.md](references/backend/overview.md)**（鸟瞰 + 三条端到端数据流 + 横切机制），再进分域：

- **domains/**（21 篇）：function · handler · agent · workflow · trigger · control · approval · skill · mcp · document · chat · messages · conversation · subagent · attachment · memory · todo · relation · touchpoint · search · support-services（十一微域合篇）
- **foundation/**（8 篇）：orm · reqctx · scheduler-flowrun（durable 引擎）· loop（ReAct）· stream-llm · sandbox（含 envfix）· platform-pkgs · bootstrap
- **frontend/**（ADR 0004）：**先读 [overview](references/frontend/overview.md)**（鸟瞰第 0 篇:三岛壳 + 海洋 + sidecar + 三流）· [architecture](references/frontend/architecture.md)（物理文件图 + 路由 + 装配）· [design-system](references/frontend/design-system.md)（设计令牌 + An* 套件 G0–G6）· [contract](references/frontend/contract.md)（后端线缆的 Dart 投影）· [features/](references/frontend/features/)（各 feature 当前形态:entities…）。**协作 / 进展 / 路线 → 一站式 hub [working/frontend/](working/frontend/README.md)**

## 权威层级

`CLAUDE.md` > `references/` > `concepts/` > `working/` > `archive/`。
