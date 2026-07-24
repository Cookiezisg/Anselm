import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as audioplayers;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Playback status normalized away from the concrete platform player.
/// 播放状态从具体平台播放器归一化出来，UI/状态层不绑定插件枚举。
enum AttachmentAudioStatus { stopped, playing, paused, completed }

/// Replaceable driver for sent audio attachment playback. The controller owns a single instance, so only
/// one transcript attachment can play at once; switching attachments stops the previous source first.
/// 已发送音频附件播放驱动。controller 只持有一个实例，因此 transcript 内同时只有一个附件播放；切换附件先停旧源。
abstract interface class AttachmentAudioDriver {
  Stream<Duration> get positionStream;
  Stream<Duration> get durationStream;
  Stream<AttachmentAudioStatus> get statusStream;

  Future<void> playBytes(List<int> bytes, {String? mimeType});
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}

class AudioplayersAttachmentAudioDriver implements AttachmentAudioDriver {
  AudioplayersAttachmentAudioDriver() {
    _player.setReleaseMode(audioplayers.ReleaseMode.stop);
  }

  final audioplayers.AudioPlayer _player = audioplayers.AudioPlayer();

  @override
  Stream<Duration> get positionStream => _player.onPositionChanged;

  @override
  Stream<Duration> get durationStream => _player.onDurationChanged;

  @override
  Stream<AttachmentAudioStatus> get statusStream =>
      _player.onPlayerStateChanged.map(
        (s) => switch (s) {
          audioplayers.PlayerState.playing => AttachmentAudioStatus.playing,
          audioplayers.PlayerState.paused => AttachmentAudioStatus.paused,
          audioplayers.PlayerState.completed => AttachmentAudioStatus.completed,
          audioplayers.PlayerState.stopped => AttachmentAudioStatus.stopped,
          audioplayers.PlayerState.disposed => AttachmentAudioStatus.stopped,
        },
      );

  @override
  Future<void> playBytes(List<int> bytes, {String? mimeType}) => _player.play(
    audioplayers.BytesSource(Uint8List.fromList(bytes), mimeType: mimeType),
  );

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

final attachmentAudioDriverFactoryProvider =
    Provider<AttachmentAudioDriver Function()>(
      (ref) => AudioplayersAttachmentAudioDriver.new,
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

  Future<void> toggle(
    String attachmentId, {
    required Future<List<int>> Function() loadBytes,
    String? mimeType,
  }) async {
    if (state.activeAttachmentId == attachmentId && state.loading) return;
    final token = ++_operation;

    if (state.activeAttachmentId == attachmentId &&
        state.playing &&
        !state.loading) {
      await _driver.pause();
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
      if (token == _operation) {
        state = state.copyWith(loading: false, playing: true, clearError: true);
      }
      return;
    }

    if (state.activeAttachmentId != null &&
        state.activeAttachmentId != attachmentId) {
      await _driver.stop();
    }

    state = AttachmentAudioPlaybackState(
      activeAttachmentId: attachmentId,
      loading: true,
    );
    try {
      final bytes = await loadBytes();
      if (token != _operation) return;
      await _driver.playBytes(bytes, mimeType: mimeType);
      if (token != _operation) return;
      state = state.copyWith(
        loading: false,
        playing: true,
        completed: false,
        position: Duration.zero,
        clearError: true,
      );
    } catch (_) {
      if (token != _operation) return;
      state = AttachmentAudioPlaybackState(
        activeAttachmentId: attachmentId,
        error: 'playback_failed',
      );
    }
  }

  Future<void> stop() async {
    _operation++;
    await _driver.stop();
    state = const AttachmentAudioPlaybackState();
  }

  void _onPosition(Duration position) {
    if (state.activeAttachmentId == null) return;
    state = state.copyWith(position: position, completed: false);
  }

  void _onDuration(Duration duration) {
    if (state.activeAttachmentId == null) return;
    state = state.copyWith(duration: duration);
  }

  void _onStatus(AttachmentAudioStatus status) {
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
