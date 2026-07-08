import 'package:anselm/core/editor/an_editor_markdown.dart';
import 'package:anselm/core/editor/an_editor_mention.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

// E9a — the document ↔ markdown codec. The built-in super_editor serializers carry the block + inline
// types; these tests lock the ONE thing this layer adds: the @mention `[[id]]` round-trip, whose verbatim
// fidelity is a backend contract (the wikilink parser builds relation edges from it). codec 往返测,重点 `[[id]]` 逐字。

const _id = 'wf_00000000000000a1';

MutableDocument _docWithMention() => MutableDocument(nodes: [
      ParagraphNode(
        id: 'p1',
        text: AttributedText('见 。', null, {
          2: const MentionPlaceholder(id: _id, name: '每日销量对账', kind: 'workflow'),
        }),
      ),
    ]);

void main() {
  group('E9a mention round-trip', () {
    test('a mention pill serializes to the [[id]] wikilink', () {
      final md = markdownFromDocument(_docWithMention());
      expect(md.contains('[[$_id]]'), isTrue, reason: 'pill → [[id]] wire form');
      expect(md.contains('每日销量对账'), isFalse, reason: 'the display name is NOT persisted (only the id)');
      expect(md.contains('￼'), isFalse, reason: 'no raw placeholder character leaks into the markdown');
    });

    test('a [[id]] wikilink deserializes to a mention pill (name resolved, kind from prefix)', () {
      final doc = documentFromMarkdown('见 [[$_id]] 的结果', names: {_id: '每日销量对账'});
      final node = doc.getNodeAt(0)! as ParagraphNode;
      final mentions = node.text.placeholders.values.whereType<MentionPlaceholder>().toList();
      expect(mentions, hasLength(1));
      expect(mentions.first.id, _id);
      expect(mentions.first.name, '每日销量对账'); // resolved from names
      expect(mentions.first.kind, 'workflow'); // derived from the `wf_` prefix
      // The surrounding prose survives around the pill. 药丸两侧文字保留。
      expect(node.text.toPlainText(includePlaceholders: false), '见  的结果');
    });

    test('an UNKNOWN id falls back to the bare id as the display name', () {
      final doc = documentFromMarkdown('[[$_id]]');
      final m = (doc.getNodeAt(0)! as ParagraphNode).text.placeholders.values.whereType<MentionPlaceholder>().first;
      expect(m.name, _id);
    });

    test('full round-trip preserves the [[id]] verbatim and is idempotent', () {
      final md1 = markdownFromDocument(_docWithMention());
      final doc2 = documentFromMarkdown(md1, names: {_id: '每日销量对账'});
      final md2 = markdownFromDocument(doc2);
      expect(md1, md2, reason: 'doc→md→doc→md is stable');
      expect(md2.contains('[[$_id]]'), isTrue, reason: 'the id survives the whole trip verbatim');
    });

    test('mentionIdsInDocument collects every referenced id', () {
      expect(mentionIdsInDocument(_docWithMention()), [_id]);
    });
  });

  group('E9a block + inline types', () {
    test('kindFromEntityId maps the id prefix to the wire kind', () {
      expect(kindFromEntityId('fn_0000000000000001'), 'function');
      expect(kindFromEntityId('ag_0000000000000001'), 'agent');
      expect(kindFromEntityId('doc_000000000000001'), 'document');
      expect(kindFromEntityId('xyz_000000000000001'), 'xyz'); // unknown prefix → itself
    });

    test('headings / lists / tasks / inline emphasis round-trip idempotently', () {
      const source = '# 标题\n\n'
          '正文有 **粗** 和 *斜* 和 `码`。\n\n'
          '- 无序一\n'
          '- 无序二\n\n'
          '1. 有序一\n\n'
          '- [ ] 未完成\n'
          '- [x] 已完成';
      final md1 = markdownFromDocument(documentFromMarkdown(source));
      final md2 = markdownFromDocument(documentFromMarkdown(md1));
      expect(md1, md2, reason: 'idempotent on the non-code block/inline set');
      expect(md1.contains('# 标题'), isTrue);
      expect(md1.contains('**粗**'), isTrue);
      expect(md1.contains('*斜*'), isTrue);
      expect(md1.contains('`码`'), isTrue);
      expect(md1.contains('- [ ] 未完成'), isTrue);
      expect(md1.contains('- [x] 已完成'), isTrue);
    });

    test('a fenced code block survives the round-trip (content preserved; super_editor drifts trailing '
        'blank lines only)', () {
      const source = '```\nvoid main() {\n  print("hi");\n}\n```';
      final doc = documentFromMarkdown(source);
      final md = markdownFromDocument(doc);
      expect(md.contains('```'), isTrue);
      expect(md.contains('void main() {'), isTrue);
      expect(md.contains('print("hi");'), isTrue);
    });
  });
}
