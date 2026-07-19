import 'package:anselm/core/contract/network.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/ui/panels/network_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// S5-⑪ network: the proxy fields hydrate from the backend and a save PATCHes the whole config.
// 网络:代理字段从后端水化,保存整体 PATCH。
void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('proxy fields hydrate and a save PATCHes the whole config', (tester) async {
    final repo = FixtureSettingsRepository()
      ..fixtureNetwork = const NetworkConfig(httpProxy: 'http://old:1');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: NetworkPanel())),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(NetworkPanel)));
    expect(find.text('http://old:1'), findsOneWidget, reason: '从后端水化');

    await tester.enterText(find.byType(TextField).at(0), 'http://127.0.0.1:7890');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.network.save));
    await tester.pumpAndSettle();
    expect(repo.fixtureNetwork.httpProxy, 'http://127.0.0.1:7890', reason: '整体 PATCH');
  });
}
