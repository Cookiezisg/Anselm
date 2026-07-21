import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:anselm/features/chat/ui/chat_tool_card.dart';
import 'package:anselm/features/chat/ui/tool_card_catalog.dart';
import 'package:anselm/features/chat/ui/tool_card_search.dart';
import 'package:anselm/features/chat/ui/tool_hit_list.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// F07 settled body (B3.3) — hits → ToolHitList; empty → «receipt IS the card» (no body/chevron);
// fallback-only badges (workflow/trigger); per-hit kind (blocks); inert attachments. F07 命中窗接线。

BlockNode _node(String name, String result) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': '{"query":"q"}'}
      ..children.add(
        BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': result},
      );

ToolCardState _state(String name, String result) => ToolCardState(
  phase: ToolCardPhase.succeeded,
  toolName: name,
  summary: '',
  danger: '',
  argsText: '{"query":"q"}',
  resultText: result,
  errorText: '',
  progressText: '',
  progressLive: false,
);

Widget _host(Widget child) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(
      body: SingleChildScrollView(child: SizedBox(width: 640, child: child)),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('hasBodyOf — empty is «receipt IS the card»', () {
    test('non-empty search has a body; empty search does not', () {
      final spec = toolCardSpecFor('search_function');
      expect(
        spec.hasBodyOf!(
          _state(
            'search_function',
            '{"count":2,"functions":[{"id":"a"},{"id":"b"}]}',
          ),
        ),
        isTrue,
      );
      expect(
        spec.hasBodyOf!(
          _state('search_function', '{"count":0,"functions":null}'),
        ),
        isFalse,
      );
    });

    test('search_blocks soft-empty string → no body', () {
      final spec = toolCardSpecFor('search_blocks');
      expect(
        spec.hasBodyOf!(_state('search_blocks', 'No blocks matched "x".')),
        isFalse,
      );
    });
  });

  testWidgets('empty search renders NO body (receipt is the whole card)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node('search_function', '{"count":0,"functions":null}'),
        ),
      ),
    );
    await tester.pump();
    // query present → 已搜索函数; count 0 → 无匹配 receipt; and crucially NO expandable body. 无可展开体。
    expect(find.textContaining('已搜索函数'), findsOneWidget);
    // Tapping the row must NOT reveal a hit list (there is no chevron / body). 点击不出命中窗。
    await tester.tap(find.textContaining('已搜索函数'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ToolHitList), findsNothing);
  });

  testWidgets('non-empty search expands to a ToolHitList of the hits', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChatToolCard(
          node: _node(
            'search_function',
            '{"count":2,"functions":[{"id":"fn_1","name":"alpha","description":"first"},{"id":"fn_2","name":"beta"}]}',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.textContaining('已搜索函数'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(ToolHitList), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
  });

  group('row projections', () {
    test(
      'workflowHitRow: fallback lifecycleState/active → badge; engine path (no ls) → none',
      () {
        final fb = workflowHitRow(t, {
          'id': 'wf_1',
          'name': 'sync',
          'lifecycleState': 'active',
          'active': true,
        });
        expect(fb.kind, 'workflow');
        expect(fb.trailing, isNotNull); // active badge
        final engine = workflowHitRow(t, {
          'id': 'wf_1',
          'name': 'sync',
          'description': 'snippet',
        });
        // engine path: no lifecycleState → the trailing is just the mono id (no fake badge). 无假徽章。
        expect(engine.kind, 'workflow');
      },
    );

    test('triggerHitRow: fallback kind/refCount/listening badges', () {
      final r = triggerHitRow(t, {
        'id': 'trg_1',
        'name': 'cron',
        'kind': 'cron',
        'refCount': 2,
        'listening': true,
      });
      expect(r.kind, 'trigger');
      expect(r.trailing, isNotNull);
    });

    test('blockHitRow: per-hit kind + entityId is the nav target', () {
      final r = blockHitRow({
        'ref': 'hd_9.charge',
        'kind': 'handler',
        'entityId': 'hd_9',
        'name': 'charge',
      });
      expect(r.kind, 'handler'); // per-hit kind, not a fixed one
      expect(r.id, 'hd_9'); // entityId, not ref
    });

    test('attachmentListRow: inert (no panel) + human size', () {
      final r = attachmentListRow({
        'id': 'att_1',
        'filename': 'q3.pdf',
        'mime': 'application/pdf',
        'sizeBytes': 48210,
      });
      expect(r.kind, 'attachment'); // no panel → ToolHitList renders it inert
      expect(r.title, 'q3.pdf');
      expect(r.subtitle, contains('KB'));
    });
  });
}
