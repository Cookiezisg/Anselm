import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

import '../../../core/runtime.dart';

const audioAttachmentErrorPermissionDenied = 'permission_denied';
const audioAttachmentErrorFailed = 'failed';

/// The recorded audio file that should enter the normal pending-attachment upload pipeline.
/// 录好的音频文件；后续进入普通待发附件上传链路。
class RecordedAudioAttachment {
  const RecordedAudioAttachment({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final List<int> bytes;
  final String filename;
  final String mimeType;
}

abstract interface class AudioAttachmentCapture {
  Future<bool> hasPermission();
  Future<void> start(String path);
  Stream<Amplitude> onAmplitudeChanged(Duration interval);
  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class RecordAudioAttachmentCapture implements AudioAttachmentCapture {
  RecordAudioAttachmentCapture([AudioRecorder? recorder])
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 96000,
      sampleRate: 44100,
      numChannels: 1,
    ),
    path: path,
  );

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      _recorder.onAmplitudeChanged(interval);

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

typedef AudioAttachmentCaptureFactory = AudioAttachmentCapture Function();

final audioAttachmentCaptureFactoryProvider =
    Provider<AudioAttachmentCaptureFactory>(
      (ref) => RecordAudioAttachmentCapture.new,
    );

final audioAttachmentDraftDataDirProvider = Provider<String>((ref) {
  final configured = ref.read(backendStartupProvider).dataDir;
  return _resolveAudioAttachmentDataDir(configured);
});

class AudioAttachmentRecorderState {
  const AudioAttachmentRecorderState({
    this.recording = false,
    this.finishing = false,
    this.elapsed = Duration.zero,
    this.level = 0,
    this.error,
  });

  final bool recording;
  final bool finishing;
  final Duration elapsed;
  final double level;
  final String? error;

  bool get active => recording || finishing;

  AudioAttachmentRecorderState copyWith({
    bool? recording,
    bool? finishing,
    Duration? elapsed,
    double? level,
    String? error,
    bool clearError = false,
  }) => AudioAttachmentRecorderState(
    recording: recording ?? this.recording,
    finishing: finishing ?? this.finishing,
    elapsed: elapsed ?? this.elapsed,
    level: level ?? this.level,
    error: clearError ? null : error ?? this.error,
  );
}

class AudioAttachmentRecorder extends Notifier<AudioAttachmentRecorderState> {
  AudioAttachmentCapture? _recorder;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _elapsedTimer;
  DateTime? _startedAt;
  String? _path;

  @override
  AudioAttachmentRecorderState build() {
    ref.onDispose(() {
      _stopMeters();
      unawaited(_recorder?.cancel());
      unawaited(_recorder?.dispose());
      final path = _path;
      if (path != null) unawaited(_deleteIfExists(path));
    });
    return const AudioAttachmentRecorderState();
  }

  Future<void> start() async {
    if (state.active) return;
    state = const AudioAttachmentRecorderState(recording: true);
    final recorder = ref.read(audioAttachmentCaptureFactoryProvider)();
    _recorder = recorder;
    try {
      final allowed = await recorder.hasPermission();
      if (!allowed) {
        await _close(cancelRecorder: true);
        state = const AudioAttachmentRecorderState(
          error: audioAttachmentErrorPermissionDenied,
        );
        return;
      }
      final path = await _nextPath();
      _path = path;
      await recorder.start(path);
      _startMeters(recorder);
    } catch (_) {
      await _close(cancelRecorder: true);
      state = const AudioAttachmentRecorderState(
        error: audioAttachmentErrorFailed,
      );
    }
  }

  Future<RecordedAudioAttachment?> finish() async {
    if (!state.active) return null;
    _stopMeters();
    state = state.copyWith(recording: false, finishing: true, level: 0);
    final recorder = _recorder;
    final startedPath = _path;
    String? stoppedPath;
    try {
      stoppedPath = await recorder?.stop();
      await recorder?.dispose();
      _recorder = null;
      final path = stoppedPath ?? startedPath;
      if (path == null) {
        state = const AudioAttachmentRecorderState(
          error: audioAttachmentErrorFailed,
        );
        return null;
      }
      final file = File(path);
      final bytes = await file.readAsBytes();
      await _deleteIfExists(path);
      _path = null;
      if (bytes.isEmpty) {
        state = const AudioAttachmentRecorderState(
          error: audioAttachmentErrorFailed,
        );
        return null;
      }
      state = const AudioAttachmentRecorderState();
      return RecordedAudioAttachment(
        bytes: bytes,
        filename: _filenameFromPath(path),
        mimeType: 'audio/mp4',
      );
    } catch (_) {
      final path = stoppedPath ?? startedPath;
      if (path != null) await _deleteIfExists(path);
      _path = null;
      await _close(cancelRecorder: true);
      state = const AudioAttachmentRecorderState(
        error: audioAttachmentErrorFailed,
      );
      return null;
    }
  }

  Future<void> cancel() async {
    await _close(cancelRecorder: true);
    state = const AudioAttachmentRecorderState();
  }

  Future<void> _close({required bool cancelRecorder}) async {
    _stopMeters();
    final recorder = _recorder;
    _recorder = null;
    try {
      if (cancelRecorder) await recorder?.cancel();
    } catch (_) {
      // Best-effort local cleanup. The recorder plugin may already have torn down the native session.
      // 本地清理尽力即可；native recorder 可能已经释放。
    }
    try {
      await recorder?.dispose();
    } catch (_) {}
    final path = _path;
    _path = null;
    if (path != null) await _deleteIfExists(path);
  }

  void _startMeters(AudioAttachmentCapture recorder) {
    _stopMeters();
    _startedAt = DateTime.now();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = _startedAt;
      if (started == null || !state.active) return;
      state = state.copyWith(elapsed: DateTime.now().difference(started));
    });
    _amplitudeSub = recorder
        .onAmplitudeChanged(const Duration(milliseconds: 180))
        .listen((amp) {
          if (!state.active) return;
          state = state.copyWith(level: _levelFromDb(amp.current));
        }, onError: (_) {});
  }

  void _stopMeters() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _startedAt = null;
    unawaited(_amplitudeSub?.cancel());
    _amplitudeSub = null;
  }

  double _levelFromDb(double db) {
    if (!db.isFinite) return 0;
    final clamped = db.clamp(-60.0, 0.0);
    return ((clamped + 60.0) / 60.0).clamp(0.0, 1.0).toDouble();
  }

  Future<String> _nextPath() async {
    final dir = Directory('${_dataDir()}/client/audio-attachment-drafts');
    await dir.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    return '${dir.path}/anselm-audio-$stamp.m4a';
  }

  String _dataDir() {
    return ref.read(audioAttachmentDraftDataDirProvider);
  }

  static String _filenameFromPath(String path) =>
      path.split(Platform.pathSeparator).last;

  static Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}

String _resolveAudioAttachmentDataDir(String? configured) {
  if (configured != null && configured.isNotEmpty) return configured;
  final envDir = Platform.environment['ANSELM_DATA_DIR'];
  if (envDir != null && envDir.isNotEmpty) return envDir;
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) return '.anselm';
  return '$home/.anselm';
}

final audioAttachmentRecorderProvider =
    NotifierProvider<AudioAttachmentRecorder, AudioAttachmentRecorderState>(
      AudioAttachmentRecorder.new,
    );
