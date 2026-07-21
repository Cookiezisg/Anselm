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

  testWidgets('roster renders; the pinned filter projects; the pin toggles in place', (
    tester,
  ) async {
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
    expect(
      repo.memories.every((m) => m.pinned),
      isTrue,
      reason: '行内 toggle 即时生效',
    );

    // The pin is a REAL control (批6 复审): button semantics + toggled state + keyboard-focusable —
    // a bare GestureDetector left setPinned's ONLY entry point keyboard-unreachable. pin 是真控件:
    // button+toggled+可聚焦(裸 GestureDetector 曾使唯一入口键盘不可达)。
    final pinNode = tester.getSemantics(pins.first);
    expect(
      pinNode,
      matchesSemantics(
        isButton: true,
        hasToggledState: true,
        isToggled: true,
        isFocusable: true,
        hasEnabledState: true,
        isEnabled: true,
        // NO hasSelectedState. This line used to read «AnInteractive 基座恒带 selected 轴» — it was
        // describing the DEFECT as though it were the design: the substrate annotated the flag on
        // every control because the prop was a non-nullable bool. A pin is `toggled`, and has no
        // selection concept at all. **不含** hasSelectedState:此处原注释写「AnInteractive 基座恒带
        // selected 轴」——那是把**缺陷**当设计描述(基座恒 annotate 是因为 prop 曾是非空 bool)。pin 是
        // toggled,根本没有「选中」这个概念。
        hasTapAction: true,
        hasFocusAction: true,
        label: t.settings.mem.pinTip,
      ),
    );
  });

  testWidgets(
    'empty roster shows a guiding lead (no tombstone) and retires filter + search',
    (tester) async {
      final repo = FixtureSettingsRepository(); // zero memories 零记忆
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      final t = Translations.of(tester.element(find.byType(MemoryPanel)));

      // The guiding invitation, NOT a «No memories yet» dead end (空态穿目标形态律). 引导句而非墓碑。
      expect(find.text(t.settings.mem.emptyLead), findsOneWidget);
      // The pinned filter + search box are noise over zero rows → they retire (零计数律). 过滤/搜索退役。
      expect(find.text(t.settings.mem.filterAll), findsNothing);
      expect(find.byType(AnInput), findsNothing, reason: '零记忆时搜索框退役');
      // The New button IS the add entry, always present. 新建钮即入口,恒在。
      expect(find.text(t.settings.mem.newMemory), findsOneWidget);
    },
  );

  testWidgets('create with the pin toggle lands a PINNED user memory', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository();
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(MemoryPanel)));

    await tester.tap(find.text(t.settings.mem.newMemory));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'safety-rule');
    await tester.enterText(find.byType(TextField).at(1), 'never rm -rf');
    await tester.enterText(find.byType(TextField).at(2), 'the verbatim body');
    // Toggle the create-only pin. 打开建时 pin(仅创建时可见)。
    expect(find.byType(AnSwitch), findsOneWidget, reason: '创建表单有 pin toggle');
    await tester.tap(find.byType(AnSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.mem.save));
    await tester.pumpAndSettle();

    final row = repo.memories.single;
    expect(row.name, 'safety-rule');
    expect(row.pinned, isTrue, reason: '建时 pin 生效');
    expect(row.source, 'user', reason: '用户手动添加 → source=user');
  });

  testWidgets('create validates the slug; a good one lands in the roster', (
    tester,
  ) async {
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
    expect(
      find.text(t.settings.mem.invalidName),
      findsOneWidget,
      reason: 'slug 就地拒绝',
    );
    expect(repo.memories, isEmpty);

    await tester.enterText(find.byType(TextField).at(0), 'good-name');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.mem.save));
    await tester.pumpAndSettle();
    expect(repo.memories.single.name, 'good-name');
    expect(find.text('good-name'), findsOneWidget, reason: '回名册即见');
  });

  testWidgets(
    'edit locks the name and NEVER unpins (F147: update omits pinned/source)',
    (tester) async {
      final repo = FixtureSettingsRepository()
        ..memories.add(
          const Memory(name: 'pinned-one', content: 'old', pinned: true),
        );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      final panelEl = tester.element(find.byType(MemoryPanel));
      final container = ProviderScope.containerOf(panelEl, listen: false);
      final t = Translations.of(panelEl);

      container
          .read(settingsDetailProvider.notifier)
          .push('memory', id: 'pinned-one');
      await tester.pumpAndSettle();
      final nameField = tester.widget<TextField>(find.byType(TextField).at(0));
      expect(nameField.enabled, isFalse, reason: '名称即文件名,编辑锁死');
      // No create-time pin toggle on edit — pin is the roster's job (F147). 编辑不显建时 pin。
      expect(
        find.byType(AnSwitch),
        findsNothing,
        reason: '编辑无建时 pin(F147 由名册 toggle 掌管)',
      );

      await tester.enterText(find.byType(TextField).at(2), 'new content');
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.settings.mem.save));
      await tester.pumpAndSettle();
      final row = repo.memories.single;
      expect(row.content, 'new content');
      expect(row.pinned, isTrue, reason: '更新绝不掉 pin(F147)');
    },
  );

  testWidgets(
    'remove drops the row from the roster (confirm dialog is overlay-owned)',
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
    },
  );
}
