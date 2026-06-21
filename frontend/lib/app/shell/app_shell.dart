import 'package:flutter/material.dart';

import '../../core/design/colors.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../i18n/strings.g.dart';

/// PLACEHOLDER shell — proves theme + i18n + tokens render. The real three-island shell
/// (left island = fixed nav chrome · ocean = scrollable feature canvas · right island =
/// on-demand context inspector) is the next foundation deliverable and replaces this rail.
/// Kept here only so the app boots green while that lands.
///
/// 占位 shell——仅证明主题 + i18n + token 可渲染。真正的三岛 shell(左岛=固定导航 chrome · 海洋=可滚
/// feature 画布 · 右岛=按需上下文检查器)是下一个地基交付物,将替换此 rail。暂留以让 app 跑绿。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final destinations = <(IconData, String)>[
      (Icons.chat_bubble_outline, t.nav.chat),
      (Icons.functions, t.nav.functions),
      (Icons.dns_outlined, t.nav.handlers),
      (Icons.smart_toy_outlined, t.nav.agents),
      (Icons.account_tree_outlined, t.nav.workflows),
      (Icons.search, t.nav.search),
      (Icons.settings_outlined, t.nav.settings),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            minWidth: AnSize.navRail,
            backgroundColor: c.surfaceSubtle,
            destinations: [
              for (final (icon, label) in destinations)
                NavigationRailDestination(
                  icon: Icon(icon, size: AnSize.iconLg),
                  label: Text(label, style: AnText.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(t.app.name,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: AnSpace.s8),
                  Text(
                    '${destinations[_index].$2} — app shape TBD',
                    style: AnText.body.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
