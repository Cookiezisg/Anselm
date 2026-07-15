import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/platform/host_platform.dart';
import 'package:anselm/core/platform/window_fullscreen.dart';
import 'package:anselm/core/ui/an_brand_icon.dart';
import 'package:anselm/core/ui/an_island.dart';
import 'package:anselm/core/ui/an_shell.dart';
import 'package:anselm/core/ui/an_window_controls.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Skeleton guards for the three-island shell: a draggable left island (240–400, default 320) +
/// a USER-DRAGGABLE right island (280–640, default 320, live-clamped so the ocean keeps its floor) +
/// the open ocean. 三岛 shell 骨架守卫:左岛可拖(240–400 默认 320)+ 右岛可拖(280–640 默认 320,
/// 实时钳制保海洋下限)+ 敞开海洋。
void main() {
  // AnShell now reads context.t for the panel-button labels → wrap in TranslationProvider. 套件读 i18n。
  Widget wrap(Widget shell) => TranslationProvider(child: MaterialApp(theme: AnTheme.light(), home: shell));
  Widget harness() => wrap(const AnShell());

  testWidgets('renders left(default 320, draggable) + right(default 320, draggable) islands + ocean',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    await tester.pump();

    expect(find.byType(AnIsland), findsNWidgets(2));
    expect(tester.getSize(find.byType(AnIsland).first).width, AnSize.sidebar); // left default 320
    expect(tester.getSize(find.byType(AnIsland).last).width, AnSize.rightIsland); // right default 320
    expect(find.text('Sidebar'), findsOneWidget);
    expect(find.text('Ocean'), findsOneWidget);
    expect(find.text('Inspector'), findsOneWidget);
  });

  testWidgets('the ocean switcher sits one chrome-bar below the island top — no redundant spacer (B11)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const AnShell(sidebar: SizedBox.expand(key: ValueKey('sidebarProbe')))));
    await tester.pump();

    final islandTop = tester.getRect(find.byType(AnIsland).first).top;
    final sidebarTop = tester.getRect(find.byKey(const ValueKey('sidebarProbe'))).top;
    // The sidebar (→ the ocean switcher) starts exactly ONE chrome-bar height below the island top
    // (islandHead 44), NOT islandHead + s8: the chrome bar's own ~12px slack below its controls is the gap,
    // so the extra s8 spacer (which made the gap ~20px, «太大») was dropped. 顶距=1 个 chrome 带高、非 +s8。
    expect(sidebarTop - islandTop, closeTo(AnSize.islandHead, 3));
  });

  testWidgets('left island drags within [min, max]; the right island does not move with it', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.pump();

    await tester.drag(find.byKey(const ValueKey('anShellLeftGrip')), const Offset(60, 0));
    await tester.pump();
    expect(tester.getSize(find.byType(AnIsland).first).width, AnSize.sidebar + 60); // 380
    expect(tester.getSize(find.byType(AnIsland).last).width, AnSize.rightIsland); // right unchanged

    await tester.drag(find.byKey(const ValueKey('anShellLeftGrip')), const Offset(999, 0));
    await tester.pump();
    expect(tester.getSize(find.byType(AnIsland).first).width, AnSize.sidebarMax); // clamped 400
  });

  testWidgets('right island drags leftward to widen, clamped to the OCEAN-FLOOR ceiling and to min',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final committed = <double>[];
    await tester.pumpWidget(wrap(AnShell(onRightWidthCommitted: committed.add)));
    await tester.pump();

    // Dragging LEFT widens (the grip sits on the island's leading gap). 向左拖=加宽。
    await tester.drag(find.byKey(const ValueKey('anShellRightGrip')), const Offset(-60, 0));
    await tester.pump();
    expect(tester.getSize(find.byType(AnIsland).last).width, AnSize.rightIsland + 60); // 380
    expect(committed.single, AnSize.rightIsland + 60);

    // A huge widen clamps to the DYNAMIC ceiling: window 1400 − pad(16) − left(320+8) − oceanMin(480)
    // − gap(8) = 568 (below rightIslandMax 640 — the ocean's floor wins). 动态上限:海洋保底优先。
    await tester.drag(find.byKey(const ValueKey('anShellRightGrip')), const Offset(-999, 0));
    await tester.pump();
    expect(tester.getSize(find.byType(AnIsland).last).width, 568);

    // And a huge narrow clamps to min. 收窄钳到最小。
    await tester.drag(find.byKey(const ValueKey('anShellRightGrip')), const Offset(999, 0));
    await tester.pump();
    expect(tester.getSize(find.byType(AnIsland).last).width, AnSize.rightIslandMin);
  });

  testWidgets('inspectorOpen reveals/hides the right island; the ocean reclaims its width',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<double> oceanWidth({required bool open}) async {
      await tester.pumpWidget(wrap(
        AnShell(
          ocean: const SizedBox.expand(key: ValueKey('oceanProbe')),
          inspectorOpen: open,
        ),
      ));
      await tester.pumpAndSettle(); // let the reveal animation finish 让揭示动画走完
      return tester.getSize(find.byKey(const ValueKey('oceanProbe'))).width;
    }

    final openW = await oceanWidth(open: true);
    final closedW = await oceanWidth(open: false);
    // Hiding the right island hands the ocean exactly the island + its gap (it slides out, no reflow).
    // 收起右岛 → 海洋正好多得岛宽 + 间距(滑出、不重排)。
    expect(closedW, greaterThan(openW));
    expect(closedW - openW, closeTo(AnSize.rightIsland + AnSize.shellGap, 0.5));
  });

  testWidgets('collapsed right island is inert — its content leaves the semantics tree (no focus trap)',
      (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget shell(bool open) => wrap(
          AnShell(
            inspector: const Text('inspector body', semanticsLabel: 'inspectorProbe'),
            inspectorOpen: open,
          ),
        );

    await tester.pumpWidget(shell(true));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('inspectorProbe'), findsOneWidget); // open → announced

    // Mid-close: the island is STILL painted (sliding out, content held full-width behind the clip) — the
    // ExcludeFocus/ExcludeSemantics wrapper must keep it inert NOW (this is the transient the wrapper guards;
    // once fully closed the subtree is dropped entirely). 滑出中仍绘制,惰化包裹须此刻生效。
    await tester.pumpWidget(shell(false));
    await tester.pump(const Duration(milliseconds: 120)); // partway through the slide-out 滑出途中
    expect(find.bySemanticsLabel('inspectorProbe'), findsNothing, reason: 'sliding-out content excluded from semantics');

    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('inspectorProbe'), findsNothing, reason: 'fully closed → subtree removed (SizedBox.shrink)');
    handle.dispose();
  });

  testWidgets('the open right island shadow is intact + matches the left (not cut by a clip)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness()); // inspectorOpen defaults true
    await tester.pumpAndSettle();

    // Both islands are the SAME AnIsland primitive → identical shadowFloat (one source). 同一原语=阴影同源。
    expect(find.byType(AnIsland), findsNWidgets(2));
    // The open right island's reveal clip uses a NO-OP clipper, so the float shadow paints past the bounds
    // (unlike the old always-on ClipRect that cut it into a pointy dead corner). 敞开态用空裁切器,阴影不被裁。
    final clip = tester.widget<ClipRect>(
      find.ancestor(of: find.byType(AnIsland).last, matching: find.byType(ClipRect)),
    );
    expect(clip.clipper, isNotNull, reason: 'open island → no-op clipper → shadow not clipped (matches the left island)');
  });

  testWidgets('collapsed left → island slides away + a reopen button appears in the ocean head', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(wrap(AnShell(onToggleLeft: () {}, leftCollapsed: true)));
    await tester.pumpAndSettle();
    expect(find.byType(AnIsland), findsOneWidget); // only the right island remains 左岛已滑走
    expect(find.byIcon(AnIcons.panelLeft), findsOneWidget); // the reopen button, now in the floating head
  });

  testWidgets('panel-right toggle shows only when onToggleRight is given, and fires', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness()); // no onToggleRight → no panel-right
    await tester.pumpAndSettle();
    expect(find.byIcon(AnIcons.panelRight), findsNothing);

    var toggled = false;
    await tester.pumpWidget(wrap(AnShell(onToggleRight: () => toggled = true)));
    await tester.pumpAndSettle();
    expect(find.byIcon(AnIcons.panelRight), findsOneWidget);
    await tester.tap(find.byIcon(AnIcons.panelRight));
    expect(toggled, isTrue);
  });

  // --- fullscreen chrome collapse (the white-band bug) --------------------
  // In native macOS fullscreen the OS hides the traffic lights + taller title bar, so the shell must
  // collapse the reservations it makes FOR those lights: the vertical band (titlebarHeight → 0) and the
  // horizontal lights gutter (AnWindowControls → 0). Left un-collapsed they read as a blank strip.

  testWidgets('titlebarHeight drives the chrome-control top inset (smaller band → controls sit higher)',
      (tester) async {
    // The raw band mechanic. NOTE: AppShell now passes AnSize.titlebar in BOTH windowed and fullscreen
    // (#10 fix — fullscreen no longer collapses the band to 0, which pinned the controls cramped to the
    // screen top); this test still pins the widget-level contract that a smaller band lifts the controls.
    // 带高机制:AppShell 现全屏也传 titlebar(#10 修:不再收 0 贴顶);此测仍钉「小带→顶控上移」的 widget 契约。
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Future<double> collapseButtonTop(double titlebarHeight) async {
      await tester.pumpWidget(wrap(AnShell(onToggleLeft: () {}, titlebarHeight: titlebarHeight)));
      await tester.pumpAndSettle();
      return tester.getTopLeft(find.byIcon(AnIcons.panelLeft)).dy;
    }

    final full = await collapseButtonTop(AnSize.titlebar); // the value AppShell now uses everywhere
    final collapsed = await collapseButtonTop(0); // a zero band would pin higher (no longer used by AppShell)
    expect(collapsed, lessThan(full),
        reason: 'a 0 band collapses the centering inset; AnSize.titlebar keeps the comfortable top gap');
  });

  testWidgets('AnWindowControls(showBrand): windowed reserves the lights gutter; fullscreen shows brand + name (#10)',
      (tester) async {
    if (!HostPlatform.isMacOS) return; // the reserve↔brand swap is macOS-only; elsewhere it's always the brand
    addTearDown(() => WindowFullScreen.active.value = false);

    Future<void> pump(bool fullScreen) async {
      WindowFullScreen.active.value = fullScreen;
      await tester.pumpWidget(wrap(const Center(child: AnWindowControls(showBrand: true))));
      await tester.pumpAndSettle();
    }

    // Windowed → reserve 72 for the OS traffic lights; no brand drawn (the OS draws the real lights).
    await pump(false);
    expect(tester.getSize(find.byType(AnWindowControls)).width, AnSize.windowControlsInset);
    expect(find.byType(AnBrandIcon), findsNothing);

    // Fullscreen → the OS hides the lights, so the freed spot carries the product mark + name (like Windows).
    // 全屏:OS 藏灯 → 空位放产品标+名(像 Windows)。
    await pump(true);
    expect(find.byType(AnBrandIcon), findsOneWidget);
    expect(find.text('Anselm'), findsOneWidget);
  });

  testWidgets('AnWindowControls default (showBrand off): reserves the gutter windowed, draws NO brand in fullscreen',
      (tester) async {
    // The brand belongs to the left island ONLY (拍板). The collapsed-island reopen zone + the workflow
    // editor reserve the lights gutter but must NEVER surface the mark/name — even in fullscreen, where a
    // showBrand-on zone would. 品牌只属左岛;reopen 区/编辑器留灯位但绝不冒出标+名,即便全屏。
    if (!HostPlatform.isMacOS) return;
    addTearDown(() => WindowFullScreen.active.value = false);

    Future<void> pump(bool fullScreen) async {
      WindowFullScreen.active.value = fullScreen;
      await tester.pumpWidget(wrap(const Center(child: AnWindowControls())));
      await tester.pumpAndSettle();
    }

    // Windowed → still reserve the 72 lights gutter (the OS draws real lights here regardless of brand).
    await pump(false);
    expect(tester.getSize(find.byType(AnWindowControls)).width, AnSize.windowControlsInset);
    expect(find.byType(AnBrandIcon), findsNothing);

    // Fullscreen → NO lights, NO brand: the zone collapses to nothing (reopen/back rides the edge).
    await pump(true);
    expect(find.byType(AnBrandIcon), findsNothing);
    expect(find.text('Anselm'), findsNothing);
    expect(tester.getSize(find.byType(AnWindowControls)).width, 0);
  });

  test('minimum window keeps the ocean ≥ its min column even with the left island at max', () {
    // The right term is rightIslandMIN: at the window minimum the user can always narrow the right
    // island to fit (its live drag ceiling squeezes wider values honestly). 右项取右岛最小:最小窗下
    // 用户总能把右岛收窄适配(更宽值被动态上限如实压缩)。
    expect(
      AnSize.windowMinWidth,
      AnSize.shellPad +
          AnSize.sidebarMax +
          AnSize.shellGap +
          AnSize.oceanMin +
          AnSize.shellGap +
          AnSize.rightIslandMin +
          AnSize.shellPad,
    );
    // Worst case: left at MAX + right at its MIN → the ocean at the minimum window is exactly
    // oceanMin (a wider right island is squeezed by the live drag ceiling, never the ocean).
    // 最坏情形:左最大+右最小 → 最小窗下海洋恰为 oceanMin(右岛更宽被动态上限压,海洋不受挤)。
    final oceanWorstCase = AnSize.windowMinWidth -
        2 * AnSize.shellPad -
        AnSize.sidebarMax -
        2 * AnSize.shellGap -
        AnSize.rightIslandMin;
    expect(oceanWorstCase, greaterThanOrEqualTo(AnSize.oceanMin));
    expect(AnSize.windowMinHeight, closeTo(AnSize.windowMinWidth / AnSize.goldenRatio, 0.01));
    expect(AnSize.windowMinWidth, lessThan(1512)); // fits a scaled 14" MacBook with margin 留余量
  });
}
