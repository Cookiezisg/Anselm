import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The OLD-TRUTH LAYER (WRK-061 R-5) — during an EDIT's live act, "the thing being changed" stays on
/// stage as a pale stratum under the live window: a low-ink excerpt of the previous version with its
/// version tag. It answers "改之前它长什么样" at a glance and honestly frames the live paint as a
/// REPLACEMENT-IN-PROGRESS. Static (no animation); the settle replaces it with the real diff badge.
///
/// 旧真相地层:edit 的 live 幕里「被改的它」以淡墨地层垫在活窗下——上一版低墨节选+版本签。一眼回答
/// 「改之前长什么样」,并诚实框定活画=进行中的替换。静态;落定后由真 diff 徽接棒。
class AnLayerDiff extends StatelessWidget {
  const AnLayerDiff({
    required this.oldText,
    this.versionLabel = '',
    this.maxLines = 8,
    super.key,
  });

  final String oldText;

  /// e.g. "v3" — the stratum's honest provenance tag. 地层出处签。
  final String versionLabel;

  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lines = oldText.split('\n');
    final shown = lines.length > maxLines ? lines.sublist(0, maxLines) : lines;
    final elided = lines.length - shown.length;
    return Opacity(
      opacity: AnOpacity.stratum,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AnSpace.s8),
        decoration: BoxDecoration(
          color: c.surfaceSunken,
          borderRadius: BorderRadius.circular(AnRadius.tag),
          border: Border.all(color: c.line, width: AnSize.hairline),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (versionLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AnSpace.s4),
              child: Text(versionLabel, style: AnText.meta.copyWith(color: c.inkFaint)),
            ),
          for (final line in shown)
            Text(line.isEmpty ? ' ' : line,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: AnText.code.copyWith(color: c.inkFaint)),
          if (elided > 0)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s2),
              child: Text('… +$elided', style: AnText.meta.copyWith(color: c.inkFaint)),
            ),
        ]),
      ),
    );
  }
}
