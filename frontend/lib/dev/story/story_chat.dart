/// The story dataset's chat surface — eight conversations that share the bible's ids so a tool card
/// here names the same function, run and approval the entity rail, scheduler and notifications show.
/// Every rail dot the product can render is present at once (pinned / generating / awaiting / unread /
/// error / three residency groups incl. a vanished one), because the dataset exists to be photographed.
///
/// story 数据集的 chat 面——八个对话共用总纲里的 id,这里工具卡点名的函数、run 与审批,就是实体 rail、
/// 调度和通知里的同一个。rail 能渲的每种点都同时在场(置顶/生成中/等回答/未读/出错/三个驻地组含一个已
/// 消失的),因为这套数据就是为了被截图而存在的。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/contract/attachment.dart';
import '../../core/contract/conversation.dart';
import '../../core/contract/entities/agent.dart';
import '../../core/contract/entities/control.dart';
import '../../core/contract/entities/document.dart';
import '../../core/contract/entities/function.dart';
import '../../core/contract/entities/trigger.dart';
import '../../core/contract/entities/values.dart';
import '../../core/contract/entities/workflow.dart';
import '../../core/contract/interaction.dart';
import '../../core/contract/messages/chat_message.dart';
import '../../core/contract/todo.dart';
import '../../core/contract/touchpoint.dart';
import '../../features/chat/data/chat_demo_fixture.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/chat/data/chat_showcase_fixture.dart';
import 'story_bible.dart';
import 'story_locale.dart';

/// The story chat repository. A [DemoChatRepository] rather than the bare fixture so typing into any
/// thread still plays a scripted streaming reply — a screenshot session must be able to show "generating".
/// story chat 仓库。用 DemoChatRepository 而非裸夹具,使任一线程里敲字仍能回放脚本流式回复——截图
/// 现场必须能演出「生成中」。
ChatRepository storyChatRepository(
  StoryLocale l, {
  DemoTurnScript? turnScript,
}) {
  final digest = _digest(l);
  final triage = _triage(l);
  final refund = _refund(l);
  final hero = _heroImages(l);
  final flaky = _flakyTest(l);
  final release = _releaseNotes(l);
  final proto = _oldPrototype(l);
  final durable = _explainDurable(l);
  final threads = [
    digest,
    triage,
    refund,
    hero,
    flaky,
    release,
    proto,
    durable,
  ];

  // A scripted reel opens on an empty rail so the thread it builds is the only thing moving; the
  // entity truth below is still seeded, which is what its settled rows open onto.
  // 脚本宣传片从空 rail 开始,画面里只有它建的那条线程在动;下方实体真身照常播种,落定行打开的就是它们。
  final reel = turnScript != null;
  final repo = DemoChatRepository(
    conversations: reel ? const [] : [for (final t in threads) t.conv],
    messages: reel
        ? const {}
        : {for (final t in threads) t.conv.id: t.messages},
    turnScript: turnScript,
  );
  _seedResidencies(repo);
  _seedInteractions(repo, l);
  _seedAttachments(repo);
  _seedTodos(repo, l);
  _seedTouchpoints(repo, l);
  _seedTruth(repo, l);
  return repo;
}

// ───────────────────────── row helpers ─────────────────────────

typedef _Thread = ({Conversation conv, List<ChatMessage> messages});

Conversation _conv(
  String id,
  String title,
  DateTime last, {
  DateTime? created,
  bool pinned = false,
  bool generating = false,
  bool awaiting = false,
  bool unread = false,
  String workDir = '',
}) => Conversation(
  id: id,
  title: title,
  autoTitled: true,
  pinned: pinned,
  createdAt: created ?? last.subtract(const Duration(minutes: 6)),
  updatedAt: last,
  lastMessageAt: last,
  isGenerating: generating,
  awaitingInput: awaiting,
  hasUnread: unread,
  workDir: workDir,
);

ChatMessage _user(
  String id,
  String conv,
  DateTime at,
  String text, {
  List<String> attachments = const [],
}) => ChatMessage(
  id: id,
  conversationId: conv,
  role: 'user',
  status: 'completed',
  attrs: attachments.isEmpty ? null : {'attachments': attachments},
  blocks: [txt('${id}_t', 'text', text)],
  createdAt: at,
);

ChatMessage _bot(
  String id,
  String conv,
  DateTime at,
  List<ChatBlock> blocks, {
  String status = 'completed',
  String stopReason = 'end_turn',
  String errorCode = '',
  String errorMessage = '',
  int tokensIn = 0,
  int tokensOut = 0,
}) => ChatMessage(
  id: id,
  conversationId: conv,
  role: 'assistant',
  status: status,
  stopReason: status == 'streaming' ? '' : stopReason,
  errorCode: errorCode,
  errorMessage: errorMessage,
  inputTokens: tokensIn,
  outputTokens: tokensOut,
  provider: 'anthropic',
  modelId: 'claude-sonnet-4-5',
  blocks: blocks,
  createdAt: at,
);

/// Tool args/results are authored as Dart maps and encoded once: hand-escaped JSON strings are where
/// showcase fixtures rot. 工具参数/结果用 Dart map 写、一次编码:手工转义的 JSON 串正是展台夹具腐烂之处。
String _j(Object o) => jsonEncode(o);

/// A tool_call whose target chip should read the entity NAME, not the id. 目标 chip 读实体名的 tool_call。
ChatBlock _tcNamed(
  String id,
  String tool,
  Map<String, Object?> args, {
  required String entityName,
  String summary = '',
  String danger = 'safe',
}) => ChatBlock(
  id: id,
  type: 'tool_call',
  content: _j(args),
  status: 'completed',
  attrs: {
    'tool': tool,
    'entityName': entityName,
    if (summary.isNotEmpty) 'summary': summary,
    'danger': danger,
  },
);

/// A nested progress line under a tool call (wire snapshot key is `text`). 嵌套进度行。
ChatBlock _progress(String callId, String text) => ChatBlock(
  id: 'pg_$callId',
  parentBlockId: callId,
  type: 'progress',
  content: text,
  status: 'completed',
);

String _iso(DateTime t) => t.toUtc().toIso8601String();

// ───────────────────────── shared story facts ─────────────────────────

const _fnv1 = 'fnv_2b8c4d6e1f3a5079';
const _fnv2 = 'fnv_7d1e3f5a9c2b4680';
const _agv1 = 'agv_5e2f7a9c1d3b6084';
const _apfv1 = 'apfv_8c4a6e2d9f1b3075';
const _ctlv1 = 'ctlv_3e7b9d1f5a2c4806';
const _wfv1 = 'wfv_1f9d3b5a7c2e4068';
const _docReleaseNotes = 'doc_9e1f3a5c7b2d4086';

const _fetchCodeV1 = '''
import requests
from datetime import datetime, timedelta

API = "https://api.github.com"


def main(repo: str, since: str, until: str) -> dict:
    headers = {"Accept": "application/vnd.github+json"}
    commits = requests.get(
        f"{API}/repos/{repo}/commits",
        params={"since": since, "until": until, "per_page": 100},
        headers=headers,
        timeout=30,
    ).json()
    pulls = requests.get(
        f"{API}/repos/{repo}/pulls",
        params={"state": "closed", "sort": "updated", "direction": "desc"},
        headers=headers,
        timeout=30,
    ).json()
    merged = [p for p in pulls if p.get("merged_at") and since <= p["merged_at"] <= until]
    return {
        "commits": [
            {"sha": c["sha"][:7], "message": c["commit"]["message"].split("\\n")[0],
             "author": c["commit"]["author"]["name"]}
            for c in commits
        ],
        "pullRequests": [{"number": p["number"], "title": p["title"]} for p in merged],
        "period": {"since": since, "until": until},
    }
''';

const _fetchCodeV2 = '''
import time

import requests
from datetime import datetime, timedelta

API = "https://api.github.com"


RETRY_STATUS = {429, 500, 502, 503, 504}


def _get(url: str, params: dict, headers: dict, attempts: int = 3) -> list:
    # GitHub answers 5xx / rate-limit transiently; back off 1s, 2s, 4s before giving up.
    for attempt in range(attempts):
        resp = requests.get(url, params=params, headers=headers, timeout=30)
        if resp.status_code not in RETRY_STATUS:
            resp.raise_for_status()
            return resp.json()
        if attempt == attempts - 1:
            resp.raise_for_status()
        time.sleep(2 ** attempt)
    return []


def main(repo: str, since: str = "", until: str = "") -> dict:
    # Default to the trailing two weeks so the cron payload can stay empty.
    until = until or datetime.utcnow().date().isoformat()
    since = since or (datetime.fromisoformat(until) - timedelta(days=14)).date().isoformat()
    headers = {"Accept": "application/vnd.github+json"}
    commits = _get(
        f"{API}/repos/{repo}/commits",
        {"since": since, "until": until, "per_page": 100},
        headers,
    )
    pulls = _get(
        f"{API}/repos/{repo}/pulls",
        {"state": "closed", "sort": "updated", "direction": "desc"},
        headers,
    )
    merged = [p for p in pulls if p.get("merged_at") and since <= p["merged_at"] <= until]
    return {
        "commits": [
            {"sha": c["sha"][:7], "message": c["commit"]["message"].split("\\n")[0],
             "author": c["commit"]["author"]["name"]}
            for c in commits
        ],
        "pullRequests": [{"number": p["number"], "title": p["title"]} for p in merged],
        "period": {"since": since, "until": until},
    }
''';

Map<String, Object?> _fetchResultV2() => {
  'commits': 32,
  'pullRequests': 0,
  'issuesOpened': 0,
  'issuesClosed': 0,
  'period': {'since': '2026-08-30', 'until': '2026-09-13'},
  'sample': [
    {
      'sha': '33facdd',
      'message': 'test(acceptance): close remaining autonomous frontier',
      'author': authorName,
    },
    {
      'sha': '06e6dbb',
      'message': 'test(acceptance): close edge296 and batch90 gate',
      'author': authorName,
    },
    {
      'sha': 'e109a37',
      'message': 'fix(acceptance): reset rail viewport when sort axis changes',
      'author': authorName,
    },
  ],
};

Map<String, Object?> _flowrunNode(
  String runId,
  String nodeId,
  String kind,
  String ref,
  String status,
  DateTime at, {
  Map<String, Object?> result = const {},
  String? error,
  DateTime? completedAt,
}) => {
  'id': 'frn_${runId.substring(3, 9)}_$nodeId',
  'flowrunId': runId,
  'nodeId': nodeId,
  'iteration': 0,
  'kind': kind,
  'ref': ref,
  'status': status,
  'result': result,
  'error': ?error,
  'createdAt': _iso(at),
  'startedAt': _iso(at),
  if (completedAt != null) 'completedAt': _iso(completedAt),
  'updatedAt': _iso(completedAt ?? at),
};

// ───────────────────────── weekly_github_digest · canonical graph ─────────────────────────

/// Authored positions for the canonical digest graph, laid out TOP→BOTTOM with the three fetches side
/// by side. The graph layer honours `pos` verbatim whenever EVERY node carries one (graph_model.dart
/// `layoutGraph`), so the truth snapshot renders vertically on any surface that respects positions
/// without touching the widget's `dir`. Grid: column = nodeW 188 + gapX 84, row = nodeH 60 + gapY 44.
/// 规范周报图的手摆坐标:自上而下,三路抓取并排。全节点带 `pos` 时布局层逐字采用(`layoutGraph`),
/// 真身快照在尊重坐标的面上天然纵向,无需改 widget 的 `dir`。网格:列 = 188+84,行 = 60+44。
const _digestPos = <String, NodePosition>{
  'start': NodePosition(x: 272, y: 0),
  'fetch_commits': NodePosition(x: 0, y: 104),
  'fetch_pulls': NodePosition(x: 272, y: 104),
  'fetch_issues': NodePosition(x: 544, y: 104),
  'write_digest': NodePosition(x: 272, y: 208),
  'check_activity': NodePosition(x: 272, y: 312),
  'review': NodePosition(x: 272, y: 416),
  'skip_notice': NodePosition(x: 544, y: 416),
  'prepare_doc': NodePosition(x: 272, y: 520),
  'notify_team': NodePosition(x: 272, y: 624),
};

/// The canonical `weekly_github_digest` graph (story_bible.dart · canonical graph v2): ONE source for
/// the create_workflow tool card ops, the truth snapshot and the per-run node ledgers, so the chat
/// surface can never drift from the bible. Node order follows [digestNodeIds].
/// 规范周报图(见 story_bible 规范图 v2):create_workflow 卡 ops、真身快照和各 run 节点台账共用同一来源,
/// chat 面不可能与总纲漂移。节点顺序即 [digestNodeIds]。
Graph _digestGraph(StoryLocale l) {
  final skipText = l.t(
    'No GitHub activity in the last two weeks — digest skipped.',
    '过去两周没有 GitHub 活动——本期周报跳过。',
  );
  Node node(String id, NodeKind kind, String ref, Map<String, String> input) =>
      Node(id: id, kind: kind, ref: ref, input: input, pos: _digestPos[id]);
  return Graph(
    nodes: [
      node('start', NodeKind.trigger, trgMonday, const {}),
      node('fetch_commits', NodeKind.action, fnFetchGithub, const {
        'kind': '"commits"',
        'days': 'trigger.days',
      }),
      node('fetch_pulls', NodeKind.action, fnFetchGithub, const {
        'kind': '"pulls"',
        'days': 'trigger.days',
      }),
      node('fetch_issues', NodeKind.action, fnFetchGithub, const {
        'kind': '"issues"',
        'days': 'trigger.days',
      }),
      node('write_digest', NodeKind.agent, agDigest, const {
        'commits': 'nodes.fetch_commits',
        'pulls': 'nodes.fetch_pulls',
        'issues': 'nodes.fetch_issues',
      }),
      node('check_activity', NodeKind.control, ctlEmptyWeek, const {
        'commits': 'nodes.fetch_commits.count',
        'pulls': 'nodes.fetch_pulls.count',
        'issues': 'nodes.fetch_issues.count',
      }),
      node('review', NodeKind.approval, apfDigest, const {
        'headline': 'nodes.write_digest.headline',
        'markdown': 'nodes.write_digest.markdown',
      }),
      node('prepare_doc', NodeKind.action, fnPrepareDoc, const {
        'headline': 'nodes.write_digest.headline',
        'markdown': 'nodes.write_digest.markdown',
        'folder_id': '"$docDigestsFolder"',
      }),
      node('notify_team', NodeKind.action, '$hdSlack.post_digest', const {
        'channel': '"#product-team"',
        'markdown': 'nodes.write_digest.markdown',
      }),
      node('skip_notice', NodeKind.action, '$hdSlack.post_message', {
        'channel': '"#product-team"',
        'text': '"$skipText"',
      }),
    ],
    edges: const [
      Edge(id: 'e1', from: 'start', to: 'fetch_commits'),
      Edge(id: 'e2', from: 'start', to: 'fetch_pulls'),
      Edge(id: 'e3', from: 'start', to: 'fetch_issues'),
      Edge(id: 'e4', from: 'fetch_commits', to: 'write_digest'),
      Edge(id: 'e5', from: 'fetch_pulls', to: 'write_digest'),
      Edge(id: 'e6', from: 'fetch_issues', to: 'write_digest'),
      Edge(id: 'e7', from: 'write_digest', to: 'check_activity'),
      Edge(
        id: 'e8',
        from: 'check_activity',
        fromPort: 'has_activity',
        to: 'review',
      ),
      Edge(
        id: 'e9',
        from: 'check_activity',
        fromPort: 'empty',
        to: 'skip_notice',
      ),
      Edge(id: 'e10', from: 'review', fromPort: 'yes', to: 'prepare_doc'),
      Edge(id: 'e11', from: 'prepare_doc', to: 'notify_team'),
    ],
  );
}

/// The create_workflow `ops` for the canonical graph — the wire shape (add_node `node{…}` with `input`
/// and `pos`, add_edge `edge{…}` with `fromPort`), derived from [_digestGraph] so the card and the
/// snapshot agree node for node. 规范图的 create_workflow ops(线缆形),从 [_digestGraph] 派生。
List<Map<String, Object?>> digestOps(StoryLocale l) {
  final g = _digestGraph(l);
  return [
    for (final n in g.nodes)
      {
        'op': 'add_node',
        'node': {
          'id': n.id,
          'kind': n.kind.name,
          'ref': n.ref,
          if (n.input.isNotEmpty) 'input': n.input,
          'pos': n.pos!.toJson(),
        },
      },
    for (final e in g.edges)
      {
        'op': 'add_edge',
        'edge': {
          'id': e.id,
          'from': e.from,
          if (e.fromPort != null) 'fromPort': e.fromPort,
          'to': e.to,
        },
      },
  ];
}

/// Per-run node ledger for a digest run: walks [digestNodeIds] and emits one row per node the bible's
/// [digestRunOutcomes] says was reached, taking kind/ref from the canonical graph. Fetches run in
/// parallel, so all three start one second after the trigger. 按总纲的节点终态生成 run 台账;三路抓取并行。
List<Map<String, Object?>> _digestRunNodes(
  StoryLocale l,
  String runId,
  DateTime at, {
  required Map<String, Map<String, Object?>> results,
  Map<String, String> errors = const {},
  required Map<String, int> doneAfterSec,
}) {
  final byId = {for (final n in _digestGraph(l).nodes) n.id: n};
  final outcomes = digestRunOutcomes[runId]!;
  return [
    for (final id in digestNodeIds)
      if (outcomes[id] case final status?)
        _flowrunNode(
          runId,
          id,
          byId[id]!.kind.name,
          byId[id]!.ref,
          status,
          at.add(Duration(seconds: id == 'start' ? 0 : _digestStartSec[id]!)),
          result: results[id] ?? const {},
          error: errors[id],
          completedAt: doneAfterSec[id] == null
              ? null
              : at.add(Duration(seconds: doneAfterSec[id]!)),
        ),
  ];
}

/// Seconds after the trigger at which each node starts (fetches in parallel at +1s, the join at +9s).
/// 各节点相对触发的启动秒数(三路抓取 +1s 并行,汇合 +9s)。
const _digestStartSec = <String, int>{
  'fetch_commits': 1,
  'fetch_pulls': 1,
  'fetch_issues': 1,
  'write_digest': 9,
  'check_activity': 41,
  'review': 41,
};

// ───────────────────────── 1 · the hero transcript ─────────────────────────

_Thread _digest(StoryLocale l) {
  const cv = cvDigest;
  final askAt = ago(days: 2, hours: 3, minutes: 12);
  final buildAt = ago(days: 2, hours: 3);
  final failedRunAt = ago(days: 2, hours: 2, minutes: 58);
  final fixAskAt = ago(minutes: 26);
  final fixAt = ago(minutes: 18);
  final parkedRunAt = ago(minutes: 20);

  final todoV1 = [
    {
      'content': l.t('Create the GitHub fetch function', '建 GitHub 拉取函数'),
      'activeForm': l.t('Creating the fetch function', '正在建拉取函数'),
      'status': 'in_progress',
    },
    {
      'content': l.t('Create the digest-writing agent', '建写周报的 agent'),
      'status': 'pending',
    },
    {
      'content': l.t('Create the Monday 09:00 trigger', '建周一 09:00 触发器'),
      'status': 'pending',
    },
    {
      'content': l.t('Create the review approval', '建审阅审批'),
      'status': 'pending',
    },
    {
      'content': l.t('Create the empty-week control', '建空周判断控制'),
      'status': 'pending',
    },
    {
      'content': l.t('Wire the workflow and run it once', '串成工作流并跑一次'),
      'status': 'pending',
    },
  ];
  final todoDone = [
    for (final t in todoV1) {'content': t['content'], 'status': 'completed'},
    {
      'content': l.t('Wait for the digest review', '等周报审阅'),
      'activeForm': l.t('Waiting for the digest review', '正在等周报审阅'),
      'status': 'in_progress',
    },
  ];

  final failedRun = {
    'flowrun': {
      'id': frDigestFailed,
      'workflowId': wfDigest,
      'versionId': _wfv1,
      'status': 'failed',
      'replayCount': 0,
      'error':
          'node fetch_commits — HandlerError: $fnFetchGithubName: 502 Bad Gateway (api.github.com)',
      'pinnedRefs': {
        'fetch_commits': _fnv1,
        'fetch_pulls': _fnv1,
        'fetch_issues': _fnv1,
      },
      'triggerId': '',
      'startedAt': _iso(failedRunAt),
      'completedAt': _iso(failedRunAt.add(const Duration(seconds: 4))),
      'createdAt': _iso(failedRunAt),
      'updatedAt': _iso(failedRunAt.add(const Duration(seconds: 4))),
    },
    'workflowName': wfDigestName,
    'nodes': _digestRunNodes(
      l,
      frDigestFailed,
      failedRunAt,
      results: {
        'start': {'firedAt': _iso(failedRunAt), 'manual': true},
        'fetch_pulls': const {'kind': 'pulls', 'count': 0},
        'fetch_issues': const {'kind': 'issues', 'count': 0},
      },
      errors: {
        'fetch_commits':
            'HandlerError: $fnFetchGithubName: 502 Bad Gateway (api.github.com) — GET /repos/Cookiezisg/Anselm/commits, no retry in v1',
      },
      doneAfterSec: const {
        'start': 0,
        'fetch_commits': 4,
        'fetch_pulls': 3,
        'fetch_issues': 3,
      },
    ),
  };

  final parkedRun = {
    'flowrun': {
      'id': frDigestParked,
      'workflowId': wfDigest,
      'versionId': _wfv1,
      'status': 'running',
      'replayCount': 0,
      'pinnedRefs': {
        'fetch_commits': _fnv2,
        'fetch_pulls': _fnv2,
        'fetch_issues': _fnv2,
      },
      'triggerId': '',
      'startedAt': _iso(parkedRunAt),
      'createdAt': _iso(parkedRunAt),
      'updatedAt': _iso(parkedRunAt.add(const Duration(seconds: 41))),
    },
    'workflowName': wfDigestName,
    'nodes': _digestRunNodes(
      l,
      frDigestParked,
      parkedRunAt,
      results: {
        'start': {'firedAt': _iso(parkedRunAt), 'manual': true},
        'fetch_commits': _fetchResultV2(),
        'fetch_pulls': const {
          'kind': 'pulls',
          'count': 0,
          'period': {'since': '2026-08-30', 'until': '2026-09-13'},
        },
        'fetch_issues': const {
          'kind': 'issues',
          'count': 0,
          'period': {'since': '2026-08-30', 'until': '2026-09-13'},
        },
        'write_digest': {
          'headline': l.t(
            'Acceptance matrix advanced to batch 90, no regressions',
            '验收矩阵推进到 batch 90,未见回归',
          ),
          'words': 412,
        },
        'check_activity': const {
          '__port': 'has_activity',
          'commits': 32,
          'pulls': 0,
          'issues': 0,
        },
        // The parked approval quotes the SHORT approval body (bible), never the whole digest.
        // 停车中的审批只引用短正文(总纲),不放整篇周报。
        'review': {'rendered': digestApprovalBody(l), 'allowReason': true},
      },
      doneAfterSec: const {
        'start': 0,
        'fetch_commits': 9,
        'fetch_pulls': 4,
        'fetch_issues': 4,
        'write_digest': 41,
        'check_activity': 41,
      },
    ),
  };

  return (
    conv: _conv(
      cv,
      cvDigestTitle(l),
      fixAt,
      created: askAt.subtract(const Duration(minutes: 1)),
      pinned: true,
    ),
    messages: [
      _user(
        'msg_dg_u1',
        cv,
        askAt,
        l.t(
          'Every Monday at 9 I want a digest of what happened in Cookiezisg/Anselm on GitHub over the last two weeks — commits, merged PRs, issues. Write it up as a document, but let me review it before it lands in the Weekly digests folder.',
          '每周一早上 9 点,我想收到一份 Cookiezisg/Anselm 这个 GitHub 仓库过去两周的周报——提交、合并的 PR、issue 都要。写成文档,但发进「每周周报」文件夹之前先让我审一下。',
        ),
      ),
      _bot('msg_dg_a1', cv, buildAt, tokensIn: 2860, tokensOut: 3410, [
        txt(
          'blk_dg_r1',
          'reasoning',
          l.t(
            'Five capabilities are needed and each maps to one entity: a function to fetch GitHub activity (called three times in parallel — commits, pulls, issues), an agent to write prose from the join, a cron trigger for Monday 09:00, a control that routes an empty week away from review, and an approval so the user reviews before filing. The existing slack_notifier handler closes both branches: post_digest after filing, post_message when the week is empty. A workflow wires them: trigger → three fetches → digest → check_activity → review → file → Slack. I will create bottom-up so every reference resolves, then run it once by hand to prove the path.',
            '需要五种能力,各对应一个实体:拉 GitHub 活动的函数(并行调用三次——提交、PR、issue)、把汇合结果写成文字的 agent、周一 09:00 的 cron 触发器、把空周绕过审阅的控制节点,以及归档前让用户审阅的审批。已有的 slack_notifier handler 收尾两条分支:归档后 post_digest,空周时 post_message。再用一个工作流串起来:触发 → 三路拉取 → 写周报 → check_activity → 审阅 → 归档 → Slack。按自下而上的顺序建,保证每个引用都能解析,最后手动跑一次验证链路。',
          ),
        ),
        txt(
          'blk_dg_t1',
          'text',
          l.t(
            'Here is the plan: one function pulls commits, PRs and issues (three fetches run in parallel), one agent writes the digest, a Monday cron kicks it off, a small control skips the review when the week is empty, and an approval holds the document until you sign off. Once filed, the existing Slack notifier posts it to #product-team. I will build them in that order and run the whole thing once so you can see it work.',
            '方案是这样:一个函数分别拉提交、PR 和 issue(三路并行),一个 agent 写周报,周一的 cron 负责触发,一个小控制节点在空周时跳过审阅,再加一道审批把文档拦在你签字之前。归档后由已有的 Slack 通知器发到 #product-team。我按这个顺序建,建完整体跑一次给你看。',
          ),
        ),
        tc(
          'dg_todo1',
          'todo_write',
          _j({'items': todoV1}),
          summary: l.t('Lay out the build checklist', '列出建造清单'),
        ),
        tr(
          'dg_todo1',
          l.t(
            '- [→] Creating the fetch function\n- [ ] Create the digest-writing agent\n- [ ] Create the Monday 09:00 trigger\n- [ ] Create the review approval\n- [ ] Create the empty-week control\n- [ ] Wire the workflow and run it once\nKeep exactly one task in_progress; mark a task completed as soon as it is done.',
            '- [→] 正在建拉取函数\n- [ ] 建写周报的 agent\n- [ ] 建周一 09:00 触发器\n- [ ] 建审阅审批\n- [ ] 建空周判断控制\n- [ ] 串成工作流并跑一次\nKeep exactly one task in_progress; mark a task completed as soon as it is done.',
          ),
        ),
        tc(
          'dg_fn',
          'create_function',
          _j({
            'ops': [
              {
                'op': 'set_meta',
                'name': fnFetchGithubName,
                'description': l.t(
                  'Fetch commits, merged PRs and issues for a GitHub repo over a date window.',
                  '按日期窗口拉取一个 GitHub 仓库的提交、已合并 PR 与 issue。',
                ),
                'tags': ['github', 'digest'],
              },
              {
                'op': 'set_inputs',
                'inputs': [
                  {'name': 'repo', 'type': 'string'},
                  {'name': 'since', 'type': 'string'},
                  {'name': 'until', 'type': 'string'},
                ],
              },
              {
                'op': 'set_outputs',
                'outputs': [
                  {'name': 'commits', 'type': 'array'},
                  {'name': 'pullRequests', 'type': 'array'},
                  {'name': 'period', 'type': 'object'},
                ],
              },
              {
                'op': 'set_dependencies',
                'dependencies': ['requests==2.32.3', 'python-dateutil==2.9.1'],
              },
              {'op': 'set_code', 'code': _fetchCodeV1},
            ],
            'changeReason': l.t(
              'New: GitHub activity fetch for the weekly digest',
              '新建:周报用的 GitHub 活动拉取',
            ),
          }),
          summary: l.t(
            'Create fetch_github_activity; the sandbox env needed one dependency fix',
            '新建 fetch_github_activity,沙箱环境自动修了一次依赖',
          ),
          danger: 'cautious',
        ),
        _progress(
          'dg_fn',
          l.t(
            'Resolving sandbox env · attempt 2/3 · pinning python-dateutil==2.9.0.post0',
            '解析沙箱环境 · 第 2/3 次 · 钉住 python-dateutil==2.9.0.post0',
          ),
        ),
        tr(
          'dg_fn',
          _j({
            'id': fnFetchGithub,
            'versionId': _fnv1,
            'version': 1,
            'envStatus': 'ready',
            'opsApplied': 5,
            'envFixAttempts': [
              {
                'attempt': 1,
                'deps': ['requests==2.32.3', 'python-dateutil==2.9.1'],
                'ok': false,
                'error':
                    'ERROR: No matching distribution found for python-dateutil==2.9.1',
              },
              {
                'attempt': 2,
                'deps': ['requests==2.32.3', 'python-dateutil==2.9.0.post0'],
                'ok': true,
              },
            ],
          }),
        ),
        tc(
          'dg_ag',
          'create_agent',
          _j({
            'name': agDigestName,
            'description': l.t(
              'Turn raw GitHub activity into a readable weekly digest in Markdown.',
              '把原始 GitHub 活动整理成可读的 Markdown 周报。',
            ),
            'prompt': l.t(
              'You write the weekly engineering digest for the Product Team. Input is the JSON output of fetch_github_activity. Group commits by theme, name the authors, call out fixes separately, and end with 2-3 highlights. Never invent work that is not in the input.',
              '你负责给产品团队写每周工程周报。输入是 fetch_github_activity 的 JSON 输出。按主题归组提交、写明作者、缺陷修复单列,结尾给 2-3 条亮点。绝不编造输入里没有的工作。',
            ),
            'tools': [
              {'ref': docHandbook, 'name': 'read_document'},
            ],
            'inputs': [
              {'name': 'activity', 'type': 'object'},
            ],
            'outputs': [
              {'name': 'headline', 'type': 'string'},
              {'name': 'markdown', 'type': 'string'},
            ],
          }),
          summary: l.t(
            'Create write_weekly_digest with a structured headline + markdown output',
            '新建 write_weekly_digest,输出结构化的 headline + markdown',
          ),
          danger: 'cautious',
        ),
        tr('dg_ag', _j({'id': agDigest, 'versionId': _agv1, 'version': 1})),
        tc(
          'dg_trg',
          'create_trigger',
          _j({
            'name': trgMondayName,
            'description': l.t(
              'Every Monday 09:00 local time.',
              '每周一本地时间 09:00。',
            ),
            'kind': 'cron',
            'config': {'expression': '0 9 * * 1', 'timezone': 'Asia/Shanghai'},
          }),
          summary: l.t(
            'Create the Monday 09:00 cron; it starts listening once a workflow that uses it is active',
            '新建周一 09:00 的 cron;引用它的工作流激活后才开始监听',
          ),
          danger: 'cautious',
        ),
        tr(
          'dg_trg',
          _j({
            'id': trgMonday,
            'name': trgMondayName,
            'kind': 'cron',
            'config': {'expression': '0 9 * * 1', 'timezone': 'Asia/Shanghai'},
            'outputs': [
              {
                'name': 'firedAt',
                'type': 'string',
                'description': 'When the trigger fired (RFC3339).',
              },
            ],
            'refCount': 0,
            'listening': false,
            'nextFireAt': _iso(ahead(hours: 11)),
            'createdAt': _iso(buildAt),
            'updatedAt': _iso(buildAt),
          }),
        ),
        tc(
          'dg_apf',
          'create_approval',
          _j({
            'name': apfDigestName,
            'description': l.t(
              'A human reads the digest before it is filed.',
              '周报归档前由人读一遍。',
            ),
            'inputs': [
              {'name': 'headline', 'type': 'string'},
              {'name': 'markdown', 'type': 'string'},
            ],
            'template':
                '## {{ input.headline }}\n\n{{ input.markdown }}\n\n---\n${l.t('Approve to file this digest under Weekly digests.', '批准后归档到「每周周报」。')}',
            'allowReason': true,
            'timeout': '72h',
            'timeoutBehavior': 'reject',
          }),
          summary: l.t(
            'Create review_weekly_digest — 72h to decide, silence rejects',
            '新建 review_weekly_digest——72 小时内决定,超时视为驳回',
          ),
        ),
        tr(
          'dg_apf',
          _j({
            'id': apfDigest,
            'name': apfDigestName,
            'activeVersionId': _apfv1,
            'version': 1,
          }),
        ),
        tc(
          'dg_ctl',
          'create_control',
          _j({
            'name': ctlEmptyWeekName,
            'description': l.t(
              'Route an empty week away from review: has_activity when any of the three fetches found something, otherwise empty.',
              '把空周绕过审阅:三路拉取任一有内容走 has_activity,否则走 empty。',
            ),
            'inputs': [
              {'name': 'commits', 'type': 'number'},
              {'name': 'pulls', 'type': 'number'},
              {'name': 'issues', 'type': 'number'},
            ],
            'branches': [
              {
                'port': 'has_activity',
                'when':
                    'input.commits > 0 || input.pulls > 0 || input.issues > 0',
                'emit': {'total': 'input.commits + input.pulls + input.issues'},
              },
              {'port': 'empty', 'when': 'true'},
            ],
          }),
          summary: l.t(
            'Create check_activity — has_activity when any count is above zero, empty otherwise',
            '新建 check_activity——任一计数大于零走 has_activity,否则走 empty',
          ),
          danger: 'cautious',
        ),
        tr(
          'dg_ctl',
          _j({
            'id': ctlEmptyWeek,
            'name': ctlEmptyWeekName,
            'activeVersionId': _ctlv1,
            'version': 1,
          }),
        ),
        tc(
          'dg_wf',
          'create_workflow',
          _j({
            'name': wfDigestName,
            'description': l.t(
              'Monday GitHub digest: three parallel fetches → write → check activity → review → file → Slack.',
              '周一 GitHub 周报:三路并行拉取 → 写作 → 活动判断 → 审阅 → 归档 → Slack。',
            ),
            'ops': digestOps(l),
            'concurrency': 'skip',
            'changeReason': l.t(
              'New: weekly GitHub digest pipeline',
              '新建:每周 GitHub 周报流水线',
            ),
          }),
          summary: l.t(
            'Create weekly_github_digest — 10 nodes, 11 edges: three fetches run in parallel, check_activity routes has_activity | empty, the approval\'s yes port leads to prepare_doc → notify_team',
            '新建 weekly_github_digest——10 个节点、11 条边:三路拉取并行,check_activity 分流 has_activity | empty,审批的 yes 端口通向 prepare_doc → notify_team',
          ),
          danger: 'cautious',
        ),
        tr(
          'dg_wf',
          _j({
            'id': wfDigest,
            'versionId': _wfv1,
            'version': 1,
            'active': false,
            'lifecycleState': 'inactive',
          }),
        ),
        _tcNamed(
          'dg_act',
          'activate_workflow',
          {'workflowId': wfDigest},
          entityName: wfDigestName,
          summary: l.t(
            'Activate it so the Monday cron starts listening',
            '激活,让周一的 cron 开始监听',
          ),
          danger: 'cautious',
        ),
        tr(
          'dg_act',
          _j({
            'id': wfDigest,
            'name': wfDigestName,
            'active': true,
            'lifecycleState': 'active',
            'version': 1,
          }),
        ),
        _tcNamed(
          'dg_run1',
          'trigger_workflow',
          {
            'workflowId': wfDigest,
            'payload': {'repo': 'Cookiezisg/Anselm'},
          },
          entityName: wfDigestName,
          summary: l.t(
            'Run it once by hand to prove the path end to end',
            '手动跑一次,把链路从头到尾验证一遍',
          ),
        ),
        tr(
          'dg_run1',
          _j({'flowrunId': frDigestFailed, 'workflowId': wfDigest}),
        ),
        _tcNamed(
          'dg_get1',
          'get_flowrun',
          {'flowrunId': frDigestFailed},
          entityName: wfDigestName,
          summary: l.t(
            'The run stopped at fetch_commits — read the node ledger',
            'run 停在 fetch_commits 节点——看节点台账',
          ),
        ),
        tr('dg_get1', _j(failedRun)),
        txt(
          'blk_dg_t2',
          'text',
          l.t(
            'Everything is built and the workflow is active, but the first manual run **failed at `fetch_commits`**: GitHub answered **502 Bad Gateway** on `/commits`, and `fetch_github_activity` v1 has no retry, so the node gave up on the first response. `fetch_pulls` and `fetch_issues` — same function, run in parallel — completed (both empty), but `write_digest` never started because the join was missing its commits, so there is no half-written digest. Want me to add 5xx / rate-limit backoff to the function and run it again?',
            '所有实体都建好了,工作流也已激活,但第一次手动 run **在 `fetch_commits` 失败了**:GitHub 在 `/commits` 上返回了 **502 Bad Gateway**,而 `fetch_github_activity` v1 没有重试,节点在第一次响应就放弃了。`fetch_pulls` 和 `fetch_issues`(同一个函数,并行跑)都跑完了(都是空的),但汇合缺了提交那一路,`write_digest` 没有启动,所以不会有半截周报。要我给函数加上 5xx / 限流退避重试再跑一次吗?',
          ),
        ),
      ]),
      _user(
        'msg_dg_u2',
        cv,
        fixAskAt,
        l.t(
          'Yes — fix it and run it again. Also make the date window default to the last two weeks so the cron payload can stay empty.',
          '好,修一下再跑。顺便把日期窗口默认成最近两周,这样 cron 的 payload 可以留空。',
        ),
      ),
      _bot('msg_dg_a2', cv, fixAt, tokensIn: 5120, tokensOut: 1880, [
        txt(
          'blk_dg_r2',
          'reasoning',
          l.t(
            'Two changes in one version: wrap the GitHub calls in a retry with exponential backoff (3 attempts, 1s/2s/4s) on 5xx and 429, and derive since/until from today when absent. Then trigger a fresh run rather than replaying the failed one, because the pinned function version must advance to v2.',
            '一个版本里改两处:把 GitHub 调用包进指数退避重试(3 次,1s/2s/4s,针对 5xx 与 429),缺省时用今天推算 since/until。然后触发一次新 run 而不是重放失败的那次,因为被钉住的函数版本要推进到 v2。',
          ),
        ),
        _tcNamed(
          'dg_fix',
          'edit_function',
          {
            'functionId': fnFetchGithub,
            'ops': [
              {
                'op': 'set_meta',
                'description': l.t(
                  'Fetch commits, merged PRs and issues for a GitHub repo over a date window; retries 5xx and rate-limit responses with exponential backoff (3 attempts).',
                  '按日期窗口拉取一个 GitHub 仓库的提交、已合并 PR 与 issue;对 5xx 与限流响应做指数退避重试(3 次)。',
                ),
              },
              {'op': 'set_code', 'code': _fetchCodeV2},
            ],
            'changeReason': l.t(
              'Retry 5xx / rate-limit with exponential backoff (3 attempts); default the window to the trailing two weeks',
              '5xx / 限流指数退避重试(3 次);窗口默认最近两周',
            ),
          },
          entityName: fnFetchGithubName,
          summary: l.t(
            'v2: 5xx / rate-limit retry with backoff + a two-week default window',
            'v2:5xx / 限流退避重试 + 默认两周窗口',
          ),
          danger: 'cautious',
        ),
        tr(
          'dg_fix',
          _j({
            'id': fnFetchGithub,
            'versionId': _fnv2,
            'version': 2,
            'envStatus': 'ready',
            'opsApplied': 2,
          }),
        ),
        _tcNamed(
          'dg_run2',
          'trigger_workflow',
          {
            'workflowId': wfDigest,
            'payload': {'repo': 'Cookiezisg/Anselm'},
          },
          entityName: wfDigestName,
          summary: l.t('Run again on v2', '用 v2 再跑一次'),
        ),
        tr(
          'dg_run2',
          _j({'flowrunId': frDigestParked, 'workflowId': wfDigest}),
        ),
        _tcNamed(
          'dg_get2',
          'get_flowrun',
          {'flowrunId': frDigestParked},
          entityName: wfDigestName,
          summary: l.t(
            'All three fetches, write_digest and check_activity completed; the run is parked at review',
            '三路拉取、write_digest 与 check_activity 已完成;run 停车在 review 节点',
          ),
        ),
        tr('dg_get2', _j(parkedRun)),
        tc(
          'dg_todo2',
          'todo_write',
          _j({'items': todoDone}),
          summary: l.t('Close the checklist', '收清单'),
        ),
        tr(
          'dg_todo2',
          l.t(
            '- [x] Create the GitHub fetch function\n- [x] Create the digest-writing agent\n- [x] Create the Monday 09:00 trigger\n- [x] Create the review approval\n- [x] Create the empty-week control\n- [x] Wire the workflow and run it once\n- [→] Waiting for the digest review\nKeep exactly one task in_progress; mark a task completed as soon as it is done.',
            '- [x] 建 GitHub 拉取函数\n- [x] 建写周报的 agent\n- [x] 建周一 09:00 触发器\n- [x] 建审阅审批\n- [x] 建空周判断控制\n- [x] 串成工作流并跑一次\n- [→] 正在等周报审阅\nKeep exactly one task in_progress; mark a task completed as soon as it is done.',
          ),
        ),
        txt(
          'blk_dg_t3',
          'text',
          l.t(
            'Fixed and re-run. The three fetches ran in parallel on `fetch_github_activity` v2 over **Aug 30 – Sep 13**: **32 commits, 0 merged PRs, 0 issues** — all from $authorName, mostly acceptance-batch closures plus two UI fixes. `write_digest` turned that into a 412-word digest, `check_activity` chose `has_activity`, and the run is now **parked at `review`** waiting for you; `prepare_doc` and `notify_team` have not run. Approve it from the notification or the Scheduler and it will be filed under Weekly digests and posted to #product-team. The Monday cron is listening; next fire is in about 11 hours.',
            '修好并重跑了。三路拉取在 `fetch_github_activity` v2 上并行跑完,窗口 **8 月 30 日 – 9 月 13 日**:**32 次提交、0 个合并 PR、0 个 issue**——全部来自 $authorName,主要是验收批次的收口加两个 UI 修复。`write_digest` 据此写了一篇 412 字的周报,`check_activity` 走了 `has_activity`,run 现在**停在 `review`** 等你;`prepare_doc` 和 `notify_team` 尚未执行。在通知或调度页批准后,它会归档到「每周周报」并发到 #product-team。周一的 cron 已在监听,下次触发大约在 11 小时后。',
          ),
        ),
      ]),
    ],
  );
}

// ───────────────────────── 2 · generating (blue pulse) ─────────────────────────

_Thread _triage(StoryLocale l) {
  const cv = cvTriage;
  final askAt = ago(minutes: 3);
  final at = ago(minutes: 1);
  return (
    conv: _conv(cv, cvTriageTitle(l), at, generating: true),
    messages: [
      _user(
        'msg_tr_u1',
        cv,
        askAt,
        l.t(
          '14 Zendesk tickets came in overnight. Triage them by severity and draft replies for anything P1.',
          '昨晚进来了 14 张 Zendesk 工单。按严重度分一下,P1 的先把回复草稿写好。',
        ),
      ),
      _bot('msg_tr_a1', cv, at, status: 'streaming', [
        txt(
          'blk_tr_r1',
          'reasoning',
          l.t(
            'The triage agent already owns this: it reads tickets through postgres_reader, scores severity with route_by_severity, and drafts replies. Invoke it with the overnight window rather than re-implementing the logic inline.',
            '分诊 agent 本来就管这件事:它通过 postgres_reader 读工单、用 route_by_severity 定严重度、再写回复草稿。直接按昨晚的时间窗调用它,不在这里重新实现一遍。',
          ),
        ),
        txt(
          'blk_tr_t1',
          'text',
          l.t(
            'Handing the batch to `triage_support_ticket` — it will pull the overnight tickets, score them, and draft the P1 replies.',
            '把这一批交给 `triage_support_ticket`——它会拉昨晚的工单、打分,并给 P1 写好回复草稿。',
          ),
        ),
        _tcNamed(
          'tr_inv',
          'invoke_agent',
          {
            'agentId': agTriage,
            'input': {'since': _iso(ago(hours: 14)), 'queue': 'support'},
          },
          entityName: agTriageName,
          summary: l.t('Triage the 14 overnight tickets', '分诊昨晚的 14 张工单'),
        ),
        // The E3 nested shape: the agent turn is a `message` wrapper under the call, still open, and its
        // trajectory hangs below it. E3 嵌套形:agent 回合是挂在调用下、仍开着的 message 包装,轨迹挂其下。
        const ChatBlock(
          id: 'tr_inv_msg',
          parentBlockId: 'tr_inv',
          type: 'message',
          status: 'streaming',
          content: '',
          attrs: {'role': 'assistant', 'subagent': true},
        ),
        ChatBlock(
          id: 'tr_inv_n1',
          parentBlockId: 'tr_inv_msg',
          type: 'reasoning',
          status: 'completed',
          content: l.t(
            'Pull the ticket rows first, then score each one.',
            '先把工单行拉出来,再逐张打分。',
          ),
        ),
        ChatBlock(
          id: 'tr_inv_n2',
          parentBlockId: 'tr_inv_msg',
          type: 'tool_call',
          status: 'completed',
          content: _j({
            'handlerId': hdPostgres,
            'method': 'query',
            'args': {
              'sql':
                  "SELECT id, subject, plan, created_at FROM tickets WHERE created_at > now() - interval '14 hours' ORDER BY created_at",
            },
          }),
          attrs: {
            'tool': 'call_handler',
            'entityName': hdPostgresName,
            'summary': l.t('Read the overnight tickets', '读昨晚的工单'),
            'danger': 'safe',
          },
        ),
        ChatBlock(
          id: 'tr_tr_inv_n2',
          parentBlockId: 'tr_inv_n2',
          type: 'tool_result',
          status: 'completed',
          content: _j({
            'result': {
              'rows': 14,
              'sample': [
                {
                  'id': 'ZD-30417',
                  'subject': 'Checkout returns 502 for EU customers',
                  'plan': 'enterprise',
                },
                {
                  'id': 'ZD-30421',
                  'subject': 'Cannot export invoices as CSV',
                  'plan': 'team',
                },
                {
                  'id': 'ZD-30425',
                  'subject': 'Dark mode toggle resets on restart',
                  'plan': 'free',
                },
              ],
            },
          }),
        ),
        ChatBlock(
          id: 'tr_inv_n3',
          parentBlockId: 'tr_inv_msg',
          type: 'text',
          status: 'streaming',
          content: l.t(
            'Scoring 14 tickets. ZD-30417 is a P1 — an enterprise checkout outage affecting EU traffic. ZD-30421 looks P2; drafting the P1 reply now with the workaround from the Support playbook',
            '正在给 14 张工单打分。ZD-30417 是 P1——企业客户的结账故障,影响欧洲流量。ZD-30421 看起来是 P2;现在按客服手册里的临时方案给 P1 写回复',
          ),
        ),
      ]),
    ],
  );
}

// ───────────────────────── 3 · awaiting input (amber) ─────────────────────────

/// The three refund options — shared by the ask_user block and its pending interaction row, which must
/// agree byte for byte or the gate shows one set of pills and the transcript another.
/// 三个退款选项——ask_user 块与待决交互行共用,两者必须逐字一致,否则门上一套药丸、transcript 另一套。
List<String> _refundOptions(StoryLocale l) => [
  l.t('Full refund ¥1,260', '全额退款 ¥1,260'),
  l.t('Partial refund ¥630 (deduct shipping)', '部分退款 ¥630(扣运费)'),
  l.t('Decline — outside the 30-day window', '拒绝——超出 30 天窗口'),
];

String _refundQuestion(StoryLocale l) => l.t(
  'Order #4821 is 34 days old, ¥1,260, one earlier refund on this account. How should I handle it?',
  '订单 #4821 已下单 34 天,金额 ¥1,260,该账户此前有过一次退款。怎么处理?',
);

_Thread _refund(StoryLocale l) {
  const cv = cvRefund;
  final askAt = ago(minutes: 9);
  final at = ago(minutes: 6);
  return (
    conv: _conv(cv, cvRefundTitle(l), at, awaiting: true),
    messages: [
      _user(
        'msg_rf_u1',
        cv,
        askAt,
        l.t(
          'A customer wants a refund on order #4821. Look it up, hold the order, and tell me what you recommend.',
          '有客户要退订单 #4821。查一下,把订单先冻结,再告诉我你的建议。',
        ),
      ),
      _bot('msg_rf_a1', cv, at, status: 'streaming', [
        txt(
          'blk_rf_r1',
          'reasoning',
          l.t(
            'Read the order through postgres_reader first. Holding the order is a write, so it goes through the danger gate. The decision itself is the user\'s — offer the three policy-consistent options instead of choosing.',
            '先通过 postgres_reader 读订单。冻结订单是写操作,要走危险门。决定本身是用户的——给出三个符合政策的选项,而不是替他选。',
          ),
        ),
        _tcNamed(
          'rf_q',
          'call_handler',
          {
            'handlerId': hdPostgres,
            'method': 'query',
            'args': {
              'sql':
                  'SELECT id, total_cents, placed_at, status, customer_refunds FROM orders WHERE id = 4821',
            },
          },
          entityName: hdPostgresName,
          summary: l.t('Look up order #4821', '查订单 #4821'),
        ),
        tr(
          'rf_q',
          _j({
            'result': {
              'rows': [
                {
                  'id': 4821,
                  'total_cents': 126000,
                  'placed_at': _iso(ago(days: 34, hours: 5)),
                  'status': 'delivered',
                  'customer_refunds': 1,
                },
              ],
            },
          }),
        ),
        tc(
          'rf_hold',
          'Bash',
          _j({
            'command':
                'psql "\$DATABASE_URL" -c "UPDATE orders SET status = \'refund_pending\' WHERE id = 4821"',
          }),
          summary: l.t(
            'Hold the order so it cannot ship again while we decide',
            '先冻结订单,决定期间不会再发货',
          ),
          danger: 'dangerous',
        ),
        tr('rf_hold', 'UPDATE 1\n\n[exit code: 0]'),
        tc(
          'rf_ask',
          'ask_user',
          _j({'message': _refundQuestion(l), 'options': _refundOptions(l)}),
          summary: l.t('Ask which refund policy to apply', '问用哪条退款政策'),
        ),
      ]),
    ],
  );
}

// ───────────────────────── 4 · attachments + media receipts ─────────────────────────

const _attHeroDesktop = 'att_1a7c3e9b5d2f4068';
const _attHeroMobile = 'att_2b8d4f0c6e3a5179';
const _attHeroOg = 'att_3c9e5a1d7f4b6280';
const _attOutDesktop = 'att_4d0f6b2e8a5c7391';
const _attOutMobile = 'att_5e1a7c3f9b6d8402';
const _attOutOg = 'att_6f2b8d4a0c7e9513';
const _attOgCropped = 'att_7a3c9e5b1d8f0624';

_Thread _heroImages(StoryLocale l) {
  const cv = cvHeroImages;
  final askAt = ago(hours: 3, minutes: 4);
  final at = ago(hours: 3);
  Map<String, Object?> resizeArgs(String id, int maxWidth) => {
    'functionId': fnResizeImage,
    'args': {
      'attachmentId': id,
      'maxWidth': maxWidth,
      'format': 'webp',
      'quality': 82,
    },
  };
  Map<String, Object?> resizeOut(
    String outId,
    String filename,
    int w,
    int h,
    int bytes,
    int ms,
  ) => {
    'ok': true,
    'output': {
      'attachmentId': outId,
      'filename': filename,
      'mime': 'image/webp',
      'width': w,
      'height': h,
      'sizeBytes': bytes,
    },
    'errorMsg': '',
    'elapsedMs': ms,
    'logs': 'decode ok\nresize → ${w}x$h (lanczos3)\nencode webp q=82\ndone',
  };
  return (
    conv: _conv(cv, cvHeroImagesTitle(l), at, workDir: storySiteDir),
    messages: [
      _user(
        'msg_hi_u1',
        cv,
        askAt,
        l.t(
          'These three hero images are way too heavy for the launch page. Bring each one down to at most 1600px wide as WebP, and give me a 1.91:1 crop of the OG image for social cards.',
          '这三张首屏图对发布页来说太重了。每张压到最宽 1600px 的 WebP,另外把 OG 图裁一版 1.91:1 给社交卡片用。',
        ),
        attachments: const [_attHeroDesktop, _attHeroMobile, _attHeroOg],
      ),
      _bot('msg_hi_a1', cv, at, tokensIn: 1940, tokensOut: 760, [
        txt(
          'blk_hi_r1',
          'reasoning',
          l.t(
            'The resize_image function already exists in this workspace, so run it once per attachment. The social crop is an edit, not a resize — edit_image with the OG file as the source.',
            'workspace 里已经有 resize_image 函数,按附件各跑一次即可。社交裁图是编辑不是缩放——用 edit_image,以 OG 图为源。',
          ),
        ),
        txt(
          'blk_hi_t1',
          'text',
          l.t(
            'Running `resize_image` on each file, then cropping the OG image for social.',
            '对每个文件跑 `resize_image`,然后把 OG 图裁成社交版。',
          ),
        ),
        _tcNamed(
          'hi_r1',
          'run_function',
          resizeArgs(_attHeroDesktop, 1600),
          entityName: fnResizeImageName,
          summary: l.t(
            'hero-desktop.png → 1600w WebP',
            'hero-desktop.png → 1600 宽 WebP',
          ),
        ),
        tr(
          'hi_r1',
          _j(
            resizeOut(
              _attOutDesktop,
              'hero-desktop@1600.webp',
              1600,
              900,
              148_212,
              611,
            ),
          ),
        ),
        _tcNamed(
          'hi_r2',
          'run_function',
          resizeArgs(_attHeroMobile, 1200),
          entityName: fnResizeImageName,
          summary: l.t(
            'hero-mobile.jpg → 1200w WebP',
            'hero-mobile.jpg → 1200 宽 WebP',
          ),
        ),
        tr(
          'hi_r2',
          _j(
            resizeOut(
              _attOutMobile,
              'hero-mobile@1200.webp',
              1200,
              2601,
              203_884,
              842,
            ),
          ),
        ),
        _tcNamed(
          'hi_r3',
          'run_function',
          resizeArgs(_attHeroOg, 1600),
          entityName: fnResizeImageName,
          summary: l.t('hero-og.png → 1600w WebP', 'hero-og.png → 1600 宽 WebP'),
        ),
        tr(
          'hi_r3',
          _j(
            resizeOut(_attOutOg, 'hero-og@1600.webp', 1600, 840, 131_507, 588),
          ),
        ),
        tc(
          'hi_crop',
          'edit_image',
          _j({
            'attachmentId': _attHeroOg,
            'prompt': l.t(
              'Crop to 1.91:1 centred on the product, keep the wordmark fully visible',
              '以产品为中心裁成 1.91:1,字标完整保留',
            ),
            'aspect': '1.91:1',
          }),
          summary: l.t('Social crop of the OG image', 'OG 图的社交裁版'),
          danger: 'cautious',
        ),
        tr(
          'hi_crop',
          _j({
            'attachmentId': _attOgCropped,
            'sourceAttachmentId': _attHeroOg,
            'filename': 'hero-og-social.png',
            'mime': 'image/png',
            'sizeBytes': 412_960,
            'provider': 'anselm',
            'model': 'image-edit-1',
            'aspect': '1.91:1',
            'width': 1200,
            'height': 628,
            'source': 'edit_image',
          }),
        ),
        txt(
          'blk_hi_t2',
          'text',
          l.t(
            'Done — three WebP files at **148 KB, 204 KB and 132 KB** (down from 2.4 MB, 1.1 MB and 1.8 MB), plus `hero-og-social.png` at 1200×628 for Open Graph cards. They are attached above; drop them into `public/hero/` and the launch page should be well under budget.',
            '好了——三个 WebP 分别是 **148 KB、204 KB、132 KB**(原来是 2.4 MB、1.1 MB、1.8 MB),另加一张 1200×628 的 `hero-og-social.png` 给 Open Graph 卡片。都在上面的卡片里;放进 `public/hero/` 后发布页应该远低于预算。',
          ),
        ),
      ]),
    ],
  );
}

// ───────────────────────── 5 · error terminal (red) ─────────────────────────

_Thread _flakyTest(StoryLocale l) {
  const cv = cvFlakyTest;
  final askAt = ago(hours: 7, minutes: 12);
  final at = ago(hours: 7);
  const testPath =
      '$storyRepoDir/backend/functions/tests/test_parse_invoice_pdf.py';
  const traceback =
      'Traceback (most recent call last):\n'
      '  File "parse_invoice_pdf.py", line 41, in main\n'
      '    total = _sum_lines(page.extract_table())\n'
      '  File "parse_invoice_pdf.py", line 18, in _sum_lines\n'
      '    return round(sum(Decimal(r[3]) for r in rows[1:]), 2)\n'
      'decimal.InvalidOperation: [<class \'decimal.ConversionSyntax\'>]';
  return (
    conv: _conv(cv, cvFlakyTestTitle(l), at, workDir: storyRepoDir),
    messages: [
      _user(
        'msg_ft_u1',
        cv,
        askAt,
        l.t(
          '`test_parse_invoice_pdf::test_totals` fails on roughly every third CI run. Find out why and fix it.',
          '`test_parse_invoice_pdf::test_totals` 大概每三次 CI 挂一次。查一下原因并修掉。',
        ),
      ),
      _bot(
        'msg_ft_a1',
        cv,
        at,
        status: 'error',
        stopReason: 'error',
        errorCode: 'SANDBOX_CRASHED',
        errorMessage: l.t(
          'sandbox worker for parse_invoice_pdf exited with signal 9 (out of memory) while the turn was running',
          'parse_invoice_pdf 的沙箱工作进程在回合进行中以信号 9(内存耗尽)退出',
        ),
        tokensIn: 4120,
        tokensOut: 920,
        [
          txt(
            'blk_ft_r1',
            'reasoning',
            l.t(
              'Intermittent failures in a parser usually mean input-order or locale dependence. Read the test, then run the function on the fixture PDF that the failing case uses.',
              '解析器的间歇性失败,通常是依赖输入顺序或 locale。先读测试,再用失败用例用的那份 PDF 夹具跑一次函数。',
            ),
          ),
          tc(
            'ft_grep',
            'Grep',
            _j({
              'pattern': 'def test_totals',
              'path': '$storyRepoDir/backend/functions/tests',
              'output_mode': 'content',
              '-n': true,
            }),
            summary: l.t('Locate the failing test', '定位失败的测试'),
          ),
          tr('ft_grep', '$testPath:57:def test_totals(sample_pdf):'),
          tc(
            'ft_read',
            'Read',
            _j({'file_path': testPath, 'offset': 50, 'limit': 20}),
            summary: l.t('Read the test body', '读测试正文'),
          ),
          tr(
            'ft_read',
            '50\t@pytest.fixture\n'
                '51\tdef sample_pdf():\n'
                '52\t    return random.choice(sorted(FIXTURES.glob("*.pdf")))\n'
                '53\t\n'
                '54\t\n'
                '57\tdef test_totals(sample_pdf):\n'
                '58\t    out = main(sample_pdf.read_bytes())\n'
                '59\t    assert out["total"] == EXPECTED[sample_pdf.name]\n',
          ),
          tc(
            'ft_pytest',
            'Bash',
            _j({
              'command':
                  'pytest -q backend/functions/tests/test_parse_invoice_pdf.py -k test_totals -p no:randomly',
            }),
            summary: l.t('Run the test locally', '本地跑一次这个测试'),
            danger: 'cautious',
          ),
          tr(
            'ft_pytest',
            '.F                                                                       [100%]\n'
                '=================================== FAILURES ===================================\n'
                '__________________________________ test_totals _________________________________\n'
                'AssertionError: assert None == Decimal(\'4820.00\')\n'
                '  where None = main(<bytes of invoice_eu_2026-07.pdf>)["total"]\n'
                '1 failed, 1 passed in 3.41s\n\n[exit code: 1]',
          ),
          _tcNamed(
            'ft_run',
            'run_function',
            {
              'functionId': fnParseInvoice,
              'args': {'attachmentPath': 'fixtures/invoice_eu_2026-07.pdf'},
            },
            entityName: fnParseInvoiceName,
            summary: l.t(
              'Reproduce on the EU fixture — the one with comma decimals',
              '在欧洲版夹具上复现——就是用逗号做小数点的那份',
            ),
          ),
          _progress(
            'ft_run',
            l.t('page 1/1 · extracting table', '第 1/1 页 · 提取表格'),
          ),
          tr(
            'ft_run',
            _j({
              'ok': false,
              'output': null,
              'errorMsg':
                  'decimal.InvalidOperation: [<class \'decimal.ConversionSyntax\'>]',
              'elapsedMs': 1184,
              'logs': traceback,
            }),
            error: true,
          ),
          txt(
            'blk_ft_t1',
            'text',
            l.t(
              'Found it: the fixture picker is `random.choice`, and the EU invoice uses `4.820,00` — `Decimal("4.820,00")` raises. The fix is to normalise thousands and decimal separators before',
              '找到了:夹具选择用的是 `random.choice`,而欧洲版发票写的是 `4.820,00`——`Decimal("4.820,00")` 会抛异常。修法是在转换前先归一千分位和小数点',
            ),
          ),
        ],
      ),
    ],
  );
}

// ───────────────────────── 6 · release notes (residency, document) ─────────────────────────

_Thread _releaseNotes(StoryLocale l) {
  const cv = cvReleaseNotes;
  final askAt = ago(hours: 5, minutes: 20);
  final at = ago(hours: 5);
  final notes = l.t(
    '# Anselm 0.2\n\n'
        '## Highlights\n\n'
        '- **Durable workflows** replay from node memoization — a crashed run resumes where it stopped.\n'
        '- **Residency**: mount a conversation on a directory; Bash and relative paths follow it.\n'
        '- **Approvals inbox** across runs, with 72h timeouts.\n\n'
        '## Fixes\n\n'
        '- Rail viewport resets when the sort axis changes (#412)\n'
        '- Branch recovery notice stays readable in narrow menus (#418)\n\n'
        '## Upgrade notes\n\n'
        'Trigger configs now carry an explicit `timezone`; existing cron triggers default to UTC.\n',
    '# Anselm 0.2\n\n'
        '## 亮点\n\n'
        '- **持久工作流**按节点记忆化重放——崩掉的 run 从断点继续。\n'
        '- **驻地**:对话可挂到一个目录上;Bash 与相对路径都跟着它走。\n'
        '- 跨 run 的**审批收件箱**,支持 72 小时超时。\n\n'
        '## 修复\n\n'
        '- 排序轴变化时 rail 视口归零(#412)\n'
        '- 分支恢复提示在窄菜单里保持可读(#418)\n\n'
        '## 升级说明\n\n'
        '触发器配置现在带显式 `timezone`;已有 cron 触发器默认 UTC。\n',
  );
  return (
    conv: _conv(cv, cvReleaseNotesTitle(l), at, workDir: storyRepoDir),
    messages: [
      _user(
        'msg_rn_u1',
        cv,
        askAt,
        l.t(
          'Draft the 0.2 release notes from everything merged since v0.1.0, and file them under Release process.',
          '根据 v0.1.0 以来合并的所有内容,起草 0.2 的版本说明,归档到「发布流程」下面。',
        ),
      ),
      _bot('msg_rn_a1', cv, at, tokensIn: 6210, tokensOut: 1430, [
        txt(
          'blk_rn_r1',
          'reasoning',
          l.t(
            'Read the merge history from the mounted repo, hand it to release_notes_writer for prose, then create the document under the Release process folder so the backlink shows up there.',
            '从挂载的仓库读合并历史,交给 release_notes_writer 写成文字,再把文档建在「发布流程」文件夹下,反链就会出现在那里。',
          ),
        ),
        tc(
          'rn_log',
          'Bash',
          _j({'command': 'git log v0.1.0..HEAD --merges --oneline'}),
          summary: l.t('List merges since v0.1.0', '列出 v0.1.0 以来的合并'),
          danger: 'cautious',
        ),
        tr(
          'rn_log',
          '9c1f2ab Merge pull request #421 from feat/durable-replay\n'
              '4e77d10 Merge pull request #419 from feat/residency-worktrees\n'
              '1b2c3d4 Merge pull request #418 from fix/branch-notice-width\n'
              'a8e9f01 Merge pull request #415 from feat/approval-inbox\n'
              '77aa0b2 Merge pull request #412 from fix/rail-viewport-reset\n'
              '5d6e7f8 Merge pull request #409 from chore/trigger-timezone\n\n[exit code: 0]',
        ),
        _tcNamed(
          'rn_agent',
          'invoke_agent',
          {
            'agentId': agReleaseNotes,
            'input': {'version': '0.2', 'since': 'v0.1.0', 'merges': 6},
          },
          entityName: agReleaseNotesName,
          summary: l.t('Write the notes from the merge list', '按合并列表写说明'),
        ),
        tr(
          'rn_agent',
          _j({
            'executionId': 'agexec_3c7e9a1b5d2f4680',
            'ok': true,
            'status': 'ok',
            'output': notes,
            'steps': 4,
            'tokensIn': 5120,
            'tokensOut': 640,
            'elapsedMs': 6900,
          }),
        ),
        tc(
          'rn_doc',
          'create_document',
          _j({
            'name': l.t('Release notes 0.2', '0.2 版本说明'),
            'parentId': docReleaseProcess,
            'content': notes,
            'tags': ['release', '0.2'],
          }),
          summary: l.t('File the draft under Release process', '把草稿归档到「发布流程」下'),
        ),
        tr(
          'rn_doc',
          'Created document "${l.t('Release notes 0.2', '0.2 版本说明')}" (id=$_docReleaseNotes, path=/${docReleaseProcessTitle(l)}/${l.t('Release notes 0.2', '0.2 版本说明')}).',
        ),
        txt(
          'blk_rn_t1',
          'text',
          l.t(
            'Drafted from the six merges since v0.1.0 and filed as **Release notes 0.2** under Release process. Three highlights (durable replay, residency, approvals inbox), two fixes, and one upgrade note about trigger timezones. Tell me if you want the tone more marketing-facing.',
            '根据 v0.1.0 以来的六次合并起草完毕,已作为 **0.2 版本说明** 归档到「发布流程」下。三条亮点(持久重放、驻地、审批收件箱)、两条修复、一条关于触发器时区的升级说明。如果想要更偏市场口吻,告诉我。',
          ),
        ),
      ]),
    ],
  );
}

// ───────────────────────── 7 · vanished residency ─────────────────────────

_Thread _oldPrototype(StoryLocale l) {
  const cv = cvOldPrototype;
  final askAt = ago(days: 2, hours: 3, minutes: 5);
  final at = ago(days: 2, hours: 3);
  return (
    conv: _conv(cv, cvOldPrototypeTitle(l), at, workDir: storyGoneDir),
    messages: [
      // The residency mark's real wire shape: a synthetic assistant turn with one empty `marker` block
      // and {kind, from, to} in attrs — the label is localized client-side. 驻地标记的真实线缆形。
      _bot('msg_op_m0', cv, askAt.subtract(const Duration(seconds: 20)), const [
        ChatBlock(
          id: 'blk_op_m0',
          type: 'marker',
          content: '',
          status: 'completed',
          attrs: {'kind': 'workdir', 'from': '', 'to': storyGoneDir},
        ),
      ]),
      _user(
        'msg_op_u1',
        cv,
        askAt,
        l.t(
          'Which parts of the old prototype are worth porting into the new backend?',
          '旧原型里哪些部分值得迁到新后端?',
        ),
      ),
      _bot('msg_op_a1', cv, at, tokensIn: 3380, tokensOut: 610, [
        tc(
          'op_glob',
          'Glob',
          _j({'pattern': '**/*.py', 'path': storyGoneDir}),
          summary: l.t('Inventory the prototype', '盘点原型文件'),
        ),
        tr(
          'op_glob',
          _j({
            'root': storyGoneDir,
            'matches': [
              {
                'path': '$storyGoneDir/pdf/extract_tables.py',
                'type': 'file',
                'size': 4180,
                'mtime': _iso(ago(days: 40)),
              },
              {
                'path': '$storyGoneDir/github/digest.py',
                'type': 'file',
                'size': 2932,
                'mtime': _iso(ago(days: 46)),
              },
              {
                'path': '$storyGoneDir/app.py',
                'type': 'file',
                'size': 11210,
                'mtime': _iso(ago(days: 38)),
              },
            ],
            'total': 3,
            'truncated': false,
          }),
        ),
        tc(
          'op_read',
          'Read',
          _j({'file_path': '$storyGoneDir/pdf/extract_tables.py'}),
          summary: l.t('Read the table extractor', '读表格提取器'),
        ),
        tr(
          'op_read',
          '1\timport pdfplumber\n2\t\n3\tdef extract_tables(path: str) -> list[list[str]]:\n4\t    with pdfplumber.open(path) as pdf:\n5\t        return [t for p in pdf.pages for t in p.extract_tables()]\n',
        ),
        txt(
          'blk_op_t1',
          'text',
          l.t(
            'Two pieces are worth keeping: `pdf/extract_tables.py` (it became `parse_invoice_pdf`) and the commit grouping in `github/digest.py`, which `write_weekly_digest` now does in prose. `app.py` is a Flask shell with nothing the new sidecar needs. I would archive the folder rather than port it further.',
            '值得留的有两块:`pdf/extract_tables.py`(它已经演变成 `parse_invoice_pdf`)和 `github/digest.py` 里的提交归组逻辑,现在由 `write_weekly_digest` 用文字完成。`app.py` 只是个 Flask 壳,新 sidecar 用不上。我建议把这个目录归档,不再继续迁。',
          ),
        ),
      ]),
    ],
  );
}

// ───────────────────────── 8 · unread (green) ─────────────────────────

_Thread _explainDurable(StoryLocale l) {
  const cv = cvExplainDurable;
  final askAt = ago(days: 1, hours: 2, minutes: 4);
  final at = ago(days: 1, hours: 2);
  return (
    conv: _conv(cv, cvExplainDurableTitle(l), at, unread: true),
    messages: [
      _user(
        'msg_ed_u1',
        cv,
        askAt,
        l.t(
          'Explain durable execution to a new teammate in one screen. They know cron jobs, not workflow engines.',
          '用一屏的篇幅给新同事讲讲持久执行。他们懂 cron 任务,没接触过工作流引擎。',
        ),
      ),
      _bot('msg_ed_a1', cv, at, tokensIn: 860, tokensOut: 540, [
        txt(
          'blk_ed_t1',
          'text',
          l.t(
            'A cron job is a single shell command: if it dies halfway, you rerun the whole thing and hope it was idempotent. A **durable** workflow remembers each node\'s result, so a rerun skips what already finished and picks up at the first node without a result.\n\n'
                '| | cron job | durable workflow |\n'
                '|---|---|---|\n'
                '| Unit of work | one process | a graph of nodes |\n'
                '| Crash mid-way | start over | resume at the failed node |\n'
                '| Waiting for a human | impossible | the run *parks* on an approval node |\n'
                '| Truth | stdout / logs | one row per node in `flowrun_nodes` |\n\n'
                'The engine is just an interpreter that walks the graph and asks "do I already have a result for this node?" before running it:\n\n'
                '```go\n'
                'for _, node := range graph.Order() {\n'
                '    if res, ok := run.Memo(node.ID); ok {\n'
                '        continue // replayed from flowrun_nodes\n'
                '    }\n'
                '    res, err := node.Execute(ctx, inputs)\n'
                '    run.Remember(node.ID, res, err) // exactly once (idx_frn_once)\n'
                '}\n'
                '```\n\n'
                'That is why `weekly_github_digest` could fail at `fetch_commits` on Friday and, after the function fix, run clean today: nothing before the failure had to be repeated, and the approval node can sit parked for days without holding a process open.',
            'cron 任务就是一条 shell 命令:中途挂了,你只能整个重跑,并祈祷它是幂等的。**持久**工作流会记住每个节点的结果,重跑时跳过已经完成的部分,从第一个没有结果的节点接着走。\n\n'
                '| | cron 任务 | 持久工作流 |\n'
                '|---|---|---|\n'
                '| 工作单元 | 一个进程 | 一张节点图 |\n'
                '| 中途崩溃 | 从头再来 | 从失败节点续跑 |\n'
                '| 等人决定 | 做不到 | run 在审批节点*停车* |\n'
                '| 真相 | stdout / 日志 | `flowrun_nodes` 里每节点一行 |\n\n'
                '引擎只是个解释器:沿着图走,每执行一个节点前先问一句「这个节点我是不是已经有结果了」:\n\n'
                '```go\n'
                'for _, node := range graph.Order() {\n'
                '    if res, ok := run.Memo(node.ID); ok {\n'
                '        continue // 从 flowrun_nodes 重放\n'
                '    }\n'
                '    res, err := node.Execute(ctx, inputs)\n'
                '    run.Remember(node.ID, res, err) // 恰好一次(idx_frn_once)\n'
                '}\n'
                '```\n\n'
                '所以 `weekly_github_digest` 才能周五在 `fetch_commits` 失败、函数修好后今天干净地跑完:失败之前的部分一步都不用重做,审批节点也能停车好几天而不占着一个进程。',
          ),
        ),
      ]),
    ],
  );
}

// ───────────────────────── seeds beyond the transcript ─────────────────────────

/// Residency projections are scripted, not probed: the story must show a clean git repo, a dirty design
/// folder and a vanished directory on any machine, including one where none of the paths exist.
/// 驻地投影是脚本化而非真探:故事要在任何机器上展示干净仓库、脏设计目录与已消失目录,包括三条路径都不存在的机器。
void _seedResidencies(DemoChatRepository repo) {
  repo.workDirInfos[storyRepoDir] = const WorkDirInfo(
    path: storyRepoDir,
    exists: true,
    isGitRepo: true,
    branch: 'main',
    dirty: false,
    branches: ['main', 'fix/invoice-parser-flake', 'release/0.2'],
    worktrees: [
      WorkTreeInfo(path: storyRepoDir, branch: 'main', current: true),
      WorkTreeInfo(path: '$storyRepoDir-release', branch: 'release/0.2'),
    ],
  );
  repo.workDirInfos[storySiteDir] = const WorkDirInfo(
    path: storySiteDir,
    exists: true,
    isGitRepo: true,
    branch: 'main',
    dirty: true,
    branches: ['main'],
    worktrees: [
      WorkTreeInfo(path: storySiteDir, branch: 'main', current: true),
    ],
  );
  repo.workDirInfos[storyGoneDir] = const WorkDirInfo(path: storyGoneDir);
}

void _seedInteractions(DemoChatRepository repo, StoryLocale l) {
  repo.interactions[cvRefund] = [
    Interaction(
      toolCallId: 'rf_ask',
      kind: InteractionKind.ask,
      tool: 'ask_user',
      resolved: false,
      message: _refundQuestion(l),
      options: _refundOptions(l),
    ),
  ];
}

void _seedAttachments(DemoChatRepository repo) {
  final at = ago(hours: 3, minutes: 5);
  void seed(
    String id,
    String filename,
    String mime,
    int sizeBytes, {
    required List<int> from,
    required List<int> to,
    required int w,
    required int h,
    String sha = '',
  }) {
    repo.attachmentMetas[id] = AttachmentMeta(
      id: id,
      sha256: sha,
      filename: filename,
      mimeType: mime,
      sizeBytes: sizeBytes,
      kind: 'image',
      createdAt: at,
      preparation: const AttachmentPreparation(
        status: 'ready',
        phase: 'ready',
        target: 'model-default',
      ),
    );
    repo.attachmentBytes[id] = _gradientPng(w, h, from, to);
  }

  // Inputs the user dropped in — three distinct gradients so the thumbs are telling apart at a glance.
  // 用户拖进来的三张——三种不同渐变,缩略图一眼能分开。
  seed(
    _attHeroDesktop,
    'hero-desktop.png',
    'image/png',
    2_497_331,
    from: const [28, 42, 78],
    to: const [118, 170, 255],
    w: 320,
    h: 180,
    sha: '3f9a1c7e5b2d4680a9c1e3f5b7d9a2c4',
  );
  seed(
    _attHeroMobile,
    'hero-mobile.jpg',
    'image/jpeg',
    1_142_880,
    from: const [64, 24, 72],
    to: const [255, 140, 96],
    w: 150,
    h: 325,
    sha: '8c2e4a6b0d1f3579c1e3a5b7d9f1b3d5',
  );
  seed(
    _attHeroOg,
    'hero-og.png',
    'image/png',
    1_836_014,
    from: const [16, 64, 56],
    to: const [180, 230, 120],
    w: 320,
    h: 168,
    sha: '5d7f9b1c3e5a7092b4d6f8a0c2e4a6c8',
  );
  // Outputs: three WebP receipts (run_function output) and the social crop (edit_image media card).
  // 产物:三份 WebP 回执(run_function 输出)与社交裁图(edit_image 媒体卡)。
  seed(
    _attOutDesktop,
    'hero-desktop@1600.webp',
    'image/webp',
    148_212,
    from: const [28, 42, 78],
    to: const [118, 170, 255],
    w: 160,
    h: 90,
  );
  seed(
    _attOutMobile,
    'hero-mobile@1200.webp',
    'image/webp',
    203_884,
    from: const [64, 24, 72],
    to: const [255, 140, 96],
    w: 75,
    h: 163,
  );
  seed(
    _attOutOg,
    'hero-og@1600.webp',
    'image/webp',
    131_507,
    from: const [16, 64, 56],
    to: const [180, 230, 120],
    w: 160,
    h: 84,
  );
  seed(
    _attOgCropped,
    'hero-og-social.png',
    'image/png',
    412_960,
    from: const [16, 64, 56],
    to: const [180, 230, 120],
    w: 382,
    h: 200,
    sha: 'b1d3f5a7c9e1b3d5f7a9c1e3b5d7f9a1',
  );
}

void _seedTodos(DemoChatRepository repo, StoryLocale l) {
  repo.todos[cvDigest] = ConversationTodos(
    conversationId: cvDigest,
    todos: [
      TodoEntry(
        content: l.t('Create the GitHub fetch function', '建 GitHub 拉取函数'),
        status: 'completed',
      ),
      TodoEntry(
        content: l.t('Create the digest-writing agent', '建写周报的 agent'),
        status: 'completed',
      ),
      TodoEntry(
        content: l.t('Create the Monday 09:00 trigger', '建周一 09:00 触发器'),
        status: 'completed',
      ),
      TodoEntry(
        content: l.t('Create the review approval', '建审阅审批'),
        status: 'completed',
      ),
      TodoEntry(
        content: l.t('Create the empty-week control', '建空周判断控制'),
        status: 'completed',
      ),
      TodoEntry(
        content: l.t('Wire the workflow and run it once', '串成工作流并跑一次'),
        status: 'completed',
      ),
      TodoEntry(
        content: l.t('Wait for the digest review', '等周报审阅'),
        activeForm: l.t('Waiting for the digest review', '正在等周报审阅'),
        status: 'in_progress',
      ),
    ],
  );
}

/// The Activity ledger (right island) for the threads that touched entities — one row per (item, verb),
/// the way the backend aggregates. 触碰过实体的线程的 Activity 台账——按(物,动词)聚合,与后端一致。
void _seedTouchpoints(DemoChatRepository repo, StoryLocale l) {
  Touchpoint tp(
    String id,
    String cv,
    String kind,
    String itemId,
    String name,
    TouchpointVerb verb,
    DateTime at, {
    int count = 1,
    TouchpointActor actor = TouchpointActor.assistant,
    String messageId = '',
  }) => Touchpoint(
    id: id,
    conversationId: cv,
    itemKind: kind,
    itemId: itemId,
    itemName: name,
    verb: verb,
    lastActor: actor,
    count: count,
    firstAt: at.subtract(Duration(minutes: count > 1 ? 30 : 0)),
    lastAt: at,
    lastMessageId: messageId,
  );

  final buildAt = ago(days: 2, hours: 3);
  final fixAt = ago(minutes: 18);
  repo.touchpoints[cvDigest] = [
    tp(
      'tp_dg1',
      cvDigest,
      'function',
      fnFetchGithub,
      fnFetchGithubName,
      TouchpointVerb.created,
      buildAt,
      messageId: 'msg_dg_a1',
    ),
    tp(
      'tp_dg2',
      cvDigest,
      'function',
      fnFetchGithub,
      fnFetchGithubName,
      TouchpointVerb.edited,
      fixAt,
      messageId: 'msg_dg_a2',
    ),
    tp(
      'tp_dg3',
      cvDigest,
      'agent',
      agDigest,
      agDigestName,
      TouchpointVerb.created,
      buildAt,
      messageId: 'msg_dg_a1',
    ),
    tp(
      'tp_dg4',
      cvDigest,
      'trigger',
      trgMonday,
      trgMondayName,
      TouchpointVerb.created,
      buildAt,
      messageId: 'msg_dg_a1',
    ),
    tp(
      'tp_dg5',
      cvDigest,
      'approval',
      apfDigest,
      apfDigestName,
      TouchpointVerb.created,
      buildAt,
      messageId: 'msg_dg_a1',
    ),
    tp(
      'tp_dg9',
      cvDigest,
      'control',
      ctlEmptyWeek,
      ctlEmptyWeekName,
      TouchpointVerb.created,
      buildAt,
      messageId: 'msg_dg_a1',
    ),
    tp(
      'tp_dg6',
      cvDigest,
      'workflow',
      wfDigest,
      wfDigestName,
      TouchpointVerb.created,
      buildAt,
      messageId: 'msg_dg_a1',
    ),
    tp(
      'tp_dg7',
      cvDigest,
      'workflow',
      wfDigest,
      wfDigestName,
      TouchpointVerb.executed,
      fixAt,
      count: 2,
      messageId: 'msg_dg_a2',
    ),
    tp(
      'tp_dg8',
      cvDigest,
      'document',
      docDigestsFolder,
      docDigestsFolderTitle(l),
      TouchpointVerb.mentioned,
      ago(days: 2, hours: 3, minutes: 12),
      actor: TouchpointActor.user,
      messageId: 'msg_dg_u1',
    ),
  ];

  final heroAt = ago(hours: 3);
  repo.touchpoints[cvHeroImages] = [
    tp(
      'tp_hi1',
      cvHeroImages,
      'attachment',
      _attHeroDesktop,
      'hero-desktop.png',
      TouchpointVerb.attached,
      heroAt.subtract(const Duration(minutes: 4)),
      actor: TouchpointActor.user,
      messageId: 'msg_hi_u1',
    ),
    tp(
      'tp_hi2',
      cvHeroImages,
      'attachment',
      _attHeroMobile,
      'hero-mobile.jpg',
      TouchpointVerb.attached,
      heroAt.subtract(const Duration(minutes: 4)),
      actor: TouchpointActor.user,
      messageId: 'msg_hi_u1',
    ),
    tp(
      'tp_hi3',
      cvHeroImages,
      'attachment',
      _attHeroOg,
      'hero-og.png',
      TouchpointVerb.attached,
      heroAt.subtract(const Duration(minutes: 4)),
      actor: TouchpointActor.user,
      messageId: 'msg_hi_u1',
    ),
    tp(
      'tp_hi4',
      cvHeroImages,
      'function',
      fnResizeImage,
      fnResizeImageName,
      TouchpointVerb.executed,
      heroAt,
      count: 3,
      messageId: 'msg_hi_a1',
    ),
    tp(
      'tp_hi5',
      cvHeroImages,
      'attachment',
      _attOgCropped,
      'hero-og-social.png',
      TouchpointVerb.created,
      heroAt,
      messageId: 'msg_hi_a1',
    ),
  ];

  final flakyAt = ago(hours: 7);
  repo.touchpoints[cvFlakyTest] = [
    tp(
      'tp_ft1',
      cvFlakyTest,
      'function',
      fnParseInvoice,
      fnParseInvoiceName,
      TouchpointVerb.executed,
      flakyAt,
      messageId: 'msg_ft_a1',
    ),
  ];

  final releaseAt = ago(hours: 5);
  repo.touchpoints[cvReleaseNotes] = [
    tp(
      'tp_rn1',
      cvReleaseNotes,
      'agent',
      agReleaseNotes,
      agReleaseNotesName,
      TouchpointVerb.executed,
      releaseAt,
      messageId: 'msg_rn_a1',
    ),
    tp(
      'tp_rn2',
      cvReleaseNotes,
      'document',
      _docReleaseNotes,
      l.t('Release notes 0.2', '0.2 版本说明'),
      TouchpointVerb.created,
      releaseAt,
      messageId: 'msg_rn_a1',
    ),
    tp(
      'tp_rn3',
      cvReleaseNotes,
      'document',
      docReleaseProcess,
      docReleaseProcessTitle(l),
      TouchpointVerb.mentioned,
      releaseAt.subtract(const Duration(minutes: 20)),
      actor: TouchpointActor.user,
      messageId: 'msg_rn_u1',
    ),
  ];

  repo.touchpoints[cvTriage] = [
    tp(
      'tp_tr1',
      cvTriage,
      'agent',
      agTriage,
      agTriageName,
      TouchpointVerb.executed,
      ago(minutes: 1),
      messageId: 'msg_tr_a1',
    ),
    tp(
      'tp_tr2',
      cvTriage,
      'handler',
      hdPostgres,
      hdPostgresName,
      TouchpointVerb.executed,
      ago(minutes: 1),
      actor: TouchpointActor.subagent,
      messageId: 'msg_tr_a1',
    ),
  ];

  repo.touchpoints[cvRefund] = [
    tp(
      'tp_rf1',
      cvRefund,
      'handler',
      hdPostgres,
      hdPostgresName,
      TouchpointVerb.executed,
      ago(minutes: 6),
      messageId: 'msg_rf_a1',
    ),
  ];
}

/// Truth snapshots so a settled Activity row opens to its full stage (code / graph / prose) rather than
/// a 404. 真身快照,使落定的 Activity 行能打开完整舞台(代码/图/正文)而不是 404。
void _seedTruth(DemoChatRepository repo, StoryLocale l) {
  final buildAt = ago(days: 2, hours: 3);
  final fixAt = ago(minutes: 18);
  repo.functions[fnFetchGithub] = FunctionEntity(
    id: fnFetchGithub,
    name: fnFetchGithubName,
    description: l.t(
      'Fetch commits, merged PRs and issues for a GitHub repo over a date window; retries 5xx and rate-limit responses with exponential backoff (3 attempts).',
      '按日期窗口拉取一个 GitHub 仓库的提交、已合并 PR 与 issue;对 5xx 与限流响应做指数退避重试(3 次)。',
    ),
    tags: const ['github', 'digest'],
    activeVersionId: _fnv2,
    activeVersion: FunctionVersion(
      id: _fnv2,
      functionId: fnFetchGithub,
      version: 2,
      code: _fetchCodeV2,
      inputs: const [
        Field(name: 'repo', type: 'string'),
        Field(name: 'since', type: 'string'),
        Field(name: 'until', type: 'string'),
      ],
      outputs: const [
        Field(name: 'commits', type: 'array'),
        Field(name: 'pullRequests', type: 'array'),
        Field(name: 'period', type: 'object'),
      ],
      dependencies: const ['requests==2.32.3', 'python-dateutil==2.9.0.post0'],
      envStatus: 'ready',
      changeReason: l.t(
        'Retry 5xx / rate-limit with exponential backoff (3 attempts); default the window to the trailing two weeks',
        '5xx / 限流指数退避重试(3 次);窗口默认最近两周',
      ),
      createdAt: fixAt,
      updatedAt: fixAt,
    ),
    createdAt: buildAt,
    updatedAt: fixAt,
  );
  repo.workflows[wfDigest] = WorkflowEntity(
    id: wfDigest,
    name: wfDigestName,
    description: l.t(
      'Monday GitHub digest: three parallel fetches → write → check activity → review → file → Slack.',
      '周一 GitHub 周报:三路并行拉取 → 写作 → 活动判断 → 审阅 → 归档 → Slack。',
    ),
    active: true,
    lifecycleState: 'active',
    activeVersionId: _wfv1,
    activeVersion: WorkflowVersion(
      id: _wfv1,
      workflowId: wfDigest,
      version: 1,
      // The canonical graph WITH authored vertical positions (see [_digestPos]). 带纵向手摆坐标的规范图。
      graphParsed: _digestGraph(l),
      createdAt: buildAt,
      updatedAt: buildAt,
    ),
    createdAt: buildAt,
    updatedAt: buildAt,
  );
  repo.controls[ctlEmptyWeek] = ControlLogic(
    id: ctlEmptyWeek,
    name: ctlEmptyWeekName,
    description: l.t(
      'Route an empty week away from review: has_activity when any of the three fetches found something, otherwise empty.',
      '把空周绕过审阅:三路拉取任一有内容走 has_activity,否则走 empty。',
    ),
    activeVersionId: _ctlv1,
    activeVersion: ControlVersion(
      id: _ctlv1,
      controlId: ctlEmptyWeek,
      version: 1,
      inputs: const [
        Field(name: 'commits', type: 'number'),
        Field(name: 'pulls', type: 'number'),
        Field(name: 'issues', type: 'number'),
      ],
      branches: const [
        Branch(
          port: 'has_activity',
          when: 'input.commits > 0 || input.pulls > 0 || input.issues > 0',
          emit: {'total': 'input.commits + input.pulls + input.issues'},
        ),
        Branch(port: 'empty', when: 'true'),
      ],
      changeReason: l.t('New: empty-week gate', '新建:空周门控'),
      createdAt: buildAt,
      updatedAt: buildAt,
    ),
    createdAt: buildAt,
    updatedAt: buildAt,
  );
  repo.triggers[trgMonday] = TriggerEntity(
    id: trgMonday,
    name: trgMondayName,
    description: l.t('Every Monday 09:00 local time.', '每周一 09:00(本地时间)。'),
    kind: TriggerSource.cron,
    config: const {'expression': '0 9 * * 1', 'timezone': 'Asia/Shanghai'},
    outputs: const [Field(name: 'firedAt', type: 'string')],
    refCount: 1,
    listening: true,
    lastFiredAt: ago(days: 1),
    nextFireAt: ago(days: -6),
    createdAt: buildAt,
    updatedAt: buildAt,
  );
  repo.agents[agDigest] = AgentEntity(
    id: agDigest,
    name: agDigestName,
    description: l.t(
      'Turn raw GitHub activity into a readable weekly digest in Markdown.',
      '把原始 GitHub 活动整理成可读的 Markdown 周报。',
    ),
    activeVersionId: _agv1,
    activeVersion: AgentVersion(
      id: _agv1,
      agentId: agDigest,
      version: 1,
      prompt: l.t(
        'You write the weekly engineering digest for the Product Team. Group commits by theme, name the authors, call out fixes separately, and end with 2-3 highlights. Never invent work that is not in the input.',
        '你负责给产品团队写每周工程周报。按主题归组提交、写明作者、缺陷修复单列,结尾给 2-3 条亮点。绝不编造输入里没有的工作。',
      ),
      tools: const [ToolRef(ref: docHandbook, name: 'read_document')],
      inputs: const [Field(name: 'activity', type: 'object')],
      outputs: const [
        Field(name: 'headline', type: 'string'),
        Field(name: 'markdown', type: 'string'),
      ],
      createdAt: buildAt,
      updatedAt: buildAt,
    ),
    createdAt: buildAt,
    updatedAt: buildAt,
  );
  repo.documents[_docReleaseNotes] = DocumentNode(
    id: _docReleaseNotes,
    parentId: docReleaseProcess,
    name: l.t('Release notes 0.2', '0.2 版本说明'),
    content: l.t(
      '# Anselm 0.2\n\n## Highlights\n\n- **Durable workflows** replay from node memoization.\n- **Residency**: mount a conversation on a directory.\n- **Approvals inbox** across runs.\n',
      '# Anselm 0.2\n\n## 亮点\n\n- **持久工作流**按节点记忆化重放。\n- **驻地**:对话可挂到一个目录上。\n- 跨 run 的**审批收件箱**。\n',
    ),
    hasContent: true,
    tags: const ['release', '0.2'],
    path:
        '/${docReleaseProcessTitle(l)}/${l.t('Release notes 0.2', '0.2 版本说明')}',
    sizeBytes: 612,
    createdAt: ago(hours: 5),
    updatedAt: ago(hours: 5),
  );
}

// ───────────────────────── a tiny PNG encoder ─────────────────────────

/// Real image bytes for the seeded attachments, generated at startup instead of checked in: the user
/// bubble and the media card decode whatever `getAttachmentBytes` returns, and a thread about resizing
/// hero images with blank file cards would photograph as a broken feature. The RGB triples are the
/// PIXELS of a fixture picture, not UI colors — nothing here paints chrome.
/// 给种子附件的真实图片字节,启动时生成而非入库:用户气泡与媒体卡解码的就是 `getAttachmentBytes` 返回的
/// 任何东西,一个讲压缩首屏图的线程若只有空文件卡,拍出来就是坏功能。RGB 三元组是夹具图片的**像素**、
/// 不是 UI 颜色——这里不画任何界面。
Uint8List _gradientPng(int w, int h, List<int> from, List<int> to) {
  final raw = BytesBuilder(copy: false);
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter: none 无滤波
    for (var x = 0; x < w; x++) {
      final t = (x / w) * 0.65 + (y / h) * 0.35;
      for (var c = 0; c < 3; c++) {
        raw.addByte((from[c] + (to[c] - from[c]) * t).round().clamp(0, 255));
      }
    }
  }
  final ihdr = ByteData(13)
    ..setUint32(0, w)
    ..setUint32(4, h)
    ..setUint8(8, 8) // bit depth 位深
    ..setUint8(9, 2) // colour type: truecolour 真彩
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  final out = BytesBuilder(copy: false)
    ..add(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  _pngChunk(out, 'IHDR', ihdr.buffer.asUint8List());
  _pngChunk(out, 'IDAT', zlib.encode(raw.takeBytes()));
  _pngChunk(out, 'IEND', const []);
  return out.takeBytes();
}

void _pngChunk(BytesBuilder out, String type, List<int> data) {
  final typeBytes = ascii.encode(type);
  final len = ByteData(4)..setUint32(0, data.length);
  out
    ..add(len.buffer.asUint8List())
    ..add(typeBytes)
    ..add(data);
  final crc = ByteData(4)..setUint32(0, _crc32([...typeBytes, ...data]));
  out.add(crc.buffer.asUint8List());
}

final List<int> _crcTable = List.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
