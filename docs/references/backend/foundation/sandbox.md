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

安装输入错误不会伪装成一次上游下载失败：固定 runtime 的未知版本，以及 uv/dotnet
明显不是发行版格式的版本，在联网前返回 `SANDBOX_RUNTIME_VERSION_UNSUPPORTED`，其
`details` 带 `kind`、`version` 和可读 `hint`；下载、校验或原子落盘失败才返回
`SANDBOX_RUNTIME_INSTALL_FAILED`，并带同样的 `kind/version` 细节供设置页给出可行动提示。

Python、Node、uv、dotnet、Docker 与 Search engine artifact 使用 installer
registry；用户可安装目录只投影明确实现 UserFacing/AvailableVersions 的类型。

Env 由 `(owner_kind,owner_id)` 唯一确定。Ensure/Destroy/GC 使用 per-key lock，
Destroy 同时逐出 lock，避免长期构建过的 owner 无限累积 mutex。

对话 scratch env 是例外的**路由授权**：`GET/POST /conversations/{id}/sandbox-envs*` 在读取或修改
机器级 manifest 前，必须先用当前 workspace 的 conversation store 校验 `{id}`。不存在或属于别的
workspace 的 conversation 统一返回 `404 CONVERSATION_NOT_FOUND`，不能仅凭 `owner_id` 前缀返回空列表
或执行删除；校验通过后才按 `<conversationID>_` 前缀读写其 scratch env。

Destroy 先检查 manifest 的 `running_pid`：只要仍有常驻进程，就返回
`409 SANDBOX_ENV_IN_USE`，保留进程、目录和 manifest，要求所属实体先停止；不会为了满足设置页
的删除动作而静默杀掉常驻进程。进程停止后，Destroy 才删除 env 行及其派生目录。

手动 `POST /sandbox:gc?olderThanDays=N` 以 `last_used_at < now-N days` 选出空闲 env；缺省、负数或
非法参数使用 30 天，显式 `0` 表示立即回收所有当前空闲 env。GC 复用 Destroy 的运行 PID 守卫，逐项
best-effort：运行中的 env 或单项删除失败会留在 manifest 并写 warning，其余项继续；返回值只统计实际删除
的 env。该动作不删除 runtime manifest/目录，runtime 仍需在无 env 引用时显式 DeleteRuntime；被 GC 的
Function/Handler env 会在下次执行时懒重建。

Bootstrap 只确保根目录/基础状态；失败进入 degraded，用户可
`:retry-bootstrap`。`GET /sandbox/bootstrap-status` 保持 `200` 并返回 `{ok:false,
error:"sandbox bootstrap failed"}`，原始路径和包装错误只进入 backend journal，不能泄漏到产品
wire。Runtime/Env 是可再生派生物，因此表与磁盘镜像可硬删。

## 3. 进程

一次性 `Spawn` 受调用 context 控制。`SpawnLongLived` 的生命周期脱离创建请求，
返回可关闭 handle。

Unix 子进程自成 process group，终止时杀整组，使 npx/uvx wrapper 的后代不会
成为孤儿；Windows 使用 Job Object/task tree，无法建组时退回单进程。
若 Unix 进程组已在外部断开或组形状已变化，live cleanup 幂等退回直接 child kill；这只处理
清理动作的竞态，不放宽 Boot 回收器的整组存活与 PID 复用防护。

Service 同时跟踪 long-lived 与 in-flight one-shot。Shutdown 显式收割两类，
不能假定所有 caller context 都及时取消。

Env manifest 保存 running PID。Boot 的 `RestoreOrCleanupOnBoot` 验证并回收
异常退出遗留的 process group，再清 PID，防止 PID 重用时误杀无关进程。

## 4. Envfix

`Provision(owner,runtime,deps)`：

1. 尝试创建/同步 env；
2. 失败时可把安装错误交给 utility model 修正 dependency list；托管模型即使附带散文、
   Markdown JSON fence 或尾逗号，envfix 也会先提取结构化对象再重试，无法提取时才诚实结束；
3. 有界重试；
4. 返回 `OK`、最终 deps 与完整 attempts。

Envfix 用 Result 表达构建失败，不把“模型未配置/依赖无法安装”伪装为基础设施
panic。调用方将 attempts 流到 Entity build terminal，并把终态写入自己的
Version env mirror。

EnsureEnv 的安装阶段仍服从调用方取消；但 manifest 的 `ready/failed` 终态写回使用保留
workspace 的 detached context，客户端断开不能留下永久 `installing`。有 workspace 的调用会
再发送 `sandbox.env_status_changed` 终态通知；机器级 attachment/search 等没有 workspace
受众的调用只写 manifest，不尝试发通知，避免制造 `MISSING_WORKSPACE_ID` 伪告警。

Function/Handler 额外拒绝通过删除声明依赖来制造假 ready；这一业务诚实边界由
实体 app 层执行。

## 5. 契约

精确 runtime/env/disk/bootstrap/GC 与 Conversation scratch env 端点见
[`api.md`](../api.md)。表见 [`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)。ID：runtime `sr_`、env `se_`。

Env manifest 的 `deps` 是集合字段，读写边界统一归一为 JSON 数组；空依赖在线上表现为
`[]` 而非 `null`。单读与列表返回同一份 manifest，且两张 manifest 表都是机器级资源，
不按 workspace 过滤。`ownerName` 是可读投影：Function/Handler 的复合 owner id 读时按当前
workspace 解析父实体名，兼容旧空名行和实体改名；实体缺失时保留空值，前端再回退 owner id。

Runtime 直接安装取舍见
[`ADR 0001`](../../../decisions/0001-sandbox-runtime-direct-install.md)。

机器级磁盘投影 `TotalSizeBytes` 汇总 runtime 与 env manifest 的 `size_bytes`，供
`GET /sandbox/disk-usage` 返回 `totalBytes`。它不按 workspace 隔离，也不在每次读取时做物理目录扫描；
两类 manifest 都为空时返回 `0`。
