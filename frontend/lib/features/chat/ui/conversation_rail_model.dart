import 'package:flutter/widgets.dart' show IconData;

import '../../../core/contract/conversation.dart';
import '../../../core/model/sidebar_model.dart';
import '../../../core/model/status_state.dart';
import '../../../core/ui/icons.dart';
import '../state/conversation_list_provider.dart';
import '../state/conversation_list_state.dart';

/// The lead status dot for a conversation rail row — or null for a plain active thread (no dot, the
/// common case). Precedence, highest first:
///   generating (blue, the only animated/breathing dot) > awaiting input (amber "needs you") >
///   unread (green "answered while you were away") > archived (gray marker) > none.
/// AWAITING wins over generating: a human-loop-blocked turn keeps `isGenerating` true (the blocked
/// goroutine still holds the run slot) AND sets `awaitingInput` — so if generating were checked first,
/// the "needs you" amber dot (the single most actionable state) would be permanently masked by blue.
/// The archived gray dot is a static "this is archived" marker that only shows when the rail includes
/// archived threads.
///
/// 会话 rail 行的前导状态点——普通活跃线程返 null(无点,常态)。优先级(高→低):**等你输入(琥珀「等你」,
/// 最该被凸显)> 生成中(蓝、呼吸)> 未读(绿「你不在时答完了」)> 已归档(灰标记)> 无**。等你优先于生成中:被人闸
/// 阻塞的回合后端 isGenerating 与 awaitingInput **同时为真**(阻塞的 goroutine 仍占 run 槽),若先判生成中,
/// 「需要你」的琥珀点会被蓝点永久遮蔽。归档灰点是静态标记,仅当 rail 含归档时出现。
AnStatus? conversationDot(Conversation c) {
  if (c.awaitingInput) return AnStatus.wait;
  if (c.isGenerating) return AnStatus.run;
  if (c.hasUnread) return AnStatus.done;
  if (c.archived) return AnStatus.idle;
  return null;
}

/// The i18n strings for the relative-time row meta — injected (not read from slang) so the formatter
/// stays pure + unit-testable without a Translations object. The widget binds these from `t.chat.time`.
///
/// 相对时间行 meta 的 i18n 串——注入(不直读 slang),使格式化纯、可单测、不依赖 Translations。widget 从 t.chat.time 绑。
class ConvTimeStrings {
  const ConvTimeStrings({
    required this.justNow,
    required this.yesterday,
    required this.minutesAgo,
    required this.hoursAgo,
    required this.daysAgo,
  });

  final String justNow;
  final String yesterday;
  final String Function(int n) minutesAgo;
  final String Function(int n) hoursAgo;
  final String Function(int n) daysAgo;
}

/// The relative-time label for a row (just now / N min / N hr / yesterday / N days / a numeric date for
/// older). Calendar-day based in LOCAL time; older than 7 days → `y/m/d` (locale-neutral numerics). This
/// is the per-row timestamp; it does NOT drive grouping (the rail's groups are residencies, not time buckets).
///
/// 行的相对时间(刚刚/N 分钟/N 小时/昨天/N 天/更老用数字日期)。本地日历日;>7 天 → `年/月/日`(纯数字)。仅是行时间戳,
/// 不参与分组(rail 的组是驻地、不是时间桶)。
String conversationTimeLabel(DateTime atUtc, DateTime now, ConvTimeStrings s) {
  final at = atUtc.toLocal();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(at.year, at.month, at.day)).inDays;
  if (days <= 0) {
    final mins = now.difference(at).inMinutes;
    if (mins < 1) return s.justNow;
    if (mins < 60) return s.minutesAgo(mins);
    return s.hoursAgo(now.difference(at).inHours);
  }
  if (days == 1) return s.yesterday;
  if (days <= 7) return s.daysAgo(days);
  return '${at.year}/${at.month}/${at.day}';
}

/// The i18n labels the rail model needs — New/filter chrome, the two flat section labels (Pinned / Recents),
/// and the time strings. Bundled so the pure builder takes one struct (mirrors entities' RailLabels). The
/// residency groups need no label from here: a group is named by its own directory.
///
/// rail 模型需的 i18n 标签——New/过滤 chrome、两个平段标签(置顶 / 最近)、时间串。打包成一个 struct 喂纯 builder
/// (镜像 entities RailLabels)。驻地组不需要此处任何标签:一个组由它自己的目录命名。
class ConvRailLabels {
  const ConvRailLabels({
    required this.newLabel,
    required this.filter,
    required this.pinned,
    required this.recents,
    required this.time,
  });

  final String newLabel;
  final String filter;
  final String pinned;
  final String recents;
  final ConvTimeStrings time;
}

/// A DISPLAY name per residency path, disambiguated against its siblings.
///
/// A directory is named by its own last segment — `~/code/anselm` is «anselm», which is what the user calls
/// it. But two mounted directories can share that name (`~/work/anselm` and `~/fork/anselm`), and two
/// identical rail heads are worse than a long one: the user cannot tell which folder they are about to
/// archive. So a colliding name grows LEFTWARD one parent segment at a time, and only for the paths that
/// actually collide — the algorithm is «shortest suffix that is unique», not «show everything».
///
/// Growth is per-collision-cluster and repeats, because one extra segment need not settle it
/// (`a/x/anselm` vs `b/x/anselm` both become `x/anselm` and must grow again). A path that runs out of
/// segments stops growing and keeps its full spelling — it cannot collide with anything else at that point
/// (two identical paths are one residency).
///
/// 每个驻地路径的**显示名**，对着它的兄弟消歧。
///
/// 一个目录由它自己的末段命名——`~/code/anselm` 就是「anselm」，那正是用户对它的叫法。但两个已挂目录可以同名
/// （`~/work/anselm` 与 `~/fork/anselm`），而两个一模一样的 rail 组头比一个长组头更糟:用户分不清自己正要归档哪个
/// 文件夹。故撞名者**向左**逐段生长，且**只有真正撞上的那些**才生长——算法是「唯一的最短后缀」、不是「全都显示」。
///
/// 生长按撞名簇进行且**反复**，因为多一段未必能分开（`a/x/anselm` 与 `b/x/anselm` 都会变成 `x/anselm`、还得再长）。
/// 段用尽的路径停止生长、保留它完整的拼法——那时它不可能再与任何东西撞（两条完全相同的路径就是同一个驻地）。
Map<String, String> workDirGroupLabels(Iterable<String> paths) {
  final all = paths.toList(growable: false);
  final segments = {for (final p in all) p: _segments(p)};
  final depth = {for (final p in all) p: 1};
  var grew = true;
  while (grew) {
    grew = false;
    final byLabel = <String, List<String>>{};
    for (final p in all) {
      byLabel.putIfAbsent(_suffix(p, segments[p]!, depth[p]!), () => []).add(p);
    }
    for (final cluster in byLabel.values) {
      if (cluster.length < 2) continue;
      for (final p in cluster) {
        if (depth[p]! < segments[p]!.length) {
          depth[p] = depth[p]! + 1;
          grew = true;
        }
      }
    }
  }
  return {for (final p in all) p: _suffix(p, segments[p]!, depth[p]!)};
}

// Path segments, separator-agnostic (a Windows residency arrives with backslashes) and empty-tolerant.
// 路径分段,分隔符不敏感(Windows 驻地带反斜杠)且容忍空段。
List<String> _segments(String path) =>
    path.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty).toList();

// The last `depth` segments, joined by '/'. A path with no segments at all (a bare root) has no name to
// show, so it degrades to its own spelling rather than to an empty head.
// 末 `depth` 段、以 '/' 连。完全没有段的路径(裸根)没有名字可显,故退化成它自己的拼法、而不是一个空组头。
String _suffix(String path, List<String> segs, int depth) {
  if (segs.isEmpty) return path;
  return segs.sublist(segs.length - depth.clamp(1, segs.length)).join('/');
}

// How many threads a group holds in the scope the rail is currently showing — the head's number, and the
// test for whether the group renders at all. 一个组在 rail 当前所显范围下装着几条线程——组头的那个数,也是它是否渲染的判据。
int _scopeCount(WorkDirGroup g, bool showArchived) =>
    showArchived ? g.activeCount + g.archivedCount : g.activeCount;

/// Project the loaded rail state onto a [SidebarModel] for [AnSidebarList] — FOUR sections in the order the
/// user asked for: **Pinned**, then one section per **residency group**, then **Recents**.
///
///   - **Pinned** (pin icon) — every pinned thread, across residencies. Pinned WINS: a pinned thread is here
///     and NOT in its residency group, so it renders exactly once.
///   - **📁 residency groups** — one per mounted directory, named by [workDirGroupLabels] (collisions grow a
///     parent segment), counted from the SERVER's projection so the number cannot drift with scrolling,
///     ordered by the group's own recency. All but the FIRST start folded: the folder metaphor is
///     click-to-open, folding keeps «Recents» reachable without scrolling past everything, and a folded
///     section fetches nothing at all — while the most-recently-active group, which is where you were just
///     working, is open. Each group's `pageKey` is its axis key, so its tail sentinel fetches its first page
///     when it is expanded AND scrolled into view.
///   - **Recents** (history icon) — ONLY the threads that live in no directory. A residency thread is in its
///     group and nowhere else, so nothing is duplicated here either.
///
/// A section is emitted only when it has something to show, EXCEPT the zero-data case: with no conversations
/// at all, Pinned + Recents both render empty (the collapsed shape of the full rail, 用户 0718 拍板) — but no
/// residency group is invented, because a group with nothing in it does not exist (it is a projection).
///
/// 把已加载的 rail 态投影成 SidebarModel 喂 AnSidebarList——**四段**、顺序就是用户要的:**置顶**、每个**驻地组**一段、
/// **最近**。
///
///   - **置顶**(pin 图标)——所有置顶线程、跨驻地。**置顶赢**:置顶线程在这里、**不**在它的驻地组里,故恰好渲一次。
///   - **📁 驻地组**——每个已挂目录一个,名字由 [workDirGroupLabels] 给(撞名者补父路径),计数取**服务端**投影故
///     不随滚动漂移,按组自身最近活跃排序。**除第一个外**默认收起:文件夹的心智就是点开、收起使「最近」不必翻过一切
///     才够得着,而收起的段**什么都不取**——同时那个最近活跃的组(你刚在里面干活的那个)是开着的。每组的 `pageKey`
///     就是它的轴键,故它的尾哨兵在它被展开**且**滚进视野时取它的第一页。
///   - **最近**(history 图标)——**仅**不住在任何目录里的线程。驻地线程在它的组里、别处没有,故此处也不重复。
///
/// 段只在有货时发射,**除零数据情形**:完全没有对话时,置顶 + 最近都渲空(满态收起的形状,用户 0718 拍板)——但**不**
/// 凭空造驻地组,因为一个什么都没装的组**并不存在**(它是投影)。
SidebarModel buildConversationRailModel(
  ConversationListState data, {
  required DateTime now,
  required ConvRailLabels labels,
  bool showCount = true,
  bool showTime = true,
  bool showArchived = false,
}) {
  // showTime/showCount are the ⚙ "show time" / "show counts" toggles: a null meta/count renders nothing
  // (AnRow omits the trailing time; the section head omits the count). showTime/showCount = ⚙ 开关:meta/count 为 null 则不渲。
  // An un-titled thread (created, auto-title pending or failed) falls back to the same "New chat" word
  // the head uses — a rail row must never render blank. 未命名线程回落「New chat」(与头一致),行绝不空白。
  SidebarRow toRow(Conversation c) => SidebarRow(
    id: c.id,
    label: c.title.trim().isEmpty ? labels.newLabel : c.title,
    meta: showTime
        ? conversationTimeLabel(c.lastMessageAt, now, labels.time)
        : null,
    dot: conversationDot(c),
  );

  int? count(int n) => showCount && n > 0 ? n : null;

  SidebarType axisSection({
    required String? label,
    required IconData icon,
    required String axisKey,
    required ConvAxis axis,
    int? headCount,
    bool initiallyFolded = false,
  }) => SidebarType(
    label: label,
    icon: icon,
    // Group heads already carry their own projection count. Flat axes use the exact list total from the
    // response header; falling back to loaded rows is only for fixtures or an older non-conforming source.
    // 组头已有自己的投影计数。平轴使用响应头里的精确总数；只有 fixture 或旧数据源缺头时才回退到已加载行数。
    count: count(headCount ?? axis.total ?? axis.rows.length),
    pageKey: axisKey,
    hasMore: axis.hasMore,
    loadingMore: axis.loadingMore,
    // M9: failure = a manual retry row, never an auto-refire 失败=手动重试行,绝非自动重触发
    loadError: axis.loadFailed,
    initiallyFolded: initiallyFolded,
    rows: [for (final c in axis.rows) toRow(c)],
  );

  // A query REPLACES the structure with one flat, headless result list (see [ConversationListState.searching]):
  // a folded folder fetches nothing, so narrowing the four sections would hide every match the user had not
  // already scrolled into view. Headless because a result list has no folder to head and no count to state —
  // the rows ARE the answer.
  // 有查询词时结构被**替换**成一条平的、**无头**的结果列表(见 [ConversationListState.searching]):收起的文件夹
  // 什么都不取,故收窄那四段会藏掉每一条用户尚未滚进视野的匹配。无头,因为结果列表没有文件夹可作头、也没有计数可
  // 声明——那些**行本身**就是答案。
  if (data.searching) {
    return SidebarModel(
      newLabel: labels.newLabel,
      filterPlaceholder: labels.filter,
      groups: [
        SidebarGroup(
          types: [
            SidebarType(
              pageKey: recentsAxisKey,
              hasMore: data.recents.hasMore,
              loadingMore: data.recents.loadingMore,
              loadError: data.recents.loadFailed,
              rows: [for (final c in data.recents.rows) toRow(c)],
            ),
          ],
        ),
      ],
    );
  }

  // Zero conversations anywhere = render BOTH flat heads (the collapsed shape of the full rail); with data,
  // an empty Pinned stays hidden. 完全无对话=两个平段头都渲(满态收起形);有数据则藏空置顶。
  final zeroData = data.allRows.isEmpty && data.groups.isEmpty;
  final groupLabels = workDirGroupLabels(data.groups.map((g) => g.workDir));

  return SidebarModel(
    newLabel: labels.newLabel,
    filterPlaceholder: labels.filter,
    groups: [
      SidebarGroup(
        types: [
          if (data.pinned.rows.isNotEmpty || zeroData)
            axisSection(
              label: labels.pinned,
              icon: AnIcons.pin,
              axisKey: pinnedAxisKey,
              axis: data.pinned,
            ),
          // The head count is the SERVER's — the projection counts the whole workspace's threads in that
          // residency, so it does not change as the user scrolls the group. Which of the two counts (or their
          // sum) is the honest number depends on what the rail is showing.
          // 组头计数是**服务端**的——投影数的是该驻地在整个 workspace 里的线程，故它不随用户滚动该组而变。两个计数
          // 中哪个（或二者之和）才是诚实的那个数，取决于 rail 正在显示什么。
          for (final (i, g) in data.groups.indexed)
            // A group whose count IN THE CURRENT SCOPE is zero does not render at all: archiving a folder's
            // last thread must make the folder go away, exactly as deleting it does (a group is a projection
            // — it exists only while something is in it). The projection still reports the group, because its
            // archived threads are still there and «show archived» will bring the whole folder back.
            // 在**当前范围**下计数为零的组根本不渲:归档一个文件夹最后一条线程必须让那个文件夹消失,与删掉它一样
            // (组是投影——它只在里面还有东西时存在)。投影仍报告该组,因为它的归档线程还在、开「显示已归档」会把整个
            // 文件夹带回来。
            if (_scopeCount(g, showArchived) > 0)
              axisSection(
                label: groupLabels[g.workDir] ?? g.workDir,
                icon: AnIcons.folder,
                axisKey: workDirAxisKey(g.workDir),
                axis:
                    data.groupAxes[g.workDir] ?? const ConvAxis(hasMore: true),
                headCount: _scopeCount(g, showArchived),
                initiallyFolded: i > 0,
              ),
          if (data.recents.rows.isNotEmpty || zeroData)
            axisSection(
              label: labels.recents,
              icon: AnIcons.history,
              axisKey: recentsAxisKey,
              axis: data.recents,
            ),
        ],
      ),
    ],
  );
}
