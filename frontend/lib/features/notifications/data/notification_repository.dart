import '../../../core/contract/notification.dart';
import '../../../core/contract/page.dart';
import '../../../core/net/api_client.dart';
import '../../../core/sse/sse_gateway.dart';
import 'notification_signal.dart';

/// A half-open `[after, before)` time window (UTC bounds; a null bound = unbounded) that narrows a
/// bulk mark-all to a slice of the ledger. [all] (both bounds null) is the whole ledger — the
/// backward-compatible default a bodyless `:mark-all-*` call gets. The tray derives one per time-group so
/// clearing «今天» leaves the «更早» backlog untouched, and the SAME [contains] membership is the single
/// source both the live serialization and the fixture / optimistic-patch use — window semantics live in ONE
/// place, never re-derived.
///
/// 半开时间窗 `[after, before)`（界皆 UTC，null 界=不设界），把批量 mark-all 收到账的一片。all（两界皆 null）=
/// 整本账，即无 body 调用的向后兼容默认。托盘按时间组各derive 一个（清「今天」不动「更早」），且同一 [contains]
/// 成员判定是 live 序列化与 fixture / 乐观补丁**共用的唯一**窗口语义源——绝不两处各算。
class MarkWindow {
  const MarkWindow({this.after, this.before});
  final DateTime? after;
  final DateTime? before;

  /// The whole ledger — no bounds. 整本账、不设界。
  static const all = MarkWindow();

  /// Both bounds unbounded → the whole ledger (a bodyless call). 两界皆无=整本账。
  bool get isAll => after == null && before == null;

  /// Half-open membership `after <= t < before` (a null bound doesn't constrain that side), compared in UTC.
  /// 半开成员判定 `after <= t < before`（null 界不约束该侧），按 UTC 比较。
  bool contains(DateTime t) {
    final u = t.toUtc();
    if (after != null && u.isBefore(after!)) return false;
    if (before != null && !u.isBefore(before!)) return false;
    return true;
  }

  /// The OPTIONAL request body for the mark-all endpoints — null when unbounded (an empty body =
  /// whole ledger, backward compatible), else `{after?, before?}` as RFC3339 UTC. 端点可选 body(不设界=null)。
  Map<String, dynamic>? toBody() {
    if (isAll) return null;
    return {
      if (after != null) 'after': after!.toUtc().toIso8601String(),
      if (before != null) 'before': before!.toUtc().toIso8601String(),
    };
  }
}

/// THE seam for the Notifications feature's data access — the tray list, the mark-read actions, the
/// unread badge, and the realtime nudge all pass through here, so the whole feature swaps backends at one
/// [FixtureNotificationRepository] override (zero-backend demo / tests), exactly as Chat + Entities do.
///
/// Notifications feature 数据访问的唯一缝——托盘列表 / mark-read 动作 / 未读徽标 / 实时 nudge 全过此,故整
/// feature 单点 override 切后端(零后端 demo / 测试),与 Chat + Entities 同款。
abstract interface class NotificationRepository {
  /// One keyset page of the notification center, newest-first (`GET /notifications`, no filters — the
  /// backend list has none). 通知中心一页 keyset,最新优先(无过滤,后端 list 无过滤参数)。
  Future<Page<NotificationItem>> listNotifications({String? cursor, int? limit});

  /// Mark one row read (`POST /{id}:mark-read` → 204, idempotent — re-marking an already-read row still
  /// 204s). No SSE echo, so the caller updates its own state. 单条已读(204 幂等,无 SSE 回声)。
  Future<void> markRead(String id);

  /// Mark every unread row within [window] read (`POST :mark-all-read` → 204, always idempotent). The
  /// window scopes a time-group's action to just that group's rows; [MarkWindow.all] (the default) marks the
  /// whole ledger (a bodyless call — backward compatible). 窗口内全部已读(默认=整本账、向后兼容;204 幂等)。
  Future<void> markAllRead({MarkWindow window});

  /// Mark every read row within [window] UNREAD — the mirror of [markAllRead] (`POST :mark-all-unread` → 204,
  /// no SSE echo, always idempotent). The post-state count isn't a known constant (the ledger's total may
  /// exceed the loaded window), so the caller refetches the authoritative [unreadCount] rather than
  /// optimistically zeroing. 窗口内全部未读——markAllRead 的镜像;因未读数非已知常量,调用方重取权威 unreadCount 对账。
  Future<void> markAllUnread({MarkWindow window});

  /// The authoritative unread count (`GET /unread-count` → `{data:{unread:n}}`, a live COUNT). This is
  /// THE source of truth for the badge — mark-read has no SSE echo, so the badge reconciles by re-reading
  /// this, never by trusting a stream frame. 权威未读数(实时 COUNT);徽标真相,靠重读它对账而非信帧。
  Future<int> unreadCount();

  /// The realtime nudge off the notifications SSE stream — a tick per frame saying "reconcile" (see
  /// [NotificationSignal]: a frame is never trusted to mean +1; the badge/list refetch the authoritative
  /// REST state). Live projects the gateway; the fixture scripts it (zero-backend demo). 实时 nudge。
  Stream<NotificationSignal> signals();

  /// The notifications-stream 410 resync signal: the replay ring evicted past our cursor — refetch the
  /// authoritative count + first page. notifications 流 410 重同步:重拉权威计数+首页。
  Stream<void> resync();
}

/// The production repository over the Phase-4.0 pipeline (ApiClient + SseGateway). Holds no state; each
/// method is a thin envelope-decode. Realtime is a projection over the gateway's raw notifications feed.
///
/// 生产 repository(接 Phase 4.0 管道)。无状态;每方法是薄信封解码。实时=网关原始 notifications feed 的投影。
class LiveNotificationRepository implements NotificationRepository {
  LiveNotificationRepository({required ApiClient api, SseGateway? sse})
      : _api = api,
        _sse = sse;

  final ApiClient _api;
  final SseGateway? _sse;

  @override
  Future<Page<NotificationItem>> listNotifications({String? cursor, int? limit}) =>
      _api.getPage('/api/v1/notifications', NotificationItem.fromJson,
          query: {'cursor': ?cursor, 'limit': ?limit});

  @override
  Future<void> markRead(String id) =>
      _api.postNoContent('/api/v1/notifications/$id:mark-read');

  @override
  Future<void> markAllRead({MarkWindow window = MarkWindow.all}) =>
      _api.postNoContent('/api/v1/notifications:mark-all-read', body: window.toBody());

  @override
  Future<void> markAllUnread({MarkWindow window = MarkWindow.all}) =>
      _api.postNoContent('/api/v1/notifications:mark-all-unread', body: window.toBody());

  @override
  Future<int> unreadCount() async {
    final data = await _api.getData('/api/v1/notifications/unread-count');
    return (data['unread'] as num?)?.toInt() ?? 0;
  }

  @override
  Stream<NotificationSignal> signals() {
    final sse = _sse;
    if (sse == null) return const Stream.empty();
    // The notifications stream is low-frequency and single-scope, so a `.where` over the raw feed is
    // correct here (mirrors LiveChatRepository.lifecycleSignals) — NOT the rebuild-storm demux guards.
    // notifications 低频、单 scope,故对原始 feed `.where` 在此正确(非 demux 所防的高频风暴)。
    return sse
        .rawStream(StreamName.notifications)
        .map(NotificationSignal.fromEnvelope)
        .where((s) => s != null)
        .cast<NotificationSignal>();
  }

  @override
  Stream<void> resync() => _sse?.resync(StreamName.notifications) ?? const Stream.empty();
}
