import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The search/filter PLACEHOLDER copy law (WRK-077 施工序⑬/LR+LI 批): every rail/list's filter-field
// placeholder reads «搜索<对象>…» / «Search <objects>…» — a real ellipsis CHARACTER (U+2026, not three
// ASCII periods), sentence case (only the leading word capitalized), and an object named (never a bare
// "Search…" with nothing to search). Two keys drifted from this (library.filter = "搜索页面" / "Search
// Page" — no ellipsis + Title Case + singular; scheduler.filterPlaceholder = "搜索…" / "Search…" — no
// object) before WRK-077 fixed them; this guard mechanizes the standard so the next drift goes red
// instead of shipping.
//
// SCOPE (what it scans): a leaf i18n key is a candidate iff its last dotted segment, lower-cased, is
//   • exactly "filter", OR
//   • ends with "search" (catches `toolPickerSearch`), OR
//   • ends with "placeholder" AND itself contains "filter" or "search" (catches `filterPlaceholder`,
//     `searchPlaceholder` — but NOT unrelated placeholders like `rotatePlaceholder`/`answerPlaceholder`/
//     `proxyPlaceholder`, which end in "placeholder" too but aren't search boxes).
// This mirrors the THREE named-argument shapes this codebase actually wires a filter/search placeholder
// through at its call site (`filter:` / `filterPlaceholder:` / `placeholder:` — verified by grep across
// lib/features at the time this guard was written).
//
// BLIND SPOTS (what it can't see — read before trusting a green run):
//   • Two REAL placeholder keys don't fit any of the three shapes above and are NOT scanned:
//     `settings.mem.searchHint` ("Search memories…") and `settings.mcp.searchMarket` ("Search the
//     marketplace…"). Both are correct today; a regression on either slips past this guard silently.
//   • It reads the i18n TABLES only — a placeholder string hard-coded inline in a widget (the very thing
//     the project's zero-hardcoded-copy law forbids) is invisible here by construction.
//   • It checks the MECHANICAL shape only (ellipsis character, leading capital, an object present) — it
//     does NOT check that the object is plural or idiomatically phrased ("Search the marketplace…" using
//     "the" instead of a bare plural is accepted; grammar judgment is a human review, not a regex).
//   • A key whose name happens to end in "search"/"filter" but ISN'T actually wired to a filter box
//     (an over-strict false positive) would otherwise be forced into this shape. `referenceSearch` is
//     the current real collision: it is a human API-key dependency label and is explicitly allowlisted
//     below. New collisions must be added to that set with a why comment — never silently weaken this
//     matcher or turn it into a broad substring scan (which would also sweep in `filterAll`/
//     `filterRunning`/`searchDefault`/`searchSection`/`grepFilter`/`searchingWeb`-style progress verbs).
//
// 搜索/过滤占位符文案法:每个 rail/列表的过滤框占位符念「搜索<对象>…」/「Search <objects>…」——真省略号
// 字符(U+2026、非三点)、句首大写(仅首词)、对象必须点名(不许光秃秃一句「搜索…」)。两键曾走样(见上);
// 本守卫把标准钉成机械检查。扫描范围/看不见什么见上方英文注释。
final _placeholderKeyPattern = RegExp(
  r'^(filter)$|search$|(filter|search).*placeholder$',
);

// Human reference label in the API-key dependency dialog, not an input placeholder.
// API-key 引用说明中的人话标签,不是输入框占位符。
const _knownNonPlaceholderKeys = {'referenceSearch'};

bool _isPlaceholderKey(String lastSegment) =>
    !_knownNonPlaceholderKeys.contains(lastSegment) &&
    _placeholderKeyPattern.hasMatch(lastSegment.toLowerCase());

// EN: "Search " + a lowercase-led object + real ellipsis. Rejects "Search…" (no space/object — the
// scheduler bug), "Search Page…" (capitalized object — the library bug's shape had this too), and
// anything missing the U+2026 character outright (the library bug before its ellipsis was added).
final _enShape = RegExp(r'^Search [a-z].+…$');

// ZH: "搜索" + ≥1-char object + real ellipsis. Rejects "搜索…" (no object) and "搜索页面" (no ellipsis).
final _zhShape = RegExp(r'^搜索.+…$');

const _threeDotEllipsis = '...';

void main() {
  test(
    'filter/search placeholder i18n values follow "Search <objects>…" / "搜索<对象>…"',
    () {
      final en =
          jsonDecode(File('lib/i18n/en.i18n.json').readAsStringSync())
              as Map<String, dynamic>;
      final zh =
          jsonDecode(File('lib/i18n/zh_CN.i18n.json').readAsStringSync())
              as Map<String, dynamic>;

      final offenders = <String>[];
      final scanned = <String>[];

      void walk(Map<String, dynamic> enNode, Map? zhNode, String path) {
        enNode.forEach((k, v) {
          final at = path.isEmpty ? k : '$path.$k';
          if (v is Map<String, dynamic>) {
            final zhChild = zhNode?[k];
            walk(v, zhChild is Map ? zhChild : null, at);
            return;
          }
          if (v is! String || !_isPlaceholderKey(k)) return;
          scanned.add(at);

          if (!_enShape.hasMatch(v)) {
            offenders.add(
              'en $at = ${jsonEncode(v)} — 须形如 "Search <objects>…"'
              '(首词后紧跟小写起首的对象、结尾真省略号 U+2026)',
            );
          }
          if (v.contains(_threeDotEllipsis)) {
            offenders.add(
              'en $at = ${jsonEncode(v)} — 三点冒充省略号,须用真省略号字符 …(U+2026)',
            );
          }

          final zhV = zhNode?[k];
          if (zhV is! String) {
            offenders.add('zh_CN $at — 缺对应键(en 侧此键存在)');
            return;
          }
          if (!_zhShape.hasMatch(zhV)) {
            offenders.add(
              'zh_CN $at = ${jsonEncode(zhV)} — 须形如 "搜索<对象>…"(结尾真省略号 U+2026,对象须点名)',
            );
          }
          if (zhV.contains(_threeDotEllipsis)) {
            offenders.add(
              'zh_CN $at = ${jsonEncode(zhV)} — 三点冒充省略号,须用真省略号字符 …(U+2026)',
            );
          }
        });
      }

      walk(en, zh, '');

      // The guard must have actually found candidates — an empty scan is a silently-neutered guard
      // (the scan rule broke, not that the codebase has zero search boxes). 必须真扫到候选,空扫=哑守卫。
      expect(
        scanned,
        isNotEmpty,
        reason: '扫描规则命中零候选键——规则本身失效了(应命中 chat.filter 等 7 键)',
      );
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    },
  );

  test(
    'sanity: the key-name rule does not sweep in known non-placeholder filter/search keys',
    () {
      // The false-positive risk named in the header's last bullet, pinned down as a real assertion (not
      // just prose) — these keys all contain "filter"/"search" but are NOT box placeholders (segmented-
      // control option labels, progress verbs, a section title, a settings-key concept label), and must
      // stay OUT of `_isPlaceholderKey`'s candidate set. 头注释最后一条的假阳性风险,钉成真断言(非仅散文)。
      const nonPlaceholders = [
        'filterAll',
        'filterRunning',
        'filterFailed',
        'filterWaiting',
        'filterPinned',
        'filterA11y',
        'grepFilter',
        'searchingWeb',
        'searchedWeb',
        'cvSearching',
        'cvSearched',
        'searchDefault',
        'searchDefaultDesc',
        'searchSection',
        'searchKeyNotProbedHint',
        'searchNoMatch',
        'referenceSearch',
        // Unrelated *Placeholder keys — end in "placeholder" but name neither filter nor search.
        'rotatePlaceholder',
        'answerPlaceholder',
        'proxyPlaceholder',
      ];
      for (final k in nonPlaceholders) {
        expect(
          _isPlaceholderKey(k),
          isFalse,
          reason: '$k 不是过滤/搜索占位符键,不应被扫描规则命中',
        );
      }
    },
  );
}
