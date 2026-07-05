import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/runtime.dart';
import '../core/shell/ocean_breadcrumb.dart';
import '../core/shell/oceans.dart';
import '../core/shell/shell_chrome.dart';
import '../core/ui/ui.dart';
import '../features/chat/state/selected_conversation.dart';
import '../features/chat/ui/chat_head.dart';
import '../features/chat/ui/chat_ocean.dart';
import '../features/chat/ui/conversation_rail.dart';
import '../features/documents/state/document_state.dart';
import '../features/documents/ui/document_ocean.dart';
import '../features/documents/ui/document_rail.dart';
import '../features/documents/ui/documents_inspector.dart';
import '../core/shell/right_panel.dart';
import '../features/entities/state/selected_entity.dart';
import '../features/entities/ui/entity_ocean.dart';
import '../features/entities/ui/entity_rail.dart';
import '../features/entities/ui/flowrun_inbox.dart';
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
/// orthogonal, takes the left-island middle). [OceanKind.isBuilt] oceans (chat / entities / documents)
/// mount their features; the rest render a "coming soon" placeholder. The notifications tray mounts the
/// cross-run approval INBOX. Entity selection + the right island are URL-driven and gated to the
/// entities ocean.
///
/// 左岛(自上而下,chrome 条下):海洋切换器(顶部 4 海洋)· 中段(当前海洋 rail,铃开时换成通知托盘——通知接管左岛、非中心)·
/// 底栏(workspace 快捷菜单 | 设置格 | 铃格)。两条独立轴:选中海洋(顶部 4 + 齿轮进的 settings,驱动中心)与通知托盘(正交,占左岛中段)。
/// 已建海洋(chat/entities/documents,OceanKind.isBuilt)挂真 feature,其余「即将推出」占位;通知托盘=跨 run 审批收件箱。
/// 实体选区 + 右岛走 URL、仅 entities 生效。
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocean = ref.watch(selectedOceanProvider);
    final onEntities = ocean == OceanKind.entities;
    // Leaving an ocean that OWNS the floating-head breadcrumb (entities' entity detail / documents' page
    // title) clears it — breadcrumb lifecycle belongs to the ocean SWITCH, not to a side-effect-only
    // placeholder widget. 离开拥有浮层头的海洋(entities 详情/documents 页题)即清——生命周期属于海洋切换。
    ref.listen(selectedOceanProvider, (prev, next) {
      const headOwners = {OceanKind.entities, OceanKind.documents};
      if (prev != null && headOwners.contains(prev) && prev != next) {
        ref.read(shellHeadProvider.notifier).clear();
      }
    });
    // Chat mounts its rail in the left-island middle AND its center ocean (landing / transcript+composer).
    // chat 同时挂左岛 rail 与中心海洋(landing / transcript+composer)。
    final onChat = ocean == OceanKind.chat;
    // Documents ocean: the file-like knowledge library (document tree + skills) in the left island +
    // a read/edit center. 文档海洋:文件式知识库(文档树 + skill)左岛 + 中心读/编。
    final onDocuments = ocean == OceanKind.documents;
    // A /chat/:id navigation (deep link, restored URL) pulls the ocean to chat — the URL is the
    // conversation-selection truth, so the ocean must follow it, never fight it. (Full ocean routing is
    // the planned go_router fold-in; this is the one coherence rule needed until then.)
    // /chat/:id 导航(深链/恢复)把海洋拉到 chat——URL 是会话选区真相,海洋必须跟、不能顶。(海洋整体路由化是
    // 既定后续;在那之前只需这一条一致性规则。)
    ref.listen(selectedConversationProvider, (prev, next) {
      if (next != null) ref.read(selectedOceanProvider.notifier).select(OceanKind.chat);
    });
    // Same coherence rule for documents: a /documents/... navigation (rail click, deep link, restored
    // URL) pulls the ocean to documents. documents 同款一致性规则:/documents/... 导航把海洋拉到 documents。
    ref.listen(selectedDocProvider, (prev, next) {
      if (next != null) ref.read(selectedOceanProvider.notifier).select(OceanKind.documents);
    });
    final notifOpen = ref.watch(notificationsOpenProvider);
    // The right island reveals for entities (run terminal) OR documents (properties inspector) when that
    // ocean has a selection. 右岛在 entities(run 终端)或 documents(属性面板)有选中时揭示。
    final hasEntitySelection = onEntities && ref.watch(selectedEntityProvider) != null;
    final hasDocSelection = onDocuments && ref.watch(selectedDocProvider) != null;
    final hasSelection = hasEntitySelection || hasDocSelection;
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
                : onDocuments
                    ? const DocumentRail()
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
        ocean: onEntities
            ? const EntityOcean()
            : onChat
                ? const ChatOcean()
                : onDocuments
                    ? const DocumentOcean()
                    : const _OceanPlaceholder(),
        // Documents → the properties inspector; entities → the run terminal (the shell only reveals it when
        // that ocean has a selection). documents→属性面板;entities→run 终端。
        inspector: AnInspector(
          headless: true,
          child: onDocuments ? const DocumentsInspector() : const RunTerminal(),
        ),
        inspectorOpen: hasSelection && !rightCollapsed,
        leftCollapsed: chrome.leftCollapsed,
        leftWidth: chrome.leftWidth,
        onToggleLeft: toggleLeft,
        onLeftWidthCommitted: (w) => ref.read(shellChromeProvider.notifier).setLeftWidth(w),
        head: onChat ? const ChatHead() : const OceanBreadcrumb(),
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

/// The notifications tray — takes over the left-island middle when the bell is on: for now the
/// cross-run approval INBOX (parked approvals awaiting a decision). A broader
/// notifications feed lands with the notifications feature; approvals are its first, most-actionable
/// section. 铃托盘:当前=审批收件箱(跨 run 待审 parked 节点);更广的通知流随通知 feature 落地。
class _NotificationsTray extends StatelessWidget {
  const _NotificationsTray();

  @override
  Widget build(BuildContext context) => const FlowrunInbox();
}

/// Open-ocean placeholder for an unbuilt ocean (breadcrumb clearing lives at the ocean switch, see the
/// [selectedOceanProvider] listener in [AppShell]). 未建海洋的中心占位(清面包屑在海洋切换处)。
class _OceanPlaceholder extends StatelessWidget {
  const _OceanPlaceholder();

  @override
  Widget build(BuildContext context) => AnState(
        kind: AnStateKind.empty,
        title: context.t.shell.comingSoonTitle,
        hint: context.t.shell.comingSoonHint,
      );
}
