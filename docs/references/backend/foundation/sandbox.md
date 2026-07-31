---
id: DOC-028
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Sandbox 与 Envfix

## 1. 定位

Sandbox 管理 Runtime、per-owner Env 与进程；Envfix 在其上提供依赖安装的共享
修复循环。

```text
RuntimeInstaller
→ runtime manifest/files
→ EnvManager(owner kind + owner ID)
→ Spawn | SpawnLongLived
```

Owner 是复合身份，不等同于 Sandbox row ID。Function/Handler 使用 per-version
owner；MCP、Attachment extractor、Skill script、Conversation scratch env 与
Search engine 复用同一底座。

## 2. Runtime 与 Env

Runtime 首用安装，不要求宿主预装。Direct installer：

- 下载平台匹配且钉版本的 archive/image；
- 校验 SHA；
- 在 staging 解包；
- 原子 rename 到正式目录；
- 写 runtime manifest。

Python、Node、uv、dotnet、Docker 与 Search engine artifact 使用 installer
registry；用户可安装目录只投影明确实现 UserFacing/AvailableVersions 的类型。

Env 由 `(owner_kind,owner_id)` 唯一确定。Ensure/Destroy/GC 使用 per-key lock，
Destroy 同时逐出 lock，避免长期构建过的 owner 无限累积 mutex。

Bootstrap 只确保根目录/基础状态；失败进入 degraded，用户可
`:retry-bootstrap`。Runtime/Env 是可再生派生物，因此表与磁盘镜像可硬删。

## 3. 进程

一次性 `Spawn` 受调用 context 控制。`SpawnLongLived` 的生命周期脱离创建请求，
返回可关闭 handle。

Unix 子进程自成 process group，终止时杀整组，使 npx/uvx wrapper 的后代不会
成为孤儿；Windows 使用 Job Object/task tree，无法建组时退回单进程。

Service 同时跟踪 long-lived 与 in-flight one-shot。Shutdown 显式收割两类，
不能假定所有 caller context 都及时取消。

Env manifest 保存 running PID。Boot 的 `RestoreOrCleanupOnBoot` 验证并回收
异常退出遗留的 process group，再清 PID，防止 PID 重用时误杀无关进程。

## 4. Envfix

`Provision(owner,runtime,deps)`：

1. 尝试创建/同步 env；
2. 失败时可把安装错误交给 utility model 修正 dependency list；
3. 有界重试；
4. 返回 `OK`、最终 deps 与完整 attempts。

Envfix 用 Result 表达构建失败，不把“模型未配置/依赖无法安装”伪装为基础设施
panic。调用方将 attempts 流到 Entity build terminal，并把终态写入自己的
Version env mirror。

Function/Handler 额外拒绝通过删除声明依赖来制造假 ready；这一业务诚实边界由
实体 app 层执行。

## 5. 契约

精确 runtime/env/disk/bootstrap/GC 与 Conversation scratch env 端点见
[`api.md`](../api.md)。表见 [`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)。ID：runtime `sr_`、env `se_`。

Runtime 直接安装取舍见
[`ADR 0001`](../../../decisions/0001-sandbox-runtime-direct-install.md)。
