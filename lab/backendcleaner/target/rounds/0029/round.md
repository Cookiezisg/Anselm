---
# Round 0029 — todo（波次 1 · M1.11）TodoWrite 式重铸

类型 / 目标：M1.11 todo 重写——把旧的「4 工具 CRUD 数据库」重铸为 Claude Code 的 `TodoWrite` 式工作草稿本。**波次 1 最后一个模块，收官**。

## 核心方针（一句话）
**todo = Agent 常驻草稿本：单工具整列替换、作用域 (conversation, subagent?)、scope_id 多态键；两条硬指标——「LLM 真用」(双层可见) + 「前端真看见」(messages 流 live + REST 初值)——在设计层钉死。**

## 考古发现（旧实现评估 = 错误抽象，非闲置）
对的概念 + 错的形态（≠ permissions 的整个错）：
- **三处 doc 吹的全是死的**：① 注入没接（`app/todo` 只被 4 工具 + main import，无任何执行面注入清单 → LLM 看不见自己的清单）；② 前端看板假（真桌面 app 的 `todo` 通知 handler 返 `[]`；`NotificationsDrawer` 的 "TodoTab" 实为 Ask 审批 tab、误名）；③ REST `GET /conversations/{id}/todos` 后端根本不存在，testend 在调死链。
- **三个死字段**：`blocked_by`/`owner`/`metadata` 无人写读。
- **病根**：照"项目管理数据库"建模（4 工具逐条 CRUD + 依赖图 + ownership），但 LLM 要的是"常驻草稿本"。漏掉唯一价值点（清单常驻模型眼前）。

## 关键决策
1. **整列替换**（TodoWrite 心智）：1 工具 `TodoWrite` 发整张清单、整行 upsert；item 3 字段 `content/activeForm/status`(3 态)、无逐项 id。砍 blocked_by/owner/metadata/description/`deleted` 状态。
2. **作用域 = (conversation, subagent?) · scope_id 多态键**：`scope_id = subagent_id ?? conversation_id`（多态 owner 引用，kind ∈ {conversation,subagent}，同 relation `from_id`，两种 id 全局唯一故天然 PK，无 surrogate/COALESCE）。**subagent 隔离**——subagent 写自己的清单、不污染父看板。旧 `owner` 字段做对了（owner 是清单的作用域、非 item 属性）。
3. **「LLM 真用」= 双层可见性**：① 工具结果回显（写完即在上下文）；② 每轮 `SystemReminder(ctx)` 注入未完成清单（loop M2.2 接）。修旧设计漏掉的注入。
4. **「前端真看见」= REST 初值 + messages 流 live**：`GET /conversations/{id}/todos?subagentId=`（初值）+ 写入推 messages 流 `signal`（`scope=conversation`、`node.type=todo`、payload `{conversationId,subagentId?,todos}`）。锚定对话（subagent 清单也锚父对话才到达前端订阅）、subagentId 入 payload 嵌子树。**不走 notifications 收件箱**（旧错：刷屏 + 前端返 `[]`）。
5. **reqctx 双种子**（M0.1 扩展）：补 `conversation.go`——`Set/Get/RequireConversationID` + `Set/GetSubagentID`。todo 是首个对话级模块；**subagent 种子提前埋**（写入方 subagent loop = 波次 3），同 M1.1 给 orm 补 ErrConflict 的模式。
6. **无 HTTP 错误码**：校验只在 `TodoWrite` 工具结果里回字符串给 LLM 自纠、永不冒泡 HTTP → plain `errors.New` sentinel（非 errorsdomain.New，S20）。整个退出 error-codes.md。

## scope 映射（修正用户初始偏好，更正确）
用户偏好"scope 叫 todo"。读 stream 协议后正确映射 = **`Node.Type="todo"`（事件类型）+ `scope.Kind=conversation`（渲染锚点）**——协议明确 scope.Kind=锚点≠事件类型，且 subagent 嵌在对话树里非独立锚点（scope.ID 必为 conversation_id 才到达对话订阅）。用户意图（标识为 todo + 带 conv/subagent）完全满足。

## 新实现
- **reqctx**：`conversation.go`（双种子 + ErrMissingConversationID）。
- **domain**：`Item{content,activeForm,status}` + `List{scope_id pk, ws, conversation_id, subagent_id*, items json, 时间戳, deleted_at}` + 3 状态 + MaxItems(64) + 3 plain sentinel + Repository{GetByScope, Upsert}。
- **store**：orm 一行一作用域，scope_id 天然 PK；GetByScope(ErrNotFound→nil,nil)；Upsert(Get→Create 或 mutate+Save 保 created_at)；DDL todos 表 + ws/conversation 索引。
- **app**：Service New(repo,bridge,log)；Write(读 ctx 作用域+normalize+Upsert+broadcast+回显)、Get、GetForScope(REST 显式)、SystemReminder(loop 注入)；broadcast 推 messages 流；render(整列)/reminder(未完成+计数)/normalize 助手。
- **handler**：`GET /conversations/{conversationID}/todos?subagentId=` 只读。

## 测试（全离线，0 Token）
store 4（GetByScope 空→nil / Upsert insert+replace 保 created_at / ws 隔离 / main vs subagent 异行）；app 6（Write 持久+渲染+broadcast 校验 scope=conversation·node.type=todo·payload / subagent 隔离但锚对话 / 空写清空 / 缺 conversation 报错 / normalize 校验 / SystemReminder open vs all-done）；reqctx 3（双种子 set/get/require + 空串视缺 + subagent 可选共存）。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet ./internal/...` 0 · `go test -race`（store 2.3s / app 2.8s / reqctx 0.9s 全 ok）· `go mod tidy` 无 diff。

## 契约（6 件）
domains/todo.md 整篇重写（TodoWrite 心智、去 RAG 式 CRUD）；database.md（注册表 td_→`-`/`List`、S15 删 td_、新增 4.4 Todo 段 scope_id 多态键）；api.md（新增 GET todos）；events.md（messages 流 todo signal）；error-codes.md（删 3 个 TODO_* 码）；contract-changes #9。

## 遗留 / 跨波次接线
- **`TodoWrite` 工具**（app/tool 才建）→ 波次 2/3。
- **loop 每轮调 `SystemReminder` 注入**→ M2.2。
- **subagent loop 埋 `SetSubagentID`**→ 波次 3。
- **messages-bridge 实接 broadcast**→ M7 boot 装配。
- **TodoHandler 注册 + 前端真任务看板**（GET 初值 + 订 messages todo signal + 按 subagentId 嵌子树）→ 覆盖回 backend/ 后前端兼容期。
- **对话删除级联清理** todo 清单 → 后波次。

## 波次 1 收官
M1.1–M1.8 ✅ + M1.9 ⏭️解散 + M1.10 ✅ + **M1.11 ✅** → **波次 1 全部完成**。下一步波次 2（tool 基础 + loop + 叶子工具）。
