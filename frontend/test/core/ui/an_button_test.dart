import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Real-window regressions the matrix (fixed-width cells) missed.
void main() {
  Widget host(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    home: Scaffold(body: child),
  );

  testWidgets('block button degrades (no crash) in an unbounded-width parent', (
    tester,
  ) async {
    // A Row gives its children unbounded width; a block button there used to expand to infinity
    // and throw. Now it degrades to intrinsic. 行给子无界宽,块级钮曾撑到无穷而崩,现退化为自适应。
    await tester.pumpWidget(
      host(
        Row(
          children: [AnButton(label: 'X', block: true, onPressed: () {})],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('block button fills a bounded parent', (tester) async {
    await tester.pumpWidget(
      host(
        Center(
          child: SizedBox(
            width: 400,
            child: AnButton(label: 'Wide', block: true, onPressed: () {}),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AnButton)).width, 400);
  });

  testWidgets(
    'toggled icon button carries the a11y toggled state; off does not (A-106)',
    (tester) async {
      await tester.pumpWidget(
        host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnButton.iconOnly(
                AnIcons.bold,
                toggled: true,
                semanticLabel: 'Bold',
                onPressed: () {},
              ),
              AnButton.iconOnly(
                AnIcons.italic,
                toggled: false,
                semanticLabel: 'Italic',
                onPressed: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      // NO hasSelectedState: a toggle's state is `toggled`, and this button has no selection concept at
      // all — the flag used to ride along because AnInteractive.selected was a non-nullable bool that
      // always annotated. This assertion carried `hasSelectedState: true` and so was pinning the defect
      // in place. 无 hasSelectedState:开关的态是 toggled,此钮**根本没有**选中这个概念;旧断言把这面旗标写死,
      // 等于把缺陷钉住。
      expect(
        tester.getSemantics(find.bySemanticsLabel('Bold')),
        matchesSemantics(
          isButton: true,
          isToggled: true,
          hasToggledState: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
      // Off state must NOT expose a toggled flag (it's a plain icon button until turned on). 关态无 toggled。
      final off = tester.getSemantics(find.bySemanticsLabel('Italic'));
      expect(
        off,
        matchesSemantics(
          isButton: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isEnabled: true,
        ),
      );
    },
  );

  // WRK-077 §5.13 — an icon-only button now carries its own tooltip.
  //
  // The count is the argument: 87 `AnButton.iconOnly` uses against 28 `AnTooltip` uses, i.e. most icon
  // buttons said NOTHING on hover. `semanticLabel` reached the semantics tree only — right for a screen
  // reader, invisible to eyes. The user hit exactly this and had to come ask what a button was
  // (「Library 里,新建页面为什么有一个下载的按钮…这是什么东西?」). Fixing it in the kit retired seven
  // hand-written wraps at once; a labelled button still gets none, because its label IS the text.
  //
  // WRK-077 §5.13——纯图标按钮现在自带 tooltip。
  //
  // **数目**就是论据:`AnButton.iconOnly` 87 处 vs `AnTooltip` 28 处,即多数图标按钮 hover 时什么也不说。
  // `semanticLabel` 只到语义树——对读屏是对的,对眼睛不存在。用户正是撞在这上面、不得不来问一个按钮是什么。
  // 落在地基上一举退掉七处手写包裹;**带文案的按钮仍然没有** tooltip,因为它的文案本身就是那段文字。
  group('icon-only buttons speak on hover (WRK-077 §5.13)', () {
    testWidgets('iconOnly gets a tooltip from its semanticLabel', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AnButton.iconOnly(
            AnIcons.copy,
            semanticLabel: 'Copy',
            onPressed: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Copy'), findsOneWidget);
    });

    testWidgets('a LABELLED button gets none — the label already says it', (
      tester,
    ) async {
      await tester.pumpWidget(host(AnButton(label: 'Save', onPressed: () {})));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Save'), findsNothing);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('exactly ONE tooltip — no doubling with an outer AnTooltip', (
      tester,
    ) async {
      // Seven call sites used to wrap iconOnly in AnTooltip by hand; after the kit change those became
      // DOUBLE tooltips and six tests went red, which is how the redundancy was found. They are unwrapped
      // now — this pins that a stray re-wrap is caught rather than silently nesting.
      // 原有七处手工把 iconOnly 包进 AnTooltip;地基改动后它们变成**双层** tooltip、六条测试转红,冗余正是这样
      // 被发现的。现已解包——本条钉住「再有人包回去会被抓到」,而不是无声嵌套。
      await tester.pumpWidget(
        host(
          AnTooltip(
            message: 'Copy',
            child: AnButton.iconOnly(
              AnIcons.copy,
              semanticLabel: 'Copy',
              onPressed: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Copy'),
        findsNWidgets(2),
        reason:
            'a hand-wrap on top of the kit tooltip nests two — unwrap the call site',
      );
    });
  });
}
