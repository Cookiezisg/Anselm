---
id: WRK-086
type: working
status: active
owner: @weilin
created: 2026-07-31
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
landed-into:
---

# WRK-086 · 全仓文档治理战役

> 本文是本次 Goal 的详细执行合同。Goal 负责持续运行，本文负责定义范围、裁决方法与完成条件，[`LOG.md`](LOG.md) 只追加证据。任何“基本完成”“主要完成”都不能替代本文的逐项验收。

## 0. 战役目标

把 Anselm 全仓文档恢复为**可依赖的当前事实系统**：

1. 当前产品事实只存在于正确的 `concept` / `reference` / `how-to` 权威面。
2. `working/` 只保存真实未完成工作；已完成施工材料提炼结论后进入顶层 `archive/`。
3. 前端、后端、API Serve 边界、testend、根与子项目入口互相一致。
4. 机械门禁覆盖本战役发现的结构性腐烂模式，后续漂移不能静默复发。
5. 所有结论均有代码、测试、配置、git 或明确外部边界作证，不凭记忆补全。

## 1. 约束与权威

执行前完整读取：

```text
AGENTS.md → CLAUDE.md → docs/INDEX.md → docs/GOVERNANCE.md → 本文
```

冲突按 `CLAUDE.md > references > concepts > working > archive` 裁决；代码是 `reference` 的物理事实。额外约束：

- 不回改 ADR 的历史判断；需要新裁决时新建 superseding ADR。
- `reference` 与代码逐项核对；state 文档整体重述到当前，不在旧段旁追加补丁。
- archive 是历史证据，不是当前事实；不得从 archive 直接复制为现行结论而不复核代码。
- 不为了让门禁变绿而放宽断言、删除能力登记或隐藏不确定性。
- 不修改与本战役无关的产品代码；若文档核对发现真实代码缺陷，只登记 finding，除非用户另行授权修代码。
- 单一主会话写当前 worktree；并行只允许独立 worktree 的只读审计。
- 只提交本战役触及的文件；每批原子提交，提交前复核 `git diff`。

## 2. 全仓范围

### 2.1 受治理文件

- 根：`AGENTS.md`、`CLAUDE.md`、`README.md`。
- 文档系统：`docs/**`。
- 子项目入口：`frontend/README.md`、`demo/{README,CAPABILITY,PATTERNS}.md`、`testend/fixtures/README.md`。
- 资产/第三方说明：所有被 git 跟踪的 `*.md`。
- 文档执行层：`backend/cmd/docs/**`、`docs/Makefile` 及根门禁编排中与 docs 有关的目标。

### 2.2 必须交叉核对的事实面

- 后端：router、schema/migrations、错误构造、SSE 发射、domain/app/infra/store、启动配置、testend/evals。
- 前端：`lib/app`、`lib/core`、六个 `lib/features/*`、路由、contract DTO、i18n、测试、三平台宿主与 Makefile。
- 网关：同级 `Anselm-API-Serve` 只读核对公开产品边界、部署/环境职责与当前可达契约；主仓不得复制其私密配置或运维 secret。
- 仓库状态：git tracked files、近期 commit、现存门禁输出与工作树。

## 3. 文档分类裁决

每篇文档必须先回答下表，再允许修改或迁移：

| 问题 | 裁决 |
|---|---|
| 描述当前系统为什么这样组成？ | `concepts/` |
| 必须与代码/线缆逐项一致？ | `references/` |
| 是稳定可照做的操作步骤？ | `how-to/` |
| 记录不可变架构取舍？ | `decisions/` |
| 是只追加的事实时间线？ | `log`，放规范登记的日志位置 |
| 是尚未落地的方案/施工面？ | `working/` |
| 已完成、终止或被取代？ | 先提炼当前结论，再进顶层 `archive/` |

禁止形态：

- 同一篇同时承担 current reference、路线、施工日志和历史回顾。
- `working/**/archived/`、`legacy`、`old` 等私设墓地。
- 标题或正文一边说“未建/在建”，另一边列出已完成实现。
- INDEX、README 或 CLAUDE 把已完成工作导向 working 作为当前入口。
- “当前支持 N 个/有 N 篇/有 N 个错误码”没有机械来源且会快速漂移。
- 外部产品、价格、法规、供应商行为的时效结论未经当前官方来源复核。

## 4. 执行循环

每一批严格走：

```text
INVENTORY
→ CLASSIFY
→ VERIFY AGAINST CODE
→ REWRITE / MIGRATE
→ LINK & INDEX
→ GATE
→ ADVERSARIAL REVIEW
→ LOG
→ COMMIT
→ REVIEW NEXT FRONTIER
```

### 4.1 INVENTORY

记录文件、type/status/id、创建/审阅日期、入口与反向链接、大小、最后提交、代码锚点、可疑词和重复事实源。机械扫描结果只能产生候选，不能直接裁决内容。

### 4.2 CLASSIFY

给每篇候选标：

- `keep-current`
- `rewrite-current`
- `split`
- `land-and-archive`
- `archive-as-history`
- `delete-generated-or-duplicate`
- `needs-user-decision`

删除或迁移前先解析精确目标、全部反向链接和 `landed-into`。

### 4.3 VERIFY AGAINST CODE

至少核对一个权威物理锚点；契约类必须覆盖完整集合而非抽样。无法证明的句子删除、改成诚实边界，或进入 working 的待确认项。

### 4.4 REWRITE / MIGRATE

- current 文档从读者任务出发整体重述，去掉建造史、日报、过期数字与自我祝贺。
- 已完成 working 先提炼结论、填 `landed-into`，再移入 `docs/archive/<战役>/`。
- 迁移后修全部 active 文档链接；archive 内历史链接只有在会误导或完全不可读时才最小修复。

### 4.5 GATE / REVIEW / COMMIT

1. 运行本批最小门禁。
2. 搜索本批相关 stale marker。
3. 从“新读者能否只靠 current docs 得到正确心智”角度对抗复审。
4. 向 LOG 追加证据。
5. 查看完整 diff 与 status。
6. 原子提交；提交信息说明治理对象，不写泛化的 `update docs`。

## 5. 战役批次

### G0 · 基线与门禁

- 全仓 Markdown 账本、链接图、ID/type/status/lifecycle 账本。
- 保存开始 commit、初始门禁与已知 warning。
- 增加低误报结构门禁：受治理区 ID 唯一、目录/type 对齐、active/superseded 状态位置、禁止 working 内私设 archive、必要 frontmatter/日期/landed 规则。
- 为新增门禁补单测或可复现夹具，更新 GOVERNANCE §11 与 CLAUDE 常驻清单。

### G1 · 前端事实源

- 为 Chat、Scheduler、平台层建立完整 current reference。
- 核对并整体重述 frontend overview、architecture、contract、design-system 与各 feature 文档。
- 把已完成的 chat/tool-card/entity/workflow/right-island/scheduler 建造材料退出 working。
- 修 `frontend/README.md`、路由/目录/命令描述和所有入口。

### G2 · 后端与 API Serve 边界

- 逐域复核 backend overview、四索引、domains、foundation 与代码。
- 复核 `concepts/architecture.md`、CLAUDE 当前后端快照与路线。
- 明确主仓、已部署 API Serve、provider secret、device proof、managed/BYOK 的责任边界。
- 不把 API Serve 私密部署细节或 secret 复制进主仓。

### G3 · Working 与 Archive

- `backend-evolution` 保留真正活跃的循环、当前战役、frontier、log 与 history；旧体系移到顶层 archive。
- FRONTIER 只保存待探路径，不兼任重复日报；LOG 只追加已确认事实；CURRENT 只写当前边界。
- 平台发行研究与当前已落平台事实拆开；未实施且具时效性的发行材料明确为 draft，并给出重新验证要求。
- 所有已结项 working 按 §9 协议落地并归档。

### G4 · 入口与长尾

- 重述 docs INDEX、根 README、子项目 README。
- 审计 demo、testend fixtures、assets/brand/art 与其他 Markdown。
- 修孤儿链接、错误路径、重复地图、过期数量和废弃命名。
- 审计 archive 入口是否足以追溯，但不把墓地重新维护成第二套 current docs。

### G5 · 全量对抗验收

- 重跑结构账本和 stale-marker 搜索，逐项裁决残留。
- 运行 `make -C docs verify`。
- 运行与改动相关的 Go 测试。
- 运行 `make verify`；环境型失败需给出可复现证据，不能悄悄降级为通过。
- 对最终 diff 做一次独立只读审计：遗漏、错误归档、事实重复、过度删减、门禁误报与未授权代码变化。
- 输出最终文档地图和剩余真实 working；本战役自身落地并归档。

## 6. 硬完成条件

以下全部满足，Goal 才能标记完成：

### 6.1 结构

- [ ] 所有受治理 current Markdown 分类正确、frontmatter 合法、ID 在受治理区唯一。
- [ ] `working/` 只剩真实未完成工作；不存在 `working/**/archived` 或同义私设墓地。
- [ ] 已完成 working 均有 current 落点、`landed-into` 和顶层 archive。
- [ ] INDEX ≤50 行，入口不把已完成施工日志当 current source。
- [ ] 所有 active 文档本地链接存在；迁移后无旧路径引用。

### 6.2 前端

- [ ] overview、architecture、contract、design-system、platform 与 feature reference 互不冲突。
- [ ] `chat`、`entities`、`library`、`notifications`、`scheduler`、`settings` 六个真实 feature 均有 current 入口。
- [ ] 路由、目录、命令、sidecar、SSE、媒体和平台宿主描述与代码一致。
- [ ] 前端已完成施工材料全部退出 working。

### 6.3 后端与网关

- [ ] 四索引与代码机械/人工复核通过。
- [ ] 每个 backend domain/foundation 文档有真实代码归属且无已删除实现。
- [ ] architecture、CLAUDE 与 backend overview 的当前状态一致。
- [ ] 主仓与 API Serve 的公开责任边界准确，主仓文档不要求本地 provider secret 来证明默认产品路径。
- [ ] backend-evolution 当前面与历史面物理分开，CURRENT/FRONTIER/LOG/HISTORY 职责不混。

### 6.4 质量与防复发

- [ ] 对高风险词完成逐条人工裁决：`在建|待拍板|下一步|重建中|未建|旧版|legacy|已废|占位|future`。
- [ ] 没有同一事实在 CLAUDE/reference/concept/README 被多份展开复制；非权威处只做短链接。
- [ ] 新增门禁有测试或明确可复现的失败样例，且 GOVERNANCE/CLAUDE 同步。
- [ ] `make -C docs verify` 通过，warning 均有书面裁决。
- [ ] 相关局部门禁通过，最终 `make verify` 通过或只有被证实的外部环境阻塞。
- [ ] `git diff` 无无关产品代码、secret、生成垃圾或用户原有改动。

### 6.5 收尾

- [ ] LOG 含基线、批次、验证、commit 与剩余边界。
- [ ] 本战役可复用规则已进入 GOVERNANCE/CLAUDE/门禁。
- [ ] 本文与 LOG 填 `landed-into` 并移入 `docs/archive/document-governance/`。
- [ ] 最终工作树干净；向用户报告完整 commit 列表、当前文档地图和唯一剩余 working。

## 7. 停止、暂停与阻塞

- 用户说暂停：先把正在编辑的文件收至语法完整，记录 LOG 与 status，不擅自提交半批。
- 需要产品裁决：穷尽代码/历史证据后列精确选项，暂停该分支；不阻塞的其他批次继续。
- 外部仓库不可读、原生工具链缺失或网络失败：保留命令、时间和原始错误；改走仍可完成的批次。
- 额度、上下文或时间不是降低完成标准的理由。Goal 只有满足 §6 才算完成。

## 8. 启动时工作树说明

Goal 启动前存在一组**未提交、未验收的前端治理草稿**：

```text
M  docs/references/frontend/overview.md
M  frontend/README.md
?? docs/references/frontend/features/chat.md
?? docs/references/frontend/features/scheduler.md
?? docs/references/frontend/platform.md
```

这些文件是本战役自身的预备草稿，不属于用户既有改动，但**不得直接视为正确或完成**。G1 必须从代码和既有文档重新复核，允许重写或删除；通过相应门禁和对抗复审后才能提交。
