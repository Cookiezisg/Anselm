import 'package:anselm/features/library/state/library_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-083 L16 — the inspector's 字数 / 大小 / 修改时间 must track the LIVE edit, not the frozen open doc.
//
// [openDocumentProvider] is deliberately never invalidated mid-edit — invalidating it would rebuild the
// editor and drop the caret (its own doc comment says so). The visible cost was the properties panel:
// after typing and saving, it still showed the OPEN-TIME numbers (real machine: 4 minutes and dozens of
// bytes stale) until a full remount on doc-switch. The outline already re-feeds live from the edit view;
// [docLiveMetricsProvider] is that same channel for char/byte/time, so the panel is honest WITHOUT
// touching the provider the caret depends on.
//
// This test locks the two properties that make that honest: the count matches the inspector's own
// whitespace-stripped rune formula (a different one would make the number JUMP when the panel falls back
// to the loaded doc), and a doc-switch clears it (so page B never briefly shows page A's size).
//
// WRK-083 L16——右岛「字数/大小/修改时间」必须跟着**活**编辑走,而不是那个冻结的打开文档。
//
// [openDocumentProvider] 编辑中刻意不失效——失效会重建编辑器、丢光标(它自己的注释这么写)。可见代价落在属性面板:
// 打字并保存后,它仍显**打开那一刻**的数(真机:陈旧了 4 分钟、几十字节),要到换文档整树重挂才更新。大纲已从编辑
// 视图实时重喂;[docLiveMetricsProvider] 是字数/字节/时间的**同一条**通道,故面板诚实、且不碰光标依赖的那个 provider。
//
// 本测试锁住让它诚实的两条性质:计数与 inspector 自己的**剥空白 rune** 公式一致(不一致会让面板回退到 loaded doc
// 时数字**跳**),以及换文档即清(故 B 页绝不闪现 A 页的大小)。

void main() {
  ProviderContainer container() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('feed derives chars (whitespace-stripped runes) + utf8 bytes', () {
    final c = container();
    final ctrl = c.read(docLiveMetricsProvider.notifier);

    // "# 标题\n\n正文 abc" — whitespace stripped is "#标题正文abc" = 8 runes; utf8 counts the CJK at 3 bytes.
    // 剥空白后 "#标题正文abc" = 8 runes;utf8 把 CJK 记 3 字节。
    ctrl.feed('# 标题\n\n正文 abc');
    final m = c.read(docLiveMetricsProvider)!;
    expect(
      m.chars,
      8,
      reason: 'same whitespace-stripped rune count the inspector uses (L16)',
    );
    // '#'(1) + 标题(2×3) + 正文(2×3) + abc(3) = 1 + 6 + 6 + 3 = 16 bytes, whitespace INCLUDED in bytes.
    // Recompute against the raw string so the guard tracks the real utf8 length, not a hand copy.
    expect(
      m.bytes,
      '# 标题\n\n正文 abc'.codeUnits.isNotEmpty ? _utf8Len('# 标题\n\n正文 abc') : 0,
    );
  });

  test('a doc switch clears the metrics — page B never shows page A (L16)', () {
    final c = container();
    final ctrl = c.read(docLiveMetricsProvider.notifier);
    ctrl.feed('page A body');
    expect(c.read(docLiveMetricsProvider), isNotNull);

    ctrl.clear();
    expect(
      c.read(docLiveMetricsProvider),
      isNull,
      reason:
          'cleared on deselect/switch so a stale size never bleeds across pages (L16)',
    );
  });

  test('media embeds do not inflate the word count (WRK-082 批F)', () {
    // An embedded chart is ~50 characters of url the reader never sees. Counting them makes a
    // document of three pictures read as denser prose than a page of actual writing — and the
    // caption, which the reader DOES see, must still count.
    //
    // 一张嵌入图表是约 50 个读者根本看不见的 url 字符。算进去会让三张图的文档读起来比一整页真文字还密;
    // 而说明文字——读者**看得见**的那部分——必须仍然计数。
    const prose = '销量分析';
    const withMedia = '$prose\n\n![销量图](anselm://media/att_00112233445566aa)\n';
    expect(
      documentCharCount(withMedia),
      // What survives is exactly the prose plus the visible `![销量图]` — the url, and only
      // the url, is gone. Spelling the survivor out beats arithmetic: the assertion then says
      // what a READER sees.
      // 活下来的恰是正文加上看得见的 `![销量图]`——url、且只有 url 消失了。把幸存者写出来胜过做
      // 算术:这条断言说的是**读者看见了什么**。
      documentCharCount('$prose![销量图]'),
      reason: 'only the url disappears from the count; the caption stays',
    );

    // The live channel and the inspector fallback must agree — a second formula makes the panel's
    // number JUMP as it swaps between them.
    // 活通道与 inspector 回退必须一致——抄第二份公式会让面板在两者切换时数字**跳**。
    final c = container();
    c.read(docLiveMetricsProvider.notifier).feed(withMedia);
    expect(c.read(docLiveMetricsProvider)!.chars, documentCharCount(withMedia));

    // Bytes are the STORED size and therefore still include the url — the document really is that
    // big on disk. 字节是**存储**大小,故仍含 url——文档在盘上确实那么大。
    expect(
      c.read(docLiveMetricsProvider)!.bytes,
      greaterThan(documentCharCount(withMedia)),
    );
  });

  test('a stale same-document seed cannot overwrite a newer edit', () {
    final c = container();
    final ctrl = c.read(docLiveMetricsProvider.notifier);

    ctrl.seed('doc_a', 'old body');
    expect(c.read(docLiveMetricsProvider)!.fromEdit, isFalse);
    ctrl.feed('new body with 中文', sourceId: 'doc_a');
    final edited = c.read(docLiveMetricsProvider)!;

    ctrl.seed('doc_a', 'old body');
    expect(c.read(docLiveMetricsProvider), edited);
    expect(c.read(docLiveMetricsProvider)!.sourceId, 'doc_a');
    expect(c.read(docLiveMetricsProvider)!.fromEdit, isTrue);
  });

  test('metrics identify their document', () {
    final c = container();
    final ctrl = c.read(docLiveMetricsProvider.notifier);

    ctrl.feed('page A body', sourceId: 'doc_a');
    expect(c.read(docLiveMetricsProvider)!.sourceId, 'doc_a');
    ctrl.seed('doc_b', 'page B body');
    expect(c.read(docLiveMetricsProvider)!.sourceId, 'doc_b');
    expect(c.read(docLiveMetricsProvider)!.fromEdit, isFalse);
  });

  test('a load seed never invents a modified timestamp', () {
    final persisted = DateTime(2026, 8, 9, 12, 17);
    final seeded = (
      sourceId: 'doc_a',
      chars: 4,
      bytes: 4,
      at: DateTime(2026, 8, 9, 12, 14),
      fromEdit: false,
    );
    expect(
      documentInspectorUpdatedAt(live: seeded, persisted: persisted),
      persisted,
    );
  });

  test('a real edit is optimistic only until persisted truth is newer', () {
    final editAt = DateTime(2026, 8, 9, 12, 18);
    final edited = (
      sourceId: 'doc_a',
      chars: 4,
      bytes: 4,
      at: editAt,
      fromEdit: true,
    );
    final beforeSave = DateTime(2026, 8, 9, 12, 17);
    final afterMove = DateTime(2026, 8, 9, 12, 19);

    expect(
      documentInspectorUpdatedAt(live: edited, persisted: beforeSave),
      editAt,
    );
    expect(
      documentInspectorUpdatedAt(live: edited, persisted: afterMove),
      afterMove,
    );
  });
}

int _utf8Len(String s) {
  var n = 0;
  for (final r in s.runes) {
    n += r <= 0x7f
        ? 1
        : r <= 0x7ff
        ? 2
        : r <= 0xffff
        ? 3
        : 4;
  }
  return n;
}
