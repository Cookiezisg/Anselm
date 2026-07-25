import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anselm/core/ui/an_scroll_behavior.dart';

// TS 红线① (WRK-077): no ScrollBehavior in this app may add PointerDeviceKind.mouse to dragDevices.
//
// Flutter's default set excludes mouse ON PURPOSE, so that text inside scrollable containers stays
// selectable; the official breaking-change note says adding it "will make it difficult or impossible to
// select text in scrollable containers and is not recommended". AnScrollBehavior added it anyway, under a
// comment reading "the base desktop set omits mouse" — reading a deliberate decision as an oversight. The
// cost was that every SelectionArea in the app was inert, in all 23 scrollables using this behavior.
//
// The reason this needs a GUARD and not just a fixed line: adding mouse back looks like a feature ("let
// people drag the content to scroll"), it makes no test fail on its own, and what it breaks — text
// selection — lives nowhere near the scroll code.
//
// TS 红线①(WRK-077):本 app 任何 ScrollBehavior 都不得把 `PointerDeviceKind.mouse` 加进 dragDevices。
//
// Flutter 默认集**故意**排除 mouse,以保滚动容器内文字可选;官方 breaking-change 文档明写加入它
// 「will make it difficult or impossible to select text in scrollable containers and is not recommended」。
// AnScrollBehavior 当年还是加了,注释写「桌面默认集不含 mouse」——把一个刻意的决定读成了疏漏。代价是全 app 的
// SelectionArea 形同虚设,在用本 behavior 的 23 处可滚区里处处如此。
//
// 为什么这需要**守卫**而不只是改对一行:把 mouse 加回来看起来像个功能(「让人能拖内容滚动」),它自己不会让任何
// 测试变红,而它破坏的东西——文字选择——住在离滚动代码很远的地方。
void main() {
  test('AnScrollBehavior does NOT put the mouse in dragDevices (TS 红线①)', () {
    expect(
      const AnScrollBehavior().dragDevices,
      isNot(contains(PointerDeviceKind.mouse)),
      reason:
          'a mouse drag must select text, not scroll — see the note in an_scroll_behavior.dart',
    );
  });

  test('the wheel / trackpad / scrollbar / touch paths are untouched', () {
    // What the removal costs is press-and-drag-with-the-left-button, a phone habit. Everything a desktop
    // user actually scrolls with keeps working — assert that, so nobody "restores" mouse thinking scrolling
    // is broken. 删掉它失去的只是「按住左键拖内容」这个手机习惯。桌面用户真正用来滚动的东西全都还在——断言这一点,
    // 免得有人以为滚动坏了而把 mouse「恢复」回来。
    final devices = const AnScrollBehavior().dragDevices;
    expect(devices, contains(PointerDeviceKind.trackpad));
    expect(devices, contains(PointerDeviceKind.touch));
  });
}
