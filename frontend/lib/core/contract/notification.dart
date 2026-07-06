import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification.freezed.dart';
part 'notification.g.dart';

/// One notification-center row — the backend projection of `notification.Notification` as the tray
/// lists it on the wire (camelCase ↔ json_serializable; mirrors `references/backend`). The backend
/// deliberately produces NO human-readable string: [type] is the open `<domain>.<action>` vocab
/// (`"workflow.run_failed"`, `"function.created"`) and [payload] is the producer-defined detail the
/// frontend renders through a type→template map. [readAt] null ⟺ UNREAD.
///
/// Only the Emit tier persists a row (see events.md ⊞/⤳): the high-frequency Broadcast reconciliation
/// echoes (conversation.*, tree refreshes) are frame-only and NEVER appear here — the notification
/// center is the curated inbox, not the full event bus.
///
/// 一条通知中心行——后端 `notification.Notification` 的投影(camelCase ↔ json_serializable;镜像
/// references/backend)。后端刻意不产人类文案:type 是开放 `<域>.<动作>` 词表、payload 是 producer 定义
/// 的细节(前端经 type→模板 映射渲染)。readAt null ⟺ 未读。只有 Emit 档落行——高频 Broadcast 对账回声
/// (conversation.* / 树刷新)仅帧、绝不现于此:通知中心是策展收件箱、非全事件总线。
@freezed
abstract class NotificationItem with _$NotificationItem {
  const NotificationItem._();

  const factory NotificationItem({
    required String id,
    required String type,
    @Default(<String, dynamic>{}) Map<String, dynamic> payload,
    DateTime? readAt,
    required DateTime createdAt,
  }) = _NotificationItem;

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(json);

  /// readAt absent = unread (the backend stamps read_at on mark-read). readAt 缺席=未读。
  bool get isUnread => readAt == null;

  /// The `<domain>` half of [type] (`"workflow"` from `"workflow.run_failed"`), or the whole string if
  /// there is no dot — the family a tray row groups/icons by. type 的 `<域>` 段(无点则整串)。
  String get domain {
    final dot = type.indexOf('.');
    return dot <= 0 ? type : type.substring(0, dot);
  }

  /// The `<action>` half of [type] (`"run_failed"`), or "" if there is no dot. type 的 `<动作>` 段。
  String get action {
    final dot = type.indexOf('.');
    return dot < 0 || dot + 1 >= type.length ? '' : type.substring(dot + 1);
  }
}
