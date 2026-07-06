import '../../../core/contract/notification.dart';
import '../../../core/contract/page.dart';
import '../../../core/net/api_client.dart';
import '../../../core/sse/sse_gateway.dart';
import 'notification_signal.dart';

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

  /// Mark every unread row read (`POST :mark-all-read` → 204, always idempotent). 全部已读(204 幂等)。
  Future<void> markAllRead();

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
  Future<void> markAllRead() =>
      _api.postNoContent('/api/v1/notifications:mark-all-read');

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
