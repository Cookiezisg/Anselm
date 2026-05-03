# V1.2 Backend 进展记录

**关联**：
- [`backend-design.md`](./backend-design.md) — 总体设计 + 规范（相对稳定，很少动）
- [`service-contract-documents/`](./service-contract-documents/) — 每个 domain 的服务契约索引（一眼清单）
- [`service-design-documents/`](./service-design-documents/) — 每个 domain 的详细设计
- [`desktop-packaging-notes.md`](./desktop-packaging-notes.md) — 桌面端分发方向（Wails / 打包 / 常驻后台）
- [`claude-code-research-documents/`](./claude-code-research-documents/) — Claude Code 内部机制调研（9 份主题报告）

**本文档定位**：所有"正在发生"的状态都在这里。开发日志 / 完成快照 / 待办清单 / 原则演化。规范/架构/愿景这些"相对不变"的放 `backend-design.md`。

---

## 1. 当前快照（截止 2026-05-01）

| Phase | 主题 | 状态 | 里程碑 |
|---|---|---|---|
| **Phase 0** | 骨架（go mod + main + /health） | ✅ | 2026-04-22 |
| **Phase 1** | 基础 infra 7 件套（GORM / logger / crypto / events / middleware / response / pagination） | ✅ | 2026-04-23 |
| **Phase 2** | 基础对话能力（apikey / model / conversation / chat） | ✅ | 2026-04-25 |
| **Phase 3** | 工具锻造（forge / attachment / tool / chat 加 tool-calling） | ✅ | 2026-04-26 |
| **Phase 3 后优化轮** | chat 基础设施重构 / pipeline → runner / 调研 / 驱动迁移 / 打包方向 | 🔄 进行中 | 2026-04-27 起 |
| **Phase 4** | 工作流（workflow / flowrun / 节点 / scheduler / trigger） | ⬜ 未开工 | — |
| **Phase 5** | 智能化（knowledge / intent / mcp / skill / chat 终极版） | ⬜ 未开工 | — |

**当前测试规模**：~170 单元/集成测试全绿（除 5 个 LLM 集成测试因 DeepSeek API key 环境失效，与代码无关）。
**当前驱动**：modernc.org/sqlite（纯 Go，无 CGO），跨平台编译一行命令。
**当前依赖体系**：完全摆脱 Eino（chat 重构后）。

---

## 2. 开发日志

按时间顺序（旧 → 新）。每个时间块按 phase 或专题分组。

### Phase 0-1：地基（2026-04-22 ~ 2026-04-23）

| 日期 | 内容 |
|---|---|
| 2026-04-22 | 全面契约审计（45 API 端点 + 10 DB 表 + 21 SSE 事件），一致性评分均低 |
| 2026-04-22 | 确定 12 条契约标准（N1-N5 API + D1-D5 DB + E1-E2 SSE） |
| 2026-04-22 | 确定 4 层架构：domain / app / infra / transport，GORM，单份结构带 tag |
| 2026-04-22 | Phase 0 完成：`backend-new/` 骨架，`/api/v1/health` 返回 envelope，优雅退出 |
| 2026-04-22 | 立 **S11 双语注释规范**（英文 + 中文），backend-new 全套代码/注释必须遵守 |
| 2026-04-22 | 日志框架定为 **zap**（dev 彩色 / prod JSON），`infra/logger/zap.go` 封装 |
| 2026-04-22 | transport 层结构升级：`http/` → `httpapi/`（避免包名冲突），拆出 `response/` / `middleware/` / `handlers/` 3 子包 |
| 2026-04-22 | **Phase 1 Step 2** 完成：`response/envelope.go`（Success / Created / NoContent / Paged / Error）+ `response/errmap.go`（FromDomainError）。N1 标准落地为强制 API |
| 2026-04-23 | **Phase 1 Step 3** 完成：`pagination/cursor.go`（Parse / EncodeCursor / DecodeCursor），cursor 分页 + 10 单测 |
| 2026-04-23 | **Phase 1 Step 4a** 完成：`middleware/recover.go`，panic → 500 INTERNAL_ERROR + 6 单测（含敏感信息不泄漏守卫）|
| 2026-04-23 | **Phase 1 Step 4b** 完成：`middleware/logger.go`（method/path/status/bytes/elapsed）+ 6 单测 |
| 2026-04-23 | **Phase 1 Step 4c** 完成：`middleware/notfound.go`，envelope 格式 404 fallback + 4 单测 |
| 2026-04-23 | 模块名纠正：`github.com/sunweilin/forgify-new` → `github.com/sunweilin/forgify/backend`（Go multi-module repo 标准命名）|
| 2026-04-23 | **Phase 1 Step 4d** 完成：`middleware/cors.go`，白名单 CORS（拒绝 `*`）+ 7 单测 |
| 2026-04-23 | **Phase 1 Step 4e** 完成：`router/` 子包 + `handlers/health.go` Register pattern 模版，4 个集成测试验证端到端中间件链 |
| 2026-04-23 | Phase 1 地基 4/7，37 测试零失败；envelope、CORS、访问日志全链路通 |
| 2026-04-23 | **Phase 1 Step 5** 完成：crypto 接口化（`domain/crypto/Encryptor`）+ AES-GCM 实现。修 4 个老代码安全问题（fallback 密钥共享灾难 / decrypt 返 nil nil / 无版本标识 / shell 脆弱）。密文 `v1:` 前缀给 KMS 留兼容位。14 新测试 |
| 2026-04-23 | **Phase 1 Step 6** 完成：`infra/db/`（db.go / migrate.go / schema_extras.go）。WAL / FK / PrepareStmt / UTC。AutoMigrate + schema_extras 模式，4 个 schema 业务问题推迟到 Phase 3 |
| 2026-04-23 | **Phase 1 Step 7** 完成：`domain/events/` 接口 + `infra/events/memory/` 内存实现。强类型事件（禁 `map[string]any`）、扇出 pub-sub、buffer 满非阻塞丢弃、ctx 自动 cancel、sync.Once 幂等 |
| 2026-04-23 | **路线图升级**：定位从"V1.0 重写"→ Agentic Workflow Platform 完整愿景。引入 6 新 domain（workflow / flowrun / scheduler / knowledge / mcp / skill / intent），对标 Dify+Coze 桌面版 |
| 2026-04-23 | 文档目录重组：`Documents/` → `documents/`；按版本分 `version-1.0` / `1.1` / `1.2`；文件名 kebab-case |
| 2026-04-23 | 加 auth middleware `InjectUserID`（硬编码 `DefaultLocalUserID = "local-user"`），Phase 2 多租户字段就绪 |
| 2026-04-23 | 加 locale middleware `InjectLocale` + 跨层共享包 `internal/pkg/reqctx/`（只 stdlib、无状态、单一职责） |
| 2026-04-23 | **全量注释瘦身**：15 个生产文件共砍 ~420 行冗余注释。S11 规范扩展为"双语 + 节制" |
| 2026-04-23 | **Phase 2 路线图修正**：新增 `model` domain（"场景 → provider/model"策略层）。立第 5 条设计原则 **"端到端推演先行"** |

### Phase 2：基础对话能力（2026-04-24 ~ 2026-04-26）

| 日期 | 内容 |
|---|---|
| 2026-04-24 | **apikey domain 层**完成。试过扁平 / 按角色子包 / Go 社区味子包多种结构，最终定**平铺**：`apikey.go`（entity + 常量 + errors + Credentials + ListFilter + Repository + KeyProvider）+ `providers.go`（11 provider 白名单）。立 **S12 包结构**（domain 平铺按概念拆，禁子目录）|
| 2026-04-24 | **apikey Repository + 18 集成测试**（CRUD / 跨用户隔离 / 分页 / GetByProvider 排序）。立 **S13 包命名**（三层同名 + `<name><role>` 别名：apikeydomain / apikeyapp / apikeystore）|
| 2026-04-24 | **apikey ConnectivityTester + HTTPTester + 21 httptest 用例**。4 种 HTTP 模式分派（openai-compatible `/models` / anthropic `/v1/messages` 1-token / google `/v1beta/models?key=` / ollama `/api/tags`）。立 **"spec 优先于邻居文件"** 审计纪律 |
| 2026-04-24 | **apikey Service + KeyProvider + 18 单测**。Service 拥有加密边界（repo 见密文、tester 见明文）。Test 编排：`repo.Get → decrypt → tester.Test → repo.UpdateTestResult → log` |
| 2026-04-24 | **apikey 5 个 HTTP 端点 + 15 个 E2E 契约测试**。`:action` URL 规范通过 `POST /{idAction}` 通配符 + `strings.Cut(":")` 拆分实现。`:test` 失败 → 422 `API_KEY_TEST_FAILED` |
| 2026-04-24 | **apikey 装配**。`router/deps.go` 加 `APIKeyService` 字段；`main.go` 串起 `MachineFingerprint → DeriveKey → AES-GCM → Store → HTTPTester → Service`。curl 实机冒烟 4/5 通过 |
| 2026-04-24 | **立设计原则 #6 "反校验剧场"**：Forgify 是本地 Electron + 单用户 + 同人写前后端。跳过"前端下拉已筛 + 下游自然报错"式的 backend 校验 |
| 2026-04-24 | **model domain 设计定档**：Q1 `/model-configs/{scenario}` 复数 path + path param；Q2 不校验 provider 白名单；Q3 不校验 hasKey。4 sentinel |
| 2026-04-24 | **文档结构重组**：`backend-rewrite.md` → `backend-design.md`；分册迁入 `service-contract-documents/`；详设计迁入 `service-design-documents/` |
| 2026-04-24 | **文档大审计 + 重写**：apikey.md 与实际代码对齐（14 处失真）。立 **设计原则 #7 + S14 "文档同步纪律"（最高优先级）**：每次代码改动联动三处文档，发现不符立刻修 |
| 2026-04-25 | **[arch-fix] providers.go 归属修正**：从 `domain/apikey/` 迁到 `app/apikey/`。理由：所有消费者都在 app 层，符合 Go "接口在消费方" 原则 |
| 2026-04-25 | **[arch] S12 文件命名规范扩展**：主文件用包名的规则从 domain 层扩展到 app / infra/store 全部三层。`service.go` → `apikey.go` / `model.go` |
| 2026-04-25 | **[arch] app/apikey 文件整合**：`keyprovider.go` + `mask.go` 合并入 `apikey.go`；测试同步合并 |
| 2026-04-25 | **model domain 完成**：7 步套路全跑完。domain（ModelConfig + 4 sentinel）→ store（9 集成测试）→ app（Service + PickForChat，12 单测）→ handler（GET + PUT，7 E2E 测试）→ errmap 4 条 → curl 冒烟 6 场景全通 |
| 2026-04-25 | **conversation domain 完成**：7 步套路全跑完。domain → store（11 集成测试）→ app（Create/List/Rename/Delete，11 单测）→ handler（POST/GET/PATCH/DELETE，6 E2E 测试）|
| 2026-04-25 | **chat domain 完成（Phase 2 版）**：Eino ReAct Agent 驱动，per-conversation 队列化（buffered channel 5）；SSE 15s keep-alive；ContentExtractor 7 种格式 + Vision；auto-titling；FTS5 全文索引（`CGO_CFLAGS="-DSQLITE_ENABLE_FTS5"`）；8 sentinel + errmap 全覆盖 |
| 2026-04-25 | **目录重组**：`backend-new/` → `backend/`；旧 Electron 代码移入 `legacy/`；`.gitignore` 按标准 Go 重写。Phase 6 原子切换内嵌完成，从路线图移除 |
| 2026-04-25 | **[doc-fix] 文档补全**：model.md / conversation.md 完整详设计；api-design.md / database-design.md / error-codes.md 同步 |
| 2026-04-26 | **[feat] apikey.ModelsFound 持久化**：`APIKey` entity 新增 `ModelsFound []string`（GORM `serializer:json`）。前端配模型时直接用作下拉选项 |
| 2026-04-26 | **[fix] SSE buffer 扩容**：`infra/events/memory/bridge.go` `defaultBufferSize` 64 → 2048，解决 DeepSeek 等快速 LLM 大量 token 事件被丢弃导致回复不完整的问题 |

### Phase 3：工具锻造（2026-04-26）

| 日期 | 内容 |
|---|---|
| 2026-04-26 | **Phase 3 开工：tool domain layer**。`domain/tool/tool.go`：5 个 entity + ExecutionResult（定义在 domain 避免循环依赖）+ 9 sentinel + Repository（30 方法）。ToolVersion 合并 pending 职责 |
| 2026-04-26 | **`infra/sandbox/python.go`**：PythonSandbox 实现，Python subprocess + 30s 超时；driver 模板追加 __main__ 桥接；Python 异常返回 ok=false 不上升为 Go error。8 测试全绿 |
| 2026-04-26 | **`domain/events/types.go` 追加 6 个 tool SSE 事件**：`tool.code_streaming` / `tool.created` / `tool.pending_created` / `tool.test_case_generated` / `tool.test_cases_done` / `tool.test_cases_not_supported` |
| 2026-04-26 | **`infra/db/schema_extras.go` 重构**：单列表 → 按 table 分组的 extraGroup 结构。追加 tools 部分唯一索引 `UNIQUE(user_id, name) WHERE deleted_at IS NULL` |
| 2026-04-26 | **[arch] 工具搜索方案切换**：chromem-go 向量搜索 → LLM 排序（SearchTool 把全部工具发给 LLM 选最相关 N 个）。删除 `infra/vectordb/`，移除 chromem-go 依赖 |
| 2026-04-26 | **`infra/store/tool/tool.go`**：完整 Repository 实现，30 个方法，覆盖 Tool CRUD / Version+Pending / TestCase / RunHistory / TestHistory。11 集成测试全绿 |
| 2026-04-26 | **`app/tool/ast.go`**：Python subprocess AST 解析，提取函数名/参数（含 required/description/default）/返回值。Google-style docstring 解析，无 docstring 不报错 |
| 2026-04-26 | **`app/tool/tool.go`**：Service 完整实现，含 CRUD / 版本管理 / pending 生命周期 / sandbox 执行 / 测试用例 / LLM 生成测试用例（emit callback 解耦 HTTP）/ 导入导出 |
| 2026-04-26 | **`app/agent/forge.go`**：5 个 System Tool（SearchTool/GetTool/CreateTool/EditTool/RunTool）+ ForgeTools 工厂。SearchTool 用 LLM 排序；Create/EditTool 流式推 ToolCodeStreaming SSE；RunTool att_id 解析 |
| 2026-04-26 | **Phase 3 装配 + 冒烟**：handlers/tool.go（22 端点）+ errmap 9 条 + main.go（Migrate 5 表、创建 sandbox/toolService、ForgeTools 注入 chatService.SetTools）。curl 验证 create / list / :run / versions / run-history / delete 全通 |
| 2026-04-26 | **[feat] testend 工具面板**：新增 Tools tab（System + User Tools 子面板）。`GET /dev/tools` 列出注册 tool；`POST /dev/invoke` 直接调用任意 system tool（绕过 LLM agent，用于冒烟） |
| 2026-04-26 | **[feat] testend SSE 双视图 + chat tool 步骤卡片**：SSE 标签页加 Stream/Raw 切换；chat 面板 assistant 消息内嵌 tool step collapsible 卡片（⚙ running → ✓ ok/✗ error） |
| 2026-04-26 | **[feat] chat tool call 可见性**：`app/chat/chat.go` 拆分为 4 文件（chat / pipeline / interceptor / util）。新增 `toolInterceptor` 包装所有 tool，发布 `chat.tool_call` / `chat.tool_result` SSE（含 `summary` 人类可读）。`Summarizable` 接口 + `CoreInfo` 方法 |

### Phase 3 后基础设施优化轮（2026-04-27 起）

Phase 3 完成后未直接开工 Phase 4，而是进入一轮深度优化与调研——chat 架构重构、生产 bug 收尾、开发体验改进、Claude Code 内部机制调研、SQLite 驱动迁移、桌面端分发方向定型。

#### Chat 基础设施重构（2026-04-27）

| 日期 | 内容 |
|---|---|
| 2026-04-27 | **[refactor] 重构决策**：审计 chat 管线发现 3 处系统性设计债——DB schema 拍扁多列 / Eino 黑盒渗透 app 层 / collectStream 收完再推。新增 `archaved/refactor-chat-infra.md` 设计文档 |
| 2026-04-27 | **[arch]** 自实现 ReAct Loop 替换 `react.NewAgent + Callback`：Eino v0.8.11 `OnEnd` 对流式不触发，改直接调 `ToolCallingChatModel.WithTools().Stream()` |
| 2026-04-27 | **[refactor Step 1]** 新建 `internal/infra/llm/`（4 文件 OpenAI-compat + Anthropic 原生）替代 Eino，`iter.Seq[StreamEvent]` 替代 channel |
| 2026-04-27 | **[refactor Steps 2-11]** chat 基础设施全量重构完成：Tool 接口 4 方法、Message 拆 Block 模型（5 类型）、message_blocks 新表、自实现 ReAct 替 Eino agent、`app/chat/` 拆 5 文件、Eino import 全清 |
| 2026-04-27 | **[refactor 测试补全]**：infra/llm 21 / app/agent 35 / app/chat 18 / store/chat Block 模型适配 + 3 新增。22 包全绿 |
| 2026-04-27 | **[fix]** 修 3 处 ReAct 严重 bug：多步循环 DB 覆盖（统一 allBlocks 累积一次保存）/ maxSteps 退出 stopReason 错 / 用户消息附件 block 缺元数据 |
| 2026-04-27 | **[refactor]** 代码清理：删 `app/agent/summarizable.go`；统一 `blocksToAssistantLLM`；修 S13 alias 违规 |
| 2026-04-27 | **[fix] T15-T19 补丁 5 条**：forge.go ctx helpers / GenerateTestCases 改 json.RawMessage / extractJSON 剥 markdown fence / extractTextContent 取最后 text block / chatRepo 共享单例 |
| 2026-04-27 | **[feat] Thinking 可见性**：新增 `chat.reasoning_token` SSE + `Message.ReasoningContent` 字段（DeepSeek-R1 history 重建必需）；testend 加 `🤔 Thinking…` 折叠块 |
| 2026-04-27 | **[fix]** 集成测试拍出 4 个生产 bug：created_at=0001 错排（OnConflict.DoUpdates 修）/ 取消流后助手消息丢失（detached ctx）/ web_search 返 null（切 lite.duckduckgo）/ 快速连发历史顺序错 |
| 2026-04-27 | **[test]** 集成测试 13 组（A-M）全通（真实 DeepSeek API），覆盖 CRUD / API Key / 分页 / 工具 / ReAct / Attachment / Auto-title / SSE messageId 等 |
| 2026-04-27 | **[doc-sync] events-design.md / database-design.md / chat.md** 全量同步：messages 表精简、message_blocks 新表、chat.tool_call_start / chat.reasoning_token 新增 |

#### Chat pipeline 二次重构（2026-04-27 后）

| 日期 | 内容 |
|---|---|
| 2026-04-27+ | **[refactor]** 移除 pipeline.go，引入 runner.go（commit b6a9199）：chat 执行管道二次拆分，为后续 context compaction 预留接口 |

#### 开发体验工程化

| 日期 | 内容 |
|---|---|
| 2026-04-27+ | **[devx]** Brewfile + Makefile setup target + 11 testend YAML collections（commit 6113d16）：`make setup` 一键检查 Xcode CLT / 装 Homebrew / 装依赖 |

#### Claude Code 内部机制调研

| 日期 | 内容 |
|---|---|
| 2026-04-28 | **[research]** Claude Code 内部机制调研：产出 `claude-code-research-documents/` 9 份主题报告 + `agent-core-upgrade.md` + `summary.md`，为 Phase 4-5 chat 终极版设计提供参考 |

#### SQLite 驱动迁移（2026-05-01）

| 日期 | 内容 |
|---|---|
| 2026-05-01 | **[infra]** SQLite 驱动 mattn → modernc.org/sqlite（纯 Go），三平台一行交叉编译，删 CGO_CFLAGS。性能慢 1.5-2x（本地无感） |

#### 桌面端分发方向定型（2026-04-30 ~ 2026-05-01）

| 日期 | 内容 |
|---|---|
| 2026-04-30 | **[doc]** 桌面端分发方向定型 + `desktop-packaging-notes.md` 落地：目标 Wails 原生桌面 app（窗口外壳 + 复用 httpapi，不走 binding）；分发 dmg/setup.exe/AppImage（v0.1 起 L3）；Python 沙箱短期 A、中期 C |
| 2026-05-01 | **[doc]** 常驻后台模式 + Notifier 接口决策：scheduler 不退出（关窗 ≠ 退出）。Phase 4 写 scheduler 时 `domain/notification/Notifier` 接口先行；桌面壳代码限 `internal/infra/desktop/` |
| 2026-05-01 | **[doc]** 决定不走 Wails binding：HTTP 等价但能复用 v1.2 transport（middleware/errmap/curl）；SSE 天然契合；binding 只换"类型同步"一项收益，OpenAPI 也能做到 |
| 2026-05-01 | **[refactor]** `schema_extras` guard 改 `db.Migrator().HasTable()` 替代 raw `sqlite_master` 查询；真正 GORM 写不出的 SQL（partial UNIQUE 等）仍走 raw exec |
| 2026-05-01 | **[refactor]** message_blocks 复合索引 `(MessageID, Seq)` 迁到 GORM tag（`index:idx_mb_msg_seq,priority:N`），删 schema_extras 对应 group |
| 2026-05-01 | **[cleanup]** 死代码清扫：删 3 个未发布的 `ToolTestCase*` event 类型（SSE 实际走 callback 不经 Bridge）；events-design.md 同步 |
| 2026-05-01 | **[arch]** pagination 迁到 `pkg/pagination` + S13 全代码补别名：4 store 反向 import 各自抄一份合并删 ~64 行；S13 加 `httpapi` 后缀全代码补 `*httpapi` 别名 |
| 2026-05-01 | **[fix] staticcheck 全套 5 修**：恢复误删 ListProviders/ListScenarios（deadcode 默认不扫测试）；SA1029 改 `//lint:ignore`；S1016 改类型转换。staticcheck 0 |
| 2026-05-01 | **[fix]** 5 处 `_ = err` 静默吞错改正：tool.newID 加 panic 与其他 newID 一致；tool.Import/Export 加 log.Warn；2 处 w.Write 加注释保留 |
| 2026-05-01 | **[review]** TODO 扫描：全代码仅 3 处 TODO 全是合法前瞻性标记（A1 中流执行 / context compaction 钩子点），无历史包袱 |
| 2026-05-01 | **[refactor]** `userID(ctx)` helper 统一到 `pkg/reqctx`：合 11 处重复；新增 `ErrMissingUserID` sentinel + `RequireUserID` helper。事故：sed 清空 apikey store，立教训"项目内禁用 sed 改 import / 函数名" |
| 2026-05-01 | **[review]** errmap 完整性反查：32 个 domain sentinel 全部已映射 ✅；补登记 `reqctxpkg.ErrMissingUserID` + `cryptoinfra.ErrUnsupportedVersion`（均 500） |
| 2026-05-01 | **[arch]** S5 / S6 降级为参考线：行数当硬规则会噪音（main.go DI / SSE 状态机 / Service 956 行都是结构必要）；改措辞"可读性优先于行数"。同步 backend-design.md |
| 2026-05-01 | **[review]** S13 别名全代码验证：176 处 internal import 0 处无别名 ✅，32 个别名全部规范后缀，100% 合规 |
| 2026-05-01 | **[refactor]** 跨 store 共享 Cursor 类型：4 store 的 `pageCursor` JSON tag 漂移，`pkg/pagination` 加共享 `Cursor` 类型，4 store 删本地副本统一为 `c` |
| 2026-05-01 | **[doc]** V1.2 文档全量校对：11 份反查代码 drift——testend-design 整体重写 / backend-design tree 更新 / chat.md pipeline→runner / 5 份 service-design 去 Eino 残留 |
| 2026-05-01 | **[arch]** backend-design.md 规范补完：新增 N6 / D6 / D7 / S15 / S16 / S17，扩 S9 detached context；新增 **T 系列测试规范**（T1-T4）+ **开发期工具纪律**（staticcheck / deadcode -test / 禁 sed 改 import） |
| 2026-05-01 | **[doc]** 创建项目根 `CLAUDE.md` + `backend-design.md` 拆分：把全部代码规范从后者搬到前者（自动加载进 context）；后者退化为"项目说明书"。前者 378 行 / 后者 304 行 |

#### Tool 系统大重构（2026-05-02 起，Phase 0-8 计划，Phase 0-7 完成，Phase 8 进行中）

对照 Claude Code 调研后认定当前 tool 实现"基础设施过于薄"。原 7 阶段计划中途扩成 8 阶段（Phase 5/6 改造为 DB schema 统一 + SSE 3-event entity-state 模型，原 Phase 5 重建 system tools 撤销）。

**关键决策**：(1) 推流仍 `bridge.Publish` 直调不引 emit 抽象；(2) agent 包改 tool / 原 app/tool 改 app/forge；(3) §S12 例外允许 tool/ 嵌套子包；(4) 每 user-facing domain 一个 SSE entity-state 事件；(5) Phase 5 数据库统一（forge_executions 合表 / Forge.Pending / Message errorCode 等）。

| 日期 | 内容 |
|---|---|
| 2026-05-03 | **[devx]** 测试包 `internal/e2e/` → `backend/test/`（build tag `e2e` → `pipeline`）；Makefile 加 `test-pipeline` / `test-console`。`forgeapp.Service.PublishSnapshot` 是 forge SSE 唯一发布点（与 chat.runner 同模式） |
| 2026-05-03 | **[test] Step 3 chat 真实端到端 5 场景全绿**（~11s）：SimpleText 流式快照单调生长 / MissingModelConfig 错误码 stub 落库 / ToolCall search_forges 配对断言 / CancelMidStream detached-ctx 终态 / ReasoningModel reasoning+text 双 block 分离 |
| 2026-05-02 | **[test] Step 2 E2E harness 落地**：`backend/internal/e2e/`（`//go:build e2e` 门控）3 文件 harness/seed/sse；真实 DI + entity-state SSE 解析 + 等待器；`make test-e2e` smoke 680ms 通过 |
| 2026-05-02 | **[fix] Step 1 防御性代码大摸排**：扫全 backend `_ = err` / 静默 fallback，修 6 处真问题 + 2 处加 log.Warn + 1 处 conversation 时戳 flake；判定 9 处合法保留。新增 `.env` 注入机制 + Makefile 三 targets（test / test-integration / test-all） |
| 2026-05-02 | **[doc] Phase 7 文档同步 #2**：8 份跟齐 Phase 5/6 改造 — events-design 重写 entity-state 3 事件 / database-design 表名 + 新字段 / forge.md 大改 / chat.md SSE 章节重写 / api-design 端点合并 |
| 2026-05-02 | **[refactor] Phase 6 SSE 12 → 3 entity-state 事件**（chat.message / forge / conversation），载荷 = entity GET 形状完整快照。`runner.go` 三 helper 是 chat.message 唯一发布源；forge tool 走预分配 ID（draft 失败干净丢弃）；pre-LLM 错误也走 stub message。22 包绿 |
| 2026-05-02 | **[refactor] Phase 5 DB schema 重构** — 4 领域：forge_run/test_history → forge_executions 统一表 / Forge.Pending 计算字段 / Message 加 errorCode/errorMessage/updatedAt / attachments 软删 + 改名。22 包绿 |
| 2026-05-02 | **[refactor] Phase 0 清理过时 tool**：删 `app/agent/system.go` + `web.go` 共 8 件（read_file/write_file/list_dir/run_shell/run_python/datetime/web_search/fetch_url）；新一代 system tools Phase 5 重建 |
| 2026-05-02 | **[refactor] Phase 0 GenerateTestCases 去流改普通 HTTP**：底层 `llm.Generate` 本就非流式所谓"流"是化妆。`GenerateEvent` 删；新增 `GenerateResult{NotSupported, Reason, TestCases}` |
| 2026-05-03 | **[refactor]** 重复实现 8 项整改：新建 `pkg/idgen` / `pkg/llmparse` / `pkg/llmclient` 三共享包；`forgeapp.PublishSnapshot` 收敛 6 处；`response.StreamSSE[T]` 泛型 helper；`idAndAction` 等 helper 合并 |
| 2026-05-02 | **[fix]** testend 前端跟齐 Phase 0-3 重命名 + 新事件 + destructive UI：tab-sse 改 forge.* 事件；tab-tools generateTestCases 改普通 fetch；tab-sql quick query 改 forges/forge_versions/f_/fv_；destructive UI 红色徽章落地 |
| 2026-05-02 | **[doc] Phase 4 文档同步 #1**：Phase 0-3 改造跟齐 6 文件 — CLAUDE.md §S15 ID 前缀 + §S18 Tool 接口规约 / events-design ChatToolCall.destructive / database-design / api-design / backend-design tree / forge.md & chat.md |
| 2026-05-02 | **[refactor] Phase 3 Tool 接口扩 10 方法 + forge tool 重写**：3 静态元字段 + 3 钩子；destructive per-call AI 自报 + 存 DB；5 forge tool 移到 `tool/forge/` 子包；reqctx 包重组（agentrun.go 装 ctx helpers）；runTools 改 IsConcurrencySafe 分批。22 包绿 |
| 2026-05-02 | **[arch] Phase 2 `agent/` → `tool/` 包重组 + S12/S13 例外条款**：CLAUDE.md 加 §S12 例外（tool 是 framework meta-namespace 允许嵌套子包）+ §S13 嵌套子包别名规则 |
| 2026-05-02 | **[refactor] Phase 1 大重命名 tool → forge**（"用户造的 Tool"全语义改 Forge）：6 entity / 5 表 / ID 前缀 t_→f_ / 22 HTTP 端点 / 5 LLM-facing 名 / 3 Bridge 事件 / testend 9 文件 161 处。**保留** Tool 接口 / ChatToolCall / ToolCallID / tc_ 前缀 |

#### 沙箱方向迭代设计（2026-05-02）

| 日期 | 内容 |
|---|---|
| 2026-05-03 | **[devx]** devbox + Makefile 二轮整理：`devbox.json` env 加 `$HOME/go/bin` 入 PATH；Makefile 加 `_require-devbox` / `_refuse-inside-devbox` 两守卫；删 `EXPORT_RESOURCES` + `ensure-resources` piggyback；help 输出明确 Setup vs Daily 分组 |
| 2026-05-03 | **[devx]** Makefile 收成 5 核心命令 + help 默认 target：`environment` / `test-console`（air live reload）/ `test-unit` / `test-pipeline` / `stop`。删 `make dev` / `make logs` / `LOG_FILE`。README 重写 5 命令版 |
| 2026-05-03 | **[devx]** 依赖基线统一 + devbox 落地：(R1) Go 1.25.5 + zap/x/net/x/tools 小升；(R2) modernc.org/sqlite v1.23→v1.50（27 minor）；(R3) `devbox.json` 锁 go@1.25/python@3.12/uv@0.11/gnumake；`scripts.bootstrap` 装 air/staticcheck/deadcode + 沙箱资源。~190 单测全绿 |
| 2026-05-03 | **[fix]** draft forge 首拒后该消失但留下空壳：`Service.RejectPending` 末尾若 `ActiveVersionID==""` 触发 `s.Delete(forgeID)`；已 active 的 forge 行为不变。新增 2 测试 + forge.md §8.5 |
| 2026-05-03 | **[fix/devx]** 沙箱迭代 1 出场 bug：`parse()` 用 `fmt.Errorf("%w: %v", ...)` 不再裸吞 cause；Makefile 加 `ensure-resources` target（dev/test-console/test-pipeline 前置）；新增 `smoke_bootstrap_test.go`（按 §T3 门控） |
| 2026-05-03 | **[doc] 沙箱迭代 1 Phase G 完成：8 份契约文档全量同步** — progress-record / CLAUDE.md / error-codes（4 行 FORGE_*）/ database-design（forge_versions 8 列 + forges 1 列）/ events-design / api-design / desktop-packaging-notes / forge.md（最大份 ~360 行新内容） |
| 2026-05-03 | **[infra/refactor/feat]** 沙箱迭代 1 实施完成（Phase A-F）：sandbox 包 10 文件重写 / Forge + ForgeVersion 加 env 字段 / Sandbox 接口 6 方法 / Service lifecycle 改造（CreateDraft / Accept env 守卫 / trimEnvBuffer LRU）/ Tool schema deps + errmap 4 行 + testend env-badge。~80+13+19+11 测试全绿 |
| 2026-05-03 | **[doc]** 沙箱迭代 1 应用 MVP "punt 给 AI 自救" 哲学：砍 5 个"自动恢复"机制（启动期 reconcile / venv 完整性校验 / Run 时 evicted 自检 / 孤儿 GC / 半成品清理），保留 2 个真兜底（mac codesign / EnvError 收集）。stage 名 downloading→preparing 修正 |
| 2026-05-03 | **[doc]** 沙箱迭代 1 反查 5 处认知偏差：wheel 共享是 clone/hardlink；Python 走 embed.FS + UV_PYTHON 离线；uv stage 名 Resolved/Prepared/Installed；macOS 元凶是 `com.apple.provenance` 须 codesign 重签。`desktop-packaging-notes.md §六` 写入公证 entitlement |
| 2026-05-02 | **[doc]** 沙箱迭代 1 设计文档完整重写（v2）：用户动线开篇；EnvID 算法（sha256 + 标准化 + 排序）；磁盘布局；N=3 LRU；ForgeVersion 持环境状态；EnvStatus 5 态状态机。**vs 之前稿**：砍异步 sync worker / 不引新 SSE 事件类 / sandbox 不直接 bridge.Publish / create_forge 进 pending / 删 SandboxTimeout |

#### 测试流水线迭代设计（2026-05-03）

| 日期 | 内容 |
|---|---|
| 2026-05-03 | **[fix]** sandbox `uv sync` 加 `--no-workspace` 试图阻止 `.venv` 外溢（事后查 flag 不存在，05-04 回退） |
| 2026-05-03 | **[infra/test]** 流水线迭代 1 Phase G 收尾：Makefile 加 `test-pipeline` / `-quick` / `-live` 三 target；CLAUDE.md 加 T6（fake LLM 约定）。**迭代 1 全 7 段完工** |
| 2026-05-03 | **[infra/test]** Phase E+F：`chat_forge` (3) / `errcodes` (16+3) / `isolation` (3) pipeline tests。**68 测全绿，2.6s** |
| 2026-05-03 | **[infra/test]** Phase D：`forge_http` (12) + `forge_lifecycle` (4) pipeline tests，`RequireForgeResources` gate |
| 2026-05-03 | **[infra/test]** Phase C：5 个 chat 场景 pipeline tests（basic/react/autotitle/queue/attachment）；harness `SetMaxOpenConns(1)` 修 in-mem SQLite 多连接 bug。**30 测全绿，2.3s** |
| 2026-05-03 | **[infra/test]** Phase B：`apikey` (5) / `model` (4) / `conversation` (4) pipeline tests；fake_llm 加 `/v1/models`。**19 测全绿，1.1s** |
| 2026-05-03 | **[infra/test]** Phase A：fake LLM 基础设施（`fake_llm.go` httptest + 5 scripts + 5 helpers）；harness 修 sandbox drift；4 chat 测试切 fake LLM 离线可跑。**5 测，1.0s** |
| 2026-05-03 | **[doc]** 流水线迭代 1 设计文档：`adhoc-topic-documents/test-pipeline-iteration-documents/01-foundation-and-coverage.md`，~13h / 7 phase / fake LLM + 真 sandbox 双层 / ~80 测覆盖目标。完整方案见该文件 |

#### Claude Code tool 抄录研究（2026-05-03）

| 日期 | 内容 |
|---|---|
| 2026-05-03 | **[research]** CC tool 抄录启动：v2.1.88→v2.1.126 delta + 41 工具 inventory（8 P0 / 7 P1 / 13 P2 / 10 Skip）。新建 `02-tools-deep/00-inventory.md` |
| 2026-05-03 | **[research]** deep-dive `01-file-ops.md`：Read/Write/Edit Piebald 原文 + Go 实现 6 节。MultiEdit 已下线（issue #11125 not planned），inventory P1 7→6 |
| 2026-05-03 | **[research]** deep-dive `02-search.md`：Grep（ripgrep wrapper 12 字段）+ Glob（doublestar + mtime-desc + 1000 cap）。LS 已下线，文档留 A/B 两方案待决 |
| 2026-05-03 | **[research]** deep-dive `03-shell.md`：Bash 描述全 41 子文件抓取 + Go 实现（cwd 状态机 + dangerous detect + background + 30K 截断）。**v1 不做 OS-level sandbox**，用 PathGuard + Ask pattern 替代 |
| 2026-05-03 | **[research]** deep-dive `04-web.md`：WebFetch（HTML→md + 小模型摘要 + 15min cache，独立 context）+ WebSearch（CC 美国限制改接 Tavily）。Forgify 走 Jina Reader 优先 + html-to-markdown fallback |
| 2026-05-03 | **[research]** deep-dive `05-ux-tasks.md`：AskUserQuestion + TaskCreate 族 4-in-1 + TodoWrite legacy + EnterPlanMode 简评。**02-tools-deep 系列收官**，5 篇覆盖 15 P0/P1 |
| 2026-05-03 | **[research]** **02-tools-deep 13 决策复审 + V1 清单**：8 P0（Read/Write/Edit/Glob/Grep/Bash/WebFetch/WebSearch）+ 5 P1（Task 族 4 + AskUserQuestion）+ 框架重构（execution_group / AgentState / PathGuard）= **13 工具 + 0.6d 框架，~7 天**。详 13 决策见 `02-tools-deep/` 各篇 |
| 2026-05-03 | **[refactor]** 框架重构 F1-F10 完工（V1 工具前置）：新增 `pkg/agentstate` + `pkg/pathguard`（11 测）+ `pkg/reqctx/agentstate.go`（4 测）；Tool 接口 10→9 方法（删 `IsConcurrencySafe`）；`StandardFields` 加 `ExecutionGroup`；`partitionByConcurrencySafety` → `partitionByExecutionGroup`（按 LLM 自报 group 调度）。CLAUDE.md §S18 同步 |
| 2026-05-03 | **[fix/devx]** `llm_integration_test.go::testKey()` 从 `"shabi"` placeholder 改 `requireKey(t)+t.Skip`（per §T3）；CLAUDE.md 加"测试命令选择"小节（禁直跑 `go test ./...`） |
| 2026-05-03 | **[feat]** O1 Read tool：`app/tool/filesystem/{filesystem,read}.go`，9 方法 + 19 单测。chat 层 wire AgentState（convQueue 字段 + ctx 注入）让 must-Read-first 守卫工作 |
| 2026-05-03 | **[feat]** O2 Write tool：`write.go`，9 方法 + 13 单测。原子写 `CreateTemp+Rename`，覆写保留原 mode |
| 2026-05-04 | **[feat]** O3 Edit tool：`edit.go`，9 方法 + 19 单测，含 `#51986 markdown bold 5 处全替`。信任 stdlib `strings.Replace`，显式报 N occurrence 比 CC "All replaced" 透明 |
| 2026-05-04 | **[fix]** sandbox `sync.go` 删 `--no-workspace`——uv 0.11.8 无此 flag（昨日加错），真正建 `.venv` 的源头是 devbox python venvShellHook（已修） |
| 2026-05-04 | **[feat/test]** O4 file-ops 装配 + pipeline test：`main.go` + `harness.go` 装 PathGuard + FilesystemTools；新建 `test/filesystem/` 3 场景（ReadEditClosedLoop / WriteWithoutReadDenied / PathGuardDeniesSensitivePath）。29.7s 通过 |
| 2026-05-04 | **[feat]** S1 Grep tool：`search/{grep,grep_rg,grep_stdlib}.go`，9 方法 + 28 单测。双后端：rg 在 PATH 走 shell out（10-100× 加速），缺时 stdlib `WalkDir + bufio + regexp` 兜底；surface 一致（同 args / 输出 / head_limit）。新增 `bmatcuk/doublestar/v4` 支持 `**` glob。装到 `main.go` + `harness.go` |
| 2026-05-03 | **[devx]** 项目根 + Makefile + devbox 瘦身：删 `.githooks/` / `.air.toml` / `tmp/` / `scripts/`；Makefile 砍 4 项（resources / _refuse-inside-devbox 等 inline 进调用方）；devbox.json 删 `python@3.12`（venvShellHook 重建 `.venv` 的坑）+ `uv@0.11`（仅装饰） |

---

## 3. Phase 4-5 路线（粗粒度）

各 Phase 开工前在此段展开细节。当前状态均为 ⬜。

### Phase 4：工作流能力（~20h，最大一块）

workflow（DAG + 状态机）+ flowrun（执行实例）+ 节点系统（LLM / Tool / Trigger / Approval / Variable 5 类）+ scheduler（cron / fsnotify / HTTP webhook）+ chat 再升级支持"对话创建工作流"。执行引擎自实现（Eino 已全面移除，不再依赖 eino/compose）。

**桌面端预留**（来自优化轮决策）：
- `Notifier` 接口在此阶段定义（domain/notification/），scheduler 依赖
- `Preferences` service 在此阶段定义（含 startOnLogin / missedTaskPolicy 等配置项）
- scheduler 状态全部走 store 持久化；时间源用 monotonic 算间隔、wall clock 调度具体时间；错过任务策略明确决策（skip/runOnce/runAll）

### Phase 5：智能化（~15h）

knowledge + document（本地 sqlite-vec）+ intent（ReAct Agent）+ mcpserver（`mark3labs/mcp-go`）+ skill（V1 浅版：打标签的工具）+ chat 终极版（意图识别 → 工作流推荐 → 自动建草稿）。

**风险点**：sqlite-vec 是 C 扩展，需验证 modernc.org/sqlite 加载兼容性。Phase 5 开工前先做兼容性 spike，跑不通则评估替代方案（备选：换回 mattn 接受 CGO / 用别的本地向量存储）。

---

## 4. 规范/原则演化

按时间倒序，查最近变化用。

| 日期 | 变化 |
|---|---|
| 2026-05-01 | **桌面端架构边界定型**：`internal/infra/desktop/` 仅 `cmd/desktop` import，`cmd/server` 编译产物保持纯净（不含 Wails / 托盘 / 通知代码）。transport 层永远只 httpapi 一份，不走 Wails binding |
| 2026-04-26 | **S14 hook 落地**：在 `.claude/settings.local.json` 配 PostToolUse hook，编辑 `backend/internal/` 下文件时自动注入文档同步提醒 |
| 2026-04-25 | **S3 扩展"严禁藏错误"**：`_ = err` 静默跳过严禁——隐藏的错误会在意想不到的地方爆发（教训：FTS5 虚拟表建失败后触发器仍建成，INSERT 时才炸）|
| 2026-04-25 | **S12 扩展**：主文件用包名规则推广至 app / infra/store 全层；明确"仅 Service 实现接口 / 小工具函数"合并入主文件，不单独建文件 |
| 2026-04-25 | **providers.go 归属原则**：辅助注册表放在消费它的层（非 domain）；domain 层只放 entity + sentinel + 接口 |
| 2026-04-24 | 立 **设计原则 #7 + S14 "文档同步纪律"（最高优先级）**：每次改代码联动三处文档；发现不符立刻修 |
| 2026-04-24 | 立 **设计原则 #6 "反校验剧场"**（单开发者 + 本地 Electron 不搞前端已覆盖的校验）|
| 2026-04-24 | 立 **"spec 优先于邻居文件"** 审计纪律（避免复制 pre-existing 违规）|
| 2026-04-24 | 文档结构三层分工：`backend-design.md`（规范） / `service-contract-documents/`（索引） / `service-design-documents/`（详设计） / `progress-record.md`（进展） |
| 2026-04-24 | 立 **S13 包命名**（三层同名 + `<name><role>` 调用方别名）|
| 2026-04-24 | 立 **S12 包结构**（domain 平铺按概念拆，禁子目录）|
| 2026-04-23 | 立 **设计原则 #5 "端到端推演先行"**（每 domain 开工前走完整数据流）|
| 2026-04-23 | 路线图升级：V1.0 重写 → Agentic Workflow Platform 完整愿景 |
| 2026-04-23 | S11 扩展为 **"双语 + 节制"** 完整规则；全量瘦身 ~420 行冗余注释 |
| 2026-04-22 | 立 **S11 双语注释规范** |
| 2026-04-22 | 定 **12 条契约标准**（N1-N5 / D1-D5 / E1-E2）|
