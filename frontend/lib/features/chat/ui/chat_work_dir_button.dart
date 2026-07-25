import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/conversation.dart';
import '../../../core/design/tokens.dart';
import '../../../core/model/status_state.dart';
import '../../../core/notice/notice_center.dart';
import '../../../core/platform/open_in_system.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_divider.dart';
import '../../../core/ui/an_menu.dart';
import '../../../core/ui/an_tooltip.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import 'chat_git_actions.dart';
import '../state/conversation_header.dart';
import '../state/work_dir.dart';

/// The RESIDENCY button — the folder in the breadcrumb, immediately before the thread's name (WRK-077 WD1).
/// It is the whole user-facing surface of "we are zoomed in HERE", and it has exactly three states:
///
///   - **Unmounted** → a LAPTOP glyph, not an empty folder. The semantics are honest: with no work dir the
///     agent's reach is the whole machine, and an empty folder would imply a container that simply has
///     nothing in it. (拍板 #8 and §3.1 both say 电脑图标; the WD1 brief's paraphrase said "浅灰空文件夹" — the
///     spec's own reasoning wins and the deviation is recorded in the batch log.)
///   - **Mounted** → a FOLDER glyph. The directory's name is deliberately NOT on the breadcrumb: a path
///     fragment is the one thing a breadcrumb cannot show honestly (a basename is ambiguous between a dozen
///     `ui/` directories, and the full path does not fit), so the identity lives one click away in the menu's
///     head, where there is room for all of it. The tooltip names it on hover.
///   - **Missing** → the same folder glyph in the WARN tone. The user mounted a directory and then moved or
///     deleted it; saying so is the point (`WorkDirInfo.exists == false`), because every relative path and
///     every Bash command in this thread now has nowhere to land.
///
/// **Glyph-only in all three states** (WRK-083 B4). That is what keeps this button a fixed 28pt square: it
/// never reflows the breadcrumb when a thread is mounted, left, or renamed, and the title beside it never
/// shifts. It sits at [AnButtonSize.md] — the SAME rung as the model menu at the other end of the head
/// (WRK-083 B3); the old `sm` made a 24pt box that read as a second-class control next to a 28pt one and
/// mis-centred in the 44pt head band.
///
/// It is never disabled mid-generation: switching takes effect on the NEXT turn (the ctx is seeded per turn
/// from the row), so blocking the button would withhold a harmless action for a state it cannot corrupt.
///
/// The button is ALWAYS this widget AND always the same geometry — the three states differ only in glyph and
/// tone, never in structure or size, so nothing here remounts or reflows when a probe lands (禁止条件包装).
///
/// 驻地按钮——面包屑里那个文件夹，紧挨在线程名之前（WRK-077 WD1）。它就是「我们 zoom 到**这里**了」面向用户的
/// 全部表面，恰有三态：
///
///   - **未挂** → **电脑**字形、不是空文件夹。语义诚实：没有工作目录时 agent 的活动范围是**整台机器**，而一个空
///     文件夹会暗示「一个恰好什么都没装的容器」。（拍板 #8 与 §3.1 都写「电脑图标」；WD1 简报的转述写作
///     「浅灰空文件夹」——规格自带的理由胜出，偏离已记入本批记录。）
///   - **已挂** → 文件夹字形。目录名**刻意不上面包屑**：路径片段恰恰是面包屑没法诚实显示的东西（basename 在十几个
///     `ui/` 之间有歧义，完整路径又放不下），故身份放在**一击之外**的菜单头里，那里放得下全部。hover 时 tooltip 报名。
///   - **不存在** → 同一个文件夹字形、warn 色。用户挂了一个目录、然后把它移走或删了；把这件事说出来正是要点
///     （`WorkDirInfo.exists == false`），因为这条线程里每个相对路径、每条 Bash 命令现在都无处落地。
///
/// **三态一律纯字形**（WRK-083 B4）。正是这一点让它恒为 28pt 方块：挂载、退出、改名都不会让面包屑重排，旁边的
/// 标题也从不移位。尺寸取 [AnButtonSize.md]——与头部另一端的模型菜单**同一档**（WRK-083 B3）；旧的 `sm` 是 24pt
/// 盒子，挨着 28pt 的读作二等控件，且在 44pt 头带里没居中。
///
/// 它在生成中**从不禁用**：切换在**下一**回合生效（ctx 每回合从行播种），故禁掉它等于为一个它无法破坏的状态
/// 扣下一个无害动作。
///
/// 按钮**恒是**本组件、**且恒是同一几何**——三态只差字形与色调，结构与尺寸从不变，故一次探测落地时此处既不重挂
/// 也不重排（禁止条件包装）。
class ChatWorkDirButton extends ConsumerWidget {
  const ChatWorkDirButton({required this.conversationId, super.key});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    // WHETHER a residency is mounted comes from the thread's stored ROW, not from the projection. The row is
    // already loaded (the head beside this button watches the same provider), so the button knows its SHAPE on
    // the first frame — reading it off the async probe would render the laptop glyph for one frame and then
    // morph into folder+name every single time a mounted thread is opened.
    // 「有没有挂驻地」来自线程存下来的**行**、不来自投影。行本就已加载(这个按钮旁边的头部 watch 的是同一个
    // provider),故按钮**第一帧**就知道自己的**形状**——若从异步探测读它,每次打开一条已挂线程都会先渲一帧电脑字形、
    // 再形变成文件夹+名字。
    final storedPath =
        ref.watch(conversationHeaderProvider(conversationId)).value?.workDir ??
        '';
    // The PROJECTION decorates: does it still exist, is it a repo, which branch, any uncommitted work. A pending
    // or failed probe reads as "we don't know yet", never as an error — the breadcrumb must not grow a spinner
    // or a red box because a filesystem stat is in flight (the controller already swallows failures).
    // **投影**做装饰:它还在吗、是仓库吗、哪个分支、有没有没提交的活。探测在飞或失败都读作「还不知道」、绝不读作
    // 错误——面包屑不该因为一次 stat 在路上就长出转圈或红框(控制器已把失败吞掉)。
    final probe = ref.watch(workDirProvider(conversationId)).value;
    final info =
        probe ?? WorkDirInfo(path: storedPath, exists: storedPath.isNotEmpty);
    final mounted = storedPath.isNotEmpty;
    // "Missing" is only claimable once the probe has ANSWERED. Before that, absence of evidence is not the
    // warning state — flashing 「目录已不存在」 while the stat is in flight would be the button lying.
    // 「不存在」只有在探测**已回答**之后才能声称。在那之前,证据的缺席不是警示态——stat 还在路上就闪
    // 「目录已不存在」是这个按钮在撒谎。
    final missing = mounted && probe != null && !probe.exists;

    return AnMenu(
      // Start-aligned: the anchor sits at the head's far left, so the menu opens down-RIGHT (the popover
      // flips on overflow). Same choice as the model menu beside it.
      // start 对齐:锚在头部最左,故菜单**右下**展开(越界自翻)。与它旁边的模型菜单同一选择。
      alignEnd: false,
      // Re-probe on OPEN, not on build: git branch / dirtiness change in the user's own terminal, and the one
      // moment the answer must be current is the moment they are looking at it. Doing it on build would poll.
      // **打开时**重探、不在 build 里:git 分支/脏态会在用户自己的终端里变,而答案必须新鲜的那一刻正是他在看它的
      // 那一刻。放在 build 里就成了轮询。
      anchorBuilder: (context, toggle, isOpen) => AnTooltip(
        message: _tooltip(t, mounted ? info : const WorkDirInfo()),
        child: AnButton(
          // NO key, and no label in any state. Both states are now the SAME geometry — a 28pt glyph-only
          // square — so there is nothing for AnButton's box animation to interpolate and nothing to rebuild
          // a fresh box for. The old `ValueKey(mounted)` existed solely because mounting swapped a fixed-width
          // square for an unbounded glyph+label box, which AnButton cannot tween (it asserts); with the label
          // gone that swap no longer happens, so keeping the key would throw away and re-inflate the button on
          // every mount/leave for no reason at all.
          // **无 key、任何状态都无 label**。两态现在是**同一几何**——28pt 纯字形方块——故 AnButton 的盒子动画没有
          // 东西可插值、也没有理由新建盒子。旧的 `ValueKey(mounted)` 存在的唯一理由是:挂载会把定宽方块换成无界的
          // 字形+标签盒,而 AnButton 补间不了(它会 assert);标签去掉后那次换形不再发生,再留着这个 key 就是在每次
          // 挂载/退出时白白丢弃并重新 inflate 这个按钮。
          // Three states, three GLYPHS — laptop (whole machine) / folder (zoomed in) / folder-x (the
          // directory is gone). The alarm has to live here now: with the label removed there is no text to
          // carry it, and AnButton has no `warn` variant to tint with. A glyph also beats a tint — it
          // survives dark mode and colour-blindness.
          // 三态三**字形**——laptop(整台机器)/ folder(已 zoom 进去)/ folder-x(目录没了)。警报必须落在这里:标签
          // 去掉后没有文本能承载它,而 AnButton 没有 `warn` 变体可着色。字形也胜过着色——暗色与色盲下都还成立。
          icon: !mounted
              ? AnIcons.laptop
              : (missing ? AnIcons.folderMissing : AnIcons.folder),
          onPressed: () {
            if (!isOpen) {
              ref.read(workDirProvider(conversationId).notifier).refresh();
            }
            toggle();
          },
        ),
      ),
      entries: _entries(context, ref, t, mounted ? info : const WorkDirInfo()),
      // Keyed by the THREAD only. The old key also carried the missing-state, which discarded and
      // re-inflated the whole menu every time a probe flipped `exists` — churn for nothing, since `entries`
      // is rebuilt from the fresh info on every build anyway. The thread half stays: switching conversations
      // is a genuine identity change and an open popover must not survive it.
      // **只按线程**给 key。旧 key 还带着「不存在」态,于是每次探测翻转 `exists` 都把整个菜单丢弃重挂——纯粹的
      // 空转,因为 `entries` 本来每次 build 都按新鲜 info 重建。线程那一半保留:切换对话是真正的身份变更,开着的
      // 浮层不该活过它。
      key: ValueKey('workdir-menu-$conversationId'),
    );
  }

  String _tooltip(Translations t, WorkDirInfo info) {
    if (info.path.isEmpty) return t.chat.workDir.buttonNone;
    return info.exists
        ? t.chat.workDir.buttonMounted(path: info.path)
        : t.chat.workDir.buttonMissing(path: info.path);
  }

  /// The three-section grammar the right island speaks (身份头 / 动作 / git), expressed in AnMenu's own
  /// vocabulary: a section LABEL is the identity head (it carries the full path — the one place with room for
  /// it), then the residency actions, then the git段 only when the directory really is a repo.
  ///
  /// An UNMOUNTED thread gets the small menu §3.1 specifies — 「选择工作目录…」+ recent — because there is no
  /// identity to head and nothing to leave.
  ///
  /// 右岛那套三段式文法（身份头 / 动作 / git），用 AnMenu 自己的词汇表达:一个 section **标签**就是身份头(它承载
  /// 完整路径——唯一放得下它的地方)，接着是驻地动作，最后 git 段**仅在**目录真是仓库时出现。
  ///
  /// **未挂**线程拿到 §3.1 指定的那个小菜单——「选择工作目录…」+ 最近——因为没有身份可作头、也没有什么可退出。
  List<AnMenuEntry> _entries(
    BuildContext context,
    WidgetRef ref,
    Translations t,
    WorkDirInfo info,
  ) {
    final w = t.chat.workDir;
    final recent = ref.watch(recentWorkDirsProvider);
    final mounted = info.path.isNotEmpty;
    return [
      // ① identity head — the full path, plus the two ways out to the OS. ①身份头——完整路径 + 两个出口到系统。
      if (mounted) ...[
        AnMenuSection(info.path),
        if (!info.exists) AnMenuItem(label: w.missing, disabled: true),
        AnMenuItem(
          label: w.revealFinder,
          icon: AnIcons.folder,
          disabled: !info.exists,
          onTap: () => _openOnHost(context, ref, revealInSystem(info.path)),
        ),
        AnMenuItem(
          label: w.openTerminal,
          icon: AnIcons.terminal,
          disabled: !info.exists,
          onTap: () => _openOnHost(context, ref, openInTerminal(info.path)),
        ),
      ],
      // ② residency actions — pick / switch, and leave (only there is something to leave).
      // ②驻地动作——选 / 切换，以及退出（仅当真有什么可退出）。
      AnMenuItem(
        label: mounted ? w.kSwitch : w.choose,
        icon: AnIcons.folder,
        onTap: () => _pick(context, ref),
      ),
      if (mounted)
        AnMenuItem(
          label: w.leave,
          icon: AnIcons.laptop,
          onTap: () => _apply(context, ref, ''),
        ),
      // The recency list — machine-level, zero backend. The CURRENT residency is filtered out: offering to
      // switch to where you already are is a menu row that does nothing.
      // 最近列表——机器级、零后端。**当前**驻地被滤掉:提议切到你已经在的地方，是一行什么都不做的菜单项。
      if (recent.where((p) => p != info.path).isNotEmpty) ...[
        AnMenuSection(w.recent),
        for (final path in recent.where((p) => p != info.path))
          AnMenuItem(
            label: _basename(path),
            meta: path,
            icon: AnIcons.folder,
            onTap: () => _apply(context, ref, path),
          ),
      ],
      // ③ git — the state (WD1) and then the three ACTIONS (WD2 switch / new branch, WD3 worktree).
      // 只在真是仓库时出现:git 段——先是状态(WD1),再是三个**动作**(WD2 切/新建分支、WD3 worktree)。
      if (info.isGitRepo) ...[
        AnMenuSection(w.git),
        AnMenuItem(
          label: info.branch.isEmpty ? w.detached : w.branch(name: info.branch),
          icon: AnIcons.control,
          disabled: true,
        ),
        AnMenuItem(
          label: info.dirty ? w.dirty : w.clean,
          icon: info.dirty ? AnIcons.circle : AnIcons.check,
          disabled: true,
        ),
        // WD2 · SWITCH — every OTHER local branch, one tap each. Listing them inline rather than behind a
        // picker is the whole affordance: a residency has a handful of local branches (the projection excludes
        // `refs/remotes` for exactly this reason), the menu already scrolls at its own max height, and a
        // one-click switch is why this batch exists.
        // WD2 · **切换**——其余每一条本地分支各一行。内联列出、不藏在一个选择器后面,正是那份可供性:一个驻地有
        // 一小把本地分支(投影排除 `refs/remotes` 正为此),菜单本就在自己的最大高度处滚动,而一键切换正是本批
        // 存在的理由。
        //
        // While DIRTY the rows are replaced by ONE line that says why and what to do next, because the server
        // would refuse anyway (the guardrail: never carry uncommitted work onto another branch behind the
        // user's back) — offering a row that is certain to fail is worse than not offering it, and a disabled
        // row with no reason is a mystery.
        // **脏**时那些行被**一行**「为什么 + 下一步」顶替,因为服务端反正会拒(那道护栏:绝不在用户背后把未提交的活
        // 带到另一条分支上)——提供一个必定失败的行比不提供更糟,而一个不给理由的禁用行是个谜。
        if (info.dirty)
          AnMenuItem(label: w.dirtyBlocksSwitch, disabled: true)
        else
          ..._branchRows(context, ref, t, info),
        AnMenuItem(
          label: w.newBranch,
          icon: AnIcons.plus,
          onTap: () => showChatGitNameDialog(
            context,
            title: w.newBranchTitle,
            explainer: w.newBranchExplainer,
            placeholder: w.newBranchField,
            confirmLabel: w.newBranchConfirm,
            onSubmit: (name) => ref
                .read(workDirProvider(conversationId).notifier)
                .createBranch(name),
          ),
        ),
        // WD3 · the one-shot. The dialog names what it will do BEFORE the name is typed, because this one
        // writes a directory on disk. WD3 · 一条龙。对话框在名字被输入**之前**就说清它会做什么,因为这一个会在
        // 盘上写出一个目录。
        AnMenuItem(
          label: w.worktreeNew,
          icon: AnIcons.folder,
          onTap: () => showChatGitNameDialog(
            context,
            title: w.worktreeTitle,
            explainer: w.worktreeExplainer,
            placeholder: w.worktreeField,
            confirmLabel: w.worktreeConfirm,
            onSubmit: (name) => ref
                .read(workDirProvider(conversationId).notifier)
                .addWorktree(name),
          ),
        ),
        // The OTHER worktrees of this repository. Moving into one is a plain residency change — the same PATCH
        // «choose a directory» performs — so it needs no endpoint of its own, and it is the answer to
        // «that folder already exists»: the worktree you wanted is right here.
        // 本仓库的**其余** worktree。移进其中一份只是一次普通的驻地变更——与「选择工作目录」那次 PATCH 完全相同
        // ——故它不需要自己的端点;它也正是「那个文件夹已存在」的答案:你要的那份 worktree 就在这儿。
        if (info.worktrees.where((t) => !t.current).isNotEmpty) ...[
          AnMenuSection(w.worktreeSection),
          for (final tree in info.worktrees.where((t) => !t.current))
            AnMenuItem(
              label: _basename(tree.path),
              meta: tree.branch,
              icon: AnIcons.folder,
              onTap: () => _apply(context, ref, tree.path),
            ),
        ],
      ],
    ];
  }

  /// The switchable branches: every local head except the one already checked out (offering a switch to where
  /// you already are is a row that does nothing — the same rule the recency list follows).
  ///
  /// A failure lands in the notice center rather than a dialog: the tap carried no text to preserve, so there
  /// is nothing to keep open and correct. The copy still names the next step — this path is reachable when the
  /// tree turned dirty, or the branch vanished, between the menu opening and the tap.
  ///
  /// 可切换的分支:除已 checkout 的那一条之外的每一条本地 head（提议切到你已经在的地方是一行什么都不做的项——与
  /// 最近列表遵守的同一条规则）。
  ///
  /// 失败落在通知中心、不是对话框:这次点击**没有**携带任何文字要保留，故没有什么要保持打开并修正。文案仍点出下一步
  /// ——这条路径在「菜单打开与点击之间工作树变脏了、或那条分支消失了」时可达。
  List<AnMenuEntry> _branchRows(
    BuildContext context,
    WidgetRef ref,
    Translations t,
    WorkDirInfo info,
  ) {
    final w = t.chat.workDir;
    final others = info.branches.where((b) => b != info.branch).toList();
    if (others.isEmpty) return const [];
    return [
      AnMenuSection(w.switchBranchSection),
      for (final branch in others)
        AnMenuItem(
          label: branch,
          icon: AnIcons.control,
          onTap: () => _runGit(
            context,
            ref,
            () => ref
                .read(workDirProvider(conversationId).notifier)
                .switchBranch(branch),
          ),
        ),
    ];
  }

  /// Run a git action whose failure has no field to sit under, and report the refusal with its next step.
  ///
  /// 跑一个「失败时没有输入框可依附」的 git 动作，并把那次拒绝连同它的下一步报出来。
  Future<void> _runGit(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ref
          .read(noticeCenterProvider.notifier)
          .show(gitActionFailure(context.t, e), tone: AnTone.warn);
    }
  }

  /// Pick a directory and mount it. A cancelled picker (null) changes NOTHING — not the row, not the recency
  /// list, not the thread's marker.
  ///
  /// 选一个目录并挂上。取消（null）**什么都不改**——不改行、不改最近列表、不给线程落标记。
  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final picked = await ref.read(directoryPickerProvider)();
    if (picked == null || picked.trim().isEmpty) return;
    if (!context.mounted) return;
    await _apply(context, ref, picked);
  }

  Future<void> _apply(BuildContext context, WidgetRef ref, String dir) async {
    try {
      await ref.read(workDirProvider(conversationId).notifier).set(dir);
    } catch (_) {
      if (!context.mounted) return;
      ref
          .read(noticeCenterProvider.notifier)
          .show(context.t.chat.actionFailed, tone: AnTone.danger);
    }
  }

  /// Hand the path to the OS and say so when the OS could not oblige. A menu item that silently does nothing
  /// (no Terminal on this Linux box, a sandboxed environment) is worse than one that admits it.
  ///
  /// 把路径交给系统，系统办不到时**说出来**。一个静默什么都不做的菜单项（这台 Linux 上没有终端、沙箱环境）比一个
  /// 承认失败的更糟。
  Future<void> _openOnHost(
    BuildContext context,
    WidgetRef ref,
    Future<bool> action,
  ) async {
    final ok = await action;
    if (ok || !context.mounted) return;
    ref
        .read(noticeCenterProvider.notifier)
        .show(context.t.chat.workDir.openFailed, tone: AnTone.warn);
  }

  /// The directory's own name — the label the button shows. A trailing separator degrades to the full path
  /// rather than to an empty label (a root like `/` has no basename, and a nameless button is a mystery).
  ///
  /// 目录自己的名字——按钮显示的标签。末尾带分隔符时退化成完整路径、而不是退化成空标签（`/` 这样的根没有
  /// basename，而一个没有名字的按钮是个谜）。
  static String _basename(String path) {
    final trimmed = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    final i = trimmed.lastIndexOf('/');
    final name = i < 0 ? trimmed : trimmed.substring(i + 1);
    return name.isEmpty ? path : name;
  }
}

/// The residency's in-line MARK in the transcript — the durable `marker` block the backend appends when the
/// work dir changes mid-thread. Rendered as the compaction whisper's twin (`AnDivider.labeled`, the labelled-
/// hairline idiom) because it answers the same kind of question: something about the CONVERSATION changed
/// here, between turns, and a reader scrolling back needs to see where.
///
/// The wording is built HERE from the block's attrs, never from its content — the block's content is empty by
/// contract precisely so the label can be localized (a Go-side sentence would freeze one language into a
/// durable row). Three shapes, because both ends are meaningful: first mount (`from` empty), a switch, and
/// leaving (`to` empty).
///
/// transcript 里驻地的**行内标记**——工作目录在线程中途改变时后端追加的持久 `marker` 块。渲成压缩低语的孪生件
/// （`AnDivider.labeled`，带标发丝线语法），因为它答的是同一类问题:关于**这段对话**的某件事在这里、在两个回合之间
/// 变了，而往回翻的读者需要看见它变在哪里。
///
/// 文案在**此处**据块的 attrs 构造、绝不据它的 content——该块的 content 按契约为空，正是为了让标签可以本地化（Go
/// 侧写一句话等于把一种语言冻进一条持久行）。三种形状，因为两端都有意义:首次挂载（`from` 空）、切换、退出（`to` 空）。
class ChatWorkDirMark extends StatelessWidget {
  const ChatWorkDirMark({required this.from, required this.to, super.key});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final w = context.t.chat.workDir;
    final label = switch ((from.isEmpty, to.isEmpty)) {
      (true, _) => w.markMounted(to: to),
      (false, true) => w.markLeft(from: from),
      (false, false) => w.markSwitched(from: from, to: to),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
      // The labelled hairline is the divider family's job (WRK-066 A-086), exactly as ChatContextMark uses it —
      // this widget only owns the attrs → sentence mapping and its i18n.
      // 带标发丝线归分隔线族（A-086），与 ChatContextMark 用法完全一致——本件只管 attrs → 句子的映射与它的 i18n。
      child: AnDivider.labeled(label, icon: AnIcons.folder),
    );
  }
}
