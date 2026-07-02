import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/chat_drafts.dart';
import 'package:anselm/features/chat/state/new_conversation.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/chat/ui/chat_composer.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The composer's behaviour contract: Enter sends / Shift+Enter newline / IME-composing Enter never
// sends / ENTER IS GATED WHILE GENERATING (the documented old gap) / send hidden when empty / stop
// while generating cancels / drafts survive a remount / the landing submit keeps text on failure.
// composer 行为契约:Enter 发/Shift+Enter 换行/IME 合成期不发/**生成中 Enter 门控**(已记档旧缺口)/空藏
// 发送/生成中 stop=cancel/草稿跨重挂/landing 失败不吞字。

const _scope = StreamScope(kind: 'conversation', id: 'cv_1');

StreamEnvelope _open(String id, String type, {String? parentId, Map<String, dynamic>? content}) =>
    StreamEnvelope(seq: 5, scope: _scope, id: id,
        frame: FrameOpen(parentId: parentId, node: StreamNode(type: type, content: content)));

Conversation _conv(String id) {
  final at = DateTime.utc(2026, 7, 2, 9);
  return Conversation(id: id, title: 'T', createdAt: at, updatedAt: at, lastMessageAt: at);
}

class _FakeSelected extends SelectedConversation {
  @override
  ConversationRef? build() => const ConversationRef('cv_1');
}

Widget _host(FixtureChatRepository repo, {Widget? child}) => ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        selectedConversationProvider.overrideWith(_FakeSelected.new),
        mentionSourceProvider.overrideWithValue(_FakeMentions()),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 560, child: child ?? const ChatComposer(conversationId: 'cv_1')),
            ),
          ),
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

void main() {
  testWidgets('Enter sends + clears; Shift+Enter inserts a newline instead', (tester) async {
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
    await tester.pumpWidget(_host(repo));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), '你好');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(repo.lastSend?.content, '你好');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty); // cleared 已清

    await tester.enterText(find.byType(TextField), '第一行');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(repo.lastSend?.content, '你好'); // unchanged — no second send 没发第二条
  });

  testWidgets('an IME-composing Enter never sends', (tester) async {
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
    await tester.pumpWidget(_host(repo));
    await _settle(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.value = const TextEditingValue(
      text: 'nihao',
      selection: TextSelection.collapsed(offset: 5),
      composing: TextRange(start: 0, end: 5), // candidate window open 候选窗开着
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(repo.lastSend, isNull); // the commit-Enter did not send 合成期 Enter 不发
  });

  testWidgets('while generating: Enter is swallowed and the trailing button is STOP → cancel', (tester) async {
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
    await tester.pumpWidget(_host(repo));
    await _settle(tester);

    // A streaming turn is in flight. 在飞回合。
    repo.emitFrame('cv_1', _open('msg_a', 'message', content: {'role': 'assistant'}));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), '想插话');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(repo.lastSend, isNull); // gated 门控住了
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '想插话'); // kept 字还在

    await tester.tap(find.byIcon(AnIcons.stop));
    await _settle(tester);
    expect(repo.cancelled, ['cv_1']);
  });

  testWidgets('send button hidden when empty; appears with content', (tester) async {
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
    await tester.pumpWidget(_host(repo));
    await _settle(tester);
    expect(find.byIcon(AnIcons.send), findsNothing);

    await tester.enterText(find.byType(TextField), 'x');
    await tester.pump();
    expect(find.byIcon(AnIcons.send), findsOneWidget);
  });

  testWidgets('the draft survives a remount and clears after a successful send', (tester) async {
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      selectedConversationProvider.overrideWith(_FakeSelected.new),
    ]);
    addTearDown(container.dispose);
    Widget host() => UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: MaterialApp(
              theme: AnTheme.light(),
              home: Scaffold(
                  body: Center(
                      child: SizedBox(width: 560, child: ChatComposer(conversationId: 'cv_1')))),
            ),
          ),
        );

    await tester.pumpWidget(host());
    await _settle(tester);
    await tester.enterText(find.byType(TextField), '写了一半');
    await tester.pump();

    await tester.pumpWidget(const SizedBox.shrink()); // unmount 卸载
    await tester.pumpWidget(host()); // remount 重挂
    await _settle(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '写了一半'); // restored 已恢复

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(container.read(chatDraftsProvider).of('cv_1'), isEmpty); // cleared on send 发后清
  });

  testWidgets('landing submit: keeps the text on failure, clears on success', (tester) async {
    final repo = FixtureChatRepository(conversations: [], messages: {});
    var fail = true;
    await tester.pumpWidget(_host(repo,
        child: ChatComposer(onSubmitNew: (text, mentions) async {
          if (fail) throw StateError('scripted create failure');
        })));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), '首条消息');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '首条消息'); // not eaten 不吞

    fail = false;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
  });

  test('startConversation: create (rail echo emitted) then send through the new pipeline', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = FixtureChatRepository(conversations: [], messages: {});
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      selectedConversationProvider.overrideWith(_FakeSelected.new),
    ]);
    addTearDown(container.dispose);

    final echoes = <String>[];
    final sub = repo.lifecycleSignals().listen((s) => echoes.add('${s.action.name}:${s.id}'));
    final id = await container.read(startConversationProvider)('第一句');
    await pumpEventQueue();
    expect(id, startsWith('cv_fx_'));
    expect(repo.lastSend?.conversationId, id);
    expect(repo.lastSend?.content, '第一句');
    expect(echoes, contains('created:$id')); // the rail hears about it 回声给 rail
    await sub.cancel();
  });

  group('@ typeahead', () {
    Future<void> pumpQuery(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 200)); // debounce 防抖
      await _settle(tester);
    }

    testWidgets('typing @ opens the panel; further typing filters; no match closes', (tester) async {
      final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
      await tester.pumpWidget(_host(repo));
      await tester.enterText(find.byType(TextField).last, '@');
      await pumpQuery(tester);
      expect(find.byType(AnMentionPanel), findsOneWidget);
      expect(find.text('sync_inventory'), findsOneWidget);
      expect(find.text('report_writer'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '@syn');
      await pumpQuery(tester);
      expect(find.text('sync_inventory'), findsOneWidget);
      expect(find.text('report_writer'), findsNothing);

      await tester.enterText(find.byType(TextField).last, '@zzz');
      await pumpQuery(tester);
      expect(find.byType(AnMentionPanel), findsNothing); // no match → closed 无匹配即关
    });

    testWidgets('↑↓ move (wrapping), Enter picks — intercepted before send — and the send carries mentions',
        (tester) async {
      final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
      await tester.pumpWidget(_host(repo));
      await tester.enterText(find.byType(TextField).last, '@');
      await pumpQuery(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // → report_writer
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // picks, must NOT send 选中、不发
      await pumpQuery(tester);
      expect(repo.lastSend, isNull);
      expect(find.byType(AnMentionPanel), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller!.text, '@report_writer ');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // now it sends 这次才发
      await _settle(tester);
      expect(repo.lastSend?.content, '@report_writer');
      expect(repo.lastSend?.mentions, [(type: 'agent', id: 'ag_1')]);
    });

    testWidgets('Esc dismisses and THIS token stays closed; a fresh @ re-opens', (tester) async {
      final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
      await tester.pumpWidget(_host(repo));
      await tester.enterText(find.byType(TextField).last, '@');
      await pumpQuery(tester);
      expect(find.byType(AnMentionPanel), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(AnMentionPanel), findsNothing);

      await tester.enterText(find.byType(TextField).last, '@sy'); // same token keeps closed 同 token 不再弹
      await pumpQuery(tester);
      expect(find.byType(AnMentionPanel), findsNothing);

      await tester.enterText(find.byType(TextField).last, ''); // leave the token 离开
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, '@');
      await pumpQuery(tester);
      expect(find.byType(AnMentionPanel), findsOneWidget); // fresh @ opens 新 @ 再弹
    });

    testWidgets('one backspace right after a pill deletes the whole @name', (tester) async {
      final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
      await tester.pumpWidget(_host(repo));
      await tester.enterText(find.byType(TextField).last, '@syn');
      await pumpQuery(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // pick sync_inventory
      await pumpQuery(tester);
      final ctl = tester.widget<TextField>(find.byType(TextField).last).controller!;
      expect(ctl.text, '@sync_inventory ');

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace); // eats the trailing space 先删尾空格
      await tester.pump();
      expect(ctl.text, '@sync_inventory');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace); // atomic 整删
      await tester.pump();
      expect(ctl.text, '');
    });
  });

}

class _FakeMentions implements MentionSource {
  @override
  Future<List<MentionCandidate>> search(String query) async {
    const all = [
      MentionCandidate(type: 'function', id: 'fn_1', name: 'sync_inventory', description: 'sync stock'),
      MentionCandidate(type: 'agent', id: 'ag_1', name: 'report_writer', description: 'writes reports'),
    ];
    final q = query.toLowerCase();
    return [for (final c in all) if (q.isEmpty || c.name.toLowerCase().contains(q)) c];
  }
}
