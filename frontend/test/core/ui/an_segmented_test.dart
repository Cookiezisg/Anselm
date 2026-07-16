import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AnSegmented's a11y contract. It had TWO Semantics annotating the same flags (its own, plus
// AnInteractive's) — an INCOMPATIBLE pair, so the framework split every unselected segment into
// parent+child and stranded the LABEL on the child while `focus` stayed on the parent: keyboard-focusing
// a segment announced an UNNAMED button. Found by dumping the tree, not by reading the code.
// AnSegmented 的 a11y 契约。它曾有**两个** Semantics 标同一批旗标(自己的 + AnInteractive 的)=**不兼容**配置 →
// 框架把每个未选中段拆成父+子,label 落到子上、focus 留在父上 → 键盘聚焦念出一个**无名按钮**。靠 dump 抓到、
// 不是靠读代码。
void main() {
  Widget host(Widget child) => TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: Scaffold(body: Center(child: SizedBox(width: 300, child: child))),
        ),
      );

  Widget seg({int value = 1}) => AnSegmented<int>(
        options: const [
          AnSegmentedOption(value: 1, label: 'Alpha'),
          AnSegmentedOption(value: 2, label: 'Beta'),
        ],
        value: value,
        onChanged: (_) {},
      );

  testWidgets('every segment is ONE node that carries its own label (never an unnamed button)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(seg()));
    await tester.pumpAndSettle();

    // The focusable node itself must be the labelled one — exactly like a stock button. If the pair were
    // split again, `Beta`'s label would live on a CHILD of the node holding `focus` and this would fail.
    // **被聚焦的那个节点自己**必须带 label(一如原装按钮);若又被拆开,Beta 的 label 会落在持 focus 的节点的
    // **孩子**上,此断言即红。
    for (final label in ['Alpha', 'Beta']) {
      final d = tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData();
      expect(d.label, label, reason: '$label 的语义节点必须自带 label');
      expect(d.flagsCollection.isButton, isTrue, reason: '$label 必须读作按钮,不是纯文本');
    }
    handle.dispose();
  });

  testWidgets('only the SELECTED segment says selected; the other says nothing at all', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(seg()));
    await tester.pumpAndSettle();

    expect(tester.getSemantics(find.bySemanticsLabel('Alpha')).flagsCollection.isSelected.toBoolOrNull(),
        isTrue);
    // NOT false — an explicit false is announced as SELECTED on the pinned engine (see AnA11y.selected),
    // which on a 2-segment control would make BOTH read as selected. 不是 false:钉住的引擎会把显式 false
    // 念成「已选中」,两段控件就会**两段都**读作选中。
    expect(tester.getSemantics(find.bySemanticsLabel('Beta')).flagsCollection.isSelected.toBoolOrNull(),
        isNull, reason: '未选中段对「选中」什么都不说');
    handle.dispose();
  });

  testWidgets('the selection flag follows the value (and only one segment ever claims it)',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(seg(value: 2)));
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.bySemanticsLabel('Beta')).flagsCollection.isSelected.toBoolOrNull(),
        isTrue);
    expect(tester.getSemantics(find.bySemanticsLabel('Alpha')).flagsCollection.isSelected.toBoolOrNull(),
        isNull);
    handle.dispose();
  });

  testWidgets('picking an unselected segment fires onChanged; the selected one is inert', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(host(AnSegmented<int>(
      options: const [
        AnSegmentedOption(value: 1, label: 'Alpha'),
        AnSegmentedOption(value: 2, label: 'Beta'),
      ],
      value: 1,
      onChanged: picked.add,
    )));
    await tester.tap(find.text('Beta'));
    expect(picked, [2]);
    await tester.tap(find.text('Alpha')); // already selected → deliberately not tappable 已选中段刻意不可点
    expect(picked, [2]);
  });
}
