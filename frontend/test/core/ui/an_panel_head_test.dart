import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_island.dart';
import 'package:anselm/core/ui/an_ledger_row.dart';
import 'package:anselm/core/ui/an_menu.dart';
import 'package:anselm/core/ui/an_panel_head.dart';
import 'package:anselm/core/ui/an_row.dart';
import 'package:anselm/core/ui/an_status_dot.dart';
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

  // RIGHT-EDGE geometry lock (0720 — the「✕ 离右缘空太多」bug): the head added a trailing s8 on TOP of the
  // island's s12, so the ✕ BOX sat at island+8 (glyph 26 from the outer edge) — 8px further inboard than the
  // left island's chrome-bar button and off the row-family iron line. The trailing button box must sit FLUSH
  // at the island content edge (head adds ZERO horizontal pad, both edges), and the ✕ glyph must land ~on the
  // meta iron line (island + 12 + 8), just like every ledger row below it. 右缘几何锁:尾钮盒齐平岛内容缘、
  // ✕ 字形落 meta 右缘铁线附近。
  testWidgets('right-edge lock: trailing ✕/⋯ box flush at island edge; ✕ glyph on the meta iron line',
      (tester) async {
    await tester.pumpWidget(host(Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnPanelHead(
          icon: AnIcons.activity,
          title: 'PROBE',
          menuSemanticLabel: 'More',
          menuEntries: [AnMenuItem(label: 'x', onTap: () {})],
          onClose: () {},
          closeSemantics: 'Close',
        ),
        AnRow(icon: AnIcons.chat, label: 'row', meta: 'Ran ×2'),
        const AnLedgerRow(lead: AnStatusDot(AnStatus.done), primary: 'node', meta: '×2'),
      ],
    )));
    await tester.pump();

    final islandRight = tester.getRect(find.byType(AnIsland)).right;
    double insetOf(Finder f) => islandRight - tester.getRect(f).right;
    final closeBox = find.ancestor(of: find.byIcon(AnIcons.close), matching: find.byType(AnButton));
    final moreBox = find.ancestor(of: find.byIcon(AnIcons.more), matching: find.byType(AnButton));

    // (a) the trailing ✕ button BOX sits flush at the island content edge — the head adds NO trailing pad
    // (single-source: island 12 is the sole horizontal inset). A re-added s8 would push this to 20 → fails.
    expect(insetOf(closeBox), moreOrLessEquals(AnSpace.s12, epsilon: 1),
        reason: '✕ button box flush at the island content edge (no head trailing pad)');

    // (b) the row + ledger meta both land on the iron line = island 12 + row-family s8 (right 缘铁线).
    const ironLine = AnSpace.s12 + AnSpace.s8;
    expect(insetOf(find.text('Ran ×2')), moreOrLessEquals(ironLine, epsilon: 1.5),
        reason: 'AnRow meta on the iron line (island + 20)');
    expect(insetOf(find.text('×2')), moreOrLessEquals(ironLine, epsilon: 1.5),
        reason: 'AnLedgerRow meta on the iron line (island + 20)');

    // (c) the ✕ GLYPH lands ~on that same iron line (icon 6px inboard of its md box → island 12 + 6 = 18,
    // 2px inside the 20 iron line — 1:1 the left island chrome button vs rail meta). The old 26 (6px PAST
    // the line) is what read「离右缘空太多」. 字形落铁线附近,与下方 meta 同一竖线感。
    final glyphInset = islandRight - tester.getRect(find.byIcon(AnIcons.close)).right;
    expect((glyphInset - ironLine).abs(), lessThanOrEqualTo(3),
        reason: '✕ glyph within 3px of the meta iron line (was 6px inboard of it)');

    // (d) ⋯ rides just left of ✕ (one md-box step) — never the old 8px-further-inboard cluster. ⋯ 紧邻 ✕ 左。
    expect(insetOf(moreBox), moreOrLessEquals(AnSpace.s12 + AnSize.control, epsilon: 1),
        reason: '⋯ box one control-width left of the flush ✕ box');
  });
}
