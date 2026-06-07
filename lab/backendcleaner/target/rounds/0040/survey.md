# R0040 skill 重写 — 业界 skill 设计调研（deep-research，2026-06-07）

> deep-research harness：104 agent · 22 源 · 110 claim → 25 核实（19 confirmed / 6 killed）· 5 角度 fan-out + 3 票对抗验证。
> 目的：给 skill 重写 + 3 个判定点定调。**结论：业界已高度收敛，Forgify 复用的 Anthropic SKILL.md 就是事实标准（agentskills.io open standard，Codex/Gemini/Copilot/Cursor 均采纳）；Forgify 现有设计大量已对标，重写主要是去 GORM + workspace 分桶 + 新地基跟进 + 几个小决策，不是大改。**

## 八条核实结论（confidence 高，除①为 medium）

1. **文件格式收敛**：目录 + SKILL.md，frontmatter 仅强制 `name`(≤64，小写字母数字连字符，禁 anthropic/claude 保留词) / `description`(非空 ≤1024，需同时编码「做什么+何时用」)，其余全 OPTIONAL。CrewAI 逐字采用。→ Forgify Frontmatter 镜像全字段**正确**；但 `MaxDescriptionChars=1536` vs 规范 1024 是本地放宽，**文档需登记偏差**。
2. **Progressive disclosure 三级**：L1 metadata(~100 token 常驻系统提示) / L2 body(<5k token 推荐非硬限，命中才读) / L3 附加 references/scripts/assets 按需读或 bash 执行、**脚本代码永不入上下文只回吐输出**。→ Forgify `scan.go` 已实现 L1/L2 分离（只缓存 frontmatter、Activate 重读 body）；`MaxBodyBytes=32KB` 是物理护栏（非 token 预算），合理。
3. **【判定点①热重载】无单一钦定机制**。三条具体说法（file-watching live-apply 1-2 / 显式 `/reload-skills` 0-3 / agent bash 读盘即发现 0-3）**全被对抗验证否决**——各厂实现不同、文档相互矛盾。验证者分两层：progressive disclosure 管「入上下文」(懒)，「磁盘发现」是另一层(启动 eager 扫描)。→ **Forgify 的 polling(1s ticker 全量 Scan + fingerprint diff + Activate 重读 body 带 rename-race 重试)比业界任何单一做法都稳健**，已解决 stale + 编辑器原子写竞态。无需改 fsnotify；唯一可议是 1s 桌面能耗。
4. **激活双模型**：inline(默认，渲染后 SKILL.md 单条消息注入、跨 turn 持久) vs `context: fork`(隔离 subagent prompt、无对话历史、必须声明 agent 否则 general-purpose)。→ Forgify `activate.go` 已 **1:1 对标官方**（验证者直接核对 activate.go:62/78/85 + scan.go:180），无需改。
5. **【判定点②allowed-tools】权威语义 = 预授权/自动批准（permission grant），非白名单限制**：列出的工具在 skill active 期间免逐次确认；未列出的仍可调、走既有权限。限制要另用 deny rules。CrewAI 标 experimental metadata。→ **Forgify `IsToolPreApprovedBySkill` 已正确实现**（命中免确认/不命中不阻塞回落，支持 `Bash(cmd*)` 命令级 glob）。**与「无中央门控、危险 LLM 逐次自报」(S18)完美自洽**：allowed-tools = 用户预先信任此 skill 的这些操作 → 免去 LLM 逐次 danger 自报+确认的快捷通道。
6. **【判定点③AI 可创建】Anthropic 软性愿景背书**：原文 'we hope to enable agents to create, edit, and evaluate Skills on their own'（'further ahead' 愿景，非已交付承诺）。→ Forgify `mutate.go` 已有 Create/Replace/Delete service 层，但 AI 工具面只有 activate/search/execution（不暴露创建）。**技术成本低**：新增 create_skill/edit_skill 工具桥接已有 mutate 即可。
7. **边界划分共识**：skill/rule = 注入指令上下文（怎么想） · tool = 可调用动作（怎么做） · workflow = 多步编排（trajectory）。激活轴 model-invoked vs user-invoked。→ **skill 不是 Quadrinity 第五实体**，而是「激活到当前 Agent 上下文 或 fork 成独立 Agent」的指令载体；skill 的 fork 正是「skill→派 Agent/subagent」的桥。
8. **Claude Code 私有扩展**（SKILL.md open standard 之上）：invocation control(`disable-model-invocation`/`user-invocable`) + subagent execution(`context:fork`+`agent`) + dynamic injection(`` !`cmd` `` shell 预处理)。→ Forgify Frontmatter 已含 `DisableModelInvocation`/`UserInvocable` 字段**但无消费点（只解析不生效）**；Forgify 用 `${CLAUDE_*}`/`$ARGUMENTS` 占位（比 `` !`cmd` `` 安全，无任意命令执行面）。

## 三个判定点的最终定调

**① 热重载/发现机制** —— 调研背书 Forgify 现有 polling「最稳健」，但**没考虑 workspace 分桶 + 桌面能耗**。综合定调：
> **砍常驻 1s 轮询 → 懒扫描 + 短 TTL（per workspace）+ 保留 fingerprint diff + 读时重读 body（含 rename-race 重试）。**
> 理由：① 桌面能耗（调研 openQuestion 4 也提）；② workspace 分桶下常驻轮询要扫所有 ws 目录、浪费；③ 对齐 memory 按需范式（无常驻 goroutine）；④ 保留了调研背书的稳健核心（fingerprint + 读时重读）。前端 mutate 后可主动触发一次 Scan（事件驱动补懒扫描）。

**② allowed-tools 语义** —— 调研**修正**了我之前「inline 降级为元数据」的说法。正解：
> **allowed-tools = 预授权（免 danger 确认）的快捷通道，非限制白名单。** activeSkill 持 skill + allowed-tools；danger 确认流（ask 波次 6）查 activeSkill 决定免不免确认。这轮 skill 在 agentstate 加 activeSkill 字段 + 保留 `IsToolPreApprovedBySkill` 逻辑，**预授权的「消费」留 ask 波次 6**（danger 确认流在那）。契约明确写「预授权(免确认) ≠ 限制白名单」。

**③ AI 可创建** —— 调研**修正**了我之前「只用户/HTTP」的倾向。正解：
> **分阶段：人类(HTTP/前端)创作为主路径 + AI 创作作为可选能力**（加 `create_skill`/`edit_skill` 工具，对话中「把这流程固化成 skill」）。`source` 字段区分（AI 写的 `source="ai"`，防与用户手写冲突/污染）。local-first 单人桌面下，AI 沉淀能力价值高、有官方背书。

## 调研带出的新判定点（要补决策）

- **N1 `disable-model-invocation` / `user-invocable` 实装？** 旧 Frontmatter 有字段但无消费点。实装 = 发现层据此分流：`disable-model-invocation` 的 skill 不进 LLM 的 search_skills 候选（只走用户显式触发）、`user-invocable` 暴露为前端 slash。关系到要不要引入 Claude Code 式 '/' command 入口。**倾向**：这轮先实装 `disable-model-invocation`（简单，发现层过滤），`user-invocable` 的前端 slash 留前端覆盖期。
- **N2 architecture.md 画出 skill 在 Quadrinity 的边界**（skill 非第五实体，是指令载体）。
- **N3 `` !`cmd` `` dynamic injection 不加**（Forgify 占位替换已是更安全子集，加它引入任意命令执行面）。保持现状。

## caveats（来自调研）

1. CC skill 体系 2026 上半年快速演化（commands 并入 skills ~v2.1.101、workflows 2026-05-28 preview、/reload-skills v2.1.152）——别把某时点 CC 实现当长期标准。
2. **allowed-tools 语义跨实现分叉**：CC/CrewAI = 预授权；但 agentskills.io 标准措辞像限制（'access ONLY to tools in allowed-tools'）。Forgify 选「预授权」正确（与无门控自洽），但**文档要声明采纳哪派**，避免迁入外部 skill 语义错配。
3. AI 自创是软性愿景非已交付，不可当「业界已普遍这么做」论据。
4. Cursor/Windsurf rules/workflows 是「相邻概念」非同一 skill（格式 .mdc/markdown 不同），是参照不是同构。
5. 市场/分发维度仅从 mutate.go+catalogsource.go 推断，**未读 import.go**——分发结论待补读。

## openQuestions（留考古/设计时定）

1. skill 市场/分发（import.go / catalogsource.go）：文件复制 / git / plugin 安装？业界（CC plugins、agentskills.io 生态、CrewAI skills repo）分发模型是否对标？**（本次未读这两文件）**
2. AI 创建 skill 如何防污染：source 字段区分 + 是否需要 sandbox 目录 / 审阅闸？
3. disable-model-invocation / user-invocable 实装到何种程度（见 N1）。
4. 1s 轮询 Wails 能耗（已定调改懒扫描+TTL，见判定点①）。

## 关键源（primary）

- Anthropic 官方：`platform.claude.com/docs/.../agent-skills/overview` · `anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills` · `anthropic.com/news/skills` · `github.com/anthropics/skills/.../skill-creator/SKILL.md`
- Claude Code：`code.claude.com/docs/en/skills` · `.../commands` · `.../agent-sdk/permissions`
- 跨厂：`docs.crewai.com/en/concepts/skills` · `agentskills.io/specification` · `docs.windsurf.com/.../cascade/workflows` · cursor rules reference
