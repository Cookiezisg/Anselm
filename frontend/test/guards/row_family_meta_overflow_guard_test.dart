import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/design/tokens.dart';
import 'package:anselm/core/ui/an_menu.dart';
import 'package:anselm/core/ui/an_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-083 B2 law: NO row-family primitive may overflow because of its `meta`.
//
// The reported bug was one menu row in the residency's「最近目录」section painting a
// yellow-and-black overflow bar. The instance fix — give that one call site a shorter string — would
// have left the defect exactly where it was, because the row primitives put `meta` in the tree as a
// BARE `Text`: non-flexible children of a `Row` are laid out with UNBOUNDED main-axis constraints, so
// `overflow: TextOverflow.ellipsis` never engages and the text simply runs past the row's edge. Every
// caller that ever passes a long `meta` gets the same bar — and `meta` is where callers naturally put
// paths, ids, model names and key names, all of which are long.
//
// So the law is about the PRIMITIVES, not the call sites: render each of them at a deliberately narrow
// width with an absurd `meta` and assert the frame paints clean. `tester.takeException()` is the whole
// mechanism — a `RenderFlex` overflow is reported through `FlutterError.onError` during paint, which
// the test binding captures.
//
// Note the guard says nothing about WHERE the text is clipped or HOW it is shortened. Those are design
// choices that may change. What may not change is that a row cannot paint outside itself.
//
// WRK-083 B2 军规:行族原语**一律不得**因 `meta` 而溢出。
//
// 报上来的是驻地「最近目录」里一行菜单画出黄黑溢出条。**实例修法**——把那一处的字符串改短——会把缺陷
// 原封不动留在原地,因为行族原语把 `meta` 作为**裸 `Text`** 放进树里:`Row` 的非弹性 child 拿到的是
// **无界**主轴约束,于是 `overflow: TextOverflow.ellipsis` 根本不会生效、文字直接跑出行外。任何将来传入
// 长 `meta` 的调用方都会得到同一条黄黑条——而 `meta` 恰恰是调用方自然会放**路径、id、模型名、密钥名**
// 的地方,它们全都很长。
//
// 故本法管的是**原语**、不是调用点:把每个原语放进一个刻意窄的宿主、喂一个荒唐的 `meta`,断言这一帧画得
// 干净。`tester.takeException()` 就是全部机制——`RenderFlex` 溢出在 paint 阶段经 `FlutterError.onError`
// 上报,测试 binding 会捕获它。
//
// 注意本守卫**不**规定文字在**哪里**被截断、**怎样**被缩短。那些是可以变的设计选择。不可以变的是:
// 一行不得画到自己之外。

/// A meta long enough to dwarf any sane row — the real report was a 148px overflow from a filesystem
/// path, and this is worse on purpose. 一个足以碾压任何正常行的 meta——真实报告是一条文件系统路径溢出
/// 148px,这里刻意更过分。
const _absurdMeta =
    '/Users/someone/Documents/Work/Projects/anselm/frontend/lib/core/ui/an_menu.dart';

Widget _host(Widget child, {double width = 240}) => TestTheme(
  child: Center(
    child: SizedBox(width: width, child: child),
  ),
);

/// The app's real theme wrapper — the primitives read colours and typography off it.
/// app 真实主题包装——原语从它读色与排版。
class TestTheme extends StatelessWidget {
  const TestTheme({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AnTheme.light(),
    home: Scaffold(body: child),
  );
}

void main() {
  // The menu is where the bug was SEEN. Its popover is `IntrinsicWidth` inside a
  // `ConstrainedBox(maxWidth: menuMaxWidth)`, which is exactly the trap: the intrinsic pass reports
  // "I would like to be 700 wide", the constraint says "you get 360", and a non-flexible child that
  // was measured against the former is then painted into the latter.
  // 菜单是这个 bug 被**看见**的地方。它的浮层是 `ConstrainedBox(maxWidth: menuMaxWidth)` 里套
  // `IntrinsicWidth`,这正是那个陷阱:intrinsic 一趟说「我想要 700 宽」,约束说「你只有 360」,而一个按前者
  // 量过的非弹性 child 随后被画进后者。
  testWidgets('AnMenu row: an absurd meta does not overflow the popover', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AnMenu(
          anchorBuilder: (context, toggle, isOpen) =>
              ElevatedButton(onPressed: toggle, child: const Text('open')),
          entries: [
            AnMenuItem(label: 'short', meta: _absurdMeta, onTap: () {}),
          ],
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(_absurdMeta), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason:
          'a long meta must shrink inside the row, never paint past menuMaxWidth '
          '(${AnSize.menuMaxWidth}) — WRK-083 B2',
    );
  });

  // AnRow is the menu row's twin: same `Expanded(label) + bare Text(meta)` shape, same trap. Nobody
  // has reported it because rail metas are timestamps and counts, but "no caller has hit it yet" is
  // not a fix — the next feature that puts an id or a path in a rail row's meta walks straight into it.
  // AnRow 是菜单行的孪生件:同样的 `Expanded(label) + 裸 Text(meta)` 形状、同样的陷阱。没人报是因为 rail 的
  // meta 都是时间戳和计数,但「还没有调用方撞上」不是修复——下一个把 id 或路径放进 rail 行 meta 的 feature
  // 会直直走进去。
  testWidgets('AnRow: an absurd meta does not overflow the row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(AnRow(label: 'short', meta: _absurdMeta, onSelect: () {})),
    );
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason: 'the row family shares one meta contract — WRK-083 B2',
    );
  });

  // The trail is not always text: AnRow stacks hover ACTIONS at the same right anchor as the meta, so
  // bounding the trail could squeeze real buttons instead of a string. This case exists because that
  // risk is the direct cost of the fix above — if the allowance ever stops fitting a normal action set,
  // this goes red rather than the buttons silently clipping on someone's rail.
  // trail 不总是文字:AnRow 把 hover **动作**叠在与 meta 同一个右锚上,故给 trail 设界有可能挤到真按钮、
  // 而不是一个字符串。本格存在,正因为那份风险是上面那个修复的直接代价——将来额度若容不下一组正常动作,
  // 这里会**变红**,而不是让按钮在谁的 rail 上悄悄被裁掉。
  testWidgets('AnRow: hover actions survive the bounded trail', (tester) async {
    await tester.pumpWidget(
      _host(
        AnRow(
          label: 'a conversation title that is quite long indeed',
          meta: _absurdMeta,
          onSelect: () {},
          actions: const [
            Icon(Icons.push_pin, size: 16),
            Icon(Icons.archive, size: 16),
            Icon(Icons.delete, size: 16),
          ],
        ),
        width: AnSize.sidebarMin,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // The narrow end of the range: a rail collapsed to its minimum still may not paint outside itself.
  // 区间的窄端:收到最小宽的 rail 依然不得画到自己之外。
  testWidgets('AnRow at a rail-narrow width still contains its meta', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AnRow(
          label: 'a fairly long label too',
          meta: _absurdMeta,
          onSelect: () {},
        ),
        width: 160,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
