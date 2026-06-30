import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/runtime.dart';
import '../core/shell/ocean_breadcrumb.dart';
import '../core/shell/oceans.dart';
import '../core/shell/shell_chrome.dart';
import '../core/ui/ui.dart';
import '../features/chat/ui/conversation_rail.dart';
import '../features/entities/state/run/right_panel.dart';
import '../features/entities/state/selected_entity.dart';
import '../features/entities/ui/entity_ocean.dart';
import '../features/entities/ui/entity_rail.dart';
import '../features/entities/ui/run/run_terminal.dart';
import '../i18n/strings.g.dart';

/// THE single shell composition — which feature sits in which island. Mounted by BOTH entries so the real
/// app and the demo never diverge (`lib/main.dart` → `make app` with live repos behind the startup gate;
/// `lib/dev/demo_main.dart` → `make demo` with fixtures, no gate). App vs demo differ ONLY in data + startup.
///
/// LEFT ISLAND (top → bottom, under the chrome bar): the [AnOceanSwitcher] (top 4 oceans) · the MIDDLE
/// (the current ocean's rail, OR the notifications tray when the bell is on — notifications take over the
/// left island, NOT the center) · the [AnSidebarFooter] (workspace quick-actions menu | settings cell |
/// bell cell). TWO independent axes: the selected OCEAN ([selectedOceanProvider] — top 4 + the
/// gear-reached `settings`, drives the CENTER) and the notifications tray ([notificationsOpenProvider] —
/// orthogonal, takes the left-island middle). Only [OceanKind.entities] is built; every other ocean +
/// the notifications tray render a "coming soon" placeholder. Entity selection + the right island are
/// URL-driven and gated to the entities ocean.
///
/// 左岛(自上而下,chrome 条下):海洋切换器(顶部 4 海洋)· 中段(当前海洋 rail,铃开时换成通知托盘——通知接管左岛、非中心)·
/// 底栏(workspace 快捷菜单 | 设置格 | 铃格)。两条独立轴:选中海洋(顶部 4 + 齿轮进的 settings,驱动中心)与通知托盘(正交,占左岛中段)。
/// 仅 entities 已建,其余海洋 + 通知托盘均「即将推出」占位。实体选区 + 右岛走 URL、仅 entities 生效。
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocean = ref.watch(selectedOceanProvider);
    final onEntities = ocean == OceanKind.entities;
    // Chat mounts its rail in the left-island middle ONLY — the center transcript/ocean is a later
    // phase, so chat keeps the coming-soon center (don't fold onChat into one flag driving both).
    // chat 只在左岛中段挂 rail——中心海洋是后续片,故 chat 保持「即将推出」中心(别用一个 flag 同驱中段+中心)。
    final onChat = ocean == OceanKind.chat;
    final notifOpen = ref.watch(notificationsOpenProvider);
    // Entity selection + the right island are entities-only (URL-driven); dormant on other oceans.
    final hasSelection = onEntities && ref.watch(selectedEntityProvider) != null;
    final rightCollapsed = ref.watch(rightPanelCollapsedProvider);
    final chrome = ref.watch(shellChromeProvider);
    final wsName = ref.watch(activeWorkspaceNameProvider) ?? context.t.shell.workspaceFallback;

    void toggleLeft() => ref.read(shellChromeProvider.notifier).toggleLeft();
    void toggleRight() => ref.read(rightPanelCollapsedProvider.notifier).toggle();
    // Picking ANY ocean (top 4 or the gear→settings) dismisses the notifications tray and shows that
    // ocean's rail + center — the tray is transient, navigating away closes it. 选任一海洋即收起通知托盘、展示该海洋。
    void selectOcean(OceanKind k) {
      ref.read(selectedOceanProvider.notifier).select(k);
      ref.read(notificationsOpenProvider.notifier).close();
    }

    // Top switcher = the first four oceans (order MUST match OceanKind). 顶部切换器 = 前四海洋(顺序须与 OceanKind 一致)。
    final oceanItems = <AnOceanItem>[
      AnOceanItem(id: 'chat', icon: AnIcons.chat, label: context.t.shell.ocean.chat),
      AnOceanItem(id: 'entities', icon: AnIcons.entities, label: context.t.shell.ocean.entities),
      AnOceanItem(id: 'scheduler', icon: AnIcons.scheduler, label: context.t.shell.ocean.scheduler),
      AnOceanItem(id: 'documents', icon: AnIcons.doc, label: context.t.shell.ocean.documents),
    ];
    // No top selection while a footer ocean (settings) is active. 在底栏海洋(settings)时顶部无选中。
    final topSelected = ocean.inTopSwitcher ? ocean.index : -1;

    // The left-island MIDDLE: notifications tray (takeover) wins; else the ocean's rail. 中段:通知托盘优先,否则海洋 rail。
    final Widget middle = notifOpen
        ? const _NotificationsTray()
        : onEntities
            ? const EntityRail()
            : onChat
                ? const ConversationRail()
                : const _RailPlaceholder();

    final sidebar = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Horizontally scrollable so a narrow / dragged-min island never clips it (demo `.nav`). 可横滚,窄岛不裁。
        SizedBox(
          height: AnSize.row,
          child: ScrollConfiguration(
            behavior: const AnScrollBehavior(),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: AnOceanSwitcher(
                items: oceanItems,
                selectedIndex: topSelected,
                onSelect: (i) => selectOcean(OceanKind.values[i]),
              ),
            ),
          ),
        ),
        const SizedBox(height: AnSpace.s8),
        Expanded(child: middle),
        const SizedBox(height: AnSpace.s8),
        AnSidebarFooter(
          workspace: AnMenu(
            // Full-width dropdown that drops straight down from the workspace button. 与 workspace 钮等宽下展。
            matchAnchorWidth: true,
            alignEnd: false,
            anchorBuilder: (context, toggle, isOpen) =>
                AnWorkspaceButton(name: wsName, onTap: toggle, isOpen: isOpen),
            entries: [
              AnMenuItem(label: wsName, checked: true, onTap: () {}),
              AnMenuItem(
                label: context.t.shell.newWorkspace,
                icon: AnIcons.plus,
                // Skeleton: creating workspaces is a follow-up. 骨架:新建工作区为后续。
                onTap: () => ref.read(overlayProvider.notifier).showToast(context.t.shell.comingSoonTitle),
              ),
              AnMenuItem(
                label: context.t.shell.workspaceSettings,
                icon: AnIcons.gear,
                onTap: () => selectOcean(OceanKind.settings),
              ),
            ],
          ),
          settingsLabel: context.t.shell.settings,
          notificationsLabel: context.t.shell.notifications,
          onSettings: () => selectOcean(OceanKind.settings),
          settingsActive: ocean == OceanKind.settings,
          onNotifications: () => ref.read(notificationsOpenProvider.notifier).toggle(),
          notificationsActive: notifOpen,
          // Skeleton: the unread count + red dot wire when the notifications feature lands. 骨架:未读数后续接。
          unreadCount: 0,
        ),
      ],
    );

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyB, meta: true): toggleLeft,
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): toggleLeft,
        const SingleActivator(LogicalKeyboardKey.backslash, meta: true): toggleRight,
        const SingleActivator(LogicalKeyboardKey.backslash, control: true): toggleRight,
      },
      child: AnShell(
        sidebar: sidebar,
        ocean: onEntities ? const EntityOcean() : const _OceanPlaceholder(),
        inspector: const AnInspector(headless: true, child: RunTerminal()),
        inspectorOpen: hasSelection && !rightCollapsed,
        leftCollapsed: chrome.leftCollapsed,
        leftWidth: chrome.leftWidth,
        onToggleLeft: toggleLeft,
        onLeftWidthCommitted: (w) => ref.read(shellChromeProvider.notifier).setLeftWidth(w),
        head: const OceanBreadcrumb(),
        // titlebarHeight defaults to AnSize.titlebar (lights-centering band, real-run verified). 用默认带高。
        onToggleRight: hasSelection ? toggleRight : null,
      ),
    );
  }
}

/// Rail placeholder for an unbuilt ocean (inset "coming soon"). 未建海洋的 rail 占位。
class _RailPlaceholder extends StatelessWidget {
  const _RailPlaceholder();

  @override
  Widget build(BuildContext context) => AnState(
        kind: AnStateKind.empty,
        size: AnStateSize.inset,
        title: context.t.shell.comingSoonTitle,
        hint: context.t.shell.comingSoonHint,
      );
}

/// The notifications tray — takes over the left-island middle when the bell is on. Skeleton placeholder.
/// 通知托盘——铃开时接管左岛中段。骨架占位。
class _NotificationsTray extends StatelessWidget {
  const _NotificationsTray();

  @override
  Widget build(BuildContext context) => AnState(
        kind: AnStateKind.empty,
        size: AnStateSize.inset,
        title: context.t.shell.notifications,
        hint: context.t.shell.notificationsHint,
      );
}

/// Open-ocean placeholder for an unbuilt ocean. Clears any stale floating-head breadcrumb the entities
/// ocean may have left (a non-entities ocean has none). 未建海洋的中心占位;清掉 entities 海洋遗留的面包屑。
class _OceanPlaceholder extends ConsumerStatefulWidget {
  const _OceanPlaceholder();

  @override
  ConsumerState<_OceanPlaceholder> createState() => _OceanPlaceholderState();
}

class _OceanPlaceholderState extends ConsumerState<_OceanPlaceholder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(shellHeadProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) => AnState(
        kind: AnStateKind.empty,
        title: context.t.shell.comingSoonTitle,
        hint: context.t.shell.comingSoonHint,
      );
}
