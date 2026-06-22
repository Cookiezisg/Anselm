import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/shell/app_shell.dart';
import '../app/window_setup.dart';
import '../core/design/theme.dart';
import '../features/entities/data/entities_repository.dart';
import '../features/entities/state/entities_providers.dart';
import '../i18n/strings.g.dart';

/// `make demo` — the REAL app shell + features on FIXTURES, zero backend. The single demo
/// entry: it shows the actual product shape (not a throwaway mock), so every feature shows
/// here on fixtures as it lands. `make app` is the same shell with the backend sidecar.
/// `make demo`——真 app 形态 + fixture 数据、零后端。唯一 demo 入口;以后每个 feature 都在这看。
Future<void> main() async {
  await initWindow(title: 'Anselm · Demo');
  LocaleSettings.useDeviceLocale();
  runApp(
    ProviderScope(
      overrides: [
        entitiesRepositoryProvider.overrideWithValue(const FixtureEntitiesRepository()),
      ],
      child: TranslationProvider(child: const _DemoApp()),
    ),
  );
}

class _DemoApp extends StatelessWidget {
  const _DemoApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Anselm · Demo',
      theme: AnTheme.light(),
      darkTheme: AnTheme.dark(),
      themeMode: ThemeMode.light,
      locale: TranslationProvider.of(context).flutterLocale,
      supportedLocales: AppLocaleUtils.supportedLocales,
      home: const AppShell(),
    );
  }
}
