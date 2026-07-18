import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnLedgerRow (WRK-066 族四) — the 右缘铁线 rule (拍板 #4): every row's meta right edge lands flush on
// ONE vertical line (the row's right edge), even under LOOSE constraints (the gallery's
// Align(centerLeft) host) and regardless of primary/chip widths. The original two-flex layout
// (Flexible primary + Spacer) split the slack and left the metas ragged — this test pins the fix.
// 右缘铁线回归:loose 约束下、不论 primary/chip 宽,meta 右缘齐一条线(行右缘)。

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  testWidgets('meta right edges form ONE line under loose constraints (右缘铁线)', (tester) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerLeft, // loose host — the gallery cell's shape 宽松宿主(画廊同形)
            child: SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  AnLedgerRow(
                      lead: AnStatusDot(AnStatus.done),
                      primary: 'exec_short',
                      chips: [AnChip('42ms')],
                      meta: '2 分钟前'),
                  AnLedgerRow(
                      lead: AnStatusDot(AnStatus.err),
                      primary: 'exec_a_much_longer_primary_id_here',
                      meta: '5 分钟前'),
                  AnLedgerRow(primary: 'node.approval_gate', meta: '等待审批'),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final metas = ['2 分钟前', '5 分钟前', '等待审批']
        .map((t) => tester.getTopRight(find.text(t)).dx)
        .toList();
    // All three right edges equal — one vertical line. 三条右缘相等=一条线。
    expect(metas[1], moreOrLessEquals(metas[0], epsilon: 0.5));
    expect(metas[2], moreOrLessEquals(metas[0], epsilon: 0.5));
  });
  testWidgets('lead dot centres on the FIRST line of a two-line row (用户 0717 红点漂移 bug)',
      (tester) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: const Scaffold(
          body: AnLedgerRow(
            lead: AnStatusDot(AnStatus.err),
            primary: 'webhook · /invoice',
            sub: 'HTTP 400 Bad Request',
            subTone: AnTone.danger,
          ),
        ),
      ),
    ));
    final dot = tester.getRect(find.byType(AnStatusDot));
    final primary = tester.getRect(find.text('webhook · /invoice'));
    // The dot's centre must sit within the primary line's vertical band — the old s8 pad hung it
    // ~4px above the text. 点心必须落在主文行的纵向带内——旧 s8 顶距把它吊在文字上方。
    expect(dot.center.dy, greaterThanOrEqualTo(primary.top),
        reason: '点不得高于主文行顶(红点漂移即此形)');
    expect(dot.center.dy, lessThanOrEqualTo(primary.bottom), reason: '点不得低于主文行底');
    expect((dot.center.dy - primary.center.dy).abs(), lessThanOrEqualTo(3),
        reason: '点与主文首行近同心(±3px)');
  });


  testWidgets('row contents inset s8 from BOTH edges; the disclosure body insets EQUALLY '
      '(WRK-070 0718 假想框:两边退一样)', (tester) async {
    await tester.pumpWidget(TranslationProvider(
      child: MaterialApp(
        theme: AnTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnLedgerRow(
                    lead: const AnStatusDot(AnStatus.done),
                    primary: 'row',
                    measure: '42.0s',
                    onTap: () {},
                    expanded: true,
                    expandChild: const SizedBox(
                        width: double.infinity,
                        height: 20,
                        child: ColoredBox(color: Color(0xFF000000))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    final host = tester.getRect(find.byType(AnLedgerRow));
    final dot = tester.getRect(find.byType(AnStatusDot));
    final measure = tester.getRect(find.text('42.0s'));
    // Lead dot retreats from the left edge; the measure from the right — the phantom frame's s8.
    expect(dot.left - host.left, greaterThanOrEqualTo(8), reason: '点从左缘退 ≥s8');
    expect(host.right - measure.right, moreOrLessEquals(8, epsilon: 0.6), reason: '时长从右缘退 s8');
    // The expansion insets EQUALLY on both sides. 展开体两侧等退。
    final bodyRect = tester.getRect(
        find.byWidgetPredicate((w) => w is ColoredBox && w.color == const Color(0xFF000000)));
    expect(bodyRect.left - host.left, moreOrLessEquals(host.right - bodyRect.right, epsilon: 0.6),
        reason: '展开体左右退距相等(用户 0718:「两边退的距离是一样的」)');
    expect(bodyRect.left - host.left, moreOrLessEquals(8, epsilon: 0.6));
  });
}
