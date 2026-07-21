import 'dart:async';

import '../../../core/contract/notification.dart';
import '../../../core/contract/page.dart';
import 'notification_repository.dart';
import 'notification_signal.dart';

/// The zero-backend [NotificationRepository] — an in-memory inbox the demo and tests drive without an
/// SSE socket. Rows live in a mutable list (newest-first); mark-read/all mutate readAt in place;
/// [emit] prepends a new row AND pushes a [NotificationSignal] so the badge/list react exactly as they
/// would off the live stream. Mirrors [FixtureChatRepository] / the entity fixture idioms.
///
/// 零后端 NotificationRepository——内存收件箱,demo/测试无需 SSE socket。行在可变表(最新优先);mark-read/all
/// 就地改 readAt;emit 前插新行**并**推 NotificationSignal,使 badge/list 与真流下反应一致。镜像 Chat/实体 fixture。
class FixtureNotificationRepository implements NotificationRepository {
  FixtureNotificationRepository({List<NotificationItem>? seed})
    : _rows = List.of(seed ?? const []);

  final List<NotificationItem> _rows;
  final _signals = StreamController<NotificationSignal>.broadcast();
  final _resync = StreamController<void>.broadcast();

  /// How many times [unreadCount] was read — lets a test prove a non-candidate echo triggers NO refetch.
  /// unreadCount 被读的次数——让测试证明 non-candidate 回声不触发 refetch。
  int unreadCountCalls = 0;

  @override
  Future<Page<NotificationItem>> listNotifications({
    String? cursor,
    int? limit,
  }) async {
    // cursor = next start index (as a string), same idiom as the entity fixture. cursor=下一起点索引串。
    final start = int.tryParse(cursor ?? '') ?? 0;
    final n = limit ?? _rows.length;
    final end = (start + n).clamp(0, _rows.length);
    final slice = _rows.sublist(start.clamp(0, _rows.length), end);
    final more = end < _rows.length;
    return Page(items: slice, nextCursor: more ? '$end' : null, hasMore: more);
  }

  @override
  Future<void> markRead(String id) async {
    final i = _rows.indexWhere((r) => r.id == id);
    // idempotent: re-marking an already-read row is a no-op that still "succeeds". 幂等:重标已读=成功 no-op。
    if (i >= 0 && _rows[i].isUnread) {
      _rows[i] = _rows[i].copyWith(readAt: _stamp);
    }
  }

  @override
  Future<void> markAllRead({MarkWindow window = MarkWindow.all}) async {
    // Only rows inside the window flip — the SAME [MarkWindow.contains] the live backend's WHERE encodes.
    // 只标窗口内行——与真后端 WHERE 同一 MarkWindow.contains 语义。
    for (var i = 0; i < _rows.length; i++) {
      if (_rows[i].isUnread && window.contains(_rows[i].createdAt)) {
        _rows[i] = _rows[i].copyWith(readAt: _stamp);
      }
    }
  }

  @override
  Future<void> markAllUnread({MarkWindow window = MarkWindow.all}) async {
    // Mirror of markAllRead: clear readAt on every read row IN THE WINDOW → unread. copyWith(readAt: null)
    // sets null via freezed's sentinel. markAllRead 的镜像:清窗口内已读行的 readAt(freezed 哨兵设 null)。
    for (var i = 0; i < _rows.length; i++) {
      if (!_rows[i].isUnread && window.contains(_rows[i].createdAt)) {
        _rows[i] = _rows[i].copyWith(readAt: null);
      }
    }
  }

  @override
  Future<int> unreadCount() async {
    unreadCountCalls++;
    return _rows.where((r) => r.isUnread).length;
  }

  /// Add an unread row WITHOUT pushing a signal — models a row that landed while we were disconnected, so
  /// a test can prove a later refetch (candidate tick / resync) picks it up but an ignored echo does not.
  /// 静默加一未读行(不推信号)——模拟断连期落的行,证明后续 refetch 才拾起、被忽略的回声不拾。
  void addSilently(NotificationItem row) => _rows.insert(0, row);

  @override
  Stream<NotificationSignal> signals() => _signals.stream;

  @override
  Stream<void> resync() => _resync.stream;

  // ── demo/test scripting ──

  /// Prepend a new inbox row and push its live signal — the demo scripts a burst of notifications with
  /// this, and tests assert the badge/list react. 前插新行并推信号(demo 脚本化通知、测试断言反应)。
  void emit(NotificationItem row) {
    _rows.insert(0, row);
    _signals.add(
      NotificationSignal(
        type: row.type,
        durable: true,
        inboxCandidate: true,
        payload: row.payload,
      ),
    );
  }

  /// Push a bare reconciliation nudge WITHOUT adding a row — models a frame-only Broadcast echo (the
  /// badge must NOT change on it). 推一条无行的对账 nudge——模拟仅帧回声(徽标不该变)。
  void emitEcho(String type) => _signals.add(
    NotificationSignal(
      type: type,
      durable: true,
      inboxCandidate: !type.startsWith('conversation.'),
    ),
  );

  /// Fire a 410 resync. 触发 410 重同步。
  void emitResync() => _resync.add(null);

  void dispose() {
    _signals.close();
    _resync.close();
  }

  // A fixed non-null stamp for "read" (the fixture doesn't need wall-clock — any past instant reads as
  // read). 固定的"已读"时戳(fixture 不需真钟——任意过去时点即已读)。
  static final DateTime _stamp = DateTime.fromMillisecondsSinceEpoch(0);
}
