# 沙箱迭代 1：uv + 捆绑 Python + 每 Forge 独立 venv

**日期**：2026-05-02
**状态**：🔄 设计中（未开工）
**阶段定位**：Phase 3 后优化轮的一项；非 Phase 4 阻塞前置
**关联**：
- 现状：[`backend/internal/infra/sandbox/python.go`](../../../../backend/internal/infra/sandbox/python.go)
- 上层消费：[`backend/internal/app/forge/forge.go`](../../../../backend/internal/app/forge/forge.go) `Service.RunForge`
- 桌面打包大方向：[`../desktop-packaging-notes.md`](../desktop-packaging-notes.md) §五
- forge domain 详设：[`../../service-design-documents/forge.md`](../../service-design-documents/forge.md)

---

## 0. 一句话定位

把 `infra/sandbox` 从"调用系统 python3 跑一段函数代码"升级为
**捆绑 Python 解释器 + uv 管 venv + 每个 forge 一个独立环境 + 创建期一次性 sync、运行期热路径**。

非目标：安全隔离（沙箱权限、网络隔离、资源限制）——本地单用户场景下仍按设计原则 #6 不投入。

---

## 1. 当前现状（精确盘点）

读完 `infra/sandbox/python.go`（147 行）+ `app/forge/ast.go`（211 行）+ 上下游调用，盘出当前 sandbox 实际形态：

### 1.1 调用链

```
LLM tool_call run_forge
  → forgetool.RunForge.Execute               app/tool/forge/run.go:75
    → resolveAttachments                     att_xxx → 真实 path
    → forgeapp.Service.RunForge              app/forge/forge.go:511
      → repo.GetForge → code 字符串
      → forgeapp.Sandbox.Run                 接口在 app/forge/forge.go:36
        → sandboxinfra.PythonSandbox.Run     infra/sandbox/python.go:66
          → os.CreateTemp + 写代码 + 追加 driver
          → exec.CommandContext("python3", tmp.Name())
          → cmd.Stdin = JSON(input)
          → cmd.Output() → JSON
          → ExecutionResult{ok, output, errorMsg, elapsedMs}
      → SaveRunHistory（无论成败）
```

### 1.2 关键观察

| 项 | 现状 |
|---|---|
| Python 来源 | 系统 `python3`（hardcoded）—— `New("python3")` |
| 依赖 | 仅 stdlib —— `import requests` 直接 ImportError |
| 隔离 | 单纯 subprocess + 上游 ctx 控制；`SandboxTimeout = 30*time.Second` 常量在 forge.md 文档里写了但**代码里根本没接**（`exec.CommandContext` 用的是上游 ctx）。本迭代决策：**彻底删 timeout**，只靠 ctx-cancel——见 §5 |
| 上游基线 | **2026-05-02 Phase 5+6 重构后**：5 张 forge 表合并为 4 张（`forge_run_history` + `forge_test_history` 合并为 `forge_executions`，含 chat 触发上下文 4 字段）；SSE 12 个细粒度事件简化为 3 个 entity-state 事件（`chat.message` / `forge` / `conversation`，载荷 = 完整 entity 快照与 REST GET 同形）；`Forge` entity 加 `Pending *ForgeVersion` 计算字段。**本迭代必须吃这个基线**，不引入新 SSE 事件类、复用现有 `forge` entity-state 通道——详 §13 |
| 临时文件 | `os.CreateTemp("", "forgify-tool-*.py")` + `defer os.Remove`，每次调用都重新创建 |
| 启动开销 | 每次 ~50-150ms（python 解释器启动 + import json/sys）|
| Driver 注入 | 字符串模板替换：`{FUNC_NAME}` → `extractFuncName(code)` 提取的第一个 `def` 名 |
| Stderr | 失败时整个 stderr 灌进 `ErrorMsg`，不结构化 |
| 取消语义 | 上游 ctx 取消 → `cmd.Process.Kill()` 由 stdlib 处理 |
| 第二处 Python | `app/forge/ast.go::parseForgeCode` 也用 `python3` 子进程跑 AST 脚本——和 sandbox 重复用法 |

### 1.3 测试覆盖

`infra/sandbox/python_test.go` 8 个测试：basic 执行 / 字符串/字典输出 / Python 异常 / ctx 取消 / 默认参数 / `extractFuncName` 解析。**全部假设系统有 python3**——CI 上能跑因为 GitHub runner 自带；用户机器上也大概率有，但是**不是契约**。

---

## 2. 痛点（为什么要改）

按"最痛 → 较痛"列：

1. **依赖管理空白**。Forge 想用 `requests`、`pandas`、`pillow` 等等任何非 stdlib 包，**没有路径**。LLM 在 `create_forge` / `edit_forge` 时只能写纯 stdlib 代码，工具能力被严重限缩。

2. **Python 依赖不在打包契约里**。桌面 app 打出来给用户，对方机器没装 python3 就直接挂。`desktop-packaging-notes.md` 第五节已经把这事写进风险——但没解决方案。

3. **运行成本固定为冷启动**。每次 `run_forge` 都开一个新 Python 进程从零 import。即使简单 forge 也有 50-150ms 解释器启动开销。如果 forge 有重 import（pandas 这种），冷启动可达 1-2s。

4. **隐式系统耦合**。Forge 行为取决于用户系统装的 Python 版本和 site-packages 里碰巧有什么——同一个 forge 在两台机器上行为可能不同，且不可重现。

5. **`infra/sandbox` 和 `app/forge/ast.go` 重复 Python 调用**。两处都 hardcode `python3` + 临时文件 + stdin → stdout 模式。打包时要解决两次。

6. **30s timeout 实际未落地**。`forge.md §4` 写了 `SandboxTimeout = 30 * time.Second`，但 `python.go::Run` 没接这个常量——上游 ctx 啥就是啥。本迭代决策：**不修这个 bug，反向删掉文档里的 30s 限制**——工具可能正常需跑很久，死循环是 LLM/用户问题，sandbox 不该越权拦。

---

## 3. 已讨论过的方案与去向

| 方案 | 思路 | 决策 |
|---|---|---|
| A. 系统 Python | README 写要求 | ❌ 桌面用户体验差；2、5 痛点完全没解 |
| B. uv 全管 | 捆 uv 二进制，`uv python install` 联网下 Python | ⚠️ 首次启动联网 30MB，体验有抖动 |
| **C. 捆绑 standalone Python + uv 管 venv** | python-build-standalone 进 Wails resources，uv 二进制也进 resources，仅依赖装包时联网 | ✅ **本迭代落点** |
| D. WASM (Pyodide) | 浏览器侧 WASM 跑 Python | ❌ 本地 Wails app 用 WASM 是过度工程；很多包在 Pyodide 没有 |

**最终方案（C）**：把 Python 解释器和 uv 都打进 .app/.exe 资源；每个 forge 在 `<dataDir>/forges/<id>/` 下有自己的 `pyproject.toml + uv.lock + .venv/`；forge 创建 / 依赖修改时跑 `uv sync` 物化 venv（异步、推 SSE 进度）；运行时 `uv run --no-sync` 直接执行。

**网络假设**：用户接受首次安装依赖时联网。仅 `uv sync` 阶段需要网；`uv run` 完全离线。

---

## 4. 落定架构总览

### 4.1 全局视图

```
┌─ Wails .app / .exe ─────────────────────────────────┐
│                                                      │
│  cmd/desktop/main.go    ← Phase 4 之后才写            │
│  cmd/server/main.go     ← 当前的 backend 入口         │
│                                                      │
│  embed.FS resources/                                 │
│  ├── bin/uv-darwin-arm64                             │
│  ├── bin/uv-darwin-amd64                             │
│  ├── bin/uv-linux-amd64                              │
│  ├── bin/uv-linux-arm64                              │
│  ├── bin/uv-windows-amd64.exe                        │
│  └── python/                                         │
│      ├── darwin-arm64.tar.gz                         │
│      ├── darwin-amd64.tar.gz                         │
│      ├── linux-amd64.tar.gz                          │
│      ├── linux-arm64.tar.gz                          │
│      └── windows-amd64.zip                           │
│                                                      │
└──────────────────────────────────────────────────────┘
                    │
                    ▼
┌─ <dataDir>/ ────────────────────────────────────────┐
│                                                      │
│  bin/                                                │
│  ├── uv             ← 启动期从 embed.FS 提取并 chmod  │
│  └── python/        ← 启动期从 embed.FS 解压          │
│      ├── bin/python3   (mac/linux)                   │
│      └── python.exe    (win)                         │
│                                                      │
│  uv-cache/          ← UV_CACHE_DIR；wheel cache、     │
│                       Python install dir 的源；       │
│                       多 forge 共享 wheel 硬链接      │
│                                                      │
│  forges/                                             │
│  └── <forge_id>/                                     │
│      ├── pyproject.toml    ← 由 sandbox 生成          │
│      ├── uv.lock           ← uv sync 后产物          │
│      ├── main.py           ← 用户 forge 代码         │
│      └── .venv/            ← uv venv（含硬链接到      │
│                              uv-cache 的 wheel）      │
│                                                      │
│  forgify.db          ← 既有 SQLite                   │
│  attachments/        ← 既有附件                       │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### 4.2 与既有 backend 的关系

- 不影响 transport / app / domain 层架构，仅扩 forge domain 加几个字段、扩 forgeapp.Sandbox 接口
- `infra/sandbox` 内部从单文件涨到 5-6 文件（按 §S12 拆概念）
- 主入口 `cmd/server` 装配多两步（preflight + 把 dataDir 传 sandbox），不含 Wails
- 桌面端 `cmd/desktop` 之后写时新增"启动卡顿引导页"对接 sandbox 启动事件

---

## 5. 核心决策表

| 决策 | 选择 | 理由 |
|---|---|---|
| Python 来源 | **捆绑 python-build-standalone** | 用户接受网下依赖，但不应该依赖系统 python3 存在 |
| Python 版本 | **3.12.x**，跟最新 stable | 类型语法、性能、ast.unparse 等都到位；后续可平滑升 3.13 |
| uv 来源 | **捆绑 uv 二进制** | uv 是单 Rust 静态二进制 ~30MB，捆进 .app 心智成本最低 |
| Python 是否对用户系统暴露 | **完全沙箱化在 dataDir 内** | 不污染用户 `~/`；用户系统的 python3 完全不参与 |
| 每 forge 一个 venv | **是** | 依赖隔离 + uv 全局 wheel cache + 硬链接 = 物理上自动去重；逻辑上独立可调试 |
| Sync 时机 | **forge 创建 / 依赖变更时**（非运行时）| 创建是用户"我在配置工具"的明确动作；运行时永远是热路径 |
| Sync 是否阻塞 HTTP | **异步 + entity-state 推快照** | uv sync 第一次可能 5-15s，HTTP 应立即返；状态走 forge entity 字段 + 现有 `forge` SSE 事件（详见下两条） |
| **Sync 进度推送方式** | **细粒度（B 方案）**：每行 uv stderr 解析后更新 forge entity 的 `EnvSyncStage`/`EnvSyncDetail` 字段，触发 forge 快照推送 | 跟 chat token 流推 ChatMessage 快照心智一致——所有"过程进度"都走 entity-state；装大包（torch、playwright 等）时用户能看到"正在下载 numpy → pandas → ..."；失败时进度链可追溯。粗粒度 A 方案否决——徽章只切 syncing/ready 两态对装重包场景体验差 |
| **不引入新 SSE 事件类** | sandbox sync 全程复用现有 `forge` entity-state 事件 | Phase 6 entity-state 模型规约：每个 user-facing domain 一个事件；不允许加 `sandbox.*` 命名空间；订阅方按 forge ID 替换本地拷贝即可渲染 sync 状态 |
| run 时是否检查 lock 一致性 | **不检查**（`--no-sync`）| sync 时机由 service 层完全控制，run 不重做 |
| `app/forge/ast.go` 的 Python | **共用捆绑 Python**（非 venv，纯 stdlib 调用）| 不需要额外 venv（ast 模块在 stdlib 里）；保持一处 Python 的概念干净 |
| 沙箱接口位置 | **保留 `forgeapp.Sandbox` interface**，扩成 Sync + Run + Destroy 三方法 | 沿用现有"接口在消费方"的 Go 习惯 |
| 错误模型 | **新增 5 个 forge sentinel**：sync 状态相关 | env 准备失败、依赖解析失败、超时、env 未就绪都需要清晰区分 |
| 旧 forge 数据迁移 | **不预先 sync，懒加载**：Run 时若 .venv 不存在，先同步再跑 | AutoMigrate 加列默认 EnvStatus="pending"，第一次跑触发首次 sync；之后路径热 |
| 资源限制 / 安全隔离 | **本迭代不做** | 设计原则 #6——本地单用户单作者；Forge 本身就是用户自己生成的代码 |
| 离线时的行为 | **Run 行得通**（venv 已 sync）；**Sync 失败转 EnvStatus="failed"** | 用户离线写 forge → 报"无法装依赖"；联网后用户能手动重 sync |
| Sync 并发同 forge | **per-forge mutex**（in-memory）| 简单可靠；不上 job queue |
| **Run 超时** | **不设 timeout**——只靠上游 ctx-cancel | 工具可能正常需跑很久（数据处理 / 大型计算）；死循环是 LLM/用户的问题，不是 sandbox 的问题；上游 ctx-cancel（用户取消 / 对话关闭）能正确停 |

---

## 6. 数据模型扩展

### 6.1 `forgedomain.Forge` 加字段

```go
type Forge struct {
    // ── 既有字段（不变）──
    ID, UserID, Name, Description, Code, Parameters, ReturnSchema, Tags string
    VersionCount int
    CreatedAt, UpdatedAt time.Time
    DeletedAt gorm.DeletedAt

    // ── 本迭代新增 ──

    // Dependencies 是 PEP 508 specifier 列表，例 ["pandas>=2.0", "requests"]。
    // 空数组 = 仅 stdlib。LLM 在 create_forge / edit_forge 时根据 import 申报。
    //
    // Dependencies 是 PEP 508 specifier 列表，例 ["pandas>=2.0", "requests"]。
    // 空数组 = 仅 stdlib。LLM 在 create_forge / edit_forge 时根据 import 申报。
    Dependencies string `gorm:"type:text;default:'[]'" json:"dependencies"` // JSON array of strings

    // PythonVersion 形如 ">=3.12"；空 = 用 sandbox 默认。
    //
    // PythonVersion 形如 ">=3.12"；空 = 用 sandbox 默认。
    PythonVersion string `gorm:"type:text;default:''" json:"pythonVersion"`

    // EnvStatus 是 venv 物化状态："pending" | "syncing" | "ready" | "failed"。
    // 由 sandbox sync worker 推进；service 层只读。
    //
    // EnvStatus 是 venv 物化状态。由 sandbox sync worker 推进；service 层只读。
    EnvStatus string `gorm:"type:text;default:'pending'" json:"envStatus"`

    // EnvError 是最近一次 sync 失败的错误信息（多行，如 uv 解析失败的输出）；
    // EnvStatus="failed" 时填。
    //
    // EnvError 是最近一次 sync 失败的错误信息；EnvStatus="failed" 时填。
    EnvError string `gorm:"type:text;default:''" json:"envError"`

    // EnvSyncedAt 是最近一次 sync 成功时间。EnvStatus="ready" 时非零。
    //
    // EnvSyncedAt 是最近一次 sync 成功时间。
    EnvSyncedAt *time.Time `json:"envSyncedAt"`

    // EnvSyncStage 是 sync 期间的当前阶段标签："resolving" | "downloading" |
    // "installing" | "" (非 syncing 时清空)。EnvStatus="syncing" 时由解析
    // uv stderr 的 progress.go 持续更新，每变化一次写库 + 推 forge 快照——
    // 跟 chat token 流推 ChatMessage 快照同心智。EnvStatus 转 ready/failed
    // 时清空。
    //
    // EnvSyncStage 是 sync 期间的当前阶段标签。EnvStatus="syncing" 时由
    // progress.go 解析 uv stderr 持续更新；其他状态时清空。
    EnvSyncStage string `gorm:"type:text;default:''" json:"envSyncStage"`

    // EnvSyncDetail 是 sync 期间的当前一行详情（uv stderr 当前行 trim 后），
    // 例如 "Downloaded numpy (15 MB) in 2.1s"。仅 EnvStatus="syncing" 时填；
    // 失败时 EnvError 承载完整失败信息，不复用此字段。
    //
    // EnvSyncDetail 是 sync 期间的当前一行详情。仅 EnvStatus="syncing" 时填。
    EnvSyncDetail string `gorm:"type:text;default:''" json:"envSyncDetail"`
}
```

> **不加** `Destructive` / `IsReadOnly` / `IsConcurrencySafe` 静态字段——destructive 走 §S18 既有的 **per-call AI 自报** 模式（`destructive` standard field 由 framework 注入 args、LLM 每次调用现场判断、StripStandardFields 剥进 `chatdomain.ToolCallData.Destructive` + `events.ChatToolCall.Destructive`）。理由：同 tool 不同 args 的 destructive 性可能不同（`run_forge(safe_calculator)` vs `run_forge(bulk_file_deleter)`），LLM 现场判精准胜于 entity 静态值。`IsReadOnly` / `IsConcurrencySafe` 同理——若未来要并发分批 forge，按 §S18 模板让 `RunForge.IsConcurrencySafe(args)` 自己决策（可读 args 现场判断），不在 entity 落地。

> **EnvSync* 字段进 entity 而非临时内存态**：因为 `forge` SSE 事件载荷规约 = REST GET 形状（Phase 6 entity-state 模型）——前端 reload 后调 GET 拿到的 entity 必须能反映出当前 syncing 进度。所以这些进度字段必须持久化到 forges 表里。每帧推送伴随一次 DB 写——uv 5-8 秒输出 5-8 行，sync 期间约 5-20 次 DB 写，跟 chat token 流写 message_blocks 同量级。

### 6.2 `forgedomain.ForgeVersion` 也加 Dependencies

按 §3.2 的"完整快照"原则，version 也要带依赖快照。这样 RevertToVersion 能恢复历史依赖集。

```go
type ForgeVersion struct {
    // ... 既有
    Dependencies  string  `gorm:"type:text;default:'[]'"`
    PythonVersion string  `gorm:"type:text;default:''"`
}
```

不需要在 ForgeVersion 上存 EnvStatus——env 是当前活跃代码的运行时状态，不是版本历史的属性。

### 6.3 EnvStatus 状态机

```
        Create / 改 deps
              │
              ▼
         ┌─────────┐
         │ pending │   ← AutoMigrate 老数据默认值；新建 forge 初始值
         └────┬────┘
              │ sync worker 拿到任务
              ▼
         ┌─────────┐
         │ syncing │   ← 唯一可观测的"忙"状态；推 SSE 进度
         └────┬────┘
              │
       ┌──────┴──────┐
       ▼             ▼
   ┌───────┐    ┌────────┐
   │ ready │    │ failed │   ← EnvError 含 uv 输出
   └───┬───┘    └────┬───┘
       │             │
       │ 改 deps     │ 用户手动 retry / 改 deps
       │             │
       └──────┬──────┘
              ▼
         (回 pending)
```

**白名单**：稳定四值，按 §D3 走 DB CHECK 约束。

```sql
CHECK (env_status IN ('pending','syncing','ready','failed'))
```

加进 `infra/db/schema_extras.go` 的 forges group。

### 6.4 数据库变更总览

| 表 | 新增列 |
|---|---|
| `forges` | `dependencies TEXT DEFAULT '[]'`, `python_version TEXT DEFAULT ''`, `env_status TEXT DEFAULT 'pending'`, `env_error TEXT DEFAULT ''`, `env_synced_at DATETIME`, `env_sync_stage TEXT DEFAULT ''`, `env_sync_detail TEXT DEFAULT ''` |
| `forge_versions` | `dependencies TEXT DEFAULT '[]'`, `python_version TEXT DEFAULT ''`（**不加** EnvSync* 字段——版本快照只存"配置态"不存"运行时态"）|
| `schema_extras` | forges 组追加 `CHECK(env_status IN ...)` 约束 |

**索引**：env_status 不上索引——单用户级别 forge 数 < 1000，全表扫够。

**迁移**：AutoMigrate 自动加列；老数据 `env_status='pending'` 默认值——第一次 Run 时懒加载触发 sync。

---

## 7. Sandbox 模块文件结构（§S12 平铺）

`internal/infra/sandbox/` 从 1 文件涨到 ~6 文件。按概念拆，不按种类拆。

```
internal/infra/sandbox/
├── sandbox.go        ← Package doc + Sandbox struct + Run() + 主入口
├── sync.go           ← Sync()：跑 uv sync，逐行调 OnProgress callback
├── preflight.go      ← Bootstrap()：启动期校验/解压 uv + Python
├── paths.go          ← 路径解析：uv binary、bundled Python、forge dirs、UV_CACHE_DIR
├── pyproject.go      ← 渲染 pyproject.toml（小文件，独立概念）
├── progress.go       ← 解析 uv stderr 行 → 结构化 ProgressUpdate(stage, detail)
└── sandbox_test.go   ← 测试集中
```

`PythonSandbox` 类型名留还是改？建议改成 `Sandbox`——本类已不只跑 Python（还管 uv venv），名字保留 Python 反而误导。

包别名按 §S13 仍 `sandboxinfra`。

> **关键**：`progress.go` 不直接发 SSE——它只把 uv stderr 行解析成 `(stage, detail)` 结构，调用 `SyncRequest.OnProgress` callback。callback 在 forgeapp 层实现（写 forge 字段 + 触发 forge entity-state 推快照）。沙箱不知道也不关心 SSE 的存在——这跟 Phase 6 立的"chat 层是唯一发布事实源"规矩同源（每个 entity 的 publish 都收口在它自己的 service 层）。

### 7.1 主类型骨架

```go
// internal/infra/sandbox/sandbox.go

type Config struct {
    DataDir       string         // <dataDir>，所有运行时数据落地点
    UVPath        string         // 已就绪的 uv 二进制路径（preflight 之后填）
    PythonPath    string         // 捆绑 Python 解释器路径（preflight 之后填）
    DefaultPython string         // 默认 PythonVersion specifier，形如 ">=3.12"
    Logger        *zap.Logger
}

type Sandbox struct {
    cfg     Config
    log     *zap.Logger
    syncMu  *forgeMutexMap  // per-forge sync 互斥
}

func New(cfg Config) *Sandbox

// 接口契约（实现 forgeapp.Sandbox 扩展后版本）：
func (s *Sandbox) Sync(ctx context.Context, req SyncRequest) error
func (s *Sandbox) Run(ctx context.Context, req RunRequest) (*forgedomain.ExecutionResult, error)
func (s *Sandbox) Destroy(ctx context.Context, forgeID string) error
```

---

## 8. 接口扩展

### 8.1 `forgeapp.Sandbox` 接口

```go
// app/forge/forge.go

type Sandbox interface {
    // Sync 物化 forgeID 对应的 .venv：
    //   - 写 pyproject.toml
    //   - 跑 `uv sync`（联网装 wheel）
    //   - 推 SSE 进度事件（如 bridge 注入）
    // 返回时 venv 已 ready 或返 error；调用方据此更新 EnvStatus。
    //
    // Sync 物化 forgeID 对应的 .venv。返回时 venv 已 ready 或返 error。
    Sync(ctx context.Context, req SyncRequest) error

    // Run 在已 ready 的 .venv 中执行 forge 代码。
    // 调用前应确保 EnvStatus="ready"；否则应先调 Sync。
    //
    // Run 在已 ready 的 .venv 中执行 forge 代码。
    Run(ctx context.Context, req RunRequest) (*forgedomain.ExecutionResult, error)

    // Destroy 删除 forgeID 对应的目录（含 .venv）。软删 forge 时调用。
    //
    // Destroy 删除 forgeID 对应目录。
    Destroy(ctx context.Context, forgeID string) error
}

type SyncRequest struct {
    ForgeID       string
    Dependencies  []string  // PEP 508 specifiers
    PythonVersion string    // ">=3.12" 等；空 = 用 sandbox 默认
}

type RunRequest struct {
    ForgeID       string
    Code          string             // 完整函数源
    EntryFunction string             // 默认 ""，为空时仍走老 extractFuncName 兜底
    Input         map[string]any
}
```

注意：**Sync 和 Run 都接 ctx，没有 timeout 字段**——sandbox 完全不强加运行时长限制，工具想跑 1 小时也行。停止只来自上游 ctx 取消（用户在 chat 里点取消 / 对话关闭 / 进程退出）。

### 8.2 `forgeapp.Service` 新增方法

```go
// 触发 forge env 异步重同步。在 Create / UpdateDependencies 内部自动调；
// 也作为 HTTP 端点 POST /api/v1/forges/{id}:resync 的 service 入口
// 用于"sync 失败后用户手动重试"或"venv 损坏后修复"。
//
// 触发 forge env 异步重同步。
func (s *Service) ResyncEnv(ctx context.Context, forgeID string) error

// 内部：转 EnvStatus；外部不直接暴露。
func (s *Service) markEnvSyncing(ctx, forgeID) error
func (s *Service) markEnvReady(ctx, forgeID, syncedAt time.Time) error
func (s *Service) markEnvFailed(ctx, forgeID, errMsg string) error
```

`Create` / `Update`（带 deps）/ `AcceptPending`（pending 的 deps 跟现有不同时）/ `RevertToVersion`（依赖变化时）——都自动 enqueue 一次 ResyncEnv。

### 8.3 异步 sync worker

```go
// app/forge/sync_worker.go (新文件，平铺在 app/forge/)

type SyncWorker struct {
    svc    *Service
    sb     Sandbox
    log    *zap.Logger
    queue  chan string  // forge ID
    wg     sync.WaitGroup
}

func NewSyncWorker(svc *Service, sb Sandbox, log *zap.Logger) *SyncWorker

func (w *SyncWorker) Start(ctx context.Context)
func (w *SyncWorker) Enqueue(forgeID string)
func (w *SyncWorker) Stop()  // graceful: 当前任务跑完，不接新任务
```

实现：channel + N 个 worker goroutine（N=2 起步——uv 内部已用全局锁，太多并发收益有限）。

**关键**：worker 写 DB 用 detached context（§S9）——上游 HTTP 请求可能早就返回了，但 sync 必须把状态写进 DB。

```go
func (w *SyncWorker) handleOne(forgeID string) {
    // 取 forge 信息
    bgCtx := reqctxpkg.SetUserID(context.Background(), forge.UserID)
    bgCtx, cancel := context.WithTimeout(bgCtx, 10*time.Minute)  // sync 上限 10 分钟
    defer cancel()
    // ... markEnvSyncing → sandbox.Sync → markEnvReady/Failed
}
```

---

## 9. 启动期 Preflight

### 9.1 调用点

`cmd/server/main.go` 在 DB Migrate 后、HTTP 起前：

```go
sb := sandboxinfra.New(sandboxinfra.Config{
    DataDir:       *dataDir,
    DefaultPython: ">=3.12",
    Bridge:        eventsBridge,
    Logger:        log,
})

if err := sb.Bootstrap(ctx); err != nil {
    // 不阻断 backend 启动——sandbox 不可用时其它功能仍能用
    // 把状态记进 sandbox，让 forge 操作返 422
    log.Error("sandbox bootstrap failed", zap.Error(err))
}

forgeService := forgeapp.NewService(forgestore.New(gdb), sb, forgeLLM, log)
syncWorker := forgeapp.NewSyncWorker(forgeService, sb, log)
syncWorker.Start(ctx)
defer syncWorker.Stop()
```

### 9.2 Bootstrap 步骤

```go
func (s *Sandbox) Bootstrap(ctx context.Context) error {
    // 1. 确保 dataDir / bin / forges / uv-cache 子目录存在
    // 2. 从 embed.FS 提取 uv 二进制到 <dataDir>/bin/uv（chmod +x）
    //    若文件已存在且 hash 一致，跳过
    // 3. 从 embed.FS 解压 Python 到 <dataDir>/bin/python/
    //    若已存在且 version 文件标记一致，跳过
    // 4. 跑 `uv --version` 校验 uv 能用
    // 5. 跑 `<bundled-python> -c "import sys; print(sys.version)"` 校验 Python 能用
    // 6. macOS：尝试 xattr -dr com.apple.quarantine <python dir>，失败仅 warn
    // 7. 把 cfg.UVPath / cfg.PythonPath 填好
    return nil
}
```

**embed.FS 资源位置**：`cmd/server/main.go` 不 embed 这些大文件——这些是桌面端 `cmd/desktop` 的事。`cmd/server` 期望这些资源已经在 `<dataDir>/bin/` 下了；找不到就在 dev 模式下从 `$FORGIFY_DEV_RESOURCES` 环境变量指定的目录拷一份。

这样：
- **dev**：开发者本机一次手动下 uv + python-build-standalone 到 `~/.forgify-dev-resources/`，设环境变量。`cmd/server` 启动自动拷过去。
- **prod (cmd/desktop)**：embed.FS 进 .app；启动期解到 dataDir。

### 9.3 失败降级

Bootstrap 失败时不挂掉整个 backend，但要让 forge 相关操作明确报错：

- `Sandbox.unavailable bool` + `Sandbox.unavailableReason string` 字段
- 任何 `Sandbox.Sync/Run/Destroy` 入口先检查这两字段，true 时返 `ErrSandboxUnavailable`
- 错误码登记：`SANDBOX_UNAVAILABLE` → 503

---

## 10. 端到端调用链（设计原则 #5）

### 链 1：LLM 创建带依赖的 forge

```
用户："写一个用 pandas 解析 CSV 的工具"

  → LLM tool_call create_forge {
      name: "csv_parser",
      description: "Parse CSV with pandas",
      instruction: "...",
      summary: "Creating CSV parser",
      destructive: false,
    }

  → forgetool.CreateForge.Execute               app/tool/forge/create.go
    → streamCode → LLM 流出 Python 代码（带 import pandas）
    → forgeapp.Service.ParseCode(code)         AST dry-run；同时提取 imports
    → derive dependencies（见 §11.1）
    → forgeapp.Service.Create(ctx, CreateInput{
        Name:..., Code:..., Dependencies: ["pandas>=2.0"]
      })
        → repo.SaveForge with EnvStatus="pending"
        → repo.SaveVersion(v1, accepted, dependencies=["pandas>=2.0"])
        → syncWorker.Enqueue(forgeID)              ← 异步！
    → bridge.Publish forge.created
    → return tool_result {forge_id, name, parameters, env_status:"pending"}

  ── 异步分支：sync worker pick up ────────────────────────────
  → SyncWorker.handleOne(forgeID)
    → markEnvSyncing → 推 sandbox.sync_started SSE
    → sandbox.Sync(ctx, SyncRequest{
        ForgeID: forgeID, Dependencies: [...], PythonVersion: ">=3.12"
      })
        → 创建 <dataDir>/forges/<id>/
        → 写 pyproject.toml
        → exec.Command(uv, "sync", "--project", forgeDir, "--python", bundledPython)
        → 解析 stderr → 推 sandbox.sync_progress SSE
        → 等返
    → markEnvReady（成功）or markEnvFailed（失败）
    → 推 sandbox.sync_ready / sandbox.sync_failed SSE
```

### 链 2：LLM 执行已就绪的 forge

```
用户："用刚才的工具处理 report.csv"

  → LLM tool_call run_forge {
      forge_id: "f_abc123",
      input: { csv_path: "att_xyz" },
      summary: "Running csv_parser on report.csv",
    }

  → forgetool.RunForge.Execute
    → resolveAttachments → att_xyz → /data/.../original.csv
    → forgeapp.Service.RunForge(ctx, forgeID, input)
      → repo.GetForge → 检查 EnvStatus
        - "ready"   → 继续
        - "syncing" → 返 ErrEnvNotReady（LLM 看到错误，自决重试）
        - "pending" → 触发同步 sync 阻塞 5s 内能完成就跑，否则返
        - "failed"  → 返 ErrEnvFailed + EnvError 内容
      → sandbox.Run(ctx, RunRequest{ForgeID, Code, Input})
        → 写 main.py 到 <dataDir>/forges/<id>/main.py
        → exec.Command(uv, "run", "--no-sync", "--project", forgeDir,
                       "python", "main.py")
        → cmd.Stdin = JSON(input)
        → cmd.Output() → JSON
        → 无 timeout；只随上游 ctx-cancel 终止子进程
        → 返 ExecutionResult
      → SaveRunHistory（不变）
    → 50KB 截断（不变）
    → return tool_result {ok, output, ...}
```

### 链 3：用户改依赖（edit_forge with new import）

```
用户："给 csv_parser 加一个用 numpy 计算列均值的功能"

  → LLM tool_call edit_forge {forge_id, instruction: "..."}
    → streamCode → 新代码含 import numpy
    → forgeapp.Service.ParseCode + derive deps → ["pandas>=2.0", "numpy>=1.24"]
    → forgeapp.Service.CreatePending(snap with new deps)
      → repo.SaveVersion(status="pending", dependencies=...)
    → 推 forge.pending_created（含新 deps，前端可显示"will install: numpy"）
    → return {pending_id, forge_id}

用户点 accept：

  → POST /api/v1/forges/{id}/pending:accept
    → forgeapp.Service.AcceptPending
      → 更新 forges 表（含新 dependencies + EnvStatus="pending"）
      → SaveVersion(status="accepted")
      → syncWorker.Enqueue(forgeID)         ← 重 sync
      → 返 200 {... envStatus:"pending" ...}
    → 异步 sync 推 SSE
```

### 链 4：手动 resync（venv 损坏修复）

```
POST /api/v1/forges/{id}:resync

  → handler → forgeapp.Service.ResyncEnv(ctx, forgeID)
    → markEnvPending
    → syncWorker.Enqueue
  → 200 envelope { envStatus: "pending" }
  → 异步推 sandbox.sync_started → progress → ready/failed
```

### 链 5：删除 forge

```
DELETE /api/v1/forges/{id}

  → forgeapp.Service.Delete
    → repo.DeleteForge（软删，沿用既有逻辑）
    → sandbox.Destroy(ctx, forgeID)        ← 新增：物理删 forge dir
                                              即使 sync 在跑，也强制取消并删
                                              （per-forge mutex 等当前 sync 退出再删）
  → 204
```

软删保留 forge 元数据用于 audit / undelete；但 venv 物理目录删掉——venv 平均 50-200MB，没必要保留。

---

## 11. 关键细节

### 11.1 LLM 提交的 dependencies 哪里来

两条路：

**路径 A**：LLM 在 `create_forge` / `edit_forge` 的 args 里显式带 `dependencies` 字段。
**路径 B**：从代码里自动提取 import 推断。

**选择 A + B 结合**：

- LLM args 里加 `dependencies` 字段（可选）
- backend 在 `ParseCode` 时同时跑一个简单的 import 提取（top-level + typed import 都数）
- LLM 显式给 = 用 LLM 的；LLM 没给 = 用提取的
- 写 `extractImports(code) → []string` 在 `app/forge/ast.go` 里加（既然已经在 Python 里 ast 了，复用同一个 subprocess 多输出一个字段）

LLM 显式给的优势：版本约束（`pandas>=2.0`），用户分发场景。
自动提取的优势：用户写代码忘了写 deps 时不挂。

### 11.2 stdlib vs 第三方包识别

需要避免把 `import json` 加进 dependencies。维护一个 stdlib whitelist（Python 3.12 stdlib 大概 200 个模块；硬编码即可）。在 `ast.go` 里：

```go
var pythonStdlibModules = map[string]bool{
    "json": true, "sys": true, "os": true, "ast": true, "io": true,
    "csv": true, "datetime": true, "re": true, "math": true,
    "collections": true, "itertools": true, "functools": true,
    // ... 完整列表
}

func filterStdlib(imports []string) []string {
    // 取 import 第一段（"a.b.c" → "a"），不在 whitelist 里的留下
}
```

### 11.3 pyproject.toml 渲染

最小可工作形态：

```toml
[project]
name = "forge-{{forgeID}}"
version = "0.1.0"
requires-python = "{{pythonVersion}}"
dependencies = [
    "pandas>=2.0",
    "requests",
]

[tool.uv]
managed = true
```

`pyproject.go::renderPyproject(req SyncRequest) string` 用 `text/template` 或裸字符串拼接（依赖列表注意 quote escape——用 `strconv.Quote`）。

### 11.4 main.py driver 注入

继承现有 `python.go::driver` 的 `__main__` block 模式，但优化：

```python
# 用户代码（直接写入）
def parse_csv(...): ...

# Driver（每次 run 时 sandbox 注入）
if __name__ == "__main__":
    import json as _json, sys as _sys
    try:
        _input = _json.load(_sys.stdin)
        _result = parse_csv(**_input)
        print(_json.dumps(_result, default=str))
    except SystemExit:
        raise
    except BaseException as _e:
        # 把异常作为 stderr 输出，但 exit 0——让 Go 侧把 exit code 当 sandbox
        # 错误（subprocess fail），Python 异常进 ErrorMsg
        import traceback as _tb
        print(_tb.format_exc(), file=_sys.stderr)
        _sys.exit(1)
```

或者更简单：直接让 Python 异常 exit code != 0，Go 侧捕 ExitError 把 stderr 灌进 ErrorMsg（这就是当前行为，保留）。

`extractFuncName` 现在的实现（找第一个 `def`）有点脆——可以复用 `parseForgeCode` 里已经准确解析出的 `FuncName` 字段。这次顺手把 sandbox 改成接收 `EntryFunction string`，由 service 层从 ParsedCode 拿来传。

### 11.5 进度事件解析

uv `sync` 的 stderr 输出形如：

```
 Resolved 12 packages in 1.5s
Downloaded 12 packages in 800ms
Installed 12 packages in 200ms
```

各种阶段 line-by-line 推过来。`progress.go` 用 line scanner 解析：

```go
func parseUVLine(line string) *eventsdomain.SandboxSyncProgress {
    switch {
    case strings.HasPrefix(line, "Resolved"):
        return &eventsdomain.SandboxSyncProgress{Stage: "resolved", Detail: line}
    case strings.HasPrefix(line, "Downloaded"):
        return &eventsdomain.SandboxSyncProgress{Stage: "downloaded", Detail: line}
    // ...
    }
    return nil  // 无法解析的 line 忽略，不推
}
```

不需要太精细——能让 UI 显示"正在装包..."就够。

### 11.6 ast.go 也走捆绑 Python

现在 `ast.go::parseForgeCode` 写死 `python3`。改成接收 `pythonPath`：

```go
// app/forge/ast.go

type ASTParser struct {
    pythonPath string
}

func NewASTParser(pythonPath string) *ASTParser
func (p *ASTParser) Parse(code string) (*ParsedCode, error)
```

`Service.parse()` 持有一个 `*ASTParser`，注入路径来自 sandbox 的 PythonPath。

ast.go 不需要 venv（ast 模块在 stdlib），直接 `<bundledPython> ast_script.py < code`。

### 11.7 Cancel 语义

`run_forge` 是 ReAct loop 里的一步。用户在 chat 里点取消 → ctx 取消传到 Run → `exec.CommandContext` 自动 kill。**注意** Python 进程可能 fork 子进程，要 kill 整个 process group：

```go
cmd := exec.CommandContext(ctx, ...)
cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
// 单独写 kill 函数：syscall.Kill(-cmd.Process.Pid, SIGKILL)
// Cmd.Cancel = func() error { ... }（Go 1.20+）
```

Windows 用 `taskkill /T /F /PID`。

### 11.8 per-forge sync mutex

```go
// internal/infra/sandbox/sandbox.go

type forgeMutexMap struct {
    mu sync.Mutex
    m  map[string]*sync.Mutex
}

func (m *forgeMutexMap) Lock(forgeID string) func() {
    m.mu.Lock()
    fm, ok := m.m[forgeID]
    if !ok {
        fm = &sync.Mutex{}
        m.m[forgeID] = fm
    }
    m.mu.Unlock()
    fm.Lock()
    return fm.Unlock
}
```

简单可靠。Sync 和 Destroy 都过它；Run 不过（一个 forge 多个 Run 并发是允许的）。

清理：很少删 forge，map 增长不大；可以 forge delete 时连带从 map 里删。

---

## 12. 错误模型

新增 sentinels 和 errmap 行（按 §S17 错误码必须登记）：

```go
// domain/forge/forge.go

var (
    // 既有错误...

    // ErrEnvNotReady：forge 的 venv 还在 syncing / pending，run 不能执行
    ErrEnvNotReady = errors.New("forge: env not ready")

    // ErrEnvFailed：forge 的 venv sync 失败，处于 EnvStatus="failed"
    // 详细错误信息在 forge.EnvError 字段
    ErrEnvFailed = errors.New("forge: env failed")

    // ErrSandboxUnavailable：sandbox bootstrap 失败，整个沙箱不可用
    ErrSandboxUnavailable = errors.New("forge: sandbox unavailable")

    // ErrDependencyResolution：uv 无法解析依赖（包名拼错 / 版本约束冲突）
    ErrDependencyResolution = errors.New("forge: dependency resolution failed")
)
```

> 不引入 `ErrSandboxTimeout`——本迭代决策无 run 超时，唯一停止信号是 ctx-cancel。Ctx 取消时上游已有错误（context.Canceled / DeadlineExceeded）走通用错误路径返回，不需要 forge 特异 sentinel。

errmap 新增行：

| Code | HTTP | Sentinel |
|---|---|---|
| `FORGE_ENV_NOT_READY` | 422 | `ErrEnvNotReady` |
| `FORGE_ENV_FAILED` | 422 | `ErrEnvFailed` |
| `FORGE_SANDBOX_UNAVAILABLE` | 503 | `ErrSandboxUnavailable` |
| `FORGE_DEPENDENCY_RESOLUTION` | 422 | `ErrDependencyResolution` |

注意 `TOOL_*` 前缀的旧错误码（来自 Phase 3）已经在 Phase 1 大重命名时改成 `FORGE_*` 了——见 progress-record.md 2026-05-02 条目。新增按 `FORGE_*` 走。

---

## 13. SSE 事件

新增 4 个事件（按 §E1 强类型 + §E2 snake_case 分层 + 必带过滤 key）：

```go
// domain/events/types.go 追加

// SandboxSyncStarted 在某 forge 开始 sync 时推。
// 过滤 key：global（不属于某对话；前端按 forgeId 过滤）。
//
// SandboxSyncStarted 在某 forge 开始 sync 时推。
type SandboxSyncStarted struct {
    ForgeID      string   `json:"forgeId"`
    Dependencies []string `json:"dependencies"`
}
func (SandboxSyncStarted) EventName() string { return "sandbox.sync_started" }

// SandboxSyncProgress 在 uv sync 过程中推。
//
// SandboxSyncProgress 在 uv sync 过程中推。
type SandboxSyncProgress struct {
    ForgeID string `json:"forgeId"`
    Stage   string `json:"stage"`  // "resolved" | "downloaded" | "installed" 等
    Detail  string `json:"detail"` // uv stderr 一行
}
func (SandboxSyncProgress) EventName() string { return "sandbox.sync_progress" }

// SandboxSyncReady 在 forge env 同步成功时推。
//
// SandboxSyncReady 在 forge env 同步成功时推。
type SandboxSyncReady struct {
    ForgeID  string `json:"forgeId"`
    Duration int64  `json:"durationMs"`
}
func (SandboxSyncReady) EventName() string { return "sandbox.sync_ready" }

// SandboxSyncFailed 在 forge env 同步失败时推。
//
// SandboxSyncFailed 在 forge env 同步失败时推。
type SandboxSyncFailed struct {
    ForgeID string `json:"forgeId"`
    Error   string `json:"error"`
}
func (SandboxSyncFailed) EventName() string { return "sandbox.sync_failed" }
```

**过滤上下文**：sandbox 事件不绑定 conversation——用户可能在 forge 详情页看自己手动建的 forge 同步进度，没有 chat。Bridge 已有"无 conversationId 走 global broadcast"的能力（既有 SSE 订阅端点 `?conversationId=` 可空），前端按 `forgeId` 过滤。

**Bridge 调用**：sandbox 的 `Sync` 方法接 `eventsdomain.Bridge` 注入，直接 `bridge.Publish(ctx, "", SandboxSyncProgress{...})`（空 conversationId）。

---

## 14. 跨平台细节

| 平台 | uv 二进制 | Python 路径 | 注意 |
|---|---|---|---|
| mac arm64 | `bin/uv` | `bin/python/bin/python3` | 公证：uv 是 Astral 签的，应继承 .app 公证；Python 子进程加载的 .dylib 可能触发 quarantine——`xattr -dr` 处理 |
| mac amd64 | 同上 | 同上 | 同上 |
| linux amd64/arm64 | `bin/uv` | `bin/python/bin/python3` | 无 Gatekeeper 麻烦；AppImage 内嵌资源解压到 `~/.local/share/forgify/bin/` |
| windows amd64 | `bin/uv.exe` | `bin/python/python.exe`（**直接在根目录**）| SmartScreen：uv 应有 Authenticode 签名；Python 自身签了 |

**process group kill**：mac/linux 用 `Setpgid + Kill(-pid)`；windows 用 `os/exec` 1.20+ 的 `Cmd.CancelExec` 或 `taskkill /T /F /PID`。封装成 `paths.go::killProcessGroup(cmd)`。

**路径分隔符**：用 `filepath.Join` 全程。

**uv 运行 Python**：

```go
// mac/linux
exec.Command(uvPath, "run", "--project", forgeDir,
    "--python", "<dataDir>/bin/python/bin/python3",
    "python", "main.py")

// win
exec.Command(uvPath, "run", "--project", forgeDir,
    "--python", "<dataDir>\\bin\\python\\python.exe",
    "python", "main.py")
```

---

## 15. 与既有 forge 系统的对接

### 15.1 老 forge 数据迁移

现状：DB 里已经有 forge 记录（即使最少也有测试创建的）。AutoMigrate 加新列时：

- `dependencies = '[]'`
- `python_version = ''`
- `env_status = 'pending'` ← 关键
- `env_error = ''`
- `env_synced_at = NULL`

**第一次 Run 触发懒同步**：`Service.RunForge` 判断 `EnvStatus != "ready"` → 同步阻塞调 `sandbox.Sync`（5s 超时，超时给 LLM 返 ErrEnvNotReady） → 成功后继续 Run。

懒同步路径只走"无依赖 forge"——纯 stdlib 代码，sync 几乎瞬间（uv venv 创建 + 无依赖装）。带依赖的 forge 老数据不存在（依赖字段是新增）。

也可以提供启动期 batch sync：`cmd/server` 启动后 enqueue 所有 EnvStatus="pending" 的 forge。但这会让启动看起来很忙。**选懒加载**——简单 + 用户视角符合直觉（"我点 run 才看到准备过程"）。

### 15.2 dependencies 字段 LLM 接口

`create_forge` / `edit_forge` 的 schema 加：

```json
{
  "dependencies": {
    "type": "array",
    "items": {"type": "string"},
    "description": "PEP 508 specifiers like ['pandas>=2.0','requests']. Required for non-stdlib imports. Empty if forge uses only Python stdlib."
  }
}
```

LLM 看到代码 `import pandas` 时应该填进去。Description 文本里点明这是契约。

### 15.3 prompt 改动

`buildCreatePrompt` / `buildEditPrompt` 在 Requirements 段加一条：

> - When the function uses non-stdlib packages, declare them as PEP 508 specifiers in the dependencies argument (e.g. `["pandas>=2.0"]`). The system will install them automatically.

LLM 自己判断哪些是 stdlib（基本能判对）。后端再用 `extractImports + filterStdlib` 兜底。

### 15.4 testend 工具面板

`testend` 的 forge 详情页要加：
- env_status 徽章（pending / syncing / ready / failed）
- 失败时显示 env_error
- "Resync" 按钮 → POST `/api/v1/forges/{id}:resync`
- SSE 订阅 sandbox.* 事件渲染进度

这是 testend-design.md 的事，跟主线代码改动并行做。

---

## 16. 测试策略（T1-T4）

### 16.1 单元测试（不依赖外部）

`paths.go` / `pyproject.go` / `progress.go` 这些纯计算的函数：

- `TestRenderPyproject_BasicDeps` 渲染对
- `TestRenderPyproject_EmptyDeps` 渲染对
- `TestParseUVProgress_ResolvedLine` 识别阶段
- `TestForgeMutexMap_PerForgeIsolation` 不同 forge 不互锁

无 Python / uv 依赖，always run。

### 16.2 集成测试（依赖 uv + Python）

按 T3 用环境变量门控：

```go
func TestSandboxSync_BasicForge(t *testing.T) {
    uvPath := os.Getenv("FORGIFY_TEST_UV")
    pythonPath := os.Getenv("FORGIFY_TEST_PYTHON")
    if uvPath == "" || pythonPath == "" {
        t.Skip("FORGIFY_TEST_UV / FORGIFY_TEST_PYTHON not set")
    }
    sb := sandboxinfra.New(sandboxinfra.Config{
        DataDir: t.TempDir(), UVPath: uvPath, PythonPath: pythonPath,
    })
    err := sb.Sync(context.Background(), SyncRequest{
        ForgeID: "f_test",
        Dependencies: []string{"requests"},
    })
    // ... 验证 .venv 存在、能 import requests 等
}
```

### 16.3 端到端（带 LLM）

`forge_dependency_e2e_test.go`（按现有 chat 集成测试模式）：
1. CreateForge with `import pandas` → 后台 sync → Run → ok
2. EditForge 改 dep → 新 pending → Accept → re-sync → Run → ok
3. EditForge dep 拼错 → Accept → sync 失败 → 错误信息含 uv 输出

需要 DEEPSEEK_API_KEY。沿用现有 LLM 集成测试基线（5 个，不算回归）。

### 16.4 现有 sandbox 测试如何改

`infra/sandbox/python_test.go` 8 个老测试：

- 改成构造 `sandboxinfra.New(Config{...})`，从环境变量取 uv + python
- ENV 缺则全部 t.Skip
- 命名按 §T1：`Test<Method>_<Scenario>` —— `TestSandboxRun_BasicExecution` 等

---

## 17. 桌面端打包对接

`cmd/desktop` 还没写（属于未来工作）。但本迭代要为它**留好接口**：

1. **`cmd/server` 不 embed 大资源**：靠环境变量找 uv + Python（dev）或 dataDir 已就绪（prod 由 `cmd/desktop` 在启动 `cmd/server` 前先解压）

2. **Sandbox config 来自外部**：`UVPath` / `PythonPath` 都通过 Config 传入，sandbox 自己不去找

3. **sandbox.Bootstrap 是幂等的**：启动期反复跑没问题（hash check + skip），方便 `cmd/desktop` 在每次启动重做一次保险

4. **Progress 可流到前端**：`Bridge` 接口已经能跨进程传给前端 SSE，桌面端 UI 可以监听

**未来 cmd/desktop 的事**（不在本迭代）：

- Wails 启动序列：解压资源 → 起 backend → 监听 backend `BACKEND_PORT=...` 输出 → 打开窗口
- 资源版本管理：升级 app 时新版 uv / Python 替换旧的（hash 不同就重新解压）
- 卸载：dataDir 留（用户数据），bin/ 删（大文件）

---

## 18. 安全 / 隔离 / 资源限制

明确划界：**本迭代什么都不做**。

- 文件系统隔离：❌ forge 跑在用户进程权限下
- 网络隔离：❌ forge 想访问任意 URL 都行
- 内存 / CPU 限制：❌ 完全不限——run 时长无 timeout（决策见 §5）；内存/CPU 让 OS 自己调度
- 包供应链：❌ 任意 PyPI 包都能装

**本地单用户单作者**——用户自己的 LLM 帮自己写代码自己用，跟用户在 terminal 里 `python -c '...'` 没本质区别。这条契合 desktop-packaging-notes.md §五的"本地单用户场景属过度工程"判断。

未来若做"分享 forge"（导出/导入他人的 forge），那时再补：
- `--require-hashes` + lockfile 验签
- 依赖白名单
- macOS sandbox-exec / linux bubblewrap / windows AppContainer 文件系统隔离

是 v2+ 的事，本迭代写进文档作为已知未做项即可。

---

## 19. 风险 / 未决事项

| 风险 | 影响 | 缓解 |
|---|---|---|
| python-build-standalone 在某平台 quirky | 中-高 | 选官方 release 锁版本；mac 测 quarantine；CI 跑跨平台 build |
| uv 版本跨升级行为变 | 中 | 锁 minor 版本；升级走集成回归 |
| 用户 dataDir 在 iCloud 同步盘上（mac），符号链接污染 | 低 | preflight 检测 dataDir 是否在 iCloud 路径，警告 |
| sync worker goroutine 泄漏 | 低 | Stop() graceful 退出 + ctx 串联 |
| Run 时 cmd 取消未杀干净子孙进程 | 中 | process group + 测试覆盖 |
| 同 forge 多 Run 并发竞争 main.py 文件 | 低 | 写文件用 atomic rename：`main.py.tmp` → `main.py`；或每次 run 用一个唯一 `main_<runID>.py`（脏一些但绝对无竞争） |
| 大型依赖（torch、tensorflow）几 GB | 中 | uv-cache 全局共享去重；dataDir 大用户自承担；UI 显示磁盘占用 |
| 用户禁用网络 → 无法装包 | 中 | 明确 EnvStatus="failed" + 文案"network unavailable, please connect and resync" |

未决（要在写代码前确认）：

- [ ] uv 实际跨平台行为：mac 上 uv-managed Python + bundled Python 互不打架？
- [ ] python-build-standalone 在 Wails resources 里解压的 .dylib quarantine 实际行为
- [ ] `cmd.SysProcAttr.Setpgid` 与 `Cmd.Cancel` 在 Go 1.22 是否冲突
- [ ] 所有现有 forge 集成测试在新 sandbox 下能不能跑（应能，但 ast.go 改动可能踩）

---

## 20. Phase 划分（建议）

不阻塞 Phase 4。可作为"Phase 3 后优化轮"的一项独立交付。

### Phase A：sandbox 内部（~1.5 天）

- [ ] `infra/sandbox/` 新增 6 个文件骨架（按 §7）
- [ ] `Sandbox.Bootstrap` 实现 + 单测（不依赖外部资源的部分）
- [ ] `Sandbox.Sync` 实现（拼 pyproject.toml + 跑 uv sync + 解析 stderr）
- [ ] `Sandbox.Run` 实现（uv run --no-sync）
- [ ] `Sandbox.Destroy` 实现
- [ ] per-forge mutex
- [ ] 集成测试（FORGIFY_TEST_UV + FORGIFY_TEST_PYTHON 环境门控）

### Phase B：domain + service 扩展（~1 天）

- [ ] `domain/forge` 加 5 个字段 + 5 个 sentinel + EnvStatus 常量
- [ ] `infra/store/forge` 适配新字段
- [ ] `infra/db/schema_extras` 加 forges CHECK 约束
- [ ] `app/forge` Sandbox 接口扩展
- [ ] `app/forge` SyncWorker 实现 + 测试
- [ ] `app/forge` Service.Create / Update / AcceptPending / RevertToVersion / Delete 接 sync 触发
- [ ] `app/forge/ast.go` 改成接收 pythonPath + 加 extractImports

### Phase C：tool 层 + HTTP（~半天）

- [ ] `app/tool/forge/create.go` schema 加 dependencies 字段；prompt 改
- [ ] `app/tool/forge/edit.go` 同上
- [ ] `app/tool/forge/run.go` envStatus 检查 + 错误 mapping
- [ ] `transport/httpapi/handlers/forge.go` 加 `:resync` 端点
- [ ] errmap 加 5 行
- [ ] 5 个 SSE 事件 struct + 注册

### Phase D：装配（~半小时）

- [ ] `cmd/server/main.go` preflight + sb 注入 + syncWorker 启动
- [ ] dev 模式从 FORGIFY_DEV_RESOURCES 拷资源
- [ ] make 加 `make download-resources` 一次性下 uv + python-build-standalone

### Phase E：文档同步（~1 天，按 §S14）

见 §22。

### Phase F：testend UI（~半天，并行）

- [ ] forge 详情页 envStatus 徽章
- [ ] resync 按钮
- [ ] sandbox.* SSE 进度条

总计：~4-5 天工作量。可以独立交付，不阻塞 Phase 4。

---

## 21. 不做的事（明确划界）

- ❌ 安全隔离（filesystem/network/cgroups）—— 本地单用户
- ❌ Pyodide / WASM 路线 —— 过度工程
- ❌ 多 Python 版本并存 —— 仅锁一个 3.12.x
- ❌ 自动垃圾回收 venv —— forge delete 时连带删；不做"30 天没用过的 forge env 清理"这种花活
- ❌ Sync 任务持久化队列（Redis/SQLite job）—— in-memory channel + 重启丢失，下次 Run 触发懒同步
- ❌ 依赖图可视化 / 冲突检测 UI —— uv 错误消息直接展示
- ❌ Pre-warmed Python 子进程池（避免每次 run 启动开销）—— 第二次起 Python 已经在内核 page cache，启动 ~50ms 可接受；池化是过早优化

---

## 22. 文档同步清单（§S14）

按本迭代落实时同步以下文档（每完成一个子任务勾一行）：

### 必改

- [ ] `service-design-documents/forge.md`
  - §1 决策表加 4 行：dependencies 字段 / per-forge venv / 异步 sync / sandbox 启动期 preflight
  - §3.1 Forge entity 加 5 字段
  - §3.2 ForgeVersion 加 2 字段
  - §4 常量加 EnvStatus 4 值
  - §5 sentinel 加 5 个
  - §6 Repository 接口加 markEnvSyncing / markEnvReady / markEnvFailed
  - §8 Service 加 ResyncEnv 方法
  - §10 各 system tool 流程（create/edit 加 dependencies 字段，run 加 EnvStatus 检查）
  - §11 HTTP API 表加 `:resync` 端点
  - §12 错误码加 5 行
  - §13 SSE 事件加 4 个
  - §14 调用链改写：链 1 改成异步 sync 模式；新增链 4（resync）链 5（delete with destroy）
  - §15 数据库表说明更新 forges 列
  - §16 sandbox 章节大改：原 PythonSandbox → 新 Sandbox 形态
  - §17 实现清单加本迭代项
- [ ] `service-contract-documents/database-design.md`
  - forges 表条目加 5 字段说明 + EnvStatus CHECK
  - forge_versions 表加 2 字段
- [ ] `service-contract-documents/error-codes.md`
  - 加 5 行 FORGE_ENV_* / FORGE_SANDBOX_*
- [ ] `service-contract-documents/events-design.md`
  - 加 sandbox.sync_started / progress / ready / failed 4 行
- [ ] `service-contract-documents/api-design.md`
  - 加 `:resync` 端点
- [ ] `progress-record.md`
  - dev log 加本迭代条目（按 [refactor]/[infra] 分类）
  - 当前快照"测试规模"更新
- [ ] `desktop-packaging-notes.md` §五
  - 把方案 A/C 表更新：本迭代落定 C+B 混合（标"实现中"）；删 D（Pyodide）
- [ ] `CLAUDE.md`
  - "项目特殊性"段：`infra/sandbox 用 subprocess 跑 Python` 改为 `infra/sandbox 捆绑 uv + Python，每 forge 独立 venv`
  - §S15 ID 前缀清单不变（forge_id 没改）
  - 不需要新增规范条目（uv 运维只是一个 infra 实现细节）

### 参考更新（可后再补）

- [ ] `backend-design.md` Architecture tree：`infra/sandbox/` 子树文件名展开
- [ ] testend-design.md：forge 面板 envStatus 区域

---

## 23. 一句话总结

把 sandbox 从"调系统 python3 跑临时文件"升级为**自带 Python + uv 管 venv + 每 forge 独立环境**：依赖装在创建时（异步、SSE 推进度），运行时永远是热路径（uv run --no-sync）。资源捆进 .app（Phase D 装配，cmd/desktop 时落 embed.FS）。对桌面端打包零阻塞，对 forge LLM 接口仅加一个 `dependencies` 字段。本迭代不动安全隔离——本地单用户单作者场景下没必要。

工作量 ~4-5 天，独立交付，不阻塞 Phase 4。

---

## 附录 A：与之前讨论版本的差异

之前几轮对话里我反复在两种模型间摇摆：

1. **PEP 723 inline metadata 模型**：每次 run 时 uv 临时建 venv（按 deps hash 缓存）—— 简洁但延迟在 run 时
2. **每 forge 持久 venv 模型**：sync 在创建时，run 时直接跑 —— 你提出来的方向

定稿是 **方向 2**。理由：

- 用户视角："我配工具时 = 配置时间；我用工具时 = 期待瞬时"——和 vscode 装扩展一个心智
- 实现视角：venv 物理位置 = `forges/<id>/.venv` 一一对应，所有权清晰；删 forge 顺手删 venv
- 磁盘视角：uv 的全局 wheel cache + 硬链接让"100 个 forge 都用 pandas" → pandas 只存一份
- 调试视角：venv 文件可见可检查，uv.lock 可读，比缓存目录里按 hash 命名的环境直观

PEP 723 inline 模型完全没用上——那是给 ad-hoc 一次性脚本设计的，forge 是持久工具，不匹配。
