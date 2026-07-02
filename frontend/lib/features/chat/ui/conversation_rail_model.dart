import '../../../core/contract/conversation.dart';
import '../../../core/model/sidebar_model.dart';
import '../../../core/model/status_state.dart';
import '../../../core/ui/icons.dart';

/// The lead status dot for a conversation rail row — or null for a plain active thread (no dot, the
/// common case). Precedence, highest first:
///   generating (blue, the only animated/breathing dot) > awaiting input (amber "needs you") >
///   unread (green "answered while you were away") > archived (gray marker) > none.
/// The first three are the live activity signals (mutually exclusive in practice — a thread is
/// generating, or blocked on you, or has a fresh reply); the archived gray dot is a static "this is
/// archived" marker that only ever shows when the rail is set to include archived threads.
///
/// 会话 rail 行的前导状态点——普通活跃线程返 null(无点,常态)。优先级(高→低):生成中(蓝、唯一呼吸)>等你输入
/// (琥珀「等你」)>未读(绿「你不在时答完了」)>已归档(灰标记)>无。前三是活态信号(实际互斥);归档灰点是静态
/// 「这是归档」标记,仅当 rail 设为含归档时才出现。
AnStatus? conversationDot(Conversation c) {
  if (c.isGenerating) return AnStatus.run;
  if (c.awaitingInput) return AnStatus.wait;
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
/// is the per-row timestamp; it does NOT drive grouping (the rail groups only Pinned vs Recents).
///
/// 行的相对时间(刚刚/N 分钟/N 小时/昨天/N 天/更老用数字日期)。本地日历日;>7 天 → `年/月/日`(纯数字)。仅是行时间戳,
/// 不参与分组(rail 只分 置顶 / 最近 两组)。
String conversationTimeLabel(DateTime atUtc, DateTime now, ConvTimeStrings s) {
  final at = atUtc.toLocal();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(at.year, at.month, at.day))
      .inDays;
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

/// The i18n labels the rail model needs — New/filter chrome, the two section labels (Pinned / Recents),
/// and the time strings. Bundled so the pure builder takes one struct (mirrors entities' RailLabels).
///
/// rail 模型需的 i18n 标签——New/过滤 chrome、两个分节标签(置顶 / 最近)、时间串。打包成一个 struct 喂纯 builder(镜像 entities RailLabels)。
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

/// Project the loaded conversations onto a [SidebarModel] for [AnSidebarList], FULLY mirroring the
/// entities rail: ONE [SidebarGroup] holding two icon'd, collapsible [SidebarType] sections — Pinned
/// (pin icon) and Recents (history icon) — each with a count + its rows. There is exactly ONE head code
/// path (the entities AnRow type head: icon lead, count right-aligned, rows indented), no bespoke flush
/// head and no time buckets. Each row carries {id, title, relative-time meta, lead dot}. A section is
/// emitted only when it has rows (no empty Pinned). Single-domain: NO client-side sort (the server
/// orders via ConvSort → ?sort=), so rows keep arrival order within each section.
///
/// 把已加载对话投影成 SidebarModel 喂 AnSidebarList,**完整镜像 entities rail**:一个 SidebarGroup 持两个带 icon 的可折叠
/// SidebarType——置顶(pin 图标)与 最近(history 图标)——各带计数 + 其行。**只有一条头路径**(entities 的 AnRow 类型头:图标 lead、
/// 计数右对齐、行缩进),无自造 flush 头、无时间桶。每行={id, 标题, 相对时间 meta, 前导点}。分节有行才出(无空置顶组)。单域:无客户端排序。
SidebarModel buildConversationRailModel(
  List<Conversation> rows, {
  required DateTime now,
  required ConvRailLabels labels,
  bool showCount = true,
  bool showTime = true,
  bool hasMore = false,
  bool loadingMore = false,
}) {
  // showTime/showCount are the ⚙ "show time" / "show counts" toggles: a null meta/count renders nothing
  // (AnRow omits the trailing time; the section head omits the count). showTime/showCount = ⚙ 开关:meta/count 为 null 则不渲。
  // An un-titled thread (created, auto-title pending or failed) falls back to the same "New chat" word
  // the head uses — a rail row must never render blank. 未命名线程回落「New chat」(与头一致),行绝不空白。
  SidebarRow toRow(Conversation c) => SidebarRow(
        id: c.id,
        label: c.title.trim().isEmpty ? labels.newLabel : c.title,
        meta: showTime ? conversationTimeLabel(c.lastMessageAt, now, labels.time) : null,
        dot: conversationDot(c),
      );

  final pinned = [for (final c in rows) if (c.pinned) toRow(c)];
  final recents = [for (final c in rows) if (!c.pinned) toRow(c)];
  int? count(int n) => showCount ? n : null;

  return SidebarModel(
    newLabel: labels.newLabel,
    filterPlaceholder: labels.filter,
    groups: [
      SidebarGroup(types: [
        if (pinned.isNotEmpty)
          SidebarType(label: labels.pinned, icon: AnIcons.pin, count: count(pinned.length), rows: pinned),
        if (recents.isNotEmpty)
          SidebarType(
            label: labels.recents,
            icon: AnIcons.history,
            count: count(recents.length),
            pageKey: 'recents', // the single paginated axis (pinned all land on page one) 唯一分页轴
            hasMore: hasMore,
            loadingMore: loadingMore,
            rows: recents,
          ),
      ]),
    ],
  );
}
