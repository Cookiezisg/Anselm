/// The story dataset's Scheduler seed — the Product Team's four workflows caught on a Sunday evening
/// with every surface state visible at once: one run mid-flight, one waiting on a human, one failure
/// inside the last 24h, one cron due in 11h, one paused sensor. Every id and name comes from
/// [story_bible.dart] so the chat tool cards, the entity rail, the run dossier and the notification
/// ledger all point at the same runs. Only DATA lives here; the stateful grammar (decide / cancel /
/// replay / run now / pause) is [FixtureSchedulerRepository]'s, unchanged.
///
/// story 数据集的调度种子——产品团队的四条 workflow 在周日傍晚的一帧,所有状态同屏:一条在跑、一条等人、
/// 一条 24h 内失败、一条 cron 11 小时后到期、一个传感器已暂停。id 与名字全部取自 story_bible,故 chat 工具卡、
/// 实体 rail、run 档案与通知账本指向同一批 run。这里只有数据;有状态文法归 FixtureSchedulerRepository,不动。
library;

import '../../core/contract/entities/relation.dart';
import '../../core/contract/entities/scheduler_matrix.dart';
import '../../core/contract/entities/scheduler_stats.dart';
import '../../core/contract/entities/trigger.dart';
import '../../core/contract/entities/trigger_schedule.dart';
import '../../core/contract/entities/values.dart';
import '../../core/contract/entities/workflow.dart';
import '../../features/scheduler/data/scheduler_demo_fixture.dart';
import '../../features/scheduler/data/scheduler_repository.dart';
import 'story_bible.dart';
import 'story_locale.dart';

SchedulerRepository storySchedulerRepository(StoryLocale l) =>
    FixtureSchedulerRepository(seed: storySchedulerSeed(l));

/// Exposed so a test or another story surface can read the same seed the repository plays back.
/// 公开给测试或其他 story 面读取同一份种子。
SchedulerSeed storySchedulerSeed(StoryLocale l) => SchedulerSeed(
  workflows: _workflows,
  stats: _stats(),
  completedSince: 5,
  runs: _runs(l),
  inbox: _inbox(l),
  versions: _versions(),
  nodesFor: (run, inbox) => _nodesFor(l, run, inbox),
  triggers: _triggers(),
  schedule: _schedule(),
  firings: _firings(),
  edges: _edges,
  workflowCreatedAt: ago(days: 21),
  triageConversationId: cvFlakyTest,
  // The digest matrix shows the WHOLE canonical graph on its row axis (never-run branches read as
  // «not reached») instead of only the nodes some run has touched.
  // 周报矩阵的行轴铺满规范图(未跑分支读作「未及」),而不只列某次 run 碰过的节点。
  matrixRows: {
    wfDigest: [
      for (final n in _digestGraph.nodes)
        MatrixRow(nodeId: n.id, kind: n.kind.name),
    ],
  },
);

// ───────────────────────── Versions (pinned graphs) ─────────────────────────

/// Pinned version ids — story-local infra ids (S15: never derived from the workflow id).
/// 钉版 id——story 本地基础设施 id(S15:不从 workflow id 派生)。
const _wfvDigest = 'wfv_5b8e2d9c1a7f3604';
const _wfvTriage = 'wfv_2c7a9e4f6b1d8503';
const _wfvInvoice = 'wfv_8d1f4b7e3a9c2605';
const _wfvRelease = 'wfv_4e9c2a6d8f1b3507';

// Node ids read as the entity names so the matrix rows and the gantt ledger speak the story's
// vocabulary («failed at parse_invoice_pdf») without a lookup. 节点 id 即实体名,矩阵行与甘特台账直接说人话。
const _nTicket = 'ticket';
const _nNewInvoice = 'new_invoice';
const _nManual = 'manual';

// The digest graph's node ids are the story bible's canonical ids (digestNodeIds), spelled out here
// as constants so a typo cannot split the ledger from the graph.
// 周报图的节点 id 即 story bible 的规范 id(digestNodeIds),此处列为常量,免得笔误把台账与图拆开。
const _nStart = 'start';
const _nFetchCommits = 'fetch_commits';
const _nFetchPulls = 'fetch_pulls';
const _nFetchIssues = 'fetch_issues';
const _nWriteDigest = 'write_digest';
const _nCheckActivity = ctlEmptyWeekName;
const _nReview = 'review';
const _nPrepareDoc = 'prepare_doc';
const _nNotifyTeam = 'notify_team';
const _nSkipNotice = 'skip_notice';

// Authored positions lay the canonical digest graph out VERTICALLY: one column per rank, the three
// fetches side by side, the `empty` branch to the right of `review`. Steps mirror GraphGeometry's
// TB auto-layout (nodeH+gapY down, nodeW+gapX across) so the pinned picture and the reflowed one
// agree. Note the run dossier's flow widget reflows pinned positions (reflowPinned) top→bottom
// anyway; `pos` here is for the surfaces that honour authored layout (the workflow editor).
// 手摆坐标把规范周报图纵向排开:每 rank 一行、三路抓取并排、`empty` 分支在 review 右侧。步长镜像
// GraphGeometry 的 TB 自动布局(纵 nodeH+gapY、横 nodeW+gapX),钉版图与重排图一致。run 卷宗的流程图
// 本就以 reflowPinned 纵向重排;这里的 pos 服务于尊重手摆布局的面(workflow 编辑器)。
const _colL = 0, _colC = 272, _colR = 544; // nodeW 188 + gapX 84
const _row = 104; // nodeH 60 + gapY 44

const _digestGraph = Graph(
  nodes: [
    Node(
      id: _nStart,
      kind: NodeKind.trigger,
      ref: trgMonday,
      pos: NodePosition(x: _colC, y: 0),
    ),
    Node(
      id: _nFetchCommits,
      kind: NodeKind.action,
      ref: fnFetchGithub,
      input: {'kind': 'commits', 'days': 'trigger.days'},
      pos: NodePosition(x: _colL, y: _row),
    ),
    Node(
      id: _nFetchPulls,
      kind: NodeKind.action,
      ref: fnFetchGithub,
      input: {'kind': 'pulls', 'days': 'trigger.days'},
      pos: NodePosition(x: _colC, y: _row),
    ),
    Node(
      id: _nFetchIssues,
      kind: NodeKind.action,
      ref: fnFetchGithub,
      input: {'kind': 'issues', 'days': 'trigger.days'},
      pos: NodePosition(x: _colR, y: _row),
    ),
    Node(
      id: _nWriteDigest,
      kind: NodeKind.agent,
      ref: agDigest,
      pos: NodePosition(x: _colC, y: 2 * _row),
    ),
    Node(
      id: _nCheckActivity,
      kind: NodeKind.control,
      ref: ctlEmptyWeek,
      pos: NodePosition(x: _colC, y: 3 * _row),
    ),
    Node(
      id: _nReview,
      kind: NodeKind.approval,
      ref: apfDigest,
      pos: NodePosition(x: _colC, y: 4 * _row),
    ),
    Node(
      id: _nPrepareDoc,
      kind: NodeKind.action,
      ref: fnPrepareDoc,
      pos: NodePosition(x: _colC, y: 5 * _row),
    ),
    Node(
      id: _nNotifyTeam,
      kind: NodeKind.action,
      ref: hdSlack,
      input: {'method': 'post_digest'},
      pos: NodePosition(x: _colC, y: 6 * _row),
    ),
    Node(
      id: _nSkipNotice,
      kind: NodeKind.action,
      ref: hdSlack,
      input: {'method': 'post_message'},
      pos: NodePosition(x: _colR, y: 4 * _row),
    ),
  ],
  edges: [
    Edge(id: 'e1', from: _nStart, to: _nFetchCommits),
    Edge(id: 'e2', from: _nStart, to: _nFetchPulls),
    Edge(id: 'e3', from: _nStart, to: _nFetchIssues),
    Edge(id: 'e4', from: _nFetchCommits, to: _nWriteDigest),
    Edge(id: 'e5', from: _nFetchPulls, to: _nWriteDigest),
    Edge(id: 'e6', from: _nFetchIssues, to: _nWriteDigest),
    Edge(id: 'e7', from: _nWriteDigest, to: _nCheckActivity),
    Edge(
      id: 'e8',
      from: _nCheckActivity,
      fromPort: 'has_activity',
      to: _nReview,
    ),
    Edge(id: 'e9', from: _nCheckActivity, fromPort: 'empty', to: _nSkipNotice),
    Edge(id: 'e10', from: _nReview, fromPort: 'yes', to: _nPrepareDoc),
    Edge(id: 'e11', from: _nPrepareDoc, to: _nNotifyTeam),
  ],
);

const _triageGraph = Graph(
  nodes: [
    Node(id: _nTicket, kind: NodeKind.trigger, ref: trgZendesk),
    Node(id: agTriageName, kind: NodeKind.agent, ref: agTriage),
    Node(id: ctlSeverityName, kind: NodeKind.control, ref: ctlSeverity),
    Node(id: hdSlackName, kind: NodeKind.action, ref: hdSlack),
    Node(id: hdPostgresName, kind: NodeKind.action, ref: hdPostgres),
  ],
  edges: [
    Edge(id: 'e1', from: _nTicket, to: agTriageName),
    Edge(id: 'e2', from: agTriageName, to: ctlSeverityName),
    Edge(id: 'e3', from: ctlSeverityName, fromPort: 'urgent', to: hdSlackName),
    Edge(
      id: 'e4',
      from: ctlSeverityName,
      fromPort: 'routine',
      to: hdPostgresName,
    ),
  ],
);

const _invoiceGraph = Graph(
  nodes: [
    Node(id: _nNewInvoice, kind: NodeKind.trigger, ref: trgInvoices),
    Node(id: fnParseInvoiceName, kind: NodeKind.action, ref: fnParseInvoice),
    Node(id: hdPostgresName, kind: NodeKind.action, ref: hdPostgres),
    Node(id: hdSlackName, kind: NodeKind.action, ref: hdSlack),
  ],
  edges: [
    Edge(id: 'e1', from: _nNewInvoice, to: fnParseInvoiceName),
    Edge(id: 'e2', from: fnParseInvoiceName, to: hdPostgresName),
    Edge(id: 'e3', from: hdPostgresName, to: hdSlackName),
  ],
);

const _releaseGraph = Graph(
  nodes: [
    Node(id: _nManual, kind: NodeKind.trigger),
    Node(id: agReleaseNotesName, kind: NodeKind.agent, ref: agReleaseNotes),
    Node(id: fnPrepareDocName, kind: NodeKind.action, ref: fnPrepareDoc),
    Node(id: hdSlackName, kind: NodeKind.action, ref: hdSlack),
  ],
  edges: [
    Edge(id: 'e1', from: _nManual, to: agReleaseNotesName),
    Edge(id: 'e2', from: agReleaseNotesName, to: fnPrepareDocName),
    Edge(id: 'e3', from: fnPrepareDocName, to: hdSlackName),
  ],
);

List<WorkflowVersion> _versions() {
  WorkflowVersion v(
    String id,
    String workflowId,
    int version,
    Graph graph,
    DateTime at,
  ) => WorkflowVersion(
    id: id,
    workflowId: workflowId,
    version: version,
    createdAt: at,
    updatedAt: at,
    graphParsed: graph,
  );
  return [
    v(_wfvDigest, wfDigest, 2, _digestGraph, ago(days: 3)),
    v(_wfvTriage, wfTriage, 2, _triageGraph, ago(days: 8)),
    v(_wfvInvoice, wfInvoice, 1, _invoiceGraph, ago(days: 9)),
    v(_wfvRelease, wfRelease, 1, _releaseGraph, ago(days: 5)),
  ];
}

// ───────────────────────── Workflows & stats ─────────────────────────

final _workflows = <SchedulerWorkflowRow>[
  SchedulerWorkflowRow(
    id: wfDigest,
    name: wfDigestName,
    lifecycleState: 'active',
    updatedAt: ago(days: 3),
  ),
  SchedulerWorkflowRow(
    id: wfTriage,
    name: wfTriageName,
    lifecycleState: 'active',
    needsAttention: true,
    updatedAt: ago(minutes: 3),
  ),
  SchedulerWorkflowRow(
    id: wfInvoice,
    name: wfInvoiceName,
    lifecycleState: 'active',
    updatedAt: ago(hours: 5),
  ),
  // Staged: the release pipeline is built but not yet activated — it ran once by hand. 已搭好未激活。
  SchedulerWorkflowRow(
    id: wfRelease,
    name: wfReleaseName,
    lifecycleState: 'inactive',
    updatedAt: ago(days: 4),
  ),
];

/// `running` / `parkedNodes` are overlaid by the repository from the run rows and the inbox, so only
/// the static health rides here. running/parkedNodes 由仓储按 run 与收件箱覆写,此处只放静态健康。
List<WorkflowRunStats> _stats() => [
  WorkflowRunStats(
    workflowId: wfDigest,
    lastRunAt: _digestParkedStart,
    recent: const ['running', 'completed', 'failed'],
    successRate: 0.67,
    avgElapsedMs: 123000,
  ),
  WorkflowRunStats(
    workflowId: wfTriage,
    lastRunAt: _triageRunningStart,
    recent: const ['running', 'completed', 'completed'],
    successRate: 1.0,
    avgElapsedMs: 45000,
  ),
  WorkflowRunStats(
    workflowId: wfInvoice,
    lastRunAt: _invoiceFailedStart,
    recent: const ['failed', 'completed'],
    successRate: 0.5,
    avgElapsedMs: 20000,
    consecutiveFailures: 1,
  ),
  WorkflowRunStats(
    workflowId: wfRelease,
    lastRunAt: _releaseStart,
    recent: const ['completed'],
    successRate: 1.0,
    avgElapsedMs: 225000,
  ),
];

// ───────────────────────── Runs ─────────────────────────

// Start instants, shared by the run rows, the stats, the firings and the trigger cards so the
// cron → firing → run chain never contradicts itself. 起点时刻共用,cron→firing→run 链不自相矛盾。
final _digestParkedStart = ago(minutes: 12);
final _digestRejectedStart = ago(days: 1, hours: 3);
// Last Monday 09:00 — the cron fired 20s before the run began; the run was replayed once ~5 days
// ago. 上周一 09:00,火先烧、run 后起;约 5 天前重放一次。
final _digestFailedStart = ago(days: 6, hours: 9);
final _mondayFiredAt = _digestFailedStart.subtract(const Duration(seconds: 20));
final _digestFailedReplayedAt = ago(days: 5, hours: 2);
final _zendeskFiredAt = ago(minutes: 3, seconds: 12);
final _triageRunningStart = ago(minutes: 3, seconds: 10);
final _triageDone1Start = ago(hours: 9);
final _triageDone2Start = ago(days: 1, hours: 4);
final _invoiceFiredAt = ago(hours: 5, seconds: 2);
final _invoiceFailedStart = ago(hours: 5);
final _invoiceDoneStart = ago(days: 1, hours: 2);
final _releaseStart = ago(days: 4);

// Firing ids — story-local ledger rows the run rows cite back. story 本地 firing 行,run 行回引。
const _trfMonday = 'trf_9e2c7a4b1d6f8305';
const _trfZendeskRunning = 'trf_3a8d1f6c9e2b4705';
const _trfZendeskDone1 = 'trf_7c1e5a3b9d2f8604';
const _trfZendeskSkipped = 'trf_5d9b3f7a2c1e8406';
const _trfInvoiceFailed = 'trf_1f6b4d8e2a9c3507';
const _trfInvoiceDone = 'trf_8b2d5f1a7c9e3406';

// Pinned function versions the digest runs cite: v1 exposed `fetch_activity` and died at the entry
// point (the build conversation's first failure), v2 renamed it to `main`. Ids follow the entity
// story's `<fn>_v<n>` spelling so the dossier and the function page name the same version.
// 周报 run 引用的函数钉版:v1 暴露 `fetch_activity` 死在入口(主对话的第一次失败),v2 改名 `main`。
// id 沿用实体故事的 `<fn>_v<n>` 写法,卷宗与函数页说同一个版本。
const _fnvFetchV1 = '${fnFetchGithub}_v1';
const _fnvFetchV2 = '${fnFetchGithub}_v2';
const _agvDigest = '${agDigest}_v1';
const _apvDigest = '${apfDigest}_v1';

const _digestPinnedV2 = <String, String>{
  _nFetchCommits: _fnvFetchV2,
  _nFetchPulls: _fnvFetchV2,
  _nFetchIssues: _fnvFetchV2,
  _nWriteDigest: _agvDigest,
  _nReview: _apvDigest,
};

// The v1 fetch failure: GitHub answered 502 on /commits and fetch v1 had no retry — the same
// string the notification story shows. v1 抓取失败:GitHub 在 /commits 应答 502,fetch v1 无重试,
// 与通知故事同一字符串。
String _digestFetchError(StoryLocale l) => l.t(
  'fetch_commits: HandlerError: $fnFetchGithubName: 502 Bad Gateway (api.github.com)',
  'fetch_commits:HandlerError: $fnFetchGithubName: 502 Bad Gateway (api.github.com)',
);

// Shared digest timeline (offsets from the run start): the three fetches leave together at 0.5s
// and settle at 1.1s / 0.9s / 1.4s, the agent writes for 1m20s, the control decides in 40ms, and
// review opens at ~82.5s — so the parked run has been waiting ~10 min at story time.
// 周报共用时间线(自 run 起点):三路抓取 0.5s 同发、1.1s/0.9s/1.4s 落地,agent 写 1m20s,控制 40ms 决,
// review 约 82.5s 开——故事时刻 parked run 已等约 10 分钟。
const _fetchAt = Duration(milliseconds: 500);
const _writeAt = Duration(seconds: 2);
const _writeSpan = Duration(seconds: 80);
const _checkAt = Duration(seconds: 82, milliseconds: 200);
const _reviewAt = Duration(seconds: 82, milliseconds: 500);
const _rejectSpan = Duration(minutes: 3, seconds: 40);

String _invoiceParseError(StoryLocale l) => l.t(
  'parse_invoice_pdf: no text layer in ACME-2026-0912.pdf (scanned image, OCR disabled)\nat parse_invoice_pdf',
  'parse_invoice_pdf:ACME-2026-0912.pdf 没有文本层(扫描件,OCR 未启用)\n位于 parse_invoice_pdf',
);

List<Flowrun> _runs(StoryLocale l) => [
  // ── weekly_github_digest ──
  // Waiting at `review` — born from the build conversation's «run it with days=14». 等审批,来自主对话。
  Flowrun(
    id: frDigestParked,
    workflowId: wfDigest,
    versionId: _wfvDigest,
    pinnedRefs: _digestPinnedV2,
    origin: 'chat',
    conversationId: cvDigest,
    status: 'running',
    startedAt: _digestParkedStart,
    updatedAt: _digestParkedStart.add(_reviewAt),
  ),
  // Reviewed and rejected by hand yesterday. 昨天手动跑、驳回。
  Flowrun(
    id: frDigestRejected,
    workflowId: wfDigest,
    versionId: _wfvDigest,
    pinnedRefs: _digestPinnedV2,
    origin: 'manual',
    status: 'completed',
    startedAt: _digestRejectedStart,
    completedAt: _digestRejectedStart.add(_reviewAt + _rejectSpan),
    updatedAt: _digestRejectedStart.add(_reviewAt + _rejectSpan),
  ),
  // Last Monday's cron tick still pinned fetch v1 (no retry): GitHub answered 502 on /commits
  // while its two siblings completed; replayed once, failed the same way.
  // 上周一的 cron 仍钉着 fetch v1(无重试):/commits 应答 502,两个兄弟抓取跑完;重放一次仍同样失败。
  Flowrun(
    id: frDigestFailed,
    workflowId: wfDigest,
    versionId: _wfvDigest,
    pinnedRefs: const {
      _nFetchCommits: _fnvFetchV1,
      _nFetchPulls: _fnvFetchV1,
      _nFetchIssues: _fnvFetchV1,
    },
    origin: 'cron',
    triggerId: trgMonday,
    firingId: _trfMonday,
    status: 'failed',
    replayCount: 1,
    error: _digestFetchError(l),
    startedAt: _digestFailedStart,
    completedAt: _digestFailedStart.add(const Duration(seconds: 2)),
    updatedAt: _digestFailedReplayedAt,
  ),
  // ── support_ticket_triage ──
  // The agent is reading ticket #4821 right now. agent 正在读工单 #4821。
  Flowrun(
    id: frTriageRunning,
    workflowId: wfTriage,
    versionId: _wfvTriage,
    pinnedRefs: const {agTriageName: 'agv_9c1e3a5b7d2f4608'},
    origin: 'webhook',
    triggerId: trgZendesk,
    firingId: _trfZendeskRunning,
    status: 'running',
    startedAt: _triageRunningStart,
    updatedAt: _triageRunningStart,
  ),
  Flowrun(
    id: frTriageDone1,
    workflowId: wfTriage,
    versionId: _wfvTriage,
    pinnedRefs: const {agTriageName: 'agv_9c1e3a5b7d2f4608'},
    origin: 'webhook',
    triggerId: trgZendesk,
    firingId: _trfZendeskDone1,
    status: 'completed',
    startedAt: _triageDone1Start,
    completedAt: _triageDone1Start.add(const Duration(seconds: 44)),
    updatedAt: _triageDone1Start.add(const Duration(seconds: 44)),
  ),
  Flowrun(
    id: frTriageDone2,
    workflowId: wfTriage,
    versionId: _wfvTriage,
    pinnedRefs: const {agTriageName: 'agv_9c1e3a5b7d2f4608'},
    origin: 'manual',
    status: 'completed',
    startedAt: _triageDone2Start,
    completedAt: _triageDone2Start.add(const Duration(seconds: 47)),
    updatedAt: _triageDone2Start.add(const Duration(seconds: 47)),
  ),
  // ── invoice_intake ──
  // The folder watch picked up a scanned PDF five hours ago — the parser has no OCR. 扫描件,解析失败。
  Flowrun(
    id: frInvoiceFailed,
    workflowId: wfInvoice,
    versionId: _wfvInvoice,
    pinnedRefs: const {fnParseInvoiceName: 'fnv_4d8f2b6a9c1e3705'},
    origin: 'fsnotify',
    triggerId: trgInvoices,
    firingId: _trfInvoiceFailed,
    status: 'failed',
    error: _invoiceParseError(l),
    startedAt: _invoiceFailedStart,
    completedAt: _invoiceFailedStart.add(const Duration(seconds: 19)),
    updatedAt: _invoiceFailedStart.add(const Duration(seconds: 19)),
  ),
  Flowrun(
    id: frInvoiceDone,
    workflowId: wfInvoice,
    versionId: _wfvInvoice,
    pinnedRefs: const {fnParseInvoiceName: 'fnv_4d8f2b6a9c1e3705'},
    origin: 'fsnotify',
    triggerId: trgInvoices,
    firingId: _trfInvoiceDone,
    status: 'completed',
    startedAt: _invoiceDoneStart,
    completedAt: _invoiceDoneStart.add(const Duration(seconds: 18)),
    updatedAt: _invoiceDoneStart.add(const Duration(seconds: 18)),
  ),
  // ── release_pipeline ──
  Flowrun(
    id: frReleaseDone,
    workflowId: wfRelease,
    versionId: _wfvRelease,
    pinnedRefs: const {agReleaseNotesName: 'agv_1a7c3e9b5d2f4806'},
    origin: 'manual',
    status: 'completed',
    startedAt: _releaseStart,
    completedAt: _releaseStart.add(const Duration(minutes: 3, seconds: 45)),
    updatedAt: _releaseStart.add(const Duration(minutes: 3, seconds: 45)),
  ),
];

// ───────────────────────── Inbox (waiting on you) ─────────────────────────

List<SchedulerInboxRow> _inbox(StoryLocale l) => [
  SchedulerInboxRow(
    node: _digestReviewNode(l, frDigestParked, _digestParkedStart),
    workflowId: wfDigest,
    workflowName: wfDigestName,
    deadline: ahead(hours: 23),
  ),
];

/// The parked `review` row — one builder because the inbox row and the run's own node ledger must be
/// the same row (same id, same park instant). 停车的 review 行:收件箱与 run 台账须是同一行。
FlowrunNode _digestReviewNode(StoryLocale l, String runId, DateTime started) {
  final parkedAt = started.add(_reviewAt);
  return FlowrunNode(
    id: 'frn_${runId}_${_nReview}_0',
    flowrunId: runId,
    nodeId: _nReview,
    kind: 'approval',
    status: 'parked',
    // The short approval body — the card must stay one screen. 短审批正文,卡片保持一屏。
    result: {'rendered': digestApprovalBody(l), 'allowReason': true},
    readyAt: parkedAt.subtract(const Duration(milliseconds: 80)),
    startedAt: parkedAt,
    createdAt: parkedAt,
    updatedAt: parkedAt,
  );
}

// ───────────────────────── Node ledgers ─────────────────────────

/// One node row with the ⑫ queue stamps (readyAt ≤ startedAt ≤ completedAt) so every gantt bar has
/// its grey queue segment. [span] null = still open (running / parked). 带排队戳的节点行;span 空=未完。
FlowrunNode _node(
  Flowrun run,
  String nodeId,
  String kind,
  String status,
  Duration at,
  Duration? span, {
  Map<String, Object?> result = const {},
  String? error,
  Duration queued = const Duration(milliseconds: 150),
  DateTime? openUntil,
}) {
  final started = run.startedAt!;
  final end = span != null ? started.add(at + span) : openUntil;
  return FlowrunNode(
    id: 'frn_${run.id}_${nodeId}_0',
    flowrunId: run.id,
    nodeId: nodeId,
    kind: kind,
    status: status,
    result: result,
    error: error,
    readyAt: started.add(at - queued),
    startedAt: started.add(at),
    createdAt: end ?? started.add(at),
    completedAt: span != null ? end : null,
    updatedAt: end ?? started.add(at),
  );
}

List<FlowrunNode> _nodesFor(
  StoryLocale l,
  Flowrun run,
  List<SchedulerInboxRow> inbox,
) {
  switch (run.id) {
    // ── digest ──
    case frDigestParked:
      return [
        ..._digestPrefix(run, days: 14, commits: 32, words: 412, sections: 4),
        // The inbox's own parked row, so the ledger and the card agree. 与收件箱同一行。
        for (final r in inbox)
          if (r.node.flowrunId == run.id) r.node,
      ];
    case frDigestRejected:
      return [
        ..._digestPrefix(run, days: 14, commits: 27, words: 380, sections: 3),
        _node(
          run,
          _nReview,
          'approval',
          'completed',
          _reviewAt,
          _rejectSpan,
          result: {
            'decision': 'no',
            'reason': l.t(
              'Too thin — wait for the batch-90 PRs to land.',
              '内容太薄,等 batch-90 的 PR 合并后再发。',
            ),
            'rendered': digestApprovalBody(l),
            'allowReason': true,
          },
        ),
      ];
    case frDigestFailed:
      return [
        _digestStart(run, days: 7),
        // /commits hangs ~1.2s before GitHub's 502 comes back; the two sibling fetches keep going
        // and land on their usual clocks, so the gantt shows one red bar beside two green ones.
        // /commits 挂约 1.2s 才等到 GitHub 的 502;两个兄弟抓取照常跑完,甘特上一根红条挨着两根绿条。
        _node(
          run,
          _nFetchCommits,
          'action',
          'failed',
          _fetchAt,
          const Duration(milliseconds: 1200),
          error: run.error ?? _digestFetchError(l),
        ),
        _digestFetch(
          run,
          _nFetchPulls,
          'pulls',
          0,
          const Duration(milliseconds: 900),
        ),
        _digestFetch(
          run,
          _nFetchIssues,
          'issues',
          0,
          const Duration(milliseconds: 1400),
        ),
      ];
    // ── triage ──
    case frTriageRunning:
      return [
        _node(
          run,
          _nTicket,
          'trigger',
          'completed',
          Duration.zero,
          const Duration(milliseconds: 200),
          result: _ticketPayload(4821, cvRefundTitle(l)),
        ),
        // Still running: an open row anchored at «now» so the matrix shows the blue cell and the
        // gantt the long bar. 仍在跑:开口行锚在当下,矩阵出蓝格、甘特出长条。
        _node(
          run,
          agTriageName,
          'agent',
          'running',
          const Duration(seconds: 1),
          null,
          queued: const Duration(milliseconds: 600),
          openUntil: storyNow,
        ),
      ];
    case frTriageDone1:
      return [
        _node(
          run,
          _nTicket,
          'trigger',
          'completed',
          Duration.zero,
          const Duration(milliseconds: 200),
          result: _ticketPayload(
            4817,
            l.t('Login loop on Safari', 'Safari 登录循环'),
          ),
        ),
        _node(
          run,
          agTriageName,
          'agent',
          'completed',
          const Duration(seconds: 1),
          const Duration(seconds: 38),
          result: {'severity': 'urgent', 'category': 'auth'},
          queued: const Duration(milliseconds: 600),
        ),
        _node(
          run,
          ctlSeverityName,
          'control',
          'completed',
          const Duration(seconds: 39, milliseconds: 200),
          const Duration(milliseconds: 40),
          result: const {'__port': 'urgent'},
        ),
        _node(
          run,
          hdSlackName,
          'action',
          'completed',
          const Duration(seconds: 40),
          const Duration(seconds: 2),
          result: const {'channel': '#support-oncall', 'ts': '1757740801.0421'},
        ),
        // The branch the control did not select. 控制节点未选的那条分支。
        _node(
          run,
          hdPostgresName,
          'action',
          'skipped',
          const Duration(seconds: 40),
          Duration.zero,
        ),
      ];
    case frTriageDone2:
      return [
        _node(
          run,
          _nTicket,
          'trigger',
          'completed',
          Duration.zero,
          const Duration(milliseconds: 200),
          result: _ticketPayload(
            4802,
            l.t('Invoice PDF missing VAT line', '发票 PDF 缺增值税行'),
          ),
        ),
        _node(
          run,
          agTriageName,
          'agent',
          'completed',
          const Duration(seconds: 1),
          const Duration(seconds: 41),
          result: {'severity': 'routine', 'category': 'billing'},
          queued: const Duration(milliseconds: 600),
        ),
        _node(
          run,
          ctlSeverityName,
          'control',
          'completed',
          const Duration(seconds: 42, milliseconds: 200),
          const Duration(milliseconds: 40),
          result: const {'__port': 'routine'},
        ),
        _node(
          run,
          hdPostgresName,
          'action',
          'completed',
          const Duration(seconds: 43),
          const Duration(seconds: 3),
          result: const {'rows': 1, 'plan': 'team'},
        ),
        _node(
          run,
          hdSlackName,
          'action',
          'skipped',
          const Duration(seconds: 43),
          Duration.zero,
        ),
      ];
    // ── invoice ──
    case frInvoiceFailed:
      return [
        _node(
          run,
          _nNewInvoice,
          'trigger',
          'completed',
          Duration.zero,
          const Duration(milliseconds: 200),
          result: const {
            'path': '/Users/you/Documents/invoices/ACME-2026-0912.pdf',
          },
        ),
        _node(
          run,
          fnParseInvoiceName,
          'action',
          'failed',
          const Duration(milliseconds: 400),
          const Duration(seconds: 18),
          error: run.error ?? _invoiceParseError(l),
          queued: const Duration(milliseconds: 250),
        ),
      ];
    case frInvoiceDone:
      return [
        _node(
          run,
          _nNewInvoice,
          'trigger',
          'completed',
          Duration.zero,
          const Duration(milliseconds: 200),
          result: const {
            'path': '/Users/you/Documents/invoices/Northwind-2026-0911.pdf',
          },
        ),
        _node(
          run,
          fnParseInvoiceName,
          'action',
          'completed',
          const Duration(milliseconds: 400),
          const Duration(seconds: 14),
          result: const {
            'vendor': 'Northwind',
            'total': 1280.00,
            'currency': 'USD',
          },
          queued: const Duration(milliseconds: 250),
        ),
        _node(
          run,
          hdPostgresName,
          'action',
          'completed',
          const Duration(seconds: 15),
          const Duration(seconds: 2),
          result: const {'rows': 1},
        ),
        _node(
          run,
          hdSlackName,
          'action',
          'completed',
          const Duration(seconds: 17),
          const Duration(seconds: 1),
          result: const {'channel': '#finance'},
        ),
      ];
    // ── release ──
    case frReleaseDone:
      return [
        _node(
          run,
          _nManual,
          'trigger',
          'completed',
          Duration.zero,
          const Duration(milliseconds: 200),
          result: const {'tag': 'v0.2.0'},
        ),
        _node(
          run,
          agReleaseNotesName,
          'agent',
          'completed',
          const Duration(seconds: 1),
          const Duration(minutes: 3, seconds: 40),
          result: {'words': 640, 'sections': 5},
          queued: const Duration(milliseconds: 500),
        ),
        _node(
          run,
          fnPrepareDocName,
          'action',
          'completed',
          const Duration(minutes: 3, seconds: 42),
          const Duration(seconds: 2),
          result: const {'documentId': docReleaseProcess},
        ),
        _node(
          run,
          hdSlackName,
          'action',
          'completed',
          const Duration(minutes: 3, seconds: 44),
          const Duration(seconds: 1),
          result: const {'channel': '#releases'},
        ),
      ];
    default:
      // «Run now» births carry no settled rows yet — the cold-open face. 立即运行的新 run 尚无行。
      return const [];
  }
}

/// The digest trigger row. 周报触发行。
FlowrunNode _digestStart(Flowrun run, {required int days}) => _node(
  run,
  _nStart,
  'trigger',
  'completed',
  Duration.zero,
  const Duration(milliseconds: 300),
  result: {'days': days},
);

/// One of the three parallel fetches — all leave at [_fetchAt], each on its own clock. 三路抓取之一。
FlowrunNode _digestFetch(
  Flowrun run,
  String nodeId,
  String kind,
  int count,
  Duration span,
) => _node(
  run,
  nodeId,
  'action',
  'completed',
  _fetchAt,
  span,
  result: {'kind': kind, 'count': count},
);

/// Everything a v2 digest run does before `review`: trigger, the three fetches, the agent and the
/// control routing `has_activity`. v2 周报 run 在 review 之前的全部:触发、三路抓取、agent、控制选 has_activity。
List<FlowrunNode> _digestPrefix(
  Flowrun run, {
  required int days,
  required int commits,
  required int words,
  required int sections,
}) => [
  _digestStart(run, days: days),
  _digestFetch(
    run,
    _nFetchCommits,
    'commits',
    commits,
    const Duration(milliseconds: 1100),
  ),
  _digestFetch(
    run,
    _nFetchPulls,
    'pulls',
    0,
    const Duration(milliseconds: 900),
  ),
  _digestFetch(
    run,
    _nFetchIssues,
    'issues',
    0,
    const Duration(milliseconds: 1400),
  ),
  _node(
    run,
    _nWriteDigest,
    'agent',
    'completed',
    _writeAt,
    _writeSpan,
    result: {'words': words, 'sections': sections},
    queued: const Duration(milliseconds: 400),
  ),
  _node(
    run,
    _nCheckActivity,
    'control',
    'completed',
    _checkAt,
    const Duration(milliseconds: 40),
    result: const {'__port': 'has_activity'},
  ),
];

Map<String, Object?> _ticketPayload(int id, String subject) => {
  'ticketId': id,
  'subject': subject,
  'requester': 'customer@example.com',
  'source': 'zendesk',
};

// ───────────────────────── Triggers, schedule, firings, edges ─────────────────────────

List<SchedulerTriggerSeed> _triggers() => [
  SchedulerTriggerSeed(
    id: trgMonday,
    name: trgMondayName,
    kind: TriggerSource.cron,
    config: const {'cron': '0 9 * * 1'},
    createdAt: ago(days: 21),
    lastFiredAt: _mondayFiredAt,
    nextFireAt: ahead(hours: 11),
  ),
  SchedulerTriggerSeed(
    id: trgZendesk,
    name: trgZendeskName,
    kind: TriggerSource.webhook,
    config: const {'path': '/hooks/zendesk'},
    createdAt: ago(days: 12),
    lastFiredAt: _zendeskFiredAt,
  ),
  SchedulerTriggerSeed(
    id: trgInvoices,
    name: trgInvoicesName,
    kind: TriggerSource.fsnotify,
    config: const {'path': '/Users/you/Documents/invoices', 'glob': '*.pdf'},
    createdAt: ago(days: 9),
    lastFiredAt: _invoiceFiredAt,
  ),
  // Paused: the uptime sensor was silenced during the launch-site migration. 发布站迁移期间静音。
  SchedulerTriggerSeed(
    id: trgUptime,
    name: trgUptimeName,
    kind: TriggerSource.sensor,
    config: const {'interval': '5m', 'url': 'https://status.anselm.example'},
    createdAt: ago(days: 30),
    lastFiredAt: ago(days: 3, hours: 2),
    paused: true,
  ),
];

/// Only crons project ticks; the weekly Monday cron lands twice inside the next ten days.
/// 只有 cron 投影刻度;每周一的 cron 十天内两次。
List<SchedulePoint> _schedule() => [
  for (final at in [ahead(hours: 11), ahead(days: 7, hours: 11)])
    SchedulePoint(
      at: at,
      triggerId: trgMonday,
      triggerName: trgMondayName,
      workflowIds: const [wfDigest],
    ),
];

Firing _firing(
  String id,
  String triggerId,
  String workflowId,
  FiringStatus status,
  DateTime at, {
  String flowrunId = '',
}) => Firing(
  id: id,
  triggerId: triggerId,
  workflowId: workflowId,
  activationId: 'tra_${id.substring(4)}',
  dedupKey: '$triggerId@${at.toUtc().toIso8601String()}',
  status: status,
  flowrunId: flowrunId,
  createdAt: at,
  updatedAt: at,
);

List<Firing> _firings() => [
  _firing(
    _trfMonday,
    trgMonday,
    wfDigest,
    FiringStatus.started,
    _mondayFiredAt,
    flowrunId: frDigestFailed,
  ),
  _firing(
    _trfZendeskRunning,
    trgZendesk,
    wfTriage,
    FiringStatus.started,
    _zendeskFiredAt,
    flowrunId: frTriageRunning,
  ),
  _firing(
    _trfZendeskDone1,
    trgZendesk,
    wfTriage,
    FiringStatus.started,
    _triageDone1Start.subtract(const Duration(seconds: 5)),
    flowrunId: frTriageDone1,
  ),
  // A second ticket arrived while #4817 was still in flight — serial overlap policy skipped it.
  // #4817 在跑时又来一张工单,串行 overlap 策略跳过。
  _firing(
    _trfZendeskSkipped,
    trgZendesk,
    wfTriage,
    FiringStatus.skipped,
    _triageDone1Start.add(const Duration(seconds: 20)),
  ),
  _firing(
    _trfInvoiceFailed,
    trgInvoices,
    wfInvoice,
    FiringStatus.started,
    _invoiceFiredAt,
    flowrunId: frInvoiceFailed,
  ),
  _firing(
    _trfInvoiceDone,
    trgInvoices,
    wfInvoice,
    FiringStatus.started,
    _invoiceDoneStart.subtract(const Duration(seconds: 3)),
    flowrunId: frInvoiceDone,
  ),
];

const _edges = <EntityRelation>[
  EntityRelation(
    id: 'rel_digest_monday',
    kind: 'equip',
    fromKind: 'workflow',
    fromId: wfDigest,
    fromName: wfDigestName,
    toKind: 'trigger',
    toId: trgMonday,
    toName: trgMondayName,
  ),
  EntityRelation(
    id: 'rel_triage_zendesk',
    kind: 'equip',
    fromKind: 'workflow',
    fromId: wfTriage,
    fromName: wfTriageName,
    toKind: 'trigger',
    toId: trgZendesk,
    toName: trgZendeskName,
  ),
  EntityRelation(
    id: 'rel_triage_uptime',
    kind: 'equip',
    fromKind: 'workflow',
    fromId: wfTriage,
    fromName: wfTriageName,
    toKind: 'trigger',
    toId: trgUptime,
    toName: trgUptimeName,
  ),
  EntityRelation(
    id: 'rel_invoice_watch',
    kind: 'equip',
    fromKind: 'workflow',
    fromId: wfInvoice,
    fromName: wfInvoiceName,
    toKind: 'trigger',
    toId: trgInvoices,
    toName: trgInvoicesName,
  ),
];
