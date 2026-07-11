import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../model/status_state.dart';

/// The ROW family's «label-over-content» head (WRK-066「同轨」族四) — the ONE implementation of the
/// recurring motif: a 13-tier grey label above arbitrary content (IO sections, intent lines, generic-body
/// sections, stage sub-sections). Pairs with [AnKv] (the ONE key-value pairs layout); together they are
/// the ONLY two label layouts — a third arrangement is a grammar violation (文法 #2).
///
/// 行族「标签在上,内容在下」当家件(「同轨」族四)——反复出现母题的唯一实现(IO 段/意图行/通用体分段/舞台
/// 小节)。与 AnKv(唯一键值对排布)配对:全 App 只此两种标签排布,第三种即违反文法 #2。
class AnFieldSection extends StatelessWidget {
  const AnFieldSection({required this.label, required this.child, this.tone = AnTone.none, super.key});

  final String label;
  final Widget child;

  /// Label tone (danger for error sections). 标签声调(错误段 danger)。
  final AnTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = switch (tone) {
      AnTone.danger => c.danger,
      AnTone.warn => c.warn,
      _ => c.inkFaint,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      // 13-tier label — the codex's「13 灰标签」(复审 #14: meta-12 drifted from the spec). 13 档标签。
      Text(label, style: AnText.label.copyWith(color: ink)),
      const SizedBox(height: AnSpace.s4),
      child,
    ]);
  }
}
