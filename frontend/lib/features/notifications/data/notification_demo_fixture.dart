import '../../../core/contract/notification.dart';
import 'notification_fixture.dart';

/// The demo's seeded notification center — a spread across event families, tones, read/unread, and time
/// buckets (today / yesterday / earlier) so `make demo` shows the tray populated and time-grouped with
/// zero backend. Wired via `notificationRepositoryProvider.overrideWithValue(demoNotificationRepository())`.
///
/// demo 的种子通知中心——横跨事件族/tone/已读/时段(今天/昨天/更早),使 make demo 托盘有内容且时间分组、零后端。
FixtureNotificationRepository demoNotificationRepository() {
  final now = DateTime.now();
  NotificationItem n(String id, String type, Map<String, dynamic> payload, Duration ago, {bool read = false}) =>
      NotificationItem(
        id: id,
        type: type,
        payload: payload,
        createdAt: now.subtract(ago),
        readAt: read ? now.subtract(ago) : null,
      );

  // Newest-first, as the backend list returns. 最新优先(同后端 list)。
  return FixtureNotificationRepository(seed: [
    // ── today ──
    n('noti_1', 'workflow.run_failed',
        {'name': 'nightly_sync', 'workflowId': 'wf_1', 'flowrunId': 'fr_9', 'error': 'HandlerError: connection refused (api_host)'},
        const Duration(minutes: 3)),
    n('noti_2', 'workflow.approval_pending', {'name': 'deploy_prod', 'workflowId': 'wf_2', 'flowrunId': 'fr_8', 'nodeId': 'approve'}, const Duration(minutes: 8)),
    n('noti_3', 'handler.crashed', {'name': 'api_host', 'handlerId': 'hd_1'}, const Duration(minutes: 22)),
    n('noti_4', 'function.created', {'name': 'fetch_orders', 'functionId': 'fn_1'}, const Duration(minutes: 41)),
    n('noti_5', 'memory.updated', {'name': 'user-preferences'}, const Duration(hours: 2)),
    n('noti_6', 'agent.edited', {'name': 'triager', 'agentId': 'ag_1'}, const Duration(hours: 4), read: true),
    // ── yesterday ──
    n('noti_7', 'workflow.attention_changed', {'name': 'etl_pipe', 'workflowId': 'wf_3', 'needsAttention': true, 'attentionReason': 'run failed at transform'}, const Duration(hours: 27)),
    n('noti_8', 'mcp.installed', {'name': 'context7'}, const Duration(hours: 30), read: true),
    n('noti_9', 'relation.dependency_broken',
        {'deletedKind': 'function', 'deletedId': 'fn_x', 'dependents': [{'kind': 'agent', 'id': 'ag_1', 'name': 'triager'}, {'kind': 'workflow', 'id': 'wf_3', 'name': 'etl_pipe'}]},
        const Duration(hours: 33), read: true),
    // ── earlier ──
    n('noti_10', 'workflow.deleted', {'name': 'legacy_report', 'workflowId': 'wf_old'}, const Duration(days: 3), read: true),
    n('noti_11', 'skill.created', {'name': 'code-review'}, const Duration(days: 4), read: true),
    n('noti_12', 'sandbox.env_status_changed', {'status': 'ready', 'envId': 'env_1', 'ownerKind': 'function', 'ownerId': 'fn_1'}, const Duration(days: 5), read: true),
  ]);
}

/// One durable failure row used by the fixture's signal-path test. The interactive demo itself uses the
/// ordered [demoTopBandShowcase] below, so it can show operation copies and an approval block without
/// depending on a person's saved notification settings. 一条 durable 失败行供 fixture 信号链测试使用;实机
/// demo 改由下方有序顶带脚本驱动,故能稳定演示操作副本与审批块,不受个人提醒设置影响。
NotificationItem demoFailureNotice() => NotificationItem(
  id: 'noti_live',
  type: 'workflow.run_failed',
  payload: const {
    'name': 'invoice_sync',
    'workflowId': 'wf_invoice',
    'flowrunId': 'fr_live',
    'error': 'HandlerError: charge() exceeded 30s',
  },
  createdAt: DateTime.now(),
);
