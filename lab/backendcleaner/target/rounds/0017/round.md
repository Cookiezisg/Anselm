# Round 0017 — transport 框架（波次 0 · M0.7）

类型 / 目标：建 transport 地基——所有业务 handler 的公共边界。response(N1 envelope + errmap 塌缩 + SSE) + middleware(workspace 注入 + 标准件) + router(框架)。**波次 0 收官。**

考古结论：旧 `errmap.go` = 293 行 + 27 internal import + ~150 sentinel 大表 + O(n) errors.Is 遍历——transport 反向耦合全项目的最大单点。其余件（envelope/sse/middleware/recorder）干净可照搬。

落地（13 源 + 6 测试）：
- **response**：
  - `envelope.go`（N1：Success/Created/NoContent/Paged/Error，照搬）。
  - **`errmap.go`（核心收益）**：293 行表 → `statusForKind(Kind)` 15 行 switch + `FromDomainError`（errors.As `*Error` → statusForKind+Code+Details；context.Canceled/DeadlineExceeded 特例；未知 500 隐藏原文）。**~50 行 + 1 import(errorsdomain)、零业务 domain import**。R0012 设计兑现。
  - `sse.go`（StreamSSE 泛型写入器，照搬）。
  - **`stream.go`（M0.4 推迟的 SSE marshal）**：stream.Envelope → 线缆 `{seq,scope,id,frame:{kind,...}}`（frame 判别 kind + node 判别 type 注入）；`WriteStreamEnvelope`（durable 带 `id:` 行 / ephemeral seq0 省略）。domain 不碰序列化，判别注入收一处。
  - `page.go`（pagination Parse，M0.1 移交）：`ParsePage`(?cursor=&limit=，clamp [1,200])；`DecodeCursor` 把 `pagination.ErrMalformedCursor` → `ErrInvalidRequest`。
- **middleware**（6）：
  - **`auth.go`（user→workspace 改名落地）**：`X-Forgify-Workspace-ID`、`SetWorkspaceID`、`UNAUTH_NO_WORKSPACE`；`WorkspaceResolver` 本地最小接口（`Validate(ctx,id)error`，零 domain 依赖，M1.1 实现、M7 注入）。
  - cors/locale/logger/recover/notfound（照搬；cors 把 workspace header 加进 AllowedHeaders）。
- **router**（框架）：
  - `recorder.go`（Recorder 记录路由，照搬核心；去 dev RecorderAdapter——依赖 handlers）。
  - `chain.go`（middleware 链 Recover→Logger→CORS→Locale→IdentifyWorkspace→requireWorkspaceExempt；豁免白名单 /workspaces·/health·/providers·/scenarios）。

边界：M0.7 = **零业务依赖的框架**。完整 `router.New`（装配所有 handler）+ Deps 容器 + health handler → cmd/server（M7）；各业务 handler 随其垂直切片；stream handler（messages/entities/notifications）随业务用 `WriteStreamEnvelope`。

测试（全绿）：statusForKind 15 Kind；FromDomainError(结构化 / fmt-wrap / context / 未知 500 隐藏)；stream marshal 四 frame wire 形状 + id 行分级；ParsePage(默认/clamp/malformed)；envelope N1；IdentifyWorkspace(header/query/invalid-drop)+RequireWorkspace(401/pass)；Chain 豁免 vs 受守。

验证：`gofmt -l` 空 / `go build ./...` / `go vet` / `go test` 全绿。

契约：contract-changes #1（header `X-Forgify-User-ID`→`X-Forgify-Workspace-ID` + `UNAUTH_NO_USER`→`UNAUTH_NO_WORKSPACE`）在 auth middleware **落地**。

**M0.7 完成 → 波次 0（地基层）全部收官**：M0.1 pkg · M0.2 db/orm · M0.3 logger/crypto · M0.4 stream domain · M0.5 stream bus · M0.6 llm(11 provider) · M0.7 transport。下一步：波次 1 叶子业务域（M1.1 workspace 起）。
