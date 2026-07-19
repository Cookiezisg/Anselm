import 'package:anselm/core/contract/attachment.dart';
import 'package:anselm/core/contract/model_capability.dart';
import 'package:anselm/core/model/model_capabilities.dart';
import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/messages/chat_message.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/conversation_stream_provider.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/chat/ui/chat_thinking.dart';
import 'package:anselm/features/chat/ui/chat_transcript.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The transcript view. Pins: phase surfaces, block dispatch to the locked modules (markdown /
// thinking / tool placeholder / cancelled banner), LIVE streaming reaching the leaf, the BuildSpy
// gate (streaming rebuilds ONLY the live leaf — page 0 / settled rows 0), the center-sliver
// prepend (pixels do not move), and the bottom pin (follows while pinned, holds while scrolled up).
// transcript 视图钉:相位面、块派发、流式到叶、BuildSpy 门禁(流式只重建 live 叶——页 0/settled 行 0)、
// center-sliver prepend 零位移、贴底跟随(钉住跟、上翻不动)。

const _scope = StreamScope(kind: 'conversation', id: 'cv_1');

StreamEnvelope _open(String id, String type, {String? parentId, Map<String, dynamic>? content}) =>
    StreamEnvelope(seq: 5, scope: _scope, id: id,
        frame: FrameOpen(parentId: parentId, node: StreamNode(type: type, content: content)));

StreamEnvelope _delta(String id, String chunk) =>
    StreamEnvelope(seq: 0, scope: _scope, id: id, frame: FrameDelta(chunk: chunk));

StreamEnvelope _close(String id, String type, Map<String, dynamic> result, {String status = 'completed'}) =>
    StreamEnvelope(seq: 6, scope: _scope, id: id,
        frame: FrameClose(status: status, result: StreamNode(type: type, content: result)));

Conversation _conv(String id) {
  final at = DateTime.utc(2026, 7, 2, 9);
  return Conversation(id: id, title: 'T', createdAt: at, updatedAt: at, lastMessageAt: at);
}

ChatMessage _turn(String id, String role,
        {String status = 'completed', String stopReason = '', int hour = 10, List<ChatBlock> blocks = const []}) =>
    ChatMessage(id: id, conversationId: 'cv_1', role: role, status: status, stopReason: stopReason,
        blocks: blocks, createdAt: DateTime.utc(2026, 7, 2, hour));

ChatBlock _blk(String id, String type, String content, {Map<String, dynamic>? attrs}) =>
    ChatBlock(id: id, type: type, content: content, status: 'completed', attrs: attrs);

class _FakeSelected extends SelectedConversation {
  @override
  ConversationRef? build() => const ConversationRef('cv_1');
}

Widget _host(FixtureChatRepository repo) => ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        selectedConversationProvider.overrideWith(_FakeSelected.new),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(body: ChatTranscriptView(conversationId: 'cv_1')),
        ),
      ),
    );

FixtureChatRepository _repo({Map<String, List<ChatMessage>>? messages}) =>
    FixtureChatRepository(conversations: [_conv('cv_1')], messages: messages ?? {'cv_1': []});

/// Frames reach the leaf via stream-microtask → coalesced postFrame notify → next-frame build — three
/// pumps in the test binding (production frames run continuously). 帧到叶需 3 泵(生产帧连续、无此事)。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  tearDown(() => TranscriptProbe.onBuild = null);

  testWidgets('hydrated history dispatches blocks to the locked modules', (tester) async {
    final repo = _repo(messages: {
      'cv_1': [
        _turn('msg_u', 'user', hour: 10, blocks: [_blk('bu', 'text', '帮我看下这个')]),
        _turn('msg_a', 'assistant', hour: 11, blocks: [
          _blk('br', 'reasoning', '想一想'),
          _blk('bt', 'text', '**答案**在这'),
          _blk('bc', 'tool_call', '{}', attrs: {'tool': 'web_search'}),
        ]),
        _turn('msg_c', 'assistant', hour: 12, status: 'cancelled', stopReason: 'cancelled',
            blocks: [_blk('bt2', 'text', '半截')]),
      ],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pump(); // hydration future 水化
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('帮我看下这个'), findsOneWidget); // user bubble 用户泡
    expect(find.byType(ChatThinking), findsOneWidget); // reasoning → thinking module
    expect(find.byType(AnMarkdown), findsWidgets); // text → markdown
    expect(find.text('web_search'), findsOneWidget); // tool placeholder V3 前占位
    final t = Translations.of(tester.element(find.byType(ChatTranscriptView)));
    expect(find.textContaining(t.chat.stoppedCancelled), findsOneWidget); // honest banner 诚实横幅
  });

  testWidgets('live streaming: open → deltas grow the leaf → close settles; pinned view follows', (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();

    repo.emitFrame('cv_1', _open('msg_a', 'message', content: {'role': 'assistant'}));
    repo.emitFrame('cv_1', _open('b1', 'text', parentId: 'msg_a', content: {'content': ''}));
    await _settle(tester);

    repo.emitFrame('cv_1', _delta('b1', '第一段'));
    await _settle(tester);
    expect(find.textContaining('第一段', findRichText: true), findsOneWidget);

    repo.emitFrame('cv_1', _delta('b1', ',更多'));
    await _settle(tester);
    expect(find.textContaining('第一段,更多', findRichText: true), findsOneWidget);

    repo.emitFrame('cv_1', _close('b1', 'text', {'content': '第一段,更多'}));
    repo.emitFrame('cv_1',
        _close('msg_a', 'message', {'role': 'assistant', 'status': 'completed', 'stopReason': 'end_turn'}));
    await _settle(tester);
    expect(find.textContaining('第一段,更多', findRichText: true), findsOneWidget);
  });

  testWidgets('a user bubble resolves attachment ids to filename cards (missing → tombstone)',
      (tester) async {
    final repo = _repo(messages: {
      'cv_1': [
        _turn('msg_u', 'user', blocks: [_blk('bu', 'text', '看这个文件')])
      ],
    });
    // attrs carry the id-only snapshot 纯 id 快照
    repo.attachmentMetas['att_ok'] = const AttachmentMeta(
        id: 'att_ok', filename: 'report.pdf', mimeType: 'application/pdf', sizeBytes: 2048, kind: 'document');
    final msgs = await repo.listMessages('cv_1');
    final withAtt = ChatMessage(
      id: 'msg_u', conversationId: 'cv_1', role: 'user', status: 'completed',
      attrs: {'attachments': ['att_ok', 'att_gone']},
      blocks: msgs.items.single.blocks, createdAt: DateTime.utc(2026, 7, 2, 10),
    );
    repo.replaceMessage('cv_1', withAtt);

    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 30)); // meta futures 元数据
    expect(find.text('report.pdf'), findsOneWidget); // resolved 解析成名
    expect(find.text('att_gone'), findsOneWidget); // missing keeps the honest id 缺失留 id
  });

  testWidgets('an image attachment renders a REAL thumbnail (bytes from the seam, cached by id)',
      (tester) async {
    // 1x1 transparent PNG 一像素透明图
    const png = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44,
      0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F,
      0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00,
      0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ];
    final repo = _repo(messages: {
      'cv_1': [
        ChatMessage(
          id: 'msg_u', conversationId: 'cv_1', role: 'user', status: 'completed',
          attrs: {'attachments': ['att_img']},
          blocks: [_blk('bu', 'text', '看图')], createdAt: DateTime.utc(2026, 7, 2, 10),
        ),
      ],
    });
    repo.attachmentMetas['att_img'] = const AttachmentMeta(
        id: 'att_img', filename: 'shot.png', mimeType: 'image/png', sizeBytes: 68, kind: 'image');
    repo.attachmentBytes['att_img'] = png;

    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 50)); // meta + bytes futures
    await tester.pump(const Duration(milliseconds: 50)); // decode frame 解码帧
    expect(find.byType(AnAttachmentThumb), findsOneWidget); // a thumb, not a file card 缩略非文件卡
    expect(find.byType(AnAttachmentCard), findsNothing);
  });

  testWidgets('shorter-than-a-screen content docks to MIN — the first row clears the floating head',
      (tester) async {
    // One short turn: the anchored list would park pixels at 0 (first row under the head); the dock
    // must land on minScrollExtent, revealing the head-clearing padding above the anchor.
    // 一条短回合:锚定列表默认停 0(首行被头盖);dock 应落 min、露出锚上让头 padding。
    final repo = _repo(messages: {
      'cv_1': [_turn('msg_u', 'user', blocks: [_blk('bu', 'text', '短问题')])],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await _settle(tester);

    final pos = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(pos.maxScrollExtent, 0); // not a screenful below the anchor 锚下未满屏
    expect(pos.minScrollExtent, lessThan(0)); // the head-clearing padding 让头 padding
    expect(pos.pixels, pos.minScrollExtent); // docked to the top 钉顶
  });

  testWidgets('BuildSpy gate: 200 streamed deltas rebuild ONLY the live leaf (page 0, settled rows 0)',
      (tester) async {
    final repo = _repo(messages: {
      'cv_1': [
        for (var i = 0; i < 6; i++)
          _turn('msg_$i', i.isEven ? 'user' : 'assistant', hour: 9,
              blocks: [_blk('b$i', 'text', '历史 $i')]),
      ],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    // Open the streaming turn, then instrument. 开流式回合后再挂探针。
    repo.emitFrame('cv_1', _open('msg_live', 'message', content: {'role': 'assistant'}));
    repo.emitFrame('cv_1', _open('bl', 'text', parentId: 'msg_live', content: {'content': ''}));
    await _settle(tester);

    final hits = <String, int>{};
    TranscriptProbe.onBuild = (zone) => hits[zone] = (hits[zone] ?? 0) + 1;

    const batches = 4;
    for (var b = 0; b < batches; b++) {
      for (var i = 0; i < 50; i++) {
        repo.emitFrame('cv_1', _delta('bl', 'x'));
      }
      await _settle(tester);
    }

    expect(hits['page'] ?? 0, 0, reason: 'the page must NEVER rebuild while streaming 页级零重建');
    expect(hits['row-settled'] ?? 0, 0,
        reason: 'settled rows are identity-cached — zero rebuilds while streaming settled 行零重建');
    expect(hits['leaf-stream'] ?? 0, lessThanOrEqualTo(batches * 3 + 2),
        reason: 'the live leaf ticks ≤1×/frame (coalesced) live 叶每帧≤1');
    expect(hits['list'] ?? 0, lessThanOrEqualTo(batches * 3 + 2));
  });

  testWidgets('C-023: a SETTLED text block in an OPEN turn is memoized — zero re-parses while the open '
      'block streams', (tester) async {
    final repo = _repo(messages: {
      'cv_1': [_turn('msg_0', 'user', hour: 9, blocks: [_blk('b0', 'text', 'hi')])],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    // Open an assistant turn holding a SETTLED text block (b1, closed) followed by a still-OPEN one (b2).
    // The whole open turn rebuilds on every b2 delta, so b1 is re-visited each tick. 开回合:落定块 b1 + 开块 b2。
    repo.emitFrame('cv_1', _open('msg_live', 'message', content: {'role': 'assistant'}));
    repo.emitFrame('cv_1', _open('b1', 'text', parentId: 'msg_live', content: {'content': ''}));
    repo.emitFrame('cv_1', _delta('b1', '已落定的一段文字'));
    repo.emitFrame('cv_1', _close('b1', 'text', {'content': '已落定的一段文字'}));
    repo.emitFrame('cv_1', _open('b2', 'text', parentId: 'msg_live', content: {'content': ''}));
    await _settle(tester);

    // Instrument AFTER b1 has settled + been cached. 落定+缓存后再挂探针。
    final hits = <String, int>{};
    TranscriptProbe.onBuild = (zone) => hits[zone] = (hits[zone] ?? 0) + 1;

    for (var i = 0; i < 40; i++) {
      repo.emitFrame('cv_1', _delta('b2', 'x'));
    }
    await _settle(tester);

    // The settled block is served from the id cache — NEVER re-parsed while b2 streams (the C-023 win;
    // without the cache this would be ~40, one GptMarkdown re-parse per tick). 落定块全程零重解析。
    expect(hits['block-text-parse'] ?? 0, 0,
        reason: 'a settled text block must be memoized — zero re-parses while the open block streams');
    // The open block DOES re-parse per tick — proof the turn genuinely rebuilds (the assertion above is
    // not vacuous). 开块逐 tick 重解析(证回合真在重建,上断言非空转)。
    expect(hits['block-text-live'] ?? 0, greaterThan(0),
        reason: 'the open block re-parses per tick (the open turn is genuinely rebuilding)');
  });

  testWidgets('center-sliver prepend: loading an older page does NOT move pixels', (tester) async {
    final repo = _repo(messages: {
      'cv_1': [
        for (var i = 0; i < 45; i++)
          _turn('msg_$i', i.isEven ? 'user' : 'assistant', hour: 9,
              blocks: [_blk('b$i', 'text', '第 $i 条,加一点长度让行高稳定一些。')]),
      ],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    // Scroll up into the older region to trigger loadOlder. 上翻进近顶带触发 loadOlder。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 4000));
    await tester.pump();
    final before = scrollable.position.pixels;
    await tester.pump(const Duration(milliseconds: 60)); // page lands 页落
    await tester.pump(const Duration(milliseconds: 20));
    expect(scrollable.position.pixels, closeTo(before, 0.5),
        reason: 'prepend grows ABOVE the center anchor — reader position never shifts prepend 零位移');
    expect(scrollable.position.minScrollExtent, lessThan(-100),
        reason: 'the older page mounted ABOVE the anchor (negative extent) 老页挂在锚上方(负延伸)');
  });

  testWidgets('scrolled-up reader is not pushed by streaming; pinned reader follows to max', (tester) async {
    final repo = _repo(messages: {
      'cv_1': [
        for (var i = 0; i < 20; i++)
          _turn('msg_$i', i.isEven ? 'user' : 'assistant', hour: 9,
              blocks: [_blk('b$i', 'text', '历史消息 $i —— 撑高度的一行文字。')]),
      ],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);

    // Pinned: at bottom, streaming keeps us at max. 钉住:流式后仍在 max。
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    repo.emitFrame('cv_1', _open('msg_a', 'message', content: {'role': 'assistant'}));
    repo.emitFrame('cv_1', _open('bl', 'text', parentId: 'msg_a', content: {'content': ''}));
    for (var i = 0; i < 30; i++) {
      repo.emitFrame('cv_1', _delta('bl', '流式内容让回合越长越高。'));
    }
    await _settle(tester);
    expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);

    // Scrolled up: more streaming must NOT move pixels. 上翻:继续流式不动 pixels。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
    await tester.pump();
    final held = scrollable.position.pixels;
    for (var i = 0; i < 30; i++) {
      repo.emitFrame('cv_1', _delta('bl', '继续流。'));
    }
    await _settle(tester);
    expect(scrollable.position.pixels, closeTo(held, 0.5),
        reason: 'growth is at the max end — an upward reader holds position 上翻阅读者不被推');
  });

  testWidgets('failed optimistic bubble: retry re-posts, discard removes', (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    final t = Translations.of(tester.element(find.byType(ChatTranscriptView)));

    repo.failNextSend = true;
    final container = ProviderScope.containerOf(tester.element(find.byType(ChatTranscriptView)));
    await container.read(conversationStreamProvider('cv_1').notifier).send('会失败的');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text(t.chat.sendFailed), findsOneWidget);

    await tester.tap(find.text(t.chat.retrySend));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(repo.lastSend?.content, '会失败的'); // re-posted 已重发
    expect(find.text(t.chat.sendFailed), findsNothing);
  });

  testWidgets('LLM_RESOLVE_ERROR banner grows the repick-model CTA that PATCHes the override (拍板 #16)',
      (tester) async {
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {
      'cv_1': [
        ChatMessage(
            id: 'msg_e',
            conversationId: 'cv_1',
            role: 'assistant',
            status: 'error',
            stopReason: 'error',
            errorCode: 'LLM_RESOLVE_ERROR',
            errorMessage: 'api key gone',
            blocks: const [],
            createdAt: DateTime.utc(2026, 7, 2, 10)),
      ],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        selectedConversationProvider.overrideWith(_FakeSelected.new),
        modelCapabilitiesProvider.overrideWith((ref) async => const [
              ModelCapability(
                  apiKeyId: 'ak_2', modelId: 'deepseek-chat', displayName: 'DeepSeek Chat', provider: 'deepseek'),
            ]),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(body: ChatTranscriptView(conversationId: 'cv_1')),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final t = Translations.of(tester.element(find.byType(ChatTranscriptView)));
    expect(find.textContaining('LLM_RESOLVE_ERROR'), findsOneWidget, reason: '诚实横幅带 code');
    expect(find.text(t.chat.repickModel), findsOneWidget, reason: 'CTA 只长在解析失败横幅上');

    await tester.tap(find.text(t.chat.repickModel));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DeepSeek Chat'));
    await tester.pumpAndSettle();
    final conv = await repo.getConversation('cv_1');
    expect(conv.modelOverride?.modelId, 'deepseek-chat', reason: '选中即 PATCH 线程覆写');
  });

  testWidgets('a plain error banner carries NO repick CTA', (tester) async {
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {
      'cv_1': [
        ChatMessage(
            id: 'msg_e2',
            conversationId: 'cv_1',
            role: 'assistant',
            status: 'error',
            stopReason: 'error',
            errorCode: 'HANDLER_RPC_TIMEOUT',
            blocks: const [],
            createdAt: DateTime.utc(2026, 7, 2, 10)),
      ],
    });
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final t = Translations.of(tester.element(find.byType(ChatTranscriptView)));
    expect(find.text(t.chat.repickModel), findsNothing);
  });
}
