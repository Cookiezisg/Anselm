import 'package:anselm/core/contract/api_key.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_dropdown.dart';
import 'package:anselm/core/ui/an_row.dart';
import 'package:anselm/core/ui/an_section.dart';
import 'package:anselm/core/ui/an_switch.dart';
import 'package:anselm/core/contract/workspace.dart';
import 'package:anselm/core/model/model_capabilities.dart';
import 'package:anselm/core/contract/model_capability.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
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

Widget _host(
  FixtureSettingsRepository repo, {
  List<ModelCapability>? capabilities,
}) => ProviderScope(
  overrides: [
    settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
    settingsRepositoryProvider.overrideWithValue(repo),
    if (capabilities != null)
      modelCapabilitiesProvider.overrideWith((ref) async => capabilities),
  ],
  child: TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: const Scaffold(
        body: SingleChildScrollView(child: ModelsKeysPanel()),
      ),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));
  _imageRowTests();

  group('免费档卡 free-tier card', () {
    testWidgets(
      'not provisioned → enable CTA + privacy hint; provision lights the meter',
      (tester) async {
        final repo = FixtureSettingsRepository(); // quota=null 未开通
        await tester.pumpWidget(_host(repo));
        await tester.pumpAndSettle();
        expect(find.text(t.settings.keys.freeEnable), findsOneWidget);
        expect(
          find.text(t.settings.keys.freeEnableHint),
          findsOneWidget,
          reason: '指纹隐私显式化',
        );

        await tester.tap(find.text(t.settings.keys.freeEnable));
        await tester.pumpAndSettle();
        expect(
          find.text(t.settings.keys.freeEnable),
          findsNothing,
          reason: '开通后 CTA 消失',
        );
        expect(
          find.text(t.settings.keys.freeRefresh),
          findsOneWidget,
          reason: '配额面出现',
        );
      },
    );

    testWidgets('degraded provision (offline) keeps the CTA + warns', (
      tester,
    ) async {
      final repo = FixtureSettingsRepository()..provisionResult = false;
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.settings.keys.freeEnable));
      await tester.pumpAndSettle();
      expect(
        find.text(t.settings.keys.freeEnable),
        findsOneWidget,
        reason: '未开通 CTA 保留可重试',
      );
    });

    testWidgets('available=false renders the amber budget banner', (
      tester,
    ) async {
      final repo = FixtureSettingsRepository()
        ..quota = const FreetierQuota(
          limit: 5000,
          used: 4000,
          remaining: 1000,
          resetAt: '2026-08-01',
          available: false,
        );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      expect(find.text(t.settings.keys.freeUnavailable), findsOneWidget);
    });
  });

  group('密钥列表 key list', () {
    testWidgets(
      'managed rows pin on top, locked (no edit/delete); BYOK rows carry actions',
      (tester) async {
        final now = DateTime.utc(2026, 7, 9);
        final repo = FixtureSettingsRepository()
          ..keys.addAll([
            ApiKey(
              id: 'aki_b',
              provider: 'openai',
              displayName: 'mine',
              testStatus: 'ok',
              createdAt: now,
              updatedAt: now,
            ),
            ApiKey(
              id: 'aki_m',
              provider: 'anselm',
              displayName: 'Anselm Free',
              testStatus: 'ok',
              createdAt: now,
              updatedAt: now,
            ),
          ]);
        await tester.pumpWidget(_host(repo));
        await tester.pumpAndSettle();

        // Managed row first despite list order. 受管行锁顶。
        final managedY = tester.getTopLeft(find.text('Anselm Free')).dy;
        final byokY = tester.getTopLeft(find.text('mine')).dy;
        expect(managedY < byokY, isTrue, reason: '受管行在 BYOK 行之上');
        // The managed mark rides the always-visible meta (not the hover slot). 受管标常驻 meta。
        expect(
          find.textContaining(t.settings.keys.managedBadge),
          findsOneWidget,
        );
        // Edit/delete belong to the BYOK row and to NO managed row. Asserted per ROW, not by counting
        // the panel: the panel also hosts the cloned-voice card, whose rows carry their own Delete, so
        // a bare count would answer a question about the whole page instead of about these two rows.
        // 编辑/删除属 BYOK 行、且**任何**受管行都没有。**逐行**断言而非数整页:本面还住着克隆音色卡、
        // 它的行自带删除,故光数个数是在回答「整页」的问题、而不是这两行的问题。
        for (final (row, present) in [('mine', true), ('Anselm Free', false)]) {
          for (final label in [
            t.settings.keys.editKey,
            t.settings.keys.deleteKey,
          ]) {
            expect(
              find.descendant(
                of: find.widgetWithText(AnRow, row),
                matching: find.text(label),
              ),
              present ? findsOneWidget : findsNothing,
              reason: '$row · $label',
            );
          }
        }
      },
    );
  });

  group('S-3 添加表单状态机 add-form state machine', () {
    testWidgets(
      'first save POSTs once and binds; a retry after failure PATCHes the SAME id',
      (tester) async {
        final repo = FixtureSettingsRepository();
        await tester.pumpWidget(_host(repo));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text(t.settings.keys.addKey).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.settings.keys.addKey).first); // 空态 hint 同词
        await tester.pumpAndSettle();
        // ADD stage 0 (0719 重构): the vendor logo grid — no form until a provider is picked. 添加
        // 第 0 段:厂家 logo 网格,选商前无表单。
        expect(
          find.text(t.settings.keys.pickProvider),
          findsOneWidget,
          reason: '厂家网格先行',
        );
        expect(find.text(t.settings.keys.saveKey), findsNothing);

        // Pick the provider by its card + fill. 点厂家卡选商,再填表。
        final panelEl = tester.element(find.byType(KeyForm));
        final container = ProviderScope.containerOf(panelEl, listen: false);
        await tester.tap(find.text('OpenAI'));
        await tester.pumpAndSettle();
        expect(
          find.text(t.settings.keys.saveKey),
          findsOneWidget,
          reason: '选商后进表单',
        );
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
        expect(container.read(settingsDetailProvider), (
          kind: 'editKey',
          id: boundId,
          category: null,
        ), reason: '行点击=编辑该行');
        await tester.enterText(find.byType(TextField).at(0), 'renamed');
        await tester.ensureVisible(find.text(t.settings.keys.saveKey));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.settings.keys.saveKey));
        await tester.pumpAndSettle();
        expect(
          repo.keys.single.id,
          boundId,
          reason: '重试/编辑 PATCH 同一行,绝不二次 POST',
        );
        expect(repo.keys.single.displayName, 'renamed');
      },
    );
  });

  group('S-15 capabilities invalidation', () {
    test('a key mutation invalidates the capabilities catalog', () async {
      var fetches = 0;
      final repo = FixtureSettingsRepository();
      final c = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
          modelCapabilitiesProvider.overrideWith((ref) async {
            fetches++;
            return const <ModelCapability>[];
          }),
        ],
      );
      addTearDown(c.dispose);
      await c.read(modelCapabilitiesProvider.future);
      expect(fetches, 1);
      c.listen(
        modelCapabilitiesProvider,
        (_, _) {},
      ); // keep alive for invalidate 保活
      await c
          .read(apiKeysProvider.notifier)
          .create(provider: 'openai', displayName: 'k', key: 'sk-1');
      await c.pump();
      await c.read(modelCapabilitiesProvider.future);
      expect(fetches, 2, reason: 'key 变更 → 能力目录重取(S-15)');
    });
  });

  group('默认模型模式 default model mode', () {
    testWidgets(
      'Anselm Auto applies directly; external native controls stay behind an explicit choice',
      (tester) async {
        final repo = FixtureSettingsRepository();
        const managed = ModelCapability(
          apiKeyId: 'aki_anselm',
          keyName: 'Anselm Free',
          provider: 'anselm',
          modelId: 'anselm-auto',
          displayName: 'Anselm Auto',
          textInputLimit: 1000000,
          multimodalInputLimit: 262144,
        );
        const external = ModelCapability(
          apiKeyId: 'aki_openai',
          keyName: 'Personal OpenAI',
          provider: 'openai',
          modelId: 'gpt-test',
          displayName: 'Test model',
          knobs: [
            ModelKnob(
              key: 'reasoning_effort',
              type: 'enum',
              values: ['low', 'high'],
              defaultValue: 'low',
            ),
          ],
        );
        await tester.pumpWidget(
          _host(repo, capabilities: const [managed, external]),
        );
        await tester.pumpAndSettle();

        // Scroll it in first: this panel's height is not a constant (an empty-state hint above can
        // push it below the fold), and `tap` on an off-screen target only WARNS.
        // 先滚入视口:本面板高度不是常量(上方空态多一行 hint 就会把它挤下折叠线),而 `tap` 对视口外目标
        // **只警告不报错**。
        await tester.ensureVisible(
          find.text(t.settings.keys.pickerChange).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.settings.keys.pickerChange).first);
        await tester.pumpAndSettle();

        expect(find.text(t.settings.keys.anselmAuto), findsOneWidget);
        expect(find.text(t.settings.keys.externalModel), findsOneWidget);
        expect(
          find.text(t.settings.keys.stageCredential),
          findsNothing,
          reason: '未选外部模式时不暴露凭证、模型或原生参数选择器',
        );

        await tester.tap(find.text(t.settings.keys.anselmAuto));
        await tester.pumpAndSettle();
        expect(
          repo.workspace.defaultDialogue,
          const ModelRef(apiKeyId: 'aki_anselm', modelId: 'anselm-auto'),
        );

        // Scroll it in first: this panel's height is not a constant (an empty-state hint above can
        // push it below the fold), and `tap` on an off-screen target only WARNS.
        // 先滚入视口:本面板高度不是常量(上方空态多一行 hint 就会把它挤下折叠线),而 `tap` 对视口外目标
        // **只警告不报错**。
        await tester.ensureVisible(
          find.text(t.settings.keys.pickerChange).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.settings.keys.pickerChange).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.settings.keys.externalModel));
        await tester.pumpAndSettle();
        expect(
          find.text(t.settings.keys.stageCredential),
          findsOneWidget,
          reason: '外部路线才进入原有的凭证→模型→确认参数流程',
        );

        await tester.tap(find.text('Personal OpenAI'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Test model'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Test model'));
        await tester.pumpAndSettle();
        expect(find.text(t.settings.keys.nativeSettings), findsOneWidget);

        await tester.tap(find.byType(AnSwitch).last);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).last,
          '{"model":"other"}',
        );
        await tester.tap(find.text(t.settings.keys.nativeSettingsApply));
        await tester.pumpAndSettle();
        expect(
          find.text(t.settings.keys.nativeSettingsUnsupported),
          findsOneWidget,
          reason: '高级 JSON 不能越过公开旋钮去重写模型或请求主体',
        );
        await tester.enterText(
          find.byType(TextField).last,
          '{"reasoning_effort":"high"}',
        );
        await tester.tap(find.text(t.settings.keys.nativeSettingsApply));
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.settings.keys.pickerApply));
        await tester.pumpAndSettle();
        expect(
          repo.workspace.defaultDialogue,
          const ModelRef(
            apiKeyId: 'aki_openai',
            modelId: 'gpt-test',
            options: {'reasoning_effort': 'high'},
          ),
          reason: '高级 JSON 与通用旋钮共用同一份持久化 options',
        );
      },
    );
  });

  group('provider 类别拆分 category split (WRK-077 施工序⑪)', () {
    testWidgets(
      'model section shows only llm-category keys; search section only search-category keys',
      (tester) async {
        final now = DateTime.utc(2026, 7, 25);
        final repo = FixtureSettingsRepository()
          ..keys.addAll([
            ApiKey(
              id: 'aki_openai',
              provider: 'openai',
              displayName: 'my-openai',
              testStatus: 'ok',
              createdAt: now,
              updatedAt: now,
            ),
            ApiKey(
              id: 'aki_brave',
              provider: 'brave',
              displayName: 'my-brave',
              testStatus: 'ok',
              createdAt: now,
              updatedAt: now,
            ),
          ]);
        await tester.pumpWidget(_host(repo));
        await tester.pumpAndSettle();

        final modelSection = find.byWidgetPredicate(
          (w) => w is AnSection && w.label == t.settings.keys.modelKeysSection,
        );
        final searchSection = find.byWidgetPredicate(
          (w) => w is AnSection && w.label == t.settings.keys.searchSection,
        );
        expect(modelSection, findsOneWidget);
        expect(searchSection, findsOneWidget);

        expect(
          find.descendant(of: modelSection, matching: find.text('my-openai')),
          findsOneWidget,
          reason: 'llm 类 key 落模型密钥区',
        );
        expect(
          find.descendant(of: modelSection, matching: find.text('my-brave')),
          findsNothing,
          reason: 'search 类 key 不得混进模型密钥区',
        );
        expect(
          find.descendant(of: searchSection, matching: find.text('my-brave')),
          findsOneWidget,
          reason: 'search 类 key 落搜索密钥区',
        );
        expect(
          find.descendant(of: searchSection, matching: find.text('my-openai')),
          findsNothing,
          reason: 'llm 类 key 不得混进搜索密钥区',
        );
      },
    );

    testWidgets(
      'ADD stage-0 logo grid filters to the category it was opened from',
      (tester) async {
        final repo = FixtureSettingsRepository();
        await tester.pumpWidget(_host(repo));
        await tester.pumpAndSettle();

        // Model keys' "+ 添加" (first on screen) → llm-only grid. 模型密钥「+ 添加」(屏上第一个)→仅 llm。
        await tester.ensureVisible(find.text(t.settings.keys.addKey).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.settings.keys.addKey).first);
        await tester.pumpAndSettle();
        expect(find.text('OpenAI'), findsOneWidget);
        expect(find.text('DeepSeek'), findsOneWidget);
        expect(
          find.text('Brave Search'),
          findsNothing,
          reason: '模型添加流的厂家网格不该混进搜索厂家',
        );
        await tester.tap(find.text(t.settings.keys.cancel));
        await tester.pumpAndSettle();

        // Search keys' "+ 添加" (last on screen) → search-only grid. 搜索密钥「+ 添加」(屏上最后一
        // 个)→仅 search。
        await tester.ensureVisible(find.text(t.settings.keys.addKey).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(t.settings.keys.addKey).last);
        await tester.pumpAndSettle();
        expect(find.text('Brave Search'), findsOneWidget);
        expect(find.text('OpenAI'), findsNothing, reason: '搜索添加流的厂家网格不该混进模型厂家');
        expect(find.text('DeepSeek'), findsNothing);
      },
    );

    testWidgets(
      'the default-search dropdown only offers probed-OK keys; unprobed rows say so',
      (tester) async {
        final now = DateTime.utc(2026, 7, 25);
        final repo = FixtureSettingsRepository()
          ..keys.addAll([
            ApiKey(
              id: 'aki_brave_ok',
              provider: 'brave',
              displayName: 'brave-ok',
              testStatus: 'ok',
              createdAt: now,
              updatedAt: now,
            ),
            ApiKey(
              // testStatus defaults to 'pending' — the not-yet-probed row. testStatus 默认 pending。
              id: 'aki_brave_pending',
              provider: 'brave',
              displayName: 'brave-pending',
              createdAt: now,
              updatedAt: now,
            ),
          ]);
        await tester.pumpWidget(_host(repo));
        await tester.pumpAndSettle();

        // Both rows render — the honesty patch EXPLAINS, never hides. 两行都渲——诚实补丁只解释、不隐藏。
        expect(find.text('brave-ok'), findsOneWidget);
        expect(find.text('brave-pending'), findsOneWidget);

        // The not-probed hint sits under exactly the pending row. 未过测提示只挂未过测那行。
        expect(
          find.text(t.settings.keys.searchKeyNotProbedHint),
          findsOneWidget,
        );

        final dropdown = tester.widget<AnDropdown<String>>(
          find.byType(AnDropdown<String>),
        );
        final offeredIds = dropdown.options.map((o) => o.value).toSet();
        expect(
          offeredIds.contains('aki_brave_ok'),
          isTrue,
          reason: '探测通过的 key 进候选',
        );
        expect(
          offeredIds.contains('aki_brave_pending'),
          isFalse,
          reason: '未探测通过的 key 不得进默认候选(诚实补丁)',
        );
      },
    );
  });
}

// ── WRK-082 批B:图像生成场景行 image scenario row ──────────────────────────────
ApiKey _key(String id, String provider, {String status = 'ok'}) => ApiKey(
  id: id,
  provider: provider,
  displayName: '$provider key',
  testStatus: status,
  createdAt: DateTime(2026, 7, 1),
  updatedAt: DateTime(2026, 7, 1),
);

void _imageRowTests() {
  group('图像生成场景行 image scenario row', () {
    testWidgets('honest absence: no capable key → how-to hint + add-key', (
      tester,
    ) async {
      final repo = FixtureSettingsRepository();
      repo.keys.add(_key('aki_d', 'deepseek')); // text-only provider 纯文本家
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(find.text('图像生成'), findsOneWidget);
      // All THREE generation rows are unset, so all three read「自动」— the count is the
      // assertion: a scenario row that silently shared another's state would show fewer.
      // 三个生成行都未设,故都读「自动」——**数量**就是断言:一个静默共用了别人状态的场景行会让这里少一个。
      expect(find.text('自动(免费档优先)'), findsNWidgets(3));
      await tester.ensureVisible(
        find.byKey(const ValueKey('imageDefaultToggle')),
      );
      await tester.tap(find.byKey(const ValueKey('imageDefaultToggle')));
      await tester.pumpAndSettle();
      expect(find.text('还没有能出图的密钥'), findsOneWidget);
      expect(find.textContaining('出图工具会自动出现'), findsOneWidget);
    });

    testWidgets('capable keys become candidates; picking one PUTs the scenario', (
      tester,
    ) async {
      final repo = FixtureSettingsRepository();
      repo.keys.add(_key('aki_o', 'openai'));
      repo.keys.add(_key('aki_z', 'zhipu', status: 'failed')); // untested 落选
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('imageDefaultToggle')),
      );
      await tester.tap(find.byKey(const ValueKey('imageDefaultToggle')));
      await tester.pumpAndSettle();

      // Only the tested openai key is offered, with its provider default model.
      // 只有已探测 openai key 成为候选,带该家默认生成模型。
      final candidate = find.textContaining('gpt-image-2');
      expect(candidate, findsOneWidget);
      expect(find.textContaining('cogview-4'), findsNothing);

      await tester.ensureVisible(candidate);
      await tester.tap(candidate);
      await tester.pumpAndSettle();
      // The fixture repo records the PUT: the row summary now shows the selection.
      // fixture 仓记下 PUT:行摘要显示所选。
      expect(find.textContaining('gpt-image-2'), findsOneWidget);
      // The IMAGE row's summary changed; speech and video are still unset, so exactly two「自动」
      // remain. Asserting "none" here would silently pass if the rows shared state.
      // **图像**行的摘要变了;语音与视频仍未设,故恰剩两个「自动」。此处若断言「一个都不剩」,各行共用
      // 状态时会静默通过。
      expect(find.text('自动(免费档优先)'), findsNWidgets(2));
    });

    testWidgets('speech is its OWN row: an image-capable key does not fill it', (
      tester,
    ) async {
      // A key that can DRAW need not be able to SPEAK. The two rows filter independently, and a
      // shared candidate list would offer a picture model as a voice.
      // 能**画**的 key 未必能**说**。两行各自独立过滤,共用候选表会把一个出图模型当音色供出来。
      final repo = FixtureSettingsRepository();
      repo.keys.add(_key('aki_o', 'openai'));
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      expect(find.text('语音合成'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('speechDefaultToggle')),
      );
      await tester.tap(find.byKey(const ValueKey('speechDefaultToggle')));
      await tester.pumpAndSettle();

      // The speech picker offers the TTS model, never the image one.
      // 语音选择器给的是 TTS 模型、绝不是图像那个。
      final candidate = find.textContaining('gpt-4o-mini-tts');
      expect(candidate, findsOneWidget);
      expect(find.textContaining('gpt-image-2'), findsNothing);

      await tester.ensureVisible(candidate);
      await tester.tap(candidate);
      await tester.pumpAndSettle();
      expect(find.textContaining('gpt-4o-mini-tts'), findsOneWidget);
    });

    testWidgets(
      'honest absence is per-capability: a drawing-only key leaves speech empty',
      (tester) async {
        // zhipu can do both, deepseek neither — but the point is the SET is consulted per row.
        final repo = FixtureSettingsRepository();
        repo.keys.add(_key('aki_d', 'deepseek'));
        await tester.pumpWidget(_host(repo));
        await tester.pumpAndSettle();

        await tester.ensureVisible(
          find.byKey(const ValueKey('speechDefaultToggle')),
        );
        await tester.tap(find.byKey(const ValueKey('speechDefaultToggle')));
        await tester.pumpAndSettle();
        expect(find.text('当前没有能合成语音的 key'), findsOneWidget);
      },
    );

    testWidgets('video offers the managed option like image and speech', (
      tester,
    ) async {
      // The managed key must appear as a video candidate. This expectation was the exact inverse
      // until the user put video in the free tier (WRK-082 H1); the row now behaves like its two
      // siblings, and a user with no key of their own can pick a video default and get a video.
      // 受管 key 必须作为视频候选出现。在用户把视频放进免费档(H1)之前,这条期望是**完全相反**的;
      // 该行现在与两个兄弟行为一致,一个自己没有 key 的用户能选一个视频默认、并真拿到片子。
      final repo = FixtureSettingsRepository();
      repo.keys.add(_key('aki_m', 'anselm'));
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('videoDefaultToggle')),
      );
      await tester.tap(find.byKey(const ValueKey('videoDefaultToggle')));
      await tester.pumpAndSettle();
      expect(find.text('当前没有能生成视频的 key'), findsNothing);

      // …while the SAME key is a perfectly good image candidate.
      // The managed row is labelled the same way in all three scenarios — the tables differ only
      // in the direct-connection providers underneath it.
      // 受管行在三个场景里的标签**完全相同**——三张表的区别只在它下面那些直连家。
      expect(find.text('Anselm 免费档(网关代管)'), findsOneWidget);

      // …and the SAME key is still a perfectly good image candidate.
      await tester.ensureVisible(
        find.byKey(const ValueKey('imageDefaultToggle')),
      );
      await tester.tap(find.byKey(const ValueKey('imageDefaultToggle')));
      await tester.pumpAndSettle();
      expect(find.text('还没有能出图的密钥'), findsNothing);
    });
  });
}
