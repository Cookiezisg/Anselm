import 'dart:async';

import 'package:anselm/core/process/backend_controller.dart';
import 'package:anselm/core/runtime.dart';
import 'package:anselm/features/chat/state/speech_input_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _ReadyBackend extends BackendStartup {
  @override
  BackendState build() => const BackendState(
    BackendPhase.ready,
    baseUrl: 'http://127.0.0.1:8080',
    authToken: 'test-token',
  );
}

class _ActiveWorkspace extends ActiveWorkspace {
  @override
  String? build() => 'ws_test';
}

class _FakeCapture implements SpeechAudioCapture {
  final audio = StreamController<List<int>>();
  final amp = StreamController<Amplitude>();
  var cancelled = false;
  var stopped = false;
  var disposed = false;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) => amp.stream;

  @override
  Future<Stream<List<int>>> startStream() async => audio.stream;

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await audio.close();
    await amp.close();
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

class _FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeWebSocketChannel();

  final incoming = StreamController<dynamic>();
  final outgoing = StreamController<dynamic>();
  final sent = <dynamic>[];

  @override
  int? closeCode;

  @override
  String? closeReason;

  @override
  String? protocol;

  @override
  Future<void> get ready => Future.value();

  @override
  Stream<dynamic> get stream => incoming.stream;

  @override
  late final WebSocketSink sink = _FakeWebSocketSink(outgoing.sink, sent);

  void failFromServer() => incoming.addError(StateError('socket lost'));
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._inner, this.sent);

  final StreamSink<dynamic> _inner;
  final List<dynamic> sent;

  @override
  Future get done => _inner.done;

  @override
  void add(dynamic data) {
    sent.add(data);
    _inner.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _inner.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream stream) => _inner.addStream(stream);

  @override
  Future close([int? closeCode, String? closeReason]) => _inner.close();
}

Future<void> _flushAsync() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  test('live socket loss reconnects once and replays buffered PCM', () async {
    final capture = _FakeCapture();
    final sockets = <_FakeWebSocketChannel>[];
    final container = ProviderContainer(
      overrides: [
        speechInputAvailableProvider.overrideWithValue(true),
        activeWorkspaceProvider.overrideWith(_ActiveWorkspace.new),
        backendStartupProvider.overrideWith(_ReadyBackend.new),
        speechAudioCaptureFactoryProvider.overrideWithValue(() => capture),
        speechSocketConnectorProvider.overrideWithValue((uri, headers) {
          expect(uri.toString(), 'ws://127.0.0.1:8080/api/v1/speech/asr');
          expect(headers['X-Anselm-Workspace-ID'], 'ws_test');
          expect(headers['Authorization'], 'Bearer test-token');
          final socket = _FakeWebSocketChannel();
          sockets.add(socket);
          return socket;
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(speechInputProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(speechInputProvider.notifier).start();
    capture.audio.add([1, 2, 3]);
    await _flushAsync();

    expect(sockets, hasLength(1));
    expect(sockets.first.sent, [
      [1, 2, 3],
    ]);

    sockets.first.failFromServer();
    await _flushAsync();

    expect(sockets, hasLength(2));
    expect(sockets.last.sent, [
      [1, 2, 3],
    ]);
    expect(container.read(speechInputProvider).recording, isTrue);
    expect(container.read(speechInputProvider).error, isNull);

    capture.audio.add([4, 5]);
    await _flushAsync();
    expect(sockets.last.sent.last, [4, 5]);
  });

  test('second live socket loss falls back to retryable draft state', () async {
    final capture = _FakeCapture();
    final sockets = <_FakeWebSocketChannel>[];
    final container = ProviderContainer(
      overrides: [
        speechInputAvailableProvider.overrideWithValue(true),
        backendStartupProvider.overrideWith(_ReadyBackend.new),
        speechAudioCaptureFactoryProvider.overrideWithValue(() => capture),
        speechSocketConnectorProvider.overrideWithValue((uri, headers) {
          final socket = _FakeWebSocketChannel();
          sockets.add(socket);
          return socket;
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(speechInputProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(speechInputProvider.notifier).start();
    capture.audio.add([1]);
    await _flushAsync();

    sockets.first.failFromServer();
    await _flushAsync();
    expect(sockets, hasLength(2));

    sockets.last.failFromServer();
    await _flushAsync();

    final state = container.read(speechInputProvider);
    expect(state.recording, isFalse);
    expect(state.error, speechInputErrorConnectionLost);
    expect(state.canRetry, isTrue);
    expect(capture.cancelled, isTrue);
    expect(capture.disposed, isTrue);
  });

  test('gateway audio-too-long error is explicit and not retryable', () async {
    final capture = _FakeCapture();
    final sockets = <_FakeWebSocketChannel>[];
    final container = ProviderContainer(
      overrides: [
        speechInputAvailableProvider.overrideWithValue(true),
        backendStartupProvider.overrideWith(_ReadyBackend.new),
        speechAudioCaptureFactoryProvider.overrideWithValue(() => capture),
        speechSocketConnectorProvider.overrideWithValue((uri, headers) {
          final socket = _FakeWebSocketChannel();
          sockets.add(socket);
          return socket;
        }),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(speechInputProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(speechInputProvider.notifier).start();
    capture.audio.add([1, 2, 3]);
    await _flushAsync();

    sockets.single.incoming.add(
      '{"type":"error","code":"SPEECH_AUDIO_TOO_LONG"}',
    );
    await _flushAsync();

    final state = container.read(speechInputProvider);
    expect(state.recording, isFalse);
    expect(state.error, speechInputErrorTooLong);
    expect(state.canRetry, isFalse);
    expect(state.committed + state.partial, isEmpty);
    expect(capture.cancelled, isTrue);
    expect(capture.disposed, isTrue);
  });
}
