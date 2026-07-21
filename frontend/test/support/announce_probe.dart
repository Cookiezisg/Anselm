import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// One captured `SemanticsService.sendAnnouncement`. 一次被捕获的播报。
class Announcement {
  const Announcement(this.message, this.assertiveness);

  final String message;

  /// The wire value: `0` = polite, `1` = assertive (dart:ui `Assertiveness.index`). 线上值:0 礼貌 / 1 打断。
  final int assertiveness;

  bool get isAssertive => assertiveness == 1;

  @override
  String toString() => '${isAssertive ? 'assertive' : 'polite'}: $message';
}

/// Taps the accessibility platform channel and records every announcement the frame posts.
///
/// This is the ONLY way to assert a screen-reader push: an announcement leaves NO trace in the semantics
/// tree (it is a fire-and-forget channel message, not a node property), so `matchesSemantics` and the
/// tree dump are both blind to it. Asserting on `Semantics.liveRegion` instead — which is what these
/// widgets' tests used to do — proves nothing about whether anything is ever SPOKEN: that flag is a
/// verified no-op on all three desktops (see `AnA11y`), so those assertions passed while the widgets
/// were silent.
///
/// An expectation of SILENCE is safe to write without [WidgetTester.ensureSemantics]: flutter_test keeps
/// semantics enabled for the whole binding (measured — `semanticsEnabled` is true before the first pump),
/// so `AnA11y`'s "nobody is listening" guard can never be what makes a probe read empty here.
///
/// Announcements are posted from post-frame callbacks, so `pumpAndSettle` (or at least a second `pump`)
/// before asserting.
///
/// 接住 accessibility 平台通道,记录本帧发出的每一条播报。**这是断言读屏推送的唯一办法**:播报在语义树里
/// **不留痕**(它是 fire-and-forget 的通道消息、不是节点属性),故 matchesSemantics 与树 dump 都看不见它。改去断言
/// `Semantics.liveRegion`(这些件的旧测试正是如此)**什么都证明不了**:那面旗标在三桌面实证 no-op,所以旧断言
/// 在**件其实是哑的**时候照样绿。断言**沉默**时无需先 ensureSemantics:flutter_test 全程开着语义(实测:首次 pump
/// 之前就是 true),故 AnA11y 的「无人在听」门在这里绝不会是探针读空的原因。播报走 post-frame,断言前须 pumpAndSettle。
List<Announcement> probeAnnouncements(WidgetTester tester) {
  final said = <Announcement>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
    SystemChannels.accessibility,
    (msg) async {
      final m = (msg as Map<Object?, Object?>?) ?? const {};
      if (m['type'] == 'announce') {
        final data = m['data']! as Map<Object?, Object?>;
        said.add(
          Announcement(
            data['message']! as String,
            (data['assertiveness'] as int?) ?? 0,
          ),
        );
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return said;
}
