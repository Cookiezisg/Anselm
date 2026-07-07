import 'dart:async';

import 'package:characters/characters.dart';

import '../../../core/contract/conversation.dart';
import '../../../core/contract/messages/chat_message.dart';
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

  return DemoChatRepository(
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
      conv('cv_migrate', '旧版迁移笔记', const Duration(days: 40), archived: true), // the archived (gray) example
    ],
    messages: {
      for (final s in shows) s.conv.id: s.messages,
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
}
