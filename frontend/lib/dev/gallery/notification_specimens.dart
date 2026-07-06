import 'package:flutter/widgets.dart';

import '../../core/contract/notification.dart';
import '../../features/notifications/ui/notification_row.dart';
import 'specimen.dart';

// Notification-center rows (WRK-058 N2) — one row per event family + tone, plus read/hover/stress. The
// gallery locks the row look before the tray assembles it. dev-only, i18n-exempt fixtures.
// 通知行(N2)——逐事件族×tone + 已读/hover/压力。gallery 先锁行长相再组装托盘。

// A fixed clock so relative times are deterministic in the gallery + matrix snapshots. 固定时钟。
final DateTime _now = DateTime.utc(2026, 7, 6, 12, 0);

NotificationItem _n(
  String type, {
  Map<String, dynamic> payload = const {},
  int minutesAgo = 5,
  bool read = false,
}) =>
    NotificationItem(
      id: 'noti_${type.hashCode}',
      type: type,
      payload: payload,
      createdAt: _now.subtract(Duration(minutes: minutesAgo)),
      readAt: read ? _now : null,
    );

Widget _row(NotificationItem n) => NotificationRow(item: n, now: _now, onTap: () {}, onMarkRead: () {});

final List<GallerySpecimen> notificationRowSpecimens = [
  // ── compositional lifecycle (semi) ──
  GallerySpecimen('function.created', (_) => _row(_n('function.created', payload: {'name': 'fetch_orders'})), span: true),
  GallerySpecimen('agent.edited', (_) => _row(_n('agent.edited', payload: {'name': 'triager', 'version': 3}, minutesAgo: 42)), span: true),
  GallerySpecimen('workflow.deleted', (_) => _row(_n('workflow.deleted', payload: {'name': 'daily_report'}, minutesAgo: 180)), span: true),
  GallerySpecimen('mcp.installed', (_) => _row(_n('mcp.installed', payload: {'name': 'context7'})), span: true),
  GallerySpecimen('memory.updated (AI wrote)', (_) => _row(_n('memory.updated', payload: {'name': 'user-preferences'})), span: true),
  GallerySpecimen('document.deleted (path as name)', (_) => _row(_n('document.deleted', payload: {'path': 'specs/api.md'})), span: true),
  GallerySpecimen('handler.config_updated', (_) => _row(_n('handler.config_updated', payload: {'name': 'stripe_gateway'})), span: true),
  // ── important (danger / warn) ──
  GallerySpecimen('workflow.run_failed (danger + detail)',
      (_) => _row(_n('workflow.run_failed', payload: {'name': 'nightly_sync', 'error': 'HandlerError: connection refused (api_host)'})), span: true),
  GallerySpecimen('handler.crashed (danger)', (_) => _row(_n('handler.crashed', payload: {'name': 'api_host'}, minutesAgo: 1)), span: true),
  GallerySpecimen('workflow.approval_pending (warn)', (_) => _row(_n('workflow.approval_pending', payload: {'name': 'deploy_prod'}, minutesAgo: 2)), span: true),
  GallerySpecimen('workflow.attention_changed · needs (warn)',
      (_) => _row(_n('workflow.attention_changed', payload: {'name': 'etl_pipe', 'needsAttention': true, 'attentionReason': 'run failed at transform'})), span: true),
  GallerySpecimen('workflow.attention_changed · recovered', (_) => _row(_n('workflow.attention_changed', payload: {'name': 'etl_pipe', 'needsAttention': false})), span: true),
  GallerySpecimen('sandbox env failed (danger)', (_) => _row(_n('sandbox.env_status_changed', payload: {'status': 'failed', 'errorMsg': 'pip: no matching distribution for numpy==99'})), span: true),
  GallerySpecimen('relation.dependency_broken (warn + names)',
      (_) => _row(_n('relation.dependency_broken', payload: {'deletedKind': 'function', 'dependents': [{'kind': 'agent', 'name': 'triager'}, {'kind': 'workflow', 'name': 'pipeline'}]})), span: true),
  GallerySpecimen('mcp.reconnected · failed', (_) => _row(_n('mcp.reconnected', payload: {'name': 'acme', 'status': 'failed'})), span: true),
  // ── read + fallback + stress ──
  GallerySpecimen('READ (grayed, stays in list)', (_) => NotificationRow(item: _n('function.created', payload: {'name': 'fetch_orders'}, read: true), now: _now, onTap: () {}), span: true, stress: true),
  GallerySpecimen('unknown type → generic fallback', (_) => _row(_n('quasar.collapsed', payload: {'foo': 'bar'})), span: true, stress: true),
  GallerySpecimen('no name (nameless honest)', (_) => _row(_n('agent.created')), span: true, stress: true),
  GallerySpecimen('overlong name + injection',
      (_) => _row(_n('function.created', payload: {'name': 'x_' * 60 + '「盒」<script>alert(1)</script>'})), span: true, stress: true),
];
