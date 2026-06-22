import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Interaction tests for the three-island shell — the "bug-free" guard for collapse,
/// drag-resize, persistence, and the right-island toggle.
/// 三岛 shell 交互测试——收起/拖拽调宽/持久化/右岛开合 的 bug-free 守卫。
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget harness() => MaterialApp(
        theme: AnTheme.light(),
        home: AnShell(
          framed: false,
          sidebarBuilder: (onCollapse) => AnSidebar(
            workspaceName: 'WS',
            nav: const [AnSidebarNav(icon: AnIcons.chat, label: 'Chat')],
            selectedIndex: 0,
            onCollapse: onCollapse,
            body: const SizedBox.shrink(),
          ),
          oceanBuilder: (scroll) => AnPage(controller: scroll, child: const Text('ocean')),
          rightIsland: const AnRightIsland(title: 'Inspector', child: Text('right')),
        ),
      );

  double widthOf(WidgetTester t, String key) =>
      t.getSize(find.byKey(ValueKey(key))).width;

  // A realistic desktop surface so wide sidebar + right island fit (the ocean flexes).
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
  }

  testWidgets('left island collapses and reopens', (tester) async {
    await pump(tester);
    expect(widthOf(tester, 'anShellLeft'), AnSize.sidebar);
    expect(find.byKey(const ValueKey('anShellGrip')), findsOneWidget);

    // collapse via the sidebar's collapse button (only one collapseLeft icon while expanded)
    await tester.tap(find.byIcon(AnIcons.collapseLeft));
    await tester.pumpAndSettle();
    expect(widthOf(tester, 'anShellLeft'), 0);
    expect(find.byKey(const ValueKey('anShellGrip')), findsNothing);

    // reopen via the button that surfaced in the ocean header (the last collapseLeft)
    await tester.tap(find.byIcon(AnIcons.collapseLeft).last);
    await tester.pumpAndSettle();
    expect(widthOf(tester, 'anShellLeft'), AnSize.sidebar);
  });

  testWidgets('drag grip resizes within bounds', (tester) async {
    await pump(tester);

    await tester.drag(find.byKey(const ValueKey('anShellGrip')), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(widthOf(tester, 'anShellLeft'), AnSize.sidebar + 60);

    // clamp at the maximum
    await tester.drag(find.byKey(const ValueKey('anShellGrip')), const Offset(999, 0));
    await tester.pumpAndSettle();
    expect(widthOf(tester, 'anShellLeft'), AnSize.sidebarMax);

    // clamp at the minimum
    await tester.drag(find.byKey(const ValueKey('anShellGrip')), const Offset(-999, 0));
    await tester.pumpAndSettle();
    expect(widthOf(tester, 'anShellLeft'), AnSize.sidebarMin);
  });

  testWidgets('right island toggles open/closed', (tester) async {
    await pump(tester);
    const open = AnSize.rightIsland + AnSpace.s8;
    expect(widthOf(tester, 'anShellRight'), open);

    await tester.tap(find.byIcon(AnIcons.collapseRight));
    await tester.pumpAndSettle();
    expect(widthOf(tester, 'anShellRight'), 0);

    await tester.tap(find.byIcon(AnIcons.collapseRight));
    await tester.pumpAndSettle();
    expect(widthOf(tester, 'anShellRight'), open);
  });

  testWidgets('collapse state persists across a remount', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(AnIcons.collapseLeft));
    await tester.pumpAndSettle();
    expect(widthOf(tester, 'anShellLeft'), 0);

    // remount a fresh shell → it should load the persisted collapsed state
    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    expect(widthOf(tester, 'anShellLeft'), 0);
  });
}
