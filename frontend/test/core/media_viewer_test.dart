import 'package:anselm/core/contract/attachment.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/media/media_cards.dart';
import 'package:anselm/core/media/media_player_chrome.dart';
import 'package:anselm/core/media/media_ref.dart';
import 'package:anselm/core/media/media_source.dart';
import 'package:anselm/core/net/api_client.dart' show NativeFetchTarget;
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import '../support/fake_video_platform.dart';

// WRK-082 B1 收口:放大与走带。两条被修的缺陷都**对断言不可见**——图卡与视频卡自始至终都在树上、
// 也都是对的,缺的是「点了之后能干什么」。故这里断言的全是**动作**,不是存在。
//
// The B1 closure: enlarging and transport. Both defects were invisible to assertions — the image card
// and the video card were present and correct the whole time; what was missing was what a tap could
// DO. So everything here asserts an ACTION, not a presence.

const _id = 'att_00112233445566aa';
const _pixel = <int>[
  // 1×1 PNG — a real decodable image, so the viewer's full-resolution decode is a real decode.
  // 1×1 PNG——真能解的图,故查看器那次全分辨率解码是一次真解码。
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

class _StubSource implements MediaSource {
  const _StubSource(this._meta);
  final AttachmentMeta _meta;

  @override
  Future<AttachmentMeta> meta(String id) async => _meta;
  @override
  Future<List<int>> bytes(String id) async => _pixel;
  @override
  NativeFetchTarget nativeTarget(String id) =>
      const NativeFetchTarget(uri: 'http://127.0.0.1:0/stub', headers: {});
  @override
  Future<AttachmentMeta> upload({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) async => throw UnimplementedError();
  @override
  Future<bool> readAloudAvailable() async => false;
  @override
  Future<ReadAloudResult> readAloud(String text, {String? voice}) async =>
      throw UnimplementedError();
}

Widget _host(Widget child, {List<Override> overrides = const []}) =>
    ProviderScope(
      overrides: overrides,
      child: TranslationProvider(
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: AnTheme.light(),
            home: Scaffold(body: SizedBox(width: 560, child: child)),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('en'));

  const imageRow = AttachmentMeta(
    id: _id,
    filename: 'lighthouse.png',
    mimeType: 'image/png',
    sizeBytes: 1523916,
    kind: 'image',
  );

  testWidgets('tapping an image card opens the full-size viewer', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const AnMediaRefCard(mediaRef: AnMediaRef(attachmentId: _id)),
        overrides: [
          mediaSourceProvider.overrideWithValue(const _StubSource(imageRow)),
        ],
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel('View full size'), findsOneWidget);

    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    // The viewer is up: it names its route (screen readers) and captions the artifact.
    // 查看器起来了:它给路由命名(供屏读)、并给产物配了说明行。
    expect(find.bySemanticsLabel('Media viewer'), findsWidgets);
    expect(find.textContaining('lighthouse.png'), findsWidgets);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('the viewer closes from its own button', (tester) async {
    await tester.pumpWidget(
      _host(
        const AnMediaRefCard(mediaRef: AnMediaRef(attachmentId: _id)),
        overrides: [
          mediaSourceProvider.overrideWithValue(const _StubSource(imageRow)),
        ],
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('Escape closes the viewer', (tester) async {
    await tester.pumpWidget(
      _host(
        const AnMediaRefCard(mediaRef: AnMediaRef(attachmentId: _id)),
        overrides: [
          mediaSourceProvider.overrideWithValue(const _StubSource(imageRow)),
        ],
      ),
    );
    await tester.pump();
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();

    // Barrier-dismissible RawDialogRoutes get Escape for free — asserted rather than assumed,
    // because an_dialog.dart had to verify the same claim against the SDK source.
    // 可关的 RawDialogRoute 白送 Escape——**断言而非假定**,因为 an_dialog.dart 当初也得对着 SDK 源码核。
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  group('video transport', () {
    late FakeVideoPlatform fake;
    late VideoPlayerController controller;

    setUp(() async {
      fake = FakeVideoPlatform();
      fake.install();
      controller = VideoPlayerController.networkUrl(
        Uri.parse('http://127.0.0.1:0/clip.mp4'),
      );
      await controller.initialize();
    });

    tearDown(() => controller.dispose());

    Widget bar({VoidCallback? onFullscreen}) => _host(
      AnVideoControls(controller: controller, onFullscreen: onFullscreen),
    );

    testWidgets('play then pause reaches the platform', (tester) async {
      await tester.pumpWidget(bar());
      await tester.pump();

      // Assert the CONTROLLER's state, not a platform call count: `play()` also arms a periodic
      // position poll, so the platform sees more than one call for one press and counting them would
      // pin an implementation detail of the package.
      // 断言 **controller** 的状态、不数平台调用次数:`play()` 还会装一个周期性的位置轮询,故一次按下
      // 平台会看到不止一次调用,数它等于把这个包的实现细节钉死。
      await tester.tap(find.bySemanticsLabel('Play video'));
      await tester.pump();
      expect(controller.value.isPlaying, isTrue);
      expect(fake.plays, greaterThan(0));

      await tester.tap(find.bySemanticsLabel('Pause video'));
      await tester.pump();
      expect(controller.value.isPlaying, isFalse);
      expect(fake.pauses, greaterThan(0));
    });

    testWidgets('a finished clip offers REPLAY, and replay seeks to zero', (
      tester,
    ) async {
      await tester.pumpWidget(bar());
      await tester.pump();
      // Drive the clip to its end. Before this fix there was no button here at all — the clip simply
      // sat on its last frame forever. 把片子推到末尾。修之前这里根本没有按钮,片子就永远停在最后一帧。
      await controller.seekTo(const Duration(seconds: 12));
      await tester.pump();

      expect(find.bySemanticsLabel('Replay'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Replay'));
      await tester.pump();
      expect(fake.position, Duration.zero);
      expect(controller.value.isPlaying, isTrue);
      // Playing arms a periodic poll; the binding fails the test on a pending timer, so stop it here
      // rather than in tearDown (which runs after that check).
      // 播放会装一个周期性轮询,而 binding 会因「还有 timer 挂着」判测试失败,故在**这里**停,不在
      // tearDown(它在那次检查之后才跑)。
      await controller.pause();
    });

    testWidgets('the clock reads position / duration', (tester) async {
      await tester.pumpWidget(bar());
      await controller.seekTo(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('0:05 / 0:12'), findsOneWidget);
    });

    testWidgets('fullscreen is offered inline and absent inside the viewer', (
      tester,
    ) async {
      var opened = 0;
      await tester.pumpWidget(bar(onFullscreen: () => opened++));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Fullscreen'));
      expect(opened, 1);

      // The viewer passes no callback — there is nowhere further to go, and a button that says
      // "fullscreen" while already fullscreen is a lie.
      // 查看器不传回调——没有更远的地方可去,而一个在全屏里还写着「全屏」的按钮是在撒谎。
      await tester.pumpWidget(bar());
      await tester.pump();
      expect(find.bySemanticsLabel('Fullscreen'), findsNothing);
    });
  });
}
