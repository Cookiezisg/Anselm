import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/api_key.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/ui/an_input.dart';
import 'package:anselm/core/ui/an_secret_field.dart';
import 'package:anselm/core/ui/an_state.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/ui/panels/models_keys_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The provider picker after H12-e: 173 providers laid out at once. The old face was a `Wrap` of logo
// tiles with no search — correct for ten, unusable for 173, and unusable in a way no pixel assertion
// notices, because it renders perfectly and just puts the vendor the user wants below the fold.
//
// H12-e 之后的供应商选择器:173 家一次铺开。旧脸是一个没有搜索的 logo `Wrap`——十家时是对的、173 家
// 时不能用,而且是**任何像素断言都注意不到**的那种不能用:它渲得好好的,只是把用户要的那家推到了屏幕外。
void main() {
  Widget host(FixtureSettingsRepository repo) => ProviderScope(
    overrides: [
      settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory()),
      settingsRepositoryProvider.overrideWithValue(repo),
    ],
    child: TranslationProvider(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: const Scaffold(body: SingleChildScrollView(child: KeyForm())),
      ),
    ),
  );

  const catalog = [
    ProviderMeta(
      name: 'openai',
      displayName: 'OpenAI',
      defaultBaseUrl: 'https://api.openai.com/v1',
      models: 41,
    ),
    // The id and the display name differ — someone who knows `togetherai` must not have to guess
    // that we render it「Together AI」. id 与显示名不同——知道 `togetherai` 的人不该还要猜。
    ProviderMeta(
      name: 'togetherai',
      displayName: 'Together AI',
      defaultBaseUrl: 'https://api.together.xyz/v1',
      curated: false,
      models: 34,
    ),
    // Reached only by the mechanical npm → dialect mapping, and its address is the customer's own.
    ProviderMeta(
      name: 'azure',
      displayName: 'Azure',
      baseUrlRequired: true,
      baseUrlHint: 'https://{resource}.openai.azure.com',
      curated: false,
      dialect: 'azure',
    ),
    // A local entry: no catalog inventory at all, so `models` is 0 = 「we do not know」.
    ProviderMeta(name: 'ollama', displayName: 'Ollama (local)'),
  ];

  Future<Translations> pump(
    WidgetTester tester, {
    List<ProviderMeta> providers = catalog,
    FixtureSettingsRepository? repo,
  }) async {
    final r = (repo ?? FixtureSettingsRepository())..providers = providers;
    await tester.pumpWidget(host(r));
    await tester.pumpAndSettle();
    return Translations.of(tester.element(find.byType(KeyForm)));
  }

  testWidgets('every provider is laid out before anything is typed', (
    tester,
  ) async {
    await pump(tester);
    for (final name in ['OpenAI', 'Together AI', 'Azure', 'Ollama (local)']) {
      expect(find.text(name), findsOneWidget, reason: '$name should be listed');
    }
  });

  testWidgets('search narrows, and matches the id as well as the name', (
    tester,
  ) async {
    await pump(tester);
    // The search box is the FIRST input on the market face — there are no others until a card is
    // picked. 搜索框是市场脸上的**第一个**输入;选中一张卡之前没有别的。
    await tester.enterText(find.byType(AnInput).first, 'togetherai');
    await tester.pumpAndSettle();
    expect(find.text('Together AI'), findsOneWidget);
    expect(find.text('OpenAI'), findsNothing);
    expect(find.text('Azure'), findsNothing);
  });

  testWidgets('no match lands the empty face, not a blank grid', (
    tester,
  ) async {
    final t = await pump(tester);
    await tester.enterText(find.byType(AnInput).first, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.byType(AnState), findsOneWidget);
    expect(find.text(t.settings.keys.noProviderMatch), findsOneWidget);
  });

  testWidgets(
    'the model count shows where we have one and is silent where we do not',
    (tester) async {
      final t = await pump(tester);
      expect(find.text(t.settings.keys.modelCount(n: 41)), findsOneWidget);
      // Ollama's 0 means「no catalog inventory」, NOT「zero models」 — printing a zero would be a fact
      // we do not have. Ollama 的 0 是「没有目录清单」、**不是**「零个模型」。
      expect(find.text(t.settings.keys.modelCount(n: 0)), findsNothing);
    },
  );

  testWidgets(
    'an untested provider says so BEFORE the user spends a key on it',
    (tester) async {
      final t = await pump(tester);
      // Two of the four fixtures are un-curated. 四个夹具里有两个未验证。
      expect(find.text(t.settings.keys.unverified), findsNWidgets(2));
    },
  );

  testWidgets(
    'picking a card advances to the form with the catalog value prefilled',
    (tester) async {
      final t = await pump(tester);
      await tester.tap(find.text('OpenAI'));
      await tester.pumpAndSettle();
      expect(find.text(t.settings.keys.secretLabel), findsOneWidget);
      expect(find.text(t.settings.keys.searchProviders), findsNothing);
      final baseUrl = tester
          .widgetList<AnInput>(find.byType(AnInput))
          .where((w) => w.controller?.text == 'https://api.openai.com/v1');
      expect(
        baseUrl,
        isNotEmpty,
        reason: 'catalog base URL should be prefilled',
      );
    },
  );

  // ── the three failure kinds (WRK-085 §7) ──

  testWidgets('an auth failure on a user-supplied address points at that field too', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..failNextKeyOp = const ApiException(
        code: 'API_KEY_TEST_FAILED',
        message: 'provider rejected the key',
        httpStatus: 422,
      );
    final t = await pump(tester, repo: repo);
    await tester.tap(find.text('Azure'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(AnInput).first, 'my azure');
    // The credential is an [AnSecretField], NOT an [AnInput]. Targeting it by index typed the key
    // into the base-URL box, left Save disabled, and made the tap a silent no-op — the first draft
    // of this test did exactly that and「passed」nothing.
    // 凭证是 [AnSecretField]、**不是** [AnInput]。按下标定位会把 key 打进 base URL 框、让保存钮保持
    // 禁用、使那一下点击成为**无声的空操作**——本测试第一稿就是这样,它「通过」了个寂寞。
    await tester.enterText(find.byType(AnSecretField), 'sk-whatever');
    await tester.enterText(
      find.byType(AnInput).at(1),
      'https://wrong.openai.azure.com',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.keys.saveKey));
    await tester.pumpAndSettle();

    // The backend's own sentence survives — it is what actually happened.
    expect(find.text('provider rejected the key'), findsOneWidget);
    // …and next to it, the thing a 401 cannot tell you: a wrong ADDRESS answers identically.
    expect(find.text(t.settings.keys.diagCheckBaseUrl), findsOneWidget);
    expect(find.text(t.settings.keys.baseUrlSuspect), findsOneWidget);
  });

  testWidgets('a failure on a provider we never tested admits that', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..failNextKeyOp = const ApiException(
        code: 'API_KEY_TEST_FAILED',
        message: 'provider rejected the key',
        httpStatus: 422,
      );
    final t = await pump(tester, repo: repo);
    // Together AI is un-curated but its base URL is OURS, so the blame cannot fall on the field —
    // which leaves the honest second line: we have never tried this one.
    // Together AI 未验证,但它的 base URL 是**我们给的**,故过错落不到那一栏上——剩下的就是那句诚实的
    // 第二行:这家我们从没试过。
    await tester.tap(find.text('Together AI'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(AnInput).first, 'my together');
    await tester.enterText(find.byType(AnSecretField), 'sk-whatever');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.keys.saveKey));
    await tester.pumpAndSettle();

    expect(find.text(t.settings.keys.diagUnverified), findsOneWidget);
    expect(find.text(t.settings.keys.diagCheckBaseUrl), findsNothing);
  });

  testWidgets('a curated provider gets no second-guessing line at all', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..failNextKeyOp = const ApiException(
        code: 'API_KEY_TEST_FAILED',
        message: 'provider rejected the key',
        httpStatus: 422,
      );
    final t = await pump(tester, repo: repo);
    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(AnInput).first, 'my openai');
    await tester.enterText(find.byType(AnSecretField), 'sk-whatever');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.settings.keys.saveKey));
    await tester.pumpAndSettle();

    expect(find.text('provider rejected the key'), findsOneWidget);
    expect(find.text(t.settings.keys.diagUnverified), findsNothing);
    expect(find.text(t.settings.keys.diagCheckBaseUrl), findsNothing);
  });
}
