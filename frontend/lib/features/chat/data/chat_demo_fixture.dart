import 'dart:async';

import 'package:characters/characters.dart';

import '../../../core/contract/attachment.dart';
import '../../../core/contract/conversation.dart';
import '../../../core/contract/entities/function.dart';
import '../../../core/contract/messages/chat_message.dart';
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
  static const _fnCodeWire = 'import time\\n\\n'
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
  static const _docBodyWire = '# 修复方案\\n\\n'
      '## 根因\\n\\n- issue_date 未做时区归一\\n- 跨年边界 Q4 与次年 Q1 混桶\\n\\n'
      '## 修法\\n\\n1. 入库前统一 astimezone 到本位时区\\n2. 聚合键 floor 到季度首日\\n'
      '3. 对历史数据跑一次回填\\n\\n'
      '## 验证\\n\\n- 抽 2025-12-31 23:50 的三笔票据核对归桶\\n- 对账报表按季度重跑一遍\\n';

  static const _replyScript = '收到,我看了一下:\n\n'
      '- **根因**:`issue_date` 没做时区归一,跨年边界上 Q4 和次年 Q1 混桶\n'
      '- **修法**:先归一到本位时区,再按季度聚合\n\n'
      '```py\ndate.astimezone(tz).quarter\n```\n\n'
      '要不要我顺手把这个写成一个 function 挂进 workflow?';

  @override
  Future<String> sendMessage(
    String conversationId, {
    required String content,
    List<String> attachmentIds = const [],
    List<({String type, String id})> mentions = const [],
  }) async {
    final assistantId = await super.sendMessage(conversationId,
        content: content, attachmentIds: attachmentIds, mentions: mentions);
    // Mirror the backend's dot truth: the row turns generating and the rail hears a turn pulse.
    // 镜像后端点真相:行转 generating,rail 收到回合脉冲。
    final conv = conversationOrNull(conversationId);
    if (conv != null) upsert(conv.copyWith(isGenerating: true, hasUnread: false));
    emitTurnSignal(conversationId, TurnSignalKind.turnOpen);
    _playReply(conversationId, assistantId, userText: content);
    return assistantId;
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
          result: StreamNode(type: 'message', content: {
            'role': 'assistant', 'status': 'cancelled', 'stopReason': 'cancelled',
          }),
        ),
      ),
    );
    final conv = conversationOrNull(conversationId);
    if (conv != null) upsert(conv.copyWith(isGenerating: false)); // cancelled ≠ unread 取消不算未读
    emitTurnSignal(conversationId, TurnSignalKind.turnClose);
  }

  // The scripted turn: echo → assistant open → thinking (deltas, close) → text (deltas, close) → stop.
  // 脚本回合:回声→assistant open→thinking(delta,close)→text(delta,close)→终帧。
  void _playReply(String conversationId, String assistantId, {required String userText}) {
    final scope = StreamScope(kind: 'conversation', id: conversationId);
    final userId = 'msg_demo_u${_demoSeq++}';
    final thinkId = 'blk_demo_t${_demoSeq++}';
    final textId = 'blk_demo_x${_demoSeq++}';
    var at = 250; // ms timeline 时间线
    void frame(int seq, String id, StreamFrame f, {int step = 0}) {
      at += step;
      _timers.add(Timer(Duration(milliseconds: at),
          () => emitFrame(conversationId, StreamEnvelope(seq: seq, scope: scope, id: id, frame: f))));
    }

    // Durable user echo (inline content — mirrors the backend shape). 用户回声(内联文本,镜像后端)。
    frame(1, userId, const FrameOpen(node: StreamNode(type: 'message', content: {'role': 'user'})));
    frame(2, userId,
        FrameClose(status: 'completed',
            result: StreamNode(type: 'message', content: {'role': 'user', 'content': userText})),
        step: 60);
    frame(3, assistantId,
        const FrameOpen(node: StreamNode(type: 'message', content: {'role': 'assistant'})),
        step: 200);

    // thinking: streams in small clumps. thinking:小簇流。
    frame(4, thinkId,
        FrameOpen(parentId: assistantId, node: const StreamNode(type: 'reasoning', content: {'content': ''})),
        step: 150);
    for (var i = 0; i < _thinkingScript.length; i += 6) {
      frame(0, thinkId,
          FrameDelta(chunk: _thinkingScript.substring(i, (i + 6).clamp(0, _thinkingScript.length))),
          step: 70);
    }
    frame(5, thinkId,
        const FrameClose(status: 'completed',
            result: StreamNode(type: 'reasoning', content: {'content': _thinkingScript})),
        step: 120);

    // ACT ONE — edit_function: the id lands first (R-5 fetches the old truth → the stratum), then
    // ops stream (set_meta chip, set_code line by line), the close carries the snapshot, the result
    // lands, the touchpoint writes the ledger. 第一幕 edit_function:首键即 id(R-5 取旧真相→地层),
    // ops 逐个流(set_meta 芯片/set_code 逐行),关帧快照,回执落地,触点落账。
    final fnToolId = 'blk_demo_f${_demoSeq++}';
    final fnResultId = 'blk_demo_fr${_demoSeq++}';
    frame(13, fnToolId,
        FrameOpen(parentId: assistantId,
            node: const StreamNode(type: 'tool_call', content: {'name': 'edit_function', 'danger': 'safe'})),
        step: 250);
    frame(0, fnToolId,
        const FrameDelta(chunk: '{"functionId":"fn_sync","summary":"给 sync_inventory 加指数退避重试",'),
        step: 150);
    frame(0, fnToolId,
        const FrameDelta(chunk: '"ops":[{"op":"set_meta","description":"sync with retry"},'),
        step: 220);
    frame(0, fnToolId, const FrameDelta(chunk: '{"op":"set_code","code":"'), step: 160);
    for (var i = 0; i < _fnCodeWire.length; i += 14) {
      frame(0, fnToolId,
          FrameDelta(chunk: _fnCodeWire.substring(i, (i + 14).clamp(0, _fnCodeWire.length))),
          step: 60);
    }
    frame(0, fnToolId, const FrameDelta(chunk: '"}]}'), step: 60);
    const fnArgs =
        '{"functionId":"fn_sync","summary":"给 sync_inventory 加指数退避重试","ops":[{"op":"set_meta","description":"sync with retry"},{"op":"set_code","code":"$_fnCodeWire"}]}';
    frame(14, fnToolId,
        const FrameClose(status: 'completed',
            result: StreamNode(type: 'tool_call', content: {
              'name': 'edit_function', 'arguments': fnArgs,
              'entityName': 'sync_inventory', 'summary': '给 sync_inventory 加指数退避重试',
            })),
        step: 320);
    frame(15, fnResultId,
        FrameOpen(parentId: fnToolId,
            node: const StreamNode(type: 'tool_result',
                content: {'content': '{"id":"fn_sync","version":4,"envStatus":"ready"}'})),
        step: 80);
    frame(16, fnResultId,
        const FrameClose(status: 'completed',
            result: StreamNode(type: 'tool_result',
                content: {'content': '{"id":"fn_sync","version":4,"envStatus":"ready"}'})),
        step: 40);
    _timers.add(Timer(Duration(milliseconds: at + 40), () {
      touch(Touchpoint(
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
      ), seq: 820 + _demoSeq);
    }));

    // ACT TWO — create_document (the show switches stages: fn settles, the doc takes over). 第二幕。
    final toolId = 'blk_demo_c${_demoSeq++}';
    final resultId = 'blk_demo_r${_demoSeq++}';
    const argsHead = '{"name":"$_docName","content":"';
    frame(9, toolId,
        FrameOpen(parentId: assistantId,
            node: const StreamNode(type: 'tool_call', content: {'name': 'create_document', 'danger': 'safe'})),
        step: 250);
    frame(0, toolId, const FrameDelta(chunk: argsHead), step: 120);
    for (var i = 0; i < _docBodyWire.length; i += 12) {
      frame(0, toolId,
          FrameDelta(chunk: _docBodyWire.substring(i, (i + 12).clamp(0, _docBodyWire.length))),
          step: 55);
    }
    frame(0, toolId, const FrameDelta(chunk: '"}'), step: 55);
    const fullArgs = '$argsHead$_docBodyWire"}';
    frame(10, toolId,
        const FrameClose(status: 'completed',
            result: StreamNode(type: 'tool_call', content: {
              'name': 'create_document', 'arguments': fullArgs,
              'entityName': _docName, 'summary': '把修复方案落成文档',
            })),
        step: 300);
    frame(11, resultId,
        FrameOpen(parentId: toolId,
            node: const StreamNode(type: 'tool_result', content: {'content': 'Created document "$_docName" (id=doc_demo_fix, path=/$_docName)'})),
        step: 80);
    frame(12, resultId,
        const FrameClose(status: 'completed',
            result: StreamNode(type: 'tool_result', content: {'content': 'Created document "$_docName" (id=doc_demo_fix, path=/$_docName)'})),
        step: 40);
    _timers.add(Timer(Duration(milliseconds: at + 40), () {
      touch(Touchpoint(
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
      ), seq: 800 + _demoSeq);
    }));

    // ACT 2.5 — the ensemble: two Subagents run in parallel with a live todo board (分镜 c).
    // 幕 2.5:双分身并行+活任务板(分镜 c)。
    final sa1 = 'blk_demo_sa${_demoSeq++}';
    final sa2 = 'blk_demo_sb${_demoSeq++}';
    void todoFrame(List<TodoEntry> items, {int seq = 30}) {
      _timers.add(Timer(Duration(milliseconds: at), () {
        emitTodos(ConversationTodos(conversationId: conversationId, todos: items), seq: seq + _demoSeq);
      }));
    }

    at += 250;
    todoFrame(const [
      TodoEntry(content: '审计最近失败的执行', activeForm: '正在审计失败执行…', status: 'in_progress'),
      TodoEntry(content: '核对告警渠道配置', status: 'pending'),
    ]);
    frame(21, sa1,
        FrameOpen(parentId: assistantId,
            node: const StreamNode(type: 'tool_call', content: {'name': 'Subagent', 'danger': 'safe'})),
        step: 200);
    frame(0, sa1, const FrameDelta(chunk: '{"description":"审计最近失败的执行","prompt":"拉最近十条失败记录并归因"}'), step: 120);
    frame(22, '${sa1}_m', FrameOpen(parentId: sa1, node: const StreamNode(type: 'message', content: {'role': 'assistant'})), step: 150);
    frame(23, '${sa1}_r', FrameOpen(parentId: '${sa1}_m', node: const StreamNode(type: 'reasoning', content: {'content': ''})), step: 100);
    for (final chunk in const ['先拉最近', '十条失败记录,', '按错误码分桶,', '再对时间轴找共因']) {
      frame(0, '${sa1}_r', FrameDelta(chunk: chunk), step: 320);
    }
    frame(24, sa2,
        FrameOpen(parentId: assistantId,
            node: const StreamNode(type: 'tool_call', content: {'name': 'Subagent', 'danger': 'safe'})),
        step: 400);
    frame(0, sa2, const FrameDelta(chunk: '{"description":"核对告警渠道配置","prompt":"检查通知渠道与静默窗口"}'), step: 120);
    frame(25, '${sa2}_m', FrameOpen(parentId: sa2, node: const StreamNode(type: 'message', content: {'role': 'assistant'})), step: 150);
    frame(26, '${sa2}_r', FrameOpen(parentId: '${sa2}_m', node: const StreamNode(type: 'reasoning', content: {'content': ''})), step: 100);
    for (final chunk in const ['列出全部渠道,', '标出无静默窗口的三条']) {
      frame(0, '${sa2}_r', FrameDelta(chunk: chunk), step: 340);
    }
    frame(27, '${sa1}_r', const FrameClose(status: 'completed', result: StreamNode(type: 'reasoning', content: {'content': '先拉最近十条失败记录,按错误码分桶,再对时间轴找共因'})), step: 200);
    frame(28, sa1,
        const FrameClose(status: 'completed',
            result: StreamNode(type: 'tool_call', content: {
              'name': 'Subagent', 'status': 'completed', 'stopReason': 'end_turn',
              'tokens': {'in': 1840, 'out': 620},
              'arguments': '{"description":"审计最近失败的执行"}',
            })),
        step: 300);
    at += 150;
    todoFrame(const [
      TodoEntry(content: '审计最近失败的执行', status: 'completed'),
      TodoEntry(content: '核对告警渠道配置', activeForm: '正在核对告警渠道…', status: 'in_progress'),
    ]);
    frame(29, '${sa2}_r', const FrameClose(status: 'completed', result: StreamNode(type: 'reasoning', content: {'content': '列出全部渠道,标出无静默窗口的三条'})), step: 500);
    frame(30, sa2,
        const FrameClose(status: 'completed',
            result: StreamNode(type: 'tool_call', content: {
              'name': 'Subagent', 'status': 'completed', 'stopReason': 'end_turn',
              'tokens': {'in': 1210, 'out': 340},
              'arguments': '{"description":"核对告警渠道配置"}',
            })),
        step: 260);
    at += 120;
    todoFrame(const [
      TodoEntry(content: '审计最近失败的执行', status: 'completed'),
      TodoEntry(content: '核对告警渠道配置', status: 'completed'),
    ]);

    // ACT 2.8 — write_memory: the memo slip (a long-tail stage spot-check on the real machine).
    // 幕 2.8:记忆笺(长尾舞台真机抽查)。
    final memId = 'blk_demo_mm${_demoSeq++}';
    frame(31, memId,
        FrameOpen(parentId: assistantId,
            node: const StreamNode(type: 'tool_call', content: {'name': 'write_memory', 'danger': 'safe'})),
        step: 250);
    frame(0, memId, const FrameDelta(chunk: '{"name":"retry-policy","content":"重试统一走'), step: 200);
    frame(0, memId, const FrameDelta(chunk: '指数退避(1s→2s→4s,最多 3 次),'), step: 320);
    frame(0, memId, const FrameDelta(chunk: '超限抛 SyncError 交上游降级。"}'), step: 320);
    frame(32, memId,
        const FrameClose(status: 'completed',
            result: StreamNode(type: 'tool_call', content: {
              'name': 'write_memory',
              'arguments': '{"name":"retry-policy","content":"重试统一走指数退避(1s→2s→4s,最多 3 次),超限抛 SyncError 交上游降级。"}',
              'entityName': 'retry-policy',
            })),
        step: 300);
    _timers.add(Timer(Duration(milliseconds: at + 40), () {
      touch(Touchpoint(
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
      ), seq: 860 + _demoSeq);
    }));

    // ACT 2.9 — trigger_workflow: the LIVE RUN SCROLL (W7): the 202 receipt holds the stage,
    // node ticks roll in quiet rows (the gate's taken port visible), the durable terminal settles.
    // 幕 2.9:活运行卷——202 回执驻台,节点 tick 逐行静落(门的选中 port 可见),durable 终态落定。
    final twId = 'blk_demo_tw${_demoSeq++}';
    final twRes = 'blk_demo_twr${_demoSeq++}';
    frame(33, twId,
        FrameOpen(parentId: assistantId,
            node: const StreamNode(type: 'tool_call', content: {'name': 'trigger_workflow', 'danger': 'safe'})),
        step: 300);
    frame(0, twId, const FrameDelta(chunk: '{"workflowId":"wf_night","payload":{"date":"2026-07-08"}}'), step: 250);
    frame(34, twRes,
        FrameOpen(parentId: twId, node: const StreamNode(type: 'tool_result', content: {
          'content': '{"flowrunId":"fr_demo_1","status":"running"}',
        })),
        step: 200);
    frame(35, twRes,
        const FrameClose(status: 'completed', result: StreamNode(type: 'tool_result', content: {
          'content': '{"flowrunId":"fr_demo_1","status":"running"}',
        })),
        step: 100);
    frame(36, twId,
        const FrameClose(status: 'completed', result: StreamNode(type: 'tool_call', content: {
          'name': 'trigger_workflow',
          'arguments': '{"workflowId":"wf_night","payload":{"date":"2026-07-08"}}',
          'entityName': 'nightly_rollup',
        })),
        step: 150);
    void runTick(int atMs, String nodeId, String status, {String port = ''}) {
      _timers.add(Timer(Duration(milliseconds: atMs), () {
        emitWorkflowFrame('wf_night', StreamEnvelope(
          seq: 0,
          scope: const StreamScope(kind: 'workflow', id: 'wf_night'),
          id: 'demo_tick_${_demoSeq++}',
          frame: FrameSignal(node: StreamNode(type: 'run', content: {
            'flowrunId': 'fr_demo_1', 'nodeId': nodeId, 'iteration': 0, 'status': status,
            if (port.isNotEmpty) 'port': port,
          })),
        ));
      }));
    }

    runTick(at + 700, 'pull_invoices', 'completed');
    runTick(at + 1500, 'fix_timezone', 'completed');
    runTick(at + 2300, 'quality_gate', 'completed', port: 'pass');
    runTick(at + 3100, 'rollup', 'completed');
    _timers.add(Timer(Duration(milliseconds: at + 3900), () {
      emitWorkflowFrame('wf_night', StreamEnvelope(
        seq: 900 + _demoSeq,
        scope: const StreamScope(kind: 'workflow', id: 'wf_night'),
        id: 'demo_term_${_demoSeq++}',
        frame: const FrameSignal(node: StreamNode(type: 'run_terminal', content: {
          'flowrunId': 'fr_demo_1', 'status': 'completed',
        })),
      ));
    }));
    at += 4200;

    // ACT THREE — create_workflow: the graph GROWS on the canvas op by op (分镜 b). 第三幕:图逐 op 生长。
    final wfToolId = 'blk_demo_w${_demoSeq++}';
    final wfResultId = 'blk_demo_wr${_demoSeq++}';
    frame(17, wfToolId,
        FrameOpen(parentId: assistantId,
            node: const StreamNode(type: 'tool_call', content: {'name': 'create_workflow', 'danger': 'safe'})),
        step: 300);
    frame(0, wfToolId,
        const FrameDelta(chunk: '{"name":"quarterly_rollup","summary":"跨年修桶的季度汇总流程","ops":['),
        step: 150);
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
    final wfArgs = '{"name":"quarterly_rollup","summary":"跨年修桶的季度汇总流程","ops":[${wfOps.join()}]}';
    frame(18, wfToolId,
        FrameClose(status: 'completed',
            result: StreamNode(type: 'tool_call', content: {
              'name': 'create_workflow', 'arguments': wfArgs,
              'entityName': 'quarterly_rollup', 'summary': '跨年修桶的季度汇总流程',
            })),
        step: 320);
    frame(19, wfResultId,
        FrameOpen(parentId: wfToolId,
            node: const StreamNode(type: 'tool_result',
                content: {'content': '{"id":"wf_demo_roll","version":1,"nodes":4,"edges":3}'})),
        step: 80);
    frame(20, wfResultId,
        const FrameClose(status: 'completed',
            result: StreamNode(type: 'tool_result',
                content: {'content': '{"id":"wf_demo_roll","version":1,"nodes":4,"edges":3}'})),
        step: 40);
    _timers.add(Timer(Duration(milliseconds: at + 40), () {
      touch(Touchpoint(
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
      ), seq: 840 + _demoSeq);
    }));

    // text: streams like tokens. text:token 式流。
    frame(6, textId,
        FrameOpen(parentId: assistantId, node: const StreamNode(type: 'text', content: {'content': ''})),
        step: 150);
    for (var i = 0; i < _replyScript.length; i += 5) {
      frame(0, textId,
          FrameDelta(chunk: _replyScript.substring(i, (i + 5).clamp(0, _replyScript.length))),
          step: 24);
    }
    frame(7, textId,
        const FrameClose(status: 'completed',
            result: StreamNode(type: 'text', content: {'content': _replyScript})),
        step: 100);
    frame(8, assistantId,
        const FrameClose(status: 'completed',
            result: StreamNode(type: 'message', content: {
              'role': 'assistant', 'status': 'completed', 'stopReason': 'end_turn',
              'inputTokens': 220, 'outputTokens': 180,
            })),
        step: 80);

    // Settle the persisted rows so a reload shows the finished turn; an un-titled thread then
    // AUTO-TITLES (mirrors the backend's post-first-turn hook) — the rail row + head play the
    // one-shot typewriter. 定格持久行;未命名线程随后自动命名(镜像后端首回合钩子)——rail 行+头播打字机。
    _timers.add(Timer(Duration(milliseconds: at + 40), () {
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
            ChatBlock(id: thinkId, type: 'reasoning', content: _thinkingScript, status: 'completed'),
            ChatBlock(id: fnToolId, type: 'tool_call', content: '', status: 'completed', attrs: {
              'tool': 'edit_function', 'arguments': fnArgs,
              'entityName': 'sync_inventory', 'summary': '给 sync_inventory 加指数退避重试',
            }),
            ChatBlock(id: fnResultId, type: 'tool_result',
                content: '{"id":"fn_sync","version":4,"envStatus":"ready"}',
                status: 'completed', attrs: {'parentBlockId': fnToolId}),
            ChatBlock(id: wfToolId, type: 'tool_call', content: '', status: 'completed', attrs: {
              'tool': 'create_workflow', 'arguments': wfArgs,
              'entityName': 'quarterly_rollup', 'summary': '跨年修桶的季度汇总流程',
            }),
            ChatBlock(id: wfResultId, type: 'tool_result',
                content: '{"id":"wf_demo_roll","version":1,"nodes":4,"edges":3}',
                status: 'completed', attrs: {'parentBlockId': wfToolId}),
            ChatBlock(id: toolId, type: 'tool_call', content: '', status: 'completed', attrs: {
              'tool': 'create_document', 'arguments': fullArgs,
              'entityName': _docName, 'summary': '把修复方案落成文档',
            }),
            ChatBlock(id: resultId, type: 'tool_result', content: 'Created document "$_docName" (id=doc_demo_fix, path=/$_docName)',
                status: 'completed', attrs: {'parentBlockId': toolId}),
            ChatBlock(id: textId, type: 'text', content: _replyScript, status: 'completed'),
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
          emitSignal(ConversationSignal(
              id: conversationId, action: ConversationAction.updated, durable: true));
        }
        upsert(next);
      }
      emitTurnSignal(conversationId, TurnSignalKind.turnClose);
    }));
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

  ChatMessage msg(String id, String conv, String role, Duration since,
          {String status = 'completed',
          String stopReason = '',
          Map<String, dynamic>? attrs,
          List<ChatBlock> blocks = const []}) =>
      ChatMessage(
        id: id,
        conversationId: conv,
        role: role,
        status: status,
        stopReason: stopReason.isEmpty && role == 'assistant' && status == 'completed'
            ? 'end_turn'
            : stopReason,
        attrs: attrs,
        blocks: blocks,
        createdAt: ago(since),
      );

  ChatBlock blk(String id, String type, String content, {Map<String, dynamic>? attrs}) =>
      ChatBlock(id: id, type: type, content: content, status: 'completed', attrs: attrs);

  // The tool-card showcase conversations (B1–B7): each exercises a family group so `make demo` displays
  // every tool card live. Folded into the rail (newest-first) + the messages map. 工具卡展台折入 demo。
  final shows = showcaseConversations();

  Touchpoint tp(String id, String kind, String itemId, String name, TouchpointVerb verb,
          Duration since, {int count = 1, TouchpointActor actor = TouchpointActor.assistant}) =>
      Touchpoint(
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

  final repo = DemoChatRepository(
    conversations: [
      // Only conversations that DO something when opened (real transcripts) + the archived example — the
      // empty rail-filler threads (daily / diag / keys / notes / research / kickoff, seeded no messages)
      // were pruned so every rail row is useful (#1). Rail states stay covered: pinned (cv_sync) / unread
      // green (cv_weekly) / archived gray (cv_migrate) / generating blue (plays live on send). The pinned
      // demo carries a full transcript (mention + thinking + code + a cancelled turn), not an empty row.
      // 只留打开有内容的对话 + 归档例;空 rail 填充对话已清(#1)。信号仍全覆盖:置顶/未读绿/归档灰/发送时生成蓝。
      conv('cv_sync', 'AI 编辑 · sync_inventory 加重试', const Duration(minutes: 10), pinned: true),
      for (final s in shows) s.conv, // the tool-card showcase — every tool card, live 工具卡展台(每卡)
      conv('cv_weekly', '周报初稿整理', const Duration(hours: 1), unread: true), // unread green + markdown/table
      conv('cv_scroll', '展台 · 长卷与深跳', const Duration(hours: 3)), // W6: 场次条 + ?around= deep jump 深跳长卷
      conv('cv_migrate', '旧版迁移笔记', const Duration(days: 40), archived: true), // the archived (gray) example
    ],
    messages: {
      for (final s in shows) s.conv.id: s.messages,
      // W6 深跳长卷: 64 turns so the head page (30) can't hold it and the TALLER drawer's bottom rows land beyond it — the 场次条 jumps ?around= for real.
      // A folded tool cluster + one dangerous call + an abnormal terminal give the drawer every row kind.
      // 48 回合,头页装不下——场次条真走 ?around=;折叠簇+危险调用+异常终态让抽屉五 kind 齐活。
      'cv_scroll': [
        for (var i = 0; i < 64; i++)
          if (i == 11)
            msg('m_l$i', 'cv_scroll', 'assistant', Duration(hours: 3, minutes: 96 - 2 * i), blocks: [
              blk('b_l${i}a', 'tool_call', '{"query":"库存同步"}', attrs: {'tool': 'search_entities'}),
              blk('b_l${i}b', 'tool_call', '{"functionId":"fn_sync"}', attrs: {'tool': 'get_function'}),
              blk('b_l${i}c', 'text', '查到了,旧版同步函数还挂在两个 workflow 上。'),
            ])
          else if (i == 23)
            msg('m_l$i', 'cv_scroll', 'assistant', Duration(hours: 3, minutes: 96 - 2 * i), blocks: [
              blk('b_l${i}a', 'tool_call', '{"functionId":"fn_legacy"}',
                  attrs: {'tool': 'delete_function', 'danger': 'dangerous', 'entityName': 'legacy_sync'}),
              blk('b_l${i}b', 'text', '旧函数已删,依赖它的两条边也一并清了。'),
            ])
          else if (i == 35)
            msg('m_l$i', 'cv_scroll', 'assistant', Duration(hours: 3, minutes: 96 - 2 * i),
                status: 'error', stopReason: 'max_tokens', blocks: [
              blk('b_l$i', 'text', '这段清单太长,先给你前半——'),
            ])
          else
            msg('m_l$i', 'cv_scroll', i.isEven ? 'user' : 'assistant',
                Duration(hours: 3, minutes: 96 - 2 * i), blocks: [
              blk(
                  'b_l$i',
                  'text',
                  i.isEven
                      ? '第 ${i ~/ 2 + 1} 问:盘点脚本第 ${i + 3} 段还需要改吗?'
                      : '第 ${i ~/ 2 + 1} 答:这一段保持现状即可,理由记在盘点手册。'),
            ]),
      ],
      // Exercises every locked module: an @mention snapshot in the user bubble, thinking, markdown+code,
      // and a cancelled turn's honest banner. 触发每个已锁模块。
      'cv_sync': [
        msg('m_s1', 'cv_sync', 'user', const Duration(minutes: 14), attrs: {
          'mentions': [
            {'type': 'function', 'id': 'fn_sync', 'name': 'sync_inventory', 'content': ''},
          ],
        }, blocks: [
          blk('b_s1', 'text', '帮 @sync_inventory 加上失败重试,指数退避'),
        ]),
        msg('m_s2', 'cv_sync', 'assistant', const Duration(minutes: 13), blocks: [
          blk('b_s2r', 'reasoning',
              '用户要给 sync_inventory 加重试。看下现在的实现:直接调用、无退避。装饰器最干净,超限抛 SyncError 让上游决定降级。'),
          blk('b_s2t', 'text',
              '加好了,要点:\n\n1. **指数退避**:`1s → 2s → 4s`,最多 3 次\n2. 超限抛 `SyncError`,上游 workflow 决定是否降级\n\n```py\n@retry(times=3, backoff=[1, 2, 4])\ndef sync_inventory():\n    ...\n```\n\n已生成新版本 v4 并激活。'),
        ]),
        msg('m_s3', 'cv_sync', 'user', const Duration(minutes: 12), blocks: [
          blk('b_s3', 'text', '再帮我把失败告警也加上'),
        ]),
        msg('m_s4', 'cv_sync', 'assistant', const Duration(minutes: 11),
            status: 'cancelled', stopReason: 'cancelled', blocks: [
          blk('b_s4', 'text', '好的,告警可以挂在第 3 次失败的分支上,先看下现有的通知渠道…'),
        ]),
      ],
      'cv_weekly': [
        msg('m_w1', 'cv_weekly', 'user', const Duration(hours: 2), blocks: [
          blk('b_w1', 'text', '把这周的进展整理成周报初稿'),
        ]),
        msg('m_w2', 'cv_weekly', 'assistant', const Duration(hours: 1), blocks: [
          blk('b_w2', 'text',
              '## 本周进展\n\n- 完成 sync_inventory 重试改造(v4 已激活)\n- flowrun 失败率从 4.2% 降到 0.8%\n\n| 指标 | 上周 | 本周 |\n|:--|--:|--:|\n| 失败率 | 4.2% | 0.8% |\n| 平均时延 | 3.1s | 2.4s |\n\n> 下周重点:告警渠道接入'),
        ]),
      ],
      // The archived (gray) example — a short, done conversation so the archived filter isn't empty. 归档例。
      'cv_migrate': [
        msg('m_mig1', 'cv_migrate', 'user', const Duration(days: 40), blocks: [
          blk('b_mig1', 'text', '把旧版三个 handler 的迁移笔记归档一下'),
        ]),
        msg('m_mig2', 'cv_migrate', 'assistant', const Duration(days: 40), blocks: [
          blk('b_mig2', 'text',
              '已整理:旧版 3 个 handler 全部迁到新契约,迁移要点记在文档《迁移笔记》。这条对话可以归档了。'),
        ]),
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

  // The pinned demo's quiet ledger — what this conversation has touched (the Cast's idle body).
  // 置顶 demo 的静场台账——演员表的安静台账。
  repo.touchpoints['cv_sync'] = [
    tp('tp_d1', 'function', 'fn_sync', 'sync_inventory', TouchpointVerb.edited,
        const Duration(minutes: 12), count: 2),
    tp('tp_d2', 'function', 'fn_sync', 'sync_inventory', TouchpointVerb.executed,
        const Duration(minutes: 11)),
    tp('tp_d3', 'workflow', 'wf_night', 'nightly_rollup', TouchpointVerb.viewed,
        const Duration(hours: 2)),
    tp('tp_d4', 'document', 'doc_runbook', '值班手册', TouchpointVerb.mentioned,
        const Duration(days: 1), actor: TouchpointActor.user),
    // The exhibit pedestal's still life — tapping this Cast row lights the 展品座. 展品座静物。
    tp('tp_d5', 'attachment', 'att_demo_shelf', 'shelf-audit.csv', TouchpointVerb.attached,
        const Duration(minutes: 14), actor: TouchpointActor.user),
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
