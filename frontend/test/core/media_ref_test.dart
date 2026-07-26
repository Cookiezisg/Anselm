import 'package:anselm/core/media/media_ref.dart';
import 'package:flutter_test/flutter_test.dart';

// The MediaRef grammar's front half must agree with the backend's `pkg/mediaref` EXACTLY — the two
// walk the same payloads, and any divergence shows up as「模型看得见而界面渲不出」(or the reverse),
// which is invisible until someone stares at a run that «has no picture».
//
// MediaRef 文法前半必须与后端 `pkg/mediaref` **逐条**一致——两边走同一批 payload,任何分歧都表现为
// 「模型看得见而界面渲不出」(或反过来),而这在有人盯着一次「没有图」的运行之前完全不可见。
void main() {
  test('collects well-formed ids at any depth, deduped, first-seen order', () {
    final refs = collectMediaRefs({
      'image': {'attachmentId': 'att_00112233445566aa', 'mime': 'image/png'},
      'items': [
        {
          'nested': {'attachmentId': 'att_00112233445566bb'},
        },
        {'attachmentId': 'att_00112233445566aa'}, // dup
        {'attachmentId': 'not-an-id'},
        {'attachment_id': 'att_00112233445566cc'}, // wrong key
        {'attachmentId': 42}, // wrong shape
      ],
    });
    expect(refs.map((r) => r.attachmentId), [
      'att_00112233445566aa',
      'att_00112233445566bb',
    ]);
  });

  test('carries the receipt hints through', () {
    final refs = collectMediaRefs({
      'attachmentId': 'att_00112233445566aa',
      'mime': 'image/png',
      'filename': 'generated-x.png',
      'width': 1536,
      'height': 1024,
      'sizeBytes': 1234,
      'source': 'generate_image',
    });
    expect(refs, hasLength(1));
    final r = refs.single;
    expect(r.mime, 'image/png');
    expect(r.filename, 'generated-x.png');
    expect(r.width, 1536);
    expect(r.height, 1024);
    expect(r.sizeBytes, 1234);
    expect(r.source, 'generate_image');
  });

  test('recognises the STRING form receipts travel between nodes as', () {
    // An agent's answer becomes a node's `text`; the downstream payload holds a JSON STRING.
    // agent 的终答成节点 `text`;下游 payload 里是一个 JSON **字符串**。
    const receipt =
        '{"attachmentId":"att_00112233445566aa","source":"generate_image"}';
    expect(collectMediaRefs({'text': receipt}), hasLength(1));
    // Nested one level deeper — the escaped-quote case a `"key"`-anchored gate would miss.
    // 再嵌一层——带引号的闸恰好会漏掉的转义引号情形。
    expect(
      collectMediaRefs(
        '{"wrapped":"{\\"attachmentId\\":\\"att_00112233445566bb\\"}"}',
      ),
      hasLength(1),
    );
    // Prose that merely mentions the word collects nothing (and must not throw).
    // 只是提到这个词的散文收集不到东西(且不得抛)。
    expect(
      collectMediaRefs('the "attachmentId" field: att_00112233445566cc'),
      isEmpty,
    );
    expect(collectMediaRefs('{"other":"att_00112233445566dd"}'), isEmpty);
  });

  test('a degenerate payload cannot expand past the cap', () {
    const hex = '0123456789abcdef';
    final items = [
      for (var i = 0; i < 20; i++)
        {'attachmentId': 'att_00112233445566${hex[i % 16]}${hex[i ~/ 16]}'},
    ];
    expect(collectMediaRefs({'items': items}), hasLength(kMediaRefMax));
  });

  test('isAttachmentId pins the id shape', () {
    expect(isAttachmentId('att_00112233445566aa'), isTrue);
    expect(isAttachmentId('att_00112233445566AA'), isFalse); // upper hex
    expect(isAttachmentId('att_00112233445566a'), isFalse); // short
    expect(isAttachmentId('msg_00112233445566aa'), isFalse); // wrong prefix
    expect(isAttachmentId(' att_00112233445566aa'), isFalse); // anchored
  });
}
