import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/router.dart';
import '../app/window_setup.dart';
import '../core/design/theme.dart';
import '../core/overlay/an_overlay.dart';
import '../core/router/navigation.dart';
import '../features/chat/data/chat_demo_fixture.dart';
import '../features/chat/data/chat_providers.dart';
import '../features/documents/data/document_repository.dart';
import '../features/documents/data/documents_demo_fixture.dart';
import '../features/entities/data/entity_demo_fixture.dart';
import '../features/entities/data/entity_providers.dart';
import '../i18n/strings.g.dart';
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
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocaleSync();
  await initWindow(title: 'Anselm · Demo (fixtures)');
  runApp(
    ProviderScope(
      overrides: [
        goRouterProvider.overrideWith(buildAppRouter),
        entityRepositoryProvider.overrideWithValue(demoEntityRepository()),
        chatRepositoryProvider.overrideWithValue(demoChatRepository()),
        documentsRepositoryProvider.overrideWithValue(demoDocumentsRepository()),
        mentionSourceProvider.overrideWith(entityMentionSource),
      ],
      child: TranslationProvider(child: const _DemoRoot()),
    ),
  );
}

/// The demo root — `MaterialApp.router` with the overlay host but NO gates. Mirrors `app.dart#AnApp`
/// minus AppStartupGate/WorkspaceGate. demo 根:MaterialApp.router + 浮层宿主,无门控。
class _DemoRoot extends ConsumerWidget {
  const _DemoRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final navigatorKey = ref.watch(rootNavigatorKeyProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      routerConfig: router,
      builder: (context, child) =>
          AnOverlayHost(navigatorKey: navigatorKey, child: child!),
    );
  }
}
