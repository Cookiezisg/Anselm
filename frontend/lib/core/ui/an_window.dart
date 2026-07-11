import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_fade_collapse.dart';
import 'an_sunken_panel.dart';

/// The WINDOW family head (WRK-066「同轨」族一) — the ONE container every machine product and every
/// typeset artifact lives in. Two looks only: [AnWindowLook.sunken] (grey well — raw machine output:
/// terminal, code tails, JSON, logs) and [AnWindowLook.card] (white bordered — finished typesetting:
/// prose, letters, note cards, form previews). A left [header] slot (command echo / title), a right
/// [actions] slot (chip-family copy etc.), an [AnSize]-tier [maxHeight] clamp, and an optional
/// [collapsible] fade past the clamp. The window NEVER sniffs content — children compose
/// AnCodeEditor / AnMarkdown / AnJsonTree / AnLiveTail inside it.
///
/// 窗族当家件(「同轨」族一)——一切机器产物与成品排版的唯一容器。只有两张脸:sunken(灰凹面=机器原料:
/// 终端/代码尾/JSON/日志)与 card(白底描边=成品排版:prose/信笺/便笺卡/表单预览)。左 header 槽(命令
/// 回显/标题)、右 actions 槽(chip 族 copy 等)、AnSize 档 maxHeight 钳制、超高可 FadeCollapse。窗绝不
/// 嗅探内容——内容由 AnCodeEditor/AnMarkdown/AnJsonTree/AnLiveTail 组合进来。
enum AnWindowLook { sunken, card }

class AnWindow extends StatelessWidget {
  const AnWindow({
    required this.child,
    this.look = AnWindowLook.sunken,
    this.header,
    this.actions = const [],
    this.maxHeight,
    this.collapsible = false,
    super.key,
  });

  final Widget child;
  final AnWindowLook look;

  /// Left header slot (command echo / title line). 左头槽。
  final Widget? header;

  /// Right action slot (copy chips etc.), flush-right on the header row. 右动作槽。
  final List<Widget> actions;

  /// Height clamp — pass an [AnSize] viewport tier, never a bare number. 高钳(AnSize 档,禁裸数)。
  final double? maxHeight;

  /// Past [maxHeight], fade-collapse with the standard expand/collapse affordance (instead of a hard
  /// clip). 超高时 FadeCollapse(标准展开/收起),而非硬裁。
  final bool collapsible;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final head = (header == null && actions.isEmpty)
        ? null
        : Row(children: [
            if (header != null) Expanded(child: header!) else const Spacer(),
            for (final a in actions)
              Padding(padding: const EdgeInsets.only(left: AnSpace.s4), child: a),
          ]);

    Widget body = child;
    if (maxHeight != null) {
      body = collapsible
          ? AnFadeCollapse(
              collapsible: true,
              collapsedHeight: maxHeight!,
              expandLabel: context.t.chat.tool.proseExpand,
              collapseLabel: context.t.chat.tool.proseCollapse,
              fadeColor: look == AnWindowLook.sunken ? c.surfaceSunken : c.surface,
              child: child,
            )
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight!),
              child: ClipRect(child: child),
            );
    }

    if (look == AnWindowLook.sunken) {
      return SizedBox(width: double.infinity, child: AnSunkenPanel(header: head, child: body));
    }
    // card — the finished-typesetting face (white surface, hairline border, card radius/inset).
    // card 脸:成品排版(白底/发丝边/card 圆角内距)。
    return Container(
      width: double.infinity,
      padding: AnInset.card,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line, width: AnSize.hairline),
        borderRadius: BorderRadius.circular(AnRadius.card),
      ),
      child: head == null
          ? body
          : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              DefaultTextStyle.merge(style: AnText.label.copyWith(color: c.inkFaint), child: head),
              const SizedBox(height: AnSpace.s6),
              body,
            ]),
    );
  }
}
