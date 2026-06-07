---
id: DOC-121
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-08
review-due: 2026-09-01
audience: [human, ai]
---
# Shell Tools — 宿主机命令执行的三件叶子工具

> **核心地位**：`tool/shell` 是 LLM 操作宿主机的“物理之手”——三件工具 `Bash` / `BashOutput` / `KillShell`，共享一个 `ProcessManager` 管理后台任务。本包是**叶子工具适配器**（无 domain / store / handler / DDL / HTTP 端点），只实现 `app/tool` 的 5 方法接口，归 `Toolset.Resident`（高频常驻）。
>
> **灵魂三条**：① **无 cwd**——桌面 agent 没有项目根 / 当前目录，永远绝对路径或单条 `cd /abs && …`；② **危险靠 LLM 逐次自报 + 极少数硬拦截兜底**（无中央门控）；③ **后台进程模型**——`bash_id` + 256KB 环形缓冲 + 增量 drain。

---

## 1. 物理布局

```
backend/internal/app/tool/shell/
├── shell.go     # NewShellTools() → {Manager, Tools[3]}；接口断言
├── manager.go   # ProcessManager（Register/Get/Remove/Stop）+ BgProcess（环形缓冲/drain/状态机）
├── bash.go      # Bash —— 前台（超时+cap+footer）/ 后台（detached+bash_id）
├── output.go    # BashOutput —— 增量 drain + 可选 regex 过滤 + 状态尾注
├── kill.go      # KillShell —— 杀+摘除，幂等
└── danger.go    # checkDangerous —— 极少数灾难命令硬拦截清单
```

无 domain / store / handler / DDL / HTTP 端点。装配器 `NewShellTools()` 返三件套（共享一个 `ProcessManager`），由 host 装入 `Toolset.Resident`；关停时调 `Manager.Stop()` 回收后台子进程。

---

## 2. 三件工具的契约（5 方法接口）

每件按 `app/tool` 的 **5 方法**：`Name` / `Description` / `Parameters` / `ValidateInput` / `Execute`。三个标准字段（`summary` / `danger` / `execution_group`）由 framework 在 `ToLLMDef` 注入 schema、在 `StripStandardFields` 从 args 剥离——工具只声明、只收到自己的业务参数。

| 工具 | 业务参数 | 行为 | 失败语义 |
|---|---|---|---|
| `Bash` | `command` · `run_in_background?` · `timeout?` | 前台同步执行（默认 120s）/ 后台 detached（返 `bash_id`） | 软失败返 tool 串 + exit footer |
| `BashOutput` | `bash_id` · `filter?`（regex） | 取某后台进程**上次轮询以来**的新输出 + 状态尾注 | 进程不存在 → 软失败串 |
| `KillShell` | `bash_id` | 杀掉（若 running）并从注册表摘除；幂等 | 未知/已结束 id → 友好串 |

> `danger` 三级（`safe` / `cautious` / `dangerous`）由 **LLM 逐次自报**，shell 工具不预设静态下限——M2.1 R0030 纯信任。

---

## 3. 无 cwd（R0033 全局废弃）

桌面 agent 没有项目根、没有“当前目录”——它像人点 Finder 一样用绝对路径在整台机器导航。所以：

- `Bash` **不记忆工作目录**。`buildShellCmd` 不设 `cmd.Dir`，子进程继承后端进程的目录。
- `cd` 退化成**普通命令**（不再有旧版的 `cd` 状态机 / `handleCD` / `AgentState.Cwd`）。要切目录就在**单条命令内** `cd /abs/dir && …`——跨调用不记忆。
- `pkg/agentstate` **永不加 cwd 字段**（filesystem.md §8/§9 已替本工具立此规矩）。

> 旧 backend 的 `bash.go` 近一半代码在维护 cwd（`parseCDOnly` / `handleCD` / `resolveCwd` / `SetCwd`）——全部删除。

---

## 4. 危险硬拦截（兜底，非中央门控）

`danger.go` 的 `checkDangerous(command)` 在执行前匹配一个**极小的灾难清单**，命中即拒（返软失败串、不进 shell）：

| 规则 | 拦截 |
|---|---|
| `rm -r/-f` 指向 `/` `/​*` `~` `$HOME` | 根 / 整个 home 的递归删除 |
| `sudo` / `doas` | 提权（非交互必卡密码或越权） |
| `mkfs(.*)` | 格式化文件系统 |
| `dd … of=/dev/…` | 裸写块设备 |
| `> /dev/sd\|hd\|nvme\|disk\|mmcblk` | 重定向覆盖块设备 |
| `:(){ :\|:& };:` | fork bomb |

**这不是安全边界、不是 allow/deny 配置系统**。本地单用户模型信任用户，真正的控制是**每次 danger 自报**；硬拦截只是薄兜底，防自主 loop 抹盘或卡死。刻意保持精简——误伤代价高于偶尔漏网（漏网命令本就该由用户确认过）。`rm -rf ~/project/dist`（home 子目录）等**不拦**。

> 旧 backend 靠已解散的 `permissionsgate` 中央门控（M1.9 判定解散）；旧 shell.md 写的 `allow/deny` 命令清单 + `ErrCommandForbidden/PERM_DENIED` 等 6 个 HTTP 错误码——全部作废。

---

## 5. 后台进程模型

`run_in_background:true` → `Bash` detached 启动（`context.Background()`，outlive 单次 chat turn），注册到 `ProcessManager`，返 `bash_id`（`bsh_<16hex>`，**内存态、不入库**）。

- **环形缓冲**：每进程 256KB ring（`appendOutput` 溢出从头丢、回退游标）。
- **增量 drain**：`BashOutput` 调 `drainNew()` 只返**上次游标以来**的新字节 + 丢弃计数 + 状态 + exit code，推进游标。
- **状态机**：`running` / `exited(code)` / `killed` / `errored`。
- **并发 pump**：stdout/stderr 两根管各一 goroutine `pumpReader`，防一根管满死锁。
- **回收**：`KillShell` 杀 + 摘除；`Manager.Stop()` 优雅关停时尽力杀掉所有 running 子进程。

---

## 6. 前台执行

- **墙钟超时**：`context.WithTimeout`，默认 120000ms、硬上限 600000ms；超时返 `[command timed out after …]` + exit −1。
- **合并输出**：stdout + stderr 合一，截到 256KB（保留尾部 + 标注丢弃字节）。
- **exit footer**：结果**始终**带 `[exit code: N]`（超时/取消/exec 失败为 −1），避免歧义。
- **shell**：Unix `/bin/sh -c`，Windows `cmd.exe /c`（不用 PowerShell）。

---

## 7. 不做什么 — 边界

- ❌ **per-conversation sandbox auto-route** — 把 `python` / `node` 命令路由进对话 scratch env 是**波次 5**（需 conversation 生命周期）；本包跑 plain 系统 shell、**不依赖 sandbox**、不引入 `mvdan.cc/sh` 词法分析。旧 `bash_route.go` + `maybeAutoRoute` 整套留后。
- ❌ **cwd / 当前目录状态** — 见 §3。
- ❌ **PTY / 交互式命令**（`vim` `less` `sudo` 提问）— 非交互批处理；交互命令会失败或被超时强杀。
- ❌ **HTTP 端点 / DDL / 错误码** — 叶子工具，失败永不冒泡 HTTP，只回 tool-result 串供 LLM 自纠；无 sentinel、无 wire code、无 DB schema。
- ❌ **allow/deny 配置系统 / 中央门控** — 见 §4。

---

## 8. 跨域接线（实接在后续波次）

| 接线 | 当下 | 实接 |
|---|---|---|
| 三工具装入 `Toolset.Resident` | host 调 `NewShellTools()` | chat M5.2 host 组装 |
| `Manager.Stop()` 关停回收 | 立契约 | server boot/shutdown M7 |
| per-conversation scratch env auto-route | **不做** | 波次 5（chat scratch env） |
| `/dev/bash-processes` dev 端点（列后台进程，需 `ProcessManager.Snapshots`） | **不做**（Snapshots 未建） | M7（dev.go + Snapshots 一并加） |
| ID 前缀 `bsh_`（后台进程，内存态不入库） | 已登记 database.md S15 | — |

---

## 9. 测试矩阵

全离线（真子进程 `echo` / `sleep` / `printf`，0 token）：

- **TestCheckDangerous**：把硬拦截当**纯函数**测（灾难命令绝不交给 shell）——blocked 集（`rm -rf /`、`sudo`、`mkfs`、`dd of=/dev/`、fork bomb…）+ safe 集（`rm -rf /tmp/build`、`rm -rf ~/project/dist`、`dd if=a of=b`…）
- **Bash**：前台 `echo`（exit 0）/ `exit 3`（非零）/ `sleep 5` + timeout 100ms（超时）/ danger 分支（`sudo whoami` 被拦）/ **无 cwd**（`cd /tmp` 不跨调用、单条 `cd && pwd` 有效）
- **后台链**：`printf` 后台 → `BashOutput` 增量 drain 拿到全部行 → `KillShell` 幂等（再杀返 not-found）
- **BashOutput filter**：regex 只留匹配行
- **ValidateInput**：空 command / timeout 越界 / 空 bash_id / 非法 regex

---

## 10. 决策快照（纠正旧 shell.md DOC-121）

旧 DOC-121 停在 2026-05-03 的 research（cwd 状态机 + 30s + Ask pattern），之后三轮决策未更新它，本轮整篇重写对齐：

| 旧文档（作废） | 现实（本轮） |
|---|---|
| 30 秒超时 | **120s 默认 / 600s 硬上限** |
| `Permissions` `allow/deny` 命令清单 | **删**（M1.9 中央门控解散）→ danger 自报 + §4 极小硬拦截 |
| 6 个 HTTP 错误码（`PERM_DENIED` / `SHELL_TIMEOUT`…，且从未进 error-codes.md） | **删**（叶子工具无端点，软失败返串） |
| 工具名 `run_bash` | **`Bash`**（对齐 Claude Code 命名） |
| Command Interception 自动重定向当**核心原理** | **留波次 5**（§7），M3.7 跑 plain shell |
| （未提）| 新增：**无 cwd**（§3）、**后台进程模型**（§5）、256KB cap |
