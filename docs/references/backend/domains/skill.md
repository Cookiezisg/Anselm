---
id: DOC-122
type: reference
status: active
owner: @weilin
created: 2026-04-22
reviewed: 2026-06-07
review-due: 2026-09-01
audience: [human, ai]
---
# Skill Domain — 文件式指令载体（memory 的近亲）

> **定位**：skill 是**可复用的指令手册**——写在 SKILL.md 文件里的预制指令包，LLM 遇到对应任务时激活、照着做。它**不是 Quadrinity 第五实体**，而是「把一段指令注入当前 Agent 上下文（inline）或 fork 成独立 Agent（fork）」的载体。本性是 **memory 的近亲**（文件式注入物），不是 function 的近亲（执行实体）：故**无 execution 审计、无 search、无版本、零 DB 表、零 LLM 依赖**。

---

## 1. 物理模型

skill 主权在文件系统，**无数据库表**。

- **位置**：`~/.forgify/workspaces/<wsID>/skills/<name>/SKILL.md`（按 workspace 分桶；目录式，为将来附加 references/scripts 留结构）。
- **身份**：`name`（slug，`^[a-z][a-z0-9_-]{0,63}$`）——slug 即身份，**无生成 id、无版本**（编辑即覆盖文件）。slug 1:1 映射目录即天然防路径穿越。
- **格式**：YAML frontmatter + Markdown body，逐字镜像 Anthropic SKILL.md 规范（frontmatter 用 `go.yaml.in/yaml/v3` 解析）。

### 1.1 Frontmatter（Anthropic 全字段镜像 + Forgify `source` 扩展）

| 字段 | 必填 | 含义 |
|---|---|---|
| `name` | ✓ | slug（≤64） |
| `description` | ✓ | 做什么 + 何时用（≤1024；LLM 据此决定激活） |
| `allowed-tools` | | **预授权**工具（激活期间免危险确认，**非**限制白名单） |
| `context` | | `inline`（默认，注入当前对话）/ `fork`（派 subagent） |
| `agent` | | fork 的 subagent 类型（`context=fork` 必填） |
| `arguments` | | 命名参数标签（`$name` 替换） |
| `disable-model-invocation` | | true 则不进 LLM catalog 概览（只人工触发） |
| `user-invocable` / `when_to_use` / `model` / `effort` | | 镜像保留（当前不消费，便于跨厂迁移） |
| `source` | | **Forgify 扩展**：`user` / `ai`（谁创作，防污染） |

### 1.2 Skill（读时投影）
`{name, description, source, context, body(仅 Get 填), frontmatter, updatedAt(=文件 mtime)}`。

---

## 2. 核心原理

### 2.1 发现 = 纯按需扫描（无缓存 / 无轮询 / 无 fingerprint）
skill 作为 catalog 数据源，catalog 组装概览时**现扫** `skills/` 目录、报每个 SKILL.md 的 name+description。LLM 看完概览**直接** `activate_skill`——无 search 中间层（数量少、已全曝光）。`disable-model-invocation` 的 skill 不进概览。Service 几乎无状态（只持 base 路径 + 端口）。

### 2.2 激活双模式
- **inline**（默认）：读 body → 占位替换 → 作为工具结果**注入当前对话** + 设 `activeSkill`。
- **fork**（`context: fork`）：同样替换 → 把正文交给**隔离 subagent**（`agent` 指定类型）独立执行、返回结论。经 `SubagentRunner` 端口（subagent 波次 5 注入；未注入时返 `SKILL_SUBAGENT_UNAVAILABLE`，inline 完整可用）。

### 2.3 占位替换
`$ARGUMENTS`（全部）/ `$1..$n`（位置）/ `$name`（命名）/ `${CLAUDE_SESSION_ID}`。**不支持** `` !`cmd` `` shell 注入（任意执行面，拒绝）；`${CLAUDE_SKILL_DIR}` 待 L3 附加文件那轮。

### 2.4 allowed-tools = 预授权（非限制）
激活时把 allowed-tools 写入 `agentstate.activeSkill`（`skill/activate.go`）；danger 确认门（`loop.dispatchWithGate`）经 `agentstate.IsToolPreApprovedBySkill` 据此对这些工具**免逐次确认**——**R0064 建 danger 门 + R0066 接通 skill 消费侧**（消费侧此前留口、现已落地）。未列出的工具照常可用、照常确认。与「无中央门控、危险靠 LLM 逐次自报」(S18) 天然自洽——allowed-tools 是免确认快捷通道，不是门控。

### 2.5 创作与分发
- `create_skill` / `edit_skill` / `delete_skill`：人工 HTTP（`source=user`）/ AI 工具（`source=ai`，区分作者防污染）。
- `edit` = 全量覆盖（无版本历史）。
- 分发 = 文件落到 `skills/` 即被下次扫描发现，**无专门 import / 市场机制**（市场留后）。

---

## 3. 与 function 的对照（部分对齐 + 3 处本质不对称）
工具命名手感对齐 function（create/edit/delete/get + activate≈run），让四类能力学一套。但 skill 是文件式指令载体，**本质不对齐**：① 无版本 / revert ② 不可 `@mention`（mention 5 种不含 skill）③ 纯文件、无 execution 审计、无 search、无 DB 表。

---

## 4. 跨域集成
- **Catalog**：skill 当数据源（这是发现入口）。
- **Relation**：`allowed-tools` 的 `fn_`/`hd_` 引用 → `skill →(equip)→ function/handler` 边；对话创作 → `conversation →(create)→ skill` 边。**relation 节点 id = name**（文件式无生成 id；R0021 预留的 `sk_` 前缀对文件式 skill 不启用）。
- **Agentstate**：`activeSkill` 槽（预授权 allowed-tools）。
- **Subagent**：fork 经 `SubagentRunner` 端口（波次 5）。

---

## 5. 工具（5，无 search / 无 execution 查询）
`activate_skill`（核心：inline 注入 / fork 派 subagent）· `get_skill`（读原文不激活）· `create_skill` · `edit_skill` · `delete_skill`。

## 6. HTTP 端点
`GET /skills`（全集，不分页）· `GET /skills/{name}` · `POST /skills` · `PUT /skills/{name}` · `DELETE /skills/{name}` · `POST /skills/{name}:activate`。

---

## 7. 错误字典

| Sentinel | Wire Code | Kind → HTTP | 场景 |
|---|---|---|---|
| `ErrNotFound` | `SKILL_NOT_FOUND` | 404 | SKILL.md 不存在 |
| `ErrInvalidName` | `SKILL_INVALID_NAME` | 400 | name 非 slug / 含路径穿越 |
| `ErrInvalidFrontmatter` | `SKILL_INVALID_FRONTMATTER` | 422 | YAML 坏 / description 缺或超长 / source 非法 |
| `ErrBodyTooLarge` | `SKILL_BODY_TOO_LARGE` | 422 | body > 32 KiB |
| `ErrNameConflict` | `SKILL_NAME_CONFLICT` | 409 | create 同名已存在 |
| `ErrForkRequiresAgent` | `SKILL_FORK_REQUIRES_AGENT` | 422 | `context=fork` 缺 `agent` |
| `ErrSubagentUnavailable` | `SKILL_SUBAGENT_UNAVAILABLE` | 503 | fork 但 subagent runner 未装（波次 5 前） |
