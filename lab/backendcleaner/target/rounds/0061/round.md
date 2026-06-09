# Round 0061 — M7 中央装配② `bootstrap.Build` 总装（composition root 下半，**点亮整个后端**）

类型 / 目标：R0060 填完 DIP 洞（适配器层）后，R0061 = **把 20+ Service 按依赖序焊成一个能跑的 HTTP server**。这是 backend-new 第一次真正点亮——`cmd/server/main.go` 从 52 行 health-stub 收薄成调 `bootstrap.Build`。

**已就绪（无需新建）**：transport 层全建（24 handler 统一 `New<X>Handler(svc,log)` + `Register(mux)`、middleware 6 件、`router.Chain(mux,log,wsResolver)`、`response.*`）；DIP 适配器全建（R0060：model resolver ×4 + ConversationSummary + ModelInfoLookup + 3 renderer + Dispatcher + RefResolver）；19 store（`New(db)` + `var Schema []string`）；infra（`db.Open`/`db.Migrate`、`stream.New(buf)`、`llm.NewFactory`、crypto/sandbox managers）。**R0061 只是装配代码 + toolFactory + boot/shutdown + main，零新 domain/store/infra。**

## 已验证装配面（亲 grep）

**DB / migrate**：`db.Open(db.Config) (*ormpkg.DB, error)`（glebarez 纯 Go sqlite + PRAGMA fk/WAL）→ `db.Migrate(db, stmts...)`，stmts = 19 store 的 `var Schema []string` 全拼。

**store**：19 个统一 `New(db *ormpkg.DB) *Store`，唯 mcp `New(db, encryptor cryptodomain.Encryptor)`。

**SSE 三总线**：`stream.New(bufSize) *Bus`（E1：messages / entities〔eventlog〕/ notifications，永不再加）；Bus 实现 `streamdomain.Bridge`（NotificationHandler 等消费）。

**handler**：24 个 `New<X>Handler(svc *<x>app.Service, log) *<X>Handler` + `(h) Register(mux Registrar)`；特例 Notification（+`bridge streamdomain.Bridge`）、Scenarios（无参静态）、Model（`*modelapp.CapabilityService`）、Flowrun（`*schedulerapp.Service`）。

**注入方法（装配后 wire）**：
- `SetRelationSyncer(relationapp.Service)`——11 实体（function/handler/agent/control/approval/trigger/mcp/document/conversation/workflow/skill）
- `catalog.RegisterSource(src)`——各 Service `AsCatalogSource()`
- `agent.SetInvokeDeps(InvokeDeps{Resolver, Tools func()[]Tool, Knowledge})`
- `workflow.SetResolver(bootstrap.NewRefResolver(...))`
- `chat.RegisterMentionResolver(r)`——5 类（document/function/handler/workflow/agent `AsMentionResolver`）
- `mcp.SetClientFactory(f)`、`sandbox.RegisterInstaller/RegisterEnvManager`
- skill `SubagentRunner` 注 subagent.Service（替 nil）

**boot 序列**：`sandbox.RestoreOrCleanupOnBoot(ctx)` → `handler.Boot(ctx)`（常驻进程）→ `mcp.Boot(ctx)`（连 server）→ `trigger.Attach(ctx,trg,wf)`（活跃 workflow 绑监听）+ `trigger.Start()`（起 listener）→ `scheduler.Recover(ctx)`（恢复在飞 flowrun）+ `scheduler.DrainFirings(ctx)`（处理积压点火）+ ticker。

**shutdown 逆序**：trigger.Shutdown → scheduler 停 ticker → chat.Shutdown（drain 队列）→ mcp.Shutdown → handler.Shutdown → `srv.Shutdown(ctx)`。

## Build() 架构

`bootstrap.Build(cfg) (*App, error)`，`App{Handler http.Handler; Boot(ctx); Shutdown(ctx)}`：

1. **数据层**：`db.Open` → `db.Migrate`(19 Schema) → 19 store（mcp 注 crypto encryptor）。
2. **infra**：`llm.NewFactory`、sandbox env managers、3×`stream.New`、blob、crypto。
3. **service**（依赖序）：先叶子（workspace/apikey/relation/catalog/notification/memory/model）→ sandbox（注 env managers）→ document/todo/attachment → quadrinity（function/handler/agent/trigger/mcp/skill/control/approval）→ workflow/flowrun/scheduler → conversation/messages/chat/subagent/contextmgr。
4. **适配器注入**（R0060 bootstrap）：model resolver ×4、ConversationSummary、ModelInfoLookup、3 renderer、Dispatcher、RefResolver；+ toolFactory（本轮建）。
5. **wire**：全 `SetRelationSyncer`、`catalog.RegisterSource`、`agent.SetInvokeDeps`、`workflow.SetResolver`、`chat.RegisterMentionResolver`、`mcp.SetClientFactory`、skill 注 subagent runner。
6. **transport**：mux + 24 handler.Register + `router.Chain(mux, log, workspaceSvc)`（workspace.Service 实现 WorkspaceResolver）。
7. **App**：返回 `{Handler, Boot, Shutdown}`，main 调 Boot → ListenAndServe → 信号 → Shutdown。

## toolFactory（本轮建，R0060 折入）

`buildToolset(services…) tool.Toolset`：**Resident** = filesystem(pathGuard)/search(pathGuard,log)/shell；**Lazy** = function/handler/agent/control/approval/workflow/trigger/document/memory/mcp/skill 各 `XxxTools(svc)` + web(picker,keys,factory,searchKeys,log)。dynamic-mcp（`DynamicTools(ctx,mcp)`）boot 时刷 / subagent Task 工具注 subagent runner。chat host 的 `Tools(ctx)` 在此 Toolset 上叠 search_tools + discovered。

## 分阶段（编译器兜底，每段独立 `go build ./...` 绿）

- **a 数据层**：`build.go` 骨架 + DB/migrate + 19 store + infra + 3 bus。
- **b service + 注入**：21 service 构造 + 适配器注入 + toolFactory + 全 Set*/RegisterSource。
- **c transport**：24 handler + mux + Chain。
- **d 生命周期**：App.Boot/Shutdown + main.go 收薄 + smoke（server 起 + /health 200）。

测试：bootstrap `TestBuild_BootsAndServesHealth`（Build → httptest → GET /health 200 envelope）；migrate 幂等；shutdown 不 panic。

验证：`go build ./...` + `go vet` + bootstrap test 绿；`make mock`（16 包）回归不破。

是否更干净（自证）：① 唯一 composition root，main 收薄成 ~30 行；② 依赖序显式（叶子→quadrinity→exec→chat），无隐藏全局；③ boot/shutdown 对称、graceful；④ 19 Schema 集中 migrate（无散落 AutoMigrate）；⑤ 适配器全在 R0060 备好、本轮只 new+wire。

遗留 / 下一步：R0062+ = 覆盖回 `backend/` + 前端/testend 兼容（依 contract-changes 施工图）。
