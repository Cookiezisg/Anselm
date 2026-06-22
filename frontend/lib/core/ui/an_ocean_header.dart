import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// 海洋页头 — the BIG in-page header at the top of an ocean's content (replicating the
/// demo's `<an-ocean-header>`): breadcrumb + big title + meta row + right-side actions. It
/// sits in the scrollable page (no card); as it scrolls out under the shell's floating
/// header, the compact title there fades in. Distinct from the shell's floating compact bar.
///
/// 海洋页头——海洋内容顶部的大页头(复刻 demo `<an-ocean-header>`):面包屑 + 大标题 + meta 行 + 右侧动作。
/// 它在可滚页面里(无卡);滚出到 shell 浮动头下方时,那里的紧凑标题淡入。与 shell 浮动条不同。
class AnOceanHeader extends StatelessWidget {
  const AnOceanHeader({
    super.key,
    required this.title,
    this.crumb = const [],
    this.meta = const [],
    this.actions = const [],
  });

  final String title;
  final List<String> crumb;
  final List<Widget> meta;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (crumb.isNotEmpty || actions.isNotEmpty)
            Row(
              children: [
                Expanded(child: _crumb(c)),
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: AnSpace.s8),
                  actions[i],
                ],
              ],
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
            child: Text(title, style: AnText.h2.copyWith(color: c.ink)),
          ),
          if (meta.isNotEmpty)
            Wrap(
              spacing: AnSpace.s16,
              runSpacing: AnSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: meta,
            ),
        ],
      ),
    );
  }

  Widget _crumb(AnColors c) {
    if (crumb.isEmpty) return const SizedBox.shrink();
    final parts = <Widget>[];
    for (var i = 0; i < crumb.length; i++) {
      if (i > 0) {
        parts.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: AnSpace.s4),
          child: Text('/', style: AnText.meta.copyWith(color: c.lineStrong)),
        ));
      }
      parts.add(Text(crumb[i], style: AnText.meta.copyWith(color: c.inkFaint)));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: parts);
  }
}
