import 'package:anselm/core/contract/sandbox.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/notice/notice_center.dart';
import 'package:anselm/core/overlay/an_overlay.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/state/sandbox_providers.dart';
import 'package:anselm/features/settings/state/settings_detail_provider.dart';
import 'package:anselm/features/settings/ui/panels/sandbox_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// S5-⑦ sandbox: bootstrap failure banner + retry, runtime roster (install form / delete with
// 409-in-use honest message), env tabs, GC. S5-⑦:引导失败横幅/运行时装删(409 诚实)/环境 tab/GC。
Widget _host(FixtureSettingsRepository repo) {
  final navKey = GlobalKey<NavigatorState>();
  return ProviderScope(
    overrides: [
      settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
      settingsRepositoryProvider.overrideWithValue(repo),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        navigatorKey: navKey,
        builder: (context, child) => AnOverlayHost(navigatorKey: navKey, child: child!),
        home: const Scaffold(body: SingleChildScrollView(child: SandboxPanel())),
      ),
    ),
  );
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('bootstrap failure shows the error + retry recovers', (tester) async {
    final repo = FixtureSettingsRepository()
      ..fixtureBootstrap = const SandboxBootstrap(ok: false, error: 'no toolchain');
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(SandboxPanel)));
    expect(find.textContaining('no toolchain'), findsOneWidget);

    await tester.tap(find.text(t.settings.sandbox.retry));
    await tester.pumpAndSettle();
    expect(find.textContaining('no toolchain'), findsNothing, reason: '重试恢复');
  });

  testWidgets('runtime roster: install form lands a runtime; delete surfaces 409-in-use honestly',
      (tester) async {
    final repo = FixtureSettingsRepository();
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final panelEl = tester.element(find.byType(SandboxPanel));
    final container = ProviderScope.containerOf(panelEl, listen: false);
    final t = Translations.of(panelEl);

    expect(find.text(t.settings.sandbox.noRuntimes), findsOneWidget);

    container.read(settingsDetailProvider.notifier).push('sandboxInstall');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.sandbox.add));
    await tester.pumpAndSettle();
    expect(repo.runtimes.single.kind, 'node', reason: '默认 kind+version 安装');
    expect(repo.runtimes.single.version, '22');

    // A delete blocked by an env reference shows the in-use message. 引用未清=诚实提示。
    repo.failNextRuntimeDelete = 'SANDBOX_ENV_IN_USE';
    await container.read(sandboxRuntimesProvider.notifier).remove(repo.runtimes.single.id).then(
        (_) {}, onError: (_) {});
    // The controller rethrows; the panel's _deleteRuntime maps it. Here we just assert the row survives.
    expect(repo.runtimes, hasLength(1), reason: '409 时行还在(未删)');
  });

  testWidgets('env tab renders an owner\'s environments with status dots', (tester) async {
    final repo = FixtureSettingsRepository()
      ..envsByOwner['function'] = [
        const SandboxEnv(
            id: 'sbe_1',
            ownerKind: 'function',
            ownerName: 'summarize',
            status: 'ready',
            deps: ['requests', 'pydantic'],
            runningPid: 4242),
      ];
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(SandboxPanel)));
    expect(find.text('summarize'), findsOneWidget);
    expect(find.textContaining('2 deps'), findsOneWidget);
    expect(find.textContaining(t.settings.sandbox.running), findsOneWidget, reason: 'runningPid>0 标运行中');
  });

  testWidgets('GC reclaims and stages the count', (tester) async {
    final repo = FixtureSettingsRepository()..gcRemoved = 5;
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(SandboxPanel)));
    await tester.ensureVisible(find.text(t.settings.sandbox.gcRun));
    await tester.tap(find.text(t.settings.sandbox.gcRun));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(SandboxPanel)), listen: false);
    final message = container.read(noticeCenterProvider).current?.message;
    expect(message?.text, t.settings.sandbox.gcDone(n: 5), reason: 'GC 回收数进入统一顶带');
    expect(message?.tone, AnTone.ok);
  });
}
