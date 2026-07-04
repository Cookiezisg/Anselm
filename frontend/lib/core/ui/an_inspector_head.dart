import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// The right-island content HEAD band — icon + title on row one (with an optional trailing action, e.g.
/// a collapse button), and an optional meta sub-row (a leading label + an end-aligned trailing value,
/// e.g. kind + resolved ref). It is the shared shape behind the run terminal's head and the workflow
/// editor's inspector head, so both read identically. Draws NO divider itself — the caller puts a
/// hairline [Container] below it (the run-terminal idiom), then the scrolling body. Icon + texts are
/// [ExcludeSemantics]-free but the title is the natural heading; keep it a real string.
///
/// 右岛内容头带——第一行 icon + 标题(可带尾部动作,如收起钮),可选 meta 次行(前置标签 + 右对齐值,如
/// kind + 已解析 ref)。run 终端头与 workflow 编辑器检查器头共用此形,二者读来一致。**不自画分隔线**(调用方
/// 在其下放一条发丝 [Container],同 run 终端做法),再接滚动 body。
class AnInspectorHead extends StatelessWidget {
  const AnInspectorHead({
    required this.icon,
    required this.title,
    this.subLeading,
    this.subTrailing,
    this.trailing,
    super.key,
  });

  /// Leading kind/scope glyph (decorative, inkMuted). 前导 kind 图标(装饰)。
  final IconData icon;

  /// The heading — the entity/node name (ink, emphasis weight, ellipsis). 标题(ink 加粗省略)。
  final String title;

  /// Optional meta sub-row leading label (inkMuted) — e.g. the kind word. 次行前置标签(灰)。
  final String? subLeading;

  /// Optional meta sub-row trailing value (inkFaint, end-aligned, ellipsis) — e.g. the resolved ref.
  /// 次行右对齐值(浅灰省略),如已解析 ref。
  final String? subTrailing;

  /// Optional trailing action on the title row — e.g. a bare `AnButton.iconOnly` collapse button.
  /// 标题行尾部动作,如裸 iconOnly 收起钮。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final sl = subLeading;
    final stt = subTrailing;
    final leading = (sl != null && sl.isNotEmpty)
        ? Padding(
            padding: const EdgeInsets.only(right: AnSpace.s8),
            child: Text(sl, style: AnText.meta.copyWith(color: c.inkMuted)),
          )
        : null;
    final hasSub = leading != null || (stt != null && stt.isNotEmpty);
    return Padding(
      // Same band metrics as the run terminal head (an_shell inspector top band). 同 run 终端头带度量。
      padding: const EdgeInsets.fromLTRB(AnSpace.s16, AnSpace.s12, AnSpace.s8, AnSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: AnSize.icon, color: c.inkMuted),
              const SizedBox(width: AnSpace.s8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (hasSub) ...[
            const SizedBox(height: AnSpace.s6),
            Row(
              children: [
                ?leading,
                Expanded(
                  child: Text(
                    stt ?? '',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.meta.copyWith(color: c.inkFaint),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
