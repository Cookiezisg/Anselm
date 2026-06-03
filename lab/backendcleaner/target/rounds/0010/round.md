# Round 0010 — infra/logger（波次 0 · M0.3）

类型 / 目标：迁移 `infra/logger` —— `zap.go` 保留 + 简化，`broadcast.go` 判定删除。

依赖扫描：
- 上游：`go.uber.org/zap`（v1.28.0，对齐主 backend）。
- 旧下游：`cmd/server/main.go`（构造 broadcaster + 作 extra core）、`router/deps.go`（注入）、`handlers/dev.go`（SSE 日志流端点）。

它是什么：`zap.go` = zap logger 工厂；`broadcast.go` = `LogBroadcaster`（实现 `zapcore.Core`，把日志扇出 SSE 给 dev 端点，环缓冲 500 + 订阅 channel 慢订阅丢条）。

判定：
- **`zap.go` 保留 + 简化**：`New(dev, extras...)` → `New(dev)`。`extras`（tee 额外 core）唯一使用者是 broadcaster，删 broadcaster 后无用户 → 去掉（未来要文件日志 tee 再加，不预造）。
- **`broadcast.go` 删除**：① 它撑起一条**日志 SSE 流 = 第四条 SSE**，违反 **E1**「全系统仅 eventlog/notifications/forge 三条，永不再加」；② 只服务 dev 日志端点，Wails 桌面 app 开发看终端日志即可；③ web 调试残留。

删除 / 移出（连带 → deps-todo，M7 wiring 执行）：`handlers/dev.go` 去日志流端点、`main` 去 broadcaster 接线、`router/deps` 去注入。

契约变更：无对外契约（dev 日志 SSE 端点随 broadcaster 删 → M7 处理）。`New` 签名简化（内部）。

新测试：2（`New(true)`/`New(false)` smoke：非 nil + 能 Info 不 panic）。

验证：`go mod tidy`；`gofmt` 净；`go build ./...` OK；`go vet` OK；`go test` 绿。

是否更干净：✅ logger 从「工厂 + SSE 广播 core(违反 E1)」→「纯 zap 工厂」。

覆盖状态：logger cleaned（仅 zap.go）；broadcast 判删，连带入 deps-todo（M7）。

下一步：M0.3 续 `infra/crypto`（AES-GCM）。
