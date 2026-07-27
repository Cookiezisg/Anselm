import 'package:anselm/core/contract/spend.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/features/settings/data/settings_repository.dart';
import 'package:anselm/features/settings/ui/panels/spend_card.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The spend card's contract is an HONESTY contract, so every test here is about what the card is
// allowed to SAY, not about what widgets exist. Units are counted and must be printed as counted;
// money is an estimate and must never be printed as if it were a bill.
//
// 支出卡的契约是一份**诚实**契约,故这里每条测的都是「卡**能说什么**」、不是「有哪些 widget」。
// 用量是数出来的、必须照数printed;金额是估算、绝不能印得像一张账单。

Widget _host(FixtureSettingsRepository repo) => ProviderScope(
  overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
  child: TranslationProvider(
    child: MaterialApp(
      theme: AnTheme.light(),
      home: const Scaffold(body: SizedBox(width: 520, child: SpendCard())),
    ),
  ),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('en'));

  testWidgets('counted units are printed as counted', (tester) async {
    final repo = FixtureSettingsRepository()
      ..fixtureSpend = const [
        SpendRow(
          date: '2026-07-28',
          category: 'image',
          provider: 'qwen',
          model: 'qwen-image-2.0',
          units: 12,
          estPUSD: 420000000000,
        ),
      ];
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    expect(find.text('12 images'), findsOneWidget);
    expect(find.text('≈ \$0.42'), findsOneWidget);
  });

  // THE test of this card. An unpriced model must read as unknown, never as free — printing
  // «$0.00» for money that was really taken is the one lie this panel is positioned to tell.
  // 本卡**那条**测试。没有价的模型必须读作「未知」、绝不是「免费」——为真的花掉的钱印「$0.00」,
  // 是这张面板所处位置能撒的唯一一个谎。
  testWidgets('an unpriced model shows a dash, never \$0.00', (tester) async {
    final repo = FixtureSettingsRepository()
      ..fixtureSpend = const [
        SpendRow(
          date: '2026-07-28',
          category: 'image',
          provider: 'openai',
          model: 'unlisted',
          units: 3,
          estPUSD: 0,
        ),
      ];
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    expect(
      find.text('3 images'),
      findsOneWidget,
    ); // the TRUE half is still shown
    expect(find.text('—'), findsOneWidget);
    expect(find.text('≈ \$0.00'), findsNothing);
  });

  // A category containing one unpriced row makes its total a LOWER BOUND, and the card says so
  // with «≥». Summing a known price with an unknown one and calling the result «≈» would quietly
  // under-report real money.
  // 某品类里只要有一行没价,它的总额就是**下界**,卡用「≥」说出来。把已知价与未知价相加还标「≈」,
  // 会静悄悄地少报真金白银。
  testWidgets('a partially priced category is marked as a lower bound', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()
      ..fixtureSpend = const [
        SpendRow(
          date: '2026-07-28',
          category: 'video',
          provider: 'qwen',
          model: 'wan2.7-t2v',
          units: 5,
          estPUSD: 415000000000,
        ),
        SpendRow(
          date: '2026-07-28',
          category: 'video',
          provider: 'google',
          model: 'veo-unlisted',
          units: 5,
          estPUSD: 0,
        ),
      ];
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    expect(find.text('10 seconds'), findsOneWidget);
    expect(find.textContaining('≥'), findsOneWidget);
  });

  testWidgets('an empty ledger says so instead of showing zeroes', (
    tester,
  ) async {
    final repo = FixtureSettingsRepository()..fixtureSpend = const [];
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Nothing generated with your own keys'),
      findsOneWidget,
    );
  });

  // The disclaimer is load-bearing: without it the numbers above read as a bill.
  // 免责是**承重**的:少了它,上面那些数字读起来就是一张账单。
  testWidgets('the estimate disclaimer is always present', (tester) async {
    final repo = FixtureSettingsRepository();
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('ESTIMATE'), findsOneWidget);
    expect(find.textContaining('billing console'), findsOneWidget);
  });
}
