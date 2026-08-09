---
id: DOC-018
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Skill

## 1. 定位

Skill 是 workspace 文件系统中的指令载体：`<name>/SKILL.md` 是真相，name
就是 identity。它没有数据库表、版本或执行日志；编辑直接覆盖文件。

Get 返回正文、frontmatter、绝对目录和安装 provenance；List 只返回轻量
metadata。

## 2. Frontmatter 与文件真相

类型化 frontmatter 覆盖：

- Agent Skills 核心：name、description、license、compatibility、metadata、
  allowed-tools；
- 执行扩展：context、agent、arguments、disable-model-invocation、
  user-invocable、when-to-use、model、effort；
- Anselm source：`user|ai`。

原始 YAML tree 是保真真相，未知 keys 与顺序在结构化编辑后继续存在。
`allowed-tools` 接受 YAML list 与空格分隔 string。结构化 body 不能再带一个
frontmatter block；raw SKILL.md 写入则保留原文。

新建 name 使用规范 lowercase hyphen slug；读取存量时使用更宽但仍文件安全的
guard。Manifest、description 与 bundled file 有物理大小上限。

Files API 包含 SKILL.md 与附属文件。相对路径先做词法/clean 检查，再通过
`os.Root` 阻断 symlink 与 TOCTOU 逃逸。Manifest 不能作为普通 file 删除；
写 manifest 进入 raw replace 校验并重算 relation。

## 3. 激活

### Inline

Inline Skill 渲染：

- `$ARGUMENTS`、位置/命名参数；
- `${CLAUDE_SESSION_ID}`；
- `${CLAUDE_SKILL_DIR}`。

`activate_skill` 的公开 schema 将 `arguments` 定义为 `array<string>`。为兼容托管模型
偶尔发出的标量形状，执行层也接受**精确 JSON 数组编码的字符串**（例如
`"[\"design\",\"review\"]"`），再按数组解码；普通字符串、数字、对象、混合类型数组
和非法 JSON 字符串仍明确拒绝，不做静默拆词或模糊转换。

`create_skill` 与 `edit_skill` 的 `allowedTools`、`arguments` 同样公开为
`array<string>`，执行层兼容精确 JSON 数组编码的字符串。该兼容只适用于数组的完整
JSON 编码；普通字符串、数字、对象、混合类型数组和非法编码仍拒绝，避免一次托管模型
调用先产生失败卡、再自行重试成第二次写入。

`create_skill` 与 `edit_skill` 的 `disableModelInvocation` 公开为 `boolean`；执行层同时
接受精确的字符串 `"true"`/`"false"`，以吸收托管模型的标量字符串化。数字、任意 truthy
文本和对象仍拒绝，不把形状错误扩大成业务语义。

`edit_skill` 对 `skill not found` 声明终局拒绝：同一回合后续完全相同的调用只返回 ledger
抑制结果，不再次触碰文件系统或制造第二张红卡；下一条用户消息使用新台账，仍可在目标出现后
有意重试。权限、临时文件系统等其他错误不被这一条吞掉。

`create_skill` 的工具短描述同时列出必填字段 `name/description/body` 与可选的
`allowedTools/context/agent/arguments/disableModelInvocation/userInvocable`；不能依赖模型从截断的
工具摘要猜测这些字段。

正文注入当前 Conversation，并把 allowed-tools 记为本次运行的预授权。Skill
不是限制白名单；未预授权的 dangerous tool 仍进入逐次 HumanLoop。激活不执行
反引号 shell substitution。

若正文未引用目录但存在 bundled files，渲染结果会前置 Skill 绝对目录，使模型
能解析相对资源。Filesystem 工具只对本 workspace Skill subtree 做精确豁免，
仍先解析 symlink。

### Fork

`context=fork` 将渲染后的任务交给指定 Subagent type。当前 runner 注册的、区分大小写的类型为
`Explore`（只读探索）、`Plan`（制定计划）和 `general-purpose`（继承父工具集）；创建/替换时
未知类型直接返回 `422 SKILL_FORK_AGENT_TYPE_INVALID`，错误 details 带 `agent` 与 `validAgents`。
安装或旧文件绕过写入校验时，激活仍在任何 active-skill 预授权之前 fail-closed。缺 agent 或 runner
时分别返回 `SKILL_FORK_REQUIRES_AGENT` / `SKILL_SUBAGENT_UNAVAILABLE`。Subagent 深度与工具隔离见
[`subagent.md`](subagent.md)。

`Explore` 对 fork skill 的 `$1` 主题执行有界探索：精确绝对路径只读该路径；`LS/Glob/Grep` 只能在
Conversation 已挂载的驻地内执行，未挂驻地时直接返回可解释边界提示；结果过宽时不枚举 home、Desktop、
Documents 或无关归档目录。这是用户等待时间与误读范围的产品边界，不削弱普通 Chat/Task 的整机只读工具面。

### Mention 与 Agent Guide

`@skill` 对 inline Skill 同时注入内容并执行同一 preauthorization；fork Skill
的 `@` 只注入指南，不偷偷派生 Subagent 或授予工具。

Agent `Guide(name)` 只渲染执行指南和目录变量，不接收 arguments、不设置父
Conversation active-skill，也不触发 fork。

## 4. 安装与信任

`InspectSource` 对 GitHub shorthand/URL 或 HTTP(S) tarball 做无写入预览。
Fetcher 限制压缩/解压大小、条目数和单文件大小，丢弃 symlink 与平台垃圾；
含 SKILL.md 的目录形成候选。

Install 写 manifest 与 bundled files，并创建隐藏的
`.anselm-install.json`：

- normalized source 与安装时间；
- file hash baseline；
- `toolsApproved=false`。

Installed source 由 sidecar 推导，不改上游 frontmatter。Files API 不暴露
sidecar。

更新前比较 hash baseline；有本地修改且未 force 时返回
`SKILL_LOCALLY_MODIFIED`。Allowed-tools 变化会重置信任门，未变化时保留授权。
第三方 Skill 未批准前仍可注入正文，但其 allowed-tools 不成为预授权。

`POST /skills/{name}:approve-tools` 打开已安装 Skill 的信任门，将 provenance 的
`toolsApproved` 置为 `true`，并发出一次 `skill.updated` durable signal。重复授权是
幂等 no-op：若已经为 `true`，只返回当前 Skill，不重写 provenance、不刷新
`updatedAt`、也不发假的 `skill.updated`。

## 5. 脚本与投影

`run_skill_script` 只运行 Files 列表中的脚本。调用时 `name` 是 skill slug（用户所说的
skill 名），`script` 是相对该 skill 目录的脚本路径；这样在 lazy 工具尚未激活完整
schema 时，目录摘要也能把用户语义映射到正确的必填键：

- `.py`、`.js`、`.mjs`、`.cjs` 进入 Skill 专属 Sandbox env；
- cwd 与 `CLAUDE_SKILL_DIR` 指向 Skill 目录；
- Python requirements 可形成 env dependencies；
- `args` 的公开类型是字符串数组，`timeoutSec` 的公开类型是整数；对真实托管 wire 为避免无意义的首呼失败，二者分别额外接受**精确 JSON 数组字符串**与**精确十进制整数字符串**；标量文本、混合数组、浮点、布尔、对象和其它模糊形状仍硬拒；
- 其它脚本走 host shell，并继续受危险确认。

Skill 进入 Catalog、Mention、Search 和 Relation。Search 只索引 manifest
description/when-to-use/body chunks，不索引 bundled files。

## 6. 契约

精确 CRUD、activate、install/update/approve 与 files 端点见
[`api.md`](../api.md)，错误见
[`error-codes.md`](../error-codes.md)，事件见
[`events.md`](../events.md)。无数据库表或生成 ID。

LLM 工具覆盖 activate、get、create、edit、delete 与 run script。`delete_skill` 永久移除 skill
目录，没有 restore 操作，具有不可绕过的静态 `dangerous` 下限；即使模型自报 `safe` 也必须经过
HumanLoop 用户批准，且不能被 skill 或 `approve_always` 预授权绕过。内建工具候选
来自 `GET /tools`，实体/MCP callable 从各自 live surface 选择。
