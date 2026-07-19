import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_island.dart';
import 'package:anselm/core/ui/an_menu.dart';
import 'package:anselm/core/ui/an_panel_head.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnPanelHead (三段式文法 §1, 0719) — the right-island identity head: icon + title + a SINGLE ⋯ overflow that
// collects every panel action + a first-class ✕, AT MOST two trailing buttons; an optional glance sub-band.
// 身份头:icon+标题 + 单 ⋯ 收编 + ✕(至多两钮)+ 可选速览带。

void main() {
  Widget host(Widget child) => TranslationProvider(
        child: MaterialApp(
          theme: AnTheme.light(),
          home: Scaffold(
            body: Center(child: SizedBox(width: 320, height: 480, child: AnIsland(child: child))),
          ),
        ),
      );

  testWidgets('renders the icon + title; ⋯ opens the menu; ✕ fires onClose', (tester) async {
    var closed = 0;
    var picked = 0;
    await tester.pumpWidget(host(AnPanelHead(
      icon: AnIcons.activity,
      title: 'Activity',
      menuSemanticLabel: 'More',
      menuEntries: [
        const AnMenuSection('Auto-staging'),
        AnMenuItem(label: 'Expand all', icon: AnIcons.unfold, onTap: () => picked++),
      ],
      onClose: () => closed++,
      closeSemantics: 'Close',
    )));
    await tester.pump();

    expect(find.text('Activity'), findsOneWidget);
    expect(find.byIcon(AnIcons.activity), findsOneWidget); // the identity glyph 身份字形

    // ✕ collapses the island (tested first — clean state, no popover barrier). ✕ 收岛(先测,无弹层遮罩)。
    await tester.tap(find.byIcon(AnIcons.close));
    await tester.pump();
    expect(closed, 1);

    // The ⋯ overflow opens the panel menu (every panel action lives here). ⋯ 开菜单。
    await tester.tap(find.byIcon(AnIcons.more));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Expand all'), findsOneWidget);
    await tester.tap(find.text('Expand all'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(picked, 1);
  });

  testWidgets('empty menuEntries → no ⋯ button (only ✕)', (tester) async {
    await tester.pumpWidget(host(AnPanelHead(
      icon: AnIcons.workflow,
      title: 'Inspector',
      onClose: () {},
      closeSemantics: 'Close',
    )));
    await tester.pump();
    expect(find.byIcon(AnIcons.more), findsNothing); // no overflow when there are no panel actions 无动作则无 ⋯
    expect(find.byIcon(AnIcons.close), findsOneWidget);
  });

  testWidgets('sub band renders when provided; absent when null (零人话律)', (tester) async {
    await tester.pumpWidget(host(AnPanelHead(
      icon: AnIcons.activity,
      title: 'Activity',
      sub: const Text('12 · 3 · 1', key: ValueKey('glance')),
    )));
    await tester.pump();
    expect(find.byKey(const ValueKey('glance')), findsOneWidget);

    await tester.pumpWidget(host(AnPanelHead(icon: AnIcons.activity, title: 'Activity')));
    await tester.pump();
    expect(find.byKey(const ValueKey('glance')), findsNothing);
  });

  testWidgets('geometry lock: icon lands at island + 12 (right-island single-source law)', (tester) async {
    await tester.pumpWidget(host(AnPanelHead(icon: AnIcons.activity, title: 'PROBE')));
    await tester.pump();
    final islandLeft = tester.getRect(find.byType(AnIsland)).left;
    final iconLeft = tester.getTopLeft(find.byIcon(AnIcons.activity)).dx;
    // The head adds NO leading pad — the island's 12px is the sole inset (same law as AnInspectorHead). 头前导 0。
    expect(iconLeft - islandLeft, moreOrLessEquals(AnSpace.s12, epsilon: 1),
        reason: 'panel-head icon flush with the island pad edge (single-source law)');
  });
}
