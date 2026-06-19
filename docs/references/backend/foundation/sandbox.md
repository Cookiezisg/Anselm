---
id: DOC-028
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-14
review-due: 2026-09-14
audience: [human, ai]
---

# sandbox + envfix —— 隔离插件运行时

## 1. 定位 + 心智模型

**sandbox** 掌管 Runtime/Env 生命周期：按 kind 的 `RuntimeInstaller` + `EnvManager` 两套注册表（`EnvManager` 4 家：python/node/docker/dotnet），per-owner env 构建（owner = `{Kind, ID}` 复合键，如 function 的 `functionID + "_" + envID`，envID 即 `fnenv_…` 版本 env 记录）、懒装、GC、spawn（一次性 `Spawn` / 长跑 `SpawnLongLived` 带 handle 追踪——infra `SpawnLongLived` 刻意丢弃 ctx：常驻进程须活得比拉起它的请求长）。**进程一律自成进程组**（unix `Setpgid`），杀进程一律杀整组（负 pgid SIGKILL），使 uvx/npx 的 python/node 孙进程随包装器一同死；windows 走 per-process Job Object（`taskkill /T`），无进程组时退化单 pid。`Shutdown` 收割两类进程：所有活跃 `SpawnLongLived` handle **与**在途一次性 `Spawn` 进程（后者登记在 `oneShots`，其 ctx 在 shutdown 时可能永不取消，故须显式整组杀）。**运行时不预装**——`directInstaller`（[ADR 0001](../../../decisions/0001-sandbox-runtime-direct-install.md)）首用时从上游直拉钉死版本的 tarball/zip，4 家自研 installer（python-build-standalone / node 官方 / uv / dotnet）+ docker installer（`docker pull`，image=runtime/container=env，无宿主装机）+ 引擎 installer（搜索 embedder 的 llama-server + GGUF 模型走同一注册表）；下载后 sha256/512 校验、staging 原子 rename 入正式目录，跨平台 `GOOS/GOARCH` 直出、无内嵌。Bootstrap 只建根目录（失败 = degraded 模式，`:retry-bootstrap` 可救）；boot 时 `RestoreOrCleanupOnBoot` 回收上次残留的 running_pid 进程（对记录 pid 的整个进程组发 SIGKILL——记录的是 spawn 的直接子 = 组长，杀整组连 uvx/npx 孙进程一并收割，再清零 pid）。安装/构建用 per-key 锁防并发重复（`envLocks` 的 per-owner 锁在 env `Destroy` 时随锁逐出，不随进程整生命周期堆积）。

**envfix** 是共享的**自愈构建循环**：`Provision(owner, runtime, deps)` 失败时把安装错误喂给 utility LLM 改依赖列表重试（默认 ≤3 次），返回 `Result`（终态 OK + 修正后的 deps + 尝试历史）——**从不返回 Go error**：基础设施失败或未配 utility 模型只是以 `OK=false` 结束、stderr 留在 History，由调用方上呈给建构 LLM 自行改代码。function/handler（+ 未来轮询触发源）共用——"装不上就让 LLM 修"只写一处。

## 2. 契约（引用）

表 `sandbox_runtimes`（`sr_`，`UNIQUE(kind,version)`）+ `sandbox_envs`（`se_`，`UNIQUE(owner_kind,owner_id)`）——皆 manifest、系统级（无 ws 列）、硬删（盘上镜像/目录才是实体）→ [database.md](../database.md) · 码 `SANDBOX_*` 15 → [error-codes.md](../error-codes.md) · ID：sandbox 行自有 `sr_`/`se_`；owner_id 复用消费方前缀（function/handler env 记录 `fnenv_`/`hdenv_`，S15）。端点（`/api/v1/sandbox/*`）：runtimes 列表/装/删 · envs 列表（`ownerKind` 必填）/查/销毁 · `GET .../disk-usage` · `GET .../bootstrap-status` · `POST .../sandbox:gc` · `POST .../sandbox:retry-bootstrap`；另有 per-conversation scratch-env 路由（`/conversations/{id}/sandbox-envs` 列表 + `:reset` / `:reset-all`）。消费方：function（Run/Destroy）、handler（SpawnLongLived）、mcp（EnsureEnv+SpawnLongLived）、attachment（抽取脚本，固定 owner `attachment/extractor`）、envfix（SandboxPort）。
