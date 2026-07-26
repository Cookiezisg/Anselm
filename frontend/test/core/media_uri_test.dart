import 'package:anselm/core/media/media_uri.dart';
import 'package:flutter_test/flutter_test.dart';

// The document-text form of a media reference. Everything here is about NOT owning what we do not
// own: a document may legitimately contain ordinary web images, and mistaking one for ours would
// hand it to the attachment pipeline, which would then honestly report that no such attachment
// exists — a broken image where a perfectly good one was.
//
// 媒体引用的文档正文形。这里的一切都关乎**不认领不属于自己的东西**:文档里完全可以有普通网图,把它
// 误认成我们的,会把它交给附件管线,而管线随后会诚实地报告「没有这个附件」——本来好好的一张图变成了
// 一个坏掉的图。
void main() {
  const id = 'att_00112233445566aa';

  test('builds and parses its own form', () {
    expect(mediaUri(id), 'anselm://media/$id');
    expect(attachmentIdFromMediaUri(mediaUri(id)), id);
  });

  test('never claims a url it does not own', () {
    for (final foreign in [
      'https://example.com/cat.png',
      'http://127.0.0.1:8080/api/v1/attachments/$id/content',
      'anselm://document/$id', // a different host under the same scheme
      'media/$id',
      './chart.png',
      '',
    ]) {
      expect(
        attachmentIdFromMediaUri(foreign),
        isNull,
        reason: 'must not claim $foreign',
      );
    }
    expect(attachmentIdFromMediaUri(null), isNull);
  });

  test('a well-formed uri carrying a malformed id is refused', () {
    // The shape check is the id grammar itself — an app-shaped url whose payload is not an
    // attachment id would otherwise send a nonsense lookup down the pipeline.
    // 形状检查就是 id 文法本身——一个像模像样却载着非附件 id 的 url,否则会把一次无意义的查询送进管线。
    expect(attachmentIdFromMediaUri('anselm://media/not-an-id'), isNull);
    expect(attachmentIdFromMediaUri('anselm://media/att_TOOSHORT'), isNull);
    expect(attachmentIdFromMediaUri('anselm://media/'), isNull);
  });
}
