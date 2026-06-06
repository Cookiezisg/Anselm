---
# Round 0032 — tool/filesystem（波次 2 · M2.3 第 1 步）

类型 / 目标:M2.3 叶子工具第 1 个——`tool/filesystem`(Read/Write/Edit 三件套)适配器迁入,机械跟进新地基 + 首建 `pkg/agentstate`(只引入 SeenFiles 字段,渐进生长)+ 首建 reqctx WithAgentState/GetAgentState 种子。

## 核心方针(一句话)
**filesystem = LLM 的"读写手臂"三件套,本质复杂度全保留(写前必读铁律 / 原子写 / cat -n / 路径守卫);9→5 方法 + AllowWrite 分流 + agentstate 渐进首建。**

## 考古发现
- 旧实现 4 文件 ~620 行(filesystem.go 20/read.go 218/write.go 166/edit.go 216)+ 测试 ~1290 行;**0 重大设计 bug**,本质复杂度无脂肪。
- 灵魂 = **写前必读铁律**(任何 Write 覆写 / Edit 修改的目标,本次运行内必须先被 Read 过),靠 `agentstate.SeenFiles`(`sync.Map: path→size`)实现 + **fail-closed**(agentstate 缺失时 Write/Edit 直接拒绝)。
- 旧 9 方法里 4 个本就是死/解散的:`IsReadOnly`/`NeedsReadFirst`/`RequiresWorkspace`/`CheckPermissions`——M2.1 已砍,本轮机械跟进。
- 旧 `Allow` 单守卫 → R0003 新 pathguard **`Allow` + `AllowWrite` 两级**(写专属 extras 含 `.git/`/`.env*`/`node_modules/`)——本轮 Write/Edit 升级用 `AllowWrite`,把"AI 永不覆盖 .git/.env"从"无防护"升到"物理拦截"。

## 关键决策(用户拍板 + 渐进原则)
1. **agentstate 渐进首建**:本轮只引入 `SeenFiles` 字段(filesystem 当下唯一消费者),其他字段(cwd/activeSkill/activatedGroups)各自首个消费者(shell M3.7 / skill M3.5 / toolset M2.3 后续)按需追加。**反预留**:加一个字段 + 一对方法是 5 行事,没有"分两次改很痛"的成本。
2. **Read 用 `Allow`,Write/Edit 用 `AllowWrite`**:消费 R0003 已铺好的两级分流——把 `.git/`/`.env`/`node_modules/` 等"AI 可读不可写"路径从无防护升为物理拦截。
3. **接线种子先立**:`reqctx.WithAgentState/GetAgentState` 本轮就建(对称 R0029 `conversation_id`/`subagent_id` + R0031 `messageID` 的种子先行做法);执行宿主(chat M5.2 / subagent M3.3 / scheduler M4.3)在 loop.Run 前 seed,本轮只立契约。
4. **fail-closed 显式**:agentstate 缺失时 Write/Edit 返 `Cannot verify Read-first guard: agent state missing`——比静默放行更安全(要么 LLM 先 Read 要么 host 学会 seed)。Read 容忍缺失(只读 + 跳过盖章)。
5. **danger 不静态声明**:M2.1 纯信任。filesystem 三工具不预设静态下限,由 LLM 逐次自报。

## 新实现
- `pkg/agentstate/agentstate.go`:`AgentState{seenFiles sync.Map}` + `New`/`MarkRead`/`WasRead`;并发安全(同 execution_group 批并行跑)。
- `pkg/reqctx/agentstate.go`:`WithAgentState`/`GetAgentState`;nil seed 视为缺失,使 fail-closed 不变形同虚设。
- `app/tool/filesystem/filesystem.go`:`FilesystemTools(pathGuard)` 装配三件套。
- `app/tool/filesystem/read.go`:Read 工具(`Allow` + cat -n + bufio 8MB 单行 + 空/目录/不存在友好串 + 截断标记 + `MarkRead` 盖章)。
- `app/tool/filesystem/write.go`:Write 工具(`AllowWrite` + 父目录检查 + 覆写写前必读 + fail-closed + 原子 tmp+rename + mode 保留)。
- `app/tool/filesystem/edit.go`:Edit 工具(`AllowWrite` + 写前必读 + size 漂移检测 + 字面量替换 + `replace_all` 唯一性 + 原子写)。

## 测试(全离线 / t.TempDir / 自注入 agentstate)
30+:
- `pkg/agentstate` 5:New 空/MarkRead 往返/MarkRead 覆盖 size/WasRead 隔离/并发 MarkRead。
- `reqctx/agentstate_test` 3:Missing/RoundTrip/nil seed 当缺失。
- `read_test` 8:ValidateInput 5 例 + cat -n 行号 + offset+limit 窗口 + 截断标记 + 空文件 + 目录(Glob 提示)+ 不存在 + pathguard 拒 + 无 state 容忍跳过盖章。
- `write_test` 10:ValidateInput 4 例 + 新建文件 + 覆写需先 Read + Read 后覆写成功 + 无 state fail-closed + 父目录不存在 + 父是文件 + 目标是目录 + `AllowWrite` 拒 `.git/` + mode 0600 保留(防 CreateTemp 默认 0600 静默收紧)。
- `edit_test` 13:ValidateInput 8 例 + 单替换 + replace_all 多替换 + 多匹配无 replace_all 拒(文件不动)+ 0 匹配 + 写前必读拒 + 无 state fail-closed + size 漂移拒 + 文件不存在(Write 提示)+ 目录 + `AllowWrite` 拒 `.env` + mode 保留。

## 验证
`gofmt -l` 干净 · `go build ./...` 0 · `go vet` 0 · `go test -race ./internal/app/tool/filesystem/... ./internal/pkg/agentstate/... ./internal/pkg/reqctx/...` ok(filesystem 2.0s / agentstate 2.1s / reqctx 1.7s)· `go mod tidy` 无新增。

## 契约
- `docs/references/backend/domains/filesystem.md` **整篇重写**(DOC-108 复用)——旧文档腐烂(`settings.json/protectedPaths`/M1.9 砍、`IsReadOnly` flag/M2.1 砍、Atomic-Atomic 拼写错、`fs_edit/fs_write` 工具名错、`forgify.db` 禁区实际为 `~/.forgify/`、5 sentinel 与 wire code 全是虚构——工具失败不冒泡 HTTP)。新版按物理事实重写:5 方法接口 + 三字段注入 + 写前必读铁律 + Allow vs AllowWrite + 原子写 + size 漂移 + 边界(Glob/cwd 不在本包)+ 接线 + 测试矩阵 + 决策快照。
- `contract-changes.md` #12:filesystem.md 整篇重写(testend 若调死链工具名 `fs_*` 改 `Read/Write/Edit`)。
- 无新 HTTP 端点 / 无 DB 表 / 无 error code(工具失败永不冒泡 HTTP)。

## 跨波次接线
- **agentstate cwd 字段**(`Bash` 工具追踪 `cd <path>`)→ shell M3.7,按需在 agentstate 追加。
- **agentstate activeSkill 字段**(skill 预授权域)→ skill M3.5。
- **agentstate activatedGroups 字段**(toolset lazy 激活账本)→ toolset(M2.3 后续/chat M5.2 通过 AutoActivator 钩子消费)。
- **`WithAgentState` 调用方** → chat M5.2(主对话每对话起一个 AgentState 挂 ctx)+ subagent M3.3(继承?或独立?波次 3 定)+ scheduler M4.3(workflow 内运行 agent 时)。
- **三工具装入 `Toolset.Resident`** → chat M5.2 host 组装(filesystem 是常驻工具典型例)。
- **PathGuard 实例** → server boot M7 用 `pathguardpkg.NewDefault()` 拿默认 deny + write extras。

## 波次 2 进度
M2.1 tool ✅ → M2.2 loop ✅ → **M2.3 第 1 步 filesystem ✅** → M2.3 search(下一)/web/toolset。
