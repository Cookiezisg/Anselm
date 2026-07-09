import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/touchpoint.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/features/chat/ui/stages/document_stage.dart';
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
    // Each touchpoint is a left-island AnRow (WRK-064 — the sidestage speaks the rail's row language).
    // 每个触点是一条左岛 AnRow。
    expect(find.byType(AnRow), findsNWidgets(2));

    final empty = _repo();
    await tester.pumpWidget(_host(empty));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(t.chat.stage.castEmpty), findsOneWidget);
  });

  testWidgets('a streamed create_document auto-expands its live row to the document stage, then settles',
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
    await tester.pump(const Duration(milliseconds: 600)); // entrance debounce → director stages 防抖→登台
    // follow=always auto-opens the row; the body resolves itemId → the row-key migrates; each step needs a
    // frame, so pump generously. follow=always 自动展开 → body 解 itemId → 行键迁移,逐步各需一帧。
    for (var k = 0; k < 6; k++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    // The DOCUMENT stage renders IN the expanded row (no brow — the row header is the identity, WRK-064).
    // 文档舞台在展开行内渲染(无眉——行头即身份)。
    expect(find.byType(DocumentStageBody), findsOneWidget); // the document kind stage 文档舞台
    expect(find.text(t.chat.stage.ribbonLive), findsOneWidget); // live honesty ribbon 活丝带
    expect(find.textContaining('第一行'), findsWidgets); // live tail 活尾窗

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
    // Clean settle drops the live ribbon; the row (and its settled document stage) stay — nothing curtains
    // it away (§8-3 落定不自动收). 干净落定去活丝带;行与落定文档舞台留存,绝不谢幕移除。
    expect(find.text(t.chat.stage.ribbonLive), findsNothing);
    expect(find.byType(DocumentStageBody), findsOneWidget);
  });

  testWidgets('load-more foot paginates WITHOUT a build-phase provider mutation (HIGH regression)',
      (tester) async {
    final repo = _repo();
    // 60 touchpoints → the first page is 50 with hasMore, so the load-more foot renders. 60 触点→首页 50 有脚。
    repo.touchpoints[_conv] = [
      for (var i = 0; i < 60; i++)
        _tp('tp_$i', 'function', 'fn_$i', 'fn_num_$i', TouchpointVerb.edited),
    ];
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Scroll the foot into view — its loadMore() is DEFERRED to a post-frame callback; a build-phase call
    // (the pre-fix bug) would trip Riverpod's «modify a provider while building» guard and surface as a
    // thrown exception here. 滚出脚:loadMore 已 post-frame 延迟;build 期调用(修复前)会触发 Riverpod 守卫抛错。
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -6000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull); // no build-phase mutation throw 无 build 期变异抛错
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
