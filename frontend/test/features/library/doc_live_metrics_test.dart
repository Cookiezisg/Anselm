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
