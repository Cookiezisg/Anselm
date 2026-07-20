import '../core/model/status_state.dart';
import '../core/notice/notice_center.dart';
import '../core/ui/icons.dart';
import '../i18n/strings.g.dart';

/// One absolute beat in the demo-only top-band tour. The script is deliberately a small finite sequence:
/// it gives a person time to read the first three messages, then holds an approval while three later
/// messages make the two-cue + `+N` state observable. demo 专用顶带巡演的一拍:前 3 条可逐条读,随后审批
/// 留在台上,让后 3 条显出两 cue + `+N`。
class DemoNoticeBeat {
  const DemoNoticeBeat({
    required this.at,
    required this.message,
    required this.priority,
  });

  final Duration at;
  final NoticeMessage message;
  final NoticePriority priority;
}

/// The `make demo` top-band tour. It pushes presentation copies straight to [NoticeCenter], rather than
/// emitting durable fixture rows, so a user's persisted event filters cannot make the showcase appear
/// broken or duplicate it. The normal app still exercises durable-event routing through the dispatcher.
/// `make demo` 的顶带巡演:直接送展示副本到 NoticeCenter,避免用户持久化事件筛选让演示漏项或重复;真 app
/// 的 durable 事件分发仍原样走 dispatcher。
List<DemoNoticeBeat> demoTopBandShowcase(Translations t) {
  String event(String workflow, String verb) =>
      '${t.ref.workflow} ${t.notifications.nameQuoted(name: workflow)} $verb';
  String operation(String workflow, String copy) =>
      '${t.notifications.nameQuoted(name: workflow)} $copy';

  return <DemoNoticeBeat>[
    DemoNoticeBeat(
      at: const Duration(seconds: 2),
      message: NoticeMessage(
        text: operation('invoice_sync', t.chat.stage.run.done),
        icon: AnIcons.check,
        tone: AnTone.ok,
        origin: NoticeOrigin.operation,
      ),
      priority: NoticePriority.priority,
    ),
    DemoNoticeBeat(
      at: const Duration(seconds: 6),
      message: NoticeMessage(
        text: event('inventory_backfill', t.notifications.verb.runFailed),
        icon: AnIcons.workflow,
        tone: AnTone.danger,
        location: '/entities/workflow/wf_digest',
        origin: NoticeOrigin.event,
      ),
      priority: NoticePriority.normal,
    ),
    DemoNoticeBeat(
      at: const Duration(seconds: 10),
      message: NoticeMessage(
        text: event('daily_digest', t.notifications.verb.needsAttention),
        icon: AnIcons.workflow,
        tone: AnTone.warn,
        location: '/entities/workflow/wf_digest',
        origin: NoticeOrigin.event,
      ),
      priority: NoticePriority.normal,
    ),
    DemoNoticeBeat(
      at: const Duration(seconds: 14),
      message: NoticeMessage(
        text: event('deploy_prod', t.notifications.verb.waitingApproval),
        icon: AnIcons.approval,
        tone: AnTone.warn,
        kind: NoticeKind.approval,
        origin: NoticeOrigin.event,
        title: 'approve_deploy',
        flowrunId: 'flr_park',
        nodeId: 'approve_deploy',
      ),
      priority: NoticePriority.priority,
    ),
    DemoNoticeBeat(
      at: const Duration(seconds: 17),
      message: NoticeMessage(
        text: operation('billing_export', t.chat.stage.run.queued),
        icon: AnIcons.refresh,
        tone: AnTone.accent,
        origin: NoticeOrigin.operation,
      ),
      priority: NoticePriority.priority,
    ),
    DemoNoticeBeat(
      at: const Duration(seconds: 20),
      message: NoticeMessage(
        text: event('report_delivery', t.notifications.verb.runFailed),
        icon: AnIcons.workflow,
        tone: AnTone.danger,
        location: '/entities/workflow/wf_digest',
        origin: NoticeOrigin.event,
      ),
      priority: NoticePriority.normal,
    ),
    DemoNoticeBeat(
      at: const Duration(seconds: 23),
      message: NoticeMessage(
        text: operation('workspace_backup', t.chat.stage.run.done),
        icon: AnIcons.check,
        tone: AnTone.ok,
        origin: NoticeOrigin.operation,
      ),
      priority: NoticePriority.priority,
    ),
  ];
}
