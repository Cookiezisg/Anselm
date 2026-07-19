import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/tokens.dart';
import '../core/runtime.dart';
import '../core/router/navigation.dart';
import '../core/shell/ocean_breadcrumb.dart';
import '../core/shell/oceans.dart';
import '../core/shell/shell_chrome.dart';
import '../core/ui/ui.dart';
import '../features/chat/state/selected_conversation.dart';
import '../features/chat/state/sidestage_activity_provider.dart';
import '../features/chat/state/sidestage_auto_reveal.dart';
import '../features/chat/state/stage_director_provider.dart';
import '../features/chat/ui/stage_panel.dart';
import '../features/chat/ui/chat_head.dart';
import '../features/chat/ui/chat_ocean.dart';
import '../features/chat/ui/chat_toc.dart';
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
import '../features/notifications/state/notice_capsule_provider.dart';
import '../features/notifications/state/toast_dispatcher.dart';
import '../features/scheduler/state/selected_scheduler.dart';
import '../features/scheduler/ui/scheduler_ocean.dart';
import '../features/scheduler/ui/scheduler_rail.dart';
import '../features/scheduler/ui/scheduler_run_inspector.dart';
import '../features/settings/ui/settings_ocean.dart';
import '../features/settings/ui/settings_rail.dart';
import '../features/notifications/state/unread_count_provider.dart';
import '../features/notifications/ui/notification_tray.dart';
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
      // The floating head binds ONLY the page's own title (用户 0719 面包屑律③:浮层头零路径). settings and
      // scheduler are head owners too but never clear on dispose — omit them and their stale title ghosts
      // over the next ocean. settings/scheduler 亦拥浮层头,dispose 不自清,故海洋切换在此统一清。
      const headOwners = {
        OceanKind.entities,
        OceanKind.documents,
        OceanKind.settings,
        OceanKind.scheduler,
      };
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
    final onSettings = ocean == OceanKind.settings;
    // A /chat/:id navigation (deep link, restored URL) pulls the ocean to chat — the URL is the
    // conversation-selection truth, so the ocean must follow it, never fight it. (Full ocean routing is
    // the planned go_router fold-in; this is the one coherence rule needed until then.)
    // /chat/:id 导航(深链/恢复)把海洋拉到 chat——URL 是会话选区真相,海洋必须跟、不能顶。(海洋整体路由化是
    // 既定后续;在那之前只需这一条一致性规则。)
    ref.listen(selectedConversationProvider, (prev, next) {
      if (next != null) {
        ref.read(selectedOceanProvider.notifier).select(OceanKind.chat);
      }
    });
    // Same coherence rule for documents: a /documents/... navigation (rail click, deep link, restored
    // URL) pulls the ocean to documents. documents 同款一致性规则:/documents/... 导航把海洋拉到 documents。
    ref.listen(selectedDocProvider, (prev, next) {
      if (next != null) {
        ref.read(selectedOceanProvider.notifier).select(OceanKind.documents);
      }
    });
    // And for scheduler: a /scheduler... navigation (deep link, fr_ paste, panel_registry flowrun ref)
    // pulls the ocean to scheduler. scheduler 同款:/scheduler... 导航把海洋拉过来。
    ref.listen(selectedSchedulerProvider, (prev, next) {
      if (next != null) {
        ref.read(selectedOceanProvider.notifier).select(OceanKind.scheduler);
      }
    });
    // And for entities: an /entities/:kind/:id navigation pulls the ocean to entities — this rule
    // existed for the other three URL-owning oceans but not here, so an entity deep link landed on
    // whatever ocean was up. entities 同款(此前唯独缺这条,实体深链会落在别的海洋上)。
    ref.listen(selectedEntityProvider, (prev, next) {
      if (next != null) {
        ref.read(selectedOceanProvider.notifier).select(OceanKind.entities);
      }
    });
    final notifOpen = ref.watch(notificationsOpenProvider);
    // The right island reveals for entities (run terminal), documents (properties inspector) OR chat
    // (the sidestage, WRK-061) when that ocean has a selection. 右岛在 entities(run 终端)/documents(属性
    // 面板)/chat(侧幕)有选中时揭示。
    // Only executable kinds (the four Quadrinity) get the run-terminal right island — support kinds
    // (control/approval/trigger, verb=null) have no execution face, so revealing a run terminal for them
    // shows a dead empty pane with a no-op run button. Mirror the verb-CTA `executable` gate.
    // 仅可执行 kind 揭示 run 终端右岛;支撑 kind 无执行面,揭示=死空板+空动作钮。延用动词 CTA 的 executable 门控。
    final hasEntitySelection =
        onEntities &&
        (ref.watch(selectedEntityProvider)?.kind.executable ?? false);
    final hasDocSelection =
        onDocuments && ref.watch(selectedDocProvider) != null;
    final chatConversation = onChat
        ? ref.watch(selectedConversationProvider)?.id
        : null;
    // The chat right island exists ONLY when the sidestage has content (用户 0718-19: 空对话的右岛钮=通向
    // 墓碑的门). The Scenes (场次) button still rides the head for any selected thread (below) — only the
    // right island + its panel-right toggle are activity-gated. 有 activity 才有右岛(+ toggle);Scenes 照旧。
    final chatHasActivity =
        chatConversation != null &&
        ref.watch(sidestageActivityProvider(chatConversation));
    // 缺口A (0719): drive the sidestage auto-reveal for the selected chat thread — a following FollowMode opens
    // the (default-collapsed) island on the first staged activity, respecting a manual close. Bare-watched so it
    // runs whether the island is open or closed. 侧幕自动揭示:跟随档下首个登台开(默认收起的)岛,尊重手动关。
    if (chatConversation != null) {
      ref.watch(sidestageAutoRevealProvider(chatConversation));
    }
    // Scheduler reveals the island ONLY on the run flagship (WRK-069 §6) — the Overview board and
    // the operations home are self-sufficient, and revealing an inspector for them would be an
    // island for the island's sake. scheduler 仅在 run 旗舰揭示右岛:看板与运营主页自足,不为放而放。
    final onScheduler = ocean == OceanKind.scheduler;
    final hasRunSelection =
        onScheduler && ref.watch(selectedSchedulerProvider) is SchedulerRun;
    final hasSelection =
        hasEntitySelection ||
        hasDocSelection ||
        chatHasActivity ||
        hasRunSelection;
    final rightCollapsed = ref.watch(rightPanelCollapsedProvider);
    // R-15: a collapsed sidestage keeps only the activity bit — a live channel behind the fold
    // lights a dot on the panel-right button. 收起的侧幕只留活动位:折叠后有 live 频道即点亮右钮点。
    final rightActivity =
        rightCollapsed &&
        chatConversation != null &&
        ref.watch(
          stageDirectorProvider(
            chatConversation,
          ).select((st) => st.channels.any((ch) => ch.live)),
        );
    final chrome = ref.watch(shellChromeProvider);
    final wsName =
        ref.watch(activeWorkspaceNameProvider) ??
        context.t.shell.workspaceFallback;

    void toggleLeft() => ref.read(shellChromeProvider.notifier).toggleLeft();
    void toggleRight() =>
        ref.read(rightPanelCollapsedProvider.notifier).toggle();
    // Picking ANY ocean (top 4 or the gear→settings) dismisses the notifications tray and shows that
    // ocean's rail + center — the tray is transient, navigating away closes it. 选任一海洋即收起通知托盘、展示该海洋。
    void selectOcean(OceanKind k) {
      ref.read(selectedOceanProvider.notifier).select(k);
      ref.read(notificationsOpenProvider.notifier).close();
    }

    // Top switcher = the first four oceans (order MUST match OceanKind). 顶部切换器 = 前四海洋(顺序须与 OceanKind 一致)。
    final oceanItems = <AnOceanItem>[
      AnOceanItem(
        id: 'chat',
        icon: AnIcons.chat,
        label: context.t.shell.ocean.chat,
      ),
      AnOceanItem(
        id: 'entities',
        icon: AnIcons.entities,
        label: context.t.shell.ocean.entities,
      ),
      AnOceanItem(
        id: 'scheduler',
        icon: AnIcons.scheduler,
        label: context.t.shell.ocean.scheduler,
      ),
      AnOceanItem(
        id: 'documents',
        icon: AnIcons.doc,
        label: context.t.shell.ocean.documents,
      ),
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
        : onSettings
        ? const SettingsRail()
        : ocean == OceanKind.scheduler
        ? const SchedulerRail()
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
                onTap: () => ref
                    .read(overlayProvider.notifier)
                    .showToast(context.t.shell.comingSoonTitle),
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
          onNotifications: () =>
              ref.read(notificationsOpenProvider.notifier).toggle(),
          notificationsActive: notifOpen,
          // The bell's red dot lights when there are unread inbox rows (authoritative COUNT; frame-only
          // reconciliation echoes never count). 铃红点=有未读收件箱行(权威 COUNT,仅帧回声不计)。
          unreadCount: ref.watch(unreadCountProvider).value ?? 0,
        ),
      ],
    );

    // Global command shortcuts (⌘B/⌘\/⌘,/⌘±/⌘0) are mounted at the APP ROOT by [GlobalShortcuts] —
    // ABOVE the autofocus Focus, so cold-start keystrokes reach them (see app.dart). Here the shell only
    // wires the SAME actions to its on-screen affordances (collapse buttons). 全局命令由 app 根的
    // GlobalShortcuts 挂载(autofocus 之上,冷启动即达);壳只把同一批动作接到屏上按钮。
    return _SessionServices(
      child: AnShell(
        sidebar: sidebar,
        bandNotice: const _BandNoticeHost(),
        // The center ocean is a LAZY IndexedStack (C-009): a visited ocean stays MOUNTED behind the fold,
        // so switching away and back is instant AND keeps its scroll offset / expansion state (the ternary
        // it replaced tore the tree down on every switch, losing all of it — Riverpod keepAlive preserved
        // the DATA but not the widget state). Lazy = an ocean isn't built until first visited, so cold start
        // doesn't eagerly mount all four + fire their fetches at once. 中心海洋=懒 IndexedStack:访问过的
        // 海洋常驻折叠后,切走再回瞬时且保滚动位/展开态(旧三元每次切换拆树、keepAlive 只保数据不保 widget 态);
        // 懒=首访才建,冷启不急挂四海洋齐发请求。
        ocean: _OceanStack(active: ocean),
        // Documents → the properties inspector; chat → the sidestage; scheduler → the run flagship's
        // two-faced inspector; entities → the run terminal (the shell only reveals it when that ocean
        // has a selection). documents→属性面板;chat→侧幕;scheduler→run 旗舰双脸检查器;entities→run 终端。
        inspector: AnInspector(
          headless: true,
          child: onDocuments
              ? const DocumentsInspector()
              : chatConversation != null
              ? StagePanel(conversationId: chatConversation)
              : onScheduler
              ? const SchedulerRunInspector()
              : const RunTerminal(),
        ),
        inspectorOpen: hasSelection && !rightCollapsed,
        rightWidth: chrome.rightWidth,
        onRightWidthCommitted: (w) =>
            ref.read(shellChromeProvider.notifier).setRightWidth(w),
        leftCollapsed: chrome.leftCollapsed,
        leftWidth: chrome.leftWidth,
        onToggleLeft: toggleLeft,
        onLeftWidthCommitted: (w) =>
            ref.read(shellChromeProvider.notifier).setLeftWidth(w),
        head: onChat ? const ChatHead() : const OceanBreadcrumb(),
        // Chat's scene/outline nav rides the shell head-trailing slot so it sits RIGHT beside the panel-right
        // toggle (not stranded at the head content's edge); the run flagship's ✕ rides the SAME slot
        // (需求⑥ 0717-晚:与 chat 图标簇同位) — it closes back to the workflow operations home, the
        // keyboard twin of the page's bare-Esc. chat 场次/大纲钮走 shell 头尾槽,紧靠右岛钮;run 旗舰的 ✕
        // 走同一槽(与 chat 簇同位),点击回运营主页,是页内裸 Esc 的鼠标孪生。
        headTrailing: onChat && chatConversation != null
            ? TranscriptToc(conversationId: chatConversation)
            : hasRunSelection
            ? _CloseRunButton(
                selection: ref.watch(selectedSchedulerProvider) as SchedulerRun,
              )
            : null,
        // The chrome control band stays [AnSize.titlebar] in fullscreen too, so the collapse button +
        // breadcrumb keep the SAME comfortable top gap as windowed (#10: the old `fullScreen ? 0` collapsed
        // the band and pinned them cramped to the screen top — the reported bug). AnWindowControls still
        // collapses its HORIZONTAL traffic-light gutter in fullscreen on its own (a separate axis).
        // 全屏也保持带高:顶控/面包屑与小窗同款舒适顶距(旧 fullScreen?0 贴顶=报告的 bug);横向红绿灯槽由
        // AnWindowControls 自行在全屏收 0(另一轴)。
        titlebarHeight: AnSize.titlebar,
        onToggleRight: hasSelection ? toggleRight : null,
        rightActivity: rightActivity,
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

/// The notifications tray — takes over the left-island middle when the bell is on. The [NotificationTray]
/// owns the rail-architecture chrome (search + ⚙ menu + collapsible groups + feed); the app shell only
/// INJECTS the cross-feature "Needs you" approval band ([FlowrunInbox] sectioned — an entities-feature
/// widget), which the tray renders as its top group. Composed here (not inside the feature) so features
/// stay independent.
///
/// 铃托盘:铃开接管左岛中段。NotificationTray 持 rail 架构 chrome(搜索 + ⚙ 菜单 + 可折叠组 + feed);app 壳只
/// 注入跨 feature 的「待你处理」审批带(FlowrunInbox 分段,entities 件),托盘渲作首组。在此组合(非在 feature 内)
/// 保 features 互不依赖。
class _NotificationsTray extends StatelessWidget {
  const _NotificationsTray();

  @override
  Widget build(BuildContext context) =>
      const NotificationTray(approvalsBand: FlowrunInbox(sectioned: true));
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

/// The center ocean host as a LAZY [IndexedStack] (C-009): each ocean is built on FIRST visit and then
/// kept MOUNTED behind the fold, so re-selecting it is instant and its scroll offset / expansion state
/// survive (Riverpod keepAlive already preserved the DATA; this preserves the WIDGET state). Unvisited
/// oceans are a zero-cost [SizedBox] until first shown, so cold start never mounts all four + fires their
/// fetches at once. A non-stack ocean (scheduler «coming soon») rides a trailing placeholder slot, so the
/// stack — and every kept-alive ocean in it — stays mounted even while the placeholder shows.
/// 中心海洋=懒 IndexedStack:首访才建、此后常驻折叠后,重选瞬时且保滚动位/展开态(keepAlive 保数据、此保 widget 态);
/// 未访海洋是零成本 SizedBox 直到首显,冷启不急挂四海洋齐发请求;非栈海洋(scheduler 占位)走末位占位槽,
/// 栈(及其中常驻海洋)在占位期也不卸。
class _OceanStack extends StatelessWidget {
  const _OceanStack({required this.active});

  final OceanKind active;

  // The stack's oceans in a fixed slot order; a trailing slot (index == length) holds the «coming soon»
  // placeholder for any future non-stack ocean, so selecting one never tears the alive oceans down.
  // 固定槽顺序;末位=未来非栈海洋的占位槽,选它不卸活海洋。
  static const _oceans = [
    OceanKind.chat,
    OceanKind.entities,
    OceanKind.scheduler,
    OceanKind.documents,
    OceanKind.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final slot = _oceans.indexOf(active);
    return AnLazyIndexedStack(
      index: slot < 0 ? _oceans.length : slot,
      count:
          _oceans.length +
          1, // + the trailing «coming soon» placeholder slot 末位占位槽
      sizing: StackFit.expand,
      builder: (context, i) => i < _oceans.length
          ? _oceanFor(_oceans[i])
          : const _OceanPlaceholder(),
    );
  }

  Widget _oceanFor(OceanKind k) => switch (k) {
    OceanKind.chat => const ChatOcean(),
    OceanKind.entities => const EntityOcean(),
    OceanKind.scheduler => const SchedulerOcean(),
    OceanKind.documents => const DocumentOcean(),
    OceanKind.settings => const SettingsOcean(),
  };
}

/// The run flagship's shell-corner ✕ (需求⑥) — same slot as chat's head-trailing cluster.
/// run 旗舰的壳角 ✕——与 chat 头尾簇同槽。
class _CloseRunButton extends ConsumerWidget {
  const _CloseRunButton({required this.selection});

  final SchedulerRun selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnButton.iconOnly(
      AnIcons.close,
      semanticLabel: context.t.scheduler.run.closeA11y,
      onPressed: () =>
          ref.read(goRouterProvider).go('/scheduler/w/${selection.workflowId}'),
    );
  }
}

/// Session-long service ignition, OUTSIDE the build phase. The toast dispatcher's first build chains
/// live-repo creation whose synchronous stream emissions can invalidate an upstream provider — doing
/// that inside AppShell.build tripped Riverpod's "setState during build" on every cold start (预存启动
/// 异常的根因). A post-frame read starts the same keep-alive services one frame later, off the build
/// stack; the dispatcher is a root (non-autoDispose) Notifier, so one read keeps it alive for the
/// session. 会话级服务点火,移出 build 期:toast 派发器首建会级联 live repo 创建,其同步流发射会令上游
/// provider 自失效——在 build 里首建即触发「setState during build」。postFrame read 一帧后点火,
/// 非 autoDispose 一次即终身。
class _SessionServices extends ConsumerStatefulWidget {
  const _SessionServices({required this.child});

  final Widget child;

  @override
  ConsumerState<_SessionServices> createState() => _SessionServicesState();
}

class _SessionServicesState extends ConsumerState<_SessionServices> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(toastDispatcherProvider);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}


/// The band-capsule host — shows the notice queue's head as ONE self-timing [AnNoticeCapsule];
/// dismiss/tap pops the queue so the next notice takes the band. Fed into [AnShell.bandNotice] (DIP:
/// the kit slot stays feature-free). 顶带胶囊宿主:显示队首(自计时胶囊),收场/点击出队递补;经
/// AnShell.bandNotice 喂入(DIP,套件槽不沾 feature)。
class _BandNoticeHost extends ConsumerWidget {
  const _BandNoticeHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(noticeCapsuleProvider);
    if (queue.isEmpty) return const SizedBox.shrink();
    final n = queue.first;
    return AnNoticeCapsule(
      key: ValueKey(n.key),
      text: n.text,
      icon: n.icon,
      danger: n.danger,
      viewLabel: context.t.notifications.view,
      onTap: n.location == null
          ? null
          : () {
              final loc = n.location!;
              ref.read(noticeCapsuleProvider.notifier).pop();
              ref.read(goRouterProvider).go(loc);
            },
      onDismissed: () => ref.read(noticeCapsuleProvider.notifier).pop(),
    );
  }
}
