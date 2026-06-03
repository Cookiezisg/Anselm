# Round 0001 — pkg/reqctx · pkg/idgen · pkg/pagination（波次 0 · M0.1 第一轮）

类型 / 目标：波次 0 起步，重写三个最底层纯工具，确立 clean 范本 + `workspace_id` 全局正名。

依赖扫描：
- 上游：无（最底层，仅 stdlib）。
- 下游：暂无（backend-new 上层未建）。
- 考古发现：三包都混入上层关注点且有反向依赖 —— `reqctx → domain/model`（modeloverride）、`pagination → domain/errors`、`idgen` 混入实体类型映射。

旧实现历史包袱：
- reqctx 是 5 文件杂物抽屉（userID + locale + 对话标识 + agentstate + modeloverride）。
- idgen 混入 `KindByPrefix`（relation 关注点）。
- pagination 把纯 cursor 编解码与 `Parse(http)` + limit 策略 + `domain/errors` 依赖混在一起。

修改后完整逻辑（给人看的，详见文件头注释）：
- reqctx = `workspace`(Set/Get/Require + ErrMissingWorkspaceID) + `locale`，纯 stdlib。
- idgen = `New(prefix)` → `<prefix>_<16hex>`，crypto/rand 失败 panic。
- pagination = `Cursor` + `EncodeCursor`/`DecodeCursor`，自定 `ErrMalformedCursor`，零上层依赖。

删除 / 移出（全部记入 deps-todo.md）：modeloverride→model(M1.3)、agentstate→agent/loop、对话标识→chat/loop/eventlog、KindByPrefix→relation(M1.4)、Parse+limit→transport(M0.7)。

契约变更：无对外 API（纯工具）。全局确立 `user_id → workspace_id`。

新测试：reqctx(workspace 有/无/空 + locale 默认/设置/不支持)、idgen(格式 + 1000 唯一)、pagination(round-trip + nil + 空 + malformed)。

验证：`gofmt -w`；`go build -o /dev/null ./...` OK；`go vet ./...` OK；`go test ./...` 全绿。

是否更干净：✅ 三包从「混杂 + 反向依赖」→「stdlib-only 单一职责叶子」；reqctx 5 文件 → 2 文件。

覆盖状态：物理全集中 reqctx/idgen/pagination 标 cleaned；移出项入 deps-todo。

下一步：M0.1 续（tokencount/pathguard/userpath/wikilink/jsonrepair/limits + `modelcaps` 判定）→ M0.2 infra/db。

---

## R0001.1 调整（2026-06-03）— reqctx 包内按 concern 拆文件

起因：`reqctx.go` 整篇是 workspace 身份，把"reqctx（请求上下文通用机制）"这个核心名占了。

调整（同一 `pkg/reqctx` 包内，仅文件重组，无拆包）：
- `workspace.go`：workspace 身份 ctx 透传（`Set/Get/RequireWorkspaceID` + `ErrMissingWorkspaceID`）。
- `reqctx.go`：包门面（包 doc）+ `locale`（唯一无业务域的通用请求属性）。
- 删 `locale.go`（并入 reqctx.go）。
- 测试同步拆：`workspace_test.go`（TestWorkspaceID）/ `reqctx_test.go`（TestLocale）。

为何不移到 workspace 业务包（M1.1）：写入 workspace id 是横切关注点，由 HTTP 中间件（M0.7）完成、在任何业务包就绪前就接线——移进业务模块会让 M0.7 依赖 M1.1，倒置层级。故留地基包内拆文件，不入 deps-todo。

验证：gofmt 净 / `go build -o /dev/null ./...` OK / `go vet` OK / `go test ./internal/pkg/reqctx` 绿。
