import 'package:anselm/core/editor/an_editor_components.dart';
import 'package:anselm/core/editor/an_editor_inline_code.dart';
import 'package:anselm/core/editor/an_editor_markdown.dart';
import 'package:anselm/core/editor/an_editor_mention.dart';
import 'package:flutter/widgets.dart' show TextAlign;
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

// E9a — the document ↔ markdown codec. The built-in super_editor serializers carry the block + inline
// types; these tests lock the ONE thing this layer adds: the @mention `[[id]]` round-trip, whose verbatim
// fidelity is a backend contract (the wikilink parser builds relation edges from it). codec 往返测,重点 `[[id]]` 逐字。

const _id = 'wf_00000000000000a1';
const _nbsp = ' '; // U+00A0 — the inline-code padding spacer the codec injects on load

// The LOGICAL text of each codeAttribution run in a node, in order — with the injected NBSP padding spacers
// stripped (a loaded run is `[NBSP]code[NBSP]`; the content that round-trips to markdown is `code`).
// 各 codeAttribution run 的逻辑文本(剥去注入的 NBSP 内距;载入 run=[NBSP]code[NBSP],往返 markdown 的内容=code)。
List<String> _codeRuns(TextNode n) {
  final text = stripCodeSpacers(n.text);
  final spans = text.getAttributionSpans({codeAttribution}).toList()..sort((a, b) => a.start.compareTo(b.start));
  return [for (final s in spans) text.copyText(s.start, s.end + 1).toPlainText()];
}

// The RAW text of each codeAttribution run (spacers INCLUDED) — to assert the padding is actually present.
List<String> _rawCodeRuns(TextNode n) {
  final spans = n.text.getAttributionSpans({codeAttribution}).toList()..sort((a, b) => a.start.compareTo(b.start));
  return [for (final s in spans) n.text.copyText(s.start, s.end + 1).toPlainText()];
}

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

    test('a fenced code block KEEPS its language tag (```dart)', () {
      const source = '```dart\nfinal x = 1;\n```';
      final md = markdownFromDocument(documentFromMarkdown(source));
      expect(md.contains('```dart'), isTrue, reason: 'the language tag is part of the wire form');
      expect(md.contains('final x = 1;'), isTrue);
    });

    test('a fenced code block LOADS as an embedded CodeBlockNode (not a paragraph), code + lang stamped', () {
      const source = '```dart\nfinal x = 1;\nfinal y = 2;\n```';
      final doc = documentFromMarkdown(source);
      final blocks = doc.toList().whereType<CodeBlockNode>().toList();
      expect(blocks, hasLength(1), reason: 'code is an atomic block node, the substrate that gives a gutter');
      expect(blocks.single.code, 'final x = 1;\nfinal y = 2;', reason: 'multiline code verbatim, no trailing \\n');
      expect(blocks.single.language, 'dart', reason: 'the fence language is stamped onto the node');
      // No stray code ParagraphNode left behind. 没遗留 code 段落。
      expect(doc.toList().whereType<ParagraphNode>().where((n) => n.getMetadataValue('blockType') == codeAttribution),
          isEmpty);
    });

    test('a [[id]]-looking run INSIDE code stays literal (code is atomic, never inflated to a pill)', () {
      const source = '```\nsee [[$_id]] here\n```';
      final doc = documentFromMarkdown(source);
      final block = doc.toList().whereType<CodeBlockNode>().single;
      expect(block.code, 'see [[$_id]] here', reason: 'code content is not mention-inflated');
      final md = markdownFromDocument(doc);
      expect(md.contains('[[$_id]]'), isTrue, reason: 'still literal in the serialized code fence');
    });

    test('INLINE `code` LOADS as codeAttribution TEXT runs (paint-beneath), text preserved', () {
      const source = '调用 `fetch_weather` 前先 `validate` 一下。';
      final doc = documentFromMarkdown(source);
      final node = doc.first as ParagraphNode;
      expect(_codeRuns(node), ['fetch_weather', 'validate'], reason: 'each inline code is a codeAttribution run');
      expect(node.text.placeholders, isEmpty, reason: 'inline code is TEXT, not a chip placeholder');
    });

    test('inline code LOADS padded with real NBSP spacers, and SAVE strips them (markdown stays clean)', () {
      const source = '调用 `fetch_weather` 一下。';
      final doc = documentFromMarkdown(source);
      final node = doc.first as ParagraphNode;
      // On load, the run is [NBSP]code[NBSP] — the padding is a REAL character (part of the code token), so the
      // paint-beneath gray sits on real space and pushes neighbours instead of overlapping them. 载入=真 NBSP 内距。
      expect(_rawCodeRuns(node), ['${_nbsp}fetch_weather$_nbsp'], reason: 'padded with a spacer NBSP each side');
      expect(node.text.toPlainText().contains(_nbsp), isTrue, reason: 'the spacer really is in the document text');
      // On save, the spacers are stripped by attribution — the markdown is `code`, never ` code `. 存盘剥离。
      final md = markdownFromDocument(doc);
      expect(md.contains('`fetch_weather`'), isTrue, reason: 'clean backtick code, no injected padding');
      expect(md.contains(_nbsp), isFalse, reason: 'no NBSP leaks into the saved markdown');
    });

    test('padCodeRuns is idempotent — a second load/pad adds no further spacers', () {
      const source = '跑 `make test` 收工。';
      final once = documentFromMarkdown(source).first as ParagraphNode;
      // Re-pad the already-padded text — must be a no-op (no new inserts). 已内距的再规整=无新插入。
      final again = padCodeRuns(once.text);
      expect(again.inserts, isEmpty, reason: 'already padded → reconcile is a stable no-op (no infinite loop)');
    });

    test('inline code round-trips: text → backtick → text, second pass stable', () {
      const source = '见 `input.value` 和 `x > 0` 两处。';
      final md1 = markdownFromDocument(documentFromMarkdown(source));
      expect(md1.contains('`input.value`'), isTrue);
      expect(md1.contains('`x > 0`'), isTrue);
      final md2 = markdownFromDocument(documentFromMarkdown(md1));
      expect(md2, md1, reason: 'idempotent across passes');
    });

    test('a [[id]]-looking substring INSIDE inline code stays literal (not inflated to a mention)', () {
      const source = '用 `see [[$_id]] here` 引用。';
      final doc = documentFromMarkdown(source);
      final node = doc.first as ParagraphNode;
      expect(_codeRuns(node).single, 'see [[$_id]] here', reason: 'code content is verbatim');
      expect(node.text.placeholders.values.whereType<MentionPlaceholder>(), isEmpty, reason: 'no pill created');
      final md = markdownFromDocument(doc);
      expect(md.contains('`see [[$_id]] here`'), isTrue, reason: 'still literal backtick code on save');
    });

    test('inline code and a real mention coexist and both round-trip', () {
      const source = '见 [[$_id]] 用 `helper()` 调用。';
      final doc = documentFromMarkdown(source);
      final node = doc.first as ParagraphNode;
      expect(node.text.placeholders.values.whereType<MentionPlaceholder>().length, 1);
      expect(_codeRuns(node), ['helper()'], reason: 'code is a codeAttribution run');
      final md = markdownFromDocument(doc);
      expect(md.contains('[[$_id]]'), isTrue);
      expect(md.contains('`helper()`'), isTrue);
    });

    test('inline code inside a LIST item round-trips (not just paragraphs)', () {
      const source = '- 跑 `make test`\n- 再 `make docs`';
      final doc = documentFromMarkdown(source);
      final runs = [for (final n in doc.toList().whereType<ListItemNode>()) ..._codeRuns(n)];
      expect(runs, ['make test', 'make docs']);
      final md = markdownFromDocument(doc);
      expect(md.contains('`make test`'), isTrue);
      expect(md.contains('`make docs`'), isTrue);
    });

    test('a table round-trips: cells survive and the second pass is stable', () {
      const source = '| A | B |\n| --- | --- |\n| 1 | 2 |';
      final md1 = markdownFromDocument(documentFromMarkdown(source));
      final md2 = markdownFromDocument(documentFromMarkdown(md1));
      for (final cell in ['A', 'B', '1', '2']) {
        expect(md1.contains(cell), isTrue, reason: 'cell $cell survives');
      }
      expect(md1.contains('|'), isTrue, reason: 'still a markdown table');
      expect(md1, md2, reason: 'second pass stable');
    });

    test('table header follows the COLUMN alignment (GFM std; AnMarkdownTableComponentBuilder un-centres it)', () {
      // super_editor's deserializer hardcodes header cells to centre; our builder copies the column
      // alignment (from the data row) onto the header so the whole column aligns the same — 1:1 with chat.
      final doc = documentFromMarkdown('| a | b | c |\n|:--|:-:|--:|\n| 1 | 2 | 3 |');
      final table = doc.toList().whereType<TableBlockNode>().first;
      final vm = const AnMarkdownTableComponentBuilder().createViewModel(doc, table) as MarkdownTableViewModel;
      const wantAligns = [TextAlign.left, TextAlign.center, TextAlign.right];
      expect(vm.cells.first.map((c) => c.textAlign).toList(), wantAligns,
          reason: 'header follows the column, not super_editor centre');
      expect(vm.cells[1].map((c) => c.textAlign).toList(), wantAligns,
          reason: 'data row already follows the column — header now agrees');
    });

    test('a NESTED list keeps its indent levels', () {
      const source = '- 一层\n   - 二层\n      - 三层';
      final doc = documentFromMarkdown(source);
      final items = doc.toList().whereType<ListItemNode>().toList();
      expect(items, hasLength(3));
      expect([for (final n in items) n.indent], [0, 1, 2], reason: 'indent parsed');
      final md1 = markdownFromDocument(doc);
      final md2 = markdownFromDocument(documentFromMarkdown(md1));
      expect(md1, md2, reason: 'nesting is stable across passes');
      final items2 = documentFromMarkdown(md1).toList().whereType<ListItemNode>().toList();
      expect([for (final n in items2) n.indent], [0, 1, 2], reason: 'indent survives the trip');
    });

    test('a blockquote and an inline link round-trip', () {
      const source = '> 引用一句\n\n看 [文档](https://anselm.website/docs) 一节。';
      final md1 = markdownFromDocument(documentFromMarkdown(source));
      final md2 = markdownFromDocument(documentFromMarkdown(md1));
      expect(md1.contains('> 引用一句'), isTrue);
      expect(md1.contains('[文档](https://anselm.website/docs)'), isTrue, reason: 'link URL verbatim');
      expect(md1, md2);
    });

    test('a horizontal rule round-trips', () {
      const source = '上\n\n---\n\n下';
      final doc = documentFromMarkdown(source);
      expect(doc.toList().whereType<HorizontalRuleNode>(), hasLength(1));
      final md = markdownFromDocument(doc);
      expect(md.contains('---'), isTrue);
    });

    test('an EMPTY document serializes without crashing (and stays empty-ish)', () {
      final doc = documentFromMarkdown('');
      final md = markdownFromDocument(doc);
      expect(md.trim(), isEmpty);
    });

    test('literal asterisks in prose survive (escaped, then re-read to the same plain text)', () {
      const source = r'价格是 3 \* 5 元。';
      final doc1 = documentFromMarkdown(source);
      final plain1 = (doc1.getNodeAt(0)! as ParagraphNode).text.toPlainText();
      final md = markdownFromDocument(doc1);
      final doc2 = documentFromMarkdown(md);
      final plain2 = (doc2.getNodeAt(0)! as ParagraphNode).text.toPlainText();
      expect(plain2, plain1, reason: 'what the reader sees is stable across the trip');
    });

    test('a [[id]] inside prose next to formatting still survives verbatim', () {
      const source = '**重点** 见 [[$_id]],此外 *无关*。';
      final md1 = markdownFromDocument(documentFromMarkdown(source));
      expect(md1.contains('[[$_id]]'), isTrue, reason: 'wikilink verbatim next to inline marks');
      final md2 = markdownFromDocument(documentFromMarkdown(md1));
      expect(md2.contains('[[$_id]]'), isTrue);
    });
  });
}
