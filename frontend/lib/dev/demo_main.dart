import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/app_shell.dart';
import '../app/window_setup.dart';
import '../core/design/theme.dart';
import '../features/entities/data/entity_demo_fixture.dart';
import '../features/entities/data/entity_providers.dart';
import '../i18n/strings.g.dart';

/// Entry for `make demo` — the REAL app shell ([AppShell], byte-identical to `make app`) driven by
/// fake data: one ProviderScope override swaps the repository seam for the zero-backend fixtures, and
/// there is no startup gate (no sidecar to wait for). This is the single "see the real app with fake
/// data" surface — every feature that lands in [AppShell] shows up here for free. NO per-feature run
/// targets: app and demo share the shell, differing only in data source + startup.
///
/// 入口:`make demo`——真 app 壳(AppShell,与 make app 同一个),假数据驱动:一个 ProviderScope override
/// 把数据缝换成零后端 fixture,无启动门控(无 sidecar 可等)。这是唯一的「真 app + 假数据」面;凡接进
/// AppShell 的 feature 在此自动出现。绝不再加 per-feature 入口——app 与 demo 共用壳,只差数据源 + 启动。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocaleSettings.useDeviceLocaleSync();
  await initWindow(title: 'Anselm · Demo (fixtures)');
  runApp(
    ProviderScope(
      overrides: [entityRepositoryProvider.overrideWithValue(demoEntityRepository())],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const AppShell(),
        ),
      ),
    ),
  );
}
