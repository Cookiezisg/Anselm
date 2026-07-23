import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/features/entities/ui/run/block_tree_view.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// BlockTreeView — the run terminal's agent-trace projection with the revision-keyed identity cache
// (S6): a root whose subtree revision is unchanged returns the IDENTICAL widget instance, which
// short-circuits its element rebuild; only the streaming root rebuilds per frame.

BlockNode _node(String id, BlockKind kind, String text, {int rev = 0}) {
  final n = BlockNode(id: id, kind: kind)
    ..content = {'content': text}
    ..status = 'completed'
    ..revision = rev;
  return n;
}

Widget _host(List<BlockNode> roots) => TranslationProvider(
  child: MaterialApp(
    theme: AnTheme.light(),
    home: Scaffold(body: BlockTreeView(roots: roots)),
  ),
);

void main() {
  testWidgets(
    'unchanged-revision roots keep their identical widget across frames; a bumped root rebuilds',
    (tester) async {
      final settled = _node('b1', BlockKind.text, 'settled text');
      final live = _node('b2', BlockKind.text, 'streaming…')..status = 'open';
      final roots = [settled, live];

      await tester.pumpWidget(_host(roots));
      Padding rootWidgetOf(String id) =>
          tester.widget<Padding>(find.byKey(ValueKey(id), skipOffstage: false));
      final settledBefore = rootWidgetOf('b1');
      final liveBefore = rootWidgetOf('b2');

      // A coalesced frame touches ONLY the live root (the reducer bumps its revision in place).
      live
        ..content = {'content': 'streaming… more'}
        ..revision += 1;
      await tester.pumpWidget(_host(roots));

      expect(
        identical(rootWidgetOf('b1'), settledBefore),
        isTrue,
        reason:
            'settled root: identical instance → element rebuild short-circuited',
      );
      expect(
        identical(rootWidgetOf('b2'), liveBefore),
        isFalse,
        reason: 'bumped root: fresh instance → rebuilt',
      );
      expect(find.text('streaming… more'), findsOneWidget);
    },
  );

  testWidgets(
    'a closed tool_call still refreshes when a nested child arrives (revision, not isOpen, is the key)',
    (tester) async {
      final call = BlockNode(id: 'c1', kind: BlockKind.toolCall)
        ..content = {'name': 'fn_greet', 'arguments': '{}'}
        ..status = 'completed'
        ..revision = 3;
      final roots = [call];
      await tester.pumpWidget(_host(roots));
      expect(find.text('resulting!'), findsNothing);

      // The nested tool_result lands AFTER the call closed — subtree semantics bump the root.
      call.children.add(_node('r1', BlockKind.toolResult, 'resulting!'));
      call.revision += 1;
      await tester.pumpWidget(_host(roots));
      expect(find.text('resulting!'), findsOneWidget);
    },
  );

  testWidgets('the collapse toggle State survives a revision rebuild', (
    tester,
  ) async {
    final call = BlockNode(id: 'c1', kind: BlockKind.toolCall)
      ..content = {'name': 'fn_greet', 'arguments': '{"x":1}'}
      ..status = 'completed'
      ..revision = 0;
    final roots = [call];
    await tester.pumpWidget(_host(roots));
    // tool_call starts collapsed — open it by tapping the disclosure head. 默认收起,点开。
    expect(find.text('{"x":1}'), findsNothing);
    await tester.tap(find.text('fn_greet'));
    await tester.pumpAndSettle();
    expect(find.text('{"x":1}'), findsOneWidget);

    // A revision bump swaps the widget instance; the element (and its _open State) must carry over.
    call.revision += 1;
    await tester.pumpWidget(_host(roots));
    await tester.pumpAndSettle();
    expect(find.text('{"x":1}'), findsOneWidget); // still open 仍展开
  });

  testWidgets('an emptied tree clears the cache (a fresh run reuses nothing)', (
    tester,
  ) async {
    final roots = [_node('b1', BlockKind.text, 'old run')];
    await tester.pumpWidget(_host(roots));
    expect(find.text('old run'), findsOneWidget);

    await tester.pumpWidget(_host(const []));
    // Same id, same revision, DIFFERENT run — a stale cache would resurrect 'old run'.
    await tester.pumpWidget(_host([_node('b1', BlockKind.text, 'new run')]));
    expect(find.text('new run'), findsOneWidget);
    expect(find.text('old run'), findsNothing);
  });
}
