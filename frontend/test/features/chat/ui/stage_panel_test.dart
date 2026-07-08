import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/touchpoint.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// StagePanel (WRK-061 W1) — the sidestage assembly wired end-to-end over the fixture: the Cast
// hydrates from the ledger, a streamed create_document STAGES (generic stage: brow + honesty ribbon +
// live tail) and settles, a touchpoint signal lands a Cast row live. 侧幕组装接线电池。
// 抢镜电池的状态机部分在 stage_director_test;此处证组装:台账水化/登台渲染/触点落行。

const _conv = 'cv_1';
const _scope = StreamScope(kind: 'conversation', id: _conv);

FixtureChatRepository _repo() => FixtureChatRepository(conversations: [
      Conversation(
        id: _conv,
        title: 'stage test',
        createdAt: DateTime.utc(2026, 7, 8),
        updatedAt: DateTime.utc(2026, 7, 8),
        lastMessageAt: DateTime.utc(2026, 7, 8),
      ),
    ]);

Widget _host(FixtureChatRepository repo) => ProviderScope(
      overrides: [chatRepositoryProvider.overrideWithValue(repo)],
      child: TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: SizedBox(width: 320, height: 640, child: StagePanel(conversationId: _conv)),
          ),
        ),
      ),
    );

Touchpoint _tp(String id, String kind, String itemId, String name, TouchpointVerb verb) => Touchpoint(
      id: id,
      conversationId: _conv,
      itemKind: kind,
      itemId: itemId,
      itemName: name,
      verb: verb,
      lastActor: TouchpointActor.assistant,
      count: 1,
      firstAt: DateTime.now().toUtc(),
      lastAt: DateTime.now().toUtc(),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('idle: the Cast hydrates from the ledger; empty state when none', (tester) async {
    final repo = _repo();
    repo.touchpoints[_conv] = [
      _tp('tp_1', 'function', 'fn_1', 'sync_inventory', TouchpointVerb.edited),
      _tp('tp_2', 'document', 'doc_1', '值班手册', TouchpointVerb.viewed),
    ];
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('sync_inventory'), findsOneWidget);
    expect(find.text('值班手册'), findsOneWidget);
    expect(find.byType(AnCastRow), findsNWidgets(2));

    final empty = _repo();
    await tester.pumpWidget(_host(empty));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(t.chat.stage.castEmpty), findsOneWidget);
  });

  testWidgets('a streamed create_document STAGES (brow + honesty ribbon + live tail), then settles',
      (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();

    repo.emitFrame(
        _conv,
        const StreamEnvelope(
            seq: 1, scope: _scope, id: 'tc_1',
            frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'create_document'}))));
    repo.emitFrame(
        _conv,
        const StreamEnvelope(
            seq: 0, scope: _scope, id: 'tc_1',
            frame: FrameDelta(chunk: '{"name":"runbook.md","content":"# 手册\\\\n第一行')));
    await tester.pump(const Duration(milliseconds: 600)); // entrance debounce 防抖
    await tester.pump(const Duration(milliseconds: 300)); // reveal animation 揭示动画
    // Once: the brow name (the DOCUMENT stage renders a prose curtain, not the generic KV — W2).
    // 一次:眉名(document 舞台渲散文幕而非通用 KV,W2)。
    expect(find.text('runbook.md'), findsOneWidget);
    expect(find.byType(AnMinimapSpine), findsOneWidget); // the spine 书脊
    expect(find.text(t.chat.stage.ribbonLive), findsOneWidget); // honesty 丝带
    expect(find.textContaining('第一行'), findsOneWidget); // live tail 活尾窗

    repo.emitFrame(
        _conv,
        const StreamEnvelope(
            seq: 2, scope: _scope, id: 'tc_1',
            frame: FrameClose(status: 'completed', result: StreamNode(type: 'tool_call', content: {
              'name': 'create_document',
              'arguments': '{"name":"runbook.md","content":"# 手册"}',
              'entityName': 'runbook.md',
            }))));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(t.chat.stage.settled), findsOneWidget); // settled章 落定章
    // Curtain: after the breath the stage returns to idle. 停拍后谢幕回静场。
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(t.chat.stage.settled), findsNothing);
  });

  testWidgets('a durable touchpoint signal lands a Cast row live', (tester) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(t.chat.stage.castEmpty), findsOneWidget);
    repo.touch(_tp('tp_9', 'workflow', 'wf_1', 'nightly_rollup', TouchpointVerb.created));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('nightly_rollup'), findsOneWidget);
    expect(find.text(t.chat.stage.castEmpty), findsNothing);
  });
}
