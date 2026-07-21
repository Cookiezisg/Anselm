import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The no-emoji law (WRK-070 B6, 用户 0718 立法:「只允许 icon,不允许 emoji」) — product copy may
// never carry a character that RENDERS as colour emoji (⏱ in the rail meta was the caught case).
// Because the zero-hardcoded-copy law already routes every product string through the i18n tables,
// guarding the tables guards the product. Text-presentation glyphs (arrows →, checks ✓✗, keycaps
// ⌘⌥⇧, geometric ▲▼) are typography, not emoji — deliberately NOT banned.
// emoji 卫士:产品文案绝不携带会渲成彩色 emoji 的字符;文案零硬编码法保证文案全走 i18n 表,守表即守
// 产品。文本字形(箭头/对勾/键帽/几何)是排印、非 emoji,刻意不禁。

final _emoji = RegExp(
  // Default-emoji-presentation singles + the supplementary emoji planes + VS16 (which FORCES emoji
  // presentation onto an otherwise-text glyph). 默认 emoji 表现的单字符 + 补充平面 + 强制彩渲的 VS16。
  r'[⌚⌛⏩-⏬⏰-⏳◽◾☔☕♈-♓♿⚓'
  r'⚡⚪⚫⚽⚾⛄⛅⛎⛔⛪⛲⛳⛵⛺⛽'
  r'✅✊✋✨❌❎❓-❕❗➕-➗➰➿⬛⬜'
  r'⭐⭕️]|[\uD83C-\uD83E][\uDC00-\uDFFF]',
);

void main() {
  test('i18n tables carry NO emoji-presentation characters (B6 只允许 icon)', () {
    final offenders = <String>[];
    for (final path in ['lib/i18n/zh_CN.i18n.json', 'lib/i18n/en.i18n.json']) {
      void walk(Object? node, String at) {
        if (node is Map) {
          node.forEach((k, v) => walk(v, '$at.$k'));
        } else if (node is String && _emoji.hasMatch(node)) {
          offenders.add('$path $at = $node');
        }
      }

      walk(jsonDecode(File(path).readAsStringSync()), '');
    }
    expect(
      offenders,
      isEmpty,
      reason:
          '产品文案出现 emoji 表现字符——法:只允许 icon(AnIcons),不允许 emoji。\n${offenders.join('\n')}',
    );
  });
}
