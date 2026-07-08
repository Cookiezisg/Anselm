import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/chat_drafts.dart';
import 'package:anselm/features/chat/state/conversation_header.dart';
import 'package:anselm/features/chat/state/new_conversation.dart';
import 'package:anselm/features/chat/state/pending_attachments.dart';
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

Widget _host(FixtureChatRepository repo, {Widget? child, SettingsPrefs? prefs}) => ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repo),
        selectedConversationProvider.overrideWith(_FakeSelected.new),
        mentionSourceProvider.overrideWithValue(_FakeMentions()),
        if (prefs != null) settingsPrefsProvider.overrideWithValue(prefs),
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

  testWidgets('sendKey=cmdEnter: bare Enter is a newline, ⌘Enter sends (S1 偏好)', (tester) async {
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
    final prefs = SettingsPrefs.inMemory({'an.chat.sendKey': 'cmdEnter'});
    await tester.pumpWidget(_host(repo, prefs: prefs));
    await _settle(tester);

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _settle(tester);
    expect(repo.lastSend, isNull, reason: 'cmdEnter 模式下裸回车不发');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await _settle(tester);
    expect(repo.lastSend?.content, 'hello', reason: '⌘Enter 发送');
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

  testWidgets('single-line height is INVARIANT to the send button appearing', (tester) async {
    // The regression: send/stop rendered a tier taller (md 28) than the sm(24) lead buttons, so the
    // first keystroke re-maxed the row and the whole composer grew 4px (animated — "cute" but wrong).
    // 回归钉:send/stop 曾比 lead 高一档,首键出现把整盒撑高 4px(被动画平滑成「可爱的突长高」)。
    final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final emptyH = tester.getSize(find.byType(AnComposer)).height;

    await tester.enterText(find.byType(TextField), 'x');
    await tester.pumpAndSettle(); // let the AnimatedSize morph finish 等形变动画走完
    expect(find.byIcon(AnIcons.send), findsOneWidget);
    expect(tester.getSize(find.byType(AnComposer)).height, emptyH);
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
        child: ChatComposer(onSubmitNew: (text, mentions, attachmentIds) async {
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

  test('landing create rolls back the orphan when the modelOverride PATCH fails — no empty-title thread left (L4)', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final repo = FixtureChatRepository(conversations: [], messages: {});
    final container = ProviderContainer(overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      selectedConversationProvider.overrideWith(_FakeSelected.new),
    ]);
    addTearDown(container.dispose);

    String? createdId;
    final sub = repo.lifecycleSignals().listen((s) {
      if (s.action.name == 'created') createdId = s.id;
    });

    // The landing had a model chosen → startConversation stamps it via PATCH between create and send. That
    // PATCH throws here: create succeeded, the model-stamp fails, and there's a live orphan to roll back.
    // (A SEND failure is NOT an orphan — that's the optimistic failed-bubble path, thread legitimately kept.)
    container.read(landingModelProvider.notifier).set((apiKeyId: 'ak_1', modelId: 'm_1'));
    repo.failNextModelOverride = true;
    await expectLater(container.read(startConversationProvider)('第一句'), throwsA(isA<StateError>()));
    await pumpEventQueue();
    expect(createdId, isNotNull, reason: 'the thread WAS created before the model-stamp failed');
    // The orphan must be rolled back — getConversation now 404s (StateError), so no empty-title row lingers
    // in the rail. 孤儿已回滚:查不到(StateError),rail 不留空标题行。
    await expectLater(repo.getConversation(createdId!), throwsA(isA<StateError>()));
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

    testWidgets('mid-word backspace does NOT atomic-delete the pill (@name glued to more text) (L1)', (tester) async {
      final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
      await tester.pumpWidget(_host(repo));
      await tester.enterText(find.byType(TextField).last, '@syn');
      await pumpQuery(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // pick sync_inventory → pillNames has it
      await pumpQuery(tester);
      final ctl = tester.widget<TextField>(find.byType(TextField).last).controller!;
      // Glue text right after the pill, caret sitting BETWEEN the pill and the glued text. 药丸后粘字、光标夹中。
      ctl.value = const TextEditingValue(
          text: '@sync_inventoryxyz', selection: TextSelection.collapsed(offset: '@sync_inventory'.length));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      // The whole `@sync_inventory` must NOT be atomically eaten (that was the L1 bug). 药丸不被整删。
      expect(ctl.text, isNot('xyz'));
      expect(ctl.text, contains('sync_inventor'));
    });

    testWidgets('lead @ button on a REVERSE selection replaces it without duplicating text (L3)', (tester) async {
      final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
      await tester.pumpWidget(_host(repo));
      await _settle(tester);
      final ctl = tester.widget<TextField>(find.byType(TextField).last).controller!;
      // "hello world" with "world" selected RIGHT-TO-LEFT (base > extent). The old code used base/extent
      // raw → `substring(0,base) + '@' + substring(extent)` DUPLICATED "world". 反向选区曾重复选中文本。
      ctl.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 11, extentOffset: 6),
      );
      await tester.pump();
      await tester.tap(find.byIcon(AnIcons.mention));
      await tester.pump();
      expect(ctl.text, 'hello @'); // "world" replaced, NOT "hello world @world" 选中被替换、无重复
    });
  });


  group('attachments', () {
    testWidgets('ready chips render in the strip; the send carries attachmentIds and clears the strip',
        (tester) async {
      final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
      late final ProviderContainer c;
      await tester.pumpWidget(Builder(builder: (ctx) {
        final host = _host(repo);
        return host;
      }));
      c = ProviderScope.containerOf(tester.element(find.byType(ChatComposer)));
      await c.read(pendingAttachmentsProvider('cv_1').notifier).addBytes([1, 2], filename: 'a.pdf', mimeType: 'application/pdf');
      await tester.pump();
      expect(find.byType(AnAttachmentChip), findsOneWidget);
      expect(find.text('a.pdf'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '看这个图');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await _settle(tester);
      expect(repo.lastSendAttachmentIds, [repo.uploads.single.id]);
      expect(c.read(pendingAttachmentsProvider('cv_1')), isEmpty); // cleared after send 发后清
    });

    testWidgets('attachments-only send is allowed; uploading gates the send', (tester) async {
      final repo = FixtureChatRepository(conversations: [_conv('cv_1')], messages: {'cv_1': []});
      await tester.pumpWidget(_host(repo));
      final c = ProviderScope.containerOf(tester.element(find.byType(ChatComposer)));
      await c.read(pendingAttachmentsProvider('cv_1').notifier).addBytes([7], filename: 'r.pdf');
      await tester.pump();
      // ready + no text → the send button EXISTS (attachments alone may send) 纯附件可发
      expect(find.byKey(const ValueKey('send')), findsOneWidget);

      repo.failNextUpload = true;
      await c.read(pendingAttachmentsProvider('cv_1').notifier).addBytes([8], filename: 'x.bin');
      await tester.pump();
      // one failed chip present; still no uploading → still sendable; now simulate uploading gate:
      // a failed chip never gates; only uploading does. 失败不禁发,仅上传中禁。
      expect(find.byKey(const ValueKey('send')), findsOneWidget);
    });
  });

}

class _FakeMentions extends MentionSource {
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
