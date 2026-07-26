import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scaled_app/scaled_app.dart';

import '../app/window_setup.dart';
import '../app/workspace_gate.dart';
import '../core/contract/workspace.dart';
import '../core/design/an_fonts.dart';
import '../core/design/theme.dart';
import '../core/design/tokens.dart';
import '../core/net/api_client.dart';
import '../core/overlay/an_overlay.dart';
import '../core/platform/window_zoom.dart';
import '../core/router/navigation.dart';
import '../core/runtime.dart';
import '../core/shell/oceans.dart';
import '../core/settings/app_prefs_providers.dart';
import '../core/settings/settings_prefs.dart';
import '../core/shortcuts/global_shortcuts.dart';
import '../core/workspace/set_active_workspace.dart';
import '../core/workspace/workspace_bootstrap.dart';
import '../features/notifications/data/notification_demo_fixture.dart';
import '../i18n/strings.g.dart';
import 'demo_main.dart';

/// `make onboard` — an isolated, zero-backend visual acceptance entry for the complete first-run
/// transition. It opens on the real [WorkspaceGate]/onboarding surface, then releases the real router
/// and AppShell over demo repositories after the preview workspace is "created". Nothing is persisted
/// and the user's actual workspace roster is never read or written.
///
/// `make onboard`——完整首启过渡的隔离视觉验收入口。先显真实 WorkspaceGate/onboarding，预览 workspace
/// 「创建」后放真实 router + AppShell，数据全走 demo fixture；零持久化，也绝不读写用户的真工作区名册。
Future<void> main() async {
  ScaledWidgetsFlutterBinding.ensureInitialized(
    scaleFactor: WindowZoom.scaleFactorCallback,
  );
  LocaleSettings.useDeviceLocaleSync();
  final prefs = SettingsPrefs.inMemory();
  WindowZoom.useSettingsPrefs(prefs);
  AnFonts.applyAtBoot(
    ui: prefs.getString(SettingsKeys.fontUi),
    code: prefs.getString(SettingsKeys.fontCode),
  );
  await initWindow(title: t.coldStart.onboardingPreviewTitle, prefs: prefs);
  WindowZoom.restore();

  final notifications = demoNotificationRepository();
  runApp(
    ProviderScope(
      overrides: [
        ...demoOverrides(prefs, notifications),
        workspaceBootstrapProvider.overrideWith(OnboardingPreviewBootstrap.new),
        selectedOceanProvider.overrideWith(OnboardingPreviewOcean.new),
        // setActiveWorkspace deliberately settles apiClientProvider. This inert client keeps that
        // invariant intact without waking a real sidecar in the zero-backend preview.
        // setActiveWorkspace 必须摊平 apiClient；此惰性 client 保留不变量、又不唤醒真 sidecar。
        apiClientProvider.overrideWith((ref) {
          final dio = Dio();
          ref.onDispose(dio.close);
          return ApiClient(
            dio: dio,
            workspaceId: () => ref.read(activeWorkspaceProvider),
            authToken: () => null,
          );
        }),
      ],
      child: TranslationProvider(child: const OnboardingPreviewRoot()),
    ),
  );
}

/// The preview must not turn its forced Chat landing into the machine's persisted last-ocean choice.
/// 预览强制落 Chat，但绝不能把它写成机器级的「上次海洋」偏好。
class OnboardingPreviewOcean extends SelectedOceanController {
  @override
  OceanKind build() => OceanKind.chat;

  @override
  void select(OceanKind kind) {
    if (kind != state) state = kind;
  }
}

/// The demo app root with only the real workspace gate restored. 启用真实 workspace gate 的 demo 根。
class OnboardingPreviewRoot extends ConsumerWidget {
  const OnboardingPreviewRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final navigatorKey = ref.watch(rootNavigatorKeyProvider);
    return MaterialApp.router(
      title: context.t.coldStart.onboardingPreviewTitle,
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      darkTheme: AnTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      themeAnimationDuration: AnTheme.switchDuration,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: router,
      builder: (context, child) => AnOverlayHost(
        navigatorKey: navigatorKey,
        child: GlobalShortcuts(
          child: Focus(autofocus: true, child: WorkspaceGate(child: child!)),
        ),
      ),
    );
  }
}

/// A fresh roster every launch; creation holds for one shape beat so the commit halo is visible.
/// 每次启动都是空名册；创建保留一个形变拍点，让提交蓝光完整可见。
class OnboardingPreviewBootstrap extends WorkspaceBootstrap {
  @override
  Future<String?> build() async => null;

  @override
  Future<Workspace> create(String name) async {
    await Future<void>.delayed(AnMotion.slow);
    final now = DateTime.now().toUtc();
    final workspace = Workspace(
      id: 'ws_onboarding_preview',
      name: name,
      language: LocaleSettings.currentLocale.languageTag,
      createdAt: now,
      updatedAt: now,
    );
    setActiveWorkspace(ref, workspace.id);
    ref.read(activeWorkspaceNameProvider.notifier).set(workspace.name);
    state = AsyncData(workspace.id);
    return workspace;
  }
}
