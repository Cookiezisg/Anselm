import 'dart:io';

import 'package:anselm/features/chat/state/audio_attachment_recorder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';

class _FakeAudioAttachmentCapture implements AudioAttachmentCapture {
  _FakeAudioAttachmentCapture(this.bytes, {this.permission = true});

  final List<int> bytes;
  final bool permission;
  String? path;
  var cancelled = false;
  var disposed = false;

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Stream<Amplitude> onAmplitudeChanged(Duration interval) =>
      const Stream<Amplitude>.empty();

  @override
  Future<void> start(String path) async {
    this.path = path;
  }

  @override
  Future<String?> stop() async {
    final p = path;
    if (p == null) return null;
    await File(p).writeAsBytes(bytes, flush: true);
    return p;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  test(
    'records to a temporary m4a, returns bytes, and removes the file',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'anselm_audio_attachment_recorder_test_',
      );
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final capture = _FakeAudioAttachmentCapture([1, 2, 3, 4]);
      final container = ProviderContainer(
        overrides: [
          audioAttachmentDraftDataDirProvider.overrideWithValue(dir.path),
          audioAttachmentCaptureFactoryProvider.overrideWithValue(
            () => capture,
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(audioAttachmentRecorderProvider, (_, _) {});
      addTearDown(sub.close);

      await container.read(audioAttachmentRecorderProvider.notifier).start();

      expect(container.read(audioAttachmentRecorderProvider).recording, isTrue);
      final path = capture.path;
      expect(path, isNotNull);
      expect(path!, startsWith(dir.path));
      expect(path, endsWith('.m4a'));

      final recorded = await container
          .read(audioAttachmentRecorderProvider.notifier)
          .finish();

      expect(recorded, isNotNull);
      expect(recorded!.bytes, [1, 2, 3, 4]);
      expect(recorded.filename, endsWith('.m4a'));
      expect(recorded.mimeType, 'audio/mp4');
      expect(container.read(audioAttachmentRecorderProvider).active, isFalse);
      expect(capture.disposed, isTrue);
      expect(await File(path).exists(), isFalse);
    },
  );

  test('permission denial is explicit and cleans up the recorder', () async {
    final capture = _FakeAudioAttachmentCapture(const [], permission: false);
    final container = ProviderContainer(
      overrides: [
        audioAttachmentDraftDataDirProvider.overrideWithValue('.anselm-test'),
        audioAttachmentCaptureFactoryProvider.overrideWithValue(() => capture),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(audioAttachmentRecorderProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(audioAttachmentRecorderProvider.notifier).start();

    final state = container.read(audioAttachmentRecorderProvider);
    expect(state.active, isFalse);
    expect(state.error, audioAttachmentErrorPermissionDenied);
    expect(capture.cancelled, isTrue);
    expect(capture.disposed, isTrue);
  });
}
