import 'package:anselm/core/design/theme.dart';
import 'package:anselm/dev/gallery/sidebar_poc.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Slice-2 POC v2 gate — DYNAMIC ANCESTOR STICKY (VS Code sticky-scroll) over a self-flattened list:
//   ① the flat + overlay combo builds; section heads + rows render; the top section pins in the overlay
//   ② VIRTUALIZATION — the 5000-row section never builds its far-off-screen tail
//   ③ folding a section head hides its rows (instant, MVP — the tween is the next step)
//   ④ the killer: scrolling INTO a deep tree pins the FULL ancestor chain (Documents › src › ui) in the
//      overlay — one mechanism serves flat sections (entities/chat) AND deep trees (documents)
//
// 切片 2 POC v2 gate:动态祖先吸顶(VS Code sticky-scroll)于自展平列表:①组合 build+段头/行+顶段吸顶 ②虚拟化
// ③段头折叠隐藏其行(瞬时 MVP)④核心:滚进深树,overlay 吸顶整条祖先链 Documents › src › ui(扁平与深树一套机制)。

Widget _host({double height = 480}) => ProviderScope(
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 600, height: height, child: const SidebarVirtualPoc()),
            ),
          ),
        ),
      ),
    );

Finder get _scrollable => find.byType(Scrollable).first;
Finder _inSticky(String text) =>
    find.descendant(of: find.byKey(const Key('poc-sticky-overlay')), matching: find.text(text));

void main() {
  testWidgets('① flat+overlay builds — section heads + rows render, top section pinned in the overlay', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Functions'), findsWidgets); // section head (in list + pinned overlay)
    expect(find.text('function-0'), findsOneWidget); // a row under it
    expect(find.text('normalize-input'), findsOneWidget); // a Pinned-section row
    expect(_inSticky('Functions'), findsOneWidget); // the top section is pinned in the overlay
  });

  testWidgets('② virtualizes — the 5000-row section never builds its far-off-screen tail', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.text('entity-4999'), findsNothing);
  });

  testWidgets('③ folding a section head hides its rows (instant MVP)', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    expect(find.text('function-0'), findsOneWidget);
    await tester.tap(_inSticky('Functions')); // tap the pinned Functions head
    await tester.pump();
    expect(find.text('function-0'), findsNothing); // whole section folded
  });

  testWidgets('④ DYNAMIC ANCESTOR STICKY — scrolling into a deep tree pins the full ancestor chain', (tester) async {
    await tester.pumpWidget(_host());
    await tester.pump();
    // Scroll down into Documents › src › ui (rows widget_*.dart at flat index ~13+).
    await tester.drag(_scrollable, const Offset(0, -420));
    await tester.pump();
    // The overlay now pins the WHOLE ancestor chain of the top-most visible row.
    expect(_inSticky('Documents'), findsOneWidget);
    expect(_inSticky('src'), findsOneWidget);
    expect(_inSticky('ui'), findsOneWidget);
  });
}
