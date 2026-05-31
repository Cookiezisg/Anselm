---
id: DOC-122
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-05-31
review-due: 2026-06-30
audience: [human, ai]
---
# Skill — V1.2 详设计

**Phase**：Phase 4 准备件（提前到位）
**状态**：✅ D7 全部交付（2026-05-06）：domain types + 5 sentinels + agentstate ActiveSkill 旁路 + Service{Scan/Get/List/Search/Activate/Body/Create/Replace/Delete/Import} + 1s 轮询 + fingerprint 短路（替换原 fsnotify watcher，2026-05-07）+ 2 system tools (search_skills/activate_skill) + framework permission integration（active skill 的 allowed-tools 在 loop dispatch 短路 CheckPermissions）+ 9 HTTP endpoints + 3 离线 pipeline 场景
**关联**：
- [`../backend-design.md`](../backend-design.md) — 总规范
- [`../service-contract-documents/database-design.md`](../service-contract-documents/database-design.md) — 无新表（文件系统是 source）
- [`../service-contract-documents/error-codes.md`](../service-contract-documents/error-codes.md) — skill ×5（已接 errmap）
- [`../service-contract-documents/events-design.md`](../service-contract-documents/events-design.md) — `skill` entity-state 事件 ✅
- 关联设计：[`subagent.md`](./subagent.md)（`context: fork` 复用 SubagentService）/ [`catalog.md`](./catalog.md)
- 外部 spec：[Anthropic Agent Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview) / [agentskills.io](https://agentskills.io)

---

## 1. 一句话

把"按需加载、可命名、有 tool 白名单"的 procedural knowledge bundle 抽象为 **`SKILL.md` 文件目录**。LLM 看到 catalog 里的 skill 描述（L1，~100 token）→ 调 `activate_skill` 加载完整指引（L2，<5k token）→ 跟着指引用现有 tool 取 L3 资源。**整套机制零新协议**——L2/L3 加载复用 LLM 已有的 Read/Bash tool。

---

## 2. 端到端推演（progressive disclosure 三层）

### L1 — 启动期（metadata 注入）

```
main.go → skillapp.NewService(deps).Scan()
  → 扫描 ~/.forgify/skills/*（**仅用户级，无项目级**）
  → 对每个 SKILL.md：
      - 用 yaml.v3 解析 YAML frontmatter
      - 不读 markdown body
      - 缓存 Skill{Name, Description, Frontmatter, BodyPath}
  → 启 1s 轮询 goroutine（每秒重 Scan + fingerprint 短路；变化时触发 SSE）
  → 暴露给 catalog（实现 CatalogSource 接口）
  
catalog generator 拼 system prompt 时拿这些 description，生成 1-2 行总结
注：description 直接来自 frontmatter（author 写），不重 LLM 生成
```

### L2 — LLM 调 activate_skill 时（body 加载）

```
LLM → tool_use{name="activate_skill", args={name:"pr-review", arguments:["1234"]}}
  → skilltool.ActivateSkill.Execute(ctx, args)
    → skillapp.Service.Activate(ctx, name, arguments)
        → 取 Skill 元数据
        → os.ReadFile(BodyPath)   # 不通过 LLM 的 Read tool（系统内部加载）
        → 字符串替换：$1, $ARGUMENTS, ${CLAUDE_SKILL_DIR}, ${CLAUDE_SESSION_ID}
        → 写 agentstate.SetActiveSkill(skill)
            → 后续 tool 的 CheckPermissions 看到 active skill → match allowed-tools 跳过 prompt
        → 如 frontmatter.Context == "fork":
            → 调 subagentapp.Spawn(type=frontmatter.Agent, prompt=substitutedBody)
            → 返回 subagent.lastMessage（隔离模式）
          否则:
            → 返回 substitutedBody 作为 tool_result
              （LLM 在下一 turn 看到这段 instructions，照着干）
  → tool_result 给 LLM
```

### L3 — LLM 跟随 L2 指引时（资源按需）

```
LLM 看 L2 body 写"跑 ${CLAUDE_SKILL_DIR}/scripts/analyze_diff.py $file"
  → LLM 自己用 Bash tool 跑那个脚本
    → permission check 看 active skill = pr-review，allowed-tools 含 Bash → 跳过 prompt
  → 脚本输出回 LLM
  → LLM 看 L2 写"用 ${CLAUDE_SKILL_DIR}/templates/review_template.md 套结果"
  → LLM 自己用 Read tool 读模板
  → ...
```

**L3 不是 Skill 系统加载的**——纯靠 LLM 用现有 tool 自取。Skill 子系统只管 L1 注入 + L2 加载 + permission 预授权。

---

## 3. 设计原则

| 原则 | 落地 |
|---|---|
| **Progressive disclosure** | metadata 永远在；body 按需 Read；resources LLM 自取 |
| **Composition with Subagent** | `context: fork` 字段调 SubagentService.Spawn，**不是 Subagent 子集而是组合关系** |
| **Allowed-tools 预授权** | 写 agentstate.ActiveSkill，后续 permission 链查询时跳过 prompt |
| **跨厂 schema 兼容（不共享目录）** | YAML frontmatter 照抄 Anthropic spec，用户可拖拽 / git clone / 手拷其他工具的 skill 进 `~/.forgify/skills/`，但 Forgify **不扫描** Claude Code / Cursor / Cline 等外部目录（自包含原则）|
| **不做 LLM 重写 description** | description 是 author 责任（YAML frontmatter source-of-truth），catalog 直接用 |
| **1s 轮询 + fingerprint 短路** | 用户改 SKILL.md 不必重启；与 catalog 同模子（catalog/polling.go），无 fsnotify 复杂度 |
| **仅用户级，无项目级** | 只 `~/.forgify/skills/` 一份，**无 `<project>/.forgify/skills/`**——避免 merge 逻辑复杂度，单用户场景用户级足够 |

---

## 4. 领域模型

### Skill（`internal/domain/skill/skill.go`）

```go
type Skill struct {
    Name        string       `json:"name"`
    Source      string       `json:"source"`        // "user" / "plugin"（v1 仅 user，未来 plugin 系统加 plugin）
    DirPath     string       `json:"dirPath"`       // 用于解析 ${CLAUDE_SKILL_DIR}
    BodyPath    string       `json:"bodyPath"`      // SKILL.md 全路径
    Description string       `json:"description"`   // 直接来自 frontmatter
    Frontmatter Frontmatter  `json:"frontmatter"`
    LoadedAt    time.Time    `json:"loadedAt"`
}
```

### Frontmatter

```go
type Frontmatter struct {
    Name                   string   `yaml:"name"`
    Description            string   `yaml:"description"`
    WhenToUse              string   `yaml:"when_to_use,omitempty"`
    AllowedTools           []string `yaml:"allowed-tools,omitempty"`     // 预授权
    DisableModelInvocation bool     `yaml:"disable-model-invocation,omitempty"`
    UserInvocable          bool     `yaml:"user-invocable,omitempty"`     // 默认 true
    Paths                  []string `yaml:"paths,omitempty"`              // glob，用于 auto-trigger（v1 暂不实现）
    Context                string   `yaml:"context,omitempty"`            // "fork" or empty
    Agent                  string   `yaml:"agent,omitempty"`              // 当 context=fork 时用哪个 subagent type
    Arguments              []string `yaml:"arguments,omitempty"`          // 命名参数
    ArgumentHint           string   `yaml:"argument-hint,omitempty"`
    Model                  string   `yaml:"model,omitempty"`              // override
    Effort                 string   `yaml:"effort,omitempty"`             // low/medium/high/...（v1 透传不消费）
}
```

**字段策略**：
- 全字段照 Anthropic SKILL.md spec，cross-vendor 兼容
- v1 真消费的字段：`name`、`description`、`allowed-tools`、`disable-model-invocation`、`context`、`agent`、`arguments`
- v1 解析但不消费：`paths`（auto-trigger）、`effort`、`when_to_use`、`model`——保留以便后续接入不破坏 schema

### Sentinel 错误（5 个）

```go
var (
    ErrSkillNotFound       = errors.New("skill: not found")
    ErrInvalidFrontmatter  = errors.New("skill: invalid frontmatter")
    ErrBodyTooLarge        = errors.New("skill: body exceeds size limit")
    ErrNameConflict        = errors.New("skill: name already exists")     // Create / Import 同名时
    ErrInvalidName         = errors.New("skill: invalid name format")     // 不合 [a-z0-9-] / 太长
)
```

`ErrNameConflict` / `ErrInvalidName` 是 D7 加的——`POST /skills` Create + `:import` 路径需要明确"撞名"和"非法名"两类失败语义，不能糊到 `ErrInvalidFrontmatter`。

### 体积常量（domain pkg 暴露）

```go
const (
    MaxBodyBytes        = 32 * 1024  // SKILL.md body 上限（超返 ErrBodyTooLarge）
    MaxDescriptionChars = 1536       // frontmatter description 字符上限（per Anthropic spec）
)
```

---

## 5. 文件系统 Layout（自包含）

**Forgify 只扫描 `~/.forgify/skills/` 一处**，**不**读 Claude Code / Cursor / VS Code 等外部目录，**也无项目级**：

```
~/.forgify/skills/                          ← 唯一 skill 位置
├── pr-review/
│   ├── SKILL.md                           # 必有
│   ├── scripts/
│   │   ├── analyze_diff.py                # L3 资源
│   │   └── check_security.sh
│   └── templates/
│       ├── review_template.md
│       └── good_examples/
│           ├── go_pr.md
│           └── react_pr.md
└── csv-clean/
    └── SKILL.md                           # 单文件 skill 也合法
```

**为什么没项目级**：
- 单用户本地 app，所有 skill 用户级足够
- 项目级会引入 merge / override / 优先级语义，复杂度大于收益
- 用户想"项目专属 skill" → 命名约定（如 `myproj-deploy`）一样工作

### 用户怎么把别处的 skill 装进来

全是**显式动作**（不是后台映射），全部落到 `~/.forgify/skills/`：

| 方式 | 操作 |
|---|---|
| **拖拽**（推荐）| UI 拖拽 zone 接收文件夹 / .zip / .tar.gz / 单个 SKILL.md → 后端 `POST /api/v1/skills:import` 解压 + 校验 + 拷进 `~/.forgify/skills/<name>/` → 下次 1s 轮询 tick 自动 pick up（或 import handler 同步 Scan 立即生效）|
| **`git clone`** | `cd ~/.forgify/skills && git clone https://github.com/foo/skill-x.git` |
| **手拷目录** | `cp -r ~/Downloads/pr-review ~/.forgify/skills/` |
| **HTTP API 创建** | UI 表单 → `POST /api/v1/skills` 后端写 SKILL.md 到 `~/.forgify/skills/<name>/` |

**Forgify 完全拥有副本**：用户改了原始来源（如 anthropics/skills 仓库更新）不影响 Forgify 已装版本，需要重装就再拖一次。

**SKILL.md 格式**（示例）：

```yaml
---
name: pr-review
description: |
  Review a GitHub PR for code quality, tests, and security.
  Use when the user asks to "review PR" or "check this pull request".
allowed-tools: Read Grep Bash(gh pr view *) Bash(gh pr diff *)
arguments: [pr_number]
context: fork
agent: Explore
---

# Reviewing PR #$1

1. Fetch PR: `gh pr view $1 --json title,body,files`
2. For each .py changed file: `python3 ${CLAUDE_SKILL_DIR}/scripts/analyze_diff.py $file`
3. Apply template at `${CLAUDE_SKILL_DIR}/templates/review_template.md`
4. Output structured review.
```

### 体积保护

- 单 SKILL.md 限制：32 KB（超返 `ErrBodyTooLarge`）
- 单 frontmatter 限制：YAML parse 后 description 字段 ≤ 1536 char（per spec）
- 总 skill 数量：v1 不限（catalog 层会处理）

---

## 6. 1s 轮询（`internal/app/skill/polling.go`）

```go
const pollInterval = 1 * time.Second

func (s *Service) Start(ctx context.Context) error  // 同步 Scan 一次 + 启 goroutine
func (s *Service) Stop()                            // 取消 ctx + 阻塞等 goroutine 退
```

**策略**：
- main.go 调 `Service.Start(ctx)`：同步跑一次 Scan（让 caller 返回前 cache 已 hot）+ 启 goroutine
- goroutine 每 `pollInterval = 1s` 调一次 `Service.Scan(ctx)`
- `Scan` 内部按排序后的 `(name + frontmatter YAML)` 算 sha256 fingerprint，与 `lastFP` 比，**相同则跳过 publishSnapshot**——防止每秒发一次冗余 SSE
- 体积假设：本地用户级 skill 数量 ≤ ~50，每次 Scan 仅是几个 SKILL.md 的 read + YAML parse（~ms 级），CPU 几乎无开销
- Stop 由 t.Cleanup 在测试中调；生产 main.go 不显式 Stop（goroutine 持 background ctx，进程退出时由 OS 回收，与 catalog/mcp 同模式）

**为什么不 fsnotify**：原 fsnotify 实现需要递归监听子目录、symlink 循环防护、Linux fd 上限 fail-soft、debounce、5min 兜底——271 行 + 1 个三方依赖 + 4 类边界条件，只为"用户改 SKILL.md 后重 Scan"。catalog 已用 1s 轮询 fingerprint 解决同类问题（且 catalog 把 skill 注册成 source 也在每秒轮询它），平行造轮代价高于收益。2026-05-07 替换。

---

## 7. Service 层（`internal/app/skill/skill.go`）

```go
type Service struct {
    skills    map[string]*skilldomain.Skill   // name → skill
    skillsDir string                          // ~/.forgify/skills/
    notif     notificationspkg.Publisher      // fingerprint 变化 publish "skill" 通知
    log       *zap.Logger
    subagent  SubagentService                 // 接口注入，用于 context: fork
    llm       llmclientpkg.Resolver           // 用于 search ranking
    lastFP    atomic.Value                    // string — 上次 Scan 后 fingerprint，用于短路无变化 publish
    mu        sync.RWMutex
    stopOnce  sync.Once
    pollDone  chan struct{}
}

type SubagentService interface {
    Spawn(ctx context.Context, typeName, prompt string, opts subagentapp.SpawnOpts) (*subagentapp.SpawnResult, error)
}

func (s *Service) Start(ctx context.Context) error                    // 同步 Scan + 启 polling goroutine
func (s *Service) Stop()                                               // 幂等 stopOnce + 阻塞 pollDone
func (s *Service) Scan(ctx context.Context) error
func (s *Service) Get(ctx context.Context, name string) (*Skill, error)
func (s *Service) List(ctx context.Context) []*Skill
func (s *Service) Search(ctx context.Context, query string, topK int) ([]*Skill, error)
func (s *Service) Activate(ctx context.Context, name string, arguments []string) (string, error)
func (s *Service) Body(ctx context.Context, name string) ([]byte, error)                  // GET /skills/{name}/body
func (s *Service) Create(ctx context.Context, name string, fm Frontmatter, body string) (*Skill, error)  // POST /skills
func (s *Service) Replace(ctx context.Context, name string, fm Frontmatter, body string) (*Skill, error) // PUT /skills/{name}
func (s *Service) Delete(ctx context.Context, name string) error                          // DELETE /skills/{name}
func (s *Service) Import(ctx context.Context, payload Payload, overwrite bool) (*ImportResult, error)    // POST :import
func (s *Service) SkillsDir() string                                  // 给 ${CLAUDE_SKILL_DIR} / Bash cwd 拼路径
```

**通知通道**：经 `notificationspkg.Publisher` 推 `skill` 通知（详 §10），Service 自身不订阅事件流。

**`lastFP` 短路**：1s 轮询每次 Scan 后算 `sha256(sort by name + frontmatter YAML)` fingerprint；与 `lastFP.Load()` 一致则跳过 publish——避免每秒一发冗余通知。

### Activate 详细实现

```go
func (s *Service) Activate(ctx context.Context, name string, arguments []string) (string, error) {
    skill := s.skills[name]
    if skill == nil { return "", ErrSkillNotFound }

    // 1. 读 body（容忍编辑器 .tmp+rename 模式的瞬态 ENOENT，retry 1 次 100ms 后）
    body, err := readBodyWithRetry(skill.BodyPath)
    if err != nil { return "", fmt.Errorf("skillapp.Activate: read body: %w", err) }
    if len(body) > skilldomain.MaxBodyBytes { return "", ErrBodyTooLarge }

    // 2. 字符串替换（含 $1..$N / $ARGUMENTS / 命名 $<name> / ${CLAUDE_SKILL_DIR} / ${CLAUDE_SESSION_ID} / ${CLAUDE_EFFORT}）
    substituted := substituteVars(string(body), arguments, skill)

    // 3. 设 active skill（agentstate） — 非 fork 路径"不"清除（让后续 tool 持续受预授权）
    //    fork 路径不写 active skill（subagent 隔离原则；详 §15 fork 路径详解）
    if skill.Frontmatter.Context != "fork" {
        if state := reqctxpkg.GetAgentState(ctx); state != nil {
            state.SetActiveSkill(skill)
            // 注意：**不**用 defer ClearActiveSkillIfMatches——
            // 非 fork 模式下，Activate 返回后续 tool（Bash/Read 等）才需要看 ActiveSkill 走预授权；
            // ActiveSkill 在主 LLM 显式 activate 另一个 skill 时被替换，或对话结束时由 agentstate 销毁清空。
        }
    }

    // 4. fork 模式 vs 直返
    if skill.Frontmatter.Context == "fork" {
        agentType := skill.Frontmatter.Agent
        if agentType == "" { agentType = "general-purpose" }
        // 嵌套 fork 抑制：subagent depth >= 1 时 inline 注入 body 当 tool_result（详 §9.5）
        if reqctxpkg.GetSubagentDepth(ctx) >= 1 {
            s.log.Info("skill activated within subagent; ignoring fork directive",
                zap.String("skill", skill.Name))
            return substituted, nil
        }
        result, err := s.subagent.Spawn(ctx, agentType, substituted, subagentapp.SpawnOpts{})
        if err != nil { return "", err }
        return result.Result, nil
    }

    // 非 fork：返 body 作 tool_result，LLM 看到照着干
    return substituted, nil
}
```

### 字符串替换支持的占位符

| 占位符 | 替换为 |
|---|---|
| `$1`, `$2`, ... `$N` | 第 N 个 argument |
| `$ARGUMENTS` | 全部 arguments 用空格连接 |
| `$<name>` | 命名参数（按 frontmatter.arguments 数组对应）|
| `${CLAUDE_SKILL_DIR}` | skill 目录绝对路径 |
| `${CLAUDE_SESSION_ID}` | conversation ID |
| `${CLAUDE_EFFORT}` | frontmatter.effort（v1 占位符存在但默认空）|

**v1 不支持**：` !`shell` ` 反引号 / fenced ` ```! ` 块（spec 有但实现复杂；后续加）。

---

## 8. 2 个 System Tool

### 8.1 `search_skills`（`internal/app/tool/skill/search.go`）

```go
func (t *SearchSkills) Description() string {
    return "Search across all installed skills (procedural workflows) for ones matching a task. " +
           "Returns top 3 candidate skills with their descriptions. " +
           "Use when you need to follow a multi-step procedure that someone has already encoded."
}
```

**Execute**：调 `svc.Search(query, 3)` → 返 JSON 列表（含 name + description + 是否 fork）。

### 8.2 `activate_skill`（`internal/app/tool/skill/activate.go`）

```go
func (t *ActivateSkill) Description() string {
    return "Load a skill's full instructions and start following them. " +
           "After activation, the skill's allowed tools are pre-approved (no permission prompts). " +
           "If the skill is configured to fork, runs in an isolated subagent context."
}

func (t *ActivateSkill) Parameters() json.RawMessage {
    return json.RawMessage(`{
      "type":"object",
      "properties":{
        "name":{"type":"string","description":"Skill name"},
        "arguments":{"type":"array","items":{"type":"string"},"description":"Positional arguments to substitute into $1, $2, etc."}
      },
      "required":["name"]
    }`)
}
```

**Execute**：调 `svc.Activate(name, arguments)` → 返 substituted body 字符串（或 fork 模式下的 subagent last message）。

---

## 9. Active Skill 在 agentstate 的处理

### `pkg/agentstate/skill.go`

```go
type AgentState struct {
    // 已有：SeenFiles / Cwd / SubagentTokenLog
    activeSkill atomic.Pointer[skilldomain.Skill]   // last-write-wins，无锁
}

func (s *AgentState) SetActiveSkill(skill *skilldomain.Skill) { s.activeSkill.Store(skill) }
func (s *AgentState) ActiveSkill() *skilldomain.Skill         { return s.activeSkill.Load() }
func (s *AgentState) ClearActiveSkillIfMatches(name string) {
    if cur := s.activeSkill.Load(); cur != nil && cur.Name == name {
        s.activeSkill.CompareAndSwap(cur, nil)
    }
}

func (s *AgentState) IsToolPreApprovedBySkill(toolName string) bool {
    skill := s.ActiveSkill()
    if skill == nil { return false }
    return matchAllowedTool(skill.Frontmatter.AllowedTools, toolName)
}
```

**为什么不用 sync.RWMutex / 不用栈**：单用户 LLM 串行调 tool（execution_group 内并行也最多 1-2 个 activate_skill 并发），原子指针足够。栈结构 / 锁结构是过度防御。

### Tool permission 链改造

各 Tool 的 `CheckPermissions` 第一步增加：

```go
func (t *Bash) CheckPermissions(args json.RawMessage, mode toolapp.PermissionMode) toolapp.PermissionResult {
    if state := agentstatepkg.FromCtxLazy(); state != nil {
        if state.IsToolPreApprovedBySkill("Bash") {
            return toolapp.PermissionAllow
        }
    }
    // 原有 logic...
}
```

或者集中在 framework 层做（更优）：在 `app/tool/tool.go` 的 dispatch 入口统一查询，**不必每个 tool 改**。

### `matchAllowedTool` pattern 解析

照 SKILL.md spec：

```
"Read"             → 完全匹配 Read tool
"Bash"             → 完全匹配 Bash tool（任意参数）
"Bash(git *)"      → 仅当 args 解析后命令以 "git " 开头才放行
"Bash(npm test)"   → 仅当 args 解析后命令完全是 "npm test" 才放行
```

v1 实现 wildcards `*`；进阶 regex 等以后加。

### 清除时机

- 非 fork 模式：activate_skill 的 `Execute` 返回时**不**清除（让后续 tool 继续受预授权）
- 主 LLM 显式调"另一个 activate_skill" → 替换 ActiveSkill
- 主 LLM 调 Task 进 subagent → subagent 不继承 ActiveSkill（隔离原则）
- 对话结束 / agentstate 销毁时清除

---

## 9.5. 失败 / 边界 / 并发控制

### `context: fork` 在已 fork 的 subagent 里再 fork（防深度传染）

**问题**：主 LLM activate skill A（fork → subagent）→ subagent 的 LLM 又 activate skill B 也 fork → 违反 subagent depth=1 原则。

**设计**：`Service.Activate` 检测当前 ctx 是否已在 subagent 里（`reqctxpkg.GetSubagentDepth(ctx) >= 1`）：
- 若是 → **强制忽略 frontmatter.Context = "fork"**，inline 注入 body 当 tool_result
- log Info "skill activated within subagent; ignoring fork directive"
- subagent 本身就是隔离 context，再 fork 是冗余浪费

### Symlink 循环防护

**已废弃（2026-05-07）**：原 fsnotify 实现需要递归 add watch 子目录，所以才需要 EvalSymlinks + visited set 防 `~/.forgify/skills/foo → ~/.forgify/skills/` 软链死循环。1s 轮询版只 `os.ReadDir(skillsDir)` 一层（不递归 subdir），软链循环不会触发——OS 层 `os.ReadDir` 自身不跟踪软链递归。

### 同 skill 并发 activate 竞态

**问题**：LLM 同 turn 同 execution_group 调 activate_skill 两次（不同 args）→ ActiveSkill state 可能撕裂。

**设计**：`agentstate.activeSkill` 用 `atomic.Pointer[Skill]`，**last-write-wins**：
- 每次 activate 直接 `Store` 覆盖前一个
- permission 检查 `Load` 当前指针，按其 allowed-tools 决定

理由：单用户场景下并发 activate 几乎不可能（LLM 一次只想做一件事），加栈结构是过度防御。即使真撞上 race，行为是"后到的 skill 决定 permission"——不崩、不死锁，最差也只是"另一个 skill 的 tool 被 ask 了一下"。**简单胜过周全**。

### `allowed-tools` 引用不存在的 tool

**问题**：SKILL.md 写 `allowed-tools: NonExistentTool` → permission 链查询永远 match fail，看似"允许"实际上没生效（false positive）。

**设计**：Service.Scan 时校验所有 allowed-tools 名在当前 framework tool registry 里：
- 不存在 → 把该 skill 标记为 `frontmatter.invalid` + 不进 catalog
- 加到 SSE 事件让前端能显示警告
- 用户修了 SKILL.md → 下次 1s 轮询 tick rescan → 通过

### Body 加载与文件改动竞态

**问题**：用户编辑 SKILL.md 同时 LLM 在 activate → 读到一半的文件。

**设计**：os.ReadFile 是原子 syscall（OS 层面），但用户编辑器可能用"先写 .tmp 再 rename"模式导致瞬时不存在。activate 时 `os.ReadFile` 失败 → 重试 1 次（100ms 后）→ 仍失败返 ErrSkillNotFound。下次 1s 轮询 tick 重 Scan 后 cache 含新 BodyPath，再次 activate 拿新版。

---

## 10. Notifications

V3 改用 `notificationspkg.Publisher` 推 `skill` 通知，**不发全 skill 快照**（前端可调 `GET /skills` 拿最新列表，避免快照刷屏）。

```json
{
  "type": "skill",
  "id":   "*",                 // skill 是用户级全局，没有 per-entity ID
  "data": {
    "changed": true,
    "count":   12              // 当前 skill 数量
  }
}
```

**触发点**：`Service.Scan` 后**且 fingerprint 变化**（1s 轮询 tick / Create / Replace / Delete / Import 内的同步 Scan / 手动 `:refresh`）。

**短路**：`fingerprint == lastFP` 时**不**publish——避免每秒一发冗余通知；只有用户改了 SKILL.md 才通知前端。

**Wire path**：`/api/v1/notifications` 全局通道 + 客户端按 `type=skill` 过滤。详 [`../service-contract-documents/events-design.md`](../service-contract-documents/events-design.md) notifications 协议章。

---

## 11. HTTP API

| Method + Path | 用途 | 响应 |
|---|---|---|
| `GET /api/v1/skills` | 列所有 skills（含 frontmatter，**不**含 body）| `{data: [Skill...]}` |
| `GET /api/v1/skills/{name}` | 单 skill 详情 | `{data: Skill}` |
| `GET /api/v1/skills/{name}/body` | 拿 skill 的 SKILL.md body 内容（编辑用）| `{data: {body: "..."}}` |
| `POST /api/v1/skills` | 创建新 skill（写 SKILL.md 到 user 目录）| `{data: Skill}` (201) |
| `PUT /api/v1/skills/{name}` | 整体替换 skill 内容（frontmatter + body）| `{data: Skill}` (200) |
| `DELETE /api/v1/skills/{name}` | 删除 skill 目录 | 204 |
| `POST /api/v1/skills:import` | **拖拽导入**（multipart：folder / zip / tar / single SKILL.md）| `{data: {imported: [...], conflicts: [...]}}` |
| `POST /api/v1/skills:refresh` | 手动 Rescan（debug 用，绕过等下一 tick）| `{data: [Skill...]}` |
| `POST /api/v1/skills/{name}:invoke` | 手动调用（slash command 路径用）| `{data: {result: "..."}}` |

### POST /api/v1/skills 创建端点

**Body**：
```json
{
  "name": "my-skill",
  "frontmatter": { "description": "...", "allowedTools": [...], ... },
  "body": "# Markdown body content..."
}
```

**行为**：
- 校验 name 合法（`[a-z0-9-]`，max 64 char）+ 不与现有冲突
- 校验 frontmatter（description 非空、allowedTools 字符串数组等）
- 创建 `~/.forgify/skills/<name>/SKILL.md`
- 写 YAML frontmatter + markdown body
- 1s 轮询触发 Rescan + SSE（fingerprint 变化时）
- 返新 Skill struct (201)

冲突 → 409 + `{error:{code:"SKILL_NAME_CONFLICT"}}`，前端可让用户改名或选择 PUT 覆盖。

### POST /api/v1/skills:import 拖拽端点

接收：
1. **multipart `folder`**：浏览器 webkitdirectory 选目录 → 多文件上传
2. **multipart `archive`**：单个 .zip / .tar.gz
3. **multipart `file`**：单个 SKILL.md（自动包一层目录）

行为：
- 解析 + 找出所有 SKILL.md
- 每个校验 frontmatter
- 不存在 → 拷进 `~/.forgify/skills/<name>/`
- 已存在 → 加 `conflicts` 列表，前端弹确认；query `?overwrite=true` 强制覆盖

响应：
```json
{ "data": {
  "imported": ["pr-review", "deploy-helper"],
  "conflicts": ["csv-clean"],
  "errors": [{"name":"bad-skill","reason":"missing description"}]
}}
```

### `:invoke` 与其他端点的关系

Slash command 是 UI sugar——用户在前端输入 `/pr-review 1234`：
- 前端调 `POST /api/v1/skills/pr-review:invoke?args=1234`
- 后端转发到 `Service.Activate` 走 chat 注入

LLM 自主调用走 `activate_skill` system tool，**不**经过这个 endpoint。

---

## 12. 错误码

| Sentinel | HTTP | Wire Code |
|---|---|---|
| `skilldomain.ErrSkillNotFound` | 404 | `SKILL_NOT_FOUND` |
| `skilldomain.ErrInvalidFrontmatter` | 422 | `SKILL_INVALID_FRONTMATTER` |
| `skilldomain.ErrBodyTooLarge` | 422 | `SKILL_BODY_TOO_LARGE` |
| `skilldomain.ErrNameConflict` | 409 | `SKILL_NAME_CONFLICT` |
| `skilldomain.ErrInvalidName` | 422 | `SKILL_INVALID_NAME` |

---

## 13. CatalogSource 实现

```go
// internal/app/skill/catalogsource.go
type catalogSource struct{ svc *Service }

func (c *catalogSource) Name() string                             { return "skill" }
func (c *catalogSource) Granularity() catalogdomain.Granularity   { return catalogdomain.PerItem }

func (c *catalogSource) ListItems(ctx context.Context) ([]catalogdomain.Item, error) {
    items := []catalogdomain.Item{}
    for _, sk := range c.svc.List(ctx) {
        items = append(items, catalogdomain.Item{
            Source:      "skill",
            ID:          sk.Name,
            Name:        sk.Name,
            Description: sk.Description,  // 直接抄 frontmatter；不重 LLM 生成
            Category:    "",  // 无；catalog generator 自己判断要不要合并
        })
    }
    return items, nil
}

func (s *Service) AsCatalogSource() catalogdomain.CatalogSource {
    return &catalogSource{svc: s}
}
```

**Granularity = PerItem** 但通常 catalog generator 不合并 skill——每个 skill 是 distinct workflow，合并会丢语义。

---

## 14. 测试覆盖 ✅

| 层 | 文件 | 测试数 | 覆盖 |
|---|---|---|---|
| domain | `internal/domain/skill/skill_test.go` | 6 | Frontmatter YAML 全 spec round-trip + 最小必填 / Skill JSON camelCase + sentinel 唯一性 / 'skill: ' 前缀审计 / 常量校验 |
| pkg/agentstate | `internal/pkg/agentstate/skill_test.go` | 10 | NilWhenUnset / Set/Get/Clear / LastWriteWins (并发) / IsToolPreApprovedBySkill (BareName/BashAnyArgs/Wildcard table/Malformed pattern fail-closed/paren-non-Bash 退化/bad-args JSON 不 panic) / wildcardMatch edge cases |
| app/skill | `internal/app/skill/{skill,polling}_test.go` | 24 | Scan empty/missing dir/valid skill/bad frontmatter (3 子)/超大 body/同名重复/splitFrontmatter 6 模式/substitute 全占位+\$10-not-pre-empted/Activate non-fork & fork & nested-fork-suppression & fork-without-svc-fails-clean & missing→ErrSkillNotFound / Search ≤topK 短路 + empty / Polling DetectsNew/DetectsEdit/DetectsDelete + Scan FingerprintShortCircuit |
| app/tool/skill | `internal/app/tool/skill/skill_test.go` | 12 | factory 返 2 tool / SearchSkills 9 方法（Identity/static/Validate 5 子/CheckPermissions 全模式/Execute empty + JSON list）/ ActivateSkill 9 方法（Identity/static IsReadOnly=false/Validate 5 子/Execute friendly-missing/Execute returns body）|
| transport/handlers | `internal/transport/httpapi/handlers/skills_test.go` | 20 | List empty + after seed / Get 404 / GetBody / Create 201 + Conflict 409 + InvalidName 422 / Replace 200 + 404 / Delete 204 + 404 / Refresh 拾起 disk 写 / Import JSON 2 files + Conflict-no-overwrite + Overwrite force + Multipart + Empty rejected / Invoke non-fork returns body + 404 / NameAction unknown 400 |
| framework integration | `internal/app/loop/tools_test.go` | 3 | NoActiveSkill 仍走 CheckPermissions / ActiveSkill 预授权绕过 (permChecks=0 计数) / NoMatch 退回 CheckPermissions |
| pipeline | `test/skill/skill_test.go` | 3 | Activate inline E2E ($1 substitution + body 进 tool_result) / Search-then-Activate E2E (双 tool_call 配对 + result) / PreApproval Bash after Activate (D7-6 端到端验证 + 'tool pre-approved by active skill' log) |

总计 80 单测 + 3 pipeline 场景全绿。

---

## 15. 与其他 domain 的关系

| 关系 | 说明 |
|---|---|
| **chat** | 主 LLM 通过 search_skills / activate_skill 调用；ActiveSkill 影响 tool permission 链 |
| **subagent** | `context: fork` 时调 SubagentService.Spawn；接口注入避免循环 import |
| **catalog** | 实现 CatalogSource；description 直接抄不重生 |
| **agentstate** | 写 ActiveSkill 字段，permission 链查询 |
| **notifications** | 经 `notificationspkg.Publisher` 推 `skill` 通知（type=skill, id=`*`, data={changed,count}）；不再走 events bridge |
| **logger** | Scan I/O 失败、frontmatter parse 错误等走 Warn |

### 与 Subagent 的协作（fork 路径详解）

```
LLM 调 activate_skill("pr-review", ["1234"])
  → Skill.Service.Activate
    → 替换 body
    → frontmatter.Context == "fork", frontmatter.Agent == "Explore"
    → 调 SubagentService.Spawn(type="Explore", prompt=substitutedBody, opts={})
        → 走 subagent 完整流程：
          - 独立 messages（system prompt = Explore 的 + 不带 ActiveSkill）
          - 过滤 tool registry（按 Explore 的 AllowedTools；**不**继承 Skill 的 allowed-tools）
          - subRunner 跑直到 stop
        → 返 last message
    → 把 last message 返给主 LLM
```

**关键**：subagent 不继承 Skill 的 allowed-tools——subagent 隔离原则**优先于** Skill 的 permission 预授权。如果你希望 fork 后的 subagent 也享受预授权，**应该在 Subagent 类型定义里把 allowed-tools 设好**，而不是寄希望于继承。

---

## 16. 演化方向

- **`paths`-triggered auto-load**：用户编辑文件 match `paths` glob 时，自动注入 skill description hint 到下次 system prompt（"file looks like X type, consider Y skill"）
- **Slash command 注册**：CLI/UI 的 `/skill-name args` 走专用 chat 注入路径（不通过 LLM tool call）
- **` !`shell` ` 预执行**：spec 支持 frontmatter / body 内嵌 shell 命令预执行注入；v1 不做
- **Skill registry 集成**：从 `anthropics/skills` repo 一键 install
- **Plugin 形态加载**：通过 plugin manager 动态加载第三方 skill bundle，复用 CatalogSource 接口

---

## Relations Integration（2026-05-19）

skill 在 relgraph 中作为节点（含孤儿）；name 是主键，不参与 wikilink。

| 方法 | 触发的 relation 操作 |
|---|---|
| `Service.Delete` | `PurgeEntity("skill", name)` 级联清边 |

skill 不直接写出向边；它通过 `workflow_uses_skill` 入向边被引用。reader 实现 `ListAllMeta` 给 relgraph 拉 label（skill name + description）。详 [`./relation.md`](./relation.md) §9.3。
