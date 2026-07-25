import 'dart:convert';

import 'package:file_selector/file_selector.dart' as file_selector;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/conversation.dart';
import '../../../core/settings/settings_prefs.dart';
import '../data/chat_providers.dart';
import '../data/chat_repository.dart';
import 'conversation_header.dart';

/// The open thread's RESIDENCY state — the live projection of its mounted work dir (`GET /{id}/workdir`) plus
/// the two writes that change it. Split from [conversationHeaderProvider] on purpose: the header holds the
/// thread's stored ROW, while this holds facts about the FILESYSTEM (does the directory still exist, which
/// branch, any uncommitted work) that change without the row changing — a user switching branch in their own
/// terminal must be visible on the next open, and caching that into the row's lifetime would make the menu lie.
///
/// The read is deliberately NOT retried and swallows errors into the unmounted projection. This is decoration
/// on a breadcrumb: a failed probe must render as "no residency", never as an error state, and never as an
/// exponential-backoff poll (the trap CH-b documented for the header provider).
///
/// 打开线程的**驻地**状态——它已挂工作目录的活投影(`GET /{id}/workdir`)+ 改变它的那两个写。**刻意**与
/// conversationHeaderProvider 分开:头部持线程存下来的**行**,而本件持关于**文件系统**的事实(目录还在吗、哪个
/// 分支、有没有没提交的活)——那些事实会在行不变的情况下改变:用户在自己终端里切了分支,下次打开就必须看得见,
/// 而把它缓存进行的生命周期会让菜单撒谎。
///
/// 这次读**刻意不重试**,并把错误吞成未挂投影。这是面包屑上的装饰:探测失败必须渲成「无驻地」、绝不渲成错误态,
/// 也绝不成为一个指数退避的轮询(CH-b 为 header provider 记下的那个陷阱)。
class WorkDirController extends AsyncNotifier<WorkDirInfo> {
  WorkDirController(this.conversationId);

  final String conversationId;
  late ChatRepository _repo;

  @override
  Future<WorkDirInfo> build() async {
    _repo = ref.watch(chatRepositoryProvider);
    return _probe();
  }

  Future<WorkDirInfo> _probe() async {
    try {
      return await _repo.workDirInfo(conversationId);
    } catch (_) {
      return const WorkDirInfo();
    }
  }

  /// Mount / switch / unmount (`''` unmounts) — the ONE orchestration point, so no caller has to remember the
  /// three things a residency change involves.
  ///
  /// The ROW write goes through [conversationHeaderProvider]: that controller owns the thread's stored row and
  /// patches itself from the authoritative PATCH response, which is what makes the breadcrumb's folder
  /// re-label on the spot instead of waiting for the notification echo. Then the PROJECTION is re-probed from
  /// the ECHOED path rather than the string that was sent — the backend expands `~` and Cleans the path, and a
  /// switch must not leave the previous branch on screen.
  ///
  /// Remembering the directory is deliberately conditioned on SUCCESS: a path the backend refused (a relative
  /// string) has no business in a list the user picks from.
  ///
  /// 挂 / 切换 / 退出(`''` 即退出)——**唯一**的编排点,故没有哪个调用方需要记住一次驻地变更涉及的那三件事。
  ///
  /// **行**的写走 conversationHeaderProvider:那个控制器拥有线程存下来的行、并据权威 PATCH 响应 patch 自己,正是
  /// 这一点让面包屑那个文件夹**当场**重新贴标签、而不是等通知回声。随后**投影**按**回显**的路径重探、而不是按发出去
  /// 的那个字符串——后端会展开 `~`、Clean 路径,而一次切换绝不能把上一个分支留在屏上。
  ///
  /// 「记住这个目录」**刻意**以**成功**为条件:一个被后端拒掉的路径(比如相对串),没资格进用户挑选的那份列表。
  Future<Conversation> set(String workDir) async {
    final updated = await ref
        .read(conversationHeaderProvider(conversationId).notifier)
        .setWorkDir(workDir);
    if (updated.workDir.isNotEmpty) {
      ref.read(recentWorkDirsProvider.notifier).remember(updated.workDir);
    }
    final info = await _probe();
    if (ref.mounted) state = AsyncData(info);
    return updated;
  }

  /// Re-read the projection (the menu opening, a window regaining focus). Cheap and idempotent; it never
  /// clears the current value first, so an open menu does not blink.
  ///
  /// 重读投影(菜单打开、窗口重获焦点)。廉价且幂等;它绝不先清掉当前值,故打开着的菜单不会闪。
  Future<void> refresh() async {
    final info = await _probe();
    if (ref.mounted) state = AsyncData(info);
  }

  /// Switch to an existing branch (WD2). The action's OWN response is the new state — the server re-probes
  /// after the checkout, so adopting it means the menu never shows one frame of the old branch.
  ///
  /// Failures are deliberately NOT swallowed here (unlike the read): the read is decoration on a breadcrumb,
  /// while this is a change the user asked for, and the guardrail's whole value is the sentence it refuses with
  /// («commit or stash them, then switch branches»). The caller renders it.
  ///
  /// 切到一条已存在的分支（WD2）。该动作**自己**的响应就是新状态——服务端在 checkout 之后重探，故采用它意味着菜单
  /// 绝不会显示一帧旧分支。
  ///
  /// 此处**刻意不吞**失败（与那次读相反）:读是面包屑上的装饰，而这是用户要求的一次**改动**，且那道护栏的全部价值就在
  /// 它拒绝时说的那句话（「先提交或贮藏，再切换分支」）。由调用方去渲它。
  Future<void> switchBranch(String branch) =>
      _apply(() => _repo.switchBranch(conversationId, branch));

  /// Create a branch at the current HEAD and move onto it (WD2). Allowed with uncommitted work: the new branch
  /// starts where you already are, so nothing can collide.
  ///
  /// 在当前 HEAD 上建一条分支并移过去（WD2）。有未提交的活时**允许**:新分支起点就是你已经在的地方，什么都撞不上。
  Future<void> createBranch(String branch) =>
      _apply(() => _repo.createBranch(conversationId, branch));

  /// Open a worktree for this conversation and follow the residency into it (WD3).
  ///
  /// The thread's stored ROW moved server-side, so the header provider is invalidated too — the breadcrumb's
  /// folder reads its label from the row (that is what lets it know its shape on the first frame), and leaving
  /// the row stale would show the new branch under the old directory's name.
  ///
  /// 为本对话开一份 worktree，并让驻地跟进去（WD3）。
  ///
  /// 线程存下来的**行**在服务端动了，故 header provider 也要失效——面包屑那个文件夹的标签读自那一行（正是它让按钮第一
  /// 帧就知道自己的形状），把那一行留在过期状态会显示成「新分支挂在旧目录名下」。
  Future<void> addWorktree(String name) async {
    await _apply(() => _repo.addWorktree(conversationId, name));
    ref.invalidate(conversationHeaderProvider(conversationId));
  }

  /// Run one residency-changing action and adopt its authoritative projection. Errors propagate; the state is
  /// only replaced on success, so a refused action leaves the menu describing reality.
  ///
  /// 跑一个改变驻地的动作并采用它权威的投影。错误向上抛;仅成功时替换 state，故一次被拒的动作会让菜单继续描述现实。
  Future<void> _apply(Future<WorkDirInfo> Function() action) async {
    final info = await action();
    if (ref.mounted) state = AsyncData(info);
  }
}

final workDirProvider = AsyncNotifierProvider.autoDispose
    .family<WorkDirController, WorkDirInfo, String>(WorkDirController.new);

/// The MACHINE-level recent-directory list — zero backend by design (WRK-077 §2.2 "零后端项"). Which folders
/// this person works in is a property of their machine, not of a workspace or a thread; the thread already
/// stores the one it is mounted on.
///
/// Most-recent-first, de-duplicated, capped. The cap exists because this is a convenience menu: past a
/// handful of entries a "recent" list stops being recall and becomes a directory the user has to read.
///
/// **机器级**最近目录表——按设计**零后端**(WRK-077 §2.2「零后端项」)。这个人在哪些文件夹里干活是他机器的属性、
/// 不是某个工作区或某条线程的属性;线程本就存着它挂上的那一个。
///
/// 最近在前、去重、有上限。上限的存在是因为这是一个便利菜单:超过一小把之后,「最近」列表就不再是回忆、而变成
/// 一份用户得去阅读的目录。
class RecentWorkDirs extends Notifier<List<String>> {
  /// Eight is a menu section a person reads at a glance; a longer recency list is a file browser, and we
  /// already have one of those (「选择工作目录…」).
  /// 八条是一个人一眼扫完的菜单段;更长的最近列表就是个文件浏览器,而那个我们已经有了(「选择工作目录…」)。
  static const int cap = 8;

  @override
  List<String> build() => _decode(
    ref.watch(settingsPrefsProvider).getString(SettingsKeys.chatRecentWorkDirs),
  );

  /// Promote [dir] to the front (a re-pick moves it up rather than duplicating it).
  ///
  /// 把 [dir] 提到最前(重复挑选是上移、不是产生副本)。
  void remember(String dir) {
    final path = dir.trim();
    if (path.isEmpty) return;
    final next = [path, ...state.where((p) => p != path)];
    _write(next.length > cap ? next.sublist(0, cap) : next);
  }

  /// Forget one entry — a directory that no longer exists, or one the user simply does not want offered.
  ///
  /// 忘掉一条——已不存在的目录,或用户就是不想再被推荐的目录。
  void forget(String dir) => _write(state.where((p) => p != dir).toList());

  void _write(List<String> next) {
    state = next;
    ref
        .read(settingsPrefsProvider)
        .setString(SettingsKeys.chatRecentWorkDirs, jsonEncode(next));
  }

  // A malformed value degrades to empty rather than throwing: this is a convenience list, and a corrupt pref
  // must never be able to keep the app from starting.
  // 坏值退化成空、不抛:这是便利列表,一份损坏的偏好绝不该让 app 起不来。
  static List<String> _decode(String raw) {
    if (raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is String && e.trim().isNotEmpty) e,
      ];
    } catch (_) {
      return const [];
    }
  }
}

final recentWorkDirsProvider = NotifierProvider<RecentWorkDirs, List<String>>(
  RecentWorkDirs.new,
);

/// The directory PICKER seam: the real `file_selector` dialog by default, overridable in a widget test.
///
/// It is a provider rather than a direct call (the composer's attachment picker calls `openFiles()` inline)
/// because「选择工作目录…」is the one menu item whose whole behaviour is "what happens AFTER the user picks" —
/// remember it, PATCH it, re-probe git, mark the thread. A native modal in the middle of that chain would make
/// every one of those steps untestable, and they are exactly the steps that can break. null = the user
/// cancelled, and cancelling must change nothing.
///
/// 目录**选择器**接缝:默认是真的 `file_selector` 对话框,widget 测试里可 override。
///
/// 做成 provider 而非直接调用(composer 的附件选择器就是内联 `openFiles()`),因为「选择工作目录…」是唯一那个
/// 「全部行为都发生在用户挑完**之后**」的菜单项——记住它、PATCH、重探 git、给线程落标记。链条中间摆一个原生模态
/// 会让上面每一步都测不了,而它们恰恰正是会坏的那些步骤。null = 用户取消,而取消必须什么都不改变。
typedef DirectoryPicker = Future<String?> Function();

final directoryPickerProvider = Provider<DirectoryPicker>(
  (ref) => file_selector.getDirectoryPath,
);
