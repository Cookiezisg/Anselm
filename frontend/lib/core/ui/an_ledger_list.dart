import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_interactive.dart';

/// The LEDGER LIST shell (WRK-066 批6, 法典族四 规则④) — the ONE «show all N» escape: renders up to
/// [cap] children, then an accent escape row that reveals the rest in place. The cap is a LIST-level
/// concern (a row can't know its sibling count), so the escape lives here, not on [AnLedgerRow];
/// heterogeneous headers (bead strips, honest-count bars) stay OUTSIDE with the caller. Collapses the
/// two verbatim hand-rolled escapes (run ledger / flowrun node list).
///
/// 台账列表壳(批6,法典族四④)——唯一「展开全部 N」逃生口:渲前 [cap] 行 + accent 逃生行原地展开
/// 其余。cap 是列表级关切(行件无从知晓兄弟数),故 escape 住这里、不进 AnLedgerRow;异构头件(珠串/
/// 诚实账)留壳外归调用方。收编两处逐字同形手搓。
class AnLedgerList extends StatefulWidget {
  const AnLedgerList({required this.children, this.cap = 12, super.key});

  final List<Widget> children;

  /// Rows shown before the escape. 逃生前显示的行数。
  final int cap;

  @override
  State<AnLedgerList> createState() => _AnLedgerListState();
}

class _AnLedgerListState extends State<AnLedgerList> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final over = widget.children.length > widget.cap;
    final visible = (_showAll || !over)
        ? widget.children
        : widget.children.take(widget.cap).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visible,
        if (over && !_showAll)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            child: AnInteractive(
              onTap: () => setState(() => _showAll = true),
              builder: (ctx, states) => Text(
                context.t.feedback.showAll(
                  n: '${widget.children.length - widget.cap}',
                ),
                style: AnText.meta
                    .weight(AnText.emphasisWeight)
                    .copyWith(color: c.accent),
              ),
            ),
          ),
      ],
    );
  }
}
