import 'dart:async';

import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/features/chat/state/attachment_audio_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// Sent-audio playback is stateful glue around a platform plugin. Keep the important behavior testable
// without native audio: one active attachment, pause/resume semantics, switch-stops-old, stream progress,
// and honest failures.
// 已发送音频播放是平台插件外的一层状态胶水。用假 driver 钉住关键行为:单活跃、暂停/恢复、切换停旧、流进度、失败诚实落态。

class _FakeAudioDriver implements AttachmentAudioDriver {
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration>.broadcast();
  final statuses = StreamController<AttachmentAudioStatus>.broadcast();
  final playPayloads = <List<int>>[];
  final playMimeTypes = <String?>[];
  var pauseCalls = 0;
  var resumeCalls = 0;
  var stopCalls = 0;
  var disposeCalls = 0;
  Object? playError;

  @override
  Stream<Duration> get positionStream => positions.stream;

  @override
  Stream<Duration> get durationStream => durations.stream;

  @override
  Stream<AttachmentAudioStatus> get statusStream => statuses.stream;

  @override
  Future<void> playBytes(List<int> bytes, {String? mimeType}) async {
    if (playError case final e?) throw e;
    playPayloads.add(List<int>.of(bytes));
    playMimeTypes.add(mimeType);
    statuses.add(AttachmentAudioStatus.playing);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    statuses.add(AttachmentAudioStatus.paused);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    statuses.add(AttachmentAudioStatus.playing);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    statuses.add(AttachmentAudioStatus.stopped);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await positions.close();
    await durations.close();
    await statuses.close();
  }
}

(ProviderContainer, _FakeAudioDriver) _setup() {
  final driver = _FakeAudioDriver();
  final c = ProviderContainer(
    overrides: [
      attachmentAudioDriverFactoryProvider.overrideWithValue(() => driver),
    ],
  );
  addTearDown(c.dispose);
  return (c, driver);
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('first toggle loads bytes and starts one active attachment', () async {
    final (c, driver) = _setup();
    await c
        .read(attachmentAudioPlaybackProvider.notifier)
        .toggle(
          'att_1',
          loadBytes: () async => [1, 2, 3],
          mimeType: 'audio/webm',
        );

    final state = c.read(attachmentAudioPlaybackProvider);
    expect(state.activeAttachmentId, 'att_1');
    expect(state.playing, isTrue);
    expect(state.loading, isFalse);
    expect(driver.playPayloads, [
      [1, 2, 3],
    ]);
    expect(driver.playMimeTypes, ['audio/webm']);
  });

  test(
    'same active attachment pauses, then resumes without reloading bytes',
    () async {
      final (c, driver) = _setup();
      final n = c.read(attachmentAudioPlaybackProvider.notifier);

      await n.toggle('att_1', loadBytes: () async => [1]);
      await n.toggle('att_1', loadBytes: () async => [9]);
      expect(driver.pauseCalls, 1);
      expect(c.read(attachmentAudioPlaybackProvider).playing, isFalse);

      await n.toggle('att_1', loadBytes: () async => [9]);
      expect(driver.resumeCalls, 1);
      expect(driver.playPayloads, [
        [1],
      ]);
    },
  );

  test(
    'switching attachments stops the previous source before playing new bytes',
    () async {
      final (c, driver) = _setup();
      final n = c.read(attachmentAudioPlaybackProvider.notifier);

      await n.toggle('att_1', loadBytes: () async => [1]);
      await n.toggle('att_2', loadBytes: () async => [2]);

      expect(driver.stopCalls, 1);
      expect(
        c.read(attachmentAudioPlaybackProvider).activeAttachmentId,
        'att_2',
      );
      expect(driver.playPayloads, [
        [1],
        [2],
      ]);
    },
  );

  test(
    'explicit stop clears active playback state and stops the driver',
    () async {
      final (c, driver) = _setup();
      final n = c.read(attachmentAudioPlaybackProvider.notifier);

      await n.toggle('att_1', loadBytes: () async => [1]);
      await n.stop();

      final state = c.read(attachmentAudioPlaybackProvider);
      expect(driver.stopCalls, 1);
      expect(state.activeAttachmentId, isNull);
      expect(state.playing, isFalse);
      expect(state.loading, isFalse);
      expect(state.completed, isFalse);
      expect(state.error, isNull);
    },
  );

  test(
    'driver streams update duration, position, progress and completion',
    () async {
      final (c, driver) = _setup();
      await c
          .read(attachmentAudioPlaybackProvider.notifier)
          .toggle('att_1', loadBytes: () async => [1]);

      driver.durations.add(const Duration(seconds: 10));
      driver.positions.add(const Duration(seconds: 3));
      await _tick();
      var state = c.read(attachmentAudioPlaybackProvider);
      expect(state.durationFor('att_1'), const Duration(seconds: 10));
      expect(state.positionFor('att_1'), const Duration(seconds: 3));
      expect(state.progressFor('att_1'), closeTo(0.3, 0.001));

      driver.statuses.add(AttachmentAudioStatus.completed);
      await _tick();
      state = c.read(attachmentAudioPlaybackProvider);
      expect(state.playing, isFalse);
      expect(state.completed, isTrue);
      expect(state.progressFor('att_1'), 1);
    },
  );

  test('play failure leaves a retryable active error state', () async {
    final (c, driver) = _setup();
    driver.playError = StateError('boom');

    await c
        .read(attachmentAudioPlaybackProvider.notifier)
        .toggle('att_1', loadBytes: () async => [1]);

    final state = c.read(attachmentAudioPlaybackProvider);
    expect(state.activeAttachmentId, 'att_1');
    expect(state.loading, isFalse);
    expect(state.playing, isFalse);
    expect(state.errorFor('att_1'), 'playback_failed');
  });

  test(
    'missing attachment content leaves a terminal missing error state',
    () async {
      final (c, driver) = _setup();

      await c
          .read(attachmentAudioPlaybackProvider.notifier)
          .toggle(
            'att_1',
            loadBytes: () async => throw const ApiException(
              code: 'ATTACHMENT_NOT_FOUND',
              message: 'attachment not found',
              httpStatus: 404,
            ),
          );

      final state = c.read(attachmentAudioPlaybackProvider);
      expect(state.activeAttachmentId, 'att_1');
      expect(state.loading, isFalse);
      expect(state.playing, isFalse);
      expect(state.errorFor('att_1'), AttachmentAudioError.attachmentMissing);
      expect(driver.playPayloads, isEmpty);
    },
  );
}
