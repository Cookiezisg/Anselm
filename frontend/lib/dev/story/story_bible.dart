/// The story story bible — ONE team workspace whose entities, conversations, runs, documents and
/// notifications all refer to each other. Every story fixture file imports these constants so the six
/// product surfaces tell the same story (the same ids show up in chat tool cards, the entity rail, the
/// scheduler matrix, the notification ledger and document backlinks).
///
/// story 故事总纲——一个团队 workspace，实体、对话、运行、文档、通知互相引用。六个 story fixture
/// 文件都从这里取常量，六个产品面才讲同一个故事（同一 id 出现在 chat 工具卡、实体 rail、调度矩阵、
/// 通知账本和文档反链里）。
library;

import 'story_locale.dart';

/// Time anchor: the story is captured on a Sunday evening; the weekly cron fires "in 11h".
/// 时间锚：故事截图发生在周日傍晚，每周 cron “11 小时后”触发。
final DateTime storyNow = DateTime.now();

/// Absolute-looking timestamps relative to [storyNow]. 相对锚点的时间。
DateTime ago({int days = 0, int hours = 0, int minutes = 0, int seconds = 0}) =>
    storyNow.subtract(
      Duration(days: days, hours: hours, minutes: minutes, seconds: seconds),
    );

DateTime ahead({int days = 0, int hours = 0, int minutes = 0}) =>
    storyNow.add(Duration(days: days, hours: hours, minutes: minutes));

// ───────────────────────── Workspace ─────────────────────────

const storyWorkspaceId = 'ws_0c62276564be7acb';
String storyWorkspaceName(StoryLocale l) => l.t('Product Team', '产品团队');

// ───────────────────────── Residencies (workDir) ─────────────────────────

const storyRepoDir = '/Users/you/code/anselm';
const storySiteDir = '/Users/you/design/launch-site';
const storyGoneDir = '/Users/you/code/old-prototype';

// ───────────────────────── Functions ─────────────────────────

const fnFetchGithub = 'fn_e70af68c82e57057';
const fnPrepareDoc = 'fn_d1f363c0815d05fd';
const fnParseInvoice = 'fn_7b1e9c2a4d5f8e30';
const fnResizeImage = 'fn_3c9a5d7e1f2b4a68';

const fnFetchGithubName = 'fetch_github_activity';
const fnPrepareDocName = 'prepare_document_payload';
const fnParseInvoiceName = 'parse_invoice_pdf';
const fnResizeImageName = 'resize_image';

// ───────────────────────── Handlers ─────────────────────────

const hdSlack = 'hd_9f2c4e6a8b1d3f57';
const hdPostgres = 'hd_2a8d6f4c1e3b5079';

const hdSlackName = 'slack_notifier';
const hdPostgresName = 'postgres_reader';

// ───────────────────────── Agents ─────────────────────────

const agDigest = 'ag_682d5adb0293d008';
const agTriage = 'ag_4b7e1c9d2f6a8305';
const agReleaseNotes = 'ag_8e3f5a1b7c9d2461';

const agDigestName = 'write_weekly_digest';
const agTriageName = 'triage_support_ticket';
const agReleaseNotesName = 'release_notes_writer';

// ───────────────────────── Controls / Approvals / Triggers ─────────────────────────

const ctlSeverity = 'ctl_5d1f8a3c9e2b7604';
const ctlSeverityName = 'route_by_severity';

const apfDigest = 'apf_9c3d8a5d6a33754c';
const apfRefund = 'apf_1e6b4d8f2a9c3507';
const apfDigestName = 'review_weekly_digest';
const apfRefundName = 'confirm_refund';

const trgMonday = 'trg_f0cd99cfb02d0236';
const trgZendesk = 'trg_6a2c8e4f1d9b3705';
const trgInvoices = 'trg_9b5d3f7a2c1e8406';
const trgUptime = 'trg_2f8a6c4e9d1b7350';
const trgMondayName = 'weekly_monday_0900';
const trgZendeskName = 'zendesk_ticket_webhook';
const trgInvoicesName = 'invoices_folder_watch';
const trgUptimeName = 'uptime_sensor';

// ───────────────────────── Workflows ─────────────────────────

const wfDigest = 'wf_3ddd9a541261ef18';
const wfTriage = 'wf_7c2e9a4b1d6f8503';
const wfInvoice = 'wf_4a8c1e6d3b9f2705';
const wfRelease = 'wf_1d9f3b7a5c2e8604';

const wfDigestName = 'weekly_github_digest';
const wfTriageName = 'support_ticket_triage';
const wfInvoiceName = 'invoice_intake';
const wfReleaseName = 'release_pipeline';

/// Flowruns referenced across surfaces (chat tool cards, scheduler, notifications).
/// 跨面引用的 run。
const frDigestParked = 'fr_f64af2892fa95eb9'; // waiting at review, days=14 等审批
const frDigestRejected = 'fr_0e2368ae1a944c65'; // completed, review=no 已驳回
const frDigestFailed = 'fr_61a8e2bc23a6bcbb'; // failed at fetch, replayed 已重放
const frTriageRunning = 'fr_8b3d5f1a7c9e2406'; // running agent node 进行中
const frTriageDone1 = 'fr_5c1e7a3b9d2f8604';
const frTriageDone2 = 'fr_2e9a4c6b1f8d3705';
const frInvoiceFailed = 'fr_6d4b2f8a3c1e9507'; // failed parse 解析失败
const frInvoiceDone = 'fr_3f7c9e1b5a2d8604';
const frReleaseDone = 'fr_9a1c3e5b7d2f4608';

// ───────────────────────── Conversations ─────────────────────────

const cvDigest =
    'cv_a755c1e4f42e5ba7'; // pinned · the main build transcript 主对话
const cvTriage = 'cv_3b8d1f6a9c2e4705'; // generating 生成中
const cvRefund = 'cv_7e2a9c4d1b6f8305'; // awaiting input 等回答
const cvHeroImages = 'cv_1c9e5b3a7d2f4806'; // attachments · workDir launch-site
const cvFlakyTest = 'cv_5a3c7e9b1d4f2608'; // failed · workDir anselm
const cvReleaseNotes =
    'cv_8d2f4a6c9e1b3507'; // queued follow-ups · workDir anselm
const cvOldPrototype = 'cv_4f6b8d2a1c9e3705'; // workDir gone 驻地失效
const cvExplainDurable = 'cv_2a6c8e4b9d1f3507'; // unread 未读

String cvDigestTitle(StoryLocale l) =>
    l.t('Weekly GitHub digest workflow', '每周 GitHub 周报工作流');
String cvTriageTitle(StoryLocale l) =>
    l.t('Triage overnight support tickets', '处理昨晚的客服工单');
String cvRefundTitle(StoryLocale l) =>
    l.t('Refund request #4821', '退款申请 #4821');
String cvHeroImagesTitle(StoryLocale l) =>
    l.t('Resize hero images for the launch page', '压缩发布页首屏图片');
String cvFlakyTestTitle(StoryLocale l) =>
    l.t('Fix the flaky invoice parser test', '修复不稳定的发票解析测试');
String cvReleaseNotesTitle(StoryLocale l) =>
    l.t('Draft the 0.2 release notes', '起草 0.2 版本说明');
String cvOldPrototypeTitle(StoryLocale l) =>
    l.t('Migrate the old prototype', '迁移旧原型');
String cvExplainDurableTitle(StoryLocale l) =>
    l.t('Explain durable execution to a new teammate', '给新同事讲讲持久执行');

// ───────────────────────── Documents & skills ─────────────────────────

const docHandbook = 'doc_1a2b3c4d5e6f7081';
const docOnboarding = 'doc_2b3c4d5e6f708192';
const docReleaseProcess = 'doc_3c4d5e6f70819203';
const docDigestsFolder = 'doc_4d5e6f7081920314';
const docDigestLatest = 'doc_fae9df7214e53a30'; // the open page 打开的那篇
const docDigestPrev = 'doc_5e6f708192031425';
const docSupportPlaybook = 'doc_6f70819203142536';
const docLaunchPlan = 'doc_7081920314253647';

String docHandbookTitle(StoryLocale l) => l.t('Team Handbook', '团队手册');
String docOnboardingTitle(StoryLocale l) => l.t('Onboarding', '新人入职');
String docReleaseProcessTitle(StoryLocale l) => l.t('Release process', '发布流程');
String docDigestsFolderTitle(StoryLocale l) => l.t('Weekly digests', '每周周报');
String docDigestLatestTitle(StoryLocale l) => l.t(
  'Weekly Digest · Aug 30 – Sep 13, 2026',
  'GitHub 周报 · 2026-08-30 ~ 09-13',
);
String docDigestPrevTitle(StoryLocale l) => l.t(
  'Weekly Digest · Aug 16 – Aug 29, 2026',
  'GitHub 周报 · 2026-08-16 ~ 08-29',
);
String docSupportPlaybookTitle(StoryLocale l) =>
    l.t('Support playbook', '客服手册');
String docLaunchPlanTitle(StoryLocale l) => l.t('Launch plan', '发布计划');

const skillGithubDigest = 'github-digest';
const skillInvoiceParsing = 'invoice-parsing';

// ───────────────────────── People ─────────────────────────

const authorName = 'Sun Weilin';

/// The digest body both the Library page and the approval card show. 周报正文（资料库与审批卡共用）。
String digestMarkdown(StoryLocale l) => l.zh
    ? '''
# Cookiezisg/Anselm 周报（2026-08-30 ~ 2026-09-13）

## 概览

本周团队主要聚焦于验收测试的密集闭环与系统前沿状态的同步。Sun Weilin 完成了 batch 84 至 batch 90 的大量测试封存与门控验证，并修复了若干 UI 和通知相关的缺陷。

- 提交：32 次
- 已合并 PR：0 个
- 新开 Issue：0 个
- 已关闭 Issue：0 个

## 提交（32 次）

### 验收测试与批次闭环

- `33facdd` 关闭剩余自主前沿测试（Sun Weilin）
- `06e6dbb` 关闭 edge296 和 batch90 门控（Sun Weilin）
- `1e9b4d4` 关闭自主前沿并修复重复工具终端（Sun Weilin）
- `23a40bf` 封存当前应用和 rig 工作（Sun Weilin）
- `63cc92f` 关闭 batch 89 并封存 fork 谱系（Sun Weilin）
- `fabce11` 关闭 batch 88 并修复 demo 执行括号（Sun Weilin）

### 缺陷修复

- `e109a37` 排序轴变化时重置 rail 视口（Sun Weilin）
- `db98b6f` 让分支恢复提示保持可读（Sun Weilin）

## 亮点

- 验收矩阵从 batch 84 推进到 batch 90，未发现回归。
- 分支与工作目录相关的用户体验缺陷已在本周内修复。
'''
    : '''
# Weekly Digest: Cookiezisg/Anselm

**Reporting period:** August 30 – September 13, 2026

## Summary

This period focused on closing the acceptance-testing loop and syncing the system frontier. Sun Weilin sealed batches 84 through 90, verified the gates, and fixed a handful of UI and notification defects.

- Commits: 32
- Merged pull requests: 0
- Opened issues: 0
- Closed issues: 0

## Commits (32)

### Acceptance testing and batch closure

- `33facdd` test(acceptance): close remaining autonomous frontier (Sun Weilin)
- `06e6dbb` test(acceptance): close edge296 and batch90 gate (Sun Weilin)
- `1e9b4d4` test(acceptance): close autonomous frontier and fix duplicate tool terminal (Sun Weilin)
- `23a40bf` chore(acceptance): seal current app and rig work (Sun Weilin)
- `63cc92f` test(acceptance): close batch 89 and seal fork lineage (Sun Weilin)
- `fabce11` test(acceptance): close batch 88 and repair demo execution bracket (Sun Weilin)

### Fixes

- `e109a37` fix(acceptance): reset rail viewport when sort axis changes (Sun Weilin)
- `db98b6f` fix(acceptance): keep branch recovery notice readable (Sun Weilin)

## Highlights

- The acceptance matrix advanced from batch 84 to batch 90 with no regressions.
- Branch and work-directory UX defects were fixed within the week.
''';

// ───────────────────────── weekly_github_digest · canonical graph (v2) ─────────────────────────
//
// Every surface that shows this workflow (chat truth snapshot + Activity stage, entity graph and
// flowrun composites, scheduler matrix / Gantt / dossier) must use exactly these node ids, kinds, refs
// and edges, so the same run reads identically everywhere. Three fetches run in parallel, join at the
// agent, a control routes empty weeks away from review, and a Slack handler closes both branches.
//
// 所有展示这条工作流的面（chat 快照与 Activity 舞台、实体图与 run 详情、调度矩阵/甘特/卷宗）必须使用
// 完全相同的节点 id、kind、ref 和边。三路并行抓取、在 Agent 汇合、控制节点把空周绕过审批、Slack 收尾。
//
//   start           trigger   trgMonday
//   fetch_commits   action    fnFetchGithub   input {kind: "commits",  days: "trigger.days"}
//   fetch_pulls     action    fnFetchGithub   input {kind: "pulls",    days: "trigger.days"}
//   fetch_issues    action    fnFetchGithub   input {kind: "issues",   days: "trigger.days"}
//   write_digest    agent     agDigest        joins the three fetches
//   check_activity  control   ctlEmptyWeek    ports: has_activity | empty
//   review          approval  apfDigest       ports: yes | no
//   prepare_doc     action    fnPrepareDoc
//   notify_team     action    hdSlack (method post_digest)
//   skip_notice     action    hdSlack (method post_message)
//
//   edges: start→fetch_commits, start→fetch_pulls, start→fetch_issues,
//          fetch_commits→write_digest, fetch_pulls→write_digest, fetch_issues→write_digest,
//          write_digest→check_activity, check_activity[has_activity]→review, check_activity[empty]→skip_notice,
//          review[yes]→prepare_doc, prepare_doc→notify_team
//
//   Layout for previews is VERTICAL (top→bottom in the order above, the three fetches side by side).
//   预览图纵向排列（自上而下按上表顺序，三路抓取并排）。

const ctlEmptyWeek = 'ctl_8a2d4f6c1e9b3705';
const ctlEmptyWeekName = 'check_activity';

/// Node ids of the canonical digest graph, in layout order. 规范图的节点 id（布局顺序）。
const digestNodeIds = [
  'start',
  'fetch_commits',
  'fetch_pulls',
  'fetch_issues',
  'write_digest',
  'check_activity',
  'review',
  'prepare_doc',
  'notify_team',
  'skip_notice',
];

/// Per-run node outcomes for the three digest runs (node id → status). 三次 run 的节点终态。
/// frDigestFailed: fetch_commits failed on v1 (GitHub 502 on /commits, no retry yet), the other two fetches completed, nothing else ran.
/// frDigestRejected: all fetches + write + check(has_activity) completed, review decided `no`, rest not run.
/// frDigestParked: all fetches + write + check(has_activity) completed, review parked, rest not run.
const digestRunOutcomes = {
  frDigestFailed: {
    'start': 'completed',
    'fetch_commits': 'failed',
    'fetch_pulls': 'completed',
    'fetch_issues': 'completed',
  },
  frDigestRejected: {
    'start': 'completed',
    'fetch_commits': 'completed',
    'fetch_pulls': 'completed',
    'fetch_issues': 'completed',
    'write_digest': 'completed',
    'check_activity': 'completed',
    'review': 'completed',
  },
  frDigestParked: {
    'start': 'completed',
    'fetch_commits': 'completed',
    'fetch_pulls': 'completed',
    'fetch_issues': 'completed',
    'write_digest': 'completed',
    'check_activity': 'completed',
    'review': 'parked',
  },
};

/// The short approval body used by every approval card (ledger, band, scheduler inbox): the title,
/// the summary paragraph and the four counts — never the full digest, so the cards stay one screen.
/// 所有审批卡共用的短正文：标题、概览段落和四个计数，不放整篇周报，卡片保持一屏。
String digestApprovalBody(StoryLocale l) => l.zh
    ? '''
**周报待审批** · Cookiezisg/Anselm · 2026-08-30 ~ 2026-09-13

本周团队主要聚焦于验收测试的密集闭环与系统前沿状态的同步。Sun Weilin 完成了 batch 84 至 batch 90 的测试封存与门控验证，并修复了若干 UI 和通知相关的缺陷。

- 提交：32 次
- 已合并 PR：0 个
- 新开 Issue：0 个
- 已关闭 Issue：0 个
'''
    : '''
**Weekly Digest Review** · Cookiezisg/Anselm · Aug 30 – Sep 13, 2026

This period focused on closing the acceptance-testing loop and syncing the system frontier. Sun Weilin sealed batches 84 through 90, verified the gates, and fixed a handful of UI and notification defects.

- Commits: 32
- Merged pull requests: 0
- Opened issues: 0
- Closed issues: 0
''';
