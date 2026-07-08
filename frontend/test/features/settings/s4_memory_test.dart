import 'package:anselm/core/contract/memory.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/state/memories_provider.dart';
import 'package:anselm/features/settings/state/settings_detail_provider.dart';
import 'package:anselm/features/settings/ui/panels/memory_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// S4-⑥ batteries: roster + pinned filter + inline pin toggle, create (slug validation), edit
// (name locked; pinned survives the update — F147), delete via confirm.
// 记忆电池:名册/固定过滤/行内 pin;新建 slug 校验;编辑锁名+pinned 存活(F147);确认删除。

Widget _host(FixtureSettingsRepository repo) => ProviderScope(
      overrides: [
        settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: MemoryPanel())),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('roster renders; the pinned filter projects; the pin toggles in place',
      (tester) async {
    final repo = FixtureSettingsRepository()
      ..memories.addAll(const [
        Memory(name: 'coding-style', description: '缩进两空格', pinned: true),
        Memory(name: 'user-timezone', description: 'SGT'),
      ]);
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(MemoryPanel)));
    expect(find.text('coding-style'), findsOneWidget);
    expect(find.text('user-timezone'), findsOneWidget);

    await tester.tap(find.text(t.settings.mem.filterPinned));
    await tester.pumpAndSettle();
    expect(find.text('user-timezone'), findsNothing, reason: '固定过滤只留 pinned');

    await tester.tap(find.text(t.settings.mem.filterAll));
    await tester.pumpAndSettle();
    // Toggle the unpinned row's pin. 给未固定行上 pin。
    final pins = find.byIcon(AnIcons.pin);
    await tester.tap(pins.last);
    await tester.pumpAndSettle();
    expect(repo.memories.every((m) => m.pinned), isTrue, reason: '行内 toggle 即时生效');
  });

  testWidgets('create validates the slug; a good one lands in the roster', (tester) async {
    final repo = FixtureSettingsRepository();
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(MemoryPanel)));

    await tester.tap(find.text(t.settings.mem.newMemory));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Bad Name!');
    await tester.enterText(find.byType(TextField).at(1), 'desc');
    await tester.enterText(find.byType(TextField).at(2), 'content');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.mem.save));
    await tester.pumpAndSettle();
    expect(find.text(t.settings.mem.invalidName), findsOneWidget, reason: 'slug 就地拒绝');
    expect(repo.memories, isEmpty);

    await tester.enterText(find.byType(TextField).at(0), 'good-name');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.mem.save));
    await tester.pumpAndSettle();
    expect(repo.memories.single.name, 'good-name');
    expect(find.text('good-name'), findsOneWidget, reason: '回名册即见');
  });

  testWidgets('edit locks the name and NEVER unpins (F147: update omits pinned/source)',
      (tester) async {
    final repo = FixtureSettingsRepository()
      ..memories.add(const Memory(name: 'pinned-one', content: 'old', pinned: true));
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final panelEl = tester.element(find.byType(MemoryPanel));
    final container = ProviderScope.containerOf(panelEl, listen: false);
    final t = Translations.of(panelEl);

    container.read(settingsDetailProvider.notifier).push('memory', id: 'pinned-one');
    await tester.pumpAndSettle();
    final nameField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(nameField.enabled, isFalse, reason: '名称即文件名,编辑锁死');

    await tester.enterText(find.byType(TextField).at(2), 'new content');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.mem.save));
    await tester.pumpAndSettle();
    final row = repo.memories.single;
    expect(row.content, 'new content');
    expect(row.pinned, isTrue, reason: '更新绝不掉 pin(F147)');
  });

  testWidgets('remove drops the row from the roster (confirm dialog is overlay-owned)',
      (tester) async {
    final repo = FixtureSettingsRepository()
      ..memories.add(const Memory(name: 'doomed'));
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final panelEl = tester.element(find.byType(MemoryPanel));
    final container = ProviderScope.containerOf(panelEl, listen: false);
    expect(find.text('doomed'), findsOneWidget);

    await container.read(memoriesProvider.notifier).remove('doomed');
    await tester.pumpAndSettle();
    expect(repo.memories, isEmpty, reason: '物理删文件');
    expect(find.text('doomed'), findsNothing, reason: '名册即时消行');
  });
}
