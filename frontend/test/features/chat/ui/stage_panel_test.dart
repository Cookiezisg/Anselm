import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/messages/chat_message.dart';
import 'package:anselm/core/contract/touchpoint.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/ui/stage_panel.dart';
import 'package:anselm/features/chat/ui/stages/document_stage.dart';
import 'package:anselm/features/chat/ui/stages/subagent_stage.dart';
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

FixtureChatRepository _repo() => FixtureChatRepository(
  conversations: [
    Conversation(
      id: _conv,
      title: 'stage test',
      createdAt: DateTime.utc(2026, 7, 8),
      updatedAt: DateTime.utc(2026, 7, 8),
      lastMessageAt: DateTime.utc(2026, 7, 8),
    ),
  ],
);

Widget _host(FixtureChatRepository repo) => ProviderScope(
  overrides: [chatRepositoryProvider.overrideWithValue(repo)],
  child: TranslationProvider(
    child: MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 320,
          height: 640,
          child: StagePanel(conversationId: _conv),
        ),
      ),
    ),
  ),
);

Touchpoint _tp(
  String id,
  String kind,
  String itemId,
  String name,
  TouchpointVerb verb,
) => Touchpoint(
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

  testWidgets('idle: the Cast hydrates from the ledger; empty state when none', (
    tester,
  ) async {
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
    // Each touchpoint is a left-island AnRow (WRK-064 — the sidestage speaks the rail's row language). Both
    // touched `now` → one time tier (刚刚) → the anti-目录病 rule renders NO group head (single tier = bare
    // rows, 三段式文法 §3, 用户 0719). So exactly 2 AnRows. 都在同一时间档(刚刚)→ 单档免组头 → 恰 2 行。
    expect(find.byType(AnRow), findsNWidgets(2));

    final empty = _repo();
    await tester.pumpWidget(_host(empty));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(t.chat.stage.castEmpty), findsOneWidget);
  });

  testWidgets(
    'a streamed create_document auto-expands its live row, dwells on settle, then curtain-collapses',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();

      repo.emitFrame(
        _conv,
        const StreamEnvelope(
          seq: 1,
          scope: _scope,
          id: 'tc_1',
          frame: FrameOpen(
            node: StreamNode(
              type: 'tool_call',
              content: {'name': 'create_document'},
            ),
          ),
        ),
      );
      repo.emitFrame(
        _conv,
        const StreamEnvelope(
          seq: 0,
          scope: _scope,
          id: 'tc_1',
          frame: FrameDelta(
            chunk: '{"name":"runbook.md","content":"# 手册\\\\n第一行',
          ),
        ),
      );
      await tester.pump(
        const Duration(milliseconds: 600),
      ); // entrance debounce → director stages 防抖→登台
      // follow=always auto-opens the row; the body resolves itemId → the row-key migrates; each step needs a
      // frame, so pump generously. follow=always 自动展开 → body 解 itemId → 行键迁移,逐步各需一帧。
      for (var k = 0; k < 6; k++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      // The DOCUMENT stage renders IN the expanded row (no brow — the row header is the identity, WRK-064).
      // 文档舞台在展开行内渲染(无眉——行头即身份)。
      expect(
        find.byType(DocumentStageBody),
        findsOneWidget,
      ); // the document kind stage 文档舞台
      expect(
        find.text(t.feedback.cast.ribbonLive),
        findsOneWidget,
      ); // live honesty ribbon 活丝带
      expect(find.textContaining('第一行'), findsWidgets); // live tail 活尾窗

      repo.emitFrame(
        _conv,
        const StreamEnvelope(
          seq: 2,
          scope: _scope,
          id: 'tc_1',
          frame: FrameClose(
            status: 'completed',
            result: StreamNode(
              type: 'tool_call',
              content: {
                'name': 'create_document',
                'arguments': '{"name":"runbook.md","content":"# 手册"}',
                'entityName': 'runbook.md',
              },
            ),
          ),
        ),
      );
      repo.emitFrame(
        _conv,
        const StreamEnvelope(
          seq: 3,
          scope: _scope,
          id: 'tr_1',
          frame: FrameOpen(
            parentId: 'tc_1',
            node: StreamNode(type: 'tool_result', content: {'content': ''}),
          ),
        ),
      );
      repo.emitFrame(
        _conv,
        const StreamEnvelope(
          seq: 4,
          scope: _scope,
          id: 'tr_1',
          frame: FrameClose(
            status: 'completed',
            result: StreamNode(type: 'tool_result', content: {'content': 'ok'}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      // 缺口B (0719) — the clean settle drops the live ribbon; the row DWELLS (settleBreath ≈ 1.8s) so the reader
      // sees the settled result, its stage still on screen. 落定去活丝带;行停留(settleBreath≈1.8s)让人看清结果、舞台仍在。
      expect(find.text(t.feedback.cast.ribbonLive), findsNothing);
      expect(
        find.byType(DocumentStageBody),
        findsOneWidget,
      ); // still expanded through the dwell 停留期仍展开

      // After the dwell the director curtains the settled subject (following → idle) → the row WE auto-opened
      // collapses back to a ledger row on the AnExpandReveal slide (缺口B). pinned / failed holds are exempt (they
      // never reach this transition). 停留后导演器谢幕(following→idle)→ 自动展开的行动画收回台账行(pinned/失败豁免)。
      await tester.pump(
        const Duration(milliseconds: 1900),
      ); // past settleBreath (1800ms) → curtain fires 越过停留
      await tester.pump(
        const Duration(milliseconds: 400),
      ); // the reveal collapses 收起动画
      expect(
        find.byType(DocumentStageBody),
        findsNothing,
      ); // the auto-opened stage curtained away 自动展开的舞台谢幕收起
    },
  );

  testWidgets(
    'load-more foot paginates WITHOUT a build-phase provider mutation (HIGH regression)',
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
      expect(
        tester.takeException(),
        isNull,
      ); // no build-phase mutation throw 无 build 期变异抛错
    },
  );

  testWidgets(
    'a settled subagent run rehydrates as a row that expands to its nested trajectory (B6)',
    (tester) async {
      // A delegated run persists as a top-level Subagent tool_call + a SIBLING sub-message (subagentId ≠ '',
      // attrs.parentBlockId). The transcript folds the trajectory back under the tool_call; the sidestage
      // lists it as a settled row WITHOUT any touchpoint. 落定 subagent 行(无触点,嵌套轨迹重水合)。
      final repo = FixtureChatRepository(
        conversations: [
          Conversation(
            id: _conv,
            title: 'x',
            createdAt: DateTime.utc(2026, 7, 8),
            updatedAt: DateTime.utc(2026, 7, 8),
            lastMessageAt: DateTime.utc(2026, 7, 8),
          ),
        ],
        messages: {
          _conv: [
            ChatMessage(
              id: 'msg_top',
              conversationId: _conv,
              role: 'assistant',
              status: 'completed',
              createdAt: DateTime.utc(2026, 7, 8, 10),
              blocks: [
                ChatBlock(
                  id: 'call_1',
                  type: 'tool_call',
                  content: '{"description":"调研通知渠道"}',
                  status: 'completed',
                  attrs: {'tool': 'Subagent'},
                ),
              ],
            ),
            ChatMessage(
              id: 'msg_sub',
              conversationId: _conv,
              role: 'assistant',
              status: 'completed',
              subagentId: 'sa_1',
              attrs: {'parentBlockId': 'call_1'},
              createdAt: DateTime.utc(2026, 7, 8, 11),
              blocks: [
                ChatBlock(
                  id: 'r1',
                  type: 'reasoning',
                  content: '想一想',
                  status: 'completed',
                ),
                ChatBlock(
                  id: 't1',
                  type: 'tool_call',
                  content: '{"pattern":"x"}',
                  status: 'completed',
                  attrs: {'tool': 'grep'},
                ),
                ChatBlock(
                  id: 'x1',
                  type: 'text',
                  content: '找到 slack 渠道最省事',
                  status: 'completed',
                ),
              ],
            ),
          ],
        },
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 100),
      ); // hydrate + fold → transcript listener rebuilds
      // The settled subagent surfaces as a row labelled with the delegate's description — no touchpoint.
      // 落定 subagent 成行(标题=委派描述),无触点。
      expect(find.text('调研通知渠道'), findsOneWidget);
      // Tap to expand → the SUBAGENT stage renders its folded ReAct trajectory tail (the sub-run's text).
      // 点开 → subagent 舞台渲折好的 ReAct 轨迹尾(子运行文本)。
      await tester.tap(find.text('调研通知渠道'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SubagentStageBody), findsOneWidget);
      expect(find.textContaining('找到 slack'), findsWidgets);
    },
  );

  testWidgets('a durable touchpoint signal lands a Cast row live', (
    tester,
  ) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(t.chat.stage.castEmpty), findsOneWidget);
    repo.touch(
      _tp('tp_9', 'workflow', 'wf_1', 'nightly_rollup', TouchpointVerb.created),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('nightly_rollup'), findsOneWidget);
    expect(find.text(t.chat.stage.castEmpty), findsNothing);
  });
}
