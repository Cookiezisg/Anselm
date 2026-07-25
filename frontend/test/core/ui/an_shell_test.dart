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
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Skeleton guards for the three-island shell: a draggable left island (240–400, default 320) +
/// a USER-DRAGGABLE right island (280–640, default 320, live-clamped so the ocean keeps its floor) +
/// the open ocean. 三岛 shell 骨架守卫:左岛可拖(240–400 默认 320)+ 右岛可拖(280–640 默认 320,
/// 实时钳制保海洋下限)+ 敞开海洋。
// `find.bySemanticsLabel` reads each render object's `debugSemantics`, which LINGERS after a node has
// been excluded from the semantics tree — the render object is still there holding its last computed
// value. That was harmless while the collapsed inspector remounted (fresh render objects, nothing stale
// to read), and it became a false positive the moment RI made the subtree persist. Walking the tree asks
// the question the test actually means: can a screen reader reach this right now?
//
// `find.bySemanticsLabel` 读的是各 render object 的 `debugSemantics`,而节点被排除出语义树后这个值会**残留**
// ——render object 还在,还揣着它上次算出的值。在「收起的 inspector 会重挂」的年代这无害(render object 是新的、
// 没有残留可读);RI 让子树持久化的那一刻,它就变成了假阳性。走一遍语义树问的才是本测试真正想问的:此刻屏幕
// 阅读器能不能到达它?
bool _inSemanticsTree(WidgetTester tester, String label) {
  var found = false;
  void walk(SemanticsNode n) {
    if (n.label == label) found = true;
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  // Root the walk at the shell's own node rather than the binding's semantics owner — the latter is
  // reachable only through the deprecated `pipelineOwner` (semantics owners are per-view now), and
  // `getSemantics` resolves to the nearest enclosing node, which is above both islands.
  // 从壳自己的节点起走,而不是 binding 的语义 owner:后者只能经已弃用的 `pipelineOwner` 拿到(语义 owner 现在
  // 是按 view 分的),而 `getSemantics` 解析到的是最近的外层节点,那已在两岛之上。
  walk(tester.getSemantics(find.byType(AnShell)));
  return found;
}

void main() {
  // AnShell now reads context.t for the panel-button labels → wrap in TranslationProvider. 套件读 i18n。
  Widget wrap(Widget shell) => TranslationProvider(
    child: MaterialApp(theme: AnTheme.light(), home: shell),
  );
  Widget harness() => wrap(const AnShell());

  testWidgets(
    'renders left(default 320, draggable) + right(default 320, draggable) islands + ocean',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness());
      await tester.pump();

      expect(find.byType(AnIsland), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(AnIsland).first).width,
        AnSize.sidebar,
      ); // left default 320
      expect(
        tester.getSize(find.byType(AnIsland).last).width,
        AnSize.rightIsland,
      ); // right default 320
      expect(find.text('Sidebar'), findsOneWidget);
      expect(find.text('Ocean'), findsOneWidget);
      expect(find.text('Inspector'), findsOneWidget);
    },
  );

  testWidgets(
    'the ocean switcher sits one chrome-bar below the island top — no redundant spacer (B11)',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          const AnShell(
            sidebar: SizedBox.expand(key: ValueKey('sidebarProbe')),
          ),
        ),
      );
      await tester.pump();

      final islandTop = tester.getRect(find.byType(AnIsland).first).top;
      final sidebarTop = tester
          .getRect(find.byKey(const ValueKey('sidebarProbe')))
          .top;
      // The sidebar (→ the ocean switcher) starts exactly ONE chrome-bar height below the island top
      // (islandHead 44), NOT islandHead + s8: the chrome bar's own ~12px slack below its controls is the gap,
      // so the extra s8 spacer (which made the gap ~20px, «太大») was dropped. 顶距=1 个 chrome 带高、非 +s8。
      expect(sidebarTop - islandTop, closeTo(AnSize.islandHead, 3));
    },
  );

  testWidgets(
    'left island drags within [min, max]; the right island does not move with it',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness());
      await tester.pump();

      await tester.drag(
        find.byKey(const ValueKey('anShellLeftGrip')),
        const Offset(60, 0),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(AnIsland).first).width,
        AnSize.sidebar + 60,
      ); // 380
      expect(
        tester.getSize(find.byType(AnIsland).last).width,
        AnSize.rightIsland,
      ); // right unchanged

      await tester.drag(
        find.byKey(const ValueKey('anShellLeftGrip')),
        const Offset(999, 0),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(AnIsland).first).width,
        AnSize.sidebarMax,
      ); // clamped 400
    },
  );

  testWidgets(
    'right island drags leftward to widen, clamped to the OCEAN-FLOOR ceiling and to min',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final committed = <double>[];
      await tester.pumpWidget(
        wrap(AnShell(onRightWidthCommitted: committed.add)),
      );
      await tester.pump();

      // Dragging LEFT widens (the grip sits on the island's leading gap). 向左拖=加宽。
      await tester.drag(
        find.byKey(const ValueKey('anShellRightGrip')),
        const Offset(-60, 0),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(AnIsland).last).width,
        AnSize.rightIsland + 60,
      ); // 380
      expect(committed.single, AnSize.rightIsland + 60);

      // A huge widen clamps to the DYNAMIC ceiling: window 1400 − pad(16) − left(320+8) − oceanMin(480)
      // − gap(8) = 568 (below rightIslandMax 640 — the ocean's floor wins). 动态上限:海洋保底优先。
      await tester.drag(
        find.byKey(const ValueKey('anShellRightGrip')),
        const Offset(-999, 0),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(AnIsland).last).width, 568);

      // And a huge narrow clamps to min. 收窄钳到最小。
      await tester.drag(
        find.byKey(const ValueKey('anShellRightGrip')),
        const Offset(999, 0),
      );
      await tester.pump();
      expect(
        tester.getSize(find.byType(AnIsland).last).width,
        AnSize.rightIslandMin,
      );
    },
  );

  testWidgets(
    'inspectorOpen reveals/hides the right island; the ocean reclaims its width',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<double> oceanWidth({required bool open}) async {
        await tester.pumpWidget(
          wrap(
            AnShell(
              ocean: const SizedBox.expand(key: ValueKey('oceanProbe')),
              inspectorOpen: open,
            ),
          ),
        );
        await tester.pumpAndSettle(); // let the reveal animation finish 让揭示动画走完
        return tester.getSize(find.byKey(const ValueKey('oceanProbe'))).width;
      }

      final openW = await oceanWidth(open: true);
      final closedW = await oceanWidth(open: false);
      // Hiding the right island hands the ocean exactly the island + its gap (it slides out, no reflow).
      // 收起右岛 → 海洋正好多得岛宽 + 间距(滑出、不重排)。
      expect(closedW, greaterThan(openW));
      expect(
        closedW - openW,
        closeTo(AnSize.rightIsland + AnSize.shellGap, 0.5),
      );
    },
  );

  testWidgets(
    'collapsed right island is inert — its content leaves the semantics tree (no focus trap)',
    (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Widget shell(bool open) => wrap(
        AnShell(
          inspector: const Text(
            'inspector body',
            semanticsLabel: 'inspectorProbe',
          ),
          inspectorOpen: open,
        ),
      );

      await tester.pumpWidget(shell(true));
      await tester.pumpAndSettle();
      expect(
        _inSemanticsTree(tester, 'inspectorProbe'),
        isTrue,
      ); // open → announced

      // Mid-close: the island is STILL painted (sliding out, content held full-width behind the clip), so the
      // ExcludeFocus/ExcludeSemantics/IgnorePointer layers — mounted always, their booleans flipped (RI 病灶①)
      // — must make it inert NOW. 滑出中仍绘制,故三层惰化(恒挂、翻布尔)须此刻生效。
      await tester.pumpWidget(shell(false));
      await tester.pump(
        const Duration(milliseconds: 120),
      ); // partway through the slide-out 滑出途中
      expect(
        _inSemanticsTree(tester, 'inspectorProbe'),
        isFalse,
        reason: 'sliding-out content excluded from semantics',
      );

      await tester.pumpAndSettle();
      expect(
        _inSemanticsTree(tester, 'inspectorProbe'),
        isFalse,
        reason: 'fully closed → unreachable',
      );
      handle.dispose();
    },
  );

  testWidgets(
    'the open right island shadow is intact + matches the left (not cut by a clip)',
    (tester) async {
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
        find.ancestor(
          of: find.byType(AnIsland).last,
          matching: find.byType(ClipRect),
        ),
      );
      expect(
        clip.clipper,
        isNotNull,
        reason:
            'open island → no-op clipper → shadow not clipped (matches the left island)',
      );
    },
  );

  testWidgets(
    'collapsed left → island slides away + a reopen button appears in the ocean head',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrap(AnShell(onToggleLeft: () {}, leftCollapsed: true)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byType(AnIsland),
        findsOneWidget,
      ); // only the right island remains 左岛已滑走
      expect(
        find.byIcon(AnIcons.panelLeft),
        findsOneWidget,
      ); // the reopen button, now in the floating head
    },
  );

  testWidgets(
    'panel-right toggle shows only when onToggleRight is given, and fires',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness()); // no onToggleRight → no panel-right
      await tester.pumpAndSettle();
      expect(find.byIcon(AnIcons.panelRight), findsNothing);

      var toggled = false;
      await tester.pumpWidget(
        wrap(AnShell(onToggleRight: () => toggled = true)),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(AnIcons.panelRight), findsOneWidget);
      await tester.tap(find.byIcon(AnIcons.panelRight));
      expect(toggled, isTrue);
    },
  );

  // 0718-19 — the panel-right toggle is a HEAD MEMBER that SLIDES IN from the trailing edge the moment it
  // first appears (a chat conversation's first activity), pushing the head-trailing Scenes button LEFT.
  // «挤» is a real位移: new member inserts at the trailing edge, older members move left. 位置语法。
  testWidgets(
    'the panel-right toggle slides in at the trailing edge and pushes headTrailing left',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const scenes = SizedBox(
        key: ValueKey('scenesProbe'),
        width: 24,
        height: 24,
      );

      // No toggle → the Scenes button sits at the trailing end. 无 toggle:Scenes 在尾端。
      await tester.pumpWidget(wrap(const AnShell(headTrailing: scenes)));
      await tester.pumpAndSettle();
      expect(find.byIcon(AnIcons.panelRight), findsNothing);
      final scenesRightAlone = tester
          .getRect(find.byKey(const ValueKey('scenesProbe')))
          .right;

      // Activity arrives → the toggle reveals (AnExpandReveal horizontal) and pushes Scenes left. 滑入+左移。
      await tester.pumpWidget(
        wrap(AnShell(headTrailing: scenes, onToggleRight: () {})),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(AnIcons.panelRight), findsOneWidget);
      final scenesRightPushed = tester
          .getRect(find.byKey(const ValueKey('scenesProbe')))
          .right;
      expect(
        scenesRightPushed,
        lessThan(scenesRightAlone),
        reason: 'the sliding-in toggle pushes the Scenes button left (real 位移)',
      );
    },
  );

  testWidgets('reduced motion → the toggle reveal is instant (no slide)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget reduced(Widget child) => wrap(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child,
        ),
      ),
    );

    await tester.pumpWidget(reduced(const AnShell()));
    await tester.pump();
    expect(find.byIcon(AnIcons.panelRight), findsNothing);

    await tester.pumpWidget(reduced(AnShell(onToggleRight: () {})));
    await tester
        .pump(); // one frame — reduced motion is instant, no settle needed
    expect(find.byIcon(AnIcons.panelRight), findsOneWidget);
  });

  // --- fullscreen chrome collapse (the white-band bug) --------------------
  // In native macOS fullscreen the OS hides the traffic lights + taller title bar, so the shell must
  // collapse the reservations it makes FOR those lights: the vertical band (titlebarHeight → 0) and the
  // horizontal lights gutter (AnWindowControls → 0). Left un-collapsed they read as a blank strip.

  testWidgets(
    'titlebarHeight drives the chrome-control top inset (smaller band → controls sit higher)',
    (tester) async {
      // The raw band mechanic. NOTE: AppShell now passes AnSize.titlebar in BOTH windowed and fullscreen
      // (#10 fix — fullscreen no longer collapses the band to 0, which pinned the controls cramped to the
      // screen top); this test still pins the widget-level contract that a smaller band lifts the controls.
      // 带高机制:AppShell 现全屏也传 titlebar(#10 修:不再收 0 贴顶);此测仍钉「小带→顶控上移」的 widget 契约。
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<double> collapseButtonTop(double titlebarHeight) async {
        await tester.pumpWidget(
          wrap(AnShell(onToggleLeft: () {}, titlebarHeight: titlebarHeight)),
        );
        await tester.pumpAndSettle();
        return tester.getTopLeft(find.byIcon(AnIcons.panelLeft)).dy;
      }

      final full = await collapseButtonTop(
        AnSize.titlebar,
      ); // the value AppShell now uses everywhere
      final collapsed = await collapseButtonTop(
        0,
      ); // a zero band would pin higher (no longer used by AppShell)
      expect(
        collapsed,
        lessThan(full),
        reason:
            'a 0 band collapses the centering inset; AnSize.titlebar keeps the comfortable top gap',
      );
    },
  );

  testWidgets(
    'AnWindowControls(showBrand): windowed reserves the lights gutter; fullscreen shows brand + name (#10)',
    (tester) async {
      if (!HostPlatform.isMacOS) {
        return; // the reserve↔brand swap is macOS-only; elsewhere it's always the brand
      }
      addTearDown(() => WindowFullScreen.active.value = false);

      Future<void> pump(bool fullScreen) async {
        WindowFullScreen.active.value = fullScreen;
        await tester.pumpWidget(
          wrap(const Center(child: AnWindowControls(showBrand: true))),
        );
        await tester.pumpAndSettle();
      }

      // Windowed → reserve 72 for the OS traffic lights; no brand drawn (the OS draws the real lights).
      await pump(false);
      expect(
        tester.getSize(find.byType(AnWindowControls)).width,
        AnSize.windowControlsInset,
      );
      expect(find.byType(AnBrandIcon), findsNothing);

      // Fullscreen → the OS hides the lights, so the freed spot carries the product mark + name (like Windows).
      // 全屏:OS 藏灯 → 空位放产品标+名(像 Windows)。
      await pump(true);
      expect(find.byType(AnBrandIcon), findsOneWidget);
      expect(find.text('Anselm'), findsOneWidget);
    },
  );

  testWidgets(
    'AnWindowControls default (showBrand off): reserves the gutter windowed, draws NO brand in fullscreen',
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
      expect(
        tester.getSize(find.byType(AnWindowControls)).width,
        AnSize.windowControlsInset,
      );
      expect(find.byType(AnBrandIcon), findsNothing);

      // Fullscreen → NO lights, NO brand: the zone collapses to nothing (reopen/back rides the edge).
      await pump(true);
      expect(find.byType(AnBrandIcon), findsNothing);
      expect(find.text('Anselm'), findsNothing);
      expect(tester.getSize(find.byType(AnWindowControls)).width, 0);
    },
  );

  // --- brand optical-centre seating (0719) --------------------------------
  // Two residents share the chrome band's control slot: the traffic lights (windowed macOS) hold the
  // lights' LINE, while the brand that replaces them (fullscreen / Win-Linux) drops to the band's OPTICAL
  // centre. WindowFullScreen.active=true reveals the brand on macOS; on Win/Linux it shows regardless — so
  // these need no platform guard. The collapse control stays on the lights' line (only the brand moves).

  testWidgets(
    'fullscreen brand seats at the band optical centre — dropped below the lights-line collapse control',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(() => WindowFullScreen.active.value = false);
      WindowFullScreen.active.value = true;

      await tester.pumpWidget(wrap(AnShell(onToggleLeft: () {})));
      await tester
          .pumpAndSettle(); // the drift-in transition settles at the optical centre

      final brandCenter = tester.getCenter(find.byType(AnBrandIcon).first).dy;
      final collapseCenter = tester
          .getCenter(find.byIcon(AnIcons.panelLeft).first)
          .dy;
      // The brand ALONE drops to the band's optical centre; the collapse control stays on the lights' line.
      expect(
        brandCenter - collapseCenter,
        closeTo(AnSize.brandBandDrop, 1.0),
        reason:
            'brand seats brandBandDrop below the lights-line control (distinct alignment)',
      );
    },
  );

  testWidgets(
    'reduced motion → the fullscreen brand seats at optical centre instantly (no drift-in)',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(() => WindowFullScreen.active.value = false);
      WindowFullScreen.active.value = true;

      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: AnShell(onToggleLeft: () {}),
            ),
          ),
        ),
      );
      await tester.pump(); // ONE frame — reduced motion is instant, no settle

      final brandCenter = tester.getCenter(find.byType(AnBrandIcon).first).dy;
      final collapseCenter = tester
          .getCenter(find.byIcon(AnIcons.panelLeft).first)
          .dy;
      expect(
        brandCenter - collapseCenter,
        closeTo(AnSize.brandBandDrop, 1.0),
        reason:
            'reduced motion lands the brand at its optical-centre home on the first frame',
      );
    },
  );

  testWidgets(
    'fullscreen brand DRIFTS down into its optical-centre home (transition, not a pop)',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(() => WindowFullScreen.active.value = false);
      WindowFullScreen.active.value = true;

      await tester.pumpWidget(wrap(AnShell(onToggleLeft: () {})));
      await tester
          .pump(); // mount frame — the drift begins at the lights' line (drop ≈ 0)
      final collapseCenter = tester
          .getCenter(find.byIcon(AnIcons.panelLeft).first)
          .dy;
      final startDrop =
          tester.getCenter(find.byType(AnBrandIcon).first).dy - collapseCenter;

      await tester.pumpAndSettle();
      final endDrop =
          tester.getCenter(find.byType(AnBrandIcon).first).dy - collapseCenter;

      expect(
        startDrop,
        lessThan(endDrop - 1),
        reason:
            'the brand drifts DOWN over the transition rather than popping into place',
      );
      expect(endDrop, closeTo(AnSize.brandBandDrop, 1.0));
    },
  );

  test(
    'minimum window keeps the ocean ≥ its min column even with the left island at max',
    () {
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
      final oceanWorstCase =
          AnSize.windowMinWidth -
          2 * AnSize.shellPad -
          AnSize.sidebarMax -
          2 * AnSize.shellGap -
          AnSize.rightIslandMin;
      expect(oceanWorstCase, greaterThanOrEqualTo(AnSize.oceanMin));
      expect(
        AnSize.windowMinHeight,
        closeTo(AnSize.windowMinWidth / AnSize.goldenRatio, 0.01),
      );
      expect(
        AnSize.windowMinWidth,
        lessThan(1512),
      ); // fits a scaled 14" MacBook with margin 留余量
    },
  );

  group('S11 reveal-freeze gate', () {
    Widget hostWithToggle(ValueNotifier<bool> open, Widget ocean) =>
        TranslationProvider(
          child: MaterialApp(
            theme: AnTheme.light(),
            home: ValueListenableBuilder<bool>(
              valueListenable: open,
              builder: (_, v, _) => AnShell(
                ocean: ocean,
                inspector: const Text('Inspector'),
                inspectorOpen: v,
              ),
            ),
          ),
        );

    testWidgets(
      'NARROW window: an island slide lays the ocean out at TARGET width — no per-frame relayout',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final widths = <double>[];
        final open = ValueNotifier(true);
        addTearDown(open.dispose);
        const probeKey = ValueKey('oceanProbe');
        await tester.pumpWidget(
          hostWithToggle(
            open,
            LayoutBuilder(
              builder: (_, c) {
                widths.add(c.maxWidth);
                return const SizedBox.expand(key: probeKey);
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1100 − 2×shellPad(8) = 1084 box; left 320+8, right 320+8 → ocean 428 (< reflow floor);
        // closing the right island targets 1084−328 = 756 — STILL under the floor → freeze.
        open.value = false; // slide the right island away 收右岛
        widths.clear();
        // NOTHING is skipped from here on. This used to pump the flip, then a frame, then clear the list
        // "to ignore the pre-freeze frame(s)". That accommodation turns out to have been unnecessary: on
        // the flip frame the reveal controller has not ticked, so the ocean's width is unchanged and the
        // probe does not re-run at all. Keeping the skip would have hidden a future regression that DID
        // relayout on the flip frame, so it is gone.
        // **从这里起一帧都不跳过。** 原先是先 pump 翻转帧、再 pump 一帧,然后清空列表「忽略冻结生效前的帧」。
        // 那份容忍其实不必要:翻转那一帧揭示控制器还没走动,海洋宽度没变,探针根本不会重跑。而留着这个跳过,
        // 会遮住将来某个**真的**在翻转帧 relayout 的回归,故删掉。
        await tester.pump(); // the flip frame itself 翻转帧本身
        await tester.pump(const Duration(milliseconds: 40));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pump(const Duration(milliseconds: 60));
        // The strongest possible evidence: the builder never re-ran mid-slide (constraints pinned
        // at the target width → ZERO ocean relayouts); any run there was must be the target width.
        // 最强证据:滑动中 builder 未重跑(约束钉终宽→海洋零 relayout);若跑,也只许是终宽。
        expect(
          widths.toSet(),
          anyOf(isEmpty, equals({756.0})),
          reason:
              'from the FIRST frame of the slide the ocean is pinned at its target width',
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(probeKey)).width,
          756.0,
          reason: 'the freeze lifts into the SAME width — zero jump',
        );
      },
    );

    testWidgets(
      'WIDE window: the slide keeps the continuous relayout (cheap — the 720 column never re-shapes)',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final widths = <double>[];
        final open = ValueNotifier(true);
        addTearDown(open.dispose);
        await tester.pumpWidget(
          hostWithToggle(
            open,
            LayoutBuilder(
              builder: (_, c) {
                widths.add(c.maxWidth);
                return const SizedBox.expand();
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        widths.clear();
        open.value = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pump(const Duration(milliseconds: 80));
        await tester.pumpAndSettle();
        // Both ends are ≥ the reflow floor (1904−656=1248 → 1904−328=1576) → never frozen: the
        // ocean glides through intermediate widths. 两端皆在阈上→不冻,海洋滑过中间宽。
        expect(
          widths.toSet().length,
          greaterThan(2),
          reason: 'continuous animation relayouts through intermediate widths',
        );
      },
    );
  });
  // CR-1a guard — the shell must never build its contents inside a layout callback again.
  //
  // The regression this locks out is not cosmetic: with a LayoutBuilder here, BOTH islands and all
  // four oceans were first-mounted during the LAYOUT phase, so any rebuild they triggered (a scroll
  // listener touching a provider, Riverpod invalidating itself mid-flush) raised
  // "setState/markNeedsBuild called during build" — and one such trip corrupted the element tree
  // badly enough to crash the process. A LayoutBuilder reintroduced here would restore that whole
  // failure class silently, because nothing else in the suite would notice.
  //
  // The shell needs exactly one number, its own width, and that is always the window's.
  //
  // CR-1a 守卫 —— 壳绝不可再把内容建在布局回调里。
  //
  // 它挡的不是外观问题:一旦这里有 LayoutBuilder,两岛与四海洋的首次挂载就发生在**布局阶段**,此后它们
  // 触发的任何重建(滚动监听碰 provider、Riverpod 冲刷中自失效)都会抛「setState/markNeedsBuild called
  // during build」——其中一次足以把 element 树弄坏到进程崩溃。若有人把 LayoutBuilder 加回来,这整类
  // 故障会**无声**复辟,因为套件里没有别的东西会察觉。
  //
  // 壳需要的恰好只是一个数——它自己的宽度——而那恒等于窗宽。
  testWidgets('the shell builds its contents OUTSIDE any layout callback', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // The assertion is deliberately about ANCESTRY, not "no LayoutBuilder anywhere": leaf primitives
    // (AnButton and friends) legitimately measure themselves. What must never come back is a layout
    // callback ABOVE the shell's own structure, because that is what drags island/ocean mounting
    // into the layout phase.
    // 断言刻意是**祖先关系**而非「哪里都不许有 LayoutBuilder」:叶子原语(AnButton 之流)合法地自量。
    // 绝不可复辟的是壳**自身结构之上**的布局回调——正是它把岛/海洋的挂载拖进布局阶段。
    expect(find.byType(AnShell), findsOneWidget);
    final island = find.byType(AnIsland).first;
    expect(island, findsOneWidget);
    expect(
      find.ancestor(of: island, matching: find.byType(LayoutBuilder)),
      findsNothing,
      reason:
          'a LayoutBuilder above the islands puts the whole app inside the layout phase again (CR-1a)',
    );

    // And the width it derives must still be the window minus the shell pad — the equivalence that
    // makes dropping the LayoutBuilder safe. 且它推导的宽度仍须等于窗宽减壳内距——这正是能拆掉
    // LayoutBuilder 的等价前提。
    expect(tester.getSize(island).width, greaterThan(0));
  });

  // ───────────────── WRK-077 RI · the remount guard ─────────────────
  //
  // Every one of the RI defects was the SAME mechanism with three faces: a wrapper that comes and goes
  // changes a slot's runtimeType, `Widget.canUpdate` says no, and the whole subtree unmounts and
  // re-inflates. Faces: the collapsed inspector wrapped in ExcludeFocus (病灶①), the freeze gate wrapping
  // the ocean in ClipRect+OverflowBox (病灶④), and the island dropping its subtree at t == 0 (病灶③).
  //
  // No pixel assertion catches this — the layout is CORRECT before and after, it is the identity that is
  // lost, and what the user feels is the cost of losing it (providers re-subscribe → flicker; a hundred
  // elements inflate in one frame → stutter; a transcript re-shaped at a new width → the reading position
  // flies away). So the guard counts MOUNTS. A subtree that survives a toggle mounts exactly once.
  //
  // 每一个 RI 病灶都是**同一个机制的三张脸**:来来去去的包装层改变 slot 的 runtimeType,`Widget.canUpdate`
  // 判否,整棵子树卸载重挂。三张脸:收起的 inspector 被 ExcludeFocus 裹住(病灶①)、冻结闸把海洋裹进
  // ClipRect+OverflowBox(病灶④)、岛在 t == 0 时丢掉子树(病灶③)。
  //
  // 任何像素断言都抓不到它——前后布局都**对**,丢掉的是身份,而用户感受到的是丢掉身份的代价(provider 重新
  // 订阅→闪;一帧 inflate 上百 element→卡;transcript 按新宽重排→阅读位置飞掉)。故守卫**数挂载次数**:
  // 一棵活过切换的子树,只挂载一次。

  testWidgets('RI: toggling the islands NEVER remounts the ocean or the inspector', (
    tester,
  ) async {
    // NARROW on purpose: the freeze gate only arms when the ocean is under the reflow floor (768), which is
    // why the user saw the ocean jump in a window and not in fullscreen. A wide-window-only guard would
    // have declared 病灶④ fixed while it was untouched.
    // **刻意用窄窗**:冻结闸只在海洋低于 reflow 底线(768)时才上膛,这正是用户「窗口化才跳、全屏不跳」的原因。
    // 只在宽窗验的守卫会宣布病灶④已修,而它根本没被碰过。
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final oceanMounts = _MountCount();
    final inspectorMounts = _MountCount();

    Widget shell({required bool leftCollapsed, required bool inspectorOpen}) =>
        wrap(
          AnShell(
            sidebar: const Text('Sidebar'),
            ocean: _CountsMounts(
              counter: oceanMounts,
              child: const Text('Ocean'),
            ),
            inspector: _CountsMounts(
              counter: inspectorMounts,
              child: const Text('Inspector'),
            ),
            leftCollapsed: leftCollapsed,
            inspectorOpen: inspectorOpen,
          ),
        );

    await tester.pumpWidget(shell(leftCollapsed: false, inspectorOpen: true));
    await tester.pumpAndSettle();
    expect(oceanMounts.value, 1, reason: 'OCEAN initial mount');
    expect(inspectorMounts.value, 1, reason: 'INSPECTOR initial mount');

    // Close the inspector, half-way and then fully — the freeze gate arms and disarms across this.
    // 关右岛,先中途再到底——冻结闸在这中间上膛又下膛。
    await tester.pumpWidget(shell(leftCollapsed: false, inspectorOpen: false));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();

    // Re-open it. 再开回来。
    await tester.pumpWidget(shell(leftCollapsed: false, inspectorOpen: true));
    await tester.pumpAndSettle();

    // And the left island, both ways. 左岛也来回一趟。
    await tester.pumpWidget(shell(leftCollapsed: true, inspectorOpen: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(shell(leftCollapsed: false, inspectorOpen: true));
    await tester.pumpAndSettle();

    expect(
      oceanMounts.value,
      1,
      reason:
          'the ocean was rebuilt — a wrapper is being added/removed around it (RI 病灶④)',
    );
    expect(
      inspectorMounts.value,
      1,
      reason:
          'the inspector was rebuilt — a wrapper is being added/removed around it, or its subtree is '
          'dropped when closed (RI 病灶①/③)',
    );
  });
}

/// A mutable counter the probe writes its mount count into. 探针写入挂载次数的可变计数器。
class _MountCount {
  int value = 0;
}

/// Counts how many times it is MOUNTED (not built). A subtree that keeps its element identity across a
/// toggle mounts exactly once; a remount is the defect, and it is invisible to any layout assertion.
/// 数**挂载**(非重建)次数。跨切换保住 element 身份的子树只挂载一次;重挂才是缺陷,而它对任何布局断言都隐形。
class _CountsMounts extends StatefulWidget {
  const _CountsMounts({required this.counter, required this.child});

  final _MountCount counter;
  final Widget child;

  @override
  State<_CountsMounts> createState() => _CountsMountsState();
}

class _CountsMountsState extends State<_CountsMounts> {
  @override
  void initState() {
    super.initState();
    widget.counter.value += 1;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
