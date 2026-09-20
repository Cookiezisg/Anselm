import 'dart:async';
import 'package:flutter/material.dart';
import 'package:anselm/core/media/media_video.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` (the ProviderScope override type) is exported from misc.dart, not the main barrel (Riverpod
// 3.x). Named only for demoOverrides's signature. Override 类型在 misc.dart(3.x 主 barrel 不导出)。
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:scaled_app/scaled_app.dart';

import '../app/router.dart';
import '../app/window_setup.dart';
import '../core/design/an_fonts.dart';
import '../core/design/theme.dart';
import '../core/overlay/an_overlay.dart';
import '../core/platform/window_zoom.dart';
import '../core/router/navigation.dart';
import '../core/settings/app_prefs_providers.dart';
import '../core/settings/settings_prefs.dart';
import '../core/shortcuts/global_shortcuts.dart';
import '../core/model/model_capabilities.dart';
import '../core/notice/notice_center.dart';
import 'story/story_bible.dart';
import '../features/entities/state/flowrun_inbox_provider.dart';
import '../features/chat/state/new_conversation.dart';
import '../features/chat/state/selected_conversation.dart';
import '../core/ui/icons.dart';
import '../core/model/status_state.dart';
import '../features/scheduler/data/scheduler_demo_fixture.dart';
import '../features/scheduler/data/scheduler_repository.dart';
import '../features/settings/data/settings_demo_fixture.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/chat/data/chat_demo_fixture.dart';
import '../features/chat/data/chat_providers.dart';
import '../features/library/data/library_repository.dart';
import '../features/library/data/library_demo_fixture.dart';
import '../features/entities/data/entity_demo_fixture.dart';
import '../features/entities/data/entity_providers.dart';
import '../features/notifications/data/notification_demo_fixture.dart';
import '../features/notifications/data/notification_fixture.dart';
import '../features/notifications/data/notification_providers.dart';
import '../i18n/strings.g.dart';
import 'demo_notice_showcase.dart';
import 'perf_probe.dart';
import 'story/story.dart';
import 'story/story_notices.dart';
import '../app/entity_mention_source.dart';
import '../core/entity/mention_source.dart';

/// Entry for `make demo` — the REAL app shell + router (byte-identical routing to `make app`, sharing
/// [buildAppRouter]) driven by fake data: one ProviderScope override swaps the repository seam for the
/// zero-backend fixtures. The ONLY differences from `make app` are (a) the data source and (b) NO startup
/// or workspace gates (there is no sidecar to wait for). Everything else — `MaterialApp.router`,
/// deep-link routing, the [AnOverlayHost] toast/dialog layer — is the same surface. NO per-feature run
/// targets: app and demo share the shell + router, differing only in data + gates.
///
/// 入口:`make demo`——真 app 壳 + 路由(与 make app 共用 buildAppRouter、路由逐字一致),假数据驱动:一个 override 把数据缝换成
/// 零后端 fixture。与 make app 仅两处差异:①数据源 ②无启动/工作区门控(无 sidecar 可等)。其余(MaterialApp.router、deep-link、
/// AnOverlayHost toast/dialog 层)同一面。绝不加 per-feature 入口。
/// The demo's ProviderScope overrides — the repository seam swapped for the zero-backend fixtures.
/// Shared by [main] and the P5 perf harness (`integration_test/perf/`) so both drive the byte-identical
/// app off the same fixtures; the caller passes the [notifications] repo it wants (main keeps a handle to
/// drive its live-notice timer). demo override 集,main 与 P5 perf harness 共用同一份 fixture 驱动同一 app。
List<Override> demoOverrides(
  SettingsPrefs prefs,
  FixtureNotificationRepository notifications,
) => [
  settingsPrefsProvider.overrideWithValue(prefs),
  goRouterProvider.overrideWith(buildAppRouter),
  entityRepositoryProvider.overrideWithValue(demoEntityRepository()),
  chatRepositoryProvider.overrideWithValue(demoChatRepository()),
  libraryRepositoryProvider.overrideWithValue(demoLibraryRepository()),
  notificationRepositoryProvider.overrideWithValue(notifications),
  settingsRepositoryProvider.overrideWithValue(demoSettingsRepository()),
  schedulerRepositoryProvider.overrideWithValue(demoSchedulerRepository()),
  // Capabilities are core-level (S-15): zero-backend demo feeds them directly, never HTTP.
  // 能力目录在 core(S-15):零后端 demo 直喂,绝不打 HTTP。
  modelCapabilitiesProvider.overrideWith((ref) async => demoModelCapabilities),
  mentionSourceProvider.overrideWith(entityMentionSource),
];

/// Dataset switch for `make demo DATASET=<name>`: `''` (default) keeps the test-backed demo fixtures;
/// `story` loads the bilingual product story (`story/`). A dart-define rather than a new entry point,
/// because the launch surface is fixed at gallery/app/demo (CLAUDE.md 前端守则「启动面」).
/// 数据集开关：空=默认 demo fixture（测试依赖）；story=双语产品故事。用 dart-define 而非新入口，
/// 因为启动面只许 gallery/app/demo 三类。
const String kDemoDataset = String.fromEnvironment('ANSELM_DEMO_DATASET');

/// Optional UI-locale pin for screenshot runs (`make demo LOCALE=zh|en`); empty = follow the device.
/// 截图时可钉住界面语言；空=跟随设备。
const String kDemoLocale = String.fromEnvironment('ANSELM_DEMO_LOCALE');

/// `promo` plays the product reel on launch: a fresh thread, the opening sentence sent for you, the
/// story's scripted build-and-run turn, the approval capsule and its decision — for recording, with
/// the top-band tour muted so nothing else moves. 启动即播产品宣传片:新线程、代你发出开场句、故事的脚本化
/// 建造与运行回合、审批胶囊及其决定——供录屏,顶带巡演静音,画面里不再有别的动静。
const String kDemoAutoplay = String.fromEnvironment('ANSELM_DEMO_AUTOPLAY');

Future<void> main() async {
  // The SCALED binding, byte-for-byte as main.dart creates it. Zoom is neither a data source nor a
  // gate, so the 铁律「app 与 demo 只差两点」 forbids it diverging here — and it is not decorative:
  // WindowZoom._apply() only relayouts `if (binding is ScaledWidgetsFlutterBinding)`, so a bare
  // WidgetsFlutterBinding makes that test FALSE and ⌘± dies SILENTLY (the factor moves, the tree
  // never reflows). The demo is the visual acceptance floor — every deviation from the app falsifies
  // an acceptance run. Guarded by test/guards/demo_parity_guard_test.dart.
  // scaled binding,与 main.dart 逐字同款。缩放既非数据源亦非门控,故「只差两点」铁律不许它在此分叉——
  // 且它不是装饰:WindowZoom._apply() 只在 `binding is ScaledWidgetsFlutterBinding` 时才重排,裸 binding
  // 让该判恒假、⌘± **静默**失效(factor 动了、树永不重排)。demo 是视觉验收地板,与 app 的每处偏离都让
  // 验收失真。由 demo_parity_guard_test.dart 守。
  ScaledWidgetsFlutterBinding.ensureInitialized(
    scaleFactor: WindowZoom.scaleFactorCallback,
  );
  initMediaPlayback();
  if (kPerfProbeEnabled) installPerfProbe();
  if (kDemoLocale.isEmpty) {
    LocaleSettings.useDeviceLocaleSync();
  } else {
    LocaleSettings.setLocaleSync(AppLocaleUtils.parse(kDemoLocale));
  }
  // Real persisted prefs in the demo too — chrome memory (island widths / last ocean / window
  // geometry) survives a relaunch, same as the app. demo 也用真持久偏好,与 app 同。
  final prefs = await SettingsPrefs.load();
  WindowZoom.useSettingsPrefs(
    prefs,
  ); // zoom persists via the central prefs, same as the app
  // Resolve the RESTART font axes before runApp, same as the app (content axis stays hot). 同 app 启动前解析重启字体轴。
  AnFonts.applyAtBoot(
    ui: prefs.getString(SettingsKeys.fontUi),
    code: prefs.getString(SettingsKeys.fontCode),
  );
  // A pinned locale must also win over the persisted UI-language preference the startup resolver applies
  // (otherwise the pref flips the tree back after the first frame). 钉住的语言也要压过持久化偏好。
  if (kDemoLocale.isNotEmpty) {
    prefs.setString(
      SettingsKeys.locale,
      kDemoLocale == 'zh' ? 'zh-CN' : kDemoLocale,
    );
  }
  await initWindow(
    title: kDemoDataset == 'story'
        ? 'Anselm · Demo (story)'
        : 'Anselm · Demo (fixtures)',
    prefs: prefs,
  );
  WindowZoom.restore(); // the persisted zoom, before the first frame 首帧前恢复持久化缩放
  // Keep the fixture repository as a stable data seam; the demo-only top-band tour itself is mounted below
  // the app root, where it can enqueue operation/event/approval presentation copies and clean up its timers.
  // fixture 仓储仍是稳定数据缝;顶带巡演改挂在 app root 下,可送操作/事件/审批副本并随根卸载清计时器。
  final story = kDemoDataset == 'story';
  final storyLocale = StoryLocale(
    zh: LocaleSettings.currentLocale == AppLocale.zhCn,
  );
  final notifRepo = story
      ? storyNotificationRepository(storyLocale)
      : demoNotificationRepository();
  final promo = story && kDemoAutoplay == 'promo' ? PromoHooks() : null;
  runApp(
    ProviderScope(
      overrides: story
          ? storyOverrides(
              prefs,
              notifRepo,
              storyLocale,
              turnScript: promo == null ? null : promoTurn(storyLocale, promo),
            )
          : demoOverrides(prefs, notifRepo),
      child: TranslationProvider(
        child: DemoRoot(showcaseNotifications: true, promo: promo),
      ),
    ),
  );
}

/// The demo root — `MaterialApp.router` with the overlay host but NO gates. Mirrors `app.dart#AnApp`
/// minus AppStartupGate/WorkspaceGate. Public so the P5 perf harness mounts the exact same tree.
/// demo 根:MaterialApp.router + 浮层宿主,无门控;公开供 P5 perf harness 挂同一棵树。
class DemoRoot extends ConsumerWidget {
  const DemoRoot({this.showcaseNotifications = false, this.promo, super.key});

  /// Non-null only for the promo reel (see [kDemoAutoplay]). 仅宣传片非空。
  final PromoHooks? promo;

  /// Only `make demo` turns this on. Test and perf mounts keep their timeline deterministic unless they
  /// explicitly opt in. 仅 make demo 开启;测试/perf 默认不启,时间线保持确定。
  final bool showcaseNotifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final navigatorKey = ref.watch(rootNavigatorKeyProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      darkTheme: AnTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      // Mirror app.dart's wrap (minus the startup/workspace gates the demo has no backend for): the
      // rebindable global shortcuts (⌘B/⌘\/⌘,/⌘±/⌘0) ABOVE the autofocus Focus so cold-start chords
      // reach them (D-035). Handlers are pure provider/static calls — no backend needed. ⌘± additionally
      // needs the SCALED binding main() installs above: this wrap only DELIVERS the chord, it cannot make
      // the tree reflow. 镜像 app 快捷键;⌘± 另需上面那口 scaled binding——本层只负责把和弦送到,让树重排的
      // 不是它。
      builder: (context, child) => AnOverlayHost(
        navigatorKey: navigatorKey,
        child: _DemoNoticeShowcase(
          enabled: showcaseNotifications,
          promo: promo,
          child: GlobalShortcuts(child: Focus(autofocus: true, child: child!)),
        ),
      ),
    );
  }
}

/// Demo-only, finite top-band tour. It is intentionally mounted below [TranslationProvider] so the script
/// uses the active locale, and below the ProviderScope so it reaches the real shared notice center. The
/// test-facing [DemoRoot] leaves it off by default. demo 专用、有限的顶带巡演:置于 TranslationProvider/ProviderScope
/// 之下,随当前语言进真正共享中心;测试用 DemoRoot 默认关闭。
class _DemoNoticeShowcase extends ConsumerStatefulWidget {
  const _DemoNoticeShowcase({
    required this.enabled,
    required this.child,
    this.promo,
  });

  final bool enabled;
  final Widget child;
  final PromoHooks? promo;

  @override
  ConsumerState<_DemoNoticeShowcase> createState() =>
      _DemoNoticeShowcaseState();
}

class _DemoNoticeShowcaseState extends ConsumerState<_DemoNoticeShowcase> {
  final List<Timer> _timers = <Timer>[];
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.enabled || _scheduled) return;
    _scheduled = true;
    final promo = widget.promo;
    if (promo != null) {
      _armPromo(promo);
      return;
    }
    final beats = kDemoDataset == 'story'
        ? storyTopBandShowcase(context.t)
        : demoTopBandShowcase(context.t);
    for (final beat in beats) {
      _timers.add(
        Timer(beat.at, () {
          if (!mounted) return;
          ref
              .read(noticeCenterProvider.notifier)
              .push(beat.message, priority: beat.priority);
        }),
      );
    }
  }

  // The two beats the reel cannot play from inside the chat repository: raise the approval capsule
  // (notice center) and decide it (entity repository), exactly as the capsule's own button would.
  // 宣传片在聊天仓库内放不了的两拍:升起审批胶囊(通知中心)、作出决定(实体仓库),与胶囊按钮本身的路径一致。
  void _armPromo(PromoHooks promo) {
    final t = context.t;
    promo.showApproval = () {
      if (!mounted) return;
      ref
          .read(noticeCenterProvider.notifier)
          .push(
            NoticeMessage(
              text:
                  '${t.ref.workflow} ${t.notifications.nameQuoted(name: wfDigestName)} ${t.notifications.verb.waitingApproval}',
              icon: AnIcons.approval,
              tone: AnTone.warn,
              kind: NoticeKind.approval,
              origin: NoticeOrigin.event,
              title: apfDigestName,
              flowrunId: frDigestParked,
              nodeId: 'review',
              location: '/scheduler/w/$wfDigest/runs/$frDigestParked',
            ),
            priority: NoticePriority.priority,
          );
    };
    promo.approve = () async {
      if (!mounted) return;
      // No local-decision mark: that is what keeps a capsule on screen to show its verdict after
      // the button press; here the decision is authoritative and the capsule simply retires.
      // 不打本地决定标记:那是让胶囊在按钮按下后留屏展示判词用的;这里决定即权威,胶囊直接退场。
      await ref
          .read(entityRepositoryProvider)
          .decideApproval(frDigestParked, 'review', decision: 'yes');
      if (!mounted) return;
      ref.invalidate(flowrunInboxProvider);
      ref
          .read(noticeCenterProvider.notifier)
          .resolveApprovalsForRun(frDigestParked);
    };
    _timers.add(
      Timer(const Duration(milliseconds: 1600), () async {
        if (!mounted) return;
        // The landing composer's exact path: start the thread, then navigate to it.
        // 与落地 composer 同一条路:先起线程,再导航过去。
        final id = await ref.read(startConversationProvider)(promoPrompt);
        if (!mounted) return;
        // This widget sits in MaterialApp.router's builder, above the Navigator, so the router
        // comes from the provider rather than the context. 本件在 builder 里、Navigator 之上,router 取自 provider。
        ref.read(goRouterProvider).go(conversationLocation(id));
      }),
    );
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
