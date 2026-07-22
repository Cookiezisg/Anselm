---
id: WRK-075
type: working
status: active
owner: @weilin
created: 2026-07-22
reviewed: 2026-07-22
review-due: 2026-10-20
audience: [human, ai]
---

# Skill 标准化战役 — 对齐 Agent Skills 开放规范（总纲）

> 目标：把 skill 从「平台组装的单文件投影」翻转为「**目录即真相**」的标准 Agent Skill——用户可自由安装 GitHub skill、文件夹随意组织、捆绑脚本可执行。法定基线 = [agentskills.io 开放规范](https://agentskills.io/specification)（参考校验器 `agentskills/agentskills` 的 `skills-ref`）；Claude Code 扩展字段按现状已镜像、继续跟随。批次规范单独成篇（`b1-*.md`…），本篇只留总表 + 跨批已拍板决策。

## 六批总表

| 批 | 范围 | 核心交付 | 状态 |
|---|---|---|---|
| **B1 文件即真相** | 后端 infra/app/transport | frontmatter 保真（yaml.Node）· SKILL.md 原文面 · files 子资源 CRUD + 穿越守卫 | **已落地并提交** → [b1-file-truth.md](b1-file-truth.md) |
| **B2 渐进披露** | 后端 activate/Guide + pathguard | `${CLAUDE_SKILL_DIR}` 文本替换 + 目录前导行（带捆绑文件才加）· skills 子树 pathguard 豁免（symlink 先解）· ~~model/effort 消费~~（subagent ModelResolver 无 override 口，backlog） | **已落地** |
| **B3 脚本执行** | 后端 shell/sandbox | 绝对路径执行 · 沙箱运行时默认 + `OwnerKindSkill` env 注入落地 | 待 B2 |
| **B4 安装通道** | 后端新 install 面 | GitHub tarball 安装器（复用 directInstaller 管线，支持 subdir/整仓扫描）· `.anselm-install.json` provenance · `:install`/`:update` · `source=installed` + allowed-tools 信任门 | 待 B3 |
| **F1 folder skill 浏览编辑** | 前端 contract + documents | DTO 开放化 · 编辑器按文件类型分派（md 富文本 / 代码 AnCodeEditor / 资产只读）+ 双模切换 · 页顶文件条 + `/documents/skill/:name/file/:path` · 右岛文件组 · rail 来源角标 | 待 B1-B2 |
| **F2 安装流与入口** | 前端 rail/右岛/chat/composer | 安装对话框（allowed-tools 琥珀前置）· 顶带进度 · 右岛来源组 + 预授权确认区 · composer `/` 斜杠菜单 · install 舞台 | 待 B4 |

## 跨批已拍板（2026-07-22，用户裁决）

1. **右岛结构化配置表单保留**——降级为便利投影，底层走保真读-改-写；主编辑面是原文。
2. **已安装 skill 用户可改**——update 前 diff 提示「本地已改、更新会覆盖」，用户选。
3. **脚本执行默认沙箱**，host bash 走显式选项 + 危险确认。
4. **SKILL.md 编辑双模**：富文本默认（codec 三保真兜底）+ 源码视图可切。
5. **文件树两处分工**：右岛文件组管概览跳转，海洋页顶文件条管当前编辑对象。
6. **刻意不对齐一处**：`` !`cmd` `` 激活期动态 shell 注入继续拒绝（任意执行面；三方 skill 世界里更危险）——文档注明。
7. **信任门（标准之上的本地加严）**：`source=installed` 的 skill，allowed-tools 需用户显式授权后才进 active-skill 预授权；未授权前危险确认照常。

## 立法基线速记（调研裁决，2026-07-22，三源交叉验证）

- **规范核心字段仅 6 个**：`name` / `description`（必填）+ `license` / `compatibility` / `metadata` / `allowed-tools`（可选）。**无 top-level `version`**（版本走 `metadata.version`）。Anselm 现有 context/agent/arguments/disable-model-invocation/user-invocable/when_to_use/model/effort 全部属 Claude Code 扩展层——保留跟随。
- **未知 top-level 键**：运行时**忽略但保真保留**（本项目比规范参考实现更强：`read_properties` 丢弃，我们编辑不丢）；发布 lint 严格模式后置。
- **`${CLAUDE_SKILL_DIR}`** = 文本替换非环境变量，值 = SKILL.md 所在目录；生态 skill 原文写的就是这个名字，**必须原名支持**。
- **allowed-tools 线格式两态**：规范 = 空格分隔字符串，Anselm 现状 = YAML 列表——读取两态兼容，写回归一为列表。
- **SKILL.md 大小写**：参考实现大写优先、回退接受 `skill.md`——跟随。
