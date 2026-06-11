---
id: DOC-028
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2026-09-11
audience: [human, ai]
---

# sandbox + envfix —— 隔离插件运行时

## 1. 定位 + 心智模型

**sandbox** 掌管 Runtime/Env 生命周期：按 kind 的 `RuntimeInstaller` + `EnvManager` 注册表（python/node/docker/dotnet），per-owner env 构建（owner = `{Kind, ID}` 复合键，如 function 的 `functionID_envID`）、懒装、GC、spawn（一次性 `Spawn` / 长跑 `SpawnLongLived` 带 handle 追踪）。**运行时不预装**——`directInstaller`（[ADR 0001](../../../decisions/0001-sandbox-runtime-direct-install.md)）首用时从上游直拉（python-build-standalone / node 官方 / uv），跨平台 `GOOS/GOARCH` 直出二进制、无内嵌。Bootstrap 只建根目录（失败 = degraded 模式，`:retry-bootstrap` 可救）；boot 时 `RestoreOrCleanupOnBoot` 对账盘上 env 与 DB manifest。安装/构建用 per-key 锁防并发重复。

**envfix** 是共享的**自愈构建循环**：`Provision(owner, runtime, deps)` 失败时把安装错误喂给 utility LLM 改依赖列表重试（≤3 次），返回终态 + 修正后的 deps + 尝试历史。function/handler（+ 未来 sensor）共用——"装不上就让 LLM 修"只写一处。

## 2. 契约（引用）

表 `sandbox_envs`（manifest，硬删——盘上目录才是实体）→ [database.md](../database.md) · 码 `SANDBOX_*` 13 → [error-codes.md](../error-codes.md) · ID：env owner 用消费方自有前缀（`fnenv_`/`hdenv_`，S15）。端点：`GET /sandbox/status` · `POST /sandbox:retry-bootstrap` · envs 列表/销毁。消费方：function（Run/Destroy）、handler（SpawnLongLived）、mcp（EnsureEnv+SpawnLongLived）、attachment（抽取脚本）、envfix（SandboxPort）。
