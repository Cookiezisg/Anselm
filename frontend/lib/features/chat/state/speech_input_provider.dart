import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/contract/conversation.dart' as conversation_contract;
import '../../../core/contract/workspace.dart';
import '../../../core/model/model_capabilities.dart';
import '../../../core/runtime.dart';
import '../../settings/state/workspaces_provider.dart';
import 'conversation_header.dart';
import 'selected_conversation.dart';

const speechInputErrorUnavailable = 'unavailable';
const speechInputErrorPermissionDenied = 'permission_denied';
const speechInputErrorConnectionLost = 'connection_lost';
const speechInputErrorFailed = 'failed';
const _speechRetryMaxBytes = 5 * 1024 * 1024;

class SpeechInputState {
  const SpeechInputState({
    this.recording = false,
    this.finishing = false,
    this.committed = '',
    this.partial = '',
    this.elapsed = Duration.zero,
    this.level = 0,
    this.error,
    this.canRetry = false,
  });

  final bool recording;
  final bool finishing;
  final String committed;
  final String partial;
  final Duration elapsed;
  final double level;
  final String? error;
  final bool canRetry;

  String get text => committed + partial;
  bool get active => recording || finishing;

  SpeechInputState copyWith({
    bool? recording,
    bool? finishing,
    String? committed,
    String? partial,
    Duration? elapsed,
    double? level,
    String? error,
    bool? canRetry,
    bool clearError = false,
  }) => SpeechInputState(
    recording: recording ?? this.recording,
    finishing: finishing ?? this.finishing,
    committed: committed ?? this.committed,
    partial: partial ?? this.partial,
    elapsed: elapsed ?? this.elapsed,
    level: level ?? this.level,
    error: clearError ? null : error ?? this.error,
    canRetry: canRetry ?? this.canRetry,
  );
}

final speechInputAvailableProvider = Provider<bool>((ref) {
  final activeWorkspaceID = ref.watch(activeWorkspaceProvider);
  if (activeWorkspaceID == null || activeWorkspaceID.isEmpty) return false;

  final caps = ref.watch(modelCapabilitiesProvider).value ?? const [];
  final selected = ref.watch(selectedConversationProvider);
  final workspaces = ref.watch(workspacesProvider).value ?? const [];
  final workspace = workspaces
      .where((w) => w.id == activeWorkspaceID)
      .firstOrNull;

  final ({String apiKeyId, String modelId})? effective;
  if (selected == null) {
    effective =
        ref.watch(landingModelProvider) ??
        _tupleFromWorkspaceModelRef(workspace?.defaultDialogue);
  } else {
    final headerState = ref.watch(conversationHeaderProvider(selected.id));
    if (!headerState.hasValue) return false;
    final header = headerState.value;
    effective =
        _tupleFromConversationModelRef(header?.modelOverride) ??
        _tupleFromWorkspaceModelRef(workspace?.defaultDialogue);
  }

  final current = effective;
  if (current == null) return false;
  return caps.any(
    (m) =>
        m.apiKeyId == current.apiKeyId &&
        m.modelId == current.modelId &&
        m.provider == 'anselm' &&
        m.modelId == 'anselm-auto',
  );
});

({String apiKeyId, String modelId})? _tupleFromWorkspaceModelRef(
  ModelRef? ref,
) => ref == null ? null : (apiKeyId: ref.apiKeyId, modelId: ref.modelId);

({String apiKeyId, String modelId})? _tupleFromConversationModelRef(
  conversation_contract.ModelRef? ref,
) => ref == null ? null : (apiKeyId: ref.apiKeyId, modelId: ref.modelId);

class SpeechInputController extends Notifier<SpeechInputState> {
  AudioRecorder? _recorder;
  WebSocketChannel? _channel;
  StreamSubscription<List<int>>? _audioSub;
  StreamSubscription<dynamic>? _socketSub;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _elapsedTimer;
  DateTime? _startedAt;
  bool _serverFinished = false;
  bool _replaying = false;
  final List<Uint8List> _retryFrames = [];
  var _retryBytes = 0;

  @override
  SpeechInputState build() {
    ref.onDispose(() {
      unawaited(_close(cancelRecorder: true, resetState: false));
    });
    return const SpeechInputState();
  }

  Future<void> start() async {
    if (state.active) return;
    if (!ref.read(speechInputAvailableProvider)) {
      state = const SpeechInputState(error: speechInputErrorUnavailable);
      return;
    }
    state = const SpeechInputState(recording: true);
    _serverFinished = false;
    _replaying = false;
    _clearRetryBuffer();
    try {
      _connectSocket();

      final recorder = AudioRecorder();
      _recorder = recorder;
      final allowed = await recorder.hasPermission();
      if (!allowed) {
        await _close(cancelRecorder: true);
        state = const SpeechInputState(error: speechInputErrorPermissionDenied);
        return;
      }
      final stream = await recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          streamBufferSize: 4096,
        ),
      );
      _audioSub = stream.listen((bytes) {
        if (bytes.isNotEmpty) {
          _rememberFrame(bytes);
          _channel?.sink.add(bytes);
        }
      }, onError: (Object e) => _fail(e));
      _startMeters(recorder);
    } catch (e) {
      await _close(cancelRecorder: true);
      state = const SpeechInputState(error: speechInputErrorFailed);
    }
  }

  Future<void> finish() async {
    if (!state.active) return;
    _stopMeters();
    state = state.copyWith(recording: false, finishing: true, level: 0);
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder?.stop();
    await _recorder?.dispose();
    _recorder = null;
    _channel?.sink.add(jsonEncode({'type': 'finish'}));
  }

  Future<void> retry() async {
    if (state.active || !state.canRetry || _retryFrames.isEmpty) return;
    if (!ref.read(speechInputAvailableProvider)) {
      state = state.copyWith(
        recording: false,
        finishing: false,
        error: speechInputErrorUnavailable,
        canRetry: true,
      );
      return;
    }
    final snapshot = state;
    state = SpeechInputState(
      finishing: true,
      committed: snapshot.text,
      elapsed: snapshot.elapsed,
    );
    _serverFinished = false;
    _replaying = true;
    try {
      _connectSocket();
      for (final frame in List<Uint8List>.of(_retryFrames)) {
        _channel?.sink.add(frame);
      }
      _channel?.sink.add(jsonEncode({'type': 'finish'}));
    } catch (_) {
      await _close(
        cancelRecorder: false,
        resetState: false,
        keepRetryBuffer: true,
      );
      state = SpeechInputState(
        committed: snapshot.committed,
        partial: snapshot.partial,
        elapsed: snapshot.elapsed,
        error: speechInputErrorFailed,
        canRetry: _retryFrames.isNotEmpty,
      );
    }
  }

  Future<void> discardRetry() async {
    await _close(cancelRecorder: true, resetState: false);
    state = const SpeechInputState();
  }

  Future<void> cancel() async {
    try {
      _channel?.sink.add(jsonEncode({'type': 'cancel'}));
    } catch (_) {
      // Best-effort: cancellation must still tear down local recording even if the socket is already
      // gone. The gateway's session max age remains the remote cleanup fallback.
    }
    await _close(cancelRecorder: true);
  }

  void _connectSocket() {
    final uri = _speechUri();
    final headers = _headers();
    final channel = IOWebSocketChannel.connect(uri, headers: headers);
    _channel = channel;
    _socketSub = channel.stream.listen(
      _handleGatewayEvent,
      onError: (Object e) => _fail(e),
      onDone: () {
        if (state.active && !_serverFinished) {
          unawaited(_failAsync(speechInputErrorConnectionLost));
        }
      },
    );
  }

  Uri _speechUri() {
    final backend = ref.read(backendStartupProvider);
    final base = Uri.parse(backend.baseUrl ?? '');
    final scheme = switch (base.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      'wss' || 'ws' => base.scheme,
      _ => 'ws',
    };
    return base.replace(scheme: scheme, path: '/api/v1/speech/asr');
  }

  Map<String, String> _headers() {
    final headers = <String, String>{};
    final ws = ref.read(activeWorkspaceProvider);
    if (ws != null && ws.isNotEmpty) {
      headers['X-Anselm-Workspace-ID'] = ws;
    }
    final token = ref.read(backendStartupProvider).authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  void _handleGatewayEvent(dynamic raw) {
    if (raw is! String) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    final type = decoded['type'] as String? ?? '';
    if (type == 'session.finished') {
      _serverFinished = true;
      unawaited(_close(cancelRecorder: false, keepText: true));
      return;
    }
    if (type == 'error') {
      final code = decoded['code']?.toString() ?? '';
      unawaited(_failAsync(_errorFromGatewayCode(code)));
      return;
    }
    if (type.endsWith('.completed')) {
      _clearReplayTranscriptIfNeeded();
      final text = _completedText(decoded);
      state = state.copyWith(committed: state.committed + text, partial: '');
      return;
    }
    if (type.endsWith('.delta')) {
      _clearReplayTranscriptIfNeeded();
      state = state.copyWith(partial: _deltaText(decoded));
    }
  }

  void _clearReplayTranscriptIfNeeded() {
    if (!_replaying) return;
    _replaying = false;
    state = state.copyWith(committed: '', partial: '', clearError: true);
  }

  String _completedText(Map<String, dynamic> event) {
    final text = event['transcript'] ?? event['text'];
    return text is String ? text : '';
  }

  String _deltaText(Map<String, dynamic> event) {
    final text = event['text'];
    final stash = event['stash'];
    return (text is String ? text : '') + (stash is String ? stash : '');
  }

  void _startMeters(AudioRecorder recorder) {
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

  String _errorFromGatewayCode(String code) => code == 'SPEECH_UPSTREAM_CLOSED'
      ? speechInputErrorConnectionLost
      : speechInputErrorFailed;

  void _fail(Object e) {
    unawaited(_failAsync(speechInputErrorConnectionLost));
  }

  Future<void> _failAsync(String error) async {
    final snapshot = state;
    final retryable = _retryFrames.isNotEmpty;
    await _close(
      cancelRecorder: true,
      resetState: false,
      keepRetryBuffer: true,
    );
    state = SpeechInputState(
      committed: snapshot.committed,
      partial: snapshot.partial,
      elapsed: snapshot.elapsed,
      error: error,
      canRetry: retryable,
    );
  }

  void _rememberFrame(List<int> bytes) {
    if (_retryBytes >= _speechRetryMaxBytes) return;
    final remaining = _speechRetryMaxBytes - _retryBytes;
    final frame = Uint8List.fromList(
      bytes.length <= remaining ? bytes : bytes.take(remaining).toList(),
    );
    if (frame.isEmpty) return;
    _retryFrames.add(frame);
    _retryBytes += frame.length;
  }

  void _clearRetryBuffer() {
    _retryFrames.clear();
    _retryBytes = 0;
  }

  Future<void> _close({
    required bool cancelRecorder,
    bool keepText = false,
    bool resetState = true,
    bool keepRetryBuffer = false,
  }) async {
    _stopMeters();
    await _audioSub?.cancel();
    _audioSub = null;
    await _socketSub?.cancel();
    _socketSub = null;
    if (cancelRecorder) {
      await _recorder?.cancel();
    } else {
      await _recorder?.stop();
    }
    await _recorder?.dispose();
    _recorder = null;
    await _channel?.sink.close();
    _channel = null;
    _replaying = false;
    if (!keepRetryBuffer) _clearRetryBuffer();
    if (!resetState) return;
    if (!keepText) {
      state = const SpeechInputState();
    } else {
      state = state.copyWith(
        recording: false,
        finishing: false,
        partial: '',
        level: 0,
      );
    }
  }
}

final speechInputProvider =
    NotifierProvider.autoDispose<SpeechInputController, SpeechInputState>(
      SpeechInputController.new,
    );
