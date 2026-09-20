/// The promo reel: one scripted turn in which the AI builds the weekly GitHub digest from a single
/// sentence — a function, an agent, a Monday trigger, the workflow graph — then runs it once, parks at
/// the review, gets approved, and finishes. Every frame goes through the real stream reducer, stage
/// director and sidestage, so what the recording shows is what the product does; only the model and
/// the clock are scripted. Entity ids reuse the story bible so settled rows open onto seeded truth.
///
/// 宣传片:一段脚本回合,AI 从一句话建出周报——function、agent、周一 trigger、workflow 图——再跑一次,停在审阅,
/// 获批,收尾。每一帧都走真实的流归约器、舞台导演和侧幕,录下来的就是产品本身;脚本化的只有模型和时钟。实体 id 沿用
/// 故事总纲,落定的行能打开已播种的真身。
library;

import '../../core/contract/touchpoint.dart';
import '../../core/sse/frame.dart';
import '../../features/chat/data/chat_demo_fixture.dart';
import '../../features/chat/data/conversation_signal.dart';
import '../../features/chat/data/turn_signal.dart';
import '../../core/contract/messages/chat_message.dart';
import 'story_bible.dart';
import 'story_chat.dart' show digestOps;
import 'story_locale.dart';

/// The sentence the reel opens with. 宣传片开场的那句话。
const promoPrompt =
    'Every Monday at 9, pull last week\'s commits and merged PRs from Cookiezisg/Anselm, '
    'write a short digest, and let me review it before it\'s filed and posted to #product-team.';

/// Beats the reel needs from outside the chat repository: the approval capsule lives in the notice
/// center and the decision lands in the entity repository, both of which need a `ref`. The demo root
/// fills these in before the first send. 宣传片需要聊天仓库之外的两拍:审批胶囊在通知中心,决定落在实体仓库,
/// 都要 ref;demo 根在首发前填上。
class PromoHooks {
  void Function()? showApproval;
  Future<void> Function()? approve;
}

const _fetchCode =
    'import requests\\n'
    'from datetime import date, timedelta\\n\\n'
    'def run(repo: str, since: str | None = None, until: str | None = None):\\n'
    '    until = until or date.today().isoformat()\\n'
    '    since = since or (date.today() - timedelta(days=7)).isoformat()\\n'
    '    base = f"https://api.github.com/repos/{repo}"\\n'
    '    commits = requests.get(f"{base}/commits", params={"since": since, "until": until}).json()\\n'
    '    pulls = [p for p in requests.get(f"{base}/pulls", params={"state": "closed"}).json()\\n'
    '             if p.get("merged_at") and since <= p["merged_at"][:10] <= until]\\n'
    '    return {"commits": commits, "pullRequests": pulls, "period": {"since": since, "until": until}}\\n';

const _agentPrompt =
    'You write the weekly engineering digest for the product team. Group commits by theme, '
    'name the authors, list merged pull requests with one line each, call out fixes separately, '
    'and end with two or three highlights. Never invent work that is not in the input.';

const _reply =
    'Done. Four things now exist in your workspace:\n\n'
    '- **fetch_github_activity** pulls the week\'s commits and merged PRs\n'
    '- **write_weekly_digest** turns them into a readable digest\n'
    '- **weekly_monday_0900** fires every Monday at 09:00\n'
    '- **weekly_github_digest** wires them together and waits for your review before filing\n\n'
    'The first run just finished: you approved it, the digest is filed under *Digests*, and #product-team has it. '
    'From now on this happens on its own every Monday.';

/// Build the turn script; the reel claims only the thread that starts with [promoPrompt].
/// 构造回合脚本;宣传片只接管以 [promoPrompt] 开场的线程。
DemoTurnScript promoTurn(StoryLocale l, PromoHooks hooks) =>
    (repo, cv, assistantId, userText) {
      if (!userText.startsWith('Every Monday at 9')) return false;
      _play(repo, cv, assistantId, userText, l, hooks);
      return true;
    };

void _play(
  DemoChatRepository repo,
  String cv,
  String assistantId,
  String userText,
  StoryLocale l,
  PromoHooks hooks,
) {
  final scope = StreamScope(kind: 'conversation', id: cv);
  final wfScope = const StreamScope(kind: 'workflow', id: wfDigest);
  var at = 250;
  var seq = 1;
  void frame(String id, StreamFrame f, {int step = 0, bool durable = true}) {
    at += step;
    final s = durable ? seq++ : 0;
    repo.schedule(
      Duration(milliseconds: at),
      () => repo.emitFrame(
        cv,
        StreamEnvelope(seq: s, scope: scope, id: id, frame: f),
      ),
    );
  }

  void stream(String id, String text, {int chunk = 12, int step = 45}) {
    for (var i = 0; i < text.length; i += chunk) {
      frame(
        id,
        FrameDelta(chunk: text.substring(i, (i + chunk).clamp(0, text.length))),
        step: step,
        durable: false,
      );
    }
  }

  void touch(String kind, String id, String name, String blockId) {
    repo.schedule(Duration(milliseconds: at + 40), () {
      final now = DateTime.now().toUtc();
      repo.touch(
        Touchpoint(
          id: 'tp_promo_${repo.nextSeq()}',
          conversationId: cv,
          itemKind: kind,
          itemId: id,
          itemName: name,
          verb: TouchpointVerb.created,
          lastActor: TouchpointActor.assistant,
          count: 1,
          firstAt: now,
          lastAt: now,
          lastMessageId: blockId,
        ),
        seq: 800 + repo.nextSeq(),
      );
    });
  }

  // A tool call with streamed arguments, then its execution bracket. 一次工具调用:参数流,再执行括号。
  ({String callId, String resultId}) tool(
    String name, {
    required List<({String text, int chunk, int step})> args,
    required String fullArgs,
    required String result,
    String? entityName,
    String? summary,
    int openStep = 250,
    int closeStep = 300,
    int resultStep = 90,
  }) {
    final callId = 'blk_promo_${repo.nextSeq()}';
    final resultId = 'blk_promo_${repo.nextSeq()}';
    frame(
      callId,
      FrameOpen(
        parentId: assistantId,
        node: StreamNode(
          type: 'tool_call',
          content: {'name': name, 'danger': 'safe'},
        ),
      ),
      step: openStep,
    );
    for (final a in args) {
      stream(callId, a.text, chunk: a.chunk, step: a.step);
    }
    frame(
      callId,
      FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_call',
          content: {
            'name': name,
            'arguments': fullArgs,
            'entityName': ?entityName,
            'summary': ?summary,
          },
        ),
      ),
      step: closeStep,
    );
    frame(
      resultId,
      FrameOpen(
        parentId: callId,
        node: StreamNode(type: 'tool_result', content: {'content': result}),
      ),
      step: resultStep,
    );
    frame(
      resultId,
      FrameClose(
        status: 'completed',
        result: StreamNode(type: 'tool_result', content: {'content': result}),
      ),
      step: 40,
    );
    return (callId: callId, resultId: resultId);
  }

  final blocks = <ChatBlock>[];
  void persist(
    String id,
    String tool,
    String args,
    String result, {
    String? entityName,
    String? summary,
  }) {
    blocks.add(
      ChatBlock(
        id: id,
        type: 'tool_call',
        content: '',
        status: 'completed',
        attrs: {
          'tool': tool,
          'arguments': args,
          'entityName': ?entityName,
          'summary': ?summary,
        },
      ),
    );
    blocks.add(
      ChatBlock(
        id: '${id}_r',
        type: 'tool_result',
        content: result,
        status: 'completed',
        attrs: {'parentBlockId': id},
      ),
    );
  }

  // ── Echo + assistant open ──
  final userId = repo.lastUserMessageId(cv) ?? 'msg_promo_u${repo.nextSeq()}';
  frame(
    userId,
    const FrameOpen(
      node: StreamNode(type: 'message', content: {'role': 'user'}),
    ),
  );
  frame(
    userId,
    FrameClose(
      status: 'completed',
      result: StreamNode(
        type: 'message',
        content: {'role': 'user', 'content': userText},
      ),
    ),
    step: 60,
  );
  frame(
    assistantId,
    const FrameOpen(
      node: StreamNode(type: 'message', content: {'role': 'assistant'}),
    ),
    step: 220,
  );

  // ── Thinking ──
  const thinking =
      'Four pieces: a fetcher for GitHub, a writer for the digest, a Monday trigger, and a workflow '
      'that holds for review before filing. Build them in that order, activate, then run once so the '
      'first digest is real.';
  final thinkId = 'blk_promo_${repo.nextSeq()}';
  frame(
    thinkId,
    FrameOpen(
      parentId: assistantId,
      node: const StreamNode(type: 'reasoning', content: {'content': ''}),
    ),
    step: 150,
  );
  stream(thinkId, thinking, chunk: 9, step: 38);
  frame(
    thinkId,
    const FrameClose(
      status: 'completed',
      result: StreamNode(type: 'reasoning', content: {'content': thinking}),
    ),
    step: 120,
  );

  // ── 1. Function ──
  const fnHead =
      '{"ops":[{"op":"set_meta","name":"$fnFetchGithubName","description":"Fetch commits and merged pull requests for a GitHub repo over a date window.","tags":["github","digest"]},'
      '{"op":"set_inputs","inputs":[{"name":"repo","type":"string"},{"name":"since","type":"string"},{"name":"until","type":"string"}]},'
      '{"op":"set_outputs","outputs":[{"name":"commits","type":"array"},{"name":"pullRequests","type":"array"},{"name":"period","type":"object"}]},'
      '{"op":"set_dependencies","dependencies":["requests==2.32.3"]},'
      '{"op":"set_code","code":"';
  const fnTail =
      '"}],"changeReason":"New: GitHub activity fetch for the weekly digest"}';
  const fnArgs = '$fnHead$_fetchCode$fnTail';
  const fnResult =
      '{"id":"$fnFetchGithub","versionId":"${fnFetchGithub}_v1","version":1,"envStatus":"ready","opsApplied":5}';
  final fn = tool(
    'create_function',
    args: [
      (text: fnHead, chunk: 40, step: 55),
      (text: _fetchCode, chunk: 16, step: 42),
      (text: fnTail, chunk: 40, step: 40),
    ],
    fullArgs: fnArgs,
    result: fnResult,
    entityName: fnFetchGithubName,
    summary: 'Fetch a week of commits and merged PRs',
  );
  touch('function', fnFetchGithub, fnFetchGithubName, fn.callId);
  persist(
    fn.callId,
    'create_function',
    fnArgs,
    fnResult,
    entityName: fnFetchGithubName,
    summary: 'Fetch a week of commits and merged PRs',
  );

  // ── 2. Agent ──
  const agHead =
      '{"name":"$agDigestName","description":"Turn raw GitHub activity into a readable weekly digest.","prompt":"';
  const agTail =
      '","inputs":[{"name":"activity","type":"object"}],"outputs":[{"name":"headline","type":"string"},{"name":"markdown","type":"string"}]}';
  const agArgs = '$agHead$_agentPrompt$agTail';
  const agResult =
      '{"id":"$agDigest","versionId":"${agDigest}_v1","version":1}';
  final ag = tool(
    'create_agent',
    args: [
      (text: agHead, chunk: 40, step: 50),
      (text: _agentPrompt, chunk: 10, step: 34),
      (text: agTail, chunk: 40, step: 40),
    ],
    fullArgs: agArgs,
    result: agResult,
    entityName: agDigestName,
    summary: 'Write the digest from the week\'s activity',
  );
  touch('agent', agDigest, agDigestName, ag.callId);
  persist(
    ag.callId,
    'create_agent',
    agArgs,
    agResult,
    entityName: agDigestName,
    summary: 'Write the digest from the week\'s activity',
  );

  // ── 3. Trigger ──
  const trHead =
      '{"name":"$trgMondayName","description":"Every Monday 09:00 local time.",';
  const trTail =
      '"kind":"cron","config":{"expression":"0 9 * * 1","timezone":"Asia/Shanghai"}}';
  const trArgs = '$trHead$trTail';
  const trResult =
      '{"id":"$trgMonday","name":"$trgMondayName","kind":"cron","config":{"expression":"0 9 * * 1","timezone":"Asia/Shanghai"},"outputs":[{"name":"firedAt","type":"string"}],"refCount":0,"listening":false,"nextFireAt":"2026-09-21T09:00:00+08:00"}';
  final tr = tool(
    'create_trigger',
    args: [
      (text: trHead, chunk: 30, step: 90),
      (text: trTail, chunk: 30, step: 110),
    ],
    fullArgs: trArgs,
    result: trResult,
    entityName: trgMondayName,
    summary: 'Every Monday at 09:00',
    closeStep: 500,
  );
  touch('trigger', trgMonday, trgMondayName, tr.callId);
  persist(
    tr.callId,
    'create_trigger',
    trArgs,
    trResult,
    entityName: trgMondayName,
    summary: 'Every Monday at 09:00',
  );

  // ── 4. Workflow — the canvas grows one op at a time ──
  final ops = digestOps(l);
  final opJson = [for (final o in ops) _json(o)];
  const wfHead =
      '{"name":"$wfDigestName","description":"Monday GitHub digest: fetch, write, check activity, review, file, notify.","ops":[';
  const wfTail =
      '],"concurrency":"skip","changeReason":"New: the weekly digest pipeline"}';
  final wfArgs = '$wfHead${opJson.join(',')}$wfTail';
  const wfResult =
      '{"id":"$wfDigest","versionId":"${wfDigest}_v1","version":1,"active":false,"lifecycleState":"inactive"}';
  final wf = tool(
    'create_workflow',
    args: [
      (text: wfHead, chunk: 60, step: 60),
      for (var i = 0; i < opJson.length; i++)
        (
          text: (i == 0 ? '' : ',') + opJson[i],
          chunk: 400,
          step: i < 10 ? 330 : 190,
        ),
      (text: wfTail, chunk: 60, step: 60),
    ],
    fullArgs: wfArgs,
    result: wfResult,
    entityName: wfDigestName,
    summary: 'Ten nodes, review before filing',
    closeStep: 420,
  );
  touch('workflow', wfDigest, wfDigestName, wf.callId);
  persist(
    wf.callId,
    'create_workflow',
    wfArgs,
    wfResult,
    entityName: wfDigestName,
    summary: 'Ten nodes, review before filing',
  );

  // ── 5. Activate ──
  const actArgs = '{"workflowId":"$wfDigest"}';
  const actResult =
      '{"id":"$wfDigest","name":"$wfDigestName","active":true,"lifecycleState":"active","version":1}';
  final act = tool(
    'activate_workflow',
    args: [(text: actArgs, chunk: 60, step: 80)],
    fullArgs: actArgs,
    result: actResult,
    entityName: wfDigestName,
    closeStep: 200,
  );
  persist(
    act.callId,
    'activate_workflow',
    actArgs,
    actResult,
    entityName: wfDigestName,
  );

  // ── 6. Run it once — node by node, then park at the review ──
  const runArgs =
      '{"workflowId":"$wfDigest","payload":{"repo":"Cookiezisg/Anselm"}}';
  const runResult = '{"flowrunId":"$frDigestParked","workflowId":"$wfDigest"}';
  final run = tool(
    'trigger_workflow',
    args: [(text: runArgs, chunk: 60, step: 80)],
    fullArgs: runArgs,
    result: runResult,
    entityName: wfDigestName,
    closeStep: 200,
  );
  persist(
    run.callId,
    'trigger_workflow',
    runArgs,
    runResult,
    entityName: wfDigestName,
  );

  var tick = 0;
  void node(String nodeId, String status, {String? port, int step = 500}) {
    at += step;
    final id = 'promo_tick_${tick++}';
    repo.schedule(
      Duration(milliseconds: at),
      () => repo.emitWorkflowFrame(
        wfDigest,
        StreamEnvelope(
          seq: 0,
          scope: wfScope,
          id: id,
          frame: FrameSignal(
            node: StreamNode(
              type: 'run',
              content: {
                'flowrunId': frDigestParked,
                'nodeId': nodeId,
                'iteration': 0,
                'status': status,
                'port': ?port,
              },
            ),
          ),
        ),
      ),
    );
  }

  node('start', 'completed', step: 700);
  node('fetch_commits', 'completed', step: 900);
  node('fetch_pulls', 'completed', step: 180);
  node('fetch_issues', 'completed', step: 220);
  node('write_digest', 'completed', step: 2300);
  node('check_activity', 'completed', port: 'has_activity', step: 500);
  node('review', 'parked', step: 400);

  // The capsule rises, the user approves, the run finishes. 胶囊升起,用户批准,run 收尾。
  at += 600;
  repo.schedule(Duration(milliseconds: at), () => hooks.showApproval?.call());
  at += 3200;
  repo.schedule(Duration(milliseconds: at), () => hooks.approve?.call());
  node('review', 'completed', port: 'yes', step: 500);
  node('prepare_doc', 'completed', step: 900);
  node('notify_team', 'completed', step: 700);
  at += 400;
  repo.schedule(
    Duration(milliseconds: at),
    () => repo.emitWorkflowFrame(
      wfDigest,
      StreamEnvelope(
        seq: 900 + repo.nextSeq(),
        scope: wfScope,
        id: 'promo_terminal',
        frame: const FrameSignal(
          node: StreamNode(
            type: 'run_terminal',
            content: {'flowrunId': frDigestParked, 'status': 'completed'},
          ),
        ),
      ),
    ),
  );

  // ── 7. The reply ──
  final textId = 'blk_promo_${repo.nextSeq()}';
  frame(
    textId,
    FrameOpen(
      parentId: assistantId,
      node: const StreamNode(type: 'text', content: {'content': ''}),
    ),
    step: 500,
  );
  stream(textId, _reply, chunk: 6, step: 22);
  frame(
    textId,
    const FrameClose(
      status: 'completed',
      result: StreamNode(type: 'text', content: {'content': _reply}),
    ),
    step: 100,
  );
  frame(
    assistantId,
    const FrameClose(
      status: 'completed',
      result: StreamNode(
        type: 'message',
        content: {
          'role': 'assistant',
          'status': 'completed',
          'stopReason': 'end_turn',
          'inputTokens': 640,
          'outputTokens': 1210,
        },
      ),
    ),
    step: 80,
  );

  repo.schedule(Duration(milliseconds: at + 40), () {
    repo.replaceMessage(
      cv,
      ChatMessage(
        id: assistantId,
        conversationId: cv,
        role: 'assistant',
        status: 'completed',
        stopReason: 'end_turn',
        inputTokens: 640,
        outputTokens: 1210,
        blocks: [
          ChatBlock(
            id: thinkId,
            type: 'reasoning',
            content: thinking,
            status: 'completed',
          ),
          ...blocks,
          ChatBlock(
            id: textId,
            type: 'text',
            content: _reply,
            status: 'completed',
          ),
        ],
        createdAt: DateTime.now().toUtc(),
      ),
    );
    final conv = repo.conversationOrNull(cv);
    if (conv != null) {
      var next = conv.copyWith(isGenerating: false, hasUnread: false);
      if (next.title.trim().isEmpty) {
        next = next.copyWith(title: 'Weekly GitHub digest', autoTitled: true);
        repo.emitSignal(
          ConversationSignal(
            id: cv,
            action: ConversationAction.updated,
            durable: true,
          ),
        );
      }
      repo.upsert(next);
    }
    repo.emitTurnSignal(cv, TurnSignalKind.turnClose);
  });
}

String _json(Object? v) {
  if (v is Map) {
    return '{${v.entries.map((e) => '"${e.key}":${_json(e.value)}').join(',')}}';
  }
  if (v is List) return '[${v.map(_json).join(',')}]';
  if (v is String) {
    return '"${v.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  }
  return '$v';
}
