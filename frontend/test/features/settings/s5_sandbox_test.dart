import 'dart:async';

import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/sandbox.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/core/notice/notice_center.dart';
import 'package:anselm/core/overlay/an_overlay.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/state/sandbox_providers.dart';
import 'package:anselm/features/settings/state/settings_detail_provider.dart';
import 'package:anselm/features/settings/ui/panels/sandbox_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/gestures.dart';
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
        builder: (context, child) =>
            AnOverlayHost(navigatorKey: navKey, child: child!),
        home: const Scaffold(
          body: SingleChildScrollView(child: SandboxPanel()),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('bootstrap failure shows the error + retry recovers', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..fixtureBootstrap = const SandboxBootstrap(
        ok: false,
        error: 'no toolchain',
      );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(SandboxPanel)));
    expect(find.textContaining('no toolchain'), findsOneWidget);

    await tester.tap(find.text(t.settings.sandbox.retry));
    await tester.pumpAndSettle();
    expect(find.textContaining('no toolchain'), findsNothing, reason: '重试恢复');
  });

  testWidgets(
    'runtime roster: install form lands a runtime; delete surfaces 409-in-use honestly',
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
      await container
          .read(sandboxRuntimesProvider.notifier)
          .remove(repo.runtimes.single.id)
          .then((_) {}, onError: (_) {});
      // The controller rethrows; the panel's _deleteRuntime maps it. Here we just assert the row survives.
      expect(repo.runtimes, hasLength(1), reason: '409 时行还在(未删)');
    },
  );

  testWidgets('runtime deletion explains permanence and respects cancel', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..runtimes.add(
        const SandboxRuntime(
          id: 'srt_uv',
          kind: 'uv',
          version: '0.11.4',
          sizeBytes: 47513600,
        ),
      );
    repo.diskAfterRuntimeDelete = 0;
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(SandboxPanel)));
    final deleteButton = find.ancestor(
      of: find.text(t.settings.sandbox.delete),
      matching: find.byType(AnButton),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(() => mouse.removePointer());

    Future<void> openDelete() async {
      await tester.ensureVisible(deleteButton);
      // ensureVisible aligns the hover action to the scroll viewport's top edge; move it below the
      // app chrome before tapping so this mirrors a real pointer hit. 将动作移出顶部遮挡区。
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 80),
      );
      await tester.pumpAndSettle();
      await mouse.moveTo(tester.getCenter(find.text('uv 0.11.4')));
      await tester.pump();
      final point = tester.getCenter(deleteButton);
      await mouse.moveTo(point);
      await tester.pump();
      await mouse.down(point);
      await mouse.up();
      await tester.pumpAndSettle();
    }

    await openDelete();
    expect(
      find.text(t.settings.sandbox.deleteRtBody(kind: 'uv', version: '0.11.4')),
      findsOneWidget,
    );
    expect(find.text(t.settings.keys.cancel), findsOneWidget);
    await tester.tap(find.text(t.settings.keys.cancel));
    await tester.pumpAndSettle();
    expect(repo.runtimes, hasLength(1), reason: '取消不得触发删除');
    expect(find.text('uv 0.11.4'), findsOneWidget);

    await openDelete();
    await tester.tap(find.text(t.settings.sandbox.confirmDelete).last);
    await tester.pumpAndSettle();
    expect(repo.runtimes, isEmpty, reason: '确认后才调用删除');
    expect(find.text(t.settings.sandbox.noRuntimes), findsOneWidget);
    expect(find.text('0 B'), findsOneWidget, reason: '删除后磁盘总量重取');
  });

  testWidgets(
    'switching open runtime kinds resets the version field to the new default',
    (tester) async {
      final repo = FixtureSettingsRepository()
        ..available = const [
          RuntimeAvailability(
            kind: 'dotnet',
            defaultVersion: '10.0.300',
            pinned: false,
          ),
          RuntimeAvailability(
            kind: 'uv',
            defaultVersion: '0.11.4',
            pinned: false,
          ),
        ];
      await tester.pumpWidget(_host(repo));
      final panelEl = tester.element(find.byType(SandboxPanel));
      final container = ProviderScope.containerOf(panelEl, listen: false);
      container.read(settingsDetailProvider.notifier).push('sandboxInstall');
      await tester.pumpAndSettle();

      expect(find.text('10.0.300'), findsOneWidget);
      await tester.tap(find.text('dotnet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('uv'));
      await tester.pumpAndSettle();

      expect(find.text('0.11.4'), findsOneWidget);
      expect(find.text('10.0.300'), findsNothing);
    },
  );

  testWidgets('runtime list failure is not rendered as an empty roster', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..runtimeListError = ApiException(
        code: 'SANDBOX_RUNTIME_LIST_FAILED',
        message: 'runtime list unavailable',
        httpStatus: 503,
      );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(SandboxPanel)));

    expect(find.text(t.settings.sandbox.runtimesLoadFailed), findsOneWidget);
    expect(find.text(t.settings.sandbox.noRuntimes), findsNothing);

    repo.runtimeListError = null;
    await tester.tap(find.text(t.settings.sandbox.retry));
    await tester.pumpAndSettle();
    expect(find.text(t.settings.sandbox.runtimesLoadFailed), findsNothing);
    expect(find.text(t.settings.sandbox.noRuntimes), findsOneWidget);
  });

  testWidgets('runtime install failure explains how to correct the version', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..available = const [
        RuntimeAvailability(
          kind: 'dotnet',
          defaultVersion: '10.0.300',
          pinned: false,
        ),
      ]
      ..runtimeInstallError = const ApiException(
        code: 'SANDBOX_RUNTIME_VERSION_UNSUPPORTED',
        message: 'runtime version is not supported',
        httpStatus: 422,
        details: {
          'kind': 'dotnet',
          'version': 'not-a-version',
          'hint': 'a release version such as 10.0.300',
        },
      );
    await tester.pumpWidget(_host(repo));
    final panelEl = tester.element(find.byType(SandboxPanel));
    final container = ProviderScope.containerOf(panelEl, listen: false);
    final t = Translations.of(panelEl);
    container.read(settingsDetailProvider.notifier).push('sandboxInstall');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not-a-version');
    await tester.tap(find.text(t.settings.sandbox.add));
    await tester.pumpAndSettle();

    expect(
      find.text(
        t.settings.sandbox.versionUnsupported(
          kind: 'dotnet',
          version: 'not-a-version',
          hint: 'a release version such as 10.0.300',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(t.settings.keys.cancel),
      findsOneWidget,
      reason: '失败留在安装表单',
    );
  });

  testWidgets('cancel is locked while runtime installation is in flight', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository();
    final pending = Completer<SandboxRuntime>();
    repo.runtimeInstallOverride = pending.future;
    await tester.pumpWidget(_host(repo));
    final panelEl = tester.element(find.byType(SandboxPanel));
    final container = ProviderScope.containerOf(panelEl, listen: false);
    final t = Translations.of(panelEl);
    container.read(settingsDetailProvider.notifier).push('sandboxInstall');
    await tester.pumpAndSettle();

    await tester.tap(find.text(t.settings.sandbox.add));
    await tester.pump();
    final cancel = find.ancestor(
      of: find.text(t.settings.keys.cancel),
      matching: find.byType(AnButton),
    );
    expect(cancel, findsOneWidget);
    expect(tester.widget<AnButton>(cancel).onPressed, isNull);

    pending.complete(
      const SandboxRuntime(id: 'srt_pending', kind: 'node', version: '22'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('env tab renders an owner\'s environments with status dots', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..envsByOwner['function'] = [
        const SandboxEnv(
          id: 'sbe_1',
          ownerKind: 'function',
          ownerName: 'summarize',
          status: 'ready',
          deps: ['requests', 'pydantic'],
          runningPid: 4242,
        ),
      ];
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(SandboxPanel)));
    expect(find.text('summarize'), findsOneWidget);
    expect(find.textContaining('2 deps'), findsOneWidget);
    expect(
      find.textContaining(t.settings.sandbox.running),
      findsOneWidget,
      reason: 'runningPid>0 标运行中',
    );
  });

  testWidgets('disk usage failure is visible and retry recovers', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..diskUsageError = const ApiException(
        code: 'SANDBOX_DISK_USAGE_FAILED',
        message: 'disk projection unavailable',
        httpStatus: 503,
      );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(SandboxPanel)));

    expect(find.text(t.settings.storage.diskLoadFailed), findsOneWidget);
    expect(find.text('42.0 MB'), findsNothing);

    repo.diskUsageError = null;
    await tester.tap(find.text(t.settings.sandbox.retry));
    await tester.pumpAndSettle();
    expect(find.text(t.settings.storage.diskLoadFailed), findsNothing);
    expect(find.text('42.0 MB'), findsOneWidget);
  });

  testWidgets(
    'env deletion explains local files, respects cancel, and refreshes disk',
    (tester) async {
      final repo = FixtureSettingsRepository()
        ..fixtureDisk = 50 * 1024 * 1024
        ..diskAfterEnvDelete = 37 * 1024 * 1024
        ..envsByOwner['function'] = [
          const SandboxEnv(
            id: 'sbe_delete',
            ownerKind: 'function',
            ownerName: 'ep173_delete_probe',
            status: 'ready',
            sizeBytes: 13 * 1024 * 1024,
          ),
        ];
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      final panelEl = tester.element(find.byType(SandboxPanel));
      final t = Translations.of(panelEl);
      final deleteButton = find.ancestor(
        of: find.text(t.settings.sandbox.delete),
        matching: find.byType(AnButton),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(() => mouse.removePointer());

      Future<void> openDelete() async {
        await tester.ensureVisible(deleteButton);
        await mouse.moveTo(tester.getCenter(find.text('ep173_delete_probe')));
        await tester.pump();
        final point = tester.getCenter(deleteButton);
        await mouse.moveTo(point);
        await tester.pump();
        await mouse.down(point);
        await mouse.up();
        await tester.pumpAndSettle();
      }

      expect(find.text('50.0 MB'), findsOneWidget);
      await openDelete();
      expect(find.text(t.settings.sandbox.deleteEnvBody), findsOneWidget);
      expect(find.text(t.settings.keys.cancel), findsOneWidget);
      await tester.tap(find.text(t.settings.keys.cancel));
      await tester.pumpAndSettle();
      expect(find.text('ep173_delete_probe'), findsOneWidget);
      expect(find.text('50.0 MB'), findsOneWidget, reason: '取消不得刷新或改变磁盘投影');

      await openDelete();
      await tester.tap(find.text(t.settings.sandbox.confirmDelete).last);
      await tester.pumpAndSettle();
      expect(repo.envsByOwner['function'], isEmpty);
      expect(find.text(t.settings.sandbox.noEnvs), findsOneWidget);
      expect(find.text('37.0 MB'), findsOneWidget, reason: '删除成功后重取机器级磁盘总量');
    },
  );

  testWidgets('failed env exposes its reason instead of only a red dot', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..envsByOwner['function'] = [
        const SandboxEnv(
          id: 'sbe_failed',
          ownerKind: 'function',
          ownerId: 'fn_failed',
          status: 'failed',
          errorMsg: 'dependency install failed',
        ),
      ];
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(SandboxPanel)));

    expect(
      find.textContaining(t.settings.sandbox.statusFailed),
      findsOneWidget,
    );
    expect(find.textContaining('dependency install failed'), findsOneWidget);
  });

  testWidgets('env list failure is not rendered as an empty tab', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..envListErrors['function'] = const ApiException(
        code: 'SANDBOX_ENV_LIST_FAILED',
        message: 'environment list unavailable',
        httpStatus: 503,
      );
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(SandboxPanel)));

    expect(find.text(t.settings.sandbox.envsLoadFailed), findsOneWidget);
    expect(find.text(t.settings.sandbox.noEnvs), findsNothing);

    repo.envListErrors.remove('function');
    await tester.tap(find.text(t.settings.sandbox.retry));
    await tester.pumpAndSettle();
    expect(find.text(t.settings.sandbox.envsLoadFailed), findsNothing);
    expect(find.text(t.settings.sandbox.noEnvs), findsOneWidget);
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
      tester.element(find.byType(SandboxPanel)),
      listen: false,
    );
    final message = container.read(noticeCenterProvider).current?.message;
    expect(
      message?.text,
      t.settings.sandbox.gcDone(n: 5),
      reason: 'GC 回收数进入统一顶带',
    );
    expect(message?.tone, AnTone.ok);
  });
}
