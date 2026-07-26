import 'package:anselm/core/media/media_source.dart';
import 'package:flutter_test/flutter_test.dart';

// The read-aloud wire contract's front half. `cached` is the money fact: the UI renders the same
// either way, so nothing on screen would ever reveal that a "cache hit" had quietly paid a
// provider — only this field, and a test that reads it, can.
//
// 朗读线缆契约的前半。`cached` 是**钱**的事实:两种情形 UI 渲得一样,故屏幕上永远不会暴露一次
// 「命中缓存」其实悄悄付了钱——只有这个字段、以及一个读它的测试,能看见。
void main() {
  test('ReadAloudResult mirrors the backend wire shape', () {
    final r = ReadAloudResult.fromJson({
      'attachmentId': 'att_00112233445566aa',
      'filename': 'read-aloud.wav',
      'mimeType': 'audio/wav',
      'sizeBytes': 4096,
      'cached': true,
    });
    expect(r.attachmentId, 'att_00112233445566aa');
    expect(r.mimeType, 'audio/wav');
    expect(r.cached, isTrue);
  });

  test('a fresh synthesis is not silently reported as cached', () {
    // Absent `cached` must default to FALSE. Defaulting the other way would make an older backend
    // look like it never charged for anything.
    // `cached` 缺席必须默认 **false**。反过来默认会让一个旧后端看起来从没收过钱。
    final r = ReadAloudResult.fromJson({
      'attachmentId': 'att_00112233445566bb',
      'mimeType': 'audio/wav',
    });
    expect(r.cached, isFalse);
  });

  test('a malformed row yields empty identity rather than a fake one', () {
    final r = ReadAloudResult.fromJson(const {});
    expect(r.attachmentId, isEmpty);
    expect(r.mimeType, isEmpty);
    expect(r.cached, isFalse);
  });
}
