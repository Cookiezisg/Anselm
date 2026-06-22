import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/ui/ui.dart';
import '../../features/entities/ui/entities_page.dart';
import '../../features/entities/ui/entities_rail.dart';
import '../../i18n/strings.g.dart';

/// The persistent three-island shell, shared by the real app (`make app`) and the
/// fixture-backed demo (`make demo`). It wires each ocean to its feature; oceans without a
/// feature yet show a coming-soon state. Stays mounted across navigation so the session SSE
/// streams never tear down.
///
/// 常驻三岛 shell,真 app 与 fixture demo 共用。每个海洋接其 feature;未落地的海洋显 coming-soon。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

enum _Ocean { chat, entities, scheduler, documents }

class _AppShellState extends State<AppShell> {
  _Ocean _ocean = _Ocean.entities; // open on the built feature

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final oceans = <(_Ocean, IconData, String)>[
      (_Ocean.chat, AnIcons.chat, t.nav.chat),
      (_Ocean.entities, AnIcons.entities, t.nav.entities),
      (_Ocean.scheduler, AnIcons.scheduler, t.nav.scheduler),
      (_Ocean.documents, AnIcons.document, t.nav.documents),
    ];
    final index = oceans.indexWhere((o) => o.$1 == _ocean);
    final current = oceans[index];
    final isEntities = _ocean == _Ocean.entities;

    return AnShell(
      headTitle: current.$3,
      sidebarBuilder: (onCollapse) => AnSidebar(
        workspaceName: 'Personal',
        nav: [for (final (_, icon, label) in oceans) AnSidebarNav(icon: icon, label: label)],
        selectedIndex: index,
        onSelect: (i) => setState(() => _ocean = oceans[i].$1),
        onCollapse: onCollapse,
        body: isEntities ? const EntitiesRail() : const SizedBox.shrink(),
      ),
      oceanBuilder: (scroll) => AnPage(
        controller: scroll,
        child: isEntities
            ? const EntitiesPage()
            : Padding(
                padding: const EdgeInsets.only(top: AnSpace.s48),
                child: AnEmptyState(
                  icon: current.$2,
                  title: '${current.$3} — coming soon',
                  hint: 'This ocean lands with its feature.',
                ),
              ),
      ),
    );
  }
}
