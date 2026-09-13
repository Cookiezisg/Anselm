/// The story dataset's Library surface — a three-level document tree + two folder skills, every id and
/// title taken from the story bible so the digest page, its backlinks, the approval card and the skill
/// rail all point at the same rows. Prose is bilingual via [StoryLocale.t]; identifiers, paths and code
/// stay English.
///
/// story 数据集的资料库面——三层文档树 + 两个 folder skill，id 与标题全部取自故事总纲，周报页、反链、
/// 审批卡与 skill rail 才指向同一批行。文案经 [StoryLocale.t] 双语，标识符、路径与代码保持英文。
library;

import 'dart:convert';

import '../../core/contract/entities/document.dart';
import '../../core/contract/entities/skill.dart';
import '../../features/library/data/library_fixtures.dart';
import 'story_bible.dart';
import 'story_locale.dart';

/// Seeds a [FixtureLibraryRepository] with the story's documents and skills. 用故事文档与 skill 播种。
FixtureLibraryRepository storyLibraryRepository(StoryLocale l) {
  // Wikilinks MUST be `[[<doc id>]]`: the codec + the fixture's backlink scan both key on the id shape
  // (a title inside the brackets renders as dead double-bracket text and yields no backlink).
  // wikilink 必须是 `[[<doc id>]]`：codec 与 fixture 反链扫描都按 id 形匹配，写标题=死文本且无反链。
  String link(String id) => '[[$id]]';

  DocumentNode doc({
    required String id,
    required String? parent,
    required String name,
    required int position,
    required String path,
    required String description,
    required List<String> tags,
    required String content,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) => DocumentNode(
    id: id,
    parentId: parent,
    name: name,
    position: position,
    path: path,
    content: content,
    description: description,
    tags: tags,
    // Byte length, not rune count — the backend's size_bytes is what the properties panel shows, and a
    // Chinese body is roughly 3× its character count. 按字节而非字符计：属性面板显示后端 size_bytes。
    sizeBytes: utf8.encode(content).length,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  final handbook = docHandbookTitle(l);
  final onboarding = docOnboardingTitle(l);
  final releaseProcess = docReleaseProcessTitle(l);
  final digestsFolder = docDigestsFolderTitle(l);
  final digestLatest = docDigestLatestTitle(l);
  final digestPrev = docDigestPrevTitle(l);
  final supportPlaybook = docSupportPlaybookTitle(l);
  final launchPlan = docLaunchPlanTitle(l);

  return FixtureLibraryRepository(
    documents: [
      // ── Team Handbook (root) ─────────────────────────────────────────────
      doc(
        id: docHandbook,
        parent: null,
        name: handbook,
        position: 0,
        path: '/$handbook',
        description: l.t(
          'How the product team works: rituals, ownership, release cadence.',
          '产品团队的工作方式：仪式、责任归属、发布节奏。',
        ),
        tags: const ['handbook', 'team'],
        createdAt: ago(days: 92),
        updatedAt: ago(days: 6, hours: 3),
        content: l.t(
          'This handbook is the single place a teammate looks when they wonder "how do we do X here". '
              'Start with ${link(docOnboarding)} on your first day and keep ${link(docReleaseProcess)} open '
              'on every release Friday.\n\n'
              '## Rituals\n\n'
              '- **Monday 09:00** — the weekly GitHub digest lands in Slack (`$wfDigestName`), then a '
              '15-minute planning sync\n'
              '- **Wednesday** — support triage review: every ticket routed by `$agTriageName` gets a '
              'human glance\n'
              '- **Friday** — release window; nothing ships after 16:00\n\n'
              '## Ownership\n\n'
              '| Area | Owner | Backup |\n'
              '| --- | --- | --- |\n'
              '| Workflows & scheduling | $authorName | Mei |\n'
              '| Support playbook | Mei | Jonas |\n'
              '| Launch site | Jonas | $authorName |\n\n'
              '## Principles\n\n'
              '1. Automate the boring half first — the digest, the ticket routing, the invoice intake\n'
              '2. Every automation gets a human review gate before it writes anywhere external\n'
              '3. Write it down here, not in a DM\n\n'
              '> If the handbook and reality disagree, fix the handbook in the same week.',
          '这本手册是同事想知道「我们这里 X 怎么做」时唯一要看的地方。入职第一天先读 '
              '${link(docOnboarding)}，每个发布周五把 ${link(docReleaseProcess)} 开在旁边。\n\n'
              '## 仪式\n\n'
              '- **周一 09:00** — GitHub 周报进 Slack（`$wfDigestName`），随后 15 分钟计划同步\n'
              '- **周三** — 客服分诊复盘：每张由 `$agTriageName` 路由的工单都过一遍人眼\n'
              '- **周五** — 发布窗口；16:00 后不再上线\n\n'
              '## 责任归属\n\n'
              '| 领域 | 负责人 | 备份 |\n'
              '| --- | --- | --- |\n'
              '| 工作流与调度 | $authorName | 小梅 |\n'
              '| 客服手册 | 小梅 | Jonas |\n'
              '| 发布站点 | Jonas | $authorName |\n\n'
              '## 原则\n\n'
              '1. 先把无聊的那一半自动化——周报、工单路由、发票录入\n'
              '2. 每个自动化在对外写入前都要有人工复核门\n'
              '3. 写在这里，不要写在私聊里\n\n'
              '> 手册和现实不一致时，当周就把手册改对。',
        ),
      ),
      doc(
        id: docOnboarding,
        parent: docHandbook,
        name: onboarding,
        position: 0,
        path: '/$handbook/$onboarding',
        description: l.t(
          'First-week checklist for a new teammate.',
          '新同事第一周清单。',
        ),
        tags: const ['handbook', 'onboarding'],
        createdAt: ago(days: 80),
        updatedAt: ago(days: 11),
        content: l.t(
          'Welcome aboard. The goal of week one is simple: run every automation once by hand so you '
              'know what it does before it does it for you.\n\n'
              '## Day 1\n\n'
              '- [x] Install the desktop app and point it at the shared workspace\n'
              '- [x] Skim ${link(docHandbook)}\n'
              '- [ ] Join `#product-digest` and `#support-triage` in Slack\n\n'
              '## Day 2 – 3\n\n'
              '- [ ] Trigger `$wfDigestName` manually and read the draft it parks for review\n'
              '- [ ] Open the `$skillGithubDigest` skill and read `templates/digest.md`\n'
              '- [ ] Watch one `$wfTriageName` run route a real ticket\n\n'
              '## Day 4 – 5\n\n'
              '- [ ] Pair on a release with the owner of ${link(docReleaseProcess)}\n'
              '- [ ] Write one paragraph in this handbook that was missing when you needed it\n\n'
              '## Accounts you will need\n\n'
              '```text\n'
              'github     org: Cookiezisg     role: member\n'
              'slack      channels: #product-digest #support-triage\n'
              'zendesk    role: agent (read + comment)\n'
              '```',
          '欢迎加入。第一周的目标很简单：把每个自动化亲手跑一遍，在它替你做事之前先知道它在做什么。\n\n'
              '## 第 1 天\n\n'
              '- [x] 安装桌面应用并连到共享 workspace\n'
              '- [x] 浏览 ${link(docHandbook)}\n'
              '- [ ] 加入 Slack 的 `#product-digest` 与 `#support-triage`\n\n'
              '## 第 2 – 3 天\n\n'
              '- [ ] 手动触发 `$wfDigestName`，读它停在审批处的草稿\n'
              '- [ ] 打开 `$skillGithubDigest` skill，读 `templates/digest.md`\n'
              '- [ ] 看一次 `$wfTriageName` 运行如何路由真实工单\n\n'
              '## 第 4 – 5 天\n\n'
              '- [ ] 和 ${link(docReleaseProcess)} 的负责人一起做一次发布\n'
              '- [ ] 在这本手册里补上一段你需要时没找到的内容\n\n'
              '## 你需要的账号\n\n'
              '```text\n'
              'github     org: Cookiezisg     role: member\n'
              'slack      channels: #product-digest #support-triage\n'
              'zendesk    role: agent (read + comment)\n'
              '```',
        ),
      ),
      doc(
        id: docReleaseProcess,
        parent: docHandbook,
        name: releaseProcess,
        position: 1,
        path: '/$handbook/$releaseProcess',
        description: l.t(
          'Tag, build, smoke-run, announce — the Friday ritual.',
          '打标签、构建、冒烟、公告——周五的固定动作。',
        ),
        tags: const ['handbook', 'release'],
        createdAt: ago(days: 75),
        updatedAt: ago(days: 2, hours: 20),
        content: l.t(
          'A release is four steps in a fixed order. The `$wfReleaseName` workflow runs the middle two; '
              'humans own the first and the last.\n\n'
              '## 1. Cut\n\n'
              '```bash\n'
              'git switch main && git pull\n'
              'git tag v0.2.0\n'
              'git push origin v0.2.0   # fires $wfReleaseName\n'
              '```\n\n'
              '## 2. Build & smoke (automated)\n\n'
              '| Node | What it proves |\n'
              '| --- | --- |\n'
              '| `build_sidecar` | the Go binary cross-compiles for all three platforms |\n'
              '| `smoke_run` | a fresh install completes the digest workflow end to end |\n'
              '| `resume_check` | killing the backend mid-run resumes, never restarts |\n\n'
              '## 3. Release notes\n\n'
              '`$agReleaseNotesName` drafts them from the merged PRs; edit for tone, never for facts.\n\n'
              '## 4. Announce\n\n'
              '- Post in `#product-digest` via `$hdSlackName`\n'
              '- Update the ${link(docLaunchPlan)} milestone table\n\n'
              '> The resume check is the whole point: durability is a release gate, not a feature flag.',
          '一次发布是固定顺序的四步。`$wfReleaseName` 工作流跑中间两步，人负责第一步和最后一步。\n\n'
              '## 1. 切版本\n\n'
              '```bash\n'
              'git switch main && git pull\n'
              'git tag v0.2.0\n'
              'git push origin v0.2.0   # 触发 $wfReleaseName\n'
              '```\n\n'
              '## 2. 构建与冒烟（自动）\n\n'
              '| 节点 | 证明什么 |\n'
              '| --- | --- |\n'
              '| `build_sidecar` | Go 二进制能交叉编译到三个平台 |\n'
              '| `smoke_run` | 全新安装能端到端跑完周报工作流 |\n'
              '| `resume_check` | 运行中杀掉后端会恢复，而不是重来 |\n\n'
              '## 3. 版本说明\n\n'
              '由 `$agReleaseNotesName` 从已合并 PR 起草；只改语气，不改事实。\n\n'
              '## 4. 公告\n\n'
              '- 经 `$hdSlackName` 发到 `#product-digest`\n'
              '- 更新 ${link(docLaunchPlan)} 里的里程碑表\n\n'
              '> 恢复检查才是重点：持久性是发布门槛，不是功能开关。',
        ),
      ),
      // ── Weekly digests (root folder) ─────────────────────────────────────
      doc(
        id: docDigestsFolder,
        parent: null,
        name: digestsFolder,
        position: 1,
        path: '/$digestsFolder',
        description: l.t(
          'Every digest the weekly_github_digest workflow has published.',
          'weekly_github_digest 工作流发布过的每一期周报。',
        ),
        tags: const ['github', 'weekly-digest'],
        createdAt: ago(days: 45),
        updatedAt: ago(hours: 5),
        content: l.t(
          'One page per fortnight, written by `$agDigestName` and approved by a human before it lands '
              'here. Newest first.\n\n'
              '- ${link(docDigestLatest)} — awaiting review\n'
              '- ${link(docDigestPrev)} — published',
          '每两周一页，由 `$agDigestName` 撰写、人工审批后才落到这里。最新在前。\n\n'
              '- ${link(docDigestLatest)} — 等待审批\n'
              '- ${link(docDigestPrev)} — 已发布',
        ),
      ),
      doc(
        id: docDigestLatest,
        parent: docDigestsFolder,
        name: digestLatest,
        position: 0,
        path: '/$digestsFolder/$digestLatest',
        description: l.t(
          'Generated by weekly_github_digest; waiting for review before it is published.',
          '由 weekly_github_digest 生成，发布前等待审批。',
        ),
        tags: const ['github', 'weekly-digest', 'draft'],
        createdAt: ago(hours: 5, minutes: 12),
        updatedAt: ago(hours: 5, minutes: 12),
        // digestMarkdown() is the SAME body the approval card shows; the categories table and the
        // sparkline are the extra sections a written-up digest carries. The sparkline is a code block
        // rather than `![](anselm://media/<id>)` because the demo has no MediaSource override — a media
        // reference would hit the live API client and render as a broken card.
        // digestMarkdown() 与审批卡同一正文；分类表与走势是完整周报多出来的节。走势用代码块而不用
        // `![](anselm://media/<id>)`：demo 没有 MediaSource 覆写，媒体引用会打真 API 渲成破卡。
        content:
            '${digestMarkdown(l).trimRight()}\n\n'
            '${l.t('## Commits by category\n\n'
                '| Category | Commits |\n'
                '| --- | --- |\n'
                '| Acceptance testing | 19 |\n'
                '| Fixes | 7 |\n'
                '| Documentation | 4 |\n'
                '| Chores | 2 |\n\n'
                '## Two-week trend\n\n'
                '```text\n'
                'commits/day  Aug 30 ─────────────────────── Sep 13\n'
                '     6 │                 █\n'
                '     4 │     █     █     █  █        █\n'
                '     2 │  █  █  █  █  █  █  █  █  █  █  █\n'
                '     0 └──────────────────────────────────\n'
                '```', '## 按类别统计提交\n\n'
                '| 类别 | 提交数 |\n'
                '| --- | --- |\n'
                '| 验收测试 | 19 |\n'
                '| 缺陷修复 | 7 |\n'
                '| 文档 | 4 |\n'
                '| 杂务 | 2 |\n\n'
                '## 两周走势\n\n'
                '```text\n'
                '每日提交  08-30 ─────────────────────── 09-13\n'
                '     6 │                 █\n'
                '     4 │     █     █     █  █        █\n'
                '     2 │  █  █  █  █  █  █  █  █  █  █  █\n'
                '     0 └──────────────────────────────────\n'
                '```')}',
      ),
      doc(
        id: docDigestPrev,
        parent: docDigestsFolder,
        name: digestPrev,
        position: 1,
        path: '/$digestsFolder/$digestPrev',
        description: l.t(
          'Published to #product-digest on Aug 31.',
          '8 月 31 日已发布到 #product-digest。',
        ),
        tags: const ['github', 'weekly-digest'],
        createdAt: ago(days: 14, hours: 5),
        updatedAt: ago(days: 13, hours: 22),
        content: l.t(
          '**Reporting period:** August 16 – August 29, 2026\n\n'
              '## Summary\n\n'
              'The fortnight went to multimodal durable execution: image and audio attachments now survive '
              'a crash mid-workflow, and the approval gate learned to show them inline.\n\n'
              '- Commits: 27\n'
              '- Merged pull requests: 3\n'
              '- Opened issues: 2\n'
              '- Closed issues: 4\n\n'
              '## Commits (27)\n\n'
              '### Durable execution\n\n'
              '- `74e2b209` feat(backend): harden multimodal durable execution ($authorName)\n'
              '- `9c41d0e2` feat(backend): memoize attachment refs in flowrun_nodes ($authorName)\n\n'
              '### Frontend\n\n'
              '- `d8fd932e` fix(frontend): preserve chat execution feedback ($authorName)\n'
              '- `2b7f6a10` feat(frontend): approval card renders media refs ($authorName)\n\n'
              '## Commits by category\n\n'
              '| Category | Commits |\n'
              '| --- | --- |\n'
              '| Features | 14 |\n'
              '| Fixes | 6 |\n'
              '| Tests | 5 |\n'
              '| Documentation | 2 |\n\n'
              '## Highlights\n\n'
              '- Zero regressions in the acceptance matrix after the multimodal change.\n'
              '- The digest workflow itself ran unattended for the first time.',
          '**统计区间：** 2026-08-16 ~ 2026-08-29\n\n'
              '## 概览\n\n'
              '这两周的重点是多模态持久执行：图片与音频附件在工作流中途崩溃后也能保留，审批门学会了内联展示它们。\n\n'
              '- 提交：27 次\n'
              '- 已合并 PR：3 个\n'
              '- 新开 Issue：2 个\n'
              '- 已关闭 Issue：4 个\n\n'
              '## 提交（27 次）\n\n'
              '### 持久执行\n\n'
              '- `74e2b209` 加固多模态持久执行（$authorName）\n'
              '- `9c41d0e2` 在 flowrun_nodes 中记忆化附件引用（$authorName）\n\n'
              '### 前端\n\n'
              '- `d8fd932e` 保留对话执行反馈（$authorName）\n'
              '- `2b7f6a10` 审批卡渲染媒体引用（$authorName）\n\n'
              '## 按类别统计提交\n\n'
              '| 类别 | 提交数 |\n'
              '| --- | --- |\n'
              '| 功能 | 14 |\n'
              '| 缺陷修复 | 6 |\n'
              '| 测试 | 5 |\n'
              '| 文档 | 2 |\n\n'
              '## 亮点\n\n'
              '- 多模态改动后验收矩阵零回归。\n'
              '- 周报工作流第一次无人值守跑完。',
        ),
      ),
      // ── Support playbook (root) ──────────────────────────────────────────
      doc(
        id: docSupportPlaybook,
        parent: null,
        name: supportPlaybook,
        position: 2,
        path: '/$supportPlaybook',
        description: l.t(
          'How tickets are routed by severity and what a human still has to do.',
          '工单如何按严重度路由，以及人仍然要做什么。',
        ),
        tags: const ['support', 'playbook'],
        createdAt: ago(days: 60),
        updatedAt: ago(days: 1, hours: 4),
        content: l.t(
          'Every Zendesk ticket enters `$wfTriageName` through `$trgZendeskName`. The agent '
              '`$agTriageName` classifies it and `$ctlSeverityName` routes it; this page is what happens '
              'after the routing.\n\n'
              '## Severity ladder\n\n'
              '| Severity | Route | Human SLA |\n'
              '| --- | --- | --- |\n'
              '| critical | page on-call via `$hdSlackName` | 30 min |\n'
              '| high | `#support-triage` thread | 4 h |\n'
              '| normal | weekly review | 5 days |\n'
              '| low | backlog label | none |\n\n'
              '## When a ticket asks for money back\n\n'
              'Refunds never leave the workflow without `$apfRefundName`. The reviewer checks:\n\n'
              '- [ ] the order exists in Postgres (`$hdPostgresName`)\n'
              '- [ ] the amount matches the invoice parsed by `$fnParseInvoiceName`\n'
              '- [ ] the customer has not been refunded for the same order before\n'
              '- [x] the reply template below is used verbatim\n\n'
              '## Reply template\n\n'
              '```text\n'
              'Hi {{customer.first_name}},\n\n'
              'Thanks for flagging order {{order.id}}. We have issued a refund of\n'
              '{{refund.amount}} {{refund.currency}}; it reaches your card in 3–5 business days.\n\n'
              '— {{agent.name}}, Product Team\n'
              '```\n\n'
              '## Escalation query\n\n'
              '```sql\n'
              'SELECT id, customer_id, total_cents\n'
              '  FROM orders\n'
              ' WHERE id = \$1 AND refunded_at IS NULL;\n'
              '```\n\n'
              '> Never resolve a `critical` ticket from the workflow alone — a human closes it.',
          '每张 Zendesk 工单经 `$trgZendeskName` 进入 `$wfTriageName`。`$agTriageName` 负责分类，'
              '`$ctlSeverityName` 负责路由；本页讲的是路由之后的事。\n\n'
              '## 严重度阶梯\n\n'
              '| 严重度 | 路由 | 人工 SLA |\n'
              '| --- | --- | --- |\n'
              '| critical | 经 `$hdSlackName` 呼叫值班 | 30 分钟 |\n'
              '| high | `#support-triage` 线程 | 4 小时 |\n'
              '| normal | 每周复盘 | 5 天 |\n'
              '| low | backlog 标签 | 无 |\n\n'
              '## 当工单要求退款\n\n'
              '退款永远不会绕过 `$apfRefundName` 离开工作流。审批人核对：\n\n'
              '- [ ] 订单在 Postgres 里存在（`$hdPostgresName`）\n'
              '- [ ] 金额与 `$fnParseInvoiceName` 解析出的发票一致\n'
              '- [ ] 该客户同一订单此前未退过款\n'
              '- [x] 逐字使用下方回复模板\n\n'
              '## 回复模板\n\n'
              '```text\n'
              'Hi {{customer.first_name}},\n\n'
              'Thanks for flagging order {{order.id}}. We have issued a refund of\n'
              '{{refund.amount}} {{refund.currency}}; it reaches your card in 3–5 business days.\n\n'
              '— {{agent.name}}, Product Team\n'
              '```\n\n'
              '## 升级查询\n\n'
              '```sql\n'
              'SELECT id, customer_id, total_cents\n'
              '  FROM orders\n'
              ' WHERE id = \$1 AND refunded_at IS NULL;\n'
              '```\n\n'
              '> `critical` 工单永远不要只靠工作流关闭——由人来收尾。',
        ),
      ),
      // ── Launch plan (root) ───────────────────────────────────────────────
      doc(
        id: docLaunchPlan,
        parent: null,
        name: launchPlan,
        position: 3,
        path: '/$launchPlan',
        description: l.t(
          'Milestones and owners for the 0.2 public launch.',
          '0.2 公开发布的里程碑与负责人。',
        ),
        tags: const ['launch', 'release', 'planning'],
        createdAt: ago(days: 21),
        updatedAt: ago(hours: 26),
        content: l.t(
          'We ship 0.2 on the Friday after the next digest. The release itself follows '
              '${link(docReleaseProcess)}; the evidence that we are ready is the digest in '
              '${link(docDigestLatest)}.\n\n'
              '## Milestones\n\n'
              '| Milestone | Owner | Due | Status |\n'
              '| --- | --- | --- | --- |\n'
              '| Acceptance matrix sealed (batch 90) | $authorName | Sep 13 | done |\n'
              '| Launch page hero images resized | Jonas | Sep 15 | in progress |\n'
              '| 0.2 release notes drafted | `$agReleaseNotesName` | Sep 17 | queued |\n'
              '| Tag v0.2.0 | $authorName | Sep 18 | — |\n\n'
              '## Open questions\n\n'
              '1. Do we announce the managed API on the same day, or a week later?\n'
              '2. Does `$fnResizeImageName` need a WebP output before the hero images go live?\n\n'
              '## Rollback\n\n'
              '- Re-tag the previous build; the workflow is idempotent so a second `:trigger` is safe\n'
              '- Post the rollback note through `$hdSlackName`\n\n'
              '> Nothing on this page is a promise until the digest says the matrix is green.',
          '0.2 在下一期周报之后的周五上线。发布本身遵循 ${link(docReleaseProcess)}；我们准备好了的证据'
              '是 ${link(docDigestLatest)} 里的周报。\n\n'
              '## 里程碑\n\n'
              '| 里程碑 | 负责人 | 截止 | 状态 |\n'
              '| --- | --- | --- | --- |\n'
              '| 验收矩阵封存（batch 90） | $authorName | 09-13 | 完成 |\n'
              '| 发布页首屏图片压缩 | Jonas | 09-15 | 进行中 |\n'
              '| 0.2 版本说明起草 | `$agReleaseNotesName` | 09-17 | 排队中 |\n'
              '| 打标签 v0.2.0 | $authorName | 09-18 | — |\n\n'
              '## 待定问题\n\n'
              '1. 受管 API 当天一起公告，还是推迟一周？\n'
              '2. 首屏图片上线前 `$fnResizeImageName` 是否需要 WebP 输出？\n\n'
              '## 回滚\n\n'
              '- 重新打上一版标签；工作流幂等，再来一次 `:trigger` 是安全的\n'
              '- 经 `$hdSlackName` 发回滚通知\n\n'
              '> 在周报说矩阵全绿之前，本页没有一条是承诺。',
        ),
      ),
    ],
    skills: [
      Skill(
        name: skillGithubDigest,
        description: l.t(
          'Turns a fortnight of GitHub activity into a reviewed weekly digest.',
          '把两周的 GitHub 活动整理成经审批的周报。',
        ),
        source: kSkillSourceUser,
        context: kSkillContextFork,
        updatedAt: ago(days: 3, hours: 7),
        body: l.t(
          'Write the fortnightly digest for `Cookiezisg/Anselm` from the activity payload produced by '
              '`$fnFetchGithubName`. The output is markdown that a human reviews at `$apfDigestName` before '
              'it is published, so accuracy matters more than polish.\n\n'
              '## When to use\n\n'
              '- The `$wfDigestName` workflow reaches its `$agDigestName` node\n'
              '- A teammate asks for "what happened in the repo since <date>"\n'
              '- A rejected digest comes back with reviewer notes to fold in\n\n'
              '## Steps\n\n'
              '1. Run `scripts/fetch.py` (or accept the payload the workflow already fetched)\n'
              '2. Group commits by conventional-commit type; merge tiny chores into one line\n'
              '3. Fill `templates/digest.md` — every section, even when the count is zero\n'
              '4. Add a "Commits by category" table and a two-week trend block\n'
              '5. Hand the markdown to `$fnPrepareDocName` so it lands in the Weekly digests folder\n\n'
              '## Rules\n\n'
              '- Quote commit hashes exactly; never paraphrase a subject line\n'
              '- Attribute every line to its author\n'
              '- Highlights are for outcomes, not for volume\n\n'
              '> A digest nobody trusts is worse than no digest.',
          '根据 `$fnFetchGithubName` 产出的活动数据，为 `Cookiezisg/Anselm` 撰写两周一期的周报。产物是'
              '一份 markdown，在 `$apfDigestName` 由人审批后才发布，所以准确比漂亮重要。\n\n'
              '## 何时使用\n\n'
              '- `$wfDigestName` 工作流运行到 `$agDigestName` 节点\n'
              '- 同事问「自 <日期> 以来仓库发生了什么」\n'
              '- 被驳回的周报带着审批意见回来需要修改\n\n'
              '## 步骤\n\n'
              '1. 运行 `scripts/fetch.py`（或直接使用工作流已经取到的数据）\n'
              '2. 按 conventional-commit 类型分组提交；把零碎杂务合并成一行\n'
              '3. 填写 `templates/digest.md`——每一节都要填，即使数量为零\n'
              '4. 加上「按类别统计提交」表和两周走势块\n'
              '5. 把 markdown 交给 `$fnPrepareDocName`，让它落到「每周周报」文件夹\n\n'
              '## 规则\n\n'
              '- 提交哈希原样引用；不要改写 subject 行\n'
              '- 每一行都注明作者\n'
              '- 亮点写结果，不写数量\n\n'
              '> 没人信的周报比没有周报更糟。',
        ),
        frontmatter: Frontmatter(
          name: skillGithubDigest,
          description: l.t(
            'Turns a fortnight of GitHub activity into a reviewed weekly digest.',
            '把两周的 GitHub 活动整理成经审批的周报。',
          ),
          // Entity ids in allowedTools are what the fixture's listSkillBindings turns into equip
          // relations, so the skill page shows the two functions it drives.
          // allowedTools 里的实体 id 会被 fixture 的 listSkillBindings 变成 equip 关系，skill 页才显示它驱动的两个函数。
          allowedTools: const [
            fnFetchGithub,
            fnPrepareDoc,
            'Read',
            'Bash(python:*)',
          ],
          context: kSkillContextFork,
          agent: agDigestName,
          userInvocable: true,
          source: kSkillSourceUser,
        ),
      ),
      Skill(
        name: skillInvoiceParsing,
        description: l.t(
          'Extracts structured fields from supplier invoice PDFs.',
          '从供应商发票 PDF 中提取结构化字段。',
        ),
        source: kSkillSourceUser,
        context: kSkillContextInline,
        updatedAt: ago(days: 9, hours: 2),
        body: l.t(
          'Read a supplier invoice PDF and return the fields listed in `reference/fields.md` as JSON. '
              'Used by the `$wfInvoiceName` workflow after `$trgInvoicesName` sees a new file.\n\n'
              '## When to use\n\n'
              '- A new PDF lands in the invoices folder\n'
              '- A support ticket disputes an amount and the reviewer needs the parsed invoice\n\n'
              '## Steps\n\n'
              '1. Call `$fnParseInvoiceName` for the raw text and layout boxes\n'
              '2. Map each field from `reference/fields.md`; leave a field `null` rather than guessing\n'
              '3. Validate that line items sum to the total within one cent\n'
              '4. Return the JSON object — no prose around it\n\n'
              '## Output shape\n\n'
              '```json\n'
              '{\n'
              '  "supplier": "Acme Cloud GmbH",\n'
              '  "invoice_number": "INV-2026-0912",\n'
              '  "issued_on": "2026-09-12",\n'
              '  "currency": "EUR",\n'
              '  "total_cents": 128400,\n'
              '  "line_items": [{ "description": "Object storage", "cents": 128400 }]\n'
              '}\n'
              '```\n\n'
              '> A wrong number is worse than a missing one; the reviewer can fill a blank.',
          '读取供应商发票 PDF，按 `reference/fields.md` 列出的字段返回 JSON。由 `$wfInvoiceName` 工作流'
              '在 `$trgInvoicesName` 发现新文件后调用。\n\n'
              '## 何时使用\n\n'
              '- 发票文件夹里出现新的 PDF\n'
              '- 客服工单对金额有争议，审批人需要解析后的发票\n\n'
              '## 步骤\n\n'
              '1. 调用 `$fnParseInvoiceName` 获取原始文本与版面框\n'
              '2. 按 `reference/fields.md` 逐字段映射；宁可留 `null` 也不要猜\n'
              '3. 校验明细合计与总额误差在一分钱以内\n'
              '4. 只返回 JSON 对象——周围不要有任何文字\n\n'
              '## 输出形状\n\n'
              '```json\n'
              '{\n'
              '  "supplier": "Acme Cloud GmbH",\n'
              '  "invoice_number": "INV-2026-0912",\n'
              '  "issued_on": "2026-09-12",\n'
              '  "currency": "EUR",\n'
              '  "total_cents": 128400,\n'
              '  "line_items": [{ "description": "Object storage", "cents": 128400 }]\n'
              '}\n'
              '```\n\n'
              '> 错的数字比缺的数字更糟；空白审批人可以补。',
        ),
        frontmatter: Frontmatter(
          name: skillInvoiceParsing,
          description: l.t(
            'Extracts structured fields from supplier invoice PDFs.',
            '从供应商发票 PDF 中提取结构化字段。',
          ),
          allowedTools: const [fnParseInvoice, 'Read'],
          context: kSkillContextInline,
          source: kSkillSourceUser,
        ),
      ),
    ],
    skillFiles: {
      skillGithubDigest: {
        'scripts/fetch.py':
            '"""Fetch two weeks of GitHub activity for the digest skill."""\n'
            'import json\n'
            'import os\n'
            'import sys\n'
            'from datetime import datetime, timedelta, timezone\n'
            'from urllib.request import Request, urlopen\n'
            '\n'
            'REPO = "Cookiezisg/Anselm"\n'
            'API = f"https://api.github.com/repos/{REPO}"\n'
            '\n'
            '\n'
            'def get(path: str) -> list[dict]:\n'
            '    req = Request(API + path, headers={"Authorization": f"Bearer {os.environ[\'GITHUB_TOKEN\']}"})\n'
            '    with urlopen(req) as resp:\n'
            '        return json.load(resp)\n'
            '\n'
            '\n'
            'def main() -> None:\n'
            '    since = (datetime.now(timezone.utc) - timedelta(days=14)).isoformat()\n'
            '    payload = {\n'
            '        "commits": get(f"/commits?since={since}&per_page=100"),\n'
            '        "pulls": get("/pulls?state=closed&sort=updated&direction=desc&per_page=50"),\n'
            '        "issues": get(f"/issues?state=all&since={since}&per_page=100"),\n'
            '    }\n'
            '    json.dump(payload, sys.stdout)\n'
            '\n'
            '\n'
            'if __name__ == "__main__":\n'
            '    main()\n',
        'templates/digest.md':
            '# Weekly Digest: {{repo}}\n'
            '\n'
            '**Reporting period:** {{period.start}} – {{period.end}}\n'
            '\n'
            '## Summary\n'
            '\n'
            '{{summary}}\n'
            '\n'
            '- Commits: {{counts.commits}}\n'
            '- Merged pull requests: {{counts.merged}}\n'
            '- Opened issues: {{counts.opened}}\n'
            '- Closed issues: {{counts.closed}}\n'
            '\n'
            '## Commits ({{counts.commits}})\n'
            '\n'
            '{{#each groups}}\n'
            '### {{title}}\n'
            '\n'
            '{{#each commits}}\n'
            '- `{{sha}}` {{subject}} ({{author}})\n'
            '{{/each}}\n'
            '\n'
            '{{/each}}\n'
            '## Commits by category\n'
            '\n'
            '| Category | Commits |\n'
            '| --- | --- |\n'
            '{{#each groups}}\n'
            '| {{title}} | {{count}} |\n'
            '{{/each}}\n'
            '\n'
            '## Highlights\n'
            '\n'
            '{{#each highlights}}\n'
            '- {{this}}\n'
            '{{/each}}\n',
      },
      skillInvoiceParsing: {
        'reference/fields.md':
            '# Invoice fields\n'
            '\n'
            'Every field is required in the output object; use `null` when the invoice does not carry it.\n'
            '\n'
            '| Field | Type | Where it usually is |\n'
            '| --- | --- | --- |\n'
            '| supplier | string | letterhead, first 10 lines |\n'
            '| invoice_number | string | "Invoice", "Rechnung", "发票号" |\n'
            '| issued_on | ISO date | next to the invoice number |\n'
            '| due_on | ISO date | "Due", "Fällig", "到期" |\n'
            '| currency | ISO 4217 | symbol or code near the total |\n'
            '| total_cents | integer | last bold amount on the page |\n'
            '| tax_cents | integer | "VAT", "MwSt", "税额" |\n'
            '| line_items[] | array | table between header and totals |\n'
            '\n'
            '## Normalisation\n'
            '\n'
            '- Amounts become integer cents; `1.284,00` and `1,284.00` both parse to `128400`\n'
            '- Dates become `YYYY-MM-DD` regardless of the locale printed\n'
            '- Supplier names keep their legal suffix (`GmbH`, `Ltd`, `有限公司`)\n',
      },
    },
  );
}
