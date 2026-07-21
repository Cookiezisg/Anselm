import 'package:anselm/features/chat/model/mention_spans.dart';
import 'package:anselm/features/chat/model/user_attachment.dart';
import 'package:flutter_test/flutter_test.dart';

// The mention position derivation (consuming left→right literal match — the backend stores NO offsets) +
// the attachment meta-line helper. Pure functions; this is their whole behavioural pin.
// 提及推位(消耗式字面匹配,后端不存偏移)+ 附件 meta 行助手。纯函数,行为全钉在此。

MentionSnapshot _m(
  String name, {
  String type = 'function',
  String id = 'fn_1',
  bool available = true,
}) => MentionSnapshot(type: type, id: id, name: name, available: available);

List<String> _shape(List<MentionSegment> segs) => [
  for (final s in segs)
    switch (s) {
      MentionTextSegment(:final text) => 't:$text',
      MentionPillSegment(:final snapshot) => 'p:${snapshot.name}',
    },
];

void main() {
  group('resolveMentionSegments', () {
    test('basic: one mention mid-sentence', () {
      final segs = resolveMentionSegments('帮我看下 @sync 为什么失败', [_m('sync')]);
      expect(_shape(segs), ['t:帮我看下 ', 'p:sync', 't: 为什么失败']);
    });

    test('multiple mentions in order; adjacent text preserved', () {
      final segs = resolveMentionSegments('让 @bot 按 @手册 走', [
        _m('bot'),
        _m('手册'),
      ]);
      expect(_shape(segs), ['t:让 ', 'p:bot', 't: 按 ', 'p:手册', 't: 走']);
    });

    test('same-name mentions map one-to-one in order (consuming)', () {
      final segs = resolveMentionSegments('@a 然后再 @a', [
        _m('a', id: 'fn_1'),
        _m('a', id: 'fn_2'),
      ]);
      expect(_shape(segs), ['p:a', 't: 然后再 ', 'p:a']);
      expect((segs[0] as MentionPillSegment).snapshot.id, 'fn_1');
      expect((segs[2] as MentionPillSegment).snapshot.id, 'fn_2');
    });

    test('unavailable snapshot never matches — literal text stays', () {
      final segs = resolveMentionSegments('看下 @ghost 呢', [
        _m('ghost', available: false),
      ]);
      expect(_shape(segs), ['t:看下 @ghost 呢']);
    });

    test(
      'renamed source (no literal match) degrades to plain text, later snapshots still match',
      () {
        final segs = resolveMentionSegments('对比 @old 和 @b', [
          _m('new'),
          _m('b'),
        ]);
        expect(_shape(segs), ['t:对比 @old 和 ', 'p:b']);
      },
    );

    test('regex metacharacters in names are literal (indexOf, not regex)', () {
      final segs = resolveMentionSegments(r'调 @a.*b(x) 一下', [_m(r'a.*b(x)')]);
      expect(_shape(segs), ['t:调 ', r'p:a.*b(x)', 't: 一下']);
    });

    test('mention at start and at end; emoji/CJK names', () {
      final segs = resolveMentionSegments('@开头 中间 @结尾🎯', [
        _m('开头'),
        _m('结尾🎯'),
      ]);
      expect(_shape(segs), ['p:开头', 't: 中间 ', 'p:结尾🎯']);
    });

    test(
      'empty text → empty; no snapshots → single text run; empty name skipped',
      () {
        expect(resolveMentionSegments('', [_m('a')]), isEmpty);
        expect(_shape(resolveMentionSegments('hi', const [])), ['t:hi']);
        expect(_shape(resolveMentionSegments('hi @ there', [_m('')])), [
          't:hi @ there',
        ]);
      },
    );
  });

  group('attachmentMetaLine', () {
    test('extension + human size', () {
      expect(
        attachmentMetaLine(filename: 'report.pdf', sizeBytes: 1258291),
        'PDF · 1.2 MB',
      );
      expect(
        attachmentMetaLine(filename: 'notes.md', sizeBytes: 8601),
        'MD · 8.4 KB',
      );
      expect(
        attachmentMetaLine(filename: 'tiny.txt', sizeBytes: 66),
        'TXT · 66 B',
      );
    });

    test(
      'no extension → mime subtype; neither → size only; zero size kept',
      () {
        expect(
          attachmentMetaLine(
            filename: 'no-ext',
            mimeType: 'application/pdf',
            sizeBytes: 12,
          ),
          'PDF · 12 B',
        );
        expect(attachmentMetaLine(filename: 'no-ext', sizeBytes: 12), '12 B');
        expect(
          attachmentMetaLine(filename: 'empty.bin', sizeBytes: 0),
          'BIN · 0 B',
        );
      },
    );

    test(
      'overlong "extension" (>8 chars) is not an extension; dotfile has none',
      () {
        expect(
          attachmentMetaLine(filename: 'weird.superlongext99', sizeBytes: 10),
          '10 B',
        );
        expect(
          attachmentMetaLine(filename: '.gitignore', sizeBytes: 10),
          '10 B',
        );
      },
    );
  });
}
