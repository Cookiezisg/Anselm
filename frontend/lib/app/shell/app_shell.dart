import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/ui/ui.dart';
import '../../i18n/strings.g.dart';

/// The persistent three-island shell (左岛 sidebar · 海洋 ocean · 右岛 inspector), faithful to
/// the demo layout, with collapse/resize chrome owned by [AnShell]. Stays mounted across
/// navigation so the session SSE streams never tear down. Ocean bodies are placeholders
/// until each feature lands.
///
/// 常驻三岛 shell(左岛 / 海洋 / 右岛),忠实于 demo 布局,收起/调宽 chrome 归 [AnShell]。导航期间常驻,
/// 会话级 SSE 流不卸载。海洋主体为占位,待各 feature 落地。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _nav = 0;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final oceans = <(IconData, String)>[
      (AnIcons.chat, t.nav.chat),
      (AnIcons.entities, t.nav.entities),
      (AnIcons.scheduler, t.nav.scheduler),
      (AnIcons.document, t.nav.documents),
    ];

    return AnShell(
      headTitle: oceans[_nav].$2,
      sidebarBuilder: (onCollapse) => AnSidebar(
        workspaceName: 'Personal',
        nav: [for (final (icon, label) in oceans) AnSidebarNav(icon: icon, label: label)],
        selectedIndex: _nav,
        onSelect: (i) => setState(() => _nav = i),
        onCollapse: onCollapse,
        body: const SizedBox.shrink(),
      ),
      oceanBuilder: (scroll) => AnPage(
        controller: scroll,
        child: Padding(
          padding: const EdgeInsets.only(top: AnSpace.s48),
          child: AnEmptyState(
            icon: oceans[_nav].$1,
            title: '${oceans[_nav].$2} — coming soon',
            hint: 'This ocean lands with its feature. The shell + UI kit are in place.',
          ),
        ),
      ),
    );
  }
}
