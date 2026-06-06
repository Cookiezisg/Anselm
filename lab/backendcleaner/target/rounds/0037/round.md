---
# Round 0037 — function 重写：版本模型去 accept + polling 剥离 + 抽 app/envfix（波次 3 起步）

类型 / 目标：波次 3 Quadrinity 执行体第一元 `function`。用户拍板三大简化——**版本号去 accept 断点**（方案 A 指针式 revert）、**polling 整个剥离**（独立概念不寄生）、**env-fix 抽共享包**（function/handler/trigger 复用）。波次 3 起步。

## 核心方针（一句话）
**function = 无状态 Python 逻辑；版本模型三正交（单调号 / 不可变内容 / 自由 active 指针，无 pending/accept）；env 物化 + LLM 改依赖自愈抽 `app/envfix` 共享；推流留 tool 层。**

## 用户拍板的三大决策
1. **版本号去 accept（方案 A）**：删 status(pending/accepted/rejected) 状态机。create/edit 写 `v(max+1)` 立即生效；**revert 纯移 active 指针**（不产生版本、不删「更新的」版本；版本号轴独立单调；active 号可小于历史号，前端诚实显示）；edit 从 active fork 出 max+1。50 上限裁最老**但绝不裁 active**（revert 后它可能很老）。
2. **polling 剥离**：删 kind/polling_interval/PollingAdapter/set_kind/set_polling_interval op——polling 触发源是独立概念，留给后面那个「单独一种」。顺带修了旧 `triggered_by="polling_trigger"` 违反 CHECK 的 bug。
3. **env-fix 抽共享 `app/envfix`**：用户预判 function/handler/trigger 都要（3 真实消费者，rule-of-three 已满足）→ 现在就抽。**推流留 tool call 里**（Sink 回调，包保持 stream-agnostic）。

## 新增 / 重写
- **`app/envfix`**（新共享包）：`Provisioner`（注入 SandboxPort/picker/keys/factory）+ `Provision` 循环（装→失败→utility LLM 改 deps→重试 ≤3）+ `Sink`（OnAttempt/OnFixing 回调）+ `Result{OK,FinalDeps,History}`。链对齐新地基（model.Resolve→ResolveCredentialsByID→factory.Build→llm.Generate + jsonrepair），**删 Thinking/llmclient/llmparse 残留**。从不返 Go error（失败=状态，调用方上呈）；FinalDeps 由调用方回写版本（号不变）。
- **domain/function**：去 GORM（db tag + `,ws`/`,deleted`/`,created`/`,updated`）；删 status/kind/polling_interval/env_sync_stage/detail；`version int` 单调号；execution 砍 hints、`triggered_by` ∈ chat/agent/workflow/manual（执行体轴）+ `IsValidTrigger`；errors 全 `errorsdomain.New`（删 5 旧码 + 加 `ErrInvalidCode`，`ErrOpInvalid` 改 422）。
- **infra/store/function**：orm 重写（workspace 自动隔离 / 软删 functions / 硬删 versions / cursor `Page` / `ErrConflict`→ErrDuplicateName）；`MaxVersionNumber`；`UpdateVersionEnv`（写 env 终态 + 修正 deps，json 手 marshal）；`TrimOldestVersions`（cutoff 版本号避 offset + **`id != active` 保护**）；三表手写 DDL。
- **app/function**：Service（Create→v1 / Edit→max+1 移指针 / Revert→纯移指针 / Run→ensureEnv+spawn+记 execution / Delete）；`ensureEnv` 经 envfix.Provision 写回；`SandboxRunner` 端口 + `SandboxAdapter`（写 main.py+driver / spawn / destroy，**装 env 交 envfix**）；3 适配器（catalog `Name+ListItems` / mention `Resolver` / relation `Namer.NamesByIDs` + forged/edited 边走 4 动词 `KindCreate`/`KindEdit`）。
- **app/tool/function**：9 工具（search/get/create/edit/revert/delete/run/search_executions/get_execution），5 方法接口、danger LLM 自报；create/edit 用累积 `forgeSink` 把 env-fix 尝试折进结果（`envFixAttempts`）；run_function 按 ctx 有无 subagent 区分 chat/agent 触发。
- **handler**：REST CRUD + `:run`/`:revert`/`:edit` + versions + executions；**删 pending 三端点**；`:iterate` 留 askai 波次 6。

## 测试（全离线）
- envfix 6（一次成功 / 修复成功 FinalDeps 回写 / 3 次耗尽 / 无 utility 模型降级 / Sink 时序 / nil Sink）。
- store 9（隔离 / dup / 软删 / 分页 / MaxVersionNumber / UpdateEnv 改 deps / **trim 保护 active** / GetByIDs 保序 / executions 聚合）。
- app 8（**revert 纯移指针 + fork-from-active + 单调 v3** 核心 / create v1 / dup / invalid code / edit 移指针 / 空 ops 重建 / run 记 execution / delete）。
- tool（9 工具装配 + ValidateInput 必填）+ domain（IsValidTrigger）。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet ./...` 0 · `go test -race -count=1`（envfix 2.6s / domain 2.0 / store 3.8 / app 3.3 / tool 4.1）全绿。

## 契约
- `domains/function.md` **整篇重写**（DOC-110：方案 A 版本模型 + env-fix 自愈 + triggered_by 四值 + 删 accept/polling/AST 吹嘘/docstring 提参）。
- `domains/envfix.md` **新建**（DOC-304：共享 env 物化 + 自愈，handler/trigger 复用登记）。
- `error-codes.md`（删 5 旧码 + 加 INVALID_CODE，OpInvalid 改 422）· `api.md`（删 pending 三端点）· `database.md`（前缀加 `fnenv_`）· `contract-changes #17`。

## 跨波次接线（deps-todo 登记）
- envfix：handler M3.2 / 轮询源那轮消费；Sink live 推流 chat M5.2；boot 注入 M7。
- function 适配器注入（catalog RegisterSource / mention 注册 / relation Namer + SetRelationSyncer）M7；SandboxRunner + envfix.Provisioner 装配 M7；DDL 收集 M7。
- triggered_by 写入方：agent host M3.4（set agent）/ workflow dispatcher M4 / chat M5.2；tool 已按 subagent ctx 区分 chat/agent。
- `:iterate`（askai 编辑）波次 6。
