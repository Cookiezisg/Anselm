import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What shape a band notice takes: a one-line PILL (the default event capsule) or the APPROVAL BLOCK
/// (灵动岛来电卡式 — expands bar→block with in-place Approve/Reject, never auto-dismisses).
/// 顶带通知的形态:单行药丸(默认)或审批块(条→块,就地批/拒,不自动收)。
enum CapsuleKind { pill, approval }

/// One queued chrome-band notice. [key] doubles as the widget key (a fresh capsule per notice) and
/// the dedup identity upstream. 一条排队的顶带通知;key 兼 widget key 与上游去重身份。
@immutable
class CapsuleNotice {
  const CapsuleNotice({
    required this.key,
    required this.text,
    this.icon,
    this.danger = true,
    this.location,
    this.kind = CapsuleKind.pill,
    this.title,
    this.flowrunId,
    this.nodeId,
  });

  final String key;
  final String text;
  final IconData? icon;
  final bool danger;

  /// Deep-link location (router path), null = not navigable. 深链路径,null=不可导航。
  final String? location;

  final CapsuleKind kind;

  /// The bare display name for the approval block's title bar (the pill uses [text], a full sentence).
  /// 审批块标题条的纯名字(药丸用整句 text)。
  final String? title;

  /// Approval-block coordinates (the `approval_pending` payload carries both — exact parked-node
  /// addressing, no fuzzy matching). 审批块坐标(payload 自带,精确定位停车节点)。
  final String? flowrunId;
  final String? nodeId;
}

/// The band-capsule queue — notices display ONE AT A TIME in arrival order (the dispatcher pushes,
/// the host shows `first` and pops on dismiss/tap). An APPROVAL cuts the line to the front (it awaits
/// a human decision — highest priority — and never auto-dismisses; queued pills resume after it is
/// decided/closed). Bounded so an event storm can't build an unbounded backlog: beyond [_cap] the
/// OLDEST undisplayed entries drop — the tray/bell keep every row, the capsule is just the messenger.
/// 顶带胶囊队列:一次一条到达序;**审批插队到头**(等人决策,最高优先,不自动收;其后药丸待其了结递补)。
/// 有界防风暴(超上限丢最旧未显示条——托盘/铃保有全量,胶囊只是信使)。
class NoticeCapsuleQueue extends Notifier<List<CapsuleNotice>> {
  static const int _cap = 5;

  @override
  List<CapsuleNotice> build() => const [];

  void push(CapsuleNotice n) {
    List<CapsuleNotice> next;
    if (n.kind == CapsuleKind.approval && state.isNotEmpty) {
      // Cut the line, but never displace a SHOWING approval (first-come decisions stay visible).
      // 插队,但不顶掉正在显示的审批(先到的决策保持在场)。
      final head = state.first;
      next = head.kind == CapsuleKind.approval
          ? [head, n, ...state.sublist(1)]
          : [n, ...state];
    } else {
      next = [...state, n];
    }
    // Keep the currently-showing head; trim overflow from just behind it. 保住在显头条,从其后裁溢出。
    if (next.length > _cap) {
      next.removeRange(1, next.length - _cap + 1);
    }
    state = next;
  }

  /// Remove the currently-showing notice (dismiss/tap teardown). 移除在显条(收场)。
  void pop() {
    if (state.isEmpty) return;
    state = state.sublist(1);
  }
}

final noticeCapsuleProvider =
    NotifierProvider<NoticeCapsuleQueue, List<CapsuleNotice>>(NoticeCapsuleQueue.new);
