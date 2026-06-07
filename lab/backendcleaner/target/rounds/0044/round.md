# R0044 — M3.7 tool 适配器组（波次 3 收官）：memory / document / shell

> 波次 3 真正收官。补齐 backend-new 唯三还没建的工具适配器——memory / document / shell。三者皆 **filesystem.md 范式的叶子工具**（无 domain/store/handler/DDL/HTTP，只实现 `app/tool` 5 方法，软失败返串）。本轮最大教训：**不能照抄旧 backend**——逐个核对 backend-new 真实接口 + **回顾契约文档**，揪出一串「旧 ≠ 新」。

## 三个适配器

| 适配器 | 工具 | 装入 | 要点 |
|---|---|---|---|
| **memory** | read / write / forget_memory（3） | Lazy | 包 `memoryapp` Get/Upsert/Delete |
| **document** | search/list/read/create/edit/move/delete_document（7） | Lazy | 包 `documentapp` Search/ListByParent/Get/Create/Update/Move/Delete，端到端真 store 测 |
| **shell** | Bash / BashOutput / KillShell + ProcessManager（3） | Resident | 前台 120s/600s+256KB+footer · 后台 detached+bash_id · 增量 drain |

## 不能抄老的（本轮核心 —— 逐项核对 backend-new 真实接口）

- **memory**：旧 `write_memory` 带 `type` 四类（user/feedback/project/reference）→ **backend-new 砍 type**（`memory.md` §3 白纸黑字「Type 四分类全砍」）；write `source=ai` 内定、**不暴露 `pinned`**（用户专属）。
- **document**：旧 `documentapp.CreateInput` → backend-new **`CreateInput/UpdateInput/MoveInput` 挪进 `documentdomain`**（app 层 `type = ` alias）；`edit_document` 调 Service.**`Update`**（非 Edit）；构造器 `documentapp.New`（非 NewService）；`delete` **砍 `destructive` flag**（无门控意义）。
- **shell**：旧 `bash.go` 近一半是 **cwd 机制**（`parseCDOnly`/`handleCD`/`resolveCwd`/`SetCwd`）→ **全删**（R0033 cwd 全局废弃，`buildShellCmd` 不设 `cmd.Dir`）；**auto-route**（`maybeAutoRoute`+`bash_route.go`+`mvdan.cc/sh` 词法）→ **砍，留波次5**（per-conversation scratch env，不预留 sandbox 字段）；**新增 `danger.go` 硬拦截 6 条**（rm -rf //~、sudo、mkfs、dd of=/dev/、>块设备、fork bomb）替代已解散的 `permissionsgate`——**非 allow/deny 配置系统**，是无人值守兜底；砍 `Snapshots`（M7 dev 端点再加）、`ConvID`（auto-route 残留）。

## 文档纠正（「别光看代码，回顾文档」揪出）

- 🔴 **`shell.md` DOC-121 严重 stale** —— 停在 2026-05-03 旧 research（30s 超时 / `run_bash` / `allow-deny` permissions / **6 个 HTTP 错误码** `PERM_DENIED`·`SHELL_*` 连 error-codes.md 都没进的孤岛 / auto-route 当核心原理）。之后 R0032/R0033（cwd 废弃）、M1.9（permissions 解散）、M2.1（5 方法/danger）三轮决策全没更新它。**整篇重写**对标 filesystem.md（叶子工具 / 5 方法 / 无 cwd / 进程模型 / 危险硬拦截 / 无端点无错误码 / §10 决策快照逐条纠正）。
- 🟡 **`agentstate.go` 注释 doc-fix** —— 旧注释「cwd 由 shell 首个消费者加」（R0032 时代）失靶；shell 是那个消费者且确认不加 → 改注释「cwd 刻意不设（R0033）」。
- 🟡 **`database.md` S15** 登记 `bsh_` 前缀（后台 shell 进程 id，内存态不入库，性质同 `hdi_`）。
- ⚪ **`memory.md`/`document.md`** §5 补工具实现状态；**`api.md` `/dev/bash-processes`** 保留为 M7 dev 端点蓝图（Snapshots 一并 M7 加，shell.md §8 注明）。

> memory.md / document.md（domain 文档）核对结果是 ✅ 准且新（06-05/06-06 reviewed）；filesystem.md 是工具文档黄金范本（已替 shell 预告 cwd 废弃）。唯 shell.md 是陷阱——**光看代码会被这份 stale 文档带沟里**。

## 测试（全离线 · 0 token）

- **memory**：fake in-memory repo；write 无 type / source=ai / 不 pinned、read 渲染、forget 删 + NotFound 软失败、ValidateInput。
- **document**：**真 store**（in-memory SQLite + `documentstore.Schema` + ws ctx）端到端；create auto-suffix、read 往返、list root/child、search 命中/未命中、edit 部分字段 + no-op、move 正常/cycle/缺 parentId、delete 级联计数。
- **shell**：真子进程；`TestCheckDangerous` 把硬拦截当**纯函数**测（灾难命令绝不交给 shell）+ Bash 前台/非零 exit/超时/danger 分支（`sudo whoami` 兜底）/**无 cwd**（cd 不跨调用、单条 cd && 有效）+ 后台链（printf→drain→kill 幂等）+ BashOutput filter + ValidateInput。

## 留 M7（装配）

`MemoryTools(svc)` / `DocumentTools(svc)` 进 `Toolset.Lazy`；`NewShellTools()` 进 `Toolset.Resident` + `Manager.Stop()` 关停回收；`/dev/bash-processes` dev 端点 + `ProcessManager.Snapshots` 一并加。

## 用户参与设计

① **「别光看代码，回顾文档」** —— 直接逼出 shell.md DOC-121 是陷阱的关键判断（代码核对 + 文档回顾双轨，否则会照 stale 文档做出 30s/allow-deny/run_bash 的错）。② 三判定点拍板：auto-route 留波次5 · 危险硬拦截保守清单 · todo 工具不带（随 chat M5.2）。

## 验证

gofmt clean · `go build ./...` · `go vet ./...` · 三新包 test ALL PASS（纯新增、不破坏任何包）。

## 波次 3 收官

function ✅ · handler ✅ · trigger ✅ · skill ✅ · mcp ✅ · agent ✅ · **tool 适配器组 ✅（memory/document/shell 收官）**。**波次 3 Quadrinity 执行体 + 全部工具适配器完成**。下一站 **波次 4 编排核心**（workflow / flowrun / scheduler —— durable execution 引擎）。
