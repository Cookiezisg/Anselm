import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/core/ui/an_scroll_behavior.dart';
import 'package:anselm/core/ui/an_interactive.dart';
import 'package:anselm/core/ui/an_selection_region.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// TS 批 (WRK-077) — the user's ask was "in Claude Code I can drag across text and copy it; we have nothing".
//
// Every assertion here is about a mechanism that fails SILENTLY, which is why the feature was absent
// without anyone filing a bug: a mouse in dragDevices makes selection inert, a row winning the gesture
// arena makes Cmd+A inert, and a region that never gets focus copies nothing. None of that throws.
//
// TS 批(WRK-077)——用户原话:「例如 claude code,我滑一些这些内容,是可以高亮然后复制粘贴什么的。但是现在我们
// 项目完全都没有。」
//
// 这里每条断言针对的都是**静默失效**的机制,这也正是这个功能缺席却没人报 bug 的原因:mouse 在 dragDevices 里会让
// 选择形同虚设、行赢了手势竞技场会让 Cmd+A 失效、永不聚焦的域复制不出任何东西。三者都不抛异常。
void main() {
  Widget host(Widget child) => TranslationProvider(
    child: MaterialApp(
      theme: AnTheme.light(),
      home: Scaffold(
        body: ScrollConfiguration(
          behavior: const AnScrollBehavior(),
          child: SingleChildScrollView(child: child),
        ),
      ),
    ),
  );

  testWidgets('a mouse DRAG across several Texts selects the text it crossed', (
    tester,
  ) async {
    // flutter_test reports a MOBILE target platform by default, where the copy shortcut is Ctrl+C, so a
    // Cmd+C here would land on nothing and the test would "prove" a broken clipboard. This is a desktop
    // app; say so. flutter_test 默认报告**移动**目标平台,那里复制键是 Ctrl+C,于是此处的 Cmd+C 会打在空处、
    // 测试就会「证明」剪贴板坏了。这是个桌面 app,把它说出来。
    // Reset INSIDE the body: flutter_test asserts every foundation debug variable is unset when the body
    // returns, and it checks that BEFORE tearDowns run. 还原要在**测试体内**:flutter_test 在体返回时断言所有
    // foundation 调试变量已复位,而这个检查发生在 tearDown **之前**。
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    await tester.pumpWidget(
      host(
        const AnSelectionRegion(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('first line'),
              Text('second line'),
              // Overflowing content, so this runs in the realistic configuration: a selection inside a
              // scrollable that CAN scroll.
              //
              // Honest limit of this test: it does NOT prove red line ① by itself. Putting
              // PointerDeviceKind.mouse back into AnScrollBehavior.dragDevices leaves it GREEN — a single
              // `moveTo` jump resolves the gesture arena differently from a real pointer's frame-by-frame
              // movement. The regression is guarded directly instead, by asserting mouse is absent
              // (test/guards/drag_devices_guard_test.dart); the causal claim rests on Flutter's own
              // breaking-change note, not on this test.
              //
              // 内容溢出,使本测试跑在真实配置下:选区处于一个**能滚**的滚动体内。
              //
              // 本测试的诚实边界:它**本身证明不了**红线①。把 `PointerDeviceKind.mouse` 加回
              // `AnScrollBehavior.dragDevices`,它依然**绿**——单次 `moveTo` 跳跃在手势竞技场里的解算与真实指针
              // 的逐帧移动不同。该回归改由直接断言「mouse 不在其中」来守(test/guards/drag_devices_guard_test.dart);
              // 因果依据是 Flutter 官方 breaking-change 文档,不是这条测试。
              SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final from =
        tester.getTopLeft(find.text('first line')) + const Offset(2, 8);
    final to =
        tester.getBottomRight(find.text('second line')) - const Offset(2, 4);
    final gesture = await tester.startGesture(
      from,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Copy through the framework's own action, then read what actually landed on the clipboard — the only
    // assertion that proves the whole chain (selection + focus + copy), rather than an internal flag.
    // 走框架自己的复制动作,再读**真正**落到剪贴板上的东西——只有这样才证明整条链(选区+焦点+复制),而不是某个内部旗标。
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    expect(copied, isNotNull, reason: 'nothing reached the clipboard');
    expect(copied, contains('first'));
    expect(copied, contains('second'));
  });

  testWidgets(
    'a clickable row still fires onTap, AND hands the region focus so Cmd+A works',
    (tester) async {
      // The two halves are one test on purpose: making Cmd+A work by focusing the region would be worthless
      // if it broke the row's tap, and the row's tap working is worthless if Cmd+A stays dead. Both must hold
      // at once. 两半刻意合成一条:靠聚焦域让 Cmd+A 生效,若代价是行点不动就毫无价值;而行能点、Cmd+A 仍死也一样。
      var taps = 0;
      await tester.pumpWidget(
        host(
          AnSelectionRegion(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnInteractive(
                  onTap: () => taps += 1,
                  builder: (_, _) => const Text('a tappable row'),
                ),
                const Text('plain prose'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('a tappable row'));
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'the row must still activate');

      final region = tester.state(find.byType(AnSelectionRegion));
      final focus = AnSelectionRegion.focusOf(
        tester.element(find.text('plain prose')),
      );
      expect(
        focus,
        isNotNull,
        reason: 'the region must publish its focus node',
      );
      expect(
        focus!.hasFocus,
        isTrue,
        reason:
            'the pointer tap must hand focus to the region, or Cmd+A/Cmd+C are silently dead',
      );
      expect(region, isNotNull);
    },
  );

  testWidgets('keyboard activation does NOT move focus to the region', (
    tester,
  ) async {
    // The mirror of the test above. Requesting region focus on the Enter/Space path would throw the user
    // out of the list they are navigating — so the hand-off is deliberately pointer-only.
    // 上一条的镜像。在 Enter/Space 路径上聚焦域会把用户从他正在浏览的列表里甩出去,故交接刻意只走指针。
    final node = FocusNode();
    addTearDown(node.dispose);
    var taps = 0;
    await tester.pumpWidget(
      host(
        AnSelectionRegion(
          child: AnInteractive(
            focusNode: node,
            autofocus: true,
            onTap: () => taps += 1,
            builder: (_, _) => const Text('row'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(node.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(taps, 1, reason: 'Enter activates');
    expect(
      node.hasFocus,
      isTrue,
      reason: 'keyboard activation must leave focus on the row',
    );
  });

  testWidgets(
    'pointer activation can rebuild selectable content without a selection exception',
    (tester) async {
      var revision = 0;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => AnSelectionRegion(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnInteractive(
                    onTap: () => setState(() => revision++),
                    builder: (_, _) => const Text('rebuild row'),
                  ),
                  Text('revision $revision'),
                  for (var i = 0; i < revision + 2; i++)
                    Text('selectable line $i'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('rebuild row'));
      await tester.pumpAndSettle();

      expect(revision, 1);
      expect(tester.takeException(), isNull);
      expect(
        AnSelectionRegion.focusOf(
          tester.element(find.text('revision 1')),
        )?.hasFocus,
        isTrue,
      );
    },
  );

  testWidgets(
    'chrome text is NOT selectable — a button label stays out of the clipboard',
    (tester) async {
      await tester.pumpWidget(
        host(
          AnSelectionRegion(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnButton(label: 'Chrome Label', onPressed: () {}),
                const Text('real prose'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A widget is selectable only if a registrar reached it. The button's label must find none.
      // 只有拿到 registrar 的 widget 才可选;按钮文案必须拿不到。
      expect(
        SelectionContainer.maybeOf(tester.element(find.text('Chrome Label'))),
        isNull,
        reason: 'a button label must be SelectionContainer.disabled (TS 排除清单)',
      );
      expect(
        SelectionContainer.maybeOf(tester.element(find.text('real prose'))),
        isNotNull,
        reason: 'prose in the same region must remain selectable',
      );
    },
  );

  testWidgets(
    'outside a region, focusOf is null — the rail and the top band are not selectable',
    (tester) async {
      await tester.pumpWidget(host(const Text('rail label')));
      await tester.pumpAndSettle();
      expect(
        AnSelectionRegion.focusOf(tester.element(find.text('rail label'))),
        isNull,
      );
      expect(
        SelectionContainer.maybeOf(tester.element(find.text('rail label'))),
        isNull,
      );
    },
  );
}
