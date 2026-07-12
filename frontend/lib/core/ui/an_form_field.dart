import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// A VERTICAL form field — label above ([AnText.strong] ink), an optional [desc] sub-line ([AnText.meta]
/// muted), then a block control below, with an s6 gap. The app's "label-above / control-below" form
/// vocabulary — distinct from the horizontal [AnField]/[AnKv] key-value rows (value hugs the right). An
/// optional [labelTrailing] rides the label baseline (a type badge / unit). The between-field spacing is
/// the caller's (a parent `Padding`/`SizedBox`), keeping the primitive pure. Collapses the label-above
/// block that the editor inspector and the run input form each hand-rolled.
///
/// 纵向表单字段——标签在上(AnText.strong 墨)、可选 [desc] 副行(AnText.meta 灰),下接 block 控件,间距 s6。
/// app 的「标签在上、控件在下」表单语汇——区别于横向 AnField/AnKv 键值行(值贴右)。可选 [labelTrailing] 骑标签
/// 基线(类型徽章 / 单位)。字段间的纵向间距归调用方(父级 Padding/SizedBox),保持原语纯净。收口编辑器检查器与
/// run 输入表单各自手搓的「标签在上」字段块。
class AnFormField extends StatelessWidget {
  const AnFormField({
    required this.label,
    required this.child,
    this.desc,
    this.labelTrailing,
    this.monoLabel = false,
    super.key,
  });

  final String label;

  /// Mono label face (env var names, wire keys — 批6 A-059 的 MCP env 动态标签组). 等宽标签脸。
  final bool monoLabel;
  final String? desc;

  /// Optional widget on the label baseline (e.g. a type badge). 标签基线上的可选件(如类型徽章)。
  final Widget? labelTrailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final labelText = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: (monoLabel ? AnText.mono : AnText.strong).copyWith(color: c.ink),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelTrailing == null)
          labelText
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(child: labelText),
              const SizedBox(width: AnSpace.s6),
              labelTrailing!,
            ],
          ),
        if (desc != null && desc!.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s2),
          Text(desc!, style: AnText.meta.copyWith(color: c.inkMuted)),
        ],
        const SizedBox(height: AnSpace.s6),
        child,
      ],
    );
  }
}
