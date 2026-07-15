import 'package:anselm/dev/markdown_corpus.dart';
import 'package:anselm/features/documents/data/documents_demo_fixture.dart';
import 'package:anselm/features/documents/model/doc_outline.dart';
import 'package:anselm/features/entities/data/entity_demo_fixture.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:flutter_test/flutter_test.dart';

// D-023 — the `make demo` documents fixture must include ONE page that exercises every block the editor
// renders: all six heading levels (which lock the outline indentation invariant), a real markdown URL
// link, a wikilink, a table, ordered / bulleted / task lists, a quote and fenced code. 全块型样章。
void main() {
  test('D-023 formatting reference seeds every block type', () async {
    final repo = demoDocumentsRepository();
    final ref = (await repo.getTree()).firstWhere((d) => d.name == 'Formatting Reference');
    final body = ref.content;

    // All six ATX heading depths present in the raw markdown (h1 sits at the very start). raw 含六档 # 记号。
    final lines = body.split('\n');
    for (final marker in ['# ', '## ', '### ', '#### ', '##### ', '###### ']) {
      expect(lines.any((l) => l.startsWith(marker)), isTrue, reason: '$marker 缺失');
    }
    // The outline LISTS all six headings (h4–h6 fold into clamped level 3) — levels {1,2,3} all present,
    // and every heading is an entry. 大纲列全六标题(h4–h6 折进 level 3),三档全在。
    final outline = extractDocOutline(body);
    expect(outline.map((e) => e.level).toSet(), containsAll([1, 2, 3]));
    for (final h in ['Heading one', 'Heading four', 'Heading six']) {
      expect(outline.any((e) => e.text == h), isTrue, reason: '$h 未列入大纲');
    }

    // A real external link (distinct from a wikilink) + a wikilink. URL 链接 + wikilink 并存。
    expect(body, contains('[link to the site](https://anselm.website)'));
    expect(body, contains('[[doc_00000000000a11ce]]'));

    // A markdown table (header + separator + rows). 表格。
    expect(body, contains('| Kind | Verb | Example |'));
    expect(body, contains('| --- | --- | --- |'));

    // Ordered / bulleted / task lists + quote + fenced code. 列表+引用+代码。
    expect(body, contains('\n- bullet one'));
    expect(body, contains('\n1. ordered one'));
    expect(body, contains('- [ ] a task still open'));
    expect(body, contains('- [x] a task already done'));
    expect(body, contains('\n> A blockquote'));
    expect(body, contains('```dart'));
  });

  test('D-041 markdown corpus page IS the shared corpus + its wikilink target resolves', () async {
    // The `make demo` kitchen-sink page renders the exact same [buildMarkdownCorpus] as the 1:1 guard test
    // (markdown_parity_test) and the editor⇄chat harness — one source of truth, so the eyeball page and the
    // green guard can never disagree. 全谱页=守卫/harness 同一份语料。
    final page = (await demoDocumentsRepository().getTree())
        .firstWhere((d) => d.name == 'Markdown 全谱 (Kitchen Sink)');
    expect(page.content, buildMarkdownCorpus());
    expect(page.content, contains('[[$kCorpusMentionId]]'));
    // The demo entity fixture provides the wikilink's resolvable target with the corpus's declared name, so
    // the mention pill shows a real name (not the raw id fallback). demo 实体缝供该 wikilink 的解析目标。
    final row = await demoEntityRepository().getEntityRow(EntityKind.function, kCorpusMentionId);
    expect(row.name, kCorpusMentionName);
  });
}
