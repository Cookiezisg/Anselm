import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// WRK-083 墓碑 — an empty state must name the EMPTINESS, never repeat the heading above it.
//
// The user's word for it: 墓碑. An icon, a word you have just finished reading, and nothing else —
// the panel's own section header borrowed as the empty state's title. Real machine: 模型与密钥 showed
// an icon captioned 「搜索密钥」 sitting directly under a section header that also said 「搜索密钥」.
// It answers no question: not what is empty, not what to do, not whether anything is wrong.
//
// This is a RECURRING shape in this project, not a one-off — the user has ruled against it before
// (0718: the tombstone sentence at the end of the big tables was deleted rather than reworded), and
// settings' own P1 consistency sweep already listed both「标题重复」and「空态零人话」as things it fixed.
// It came back. So it is guarded mechanically now.
//
// The rule is narrow on purpose: NOT "every empty state must have a hint". Plenty of them are
// self-explanatory (`noMatches` under a search box needs no paragraph). The defect is specifically
// borrowing a heading key — `*Section` / `*Title` / `*Header` — as the empty state's own title, which
// is exactly how both instances were written.
//
// WRK-083 墓碑——空态必须点名**空本身**,绝不复读它上方的标题。
//
// 用户给它的词是「墓碑」:一个图标、一个你刚读完的词,再无其他——面板自己的分区标题被借来当空态标题。真机:
// 「模型与密钥」里一个图标下写着「搜索密钥」,而它正上方的分区标题也是「搜索密钥」。它什么问题都不回答:
// 空的是什么、该做什么、是不是出错了,一个都没答。
//
// 这在本项目里是**反复出现**的形状、不是孤例——用户此前已经裁过一次(0718:大表尽头那句墓碑是**删掉**而不是改写),
// 而 settings 自己的 P1 一致性扫荡也把「标题重复」与「空态零人话」双双列为已修项。它又回来了。故现在机械地守。
//
// 规则**刻意收窄**:**不是**「每个空态都必须有 hint」。很多空态本就自明(搜索框下的 `noMatches` 不需要一段话)。
// 缺陷特指**借用标题 key**——`*Section` / `*Title` / `*Header`——来当空态自己的标题,而这正是那两处的写法。

void main() {
  test('no empty state borrows a section heading as its title (墓碑)', () {
    final offenders = <String>[];
    // ONLY `*Section` — this project's naming for a section heading. The first draft also matched
    // `*Title` / `*Header` and immediately flagged `comingSoonTitle`, `notFoundTitle`, `firstUseTitle`,
    // `relayFailedTitle`: purpose-built empty-state copy that merely ENDS in "Title". A guard that
    // cannot tell a heading from a title would train people to ignore it.
    // **只认 `*Section`**——本项目给分区标题的命名。初稿把 `*Title`/`*Header` 也算上,当场误判了
    // `comingSoonTitle`/`notFoundTitle`/`firstUseTitle`/`relayFailedTitle`:那些是**专门写的**空态文案,只是恰好以
    // "Title" 结尾。一条分不清「标题」与「分区标题」的守卫,只会训练人无视它。
    final headingKey = RegExp(r'\.\w*Section\b');

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (!src.contains('AnStateKind.empty')) continue;

      // Walk each `AnState(` to its MATCHING close paren and strip comments — a fixed line window
      // cannot do this job: the first offender was missed by a 6-line window simply because the fix's
      // own explanatory comment pushed `title:` out of it. A guard whose reach depends on how much
      // prose sits next to the code is not a guard.
      // 逐个 `AnState(` 走到它**配对**的右括号并剥掉注释——固定行窗做不了这件事:第一处漏网,仅仅因为修复本身
      // 那段说明注释把 `title:` 挤出了 6 行窗口。一条「够得着多远取决于旁边写了多少字」的守卫不算守卫。
      for (final m in RegExp(r'AnState\(').allMatches(src)) {
        var depth = 0;
        var end = m.end;
        for (var i = m.end - 1; i < src.length; i++) {
          if (src[i] == '(') depth++;
          if (src[i] == ')') {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
        }
        final body = src
            .substring(m.end, end)
            .split('\n')
            .map((l) => l.trim().startsWith('//') ? '' : l)
            .join('\n');
        if (!body.contains('AnStateKind.empty')) continue;
        final title = RegExp(r'title:\s*([^,\n]+)').firstMatch(body)?.group(1);
        if (title == null) continue;
        if (headingKey.hasMatch(title)) {
          final line = src.substring(0, m.start).split('\n').length;
          offenders.add('${f.path}:$line  title: ${title.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these empty states are captioned with a HEADING key, so they repeat the text directly '
          'above them and say nothing about what is empty or what to do (WRK-083 墓碑):\n  '
          '${offenders.join("\n  ")}',
    );
  });
}
