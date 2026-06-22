import 'dart:async';

import 'package:flutter/material.dart';

import '../core/design/colors.dart';
import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/ui/ui.dart';

/// Dev-only mock of the three-island shell (Entities ocean), faithfully matching the demo,
/// with the full chrome interactions live: collapse/expand the left island, drag its right
/// edge to resize, toggle the right island, and a peek that appears after a moment. No
/// backend/i18n.
/// 三岛 shell 开发 mock(Entities 海洋),交互齐全:收起/展开左岛、拖右缘调宽、开合右岛、稍后浮现 peek。
class ShellDemo extends StatefulWidget {
  const ShellDemo({super.key});

  @override
  State<ShellDemo> createState() => _ShellDemoState();
}

class _ShellDemoState extends State<ShellDemo> {
  int _nav = 1; // Entities
  int _sel = 0;
  bool _peek = false;
  Timer? _peekTimer;

  @override
  void initState() {
    super.initState();
    _peekTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _peek = true);
    });
  }

  @override
  void dispose() {
    _peekTimer?.cancel();
    super.dispose();
  }

  static const _oceans = <AnSidebarNav>[
    AnSidebarNav(icon: AnIcons.chat, label: 'Chat'),
    AnSidebarNav(icon: AnIcons.entities, label: 'Entities'),
    AnSidebarNav(icon: AnIcons.scheduler, label: 'Scheduler'),
    AnSidebarNav(icon: AnIcons.document, label: 'Documents'),
  ];

  static const _entities = <(IconData, String, AnStatus)>[
    (AnIcons.function, 'greet_user', AnStatus.done),
    (AnIcons.agent, 'Research agent', AnStatus.run),
    (AnIcons.workflow, 'Nightly digest', AnStatus.done),
    (AnIcons.handler, 'Webhook handler', AnStatus.err),
    (AnIcons.function, 'summarize_text', AnStatus.idle),
    (AnIcons.mcp, 'github', AnStatus.done),
    (AnIcons.skill, 'code-review', AnStatus.idle),
  ];

  static const _code = 'def greet(name: str) -> dict:\n'
      '    # build a friendly greeting\n'
      '    msg = f"Hello, {name}!"\n'
      '    return {"message": msg, "len": len(msg)}';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnShell(
      headTitle: _entities[_sel].$2,
      sidebarBuilder: (onCollapse) => AnSidebar(
        workspaceName: 'Personal',
        nav: _oceans,
        selectedIndex: _nav,
        onSelect: (i) => setState(() => _nav = i),
        onCollapse: onCollapse,
        unread: _peek,
        peek: _peek
            ? AnPeek(
                message: 'Nightly digest · waiting for approval',
                onView: () => setState(() => _peek = false),
                onDismiss: () => setState(() => _peek = false),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
          children: [
            for (var i = 0; i < _entities.length; i++)
              AnRow(
                leading: _entities[i].$1,
                title: _entities[i].$2,
                selected: i == _sel,
                trailing: AnStatusDot(_entities[i].$3),
                onTap: () => setState(() => _sel = i),
              ),
          ],
        ),
      ),
      oceanBuilder: (scroll) => AnPage(
        controller: scroll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnOceanHeader(
              crumb: const ['Entities', 'Function'],
              title: _entities[_sel].$2,
              actions: [
                AnButton(label: 'Run', icon: AnIcons.run, variant: AnButtonVariant.primary, onPressed: () {}),
                AnIconButton(AnIcons.iterate, tooltip: 'Iterate with AI', onPressed: () {}),
                AnIconButton(AnIcons.more, tooltip: 'More', onPressed: () {}),
              ],
              meta: const [
                AnBadge('active v3', tone: AnBadgeTone.accent),
                AnBadge('ready', tone: AnBadgeTone.ok),
              ],
            ),
            AnInfoCard(
              title: 'Overview',
              children: [
                AnKvRow(label: 'Kind', child: const AnBadge('Function', variant: AnBadgeVariant.outline)),
                const AnKvRow(label: 'Description', value: 'Build a friendly greeting for a user.'),
                const AnKvRow(label: 'Updated', value: '2 minutes ago'),
              ],
            ),
            const SizedBox(height: AnSpace.s24),
            AnSection(title: 'Code', child: const AnCodeBlock(_code)),
            const SizedBox(height: AnSpace.s24),
            AnSection(
              title: 'Inputs',
              child: AnThinTable(
                columns: const [AnColumn('Name', flex: 2), AnColumn('Type'), AnColumn('Required')],
                rows: [
                  [
                    Text('name', style: AnText.body.copyWith(color: c.ink)),
                    Text('str', style: AnText.mono.copyWith(color: c.inkMuted)),
                    const AnBadge('yes', tone: AnBadgeTone.ok),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      rightIsland: AnRightIsland(
        title: 'Last run',
        icon: AnIcons.run,
        onClose: () {},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AnStatusDot(AnStatus.done),
                const SizedBox(width: AnSpace.s8),
                Text('Completed in 0.4s', style: AnText.body.copyWith(color: c.ink)),
              ],
            ),
            const SizedBox(height: AnSpace.s16),
            Text('RESULT', style: AnText.label.copyWith(color: c.inkFaint)),
            const SizedBox(height: AnSpace.s8),
            const AnJsonTree({'message': 'Hello, Ada!', 'len': 11, 'ok': true}),
          ],
        ),
      ),
    );
  }
}
