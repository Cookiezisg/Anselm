import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/model/status_state.dart';
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
}
