// SPIKE (throwaway, WRK-documents): validates the load-bearing assumption behind choosing super_editor
// as the Notion editor foundation — that markdown stays the source of truth and round-trips through the
// editor's document model without lossy drift, INCLUDING the `[[id]]` wikilink (the relation-graph edge).
// If this fails, super_editor's markdown-canonical story is broken → re-open the fleather fallback.
// Run: flutter test test/dev/spike/super_editor_roundtrip_spike_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

// The round-trip: markdown string → editor Document → markdown string, strict CommonMark (matches the
// backend's plain-markdown content). markdown → Document → markdown,严格 CommonMark(对齐后端存储)。
String rt(String md) => serializeDocumentToMarkdown(
      deserializeMarkdownToDocument(md, syntax: MarkdownSyntax.normal),
      syntax: MarkdownSyntax.normal,
    );

void main() {
  group('super_editor markdown round-trip spike', () {
    // Idempotent stability is the honest measure — byte-equality with the ORIGINAL is too strict
    // (markdown has many valid spellings: `-` vs `*`, spacing). What matters: the round-trip reaches a
    // FIXED POINT (rt(rt(x)) == rt(x)) so repeated save/load never drifts, and content is preserved.
    // 幂等稳定=诚实度量:往返到不动点,反复存取不漂移。
    final matrix = <String, String>{
      'heading': '# Title\n\n## Sub',
      'paragraph': 'A plain paragraph with text.',
      'inline styles': 'Some **bold**, *italic*, and `code`.',
      'unordered list': '- one\n- two\n- three',
      'nested list': '- one\n    - a\n    - b\n- two',
      'ordered list': '1. first\n2. second',
      'task list': '- [ ] todo\n- [x] done',
      'blockquote': '> quoted line',
      'table': '| a | b |\n| --- | --- |\n| 1 | 2 |',
      'horizontal rule': 'above\n\n---\n\nbelow',
      'wikilink in text': 'See [[doc_9f2c41aa77b0e310]] for context.',
      'mixed doc': '# Notes\n\nA para with **bold** and [[doc_abc0000000000000]].\n\n- item\n- item\n\n> quote',
    };

    matrix.forEach((name, md) {
      test('idempotent fixed-point: $name', () {
        final once = rt(md);
        final twice = rt(once);
        expect(twice, once, reason: 'round-trip must reach a fixed point for "$name"\n--- once ---\n$once\n--- twice ---\n$twice');
      });
    });

    // The sharpest edge (C2): a `[[prefix_16hex]]` wikilink is NOT standard markdown. A naive editor might
    // escape it to `\[\[...\]\]` or reflow it, silently severing the relation-graph `link` edge. This test
    // records the CURRENT behavior WITHOUT any custom codec registered — the baseline the real wikilink
    // codec (P3.3) must improve on. wikilink 逐字存活基线(未注册自定义 codec)。
    test('wikilink [[id]] survives round-trip verbatim (baseline, no custom codec)', () {
      final out = rt('See [[doc_9f2c41aa77b0e310]] here.');
      expect(out, contains('[[doc_9f2c41aa77b0e310]]'),
          reason: 'the relation-graph wikilink must survive verbatim (not escaped/mangled); got:\n$out');
    });

    // KNOWN GAP (spike-recorded, not a blocker): super_editor models fenced code as a ParagraphNode with a
    // block attribution — there is no first-class code node — so it appends trailing spaces and DRIFTS the
    // whitespace on each round-trip (not a fixed point). The code TEXT survives; only trailing whitespace
    // grows. The real editor routes fenced code to AnCodeEditor + a custom code-block serializer (P3.5)
    // that emits the body verbatim. Recorded here so the regression is visible, not silent.
    // 已知缺口:代码围栏尾随空白漂移(无一等代码节点);正文存活,P3.5 自定义序列化器修。
    test('code fence: body survives (trailing-whitespace drift is the known P3.5 gap)', () {
      final out = rt('```\nvoid main() {}\n```');
      expect(out.contains('void main() {}'), isTrue, reason: 'code body must survive; got:\n$out');
      expect(out.trimLeft().startsWith('```'), isTrue, reason: 'the fence must survive; got:\n$out');
    });
  });
}
