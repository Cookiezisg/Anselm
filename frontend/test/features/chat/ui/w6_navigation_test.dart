import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/messages/chat_message.dart';
import 'package:anselm/core/contract/touchpoint.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/chat/state/transcript_jump_provider.dart';
import 'package:anselm/features/chat/ui/chat_toc.dart';
import 'package:anselm/features/chat/ui/chat_transcript.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// W6 navigation batteries: the transcript deep jump (re-anchor + the「跳转不夺视口」acceptance),
// the 场次条 drawer (grouped anchors → jump), and the Cast exhibit (点行登台 + attachment 展品座).
// W6 导航电池:深跳(重锚+不夺视口验收)、场次条(锚点→跳转)、Cast 展品(点行登台+附件展品座)。

const _conv = 'cv_1';
const _scope = StreamScope(kind: 'conversation', id: _conv);

Conversation _c() {
  final at = DateTime.utc(2026, 7, 8, 9);
  return Conversation(id: _conv, title: 'T', createdAt: at, updatedAt: at, lastMessageAt: at);
}

ChatMessage _turn(int i, {List<ChatBlock>? blocks, String status = 'completed'}) => ChatMessage(
      id: 'msg_$i',
      conversationId: _conv,
      role: i.isEven ? 'user' : 'assistant',
      status: status,
      blocks: blocks ??
          [ChatBlock(id: 'b_$i', type: 'text', content: '第 $i 回内容', status: 'completed')],
      createdAt: DateTime.utc(2026, 7, 8, 9).add(Duration(minutes: i)),
    );

FixtureChatRepository _repo({int count = 60}) => FixtureChatRepository(
      conversations: [_c()],
      messages: {
        _conv: [for (var i = 0; i < count; i++) _turn(i)],
      },
    );

class _NoSelection extends SelectedConversation {
  @override
  ConversationRef? build() => null;
}

Widget _host(FixtureChatRepository repo, Widget child) => ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        // The real selection derives from the router — absent in unit hosts. 真选区依赖路由,单测桩掉。
        selectedConversationProvider.overrideWith(_NoSelection.new),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(body: SizedBox(width: 720, height: 760, child: child)),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('deep jump re-anchors on the target + shows the back-to-present pill; '
      'streaming frames never steal the viewport (the acceptance)', (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo, ChatTranscriptView(conversationId: _conv)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final el = tester.element(find.byType(ChatTranscriptView));
    final container = ProviderScope.containerOf(el, listen: false);
    container.read(transcriptJumpProvider(_conv).notifier).request('msg_5');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // The target turn is on screen at the anchor; the pill floats. 目标在锚位;pill 浮现。
    // (assistant prose renders as rich markdown spans). assistant 散文是富文本。
    expect(find.textContaining('第 5 回内容', findRichText: true), findsOneWidget);
    expect(find.text(t.chat.backToPresent), findsOneWidget);

    // Streaming frames land while detached — the viewport must NOT be yanked to the bottom.
    // 离场期间流式帧到达——视口绝不许被拽底。
    final scrollable = find.byType(Scrollable).first;
    final before = tester.widget<Scrollable>(scrollable).controller!.position.pixels;
    repo.emitFrame(_conv, const StreamEnvelope(
        seq: 9, scope: _scope, id: 'live_m',
        frame: FrameOpen(node: StreamNode(type: 'message', content: {'role': 'assistant'}))));
    repo.emitFrame(_conv, const StreamEnvelope(
        seq: 0, scope: _scope, id: 'live_m', frame: FrameDelta(chunk: '新内容涌来')));
    await tester.pump(const Duration(milliseconds: 100));
    final after = tester.widget<Scrollable>(scrollable).controller!.position.pixels;
    expect(after, before); // zero viewport theft 零夺视口
    // The live turn is HIDDEN while detached (it belongs to the present). 离场藏 live。
    expect(find.textContaining('新内容涌来', findRichText: true), findsNothing);

    // The pill rejoins the live present — AND docks back to the bottom (the newest turn visible;
    // rejoining without re-docking would maroon the reader mid-history). pill 归队现场——且**重新贴底**
    // (最新回合可见;归队不贴底=把读者晾在史中)。
    await tester.tap(find.text(t.chat.backToPresent));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(t.chat.backToPresent), findsNothing);
    final pos = tester.widget<Scrollable>(find.byType(Scrollable).first).controller!.position;
    expect((pos.maxScrollExtent - pos.pixels).abs() < 2, isTrue,
        reason: 'rejoin docks to the present 归队即贴底 (pixels=${pos.pixels}, max=${pos.maxScrollExtent})');
    expect(find.textContaining('第 59 回内容', findRichText: true), findsOneWidget,
        reason: 'the newest turn is on screen 最新回合在屏');
  });

  testWidgets('场次条: the drawer groups anchors and a tap fires the jump', (tester) async {
    final repo = FixtureChatRepository(
      conversations: [_c()],
      messages: {
        _conv: [
          _turn(0),
          _turn(1, blocks: [
            const ChatBlock(id: 'tc_a', type: 'tool_call', attrs: {'tool': 'get_function'}, status: 'completed'),
            const ChatBlock(id: 'tc_b', type: 'tool_call', attrs: {'tool': 'edit_function'}, status: 'completed'),
            const ChatBlock(
                id: 'tc_c',
                type: 'tool_call',
                attrs: {'tool': 'delete_function', 'danger': 'dangerous', 'entityName': 'fn_old'},
                status: 'completed'),
          ]),
          _turn(2),
        ],
      },
    );
    await tester.pumpWidget(_host(repo, Center(child: TranscriptToc(conversationId: _conv))));
    await tester.pump();
    await tester.tap(find.byType(AnButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('第 0 回内容'), findsOneWidget); // user anchors 用户主锚
    expect(find.text('第 2 回内容'), findsOneWidget);
    expect(find.text(t.chat.toc.toolCluster(n: 2)), findsOneWidget); // ⚙ 2 folded 折叠簇
    expect(find.text('delete_function · fn_old'), findsOneWidget); // danger surfaces 危险露出

    // Hold the autoDispose channel open like the real transcript view does, THEN tap.
    // 先像真视图那样持住 autoDispose 通道,再点。
    final el = tester.element(find.byType(TranscriptToc));
    final container = ProviderScope.containerOf(el, listen: false);
    TranscriptJumpRequest? received;
    final sub = container.listen(transcriptJumpProvider(_conv), (_, next) => received = next);
    await tester.tap(find.text('第 0 回内容'));
    await tester.pump();
    // The command channel fired for msg_0 (the view consumes + clears it in the real page).
    // 命令通道已为 msg_0 发射(真页面里由视图消费并清除)。
    expect(received, isNotNull);
    expect(received!.messageId, 'msg_0');
    sub.close();
  });

  testWidgets('Cast 点行登台: an entity row pins the identity-face exhibit; attachment gets the 展品座',
      (tester) async {
    final repo = FixtureChatRepository(conversations: [_c()]);
    final at = DateTime.now().toUtc();
    repo.touchpoints[_conv] = [
      Touchpoint(
          id: 'tp_1', conversationId: _conv, itemKind: 'function', itemId: 'fn_1',
          itemName: 'sync_inventory', verb: TouchpointVerb.edited, lastActor: TouchpointActor.assistant,
          count: 2, firstAt: at, lastAt: at, lastMessageId: 'msg_9'),
      Touchpoint(
          id: 'tp_2', conversationId: _conv, itemKind: 'attachment', itemId: 'att_1',
          itemName: 'photo.png', verb: TouchpointVerb.attached, lastActor: TouchpointActor.user,
          count: 1, firstAt: at, lastAt: at),
    ];
    final att = await repo.uploadAttachment(bytes: [1, 2, 3], filename: 'photo.png');
    repo.touchpoints[_conv]![1] = repo.touchpoints[_conv]![1].copyWith(itemId: att.id);

    await tester.pumpWidget(_host(repo, SizedBox(width: 340, child: StagePanel(conversationId: _conv))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Tapping the row EXPANDS it in place (accordion, WRK-064) to the settled identity summary — the id
    // KV + the verb history — no separate exhibit surface. 点行就地展开为 settled 身份摘要(id KV + 动词史)。
    await tester.tap(find.text('sync_inventory'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('fn_1'), findsOneWidget); // the id KV row 身份 KV
    expect(find.text(t.chat.stage.verb.edited), findsWidgets); // verb history 动词史

    // Tapping it again collapses the row (sticky until re-toggled). 再点收起(粘性)。
    await tester.tap(find.text('sync_inventory'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500)); // collapse reveal 收起揭示
    expect(find.text('fn_1'), findsNothing);
  });
}
