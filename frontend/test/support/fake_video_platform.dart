import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A platform fake so a REAL [VideoPlayerController] can exist in a widget test. The transport is the
/// thing under test, and a transport without a controller is untestable by construction — every other
/// video test in this repo deliberately never builds one, which is exactly why nothing caught that
/// there was no transport at all.
///
/// 一个平台假件,好让**真的** [VideoPlayerController] 能活在 widget test 里。被测的正是走带控件,而没有
/// controller 的走带控件在构造上就不可测——本仓其余每一个视频测试都刻意不建 controller,而这正是
/// 「**根本没有走带控件**」一直没被任何东西抓到的原因。
class FakeVideoPlatform extends VideoPlayerPlatform {
  FakeVideoPlatform({
    this.initializationDelay = Duration.zero,
    this.createError,
  });

  final _events = StreamController<VideoEvent>.broadcast();
  final Duration initializationDelay;
  final Object? createError;
  Duration position = Duration.zero;
  int seeks = 0, plays = 0, pauses = 0;

  /// Registers this fake as THE platform. Kept here so no test file has to import the platform
  /// interface just to assign one field. 把本假件登记为**那个**平台;放这儿,免得每个测试文件为了赋一个
  /// 字段而去 import 平台接口。
  void install() => VideoPlayerPlatform.instance = this;

  @override
  Future<void> init() async {}
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<int?> create(DataSource dataSource) async {
    if (createError != null) throw createError!;
    return 1;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    if (createError != null) throw createError!;
    return 1;
  }

  Duration duration = const Duration(seconds: 12);

  // The `initialized` event must arrive ON SUBSCRIBE. `controller.initialize()` subscribes and then
  // AWAITS it, so emitting from the test after that await is a deadlock — the setUp never returns and
  // the whole file hangs with no failure to read.
  // `initialized` 事件必须在**订阅时**就到。`controller.initialize()` 先订阅、然后 **await** 它,故测试在
  // 那个 await 之后再发事件是死锁——setUp 永不返回,整份文件挂住且没有任何失败可读。
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) async* {
    if (initializationDelay > Duration.zero) {
      await Future<void>.delayed(initializationDelay);
    }
    yield VideoEvent(
      eventType: VideoEventType.initialized,
      duration: duration,
      size: const Size(640, 360),
    );
    yield* _events.stream;
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async => plays++;
  @override
  Future<void> pause(int playerId) async => pauses++;
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> seekTo(int playerId, Duration p) async {
    seeks++;
    position = p;
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => position;
  @override
  Widget buildView(int playerId) => const SizedBox.shrink();
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.shrink();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
