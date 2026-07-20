import 'package:anselm/core/design/colors.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/run/an_approval_capsule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The approval BLOCK capsule: three overlapping beats (birth→bar→block, width grows before height),
// amber dot (never danger red), NEVER auto-dismisses, ✕/verdict retreat along the same line.
// 审批块:三交叠拍宽先高后、琥珀点、绝不自动收、✕/判词同线倒放。
void main() {
  Widget host(Widget child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        home: Scaffold(body: Align(alignment: Alignment.topCenter, child: child)),
      );

  AnApprovalCapsule cap({String? verdict, VoidCallback? onDismissed, VoidCallback? onApprove}) =>
      AnApprovalCapsule(
        title: 'approve_deploy',
        question: 'Deploy **v2.4.0** to production?',
        pendingLabel: 'Awaiting approval',
        approveLabel: 'Approve',
        rejectLabel: 'Reject',
        verdict: verdict,
        onApprove: onApprove ?? () {},
        onReject: () {},
        onClose: () {},
        onDismissed: onDismissed ?? () {},
      );

  testWidgets('beats: width stretches before height; the block ends past both', (tester) async {
    await tester.pumpWidget(host(cap()));
    await tester.pump();
    Size shell() => tester.getSize(find.byType(DecoratedBox).first);
    await tester.pump(const Duration(milliseconds: 100)); // birth done, bar stretching 诞生毕,横拉中
    final bar = shell();
    expect(bar.height, lessThan(40), reason: '横拉拍里高度仍是条(≈28)');
    await tester.pump(const Duration(milliseconds: 300)); // into the height beat 纵长拍
    final mid = shell();
    expect(mid.width, greaterThan(bar.width));
    await tester.pump(const Duration(milliseconds: 500)); // settled 落定
    final full = shell();
    expect(full.height, greaterThan(mid.height), reason: '块高在宽之后长足');
    // Question + both action buttons swept out. 问题句与双钮已被扫出。
    expect(find.textContaining('Deploy'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing, reason: '纯文本预览去记号(星号 bug 不重演)');
    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('the dot is WARN amber — never danger red (分级点色铁律)', (tester) async {
    await tester.pumpWidget(host(cap()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    final c = AnTheme.light().extension<AnColors>()!;
    final dot = tester
        .widgetList<Container>(find.byType(Container))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.shape == BoxShape.circle);
    expect(dot.color, c.warn);
    expect(dot.color, isNot(c.danger));
  });

  testWidgets('NEVER auto-dismisses: still on stage far past any toast tier', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(host(cap(onDismissed: () => dismissed++)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));
    expect(dismissed, 0, reason: '审批等人决策,绝不计时溜走');
    expect(find.text('Approve'), findsOneWidget);
  });

  testWidgets('a verdict landing flashes then retreats along the same line', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(host(cap(onDismissed: () => dismissed++)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpWidget(host(cap(verdict: 'Approved', onDismissed: () => dismissed++)));
    await tester.pump();
    expect(find.text('Approved'), findsOneWidget, reason: '判词换上标题动词位');
    await tester.pump(const Duration(milliseconds: 900)); // verdict dwell 判词一拍
    await tester.pump(const Duration(milliseconds: 600)); // reverse 倒放
    await tester.pump();
    expect(dismissed, 1);
  });
}
