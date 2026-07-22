---
id: DOC-018
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-22
review-due: 2026-10-22
audience: [human, ai]
---

# skill —— 目录式 Agent Skill（指令载体，文件即真相）

## 1. 定位 + 心智模型

skill 是**指令载体、非构建实体**——memory 的近亲（文件式注入物），不是 function 的近亲（执行实体）。**name(slug) 即身份**：无生成 id、无版本（编辑即覆盖文件）、零 DB 表、零 LLM 依赖；无 execution log、无 LLM 搜索（与文件式指令载体的抽象错配，故不提供）。

**目录即真相**（对齐 [Agent Skills 开放规范](https://agentskills.io/specification)，WRK-076）：每 skill 一个目录 `~/.anselm/workspaces/<ws>/skills/<name>/`，清单 `SKILL.md`（读取时小写 `skill.md` 回退、平台写入恒大写，写入清退独立小写残件——大小写不敏感文件系统上经 `SameFile` 判别防自删）+ **任意捆绑文件**（references/scripts/assets…，经 files 子资源 CRUD）。**纯按需**：每次 List 现扫目录、只读清单，无缓存/无 watcher；坏文件跳过不连坐（单读则大声失败）。**读永不写回**；结构化写对原文 YAML 节点树做手术（**typed 视图之外的键与键序在编辑循环中不丢**——`license`/`metadata`/厂商扩展键经右岛表单编辑幸存）；原文写（files 面 PUT SKILL.md）逐字节忠实、不 TrimSpace。

**双正则（WRK-076 D3）**：守卫正则 `^[a-z0-9][a-z0-9_-]{0,63}$` 是路径穿越守卫 + 存量兜底（允数字开头与 `_`，合法 name 1:1 映射目录）；创建正则 `^[a-z0-9]+(-[a-z0-9]+)*$`（≤64）是规范 ASCII 形态、仅新建从严（无 `_`、无首尾/连续连字符；刻意不采参考实现的 Unicode 放宽——跨平台文件系统一致性优先）。

**Frontmatter = 规范核心 6 字段**（name/description 必填 + license/compatibility/metadata/allowed-tools）**+ Claude Code 扩展**（context/agent/arguments/disable-model-invocation/user-invocable/when_to_use/model/effort）**+ Anselm 扩展 `source: user|ai`**。未知 top-level 键运行时忽略、编辑保真保留（比规范参考实现更强——它读时丢弃）。`allowed-tools` 线格式两态兼容：YAML 列表或规范的空格分隔字符串（读时归一为列表）。结构化面（POST/PUT 参数）仍由平台组装 frontmatter、body 仅正文——**结构化 body 不得自带 frontmatter 块**（`--- … ---` 开头则 `SKILL_INVALID_FRONTMATTER` 拒；孤立 `---` 分隔线放行）；原文面提交整份 SKILL.md、天然以围栏开头（先切围栏再校验）。护栏：清单 ≤32KB、description ≤1024 字符、附属文件单文件 ≤1MB。

## 2. 行为

- **激活两模式**（`Activate(name, args)`）：`inline` = 渲染正文（`$ARGUMENTS`/`$1..$n`/命名占位/`${CLAUDE_SESSION_ID}` 替换；刻意**不支持** `` !`cmd` `` shell 注入——任意执行面，拒绝）注入当前对话 + **把 allowed-tools 记为本次运行的预授权**（active skill，危险确认流消费——预授权非限制白名单）；`fork` = 把渲染正文派给隔离 subagent（frontmatter.agent 必填，否则 `SKILL_FORK_REQUIRES_AGENT`）。
- **`Guide(name)`**（agent 挂载路径）：只渲染正文（展开 `${CLAUDE_SESSION_ID}`，不接 `$ARGUMENTS`/位置参数）、**不**设 active-skill、**不** fork——见 [agent.md](agent.md)#3。
- **创作**：Create（同名 → `SKILL_NAME_CONFLICT`；name 过创建正则）/ Replace（缺失 → 404；守卫正则，存量下划线名照常）/ Delete（删整目录）；同步 relation 边（allowed-tools → equip 出边、构建对话 → 入边）。
- **files 面**（文件即真相）：ListFiles（含清单，slash 相对路径升序）/ ReadFile（读护栏统一 1MB，超限清单也可读——修坏件通道）/ WriteFile（清单路径路由到 **ReplaceRaw**：skill 必须已存在 + 尺寸/围栏/`name`==目录名校验〔description 刻意不必填，导入件可缺省〕+ equip 边重同步；附属文件父目录按需建）/ DeleteFile（**清单拒删**，指向 `DELETE /skills/{name}`）。**穿越守卫三重**：`filepath.IsLocal` 词法早拒（含反斜杠拒）→ Clean 复核 → 一切 I/O 经 `os.Root` 句柄（symlink 逃逸/TOCTOU 内核级阻断）；文件写/删发 `skill.updated`（payload 携 `path`）。

## 3. 契约（引用）

端点 → [api.md](../api.md)（CRUD + `:activate` + files 子资源〔`{path...}` 尾随通配〕）· 无 DB 表（文件式）· 码 `SKILL_*` 10+1 → [error-codes.md](../error-codes.md) · 通知 `skill.{created,updated,deleted}`（文件写的 `updated` 携 `path`）。LLM 工具 5 个：activate/get/create/edit/delete_skill（无 search——catalog 概览已曝光全部 skill）。消费方：chat loop（active skill 预授权）、agent（Guide 挂载）、catalog（name+desc）、搜索索引（**仅清单**：description+whenToUse 卡片 + body 分块；附属文件不进索引——已知取舍，WRK-076 D10）。
