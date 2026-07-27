import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' as mk;

import '../../../core/contract/api_error.dart';

/// Playback status normalized away from the concrete platform player.
/// 播放状态从具体平台播放器归一化出来，UI/状态层不绑定插件枚举。
enum AttachmentAudioStatus { stopped, playing, paused, completed }

/// Stable UI-facing audio playback error codes. Transient playback failures remain retryable; missing
/// content is a terminal tombstone because the original attachment bytes are gone.
/// 稳定的音频播放错误码。瞬时播放失败保留重试；原件内容缺失是终态墓碑。
abstract final class AttachmentAudioError {
  static const playbackFailed = 'playback_failed';
  static const attachmentMissing = 'attachment_missing';
  static const attachmentOffline = 'attachment_offline';
}

/// Replaceable driver for sent audio attachment playback. The controller owns a single instance, so only
/// one transcript attachment can play at once; switching attachments stops the previous source first.
/// 已发送音频附件播放驱动。controller 只持有一个实例，因此 transcript 内同时只有一个附件播放；切换附件先停旧源。
abstract interface class AttachmentAudioDriver {
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<AttachmentAudioStatus> get statusStream;

  /// Play from a URL. There is deliberately no bytes variant: every attachment this app plays is
  /// reachable over loopback HTTP (a playback lease, or the sidecar's content endpoint), and a
  /// sandboxed macOS app cannot hand a native player an arbitrary file path anyway (ADR 0016).
  /// One source shape means one code path to keep honest.
  ///
  /// 从 URL 播。刻意**没有**字节形态:本应用会播的每一份附件都经 loopback HTTP 可达(播放 lease,或
  /// sidecar 的内容端点),而沙箱化的 macOS app 本来也没法把任意文件路径交给原生播放器(ADR 0016)。
  /// 一种源形状 = 只有一条要维持诚实的代码路径。
  Future<void> playUrl(String url, {String? mimeType});
  Future<void> seek(Duration position);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

/// The media_kit (libmpv) driver — the SAME native stack the inline video card uses (ADR 0016).
///
/// It replaced audioplayers rather than sitting beside it: libmpv now ships with the app for video
/// regardless, so a second native audio stack would be pure additional weight, plus a second thing
/// that can grab an audio device. The seam above exists precisely so this swap costs the UI nothing.
///
/// media_kit(libmpv)驱动——与内联视频卡**同一套**原生栈(ADR 0016)。
///
/// 它**替掉**了 audioplayers、而不是与之并存:libmpv 现在无论如何都要为视频打进包,故再留一套原生音频栈
/// 是纯粹的额外重量,外加多一个会去抢音频设备的东西。上面那层缝的存在,正是为了让这次替换对 UI 零成本。
class MediaKitAttachmentAudioDriver implements AttachmentAudioDriver {
  MediaKitAttachmentAudioDriver();

  // The native player is built on FIRST PLAY, never in the constructor. Constructing one reaches
  // into libmpv, which does not exist in a widget test — and this driver is instantiated by the
  // controller's build(), i.e. by every test that renders a transcript. Lazily is the same rule the
  // inline video card follows, for the same reason (ADR 0016).
  // 原生播放器在**第一次播放**时才建,绝不在构造函数里。构造它要伸到 libmpv,而 widget test 里没有那一层
  // ——而本驱动是由 controller 的 build() 实例化的,也就是**每一个**渲 transcript 的测试都会造它。
  // 惰性与内联视频卡是同一条规矩、同一个理由(ADR 0016)。
  mk.Player? _player;
  final _positions = StreamController<Duration>.broadcast();
  final _durations = StreamController<Duration>.broadcast();
  final _statuses = StreamController<AttachmentAudioStatus>.broadcast();

  mk.Player _ensure() {
    final existing = _player;
    if (existing != null) return existing;
    final player = mk.Player();
    _player = player;
    player.stream.position.listen(_positions.add);
    player.stream.duration.listen(_durations.add);
    // libmpv reports playing/completed as two independent booleans rather than one enum, so the
    // normalized status is derived here. `completed` wins: at end-of-file both can be true for a
    // frame, and reporting "playing" there would leave the UI stuck mid-track forever.
    // libmpv 用两个独立布尔而非一个枚举报告 playing/completed,故归一状态在此推导。**completed 优先**:
    // 播放到尾时两者可能同为真一帧,那里报 "playing" 会让 UI 永远卡在半途。
    player.stream.completed.listen((done) {
      if (done) _statuses.add(AttachmentAudioStatus.completed);
    });
    player.stream.playing.listen((playing) {
      if (player.state.completed) return;
      _statuses.add(
        playing ? AttachmentAudioStatus.playing : AttachmentAudioStatus.paused,
      );
    });
    return player;
  }

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Stream<Duration> get durationStream => _durations.stream;

  @override
  Stream<AttachmentAudioStatus> get statusStream => _statuses.stream;

  @override
  Future<void> playUrl(String url, {String? mimeType}) =>
      _ensure().open(mk.Media(url));

  @override
  Future<void> seek(Duration position) async => _player?.seek(position);

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> resume() async => _player?.play();

  @override
  Future<void> stop() async => _player?.stop();

  @override
  Future<void> dispose() async {
    await _positions.close();
    await _durations.close();
    await _statuses.close();
    await _player?.dispose();
  }
}

final attachmentAudioDriverFactoryProvider =
    Provider<AttachmentAudioDriver Function()>(
      (ref) => MediaKitAttachmentAudioDriver.new,
    );

@immutable
class AttachmentAudioPlaybackState {
  const AttachmentAudioPlaybackState({
    this.activeAttachmentId,
    this.loading = false,
    this.playing = false,
    this.completed = false,
    this.position = Duration.zero,
    this.duration,
    this.error,
  });

  final String? activeAttachmentId;
  final bool loading;
  final bool playing;
  final bool completed;
  final Duration position;
  final Duration? duration;

  /// Machine-readable error code; UI maps it to i18n text.
  /// 机器可读错误码；UI 层映射为 i18n 文案。
  final String? error;

  bool isActive(String id) => activeAttachmentId == id;
  bool isLoading(String id) => isActive(id) && loading;
  bool isPlaying(String id) => isActive(id) && playing;
  bool isCompleted(String id) => isActive(id) && completed;
  String? errorFor(String id) => isActive(id) ? error : null;
  Duration positionFor(String id) => isActive(id) ? position : Duration.zero;
  Duration? durationFor(String id) => isActive(id) ? duration : null;

  double progressFor(String id) {
    final d = durationFor(id);
    if (d == null || d.inMilliseconds <= 0) return 0;
    return (positionFor(id).inMilliseconds / d.inMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  AttachmentAudioPlaybackState copyWith({
    String? activeAttachmentId,
    bool clearActiveAttachmentId = false,
    bool? loading,
    bool? playing,
    bool? completed,
    Duration? position,
    Duration? duration,
    bool clearDuration = false,
    String? error,
    bool clearError = false,
  }) => AttachmentAudioPlaybackState(
    activeAttachmentId: clearActiveAttachmentId
        ? null
        : activeAttachmentId ?? this.activeAttachmentId,
    loading: loading ?? this.loading,
    playing: playing ?? this.playing,
    completed: completed ?? this.completed,
    position: position ?? this.position,
    duration: clearDuration ? null : duration ?? this.duration,
    error: clearError ? null : error ?? this.error,
  );
}

class AttachmentAudioPlaybackController
    extends Notifier<AttachmentAudioPlaybackState> {
  late final AttachmentAudioDriver _driver;
  late final List<StreamSubscription<dynamic>> _subs;
  var _operation = 0;

  @override
  AttachmentAudioPlaybackState build() {
    _driver = ref.read(attachmentAudioDriverFactoryProvider)();
    _subs = [
      _driver.positionStream.listen(_onPosition),
      _driver.durationStream.listen(_onDuration),
      _driver.statusStream.listen(_onStatus),
    ];
    ref.onDispose(() {
      unawaited(_disposeDriver());
    });
    return const AttachmentAudioPlaybackState();
  }

  Future<void> toggleUrl(
    String attachmentId, {
    required Future<String> Function() loadUrl,
    String? mimeType,
  }) => _toggleWith<String>(
    attachmentId,
    load: loadUrl,
    play: (url) => _driver.playUrl(url, mimeType: mimeType),
  );

  Future<void> _toggleWith<T>(
    String attachmentId, {
    required Future<T> Function() load,
    required Future<void> Function(T source) play,
  }) async {
    if (state.activeAttachmentId == attachmentId && state.loading) return;
    final token = ++_operation;

    if (state.activeAttachmentId == attachmentId &&
        state.playing &&
        !state.loading) {
      await _driver.pause();
      if (!ref.mounted) return;
      if (token == _operation) {
        state = state.copyWith(loading: false, playing: false);
      }
      return;
    }

    if (state.activeAttachmentId == attachmentId &&
        !state.completed &&
        !state.loading &&
        state.error == null) {
      await _driver.resume();
      if (!ref.mounted) return;
      if (token == _operation) {
        state = state.copyWith(loading: false, playing: true, clearError: true);
      }
      return;
    }

    if (state.activeAttachmentId != null &&
        state.activeAttachmentId != attachmentId) {
      await _driver.stop();
      if (!ref.mounted) return;
    }

    state = AttachmentAudioPlaybackState(
      activeAttachmentId: attachmentId,
      loading: true,
    );
    try {
      final source = await load();
      if (!ref.mounted || token != _operation) return;
      await play(source);
      if (!ref.mounted || token != _operation) return;
      state = state.copyWith(
        loading: false,
        playing: true,
        completed: false,
        position: Duration.zero,
        clearError: true,
      );
    } catch (e) {
      if (!ref.mounted || token != _operation) return;
      state = AttachmentAudioPlaybackState(
        activeAttachmentId: attachmentId,
        error: _playbackErrorCode(e),
      );
    }
  }

  Future<void> stop() async {
    _operation++;
    await _driver.stop();
    if (!ref.mounted) return;
    state = const AttachmentAudioPlaybackState();
  }

  Future<void> seek(String attachmentId, Duration position) async {
    if (state.activeAttachmentId != attachmentId || state.error != null) return;
    final target = _clampSeekPosition(position, state.duration);
    await _driver.seek(target);
    if (!ref.mounted) return;
    state = state.copyWith(position: target, completed: false);
  }

  void _onPosition(Duration position) {
    if (!ref.mounted) return;
    if (state.activeAttachmentId == null) return;
    state = state.copyWith(position: position, completed: false);
  }

  void _onDuration(Duration duration) {
    if (!ref.mounted) return;
    if (state.activeAttachmentId == null) return;
    state = state.copyWith(duration: duration);
  }

  void _onStatus(AttachmentAudioStatus status) {
    if (!ref.mounted) return;
    if (state.activeAttachmentId == null) return;
    state = switch (status) {
      AttachmentAudioStatus.playing => state.copyWith(
        loading: false,
        playing: true,
        completed: false,
        clearError: true,
      ),
      AttachmentAudioStatus.paused => state.copyWith(
        loading: false,
        playing: false,
        completed: false,
      ),
      AttachmentAudioStatus.completed => state.copyWith(
        loading: false,
        playing: false,
        completed: true,
        position: state.duration ?? state.position,
      ),
      AttachmentAudioStatus.stopped => state.copyWith(
        loading: false,
        playing: false,
      ),
    };
  }

  Future<void> _disposeDriver() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _driver.dispose();
  }
}

final attachmentAudioPlaybackProvider =
    NotifierProvider<
      AttachmentAudioPlaybackController,
      AttachmentAudioPlaybackState
    >(AttachmentAudioPlaybackController.new);

String _playbackErrorCode(Object error) {
  if (_isMissingAttachmentContent(error)) {
    return AttachmentAudioError.attachmentMissing;
  }
  if (_isOfflineAttachmentContent(error)) {
    return AttachmentAudioError.attachmentOffline;
  }
  return AttachmentAudioError.playbackFailed;
}

bool _isMissingAttachmentContent(Object error) {
  if (error case ApiException(:final isNotFound) when isNotFound) {
    return true;
  }
  // Fixture repositories mirror a 404 with a StateError, so widget tests exercise the same UI branch
  // without a live Dio stack. Keep this narrowly attachment-content shaped; generic "not found" strings
  // remain transient playback failures.
  // fixture 用 StateError 模拟 404，让 widget test 无需真 Dio 也能走同一分支。只识别附件内容形状，
  // 泛化 "not found" 仍按瞬时播放失败处理。
  final text = error.toString();
  return text.contains('attachment content not found') ||
      text.contains('ATTACHMENT_NOT_FOUND');
}

bool _isOfflineAttachmentContent(Object error) {
  if (error case ApiException(:final isTransport) when isTransport) {
    return true;
  }
  final text = error.toString().toLowerCase();
  return text.contains('connection refused') ||
      text.contains('connection timed out') ||
      text.contains('network is unreachable') ||
      text.contains('no route to host');
}

Duration _clampSeekPosition(Duration position, Duration? duration) {
  if (position < Duration.zero) return Duration.zero;
  final d = duration;
  if (d != null && d >= Duration.zero && position > d) return d;
  return position;
}
