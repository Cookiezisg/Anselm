import 'dart:async';

import 'package:characters/characters.dart';

import '../../../core/contract/attachment.dart';
import '../../../core/contract/conversation.dart';
import '../../../core/contract/interaction.dart';
import '../../../core/contract/entities/agent.dart';
import '../../../core/contract/entities/approval.dart';
import '../../../core/contract/entities/control.dart';
import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/function.dart';
import '../../../core/contract/entities/handler.dart';
import '../../../core/contract/entities/skill.dart';
import '../../../core/contract/entities/trigger.dart';
import '../../../core/contract/entities/values.dart';
import '../../../core/contract/entities/workflow.dart';
import '../../../core/contract/mcp.dart';
import '../../../core/contract/messages/chat_message.dart';
import '../../../core/contract/page.dart';
import '../../../core/contract/todo.dart';
import '../../../core/contract/touchpoint.dart';
import '../../../core/sse/frame.dart';
import 'chat_fixtures.dart';
import 'chat_showcase_fixture.dart';
import 'conversation_signal.dart';
import 'turn_signal.dart';

/// The scripted auto-title: the first user line, grapheme-safe cut (emoji/CJK never split) — mirrors
/// the backend's utility titler in spirit. 脚本自动命名:首行字素安全截断(镜像后端 utility 命名器)。
String _demoTitle(String text) {
  final line = text.trim().split('\n').first.trim();
  final chars = line.characters;
  return chars.length <= 12 ? line : chars.take(12).join();
}

/// The zero-backend chat repository for `make demo` / the gallery. Every conversation is USEFUL — the
/// tool-card showcase (every tool card, live) + a pinned chat that exercises the locked modules
/// (markdown+code, thinking, a cancelled turn's honest banner, an @mention snapshot) + an unread
/// markdown/table chat + one archived example; the empty rail-filler threads were pruned (#1). Rail signal
/// states stay covered — pinned / unread green / archived gray, and generating blue plays LIVE on send via
/// a SCRIPTED STREAMING REPLY: every send plays user-echo → thinking deltas → text deltas → close over ~4s
/// through the same frame seam the live gateway uses, then settles the persisted rows so a reload shows the
/// finished turn. Stop mid-stream lands an honest `cancelled`.
///
/// 零后端 chat repository(make demo / gallery):每个对话都有用——工具卡展台(每卡)+ 置顶对话触发已锁模块
/// (markdown+代码 / thinking / 取消回合诚实横幅 / @提及快照)+ 未读 markdown/表格对话 + 一个归档例;空 rail
/// 填充对话已清(#1)。信号仍覆盖:置顶 / 未读绿 / 归档灰,生成蓝随**发送时**脚本流式回放(用户回声→thinking
/// →text→close 约 4s、定格持久行),流中 Stop 落诚实 cancelled。
class DemoChatRepository extends FixtureChatRepository {
  DemoChatRepository({super.conversations, super.messages});

  final List<Timer> _timers = [];
  int _demoSeq = 0;

  static const _thinkingScript =
      '用户在问一个执行类问题。先确认涉及哪个实体,再决定是直接答还是需要查一下最近的执行记录;这里上下文足够,直接组织答案。';
  // Act one for the sidestage: edit_function over the seeded old truth (R-5: the stratum + the real
  // settle diff), streamed op by op. 侧幕第一幕:edit_function 压着旧真相流(R-5 地层+落定真 diff)。
  static const _fnCodeWire =
      'import time\\n\\n'
      'def sync_inventory():\\n'
      '    for attempt in range(3):\\n'
      '        try:\\n'
      '            return _pull_and_merge()\\n'
      '        except SyncError:\\n'
      '            time.sleep(2 ** attempt)\\n'
      '    raise SyncError("retries exhausted")\\n';

  // Act two: a create_document whose args STREAM (the right island stages it live, then the
  // touchpoint signal lands the Cast row). 侧幕第二幕:create_document 流式登台+触点落账。
  static const _docName = 'quarterly-fix.md';
  static const _docBodyWire =
      '# 修复方案\\n\\n'
      '## 根因\\n\\n- issue_date 未做时区归一\\n- 跨年边界 Q4 与次年 Q1 混桶\\n\\n'
      '## 修法\\n\\n1. 入库前统一 astimezone 到本位时区\\n2. 聚合键 floor 到季度首日\\n'
      '3. 对历史数据跑一次回填\\n\\n'
      '## 验证\\n\\n- 抽 2025-12-31 23:50 的三笔票据核对归桶\\n- 对账报表按季度重跑一遍\\n';

  static const _replyScript =
      '收到,我看了一下:\n\n'
      '- **根因**:`issue_date` 没做时区归一,跨年边界上 Q4 和次年 Q1 混桶\n'
      '- **修法**:先归一到本位时区,再按季度聚合\n\n'
      '```py\ndate.astimezone(tz).quarter\n```\n\n'
      '要不要我顺手把这个写成一个 function 挂进 workflow?';

  // D-021 — the send-failure bubble (retry / discard), scoped to cv_flaky's first send so the failed
  // optimistic bubble + its retry/discard buttons are demo-able without breaking every other send. One-
  // shot → Retry succeeds and plays the normal reply. cv_flaky 首发失败→乐观泡长出重试/丢弃,重试即成。
  bool _flakySendFailed = false;

  @override
  Future<String> sendMessage(
    String conversationId, {
    required String content,
    List<String> attachmentIds = const [],
    List<({String type, String id})> mentions = const [],
  }) async {
    if (conversationId == 'cv_flaky' && !_flakySendFailed) {
      _flakySendFailed = true;
      throw StateError('scripted send failure');
    }
    final assistantId = await super.sendMessage(
      conversationId,
      content: content,
      attachmentIds: attachmentIds,
      mentions: mentions,
    );
    // Mirror the backend's dot truth: the row turns generating and the rail hears a turn pulse.
    // 镜像后端点真相:行转 generating,rail 收到回合脉冲。
    final conv = conversationOrNull(conversationId);
    if (conv != null) {
      upsert(conv.copyWith(isGenerating: true, hasUnread: false));
    }
    emitTurnSignal(conversationId, TurnSignalKind.turnOpen);
    _playReply(conversationId, assistantId, userText: content);
    return assistantId;
  }

  // D-012 — the Cast ledger's first-fetch failure + retry, scoped to one seeded conversation so the rest
  // of the demo stays healthy. touchpointLedgerProvider is autoDispose.family and hydrates lazily only
  // when that conversation's sidestage opens, so this error appears ONLY when the user opens cv_flaky's
  // Cast; the one-shot means Retry succeeds. cv_flaky 首拉台账失败→重试成(仅此对话,懒加载不伤 happy-path)。
  bool _flakyCastFailed = false;
  @override
  Future<Page<Touchpoint>> listTouchpoints(
    String conversationId, {
    String? cursor,
    int? limit,
    String? kind,
    TouchpointVerb? verb,
  }) async {
    if (conversationId == 'cv_flaky' && !_flakyCastFailed) {
      _flakyCastFailed = true;
      throw StateError('scripted touchpoint fetch failure');
    }
    return super.listTouchpoints(
      conversationId,
      cursor: cursor,
      limit: limit,
      kind: kind,
      verb: verb,
    );
  }

  @override
  Future<void> cancelTurn(String conversationId) async {
    await super.cancelTurn(conversationId);
    // Stop the playback and land an honest cancelled terminal — like the backend would. 停回放,落诚实 cancelled。
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    final send = lastSend;
    if (send == null || send.conversationId != conversationId) return;
    emitFrame(
      conversationId,
      StreamEnvelope(
        seq: 900 + _demoSeq++,
        scope: StreamScope(kind: 'conversation', id: conversationId),
        id: send.assistantId,
        frame: const FrameClose(
          status: 'cancelled',
          result: StreamNode(
            type: 'message',
            content: {
              'role': 'assistant',
              'status': 'cancelled',
              'stopReason': 'cancelled',
            },
          ),
        ),
      ),
    );
    final conv = conversationOrNull(conversationId);
    if (conv != null) {
      upsert(conv.copyWith(isGenerating: false)); // cancelled ≠ unread 取消不算未读
    }
    emitTurnSignal(conversationId, TurnSignalKind.turnClose);
  }

  // The scripted turn: echo → assistant open → thinking (deltas, close) → text (deltas, close) → stop.
  // 脚本回合:回声→assistant open→thinking(delta,close)→text(delta,close)→终帧。
  void _playReply(
    String conversationId,
    String assistantId, {
    required String userText,
  }) {
    final scope = StreamScope(kind: 'conversation', id: conversationId);
    final userId = 'msg_demo_u${_demoSeq++}';
    final thinkId = 'blk_demo_t${_demoSeq++}';
    final textId = 'blk_demo_x${_demoSeq++}';
    var at = 250; // ms timeline 时间线
    void frame(int seq, String id, StreamFrame f, {int step = 0}) {
      at += step;
      _timers.add(
        Timer(
          Duration(milliseconds: at),
          () => emitFrame(
            conversationId,
            StreamEnvelope(seq: seq, scope: scope, id: id, frame: f),
          ),
        ),
      );
    }

    // Durable user echo (inline content — mirrors the backend shape). 用户回声(内联文本,镜像后端)。
    frame(
      1,
      userId,
      const FrameOpen(
        node: StreamNode(type: 'message', content: {'role': 'user'}),
      ),
    );
    frame(
      2,
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
      3,
      assistantId,
      const FrameOpen(
        node: StreamNode(type: 'message', content: {'role': 'assistant'}),
      ),
      step: 200,
    );

    // thinking: streams in small clumps. thinking:小簇流。
    frame(
      4,
      thinkId,
      FrameOpen(
        parentId: assistantId,
        node: const StreamNode(type: 'reasoning', content: {'content': ''}),
      ),
      step: 150,
    );
    for (var i = 0; i < _thinkingScript.length; i += 6) {
      frame(
        0,
        thinkId,
        FrameDelta(
          chunk: _thinkingScript.substring(
            i,
            (i + 6).clamp(0, _thinkingScript.length),
          ),
        ),
        step: 70,
      );
    }
    frame(
      5,
      thinkId,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'reasoning',
          content: {'content': _thinkingScript},
        ),
      ),
      step: 120,
    );

    // ACT ONE — edit_function: the id lands first (R-5 fetches the old truth → the stratum), then
    // ops stream (set_meta chip, set_code line by line), the close carries the snapshot, the result
    // lands, the touchpoint writes the ledger. 第一幕 edit_function:首键即 id(R-5 取旧真相→地层),
    // ops 逐个流(set_meta 芯片/set_code 逐行),关帧快照,回执落地,触点落账。
    final fnToolId = 'blk_demo_f${_demoSeq++}';
    final fnResultId = 'blk_demo_fr${_demoSeq++}';
    frame(
      13,
      fnToolId,
      FrameOpen(
        parentId: assistantId,
        node: const StreamNode(
          type: 'tool_call',
          content: {'name': 'edit_function', 'danger': 'safe'},
        ),
      ),
      step: 250,
    );
    frame(
      0,
      fnToolId,
      const FrameDelta(
        chunk: '{"functionId":"fn_sync","summary":"给 sync_inventory 加指数退避重试",',
      ),
      step: 150,
    );
    frame(
      0,
      fnToolId,
      const FrameDelta(
        chunk: '"ops":[{"op":"set_meta","description":"sync with retry"},',
      ),
      step: 220,
    );
    frame(
      0,
      fnToolId,
      const FrameDelta(chunk: '{"op":"set_code","code":"'),
      step: 160,
    );
    for (var i = 0; i < _fnCodeWire.length; i += 14) {
      frame(
        0,
        fnToolId,
        FrameDelta(
          chunk: _fnCodeWire.substring(
            i,
            (i + 14).clamp(0, _fnCodeWire.length),
          ),
        ),
        step: 60,
      );
    }
    frame(0, fnToolId, const FrameDelta(chunk: '"}]}'), step: 60);
    const fnArgs =
        '{"functionId":"fn_sync","summary":"给 sync_inventory 加指数退避重试","ops":[{"op":"set_meta","description":"sync with retry"},{"op":"set_code","code":"$_fnCodeWire"}]}';
    frame(
      14,
      fnToolId,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_call',
          content: {
            'name': 'edit_function',
            'arguments': fnArgs,
            'entityName': 'sync_inventory',
            'summary': '给 sync_inventory 加指数退避重试',
          },
        ),
      ),
      step: 320,
    );
    frame(
      15,
      fnResultId,
      FrameOpen(
        parentId: fnToolId,
        node: const StreamNode(
          type: 'tool_result',
          content: {
            'content': '{"id":"fn_sync","version":4,"envStatus":"ready"}',
          },
        ),
      ),
      step: 80,
    );
    frame(
      16,
      fnResultId,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_result',
          content: {
            'content': '{"id":"fn_sync","version":4,"envStatus":"ready"}',
          },
        ),
      ),
      step: 40,
    );
    _timers.add(
      Timer(Duration(milliseconds: at + 40), () {
        touch(
          Touchpoint(
            id: 'tp_demo_fn${_demoSeq++}',
            conversationId: conversationId,
            itemKind: 'function',
            itemId: 'fn_sync',
            itemName: 'sync_inventory',
            verb: TouchpointVerb.edited,
            lastActor: TouchpointActor.assistant,
            count: 1,
            firstAt: DateTime.now().toUtc(),
            lastAt: DateTime.now().toUtc(),
            lastMessageId: fnToolId,
          ),
          seq: 820 + _demoSeq,
        );
      }),
    );

    // ACT TWO — create_document (the show switches stages: fn settles, the doc takes over). 第二幕。
    final toolId = 'blk_demo_c${_demoSeq++}';
    final resultId = 'blk_demo_r${_demoSeq++}';
    const argsHead = '{"name":"$_docName","content":"';
    frame(
      9,
      toolId,
      FrameOpen(
        parentId: assistantId,
        node: const StreamNode(
          type: 'tool_call',
          content: {'name': 'create_document', 'danger': 'safe'},
        ),
      ),
      step: 250,
    );
    frame(0, toolId, const FrameDelta(chunk: argsHead), step: 120);
    for (var i = 0; i < _docBodyWire.length; i += 12) {
      frame(
        0,
        toolId,
        FrameDelta(
          chunk: _docBodyWire.substring(
            i,
            (i + 12).clamp(0, _docBodyWire.length),
          ),
        ),
        step: 55,
      );
    }
    frame(0, toolId, const FrameDelta(chunk: '"}'), step: 55);
    const fullArgs = '$argsHead$_docBodyWire"}';
    frame(
      10,
      toolId,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_call',
          content: {
            'name': 'create_document',
            'arguments': fullArgs,
            'entityName': _docName,
            'summary': '把修复方案落成文档',
          },
        ),
      ),
      step: 300,
    );
    frame(
      11,
      resultId,
      FrameOpen(
        parentId: toolId,
        node: const StreamNode(
          type: 'tool_result',
          content: {
            'content':
                'Created document "$_docName" (id=doc_demo_fix, path=/$_docName)',
          },
        ),
      ),
      step: 80,
    );
    frame(
      12,
      resultId,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_result',
          content: {
            'content':
                'Created document "$_docName" (id=doc_demo_fix, path=/$_docName)',
          },
        ),
      ),
      step: 40,
    );
    _timers.add(
      Timer(Duration(milliseconds: at + 40), () {
        touch(
          Touchpoint(
            id: 'tp_demo_${_demoSeq++}',
            conversationId: conversationId,
            itemKind: 'document',
            itemId: 'doc_demo_fix',
            itemName: _docName,
            verb: TouchpointVerb.created,
            lastActor: TouchpointActor.assistant,
            count: 1,
            firstAt: DateTime.now().toUtc(),
            lastAt: DateTime.now().toUtc(),
            lastMessageId: toolId,
          ),
          seq: 800 + _demoSeq,
        );
      }),
    );

    // ACT 2.5 — the ensemble: two Subagents run in parallel with a live todo board (分镜 c).
    // 幕 2.5:双分身并行+活任务板(分镜 c)。
    final sa1 = 'blk_demo_sa${_demoSeq++}';
    final sa2 = 'blk_demo_sb${_demoSeq++}';
    // The execution bracket (G4): a real backend opens/closes a tool_result around the delegate's
    // run — the tool_call close only ends the ARG stream, and the sidestage judges liveness by the
    // execution phase. 执行括号(G4):真后端以 tool_result 围住分身执行;参流关≠执行终态。
    final sa1r = 'blk_demo_sar${_demoSeq++}';
    final sa2r = 'blk_demo_sbr${_demoSeq++}';
    void todoFrame(List<TodoEntry> items, {int seq = 30}) {
      _timers.add(
        Timer(Duration(milliseconds: at), () {
          emitTodos(
            ConversationTodos(conversationId: conversationId, todos: items),
            seq: seq + _demoSeq,
          );
        }),
      );
    }

    at += 250;
    todoFrame(const [
      TodoEntry(
        content: '审计最近失败的执行',
        activeForm: '正在审计失败执行…',
        status: 'in_progress',
      ),
      TodoEntry(content: '核对告警渠道配置', status: 'pending'),
    ]);
    frame(
      21,
      sa1,
      FrameOpen(
        parentId: assistantId,
        node: const StreamNode(
          type: 'tool_call',
          content: {'name': 'Subagent', 'danger': 'safe'},
        ),
      ),
      step: 200,
    );
    frame(
      0,
      sa1,
      const FrameDelta(
        chunk: '{"description":"审计最近失败的执行","prompt":"拉最近十条失败记录并归因"}',
      ),
      step: 120,
    );
    frame(
      22,
      '${sa1}_m',
      FrameOpen(
        parentId: sa1,
        node: const StreamNode(type: 'message', content: {'role': 'assistant'}),
      ),
      step: 150,
    );
    frame(
      23,
      '${sa1}_r',
      FrameOpen(
        parentId: '${sa1}_m',
        node: const StreamNode(type: 'reasoning', content: {'content': ''}),
      ),
      step: 100,
    );
    for (final chunk in const ['先拉最近', '十条失败记录,', '按错误码分桶,', '再对时间轴找共因']) {
      frame(0, '${sa1}_r', FrameDelta(chunk: chunk), step: 320);
    }
    frame(
      24,
      sa2,
      FrameOpen(
        parentId: assistantId,
        node: const StreamNode(
          type: 'tool_call',
          content: {'name': 'Subagent', 'danger': 'safe'},
        ),
      ),
      step: 400,
    );
    frame(
      0,
      sa2,
      const FrameDelta(
        chunk: '{"description":"核对告警渠道配置","prompt":"检查通知渠道与静默窗口"}',
      ),
      step: 120,
    );
    frame(
      25,
      '${sa2}_m',
      FrameOpen(
        parentId: sa2,
        node: const StreamNode(type: 'message', content: {'role': 'assistant'}),
      ),
      step: 150,
    );
    frame(
      26,
      '${sa2}_r',
      FrameOpen(
        parentId: '${sa2}_m',
        node: const StreamNode(type: 'reasoning', content: {'content': ''}),
      ),
      step: 100,
    );
    for (final chunk in const ['列出全部渠道,', '标出无静默窗口的三条']) {
      frame(0, '${sa2}_r', FrameDelta(chunk: chunk), step: 340);
    }
    frame(
      27,
      '${sa1}_r',
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'reasoning',
          content: {'content': '先拉最近十条失败记录,按错误码分桶,再对时间轴找共因'},
        ),
      ),
      step: 200,
    );
    frame(
      28,
      sa1,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_call',
          content: {
            'name': 'Subagent',
            'status': 'completed',
            'stopReason': 'end_turn',
            'tokens': {'in': 1840, 'out': 620},
            'arguments': '{"description":"审计最近失败的执行"}',
          },
        ),
      ),
      step: 300,
    );
    frame(
      45,
      sa1r,
      FrameOpen(
        parentId: sa1,
        node: const StreamNode(type: 'tool_result', content: {'content': ''}),
      ),
      step: 40,
    );
    frame(
      46,
      sa1r,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_result',
          content: {'content': '已按错误码分桶:超时 6 / 鉴权 3 / 参数 1,共因指向网关超时。'},
        ),
      ),
      step: 160,
    );
    at += 150;
    todoFrame(const [
      TodoEntry(content: '审计最近失败的执行', status: 'completed'),
      TodoEntry(
        content: '核对告警渠道配置',
        activeForm: '正在核对告警渠道…',
        status: 'in_progress',
      ),
    ]);
    frame(
      29,
      '${sa2}_r',
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'reasoning',
          content: {'content': '列出全部渠道,标出无静默窗口的三条'},
        ),
      ),
      step: 500,
    );
    frame(
      30,
      sa2,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_call',
          content: {
            'name': 'Subagent',
            'status': 'completed',
            'stopReason': 'end_turn',
            'tokens': {'in': 1210, 'out': 340},
            'arguments': '{"description":"核对告警渠道配置"}',
          },
        ),
      ),
      step: 260,
    );
    frame(
      47,
      sa2r,
      FrameOpen(
        parentId: sa2,
        node: const StreamNode(type: 'tool_result', content: {'content': ''}),
      ),
      step: 40,
    );
    frame(
      48,
      sa2r,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_result',
          content: {'content': '全部渠道已核对:sms / wecom / slack-ops 三条无静默窗口。'},
        ),
      ),
      step: 160,
    );
    at += 120;
    todoFrame(const [
      TodoEntry(content: '审计最近失败的执行', status: 'completed'),
      TodoEntry(content: '核对告警渠道配置', status: 'completed'),
    ]);

    // ACT 2.8 — write_memory: the memo slip (a long-tail stage spot-check on the real machine).
    // 幕 2.8:记忆笺(长尾舞台真机抽查)。
    final memId = 'blk_demo_mm${_demoSeq++}';
    frame(
      31,
      memId,
      FrameOpen(
        parentId: assistantId,
        node: const StreamNode(
          type: 'tool_call',
          content: {'name': 'write_memory', 'danger': 'safe'},
        ),
      ),
      step: 250,
    );
    frame(
      0,
      memId,
      const FrameDelta(chunk: '{"name":"retry-policy","content":"重试统一走'),
      step: 200,
    );
    frame(
      0,
      memId,
      const FrameDelta(chunk: '指数退避(1s→2s→4s,最多 3 次),'),
      step: 320,
    );
    frame(
      0,
      memId,
      const FrameDelta(chunk: '超限抛 SyncError 交上游降级。"}'),
      step: 320,
    );
    frame(
      32,
      memId,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_call',
          content: {
            'name': 'write_memory',
            'arguments':
                '{"name":"retry-policy","content":"重试统一走指数退避(1s→2s→4s,最多 3 次),超限抛 SyncError 交上游降级。"}',
            'entityName': 'retry-policy',
          },
        ),
      ),
      step: 300,
    );
    _timers.add(
      Timer(Duration(milliseconds: at + 40), () {
        touch(
          Touchpoint(
            id: 'tp_demo_mm${_demoSeq++}',
            conversationId: conversationId,
            itemKind: 'memory',
            itemId: 'retry-policy',
            itemName: 'retry-policy',
            verb: TouchpointVerb.created,
            lastActor: TouchpointActor.assistant,
            count: 1,
            firstAt: DateTime.now().toUtc(),
            lastAt: DateTime.now().toUtc(),
            lastMessageId: memId,
          ),
          seq: 860 + _demoSeq,
        );
      }),
    );

    // ACT 2.9 — trigger_workflow: the LIVE RUN SCROLL (W7): the 202 receipt holds the stage,
    // node ticks roll in quiet rows (the gate's taken port visible), the durable terminal settles.
    // 幕 2.9:活运行卷——202 回执驻台,节点 tick 逐行静落(门的选中 port 可见),durable 终态落定。
    final twId = 'blk_demo_tw${_demoSeq++}';
    final twRes = 'blk_demo_twr${_demoSeq++}';
    frame(
      33,
      twId,
      FrameOpen(
        parentId: assistantId,
        node: const StreamNode(
          type: 'tool_call',
          content: {'name': 'trigger_workflow', 'danger': 'safe'},
        ),
      ),
      step: 300,
    );
    frame(
      0,
      twId,
      const FrameDelta(
        chunk: '{"workflowId":"wf_night","payload":{"date":"2026-07-08"}}',
      ),
      step: 250,
    );
    frame(
      34,
      twRes,
      FrameOpen(
        parentId: twId,
        node: const StreamNode(
          type: 'tool_result',
          content: {'content': '{"flowrunId":"fr_demo_1","status":"running"}'},
        ),
      ),
      step: 200,
    );
    frame(
      35,
      twRes,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_result',
          content: {'content': '{"flowrunId":"fr_demo_1","status":"running"}'},
        ),
      ),
      step: 100,
    );
    frame(
      36,
      twId,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_call',
          content: {
            'name': 'trigger_workflow',
            'arguments':
                '{"workflowId":"wf_night","payload":{"date":"2026-07-08"}}',
            'entityName': 'nightly_rollup',
          },
        ),
      ),
      step: 150,
    );
    void runTick(int atMs, String nodeId, String status, {String port = ''}) {
      _timers.add(
        Timer(Duration(milliseconds: atMs), () {
          emitWorkflowFrame(
            'wf_night',
            StreamEnvelope(
              seq: 0,
              scope: const StreamScope(kind: 'workflow', id: 'wf_night'),
              id: 'demo_tick_${_demoSeq++}',
              frame: FrameSignal(
                node: StreamNode(
                  type: 'run',
                  content: {
                    'flowrunId': 'fr_demo_1',
                    'nodeId': nodeId,
                    'iteration': 0,
                    'status': status,
                    if (port.isNotEmpty) 'port': port,
                  },
                ),
              ),
            ),
          );
        }),
      );
    }

    runTick(at + 700, 'pull_invoices', 'completed');
    runTick(at + 1500, 'fix_timezone', 'completed');
    runTick(at + 2300, 'quality_gate', 'completed', port: 'pass');
    runTick(at + 3100, 'rollup', 'completed');
    _timers.add(
      Timer(Duration(milliseconds: at + 3900), () {
        emitWorkflowFrame(
          'wf_night',
          StreamEnvelope(
            seq: 900 + _demoSeq,
            scope: const StreamScope(kind: 'workflow', id: 'wf_night'),
            id: 'demo_term_${_demoSeq++}',
            frame: const FrameSignal(
              node: StreamNode(
                type: 'run_terminal',
                content: {'flowrunId': 'fr_demo_1', 'status': 'completed'},
              ),
            ),
          ),
        );
      }),
    );
    at += 4200;

    // ACT THREE — create_workflow: the graph GROWS on the canvas op by op (分镜 b). 第三幕:图逐 op 生长。
    final wfToolId = 'blk_demo_w${_demoSeq++}';
    final wfResultId = 'blk_demo_wr${_demoSeq++}';
    frame(
      17,
      wfToolId,
      FrameOpen(
        parentId: assistantId,
        node: const StreamNode(
          type: 'tool_call',
          content: {'name': 'create_workflow', 'danger': 'safe'},
        ),
      ),
      step: 300,
    );
    frame(
      0,
      wfToolId,
      const FrameDelta(
        chunk: '{"name":"quarterly_rollup","summary":"跨年修桶的季度汇总流程","ops":[',
      ),
      step: 150,
    );
    const wfOps = [
      '{"op":"add_node","node":{"id":"pull","kind":"action","ref":"fn_pull_invoices"}}',
      ',{"op":"add_node","node":{"id":"fix_tz","kind":"action","ref":"fn_sync","input":{"rows":"pull.result"}}}',
      ',{"op":"add_edge","edge":{"id":"e1","from":"pull","to":"fix_tz"}}',
      ',{"op":"add_node","node":{"id":"rollup","kind":"action","ref":"fn_rollup","input":{"rows":"fix_tz.result","cap":"input.cap"}}}',
      ',{"op":"add_edge","edge":{"id":"e2","from":"fix_tz","to":"rollup"}}',
      ',{"op":"add_node","node":{"id":"gate","kind":"approval","ref":"ap_big_spend"}}',
      ',{"op":"add_edge","edge":{"id":"e3","from":"rollup","to":"gate"}}',
    ];
    for (final op in wfOps) {
      frame(0, wfToolId, FrameDelta(chunk: op), step: 420);
    }
    frame(0, wfToolId, const FrameDelta(chunk: ']}'), step: 120);
    final wfArgs =
        '{"name":"quarterly_rollup","summary":"跨年修桶的季度汇总流程","ops":[${wfOps.join()}]}';
    frame(
      18,
      wfToolId,
      FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_call',
          content: {
            'name': 'create_workflow',
            'arguments': wfArgs,
            'entityName': 'quarterly_rollup',
            'summary': '跨年修桶的季度汇总流程',
          },
        ),
      ),
      step: 320,
    );
    frame(
      19,
      wfResultId,
      FrameOpen(
        parentId: wfToolId,
        node: const StreamNode(
          type: 'tool_result',
          content: {
            'content': '{"id":"wf_demo_roll","version":1,"nodes":4,"edges":3}',
          },
        ),
      ),
      step: 80,
    );
    frame(
      20,
      wfResultId,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'tool_result',
          content: {
            'content': '{"id":"wf_demo_roll","version":1,"nodes":4,"edges":3}',
          },
        ),
      ),
      step: 40,
    );
    _timers.add(
      Timer(Duration(milliseconds: at + 40), () {
        touch(
          Touchpoint(
            id: 'tp_demo_wf${_demoSeq++}',
            conversationId: conversationId,
            itemKind: 'workflow',
            itemId: 'wf_demo_roll',
            itemName: 'quarterly_rollup',
            verb: TouchpointVerb.created,
            lastActor: TouchpointActor.assistant,
            count: 1,
            firstAt: DateTime.now().toUtc(),
            lastAt: DateTime.now().toUtc(),
            lastMessageId: wfToolId,
          ),
          seq: 840 + _demoSeq,
        );
      }),
    );

    // text: streams like tokens. text:token 式流。
    frame(
      6,
      textId,
      FrameOpen(
        parentId: assistantId,
        node: const StreamNode(type: 'text', content: {'content': ''}),
      ),
      step: 150,
    );
    for (var i = 0; i < _replyScript.length; i += 5) {
      frame(
        0,
        textId,
        FrameDelta(
          chunk: _replyScript.substring(
            i,
            (i + 5).clamp(0, _replyScript.length),
          ),
        ),
        step: 24,
      );
    }
    frame(
      7,
      textId,
      const FrameClose(
        status: 'completed',
        result: StreamNode(type: 'text', content: {'content': _replyScript}),
      ),
      step: 100,
    );
    frame(
      8,
      assistantId,
      const FrameClose(
        status: 'completed',
        result: StreamNode(
          type: 'message',
          content: {
            'role': 'assistant',
            'status': 'completed',
            'stopReason': 'end_turn',
            'inputTokens': 220,
            'outputTokens': 180,
          },
        ),
      ),
      step: 80,
    );

    // Settle the persisted rows so a reload shows the finished turn; an un-titled thread then
    // AUTO-TITLES (mirrors the backend's post-first-turn hook) — the rail row + head play the
    // one-shot typewriter. 定格持久行;未命名线程随后自动命名(镜像后端首回合钩子)——rail 行+头播打字机。
    _timers.add(
      Timer(Duration(milliseconds: at + 40), () {
        replaceMessage(
          conversationId,
          ChatMessage(
            id: assistantId,
            conversationId: conversationId,
            role: 'assistant',
            status: 'completed',
            stopReason: 'end_turn',
            inputTokens: 220,
            outputTokens: 180,
            blocks: [
              ChatBlock(
                id: thinkId,
                type: 'reasoning',
                content: _thinkingScript,
                status: 'completed',
              ),
              ChatBlock(
                id: fnToolId,
                type: 'tool_call',
                content: '',
                status: 'completed',
                attrs: {
                  'tool': 'edit_function',
                  'arguments': fnArgs,
                  'entityName': 'sync_inventory',
                  'summary': '给 sync_inventory 加指数退避重试',
                },
              ),
              ChatBlock(
                id: fnResultId,
                type: 'tool_result',
                content: '{"id":"fn_sync","version":4,"envStatus":"ready"}',
                status: 'completed',
                attrs: {'parentBlockId': fnToolId},
              ),
              ChatBlock(
                id: wfToolId,
                type: 'tool_call',
                content: '',
                status: 'completed',
                attrs: {
                  'tool': 'create_workflow',
                  'arguments': wfArgs,
                  'entityName': 'quarterly_rollup',
                  'summary': '跨年修桶的季度汇总流程',
                },
              ),
              ChatBlock(
                id: wfResultId,
                type: 'tool_result',
                content:
                    '{"id":"wf_demo_roll","version":1,"nodes":4,"edges":3}',
                status: 'completed',
                attrs: {'parentBlockId': wfToolId},
              ),
              ChatBlock(
                id: toolId,
                type: 'tool_call',
                content: '',
                status: 'completed',
                attrs: {
                  'tool': 'create_document',
                  'arguments': fullArgs,
                  'entityName': _docName,
                  'summary': '把修复方案落成文档',
                },
              ),
              ChatBlock(
                id: resultId,
                type: 'tool_result',
                content:
                    'Created document "$_docName" (id=doc_demo_fix, path=/$_docName)',
                status: 'completed',
                attrs: {'parentBlockId': toolId},
              ),
              ChatBlock(
                id: textId,
                type: 'text',
                content: _replyScript,
                status: 'completed',
              ),
            ],
            createdAt: DateTime.now().toUtc(),
          ),
        );
        final conv = conversationOrNull(conversationId);
        if (conv != null) {
          // Terminal truth: generating off, unread on (completed lands unseen — the rail's green).
          // 终态真相:generating 灭、unread 亮(完成未读=rail 绿)。
          var next = conv.copyWith(isGenerating: false, hasUnread: true);
          if (next.title.trim().isEmpty) {
            next = next.copyWith(title: _demoTitle(userText), autoTitled: true);
            emitSignal(
              ConversationSignal(
                id: conversationId,
                action: ConversationAction.updated,
                durable: true,
              ),
            );
          }
          upsert(next);
        }
        emitTurnSignal(conversationId, TurnSignalKind.turnClose);
      }),
    );
  }

  @override
  Future<void> dispose() async {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    await super.dispose();
  }
}

/// The `make demo` seed — rail spread + module-exercising transcripts. 零后端种子。
DemoChatRepository demoChatRepository() {
  final now = DateTime.now().toUtc();
  DateTime ago(Duration d) => now.subtract(d);

  Conversation conv(
    String id,
    String title,
    Duration since, {
    bool pinned = false,
    bool archived = false,
    bool generating = false,
    bool awaiting = false,
    bool unread = false,
  }) {
    final at = ago(since);
    return Conversation(
      id: id,
      title: title,
      autoTitled: true,
      pinned: pinned,
      archived: archived,
      createdAt: at.subtract(const Duration(minutes: 5)),
      updatedAt: at,
      lastMessageAt: at,
      isGenerating: generating,
      awaitingInput: awaiting,
      hasUnread: unread,
    );
  }

  ChatMessage msg(
    String id,
    String conv,
    String role,
    Duration since, {
    String status = 'completed',
    String stopReason = '',
    Map<String, dynamic>? attrs,
    List<ChatBlock> blocks = const [],
  }) => ChatMessage(
    id: id,
    conversationId: conv,
    role: role,
    status: status,
    stopReason:
        stopReason.isEmpty && role == 'assistant' && status == 'completed'
        ? 'end_turn'
        : stopReason,
    attrs: attrs,
    blocks: blocks,
    createdAt: ago(since),
  );

  ChatBlock blk(
    String id,
    String type,
    String content, {
    Map<String, dynamic>? attrs,
    String parent = '',
  }) => ChatBlock(
    id: id,
    type: type,
    content: content,
    status: 'completed',
    attrs: attrs,
    parentBlockId: parent,
  );

  // The tool-card showcase conversations (B1–B7): each exercises a family group so `make demo` displays
  // every tool card live. Folded into the rail (newest-first) + the messages map. 工具卡展台折入 demo。
  final shows = showcaseConversations();

  Touchpoint tp(
    String id,
    String kind,
    String itemId,
    String name,
    TouchpointVerb verb,
    Duration since, {
    int count = 1,
    TouchpointActor actor = TouchpointActor.assistant,
  }) => Touchpoint(
    id: id,
    conversationId: 'cv_sync',
    itemKind: kind,
    itemId: itemId,
    itemName: name,
    verb: verb,
    lastActor: actor,
    count: count,
    firstAt: ago(since + const Duration(minutes: 3)),
    lastAt: ago(since),
  );

  // D-005 — a realistic chat HISTORY so the rail paginates past its 30-row page (loadMore + the skeleton
  // foot). Each is a SHORT but REAL Q&A — honoring #1 (no empty fillers; every row opens to content), just
  // brief. Newest of these sits below the showcase (hours-old). 真实历史使 rail 翻页(每行仍有内容)。
  const pastTopics = <({String id, String title, String q, String a})>[
    (
      id: 'p01',
      title: '库存漂移怎么排查',
      q: '库存数字对不上,先从哪看?',
      a: '先手动跑一次 `nightly_rollup` 对账,再比对 `sync_inventory` 最近三次执行的输入差异。多半是某个源的分页没取全。',
    ),
    (
      id: 'p02',
      title: 'webhook 签名怎么验',
      q: 'GitHub 的 webhook 签名前端要怎么校验?',
      a: '不在前端验——签名用 `X-Hub-Signature-256` 头,由后端 trigger 用共享密钥做 HMAC-SHA256 比对。前端只读结果。',
    ),
    (
      id: 'p03',
      title: 'cron 表达式解释',
      q: '`0 2 * * 1` 是什么意思?',
      a: '每周一凌晨 02:00 触发一次(分 时 日 月 周)。',
    ),
    (
      id: 'p04',
      title: 'SQLite 备份',
      q: '本地数据怎么备份?',
      a: '直接 `cp` 那个 SQLite 文件即可——它就是唯一事实源。停一下 sidecar 再拷更稳。',
    ),
    (
      id: 'p05',
      title: '退避重试参数',
      q: '重试退避设几次合适?',
      a: '指数退避 1s→2s→4s,最多 3 次;超限抛 `SyncError` 交上游降级。',
    ),
    (
      id: 'p06',
      title: '沙箱 python 版本',
      q: '函数用的是哪个 python?',
      a: '默认 3.12;每个函数的 env 可钉自己的版本,在实体详情的沙箱段看得到。',
    ),
    (
      id: 'p07',
      title: 'workflow 并发策略',
      q: 'concurrency 选 skip 还是 queue?',
      a: 'skip=同一时刻只跑一个、后来的丢弃;queue=排队。对账这类幂等任务用 skip 就好。',
    ),
    (
      id: 'p08',
      title: '审批超时行为',
      q: '审批一直没人点会怎样?',
      a: '看 approval 配的 timeoutBehavior——reject/approve/fail 三选一;留空则永不超时,一直停车等人。',
    ),
    (
      id: 'p09',
      title: 'MCP 装 filesystem',
      q: '怎么加一个文件系统 MCP?',
      a: '在设置的 MCP 面板从市场装 `filesystem`,给它一个 root 目录做读写边界。',
    ),
    (
      id: 'p10',
      title: '快捷键改绑',
      q: '切左岛的快捷键能改吗?',
      a: '能,设置→快捷键面板逐命令录新键,热生效;⌘B 是默认。',
    ),
    (id: 'p11', title: '深色模式', q: '有深色主题吗?', a: '有,跟随系统或在通用设置里手动切。'),
    (
      id: 'p12',
      title: '导出对话',
      q: '对话能导出吗?',
      a: '当前对话是 SQLite 里的 messages 行,可整库备份;单独导出还没做前端入口。',
    ),
    (
      id: 'p13',
      title: 'agent prompt 调优',
      q: 'agent 输出太发散怎么收?',
      a: '在 prompt 里要求引用来源、给 outputSchema 约束字段;下游节点才不至于读自由文本。',
    ),
    (
      id: 'p14',
      title: '触发器 fsnotify',
      q: 'fsnotify 触发器的 pattern 怎么写?',
      a: '给 path + events(create/modify)+ 一个 glob pattern,如 `*.csv`,只对匹配文件触发。',
    ),
    (
      id: 'p15',
      title: '函数依赖查询',
      q: '删函数前怎么看谁在用它?',
      a: '用 `get_relations` 查它的依赖邻域,或看实体详情的 backlinks 段;有依赖会挡删并提示。',
    ),
    (
      id: 'p16',
      title: '控制器 CEL 语法',
      q: '控制分支的 when 怎么写?',
      a: 'CEL 布尔式,写 `input.amount >= 1000` 这种;自上而下首个为真的分支胜,末支恒 `true` 兜底。',
    ),
    (
      id: 'p17',
      title: '文档 wikilink',
      q: '文档里怎么互相引用?',
      a: '打 `@` 选实体或页面,落成 `[[id]]` 双链;渲染成可点药丸,改名不断链。',
    ),
    (
      id: 'p18',
      title: '通知级别',
      q: '通知太吵能关吗?',
      a: '设置→通知面板三档:静音(托盘照收不弹)/仅需处理(只弹 warn·danger)/全部。',
    ),
    (
      id: 'p19',
      title: '出厂重置',
      q: '怎么把一切清空重来?',
      a: '设置→存储的出厂重置:停 sidecar→删数据目录→重启,双闸确认防误触。',
    ),
    (
      id: 'p20',
      title: '一次大重构会话',
      q: '把整套对账流从头理一遍',
      a: '好,我把涉及的函数、控制器、审批、触发器、文档逐个过了一遍(见右岛演员表——这次会话碰过的一切都在那儿按物聚合)。',
    ),
  ];
  final pastChats = [
    for (var i = 0; i < pastTopics.length; i++)
      (
        conv: conv(
          'cv_${pastTopics[i].id}',
          pastTopics[i].title,
          Duration(hours: 6 + i),
        ),
        msgs: [
          msg(
            'm_${pastTopics[i].id}u',
            'cv_${pastTopics[i].id}',
            'user',
            Duration(hours: 6 + i, minutes: 2),
            blocks: [blk('b_${pastTopics[i].id}u', 'text', pastTopics[i].q)],
          ),
          msg(
            'm_${pastTopics[i].id}a',
            'cv_${pastTopics[i].id}',
            'assistant',
            Duration(hours: 6 + i, minutes: 1),
            blocks: [blk('b_${pastTopics[i].id}a', 'text', pastTopics[i].a)],
          ),
        ],
      ),
  ];

  final repo = DemoChatRepository(
    conversations: [
      // Only conversations that DO something when opened (real transcripts) + the archived example — the
      // empty rail-filler threads (daily / diag / keys / notes / research / kickoff, seeded no messages)
      // were pruned so every rail row is useful (#1). Rail states stay covered: pinned (cv_sync) / unread
      // green (cv_weekly) / archived gray (cv_migrate) / generating blue (plays live on send). The pinned
      // demo carries a full transcript (mention + thinking + code + a cancelled turn), not an empty row.
      // 只留打开有内容的对话 + 归档例;空 rail 填充对话已清(#1)。信号仍全覆盖:置顶/未读绿/归档灰/发送时生成蓝。
      conv(
        'cv_sync',
        'AI 编辑 · sync_inventory 加重试',
        const Duration(minutes: 10),
        pinned: true,
      ),
      for (final s in shows)
        s.conv, // the tool-card showcase — every tool card, live 工具卡展台(每卡)
      conv(
        'cv_gate',
        '展台 · 活人闸',
        const Duration(minutes: 2),
        awaiting: true,
      ), // M8: the LIVE gate 活门(琥珀点)
      conv(
        'cv_ask',
        '展台 · 提问待答',
        const Duration(minutes: 4),
        awaiting: true,
      ), // D-002: a LIVE ask_user gate 活问闸
      conv(
        'cv_weekly',
        '周报初稿整理',
        const Duration(hours: 1),
        unread: true,
      ), // unread green + markdown/table
      conv(
        'cv_scroll',
        '展台 · 长卷与深跳',
        const Duration(hours: 3),
      ), // W6: 场次条 + ?around= deep jump 深跳长卷
      conv(
        'cv_flaky',
        '展台 · 出错与恢复',
        const Duration(hours: 4),
      ), // D-012: its Cast ledger fails its first fetch 台账首拉失败
      for (final c in pastChats)
        c.conv, // D-005 history — rail paginates past its 30-row page 历史使 rail 翻页
      conv(
        'cv_migrate',
        '旧版迁移笔记',
        const Duration(days: 40),
        archived: true,
      ), // the archived (gray) example
    ],
    messages: {
      for (final c in pastChats) c.conv.id: c.msgs,
      for (final s in shows) s.conv.id: s.messages,
      // D-012 — a real short transcript; opening its Cast (right island) fails its first touchpoint
      // fetch → the error+retry state, then Retry succeeds (the override above is one-shot). 出错与恢复。
      'cv_flaky': [
        msg(
          'm_fk1',
          'cv_flaky',
          'user',
          const Duration(hours: 4, minutes: 3),
          blocks: [blk('b_fk1', 'text', '刚才网络抖了一下,你这边有影响吗?')],
        ),
        msg(
          'm_fk2',
          'cv_flaky',
          'assistant',
          const Duration(hours: 4, minutes: 2),
          blocks: [
            blk(
              'b_fk2',
              'text',
              '有短暂影响,已自动恢复。右岛的演员表这次首次拉取失败了——点「重试」就能重新载入(前端对瞬时失败都是可重试的,不会丢状态)。',
            ),
          ],
        ),
      ],
      // M8 活人闸: the gate's REAL wire shape — the tool_call block CLOSED (args final; an open
      // block is argsStreaming and can never reach awaitingConfirm), no tool_result yet, the message
      // still streaming, plus a seeded pending interaction. The amber gate (approve/deny) is finally
      // demo-able live, and the rail shows the amber dot (M1 order).
      // M8 活人闸:门的真实线缆形——tool_call 块已关帧(args 定稿;开着=argsStreaming,永远到不了
      // awaitingConfirm)、尚无 tool_result、message 仍 streaming,再种待决 interaction。琥珀门
      // (批/拒)终于可在 demo 活演,rail 同框演琥珀点(M1 顺序)。
      'cv_gate': [
        msg(
          'm_hg1',
          'cv_gate',
          'user',
          const Duration(minutes: 3),
          blocks: [blk('b_hg1', 'text', '把废弃的 legacy_sync 函数删掉吧')],
        ),
        msg(
          'm_hg2',
          'cv_gate',
          'assistant',
          const Duration(minutes: 2),
          status: 'streaming',
          blocks: [
            blk(
              'b_hg_gate',
              'tool_call',
              '{"functionId":"fn_legacy_sync"}',
              attrs: {
                'tool': 'delete_function',
                'danger': 'dangerous',
                'summary': '删除废弃函数 legacy_sync(不可逆)',
              },
            ),
          ],
        ),
      ],
      // D-002 活问闸: the ask_user gate's live wire shape — same as the danger gate (a CLOSED tool_call,
      // no tool_result, the message still streaming), but kind=ask: the gate renders the prompt + option
      // pills + a free-text field. The seeded ask Interaction below carries message + options. 活 ask 门:
      // 同 danger 门的线缆形但 kind=ask,渲 prompt+选项药丸+自由文本框。
      'cv_ask': [
        msg(
          'm_ak1',
          'cv_ask',
          'user',
          const Duration(minutes: 5),
          blocks: [blk('b_ak1', 'text', '帮我把这批发票发出去')],
        ),
        msg(
          'm_ak2',
          'cv_ask',
          'assistant',
          const Duration(minutes: 4),
          status: 'streaming',
          blocks: [
            blk(
              'b_ak_gate',
              'tool_call',
              '{"message":"这批发票要发到哪个环境?","options":["生产环境","预发环境","测试环境"]}',
              attrs: {
                'tool': 'ask_user',
                'danger': 'safe',
                'summary': '向你确认部署环境',
              },
            ),
          ],
        ),
      ],
      // W6 深跳长卷: 64 turns so the head page (30) can't hold it and the TALLER drawer's bottom rows land beyond it — the 场次条 jumps ?around= for real.
      // A folded tool cluster + one dangerous call + an abnormal terminal give the drawer every row kind.
      // 48 回合,头页装不下——场次条真走 ?around=;折叠簇+危险调用+异常终态让抽屉五 kind 齐活。
      'cv_scroll': [
        for (var i = 0; i < 64; i++)
          if (i == 11)
            msg(
              'm_l$i',
              'cv_scroll',
              'assistant',
              Duration(hours: 3, minutes: 96 - 2 * i),
              blocks: [
                blk(
                  'b_l${i}a',
                  'tool_call',
                  '{"query":"库存同步"}',
                  attrs: {'tool': 'search_entities'},
                ),
                blk(
                  'b_l${i}b',
                  'tool_call',
                  '{"functionId":"fn_sync"}',
                  attrs: {'tool': 'get_function'},
                ),
                blk('b_l${i}c', 'text', '查到了,旧版同步函数还挂在两个 workflow 上。'),
              ],
            )
          else if (i == 21)
            // M7: the context-compaction whisper, finally visible in make demo. 压缩低语 demo 可见。
            msg(
              'm_l$i',
              'cv_scroll',
              'assistant',
              Duration(hours: 3, minutes: 96 - 2 * i),
              blocks: [
                blk(
                  'b_l${i}k',
                  'compaction',
                  'Compacted 18 earlier turns into the running summary.',
                ),
                blk('b_l$i', 'text', '第 ${i ~/ 2 + 1} 答:这一段保持现状即可,理由记在盘点手册。'),
              ],
            )
          else if (i == 23)
            msg(
              'm_l$i',
              'cv_scroll',
              'assistant',
              Duration(hours: 3, minutes: 96 - 2 * i),
              blocks: [
                blk(
                  'b_l${i}a',
                  'tool_call',
                  '{"functionId":"fn_legacy"}',
                  attrs: {
                    'tool': 'delete_function',
                    'danger': 'dangerous',
                    'entityName': 'legacy_sync',
                  },
                ),
                blk('b_l${i}b', 'text', '旧函数已删,依赖它的两条边也一并清了。'),
              ],
            )
          else if (i == 35)
            msg(
              'm_l$i',
              'cv_scroll',
              'assistant',
              Duration(hours: 3, minutes: 96 - 2 * i),
              status: 'error',
              stopReason: 'max_tokens',
              blocks: [blk('b_l$i', 'text', '这段清单太长,先给你前半——')],
            )
          else
            msg(
              'm_l$i',
              'cv_scroll',
              i.isEven ? 'user' : 'assistant',
              Duration(hours: 3, minutes: 96 - 2 * i),
              blocks: [
                blk(
                  'b_l$i',
                  'text',
                  i.isEven
                      ? '第 ${i ~/ 2 + 1} 问:盘点脚本第 ${i + 3} 段还需要改吗?'
                      : '第 ${i ~/ 2 + 1} 答:这一段保持现状即可,理由记在盘点手册。',
                ),
              ],
            ),
      ],
      // Exercises every locked module: an @mention snapshot in the user bubble, thinking, markdown+code,
      // and a cancelled turn's honest banner. 触发每个已锁模块。
      'cv_sync': [
        msg(
          'm_s1',
          'cv_sync',
          'user',
          const Duration(minutes: 14),
          attrs: {
            'mentions': [
              {
                'type': 'function',
                'id': 'fn_sync',
                'name': 'sync_inventory',
                'content': '',
              },
            ],
          },
          blocks: [blk('b_s1', 'text', '帮 @sync_inventory 加上失败重试,指数退避')],
        ),
        msg(
          'm_s2',
          'cv_sync',
          'assistant',
          const Duration(minutes: 13),
          blocks: [
            blk(
              'b_s2r',
              'reasoning',
              '用户要给 sync_inventory 加重试。看下现在的实现:直接调用、无退避。装饰器最干净,超限抛 SyncError 让上游决定降级。',
            ),
            blk(
              'b_s2t',
              'text',
              '加好了,要点:\n\n1. **指数退避**:`1s → 2s → 4s`,最多 3 次\n2. 超限抛 `SyncError`,上游 workflow 决定是否降级\n\n```py\n@retry(times=3, backoff=[1, 2, 4])\ndef sync_inventory():\n    ...\n```\n\n已生成新版本 v4 并激活。',
            ),
          ],
        ),
        msg(
          'm_s3',
          'cv_sync',
          'user',
          const Duration(minutes: 12),
          attrs: {
            'attachments': [
              'att_demo_shelf',
            ], // L5: the in-bubble chip rides the seeded still life 泡内 chip
          },
          blocks: [blk('b_s3', 'text', '再帮我把失败告警也加上')],
        ),
        msg(
          'm_s4',
          'cv_sync',
          'assistant',
          const Duration(minutes: 11),
          status: 'cancelled',
          stopReason: 'cancelled',
          blocks: [blk('b_s4', 'text', '好的,告警可以挂在第 3 次失败的分支上,先看下现有的通知渠道…')],
        ),
        msg(
          'm_s4b',
          'cv_sync',
          'user',
          const Duration(minutes: 10, seconds: 40),
          blocks: [blk('b_s4b', 'text', '你先并行调研一下现有的通知渠道有哪些可接入')],
        ),
        // WRK-064 B6: a DELEGATED subagent run. The Subagent tool_call closes on the top-level turn; the
        // delegate's own reasoning/tool_call/text land on a SIBLING sub-message (subagentId ≠ '',
        // attrs.parentBlockId = the tool_call). The transcript folds that trajectory back under the
        // tool_call so the settled subagent row on the sidestage rehydrates its full nested ReAct tail —
        // no touchpoint, no entity, the transcript IS its truth. 落定 subagent 行(嵌套轨迹重水合)。
        msg(
          'm_s5',
          'cv_sync',
          'assistant',
          const Duration(minutes: 10, seconds: 20),
          blocks: [
            blk(
              'b_s5_sa',
              'tool_call',
              '{"description":"调研现有通知渠道并列出可接入项"}',
              attrs: {'tool': 'Subagent'},
            ),
            // The persisted execution bracket (G4) — without it a settled delegate reads as
            // RUNNING forever under the phase law. 持久化执行括号:缺它落定分身按相位律永远「在跑」。
            blk(
              'b_s5_sar',
              'tool_result',
              '调研完成:可用渠道 Slack / 企业微信 / 邮件;建议先接 Slack。',
              parent: 'b_s5_sa',
            ),
            blk(
              'b_s5_t',
              'text',
              '调研完成:可用渠道有 Slack、企业微信、邮件三种,建议先接 Slack(成本最低)。',
            ),
          ],
        ),
        ChatMessage(
          id: 'm_s5_sub',
          conversationId: 'cv_sync',
          role: 'assistant',
          status: 'completed',
          stopReason: 'end_turn',
          subagentId: 'sa_demo',
          inputTokens: 1840,
          outputTokens: 320,
          attrs: {'parentBlockId': 'b_s5_sa'},
          blocks: [
            blk('b_sa_r', 'reasoning', '先看代码里注册了哪些 notifier,再查各渠道的鉴权成本,挑最省事的。'),
            blk(
              'b_sa_t1',
              'tool_call',
              '{"pattern":"notifier","path":"backend/"}',
              attrs: {'tool': 'grep'},
            ),
            blk(
              'b_sa_t2',
              'tool_call',
              '{"file":"backend/internal/infra/notify/registry.go"}',
              attrs: {'tool': 'read'},
            ),
            blk(
              'b_sa_x',
              'text',
              '注册表里有 slack / wecom / email 三个 notifier;slack 只要一个 webhook URL,接入成本最低。',
            ),
          ],
          createdAt: ago(const Duration(minutes: 10, seconds: 5)),
        ),
      ],
      'cv_weekly': [
        msg(
          'm_w1',
          'cv_weekly',
          'user',
          const Duration(hours: 2),
          blocks: [blk('b_w1', 'text', '把这周的进展整理成周报初稿')],
        ),
        msg(
          'm_w2',
          'cv_weekly',
          'assistant',
          const Duration(hours: 1),
          blocks: [
            blk(
              'b_w2',
              'text',
              '## 本周进展\n\n- 完成 sync_inventory 重试改造(v4 已激活)\n- flowrun 失败率从 4.2% 降到 0.8%\n\n| 指标 | 上周 | 本周 |\n|:--|--:|--:|\n| 失败率 | 4.2% | 0.8% |\n| 平均时延 | 3.1s | 2.4s |\n\n> 下周重点:告警渠道接入',
            ),
          ],
        ),
      ],
      // The archived (gray) example — a short, done conversation so the archived filter isn't empty. 归档例。
      'cv_migrate': [
        msg(
          'm_mig1',
          'cv_migrate',
          'user',
          const Duration(days: 40),
          blocks: [blk('b_mig1', 'text', '把旧版三个 handler 的迁移笔记归档一下')],
        ),
        msg(
          'm_mig2',
          'cv_migrate',
          'assistant',
          const Duration(days: 40),
          blocks: [
            blk(
              'b_mig2',
              'text',
              '已整理:旧版 3 个 handler 全部迁到新契约,迁移要点记在文档《迁移笔记》。这条对话可以归档了。',
            ),
          ],
        ),
      ],
    },
  );
  // R-5 old truth: the function the demo's edit act plays over (the stratum + the real settle diff).
  // R-5 旧真相:demo edit 幕压着演的函数(地层+落定真 diff)。
  repo.functions['fn_sync'] = FunctionEntity(
    id: 'fn_sync',
    name: 'sync_inventory',
    description: 'inventory sync',
    activeVersionId: 'fv_3',
    activeVersion: FunctionVersion(
      id: 'fv_3',
      functionId: 'fn_sync',
      version: 3,
      code: 'def sync_inventory():\n    return _pull_and_merge()\n',
      createdAt: ago(const Duration(days: 2)),
      updatedAt: ago(const Duration(days: 2)),
    ),
    createdAt: ago(const Duration(days: 9)),
    updatedAt: ago(const Duration(days: 2)),
  );
  // Truth snapshots so the pinned demo's SETTLED rows open to their full stage (WRK-064 sceneFromTruth):
  // sync_inventory → code, nightly_rollup → the graph, 值班手册 → the prose. 落定行渲完整真身舞台的真身。
  repo.workflows['wf_night'] = WorkflowEntity(
    id: 'wf_night',
    name: 'nightly_rollup',
    activeVersionId: 'wv_2',
    activeVersion: WorkflowVersion(
      id: 'wv_2',
      workflowId: 'wf_night',
      version: 2,
      graphParsed: const Graph(
        nodes: [
          Node(id: 'trg', kind: NodeKind.trigger, ref: 'cron_nightly'),
          Node(id: 'pull', kind: NodeKind.action, ref: 'fn_sync'),
          Node(id: 'gate', kind: NodeKind.control, ref: 'amount_gate'),
          Node(id: 'emit', kind: NodeKind.action, ref: 'post_summary'),
        ],
        edges: [
          Edge(id: 'e1', from: 'trg', to: 'pull'),
          Edge(id: 'e2', from: 'pull', to: 'gate'),
          Edge(id: 'e3', from: 'gate', to: 'emit', fromPort: 'ok'),
        ],
      ),
      createdAt: ago(const Duration(days: 3)),
      updatedAt: ago(const Duration(days: 1)),
    ),
    createdAt: ago(const Duration(days: 20)),
    updatedAt: ago(const Duration(days: 1)),
  );
  repo.documents['doc_runbook'] = DocumentNode(
    id: 'doc_runbook',
    name: '值班手册',
    content:
        '# 值班手册\n\n## 告警响应\n\n1. 先看 dashboard 的 error rate\n2. 确认影响范围与租户\n3. 能自处理则处理,否则升级\n\n## 常见故障\n\n- 同步超时 → 检查 `sync_inventory` 的重试配置\n- 库存漂移 → 手动跑一次 `nightly_rollup`\n',
    path: '/runbook',
    sizeBytes: 268,
    createdAt: ago(const Duration(days: 30)),
    updatedAt: ago(const Duration(days: 3)),
  );
  repo.skills['commit-helper'] = Skill(
    name: 'commit-helper',
    source: 'ai',
    context: 'inline',
    body:
        '# Commit Helper\n\n为暂存的改动写一条 Conventional Commit:\n\n- 先 `git diff --staged` 看改了什么\n- 类型:feat / fix / refactor / docs / chore\n- 首行 ≤ 72 字,祈使句;正文说清 why 而非 what\n',
    frontmatter: const Frontmatter(
      allowedTools: ['bash', 'read'],
      context: 'inline',
      arguments: ['scope'],
    ),
    updatedAt: ago(const Duration(days: 5)),
  );
  repo.mcpServers['github'] = McpServerStatus(
    id: 'mcp_github',
    name: 'github',
    status: 'ready',
    connectedAt: ago(const Duration(hours: 3)),
    tools: const [
      McpToolDef(name: 'create_issue'),
      McpToolDef(name: 'list_pull_requests'),
      McpToolDef(name: 'get_file_contents'),
      McpToolDef(name: 'search_code'),
    ],
  );
  // D-008/010 truth snapshots the wf_night graph already routes on (amount_gate control + cron_nightly
  // trigger) — so tapping either Cast row opens its real stage. D-006/007/009 add the still-missing agent /
  // approval / handler stages. R-16: the trigger stage trusts only this GET snapshot, never a frame.
  // wf_night 图已引用的控制/触发真身 + 补齐 agent/approval/handler 三舞台;触发只信此 GET。
  repo.controls['amount_gate'] = ControlLogic(
    id: 'amount_gate',
    name: 'amount_gate',
    description: '按金额分流退款审批',
    activeVersionId: 'clv_1',
    activeVersion: ControlVersion(
      id: 'clv_1',
      controlId: 'amount_gate',
      version: 1,
      inputs: const [
        Field(name: 'amount', type: 'number', description: '退款金额'),
      ],
      branches: const [
        Branch(port: 'ok', when: 'input.amount < 1000'),
        Branch(port: 'review', when: 'true'),
      ],
      createdAt: ago(const Duration(days: 3)),
      updatedAt: ago(const Duration(days: 1)),
    ),
    createdAt: ago(const Duration(days: 12)),
    updatedAt: ago(const Duration(days: 1)),
  );
  repo.triggers['cron_nightly'] = TriggerEntity(
    id: 'cron_nightly',
    name: 'cron_nightly',
    description: '每晚 02:00 触发夜间汇总',
    kind: TriggerSource.cron,
    config: const {'expression': '0 2 * * *'},
    outputs: const [Field(name: 'firedAt', type: 'string')],
    refCount: 1,
    listening: true,
    lastFiredAt: ago(const Duration(hours: 8)),
    nextFireAt: ago(const Duration(hours: -16)),
    createdAt: ago(const Duration(days: 20)),
    updatedAt: ago(const Duration(days: 1)),
  );
  repo.agents['ag_reconcile'] = AgentEntity(
    id: 'ag_reconcile',
    name: 'reconcile-bot',
    description: '对账异常研判 agent',
    activeVersionId: 'av_2',
    activeVersion: AgentVersion(
      id: 'av_2',
      agentId: 'ag_reconcile',
      version: 2,
      prompt: 'You reconcile inventory drift. Cite the ledger rows you used.',
      skill: 'deep-research',
      tools: const [ToolRef(ref: 'fn_sync', name: 'sync_inventory')],
      inputs: const [Field(name: 'date', type: 'string')],
      outputs: const [Field(name: 'report', type: 'string')],
      createdAt: ago(const Duration(days: 4)),
      updatedAt: ago(const Duration(days: 1)),
    ),
    createdAt: ago(const Duration(days: 14)),
    updatedAt: ago(const Duration(days: 1)),
  );
  repo.approvals['apf_refund'] = ApprovalForm(
    id: 'apf_refund',
    name: 'refund-approval',
    description: '大额退款人工签核',
    activeVersionId: 'apv_1',
    activeVersion: ApprovalVersion(
      id: 'apv_1',
      approvalId: 'apf_refund',
      version: 1,
      inputs: const [
        Field(name: 'amount', type: 'number'),
        Field(name: 'reason', type: 'string'),
      ],
      template: '退款 **{{ input.amount }}** 元?\n\n事由:{{ input.reason }}',
      allowReason: true,
      timeout: '12h',
      timeoutBehavior: 'reject',
      createdAt: ago(const Duration(days: 6)),
      updatedAt: ago(const Duration(days: 1)),
    ),
    createdAt: ago(const Duration(days: 16)),
    updatedAt: ago(const Duration(days: 1)),
  );
  repo.handlers['hd_ledger'] = HandlerEntity(
    id: 'hd_ledger',
    name: 'ledger',
    description: '账本读写 handler',
    activeVersionId: 'hv_1',
    runtimeState: 'running',
    configState: 'ready',
    activeVersion: HandlerVersion(
      id: 'hv_1',
      handlerId: 'hd_ledger',
      version: 1,
      imports: 'import psycopg',
      initBody: 'self.conn = psycopg.connect(args["dsn"])',
      shutdownBody: 'self.conn.close()',
      methods: const [
        MethodSpec(
          name: 'append',
          inputs: [Field(name: 'row', type: 'object')],
          outputs: [Field(name: 'id', type: 'string')],
          body: 'return self.conn.execute(...)',
        ),
      ],
      initArgsSchema: const [
        InitArgSpec(
          name: 'dsn',
          type: 'string',
          required: true,
          sensitive: true,
        ),
      ],
      envStatus: 'ready',
      createdAt: ago(const Duration(days: 8)),
      updatedAt: ago(const Duration(days: 1)),
    ),
    createdAt: ago(const Duration(days: 18)),
    updatedAt: ago(const Duration(days: 1)),
  );

  // The pinned demo's quiet ledger — what this conversation has touched (the Cast's idle body).
  // 置顶 demo 的静场台账——演员表的安静台账。
  repo.touchpoints['cv_sync'] = [
    tp(
      'tp_d1',
      'function',
      'fn_sync',
      'sync_inventory',
      TouchpointVerb.edited,
      const Duration(minutes: 12),
      count: 2,
    ),
    tp(
      'tp_d2',
      'function',
      'fn_sync',
      'sync_inventory',
      TouchpointVerb.executed,
      const Duration(minutes: 11),
    ),
    tp(
      'tp_d3',
      'workflow',
      'wf_night',
      'nightly_rollup',
      TouchpointVerb.viewed,
      const Duration(hours: 2),
    ),
    tp(
      'tp_d4',
      'document',
      'doc_runbook',
      '值班手册',
      TouchpointVerb.mentioned,
      const Duration(days: 1),
      actor: TouchpointActor.user,
    ),
    // The exhibit pedestal's still life — tapping this Cast row lights the 展品座. 展品座静物。
    tp(
      'tp_d5',
      'attachment',
      'att_demo_shelf',
      'shelf-audit.csv',
      TouchpointVerb.attached,
      const Duration(minutes: 14),
      actor: TouchpointActor.user,
    ),
    tp(
      'tp_d6',
      'skill',
      'commit-helper',
      'commit-helper',
      TouchpointVerb.edited,
      const Duration(minutes: 9),
    ),
    tp(
      'tp_d7',
      'mcp',
      'github',
      'github',
      TouchpointVerb.mentioned,
      const Duration(minutes: 7),
    ),
    // D-006~010 — one Cast row per remaining kind so every sidestage stage has a way to open (the
    // snapshots above are their old-truth GETs). D-013 — a tombstone row (verb=deleted bans the GET;
    // the stage shows the tombstone, never a 404). 每 kind 一行开幕 + 墓碑行(deleted 封 GET)。
    tp(
      'tp_d8',
      'control',
      'amount_gate',
      'amount_gate',
      TouchpointVerb.viewed,
      const Duration(minutes: 8),
    ),
    tp(
      'tp_d9',
      'trigger',
      'cron_nightly',
      'cron_nightly',
      TouchpointVerb.viewed,
      const Duration(hours: 8),
    ),
    tp(
      'tp_d10',
      'agent',
      'ag_reconcile',
      'reconcile-bot',
      TouchpointVerb.mentioned,
      const Duration(minutes: 6),
    ),
    tp(
      'tp_d11',
      'approval',
      'apf_refund',
      'refund-approval',
      TouchpointVerb.viewed,
      const Duration(minutes: 5),
    ),
    tp(
      'tp_d12',
      'handler',
      'hd_ledger',
      'ledger',
      TouchpointVerb.executed,
      const Duration(minutes: 4),
    ),
    tp(
      'tp_d13',
      'function',
      'fn_legacy_sync',
      'legacy_sync',
      TouchpointVerb.deleted,
      const Duration(minutes: 2),
    ),
  ];
  // D-011 — the marathon session (cv_p20) touched 54 things, so its Cast ledger paginates past the 50-row
  // page (loadMore + the skeleton foot). The first 10 rows reuse the seeded snapshots (open to a real
  // stage); the rest are synthetic `viewed` rows that degrade honestly to the summary fallback when opened
  // (StageBodyFromTruth's error branch, never a crash). 马拉松会话 54 触点使台账翻页;前 10 真、余合成降级。
  const seededRefs = <({String kind, String id, String name})>[
    (kind: 'function', id: 'fn_sync', name: 'sync_inventory'),
    (kind: 'workflow', id: 'wf_night', name: 'nightly_rollup'),
    (kind: 'control', id: 'amount_gate', name: 'amount_gate'),
    (kind: 'trigger', id: 'cron_nightly', name: 'cron_nightly'),
    (kind: 'agent', id: 'ag_reconcile', name: 'reconcile-bot'),
    (kind: 'approval', id: 'apf_refund', name: 'refund-approval'),
    (kind: 'handler', id: 'hd_ledger', name: 'ledger'),
    (kind: 'document', id: 'doc_runbook', name: '值班手册'),
    (kind: 'skill', id: 'commit-helper', name: 'commit-helper'),
    (kind: 'mcp', id: 'github', name: 'github'),
  ];
  const synthKinds = ['function', 'workflow', 'handler', 'agent', 'document'];
  repo.touchpoints['cv_p20'] = [
    for (var i = 0; i < seededRefs.length; i++)
      Touchpoint(
        id: 'tp_p20_s$i',
        conversationId: 'cv_p20',
        itemKind: seededRefs[i].kind,
        itemId: seededRefs[i].id,
        itemName: seededRefs[i].name,
        verb: TouchpointVerb.viewed,
        lastActor: TouchpointActor.assistant,
        count: 1,
        firstAt: ago(Duration(hours: 26, minutes: i)),
        lastAt: ago(Duration(hours: 25, minutes: i)),
      ),
    for (var i = 0; i < 44; i++)
      Touchpoint(
        id: 'tp_p20_x$i',
        conversationId: 'cv_p20',
        itemKind: synthKinds[i % synthKinds.length],
        itemId: 'ent_marathon_$i',
        itemName: 'entity_$i',
        verb: TouchpointVerb.viewed,
        lastActor: TouchpointActor.assistant,
        count: 1,
        firstAt: ago(Duration(hours: 27, minutes: i)),
        lastAt: ago(Duration(hours: 26, minutes: i)),
      ),
  ];
  // D-012 — cv_flaky's Cast rows, landed AFTER the one-shot first-fetch failure is retried. 重试后的台账。
  repo.touchpoints['cv_flaky'] = [
    Touchpoint(
      id: 'tp_fk1',
      conversationId: 'cv_flaky',
      itemKind: 'function',
      itemId: 'fn_sync',
      itemName: 'sync_inventory',
      verb: TouchpointVerb.viewed,
      lastActor: TouchpointActor.assistant,
      count: 1,
      firstAt: ago(const Duration(hours: 4, minutes: 3)),
      lastAt: ago(const Duration(hours: 4, minutes: 2)),
    ),
    Touchpoint(
      id: 'tp_fk2',
      conversationId: 'cv_flaky',
      itemKind: 'workflow',
      itemId: 'wf_night',
      itemName: 'nightly_rollup',
      verb: TouchpointVerb.mentioned,
      lastActor: TouchpointActor.user,
      count: 1,
      firstAt: ago(const Duration(hours: 4, minutes: 3)),
      lastAt: ago(const Duration(hours: 4, minutes: 2)),
    ),
  ];
  repo.interactions['cv_gate'] = const [
    Interaction(
      toolCallId: 'b_hg_gate',
      kind: InteractionKind.danger,
      tool: 'delete_function',
      resolved: false,
      summary: '删除废弃函数 legacy_sync(不可逆)',
      args: {'functionId': 'fn_legacy_sync'},
    ),
  ];
  // D-002 — the LIVE ask_user gate's pending interaction: kind=ask carries the prompt + option pills the
  // gate renders (plus the free-text field for an off-menu answer). 活问闸:kind=ask 携 prompt+选项。
  repo.interactions['cv_ask'] = const [
    Interaction(
      toolCallId: 'b_ak_gate',
      kind: InteractionKind.ask,
      tool: 'ask_user',
      resolved: false,
      message: '这批发票要发到哪个环境?',
      options: ['生产环境', '预发环境', '测试环境'],
    ),
  ];
  repo.attachmentMetas['att_demo_shelf'] = const AttachmentMeta(
    id: 'att_demo_shelf',
    filename: 'shelf-audit.csv',
    mimeType: 'text/csv',
    sizeBytes: 48213,
    kind: 'text',
    sha256: '9f86d081884c7d65a0f0b3c2',
  );
  return repo;
}
