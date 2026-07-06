// Dev screenshot harness for `make demo` — renders the REAL app shell ([AppShell], same as make app)
// driven by the zero-backend [demoEntityRepository], headlessly via Skia → test/dev/out/demo.png.
// STEP 6: routing is real — pre-selection is a deep link (navigate the GoRouter), not a provider override.
// Run:  flutter test test/dev/capture_demo.dart
// 截 make demo 的真壳(AppShell)+ fixture → demo.png。STEP 6:预选 = deep-link 导航(非 provider override)。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:anselm/app/router.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/core/shell/oceans.dart';
import 'package:anselm/core/shell/shell_chrome.dart';
import 'package:anselm/core/ui/an_sidebar_footer.dart';
import 'package:anselm/core/ui/icons.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/features/chat/data/chat_demo_fixture.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/notifications/data/notification_demo_fixture.dart';
import 'package:anselm/features/notifications/data/notification_providers.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, String path) async {
  final f = File(path);
  if (!f.existsSync()) return;
  final b = f.readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(b.buffer, b.offsetInBytes, b.length)));
  await loader.load();
}

// Optional `--dart-define=SEL=function:fn_normalize` deep-links to an entity so the detail sea is
// captured (default: rail + empty ocean → demo.png; selected → demo_<id>.png). 可预选实体截详情。
const _sel = String.fromEnvironment('SEL');
// Optional `--dart-define=TAB=overview|versions|logs` taps that tab before capture. 预点某 tab。
const _tab = String.fromEnvironment('TAB');
// Optional `--dart-define=VSEL=v1` taps that version row in the 版本 tab. 选某版本行。
const _vsel = String.fromEnvironment('VSEL');
// Optional `--dart-define=HOVER=<text>` hovers a widget by its text (reveals meta edit affordances:
// the far-right pencil, the tags ✕/➕). 悬停某文本处,揭示 meta 编辑触点(最右铅笔、标签 ✕/➕)。
const _hover = String.fromEnvironment('HOVER');
// Optional `--dart-define=TAPADD=1` (with HOVER) presses the revealed ➕ → the tag add input. 按 ➕。
const _tapAdd = String.fromEnvironment('TAPADD');
// Optional `--dart-define=RUN=1` opens the right-island run terminal (verb CTA) + executes, to capture
// the STEP 5 run terminal with live output. Requires SEL. 打开右岛 run 终端并执行,截运行态。
const _run = String.fromEnvironment('RUN');
// Optional `--dart-define=COLLAPSE=1` collapses the left island (verify reopen-after-lights layout). 收起左岛。
const _collapse = String.fromEnvironment('COLLAPSE');
// Optional `--dart-define=OCEAN=chat|scheduler|documents|settings` switches the ocean (verify the
// switcher + "coming soon" placeholder for an unbuilt ocean / the gear→settings ocean). 切换海洋。
const _ocean = String.fromEnvironment('OCEAN');
// Optional `--dart-define=NOTIF=1` opens the notifications tray (bell) — verify it takes over the left
// island. 拉开通知托盘,验它接管左岛。
const _notif = String.fromEnvironment('NOTIF');
// Optional `--dart-define=CHATSEL=cv_id` deep-links to a conversation (on the chat ocean) so the rail's
// selected-row highlight + route-derived selection are captured. 预选某对话,截 rail 高亮 + 路由派生选区。
const _chatSel = String.fromEnvironment('CHATSEL');
// Optional `--dart-define=CHATMENU=1` taps the rail's ⚙ sliders button to open the Sort/Display menu.
// 点 rail 的 ⚙ sliders 钮,展开排序/显示菜单。
const _chatMenu = String.fromEnvironment('CHATMENU');
// Optional `--dart-define=CHATROWMENU=1` (chat ocean) hovers a conversation row + opens its ⋯ menu
// (rename / pin / archive / delete). `--dart-define=CHATRENAME=1` goes one further: taps 重命名 so the row
// shows the in-place rename field. 行 ⋯ 菜单 / 就地改名截图。
const _chatRowMenu = String.fromEnvironment('CHATROWMENU');
const _chatRename = String.fromEnvironment('CHATRENAME');
// Optional `--dart-define=CHATSEND=文本` types into the composer + Enter, then pumps the demo's scripted
// streaming reply. `CHATAT=mid|done` picks the capture moment (default done). 打字发送 + 泵脚本流;选截流中或完成。
const _chatSend = String.fromEnvironment('CHATSEND');
const _chatAt = String.fromEnvironment('CHATAT');
// Optional `--dart-define=WSMENU=1` opens the workspace quick-actions menu — verify it matches the
// trigger width. 打开 workspace 快捷菜单,验它与触发钮等宽。
const _wsmenu = String.fromEnvironment('WSMENU');
// Optional `--dart-define=NOTIFPICK=1` opens notifications THEN taps the settings gear — verify picking
// an ocean dismisses the tray (settings shows, not notifications). 开通知再点设置齿轮,验选海洋即收起托盘。
const _notifPick = String.fromEnvironment('NOTIFPICK');

/// The capture root — the REAL [AppShell] driven by the REAL [buildAppRouter] (so routing is exercised
/// exactly as `make app`); the `builder` wraps the routed shell in a keyed RepaintBoundary to grab. 截图根。
class _CaptureApp extends ConsumerWidget {
  const _CaptureApp();
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        routerConfig: ref.watch(goRouterProvider),
        builder: (context, child) =>
            RepaintBoundary(key: const ValueKey('cap'), child: child!),
      );
}

void main() {
  setUpAll(() async {
    await _load('Inter', 'assets/fonts/InterVariable.ttf');
    await _load('MiSans', 'assets/fonts/MiSansVF.ttf');
    await _load('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
    final cache = '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev';
    await _load('packages/lucide_icons_flutter/Lucide300',
        '$cache/lucide_icons_flutter-3.1.14+2/assets/build_font/LucideVariable-w300.ttf');
    LocaleSettings.setLocaleRaw('zh-CN');
  });

  testWidgets('demo', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(AnSize.windowInitialWidth * 2, AnSize.windowInitialHeight * 2);
    addTearDown(tester.view.reset);

    EntityKind? selKind;
    String? selId;
    var outName = 'demo';
    if (_sel.isNotEmpty) {
      final parts = _sel.split(':');
      selKind = EntityKind.values.byName(parts[0]);
      selId = parts[1];
      outName = 'demo_$selId';
    }

    await tester.pumpWidget(ProviderScope(
      overrides: [
        entityRepositoryProvider.overrideWithValue(demoEntityRepository()),
        chatRepositoryProvider.overrideWithValue(demoChatRepository()),
        notificationRepositoryProvider.overrideWithValue(demoNotificationRepository()),
        goRouterProvider.overrideWith(buildAppRouter),
      ],
      child: TranslationProvider(child: const _CaptureApp()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80)); // let the 4 list futures resolve

    final container = ProviderScope.containerOf(tester.element(find.byType(_CaptureApp)), listen: false);
    container.read(activeWorkspaceNameProvider.notifier).set('Personal'); // footer shows a real name 底栏显真名
    await tester.pump(); // let the name reach the footer 让名字到达底栏

    // Switch the ocean (the switcher's real path) — captures the placeholder for an unbuilt ocean. 切换海洋。
    if (_ocean.isNotEmpty) {
      container.read(selectedOceanProvider.notifier).select(OceanKind.values.byName(_ocean));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // the switch animation settles 切换动画落定
      outName = '${outName}_$_ocean';
    }

    // Deep-link to a conversation (real navigation) so the rail highlights the selected row. 深链选中对话。
    if (_chatSel.isNotEmpty) {
      container.read(goRouterProvider).go(conversationLocation(_chatSel));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      outName = '${outName}_sel';
    }

    // Open the rail's ⚙ sliders menu (Sort / Display) to capture it. 打开 rail 的 ⚙ 菜单。
    if (_chatMenu.isNotEmpty) {
      await tester.tap(find.byIcon(AnIcons.sliders).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250)); // popover open animation 浮层开
      outName = '${outName}_menu';
    }

    // Hover a conversation row + open its ⋯ menu (rename / pin / archive / delete), optionally tapping
    // 重命名 to show the in-place rename field. A real mouse + alwaysTraditional highlight reveals the
    // hover-gated trail action; fixed pumps (NOT pumpAndSettle — the demo has a forever-breathing
    // generating dot). 悬停某行 + 开 ⋯ 菜单(可再点重命名显就地编辑框)。
    if (_chatRowMenu.isNotEmpty || _chatRename.isNotEmpty) {
      WidgetsBinding.instance.focusManager.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      final row = find.text('API key 轮换排查'); // a calm recents row (no animated dot)
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      final rowY = tester.getCenter(row.first).dy;
      await mouse.moveTo(tester.getCenter(row.first));
      await tester.pump(); // hover → the row's ⋯ becomes hit-testable
      // Pick the ⋯ at THIS row's y (every row lays one out; only the hovered one is interactive). 取该行 y 的 ⋯。
      var p = Offset.zero;
      final mores = find.byIcon(AnIcons.more);
      for (var i = 0; i < mores.evaluate().length; i++) {
        final c = tester.getCenter(mores.at(i));
        if ((c.dy - rowY).abs() < 4) {
          p = c;
          break;
        }
      }
      await mouse.moveTo(p);
      await tester.pump();
      await mouse.down(p);
      await mouse.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250)); // popover open
      outName = '${outName}_rowmenu';
      if (_chatRename.isNotEmpty) {
        await tester.tap(find.text(LocaleSettings.instance.currentTranslations.chat.rename));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250)); // the row becomes the rename field
        outName = '${outName.replaceFirst('_rowmenu', '')}_rename';
      }
    }

    // Open the notifications tray (bell) — it takes over the left-island middle. 拉开通知托盘,接管左岛中段。
    if (_notif.isNotEmpty) {
      container.read(notificationsOpenProvider.notifier).toggle();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      outName = '${outName}_notif';
    }

    // Open the workspace quick-actions menu — verify it matches the trigger width. 打开 workspace 菜单,验等宽。
    if (_wsmenu.isNotEmpty) {
      await tester.tap(find.byType(AnWorkspaceButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200)); // popover open animation 浮层开
      outName = '${outName}_wsmenu';
    }

    // Open notifications, THEN tap the settings gear — picking an ocean must dismiss the tray (we should
    // see the SETTINGS ocean, not the notifications list). 开通知再点齿轮:选海洋须收起托盘 → 应见设置海洋而非通知。
    if (_notifPick.isNotEmpty) {
      container.read(notificationsOpenProvider.notifier).toggle(); // open the tray 开托盘
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byIcon(AnIcons.gear).first); // user picks settings 用户点设置
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      outName = '${outName}_notifpick';
    }

    // Pre-select via a deep link (the real navigation path). 经 deep-link 预选(真导航路径)。
    if (selKind != null && selId != null) {
      // EDITOR=1: go straight to the full-screen graph editor route. EDITOR=1 直进全屏图编辑器。
      if (const String.fromEnvironment('EDITOR').isNotEmpty && selKind == EntityKind.workflow) {
        container.read(goRouterProvider).go(workflowEditorLocation(selId));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump(const Duration(milliseconds: 200));
        outName = '${outName}_editor';
        // EDNODE=<nodeId>: tap a node to reveal the inspector's node editor. 点节点显检查器。
        if (const String.fromEnvironment('EDNODE').isNotEmpty) {
          await tester.tap(find.text(const String.fromEnvironment('EDNODE')).first);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 120));
          outName = '${outName}_node';
        }
      } else {
      container.read(goRouterProvider).go(entityLocation(selKind, selId));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80)); // detail resolves
      // The right island slides in (AnMotion.slow 340ms) and the ocean narrows — let it settle so
      // width-reactive content (framed graph re-fit) captures at the FINAL size, not mid-flight.
      // 右岛滑入、海洋变窄——让其落定,宽度响应内容(framed 图重 fit)按终宽截。
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      }
    }

    if (_collapse.isNotEmpty) {
      container.read(shellChromeProvider.notifier).toggleLeft();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // the collapse slide settles 收起滑动
      outName = '${outName}_collapsed';
    }

    // Type + send in the open conversation (or the landing) and pump the scripted stream. 打字发送+泵流。
    if (_chatSend.isNotEmpty) {
      await tester.enterText(find.byType(TextField).last, _chatSend); // the composer field (rail filter is first)
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      // The scripted reply spans ~4s: mid ≈ inside the text deltas; done = past the terminal. 脚本约 4s。
      final horizonMs = _chatAt == 'mid' ? 2600 : 6500;
      for (var i = 0; i < horizonMs ~/ 50; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      outName = '${outName}_send${_chatAt == 'mid' ? '_mid' : ''}';
    }

    if (_tab.isNotEmpty) {
      final detail = LocaleSettings.instance.currentTranslations.entities.detail.tab;
      final label = {'overview': detail.overview, 'versions': detail.versions, 'logs': detail.logs, 'runs': detail.runs}[_tab]!;
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120)); // the tab's data loads (cockpit pages through)
      await tester.pump(const Duration(milliseconds: 120));
      outName = '${outName}_$_tab';
      // RUNSEL=<flowrunId>: pick a run in the cockpit list. 点 run 列表某条。
      if (const String.fromEnvironment('RUNSEL').isNotEmpty) {
        await tester.tap(find.text(const String.fromEnvironment('RUNSEL')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        await tester.pump(const Duration(milliseconds: 120));
        outName = '${outName}_${const String.fromEnvironment('RUNSEL')}';
      }
      // NODESEL=<nodeId>: pick a node in the run cockpit → the node-debug card. 点甘特节点出调试卡。
      if (const String.fromEnvironment('NODESEL').isNotEmpty) {
        await tester.tap(find.text(const String.fromEnvironment('NODESEL')).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        outName = '${outName}_node';
      }
      if (_vsel.isNotEmpty) {
        // Tap a version row (e.g. `v1`) to show a non-active selection → set-active appears in the
        // footer BELOW the diff. 选某版本行,验证 set-active 在 diff 下方 footer。
        await tester.tap(find.text(_vsel));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        outName = '${outName}_$_vsel';
      }
    }

    if (_run.isNotEmpty && selKind != null) {
      final verb = LocaleSettings.instance.currentTranslations.entities.detail.verb;
      final label = {
        EntityKind.function: verb.run,
        EntityKind.handler: verb.call,
        EntityKind.agent: verb.invoke,
        EntityKind.workflow: verb.trigger,
      }[selKind]!;
      // The right island is already revealed (strong-linked to the selection); the header verb CTA both
      // ensures it's open and fires the run. 右岛已随选区揭示;头部动词 CTA 展开 + 执行。
      await tester.tap(find.widgetWithText(AnButton, label).first);
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 40)); // scripted stream frames
      }
      outName = '${outName}_run';
    }

    if (_hover.isNotEmpty) {
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text(_hover).first));
      await tester.pump(); // hover enter
      await tester.pump(const Duration(milliseconds: 200)); // reveal settles (avoid pumpAndSettle: caret blinks)
      outName = '${outName}_hover';
      if (_tapAdd.isNotEmpty) {
        // Press the revealed far-right ➕ → the tag add input mounts (WRK-054). 按 ➕ → 输入框挂出。
        await tester.tap(find.byIcon(AnIcons.plus).first, warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        outName = '${outName}_adding';
      }
    }

    late final Uint8List bytes;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('cap')));
      final image = await boundary.toImage(pixelRatio: 2.0);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      bytes = png!.buffer.asUint8List();
      image.dispose();
    });
    final dir = Directory('test/dev/out')..createSync(recursive: true);
    File('${dir.path}/$outName.png').writeAsBytesSync(bytes);

    // A mid-stream capture leaves the demo script's timers pending — drain them so the harness ends
    // clean (the frame is already grabbed). 流中截帧后脚本计时器仍挂——泵尽收尾(图已到手)。
    if (_chatSend.isNotEmpty && _chatAt == 'mid') {
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
  });
}
