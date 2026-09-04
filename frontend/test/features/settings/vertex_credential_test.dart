import 'package:anselm/core/contract/api_key.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_input.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/ui/panels/models_keys_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Vertex is the only provider whose「key」is not a pasted string but a service-account JSON file.
// The control has to say so, because the alternative failure is silent and expensive: a user shown
// 「API key」goes hunting through their Google project for something that was never issued.
//
// Vertex 是唯一「key」不是粘贴字符串、而是服务账号 JSON 文件的一家。控件必须把这件事说出来,因为另一种
// 失败是**无声且昂贵**的:一个看见「API key」的用户会去自己的 Google 项目里翻一样**从没被签发过**的东西。
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

  Future<Translations> pump(WidgetTester tester, List<ProviderMeta> ps) async {
    final repo = FixtureSettingsRepository()..providers = ps;
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();
    return Translations.of(tester.element(find.byType(KeyForm)));
  }

  const vertex = ProviderMeta(
    name: 'google-vertex',
    displayName: 'Vertex',
    baseUrlRequired: true,
    curated: false,
    dialect: 'vertex',
    credential: 'service_account_json',
  );
  const openai = ProviderMeta(
    name: 'openai',
    displayName: 'OpenAI',
    defaultBaseUrl: 'https://api.openai.com/v1',
  );

  testWidgets(
    'a file-credential provider gets a paste area + a file picker, never an API-key box',
    (tester) async {
      final t = await pump(tester, const [vertex, openai]);
      await tester.tap(find.text('Vertex'));
      await tester.pumpAndSettle();

      expect(find.text(t.settings.keys.serviceAccountLabel), findsOneWidget);
      expect(find.text(t.settings.keys.serviceAccountPick), findsOneWidget);
      // The label the user must NOT see here — it names a thing their project never issued.
      // 用户在这里**不能**看见的那个标签——它命名的东西他的项目从没签发过。
      expect(find.text(t.settings.keys.secretLabel), findsNothing);
    },
  );

  testWidgets('an ordinary provider keeps the secret box', (tester) async {
    final t = await pump(tester, const [vertex, openai]);
    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();

    expect(find.text(t.settings.keys.secretLabel), findsOneWidget);
    expect(find.text(t.settings.keys.serviceAccountLabel), findsNothing);
  });

  testWidgets('pasting an API key where a file belongs is caught before saving', (
    tester,
  ) async {
    final t = await pump(tester, const [vertex, openai]);
    await tester.tap(find.text('Vertex'));
    await tester.pumpAndSettle();

    // The mistake this field will actually see. Caught HERE, the next chance is a token exchange
    // whose failure reads as「my Google account is broken」.
    // 这一栏真正会遇到的错误。在**这里**逮住;下一次机会是一次换 token,而它的失败读起来是
    // 「我的 Google 账号坏了」。
    // Target the service-account box by its OWN placeholder, not by position: the form also carries
    // a display-name and a base-URL input, and an index-based finder silently tests one of those
    // instead (it did, on the first draft of this test — and passed nothing).
    // 按**它自己的 placeholder** 定位服务账号框、不按位置:表单里还有显示名与 base URL 两个输入,按下标
    // 定位会静默地去测其中一个(本测试第一稿就是这样——而它什么也没测到)。
    final saBox = find.byWidgetPredicate(
      (w) =>
          w is AnInput &&
          w.placeholder == t.settings.keys.serviceAccountPlaceholder,
    );
    await tester.enterText(saBox, 'AIzaSyNotAServiceAccount');
    await tester.pumpAndSettle();
    expect(find.text(t.settings.keys.serviceAccountBad), findsOneWidget);

    final inputs = find.byType(AnInput);
    await tester.enterText(inputs.at(0), 'invalid file');
    await tester.enterText(
      inputs.at(2),
      'https://us-central1-aiplatform.googleapis.com',
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AnButton>(
            find.widgetWithText(AnButton, t.settings.keys.saveKey),
          )
          .onPressed,
      isNull,
      reason: 'invalid service-account JSON must block persistence and probing',
    );

    await tester.enterText(
      saBox,
      '{"type":"service_account","project_id":"p","private_key":123}',
    );
    await tester.pumpAndSettle();
    expect(find.text(t.settings.keys.serviceAccountBad), findsOneWidget);

    // A real service-account shape clears it.
    await tester.enterText(
      saBox,
      '{"type":"service_account","project_id":"p","private_key":"-----BEGIN PRIVATE KEY-----\\nx\\n-----END PRIVATE KEY-----\\n"}',
    );
    await tester.pumpAndSettle();
    expect(find.text(t.settings.keys.serviceAccountBad), findsNothing);
    expect(
      tester
          .widget<AnButton>(
            find.widgetWithText(AnButton, t.settings.keys.saveKey),
          )
          .onPressed,
      isNotNull,
      reason:
          'a structurally valid service-account JSON may proceed to probing',
    );
  });
}
