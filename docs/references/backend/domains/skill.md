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

正文注入当前 Conversation，并把 allowed-tools 记为本次运行的预授权。Skill
不是限制白名单；未预授权的 dangerous tool 仍进入逐次 HumanLoop。激活不执行
反引号 shell substitution。

若正文未引用目录但存在 bundled files，渲染结果会前置 Skill 绝对目录，使模型
能解析相对资源。Filesystem 工具只对本 workspace Skill subtree 做精确豁免，
仍先解析 symlink。

### Fork

`context=fork` 将渲染后的任务交给指定 Subagent type；缺 agent 或 runner 时
大声失败。Subagent 深度与工具隔离见 [`subagent.md`](subagent.md)。

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

## 5. 脚本与投影

`run_skill_script` 只运行 Files 列表中的脚本：

- `.py`、`.js`、`.mjs`、`.cjs` 进入 Skill 专属 Sandbox env；
- cwd 与 `CLAUDE_SKILL_DIR` 指向 Skill 目录；
- Python requirements 可形成 env dependencies；
- 其它脚本走 host shell，并继续受危险确认。

Skill 进入 Catalog、Mention、Search 和 Relation。Search 只索引 manifest
description/when-to-use/body chunks，不索引 bundled files。

## 6. 契约

精确 CRUD、activate、install/update/approve 与 files 端点见
[`api.md`](../api.md)，错误见
[`error-codes.md`](../error-codes.md)，事件见
[`events.md`](../events.md)。无数据库表或生成 ID。

LLM 工具覆盖 activate、get、create、edit、delete 与 run script。内建工具候选
来自 `GET /tools`，实体/MCP callable 从各自 live surface 选择。
