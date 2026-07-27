import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/spend.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/settings_repository.dart';

/// The BYOK spend card (WRK-082 H10) — the direct-connection twin of the managed free-tier quota
/// card it sits beside. Two meters, two kinds of money: the quota card answers "how much of the
/// managed allowance is left", this one answers "what have my own keys been spending".
///
/// **Its whole design is one honesty rule.** Units are TRUE — images, characters and seconds are
/// counted, not estimated — so they are rendered plainly and lead each row. Money is an ESTIMATE
/// from a hand-written price table, so it is rendered muted, prefixed with `≈`, and the card says
/// out loud that the authority is the provider's own billing console. A model the table does not
/// know shows a dash, never «$0.00»: an unpriced call is honestly unknown, and printing zero would
/// be the panel's one chance to lie about money taken with both hands.
///
/// BYOK 支出卡(H10)——它旁边那张受管免费档配额卡的**直连孪生件**。两个仪表、两种钱:配额卡答
/// 「受管额度还剩多少」,这张答「我自己的 key 花掉了什么」。
///
/// **它整个设计就是一条诚实律。** 用量**恒真**——张/字符/秒是数出来的、不是估的——故它平铺直叙、
/// 领在每行开头。金额**是估算**、出自手写价目表,故它渲成弱色、前缀 `≈`,且卡上明说权威在供应商
/// 自己的账单控制台。表不认识的模型显示一道破折号、**绝不显示「$0.00」**:没有价的调用是诚实的
/// 未知,而印一个 0,正是这张面板双手奉上的、唯一一次对钱撒谎的机会。
class SpendCard extends ConsumerWidget {
  const SpendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final c = context.colors;
    final rows = ref.watch(spendProvider);

    return AnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No refresh button, deliberately: [spendProvider] is autoDispose and refetches on every
          // panel open, and the card sitting above it already carries a «刷新» — two adjacent
          // identical labels are ambiguous to a READER, not just to a test finder.
          // **刻意不设刷新钮**:spendProvider 是 autoDispose、每次打开面板即重取;而它上面那张卡已经
          // 有一个「刷新」——两个相邻的同名按钮对**读的人**就是歧义,不只是对测试的查找器。
          Text(
            t.settings.spend.title,
            style: AnText.label.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: AnSpace.s8),
          Text(
            t.settings.spend.window,
            style: AnText.body
                .weight(AnText.emphasisWeight)
                .copyWith(color: c.ink),
          ),
          const SizedBox(height: AnSpace.s12),
          switch (rows) {
            AsyncData(:final value) when value.isEmpty => Text(
              t.settings.spend.empty,
              style: AnText.meta.copyWith(color: c.inkFaint),
            ),
            AsyncData(:final value) => _Totals(rows: value),
            AsyncError() => Text(
              t.settings.spend.unavailable,
              style: AnText.meta.copyWith(color: c.inkFaint),
            ),
            _ => const AnSkeleton.text(),
          },
          const SizedBox(height: AnSpace.s12),
          // The disclaimer is NOT fine print to be skipped — it is the reason the numbers above are
          // allowed to exist at all. 免责不是可跳过的小字——它正是上面那些数字被允许存在的理由。
          Text(
            t.settings.spend.estimateNote,
            style: AnText.meta.copyWith(color: c.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// One line per category, summed across the window. The panel deliberately does NOT chart per-day:
/// the question a user brings here is "what did my keys cost me", not "draw me a time series".
///
/// 每品类一行,窗内求和。面板**刻意不**画逐日曲线:用户带来的问题是「我的 key 花了我什么」,
/// 不是「给我画条时间序列」。
class _Totals extends StatelessWidget {
  const _Totals({required this.rows});

  final List<SpendRow> rows;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final byCategory = <String, ({int units, int est, bool anyUnpriced})>{};
    for (final r in rows) {
      final prev =
          byCategory[r.category] ?? (units: 0, est: 0, anyUnpriced: false);
      byCategory[r.category] = (
        units: prev.units + r.units,
        est: prev.est + r.estPUSD,
        // A single unpriced row taints the whole category's estimate: the sum is then a LOWER
        // BOUND, and saying so is the difference between an estimate and a wrong number.
        // 一行没有价就污染整个品类的估算:那时的和是**下界**,说出来才是估算与错数之别。
        anyUnpriced: prev.anyUnpriced || r.estPUSD == 0,
      );
    }
    const order = ['image', 'speech', 'video'];
    final present = order.where(byCategory.containsKey).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final cat in present) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AnSpace.s4),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(switch (cat) {
                    'image' => t.settings.spend.catImage,
                    'speech' => t.settings.spend.catSpeech,
                    _ => t.settings.spend.catVideo,
                  }, style: AnText.body.copyWith(color: c.ink)),
                ),
                Text(switch (cat) {
                  'image' => t.settings.spend.unitImages(
                    n: byCategory[cat]!.units,
                  ),
                  'speech' => t.settings.spend.unitChars(
                    n: byCategory[cat]!.units,
                  ),
                  _ => t.settings.spend.unitSeconds(n: byCategory[cat]!.units),
                }, style: AnText.body.copyWith(color: c.ink)),
                const Spacer(),
                Text(
                  _money(byCategory[cat]!.est, byCategory[cat]!.anyUnpriced, t),
                  style: AnText.mono.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// pUSD → «≈ $x.xx». A zero total with unpriced rows is a DASH, not «$0.00» — the table simply
  /// has no price for what was made. A non-zero total that also contains unpriced rows is marked
  /// «≥», because the true figure can only be higher.
  ///
  /// pUSD → 「≈ $x.xx」。含无价行的零总额显示**破折号**、不是「$0.00」——表里根本没有那件东西的价。
  /// 非零但**也**含无价行的总额标「≥」,因为真数只可能更高。
  static String _money(int pusd, bool anyUnpriced, Translations t) {
    if (pusd == 0) return anyUnpriced ? '—' : '≈ \$0.00';
    final usd = pusd / 1e12;
    final s = usd < 0.01 ? usd.toStringAsFixed(4) : usd.toStringAsFixed(2);
    return '${anyUnpriced ? '≥' : '≈'} \$$s';
  }
}

/// The last 30 days of direct-side generation spend. autoDispose — refetched each panel open, the
/// same discipline as the storage stat. 近 30 天直连侧生成支出;每次打开重取,与存储统计同纪律。
final spendProvider = FutureProvider.autoDispose<List<SpendRow>>(
  (ref) => ref.watch(settingsRepositoryProvider).spend(days: 30),
);
