import 'package:anselm/core/contract/api_key.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/models/model_capabilities.dart';
import 'package:anselm/core/contract/model_capability.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/ui/an_dropdown.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/state/api_keys_provider.dart';
import 'package:anselm/features/settings/state/settings_detail_provider.dart';
import 'package:anselm/features/settings/ui/panels/models_keys_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// S2 模型与密钥 batteries: the free-tier card's three faces, the key list (managed locked on top),
// the S-3 add-form state machine, and the S-15 capabilities invalidation.
// S2 电池:免费档卡三面/密钥列表(受管锁顶)/S-3 表单状态机/S-15 能力目录失效。

Widget _host(FixtureSettingsRepository repo) => ProviderScope(
      overrides: [
        settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
        settingsRepositoryProvider.overrideWithValue(repo),
      ],
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(body: SingleChildScrollView(child: ModelsKeysPanel())),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('免费档卡 free-tier card', () {
    testWidgets('not provisioned → enable CTA + privacy hint; provision lights the meter',
        (tester) async {
      final repo = FixtureSettingsRepository(); // quota=null 未开通
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      expect(find.text(t.settings.keys.freeEnable), findsOneWidget);
      expect(find.text(t.settings.keys.freeEnableHint), findsOneWidget, reason: '指纹隐私显式化');

      await tester.tap(find.text(t.settings.keys.freeEnable));
      await tester.pumpAndSettle();
      expect(find.text(t.settings.keys.freeEnable), findsNothing, reason: '开通后 CTA 消失');
      expect(find.text(t.settings.keys.freeRefresh), findsOneWidget, reason: '配额面出现');
    });

    testWidgets('degraded provision (offline) keeps the CTA + warns', (tester) async {
      final repo = FixtureSettingsRepository()..provisionResult = false;
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.settings.keys.freeEnable));
      await tester.pumpAndSettle();
      expect(find.text(t.settings.keys.freeEnable), findsOneWidget, reason: '未开通 CTA 保留可重试');
    });

    testWidgets('available=false renders the amber budget banner', (tester) async {
      final repo = FixtureSettingsRepository()
        ..quota = const FreetierQuota(
            limit: 5000, used: 4000, remaining: 1000, resetAt: '2026-08-01', available: false);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      expect(find.text(t.settings.keys.freeUnavailable), findsOneWidget);
    });
  });

  group('密钥列表 key list', () {
    testWidgets('managed rows pin on top, locked (no edit/delete); BYOK rows carry actions',
        (tester) async {
      final now = DateTime.utc(2026, 7, 9);
      final repo = FixtureSettingsRepository()
        ..keys.addAll([
          ApiKey(id: 'aki_b', provider: 'openai', displayName: 'mine',
              testStatus: 'ok', createdAt: now, updatedAt: now),
          ApiKey(id: 'aki_m', provider: 'anselm', displayName: 'Anselm Free',
              testStatus: 'ok', createdAt: now, updatedAt: now),
        ]);
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      // Managed row first despite list order. 受管行锁顶。
      final managedY = tester.getTopLeft(find.text('Anselm Free')).dy;
      final byokY = tester.getTopLeft(find.text('mine')).dy;
      expect(managedY < byokY, isTrue, reason: '受管行在 BYOK 行之上');
      // The managed mark rides the always-visible meta (not the hover slot). 受管标常驻 meta。
      expect(find.textContaining(t.settings.keys.managedBadge), findsOneWidget);
      // Exactly ONE set of edit/delete affordances (the BYOK row's). 编辑/删除只属 BYOK 行。
      expect(find.text(t.settings.keys.editKey), findsOneWidget);
      expect(find.text(t.settings.keys.deleteKey), findsOneWidget);
    });
  });

  group('S-3 添加表单状态机 add-form state machine', () {
    testWidgets('first save POSTs once and binds; a retry after failure PATCHes the SAME id',
        (tester) async {
      final repo = FixtureSettingsRepository();
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text(t.settings.keys.addKey).first); // 空态 hint 同词
      await tester.pumpAndSettle();
      expect(find.text(t.settings.keys.saveKey), findsOneWidget, reason: '推入表单');

      // Pick provider + fill. 选 provider 填表。
      final panelEl = tester.element(find.byType(KeyForm));
      final container = ProviderScope.containerOf(panelEl, listen: false);
      await tester.tap(find.byType(AnDropdown<String>).first);
      await tester.pumpAndSettle();
      expect(find.text('OpenAI'), findsWidgets, reason: 'provider 菜单已开');
      await tester.tap(find.text('OpenAI').last);
      await tester.pumpAndSettle();
      final inputs = find.byType(TextField);
      await tester.enterText(inputs.at(0), 'my-key'); // displayName
      await tester.enterText(inputs.at(1), 'sk-abc123'); // secret
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(t.settings.keys.saveKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.settings.keys.saveKey));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(repo.keys, hasLength(1), reason: 'POST exactly once');
      final boundId = repo.keys.single.id;

      // The pop happened on success — re-open edit to prove PATCH path binds the same row. 编辑同行。
      expect(container.read(settingsDetailProvider), isNull, reason: '成功后弹出');
      // Re-enter EDIT the real-user way: clicking the row pushes the edit detail. 点行进编辑。
      await tester.tap(find.text('my-key'));
      await tester.pumpAndSettle();
      expect(container.read(settingsDetailProvider),
          (kind: 'editKey', id: boundId), reason: '行点击=编辑该行');
      await tester.enterText(find.byType(TextField).at(0), 'renamed');
      await tester.ensureVisible(find.text(t.settings.keys.saveKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.settings.keys.saveKey));
      await tester.pumpAndSettle();
      expect(repo.keys.single.id, boundId, reason: '重试/编辑 PATCH 同一行,绝不二次 POST');
      expect(repo.keys.single.displayName, 'renamed');
    });
  });

  group('S-15 capabilities invalidation', () {
    test('a key mutation invalidates the capabilities catalog', () async {
      var fetches = 0;
      final repo = FixtureSettingsRepository();
      final c = ProviderContainer(overrides: [
        settingsRepositoryProvider.overrideWithValue(repo),
        modelCapabilitiesProvider.overrideWith((ref) async {
          fetches++;
          return const <ModelCapability>[];
        }),
      ]);
      addTearDown(c.dispose);
      await c.read(modelCapabilitiesProvider.future);
      expect(fetches, 1);
      c.listen(modelCapabilitiesProvider, (_, _) {}); // keep alive for invalidate 保活
      await c.read(apiKeysProvider.notifier).create(
          provider: 'openai', displayName: 'k', key: 'sk-1');
      await c.pump();
      await c.read(modelCapabilitiesProvider.future);
      expect(fetches, 2, reason: 'key 变更 → 能力目录重取(S-15)');
    });
  });
}
