import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../ui/ui.dart';
import '../../i18n/strings.g.dart';
import 'run_nav.dart';

// Run provenance + status words — upstreamed from chat's dossier furniture (WRK-069 S0) so the
// Scheduler's run flagship head and chat's cards speak the SAME origin line and the SAME status
// vocabulary. Words live in the core-visible `run.*` namespace (批6a). 出处行与执行状态词——自 chat
// 卷宗上收(S0),Scheduler 旗舰头与 chat 卡同一条出处、同一套状态词;词表在 core 可见的 run.*。

/// The ok/failed/timeout/cancelled execution status → its word — the ONE map (B-074: the dossier head,
/// its receipt and exec's invoke stat bar carried three verbatim copies). 执行状态词唯一映射。
String runStatusWord(Translations t, String status) => switch (status) {
      'ok' => t.run.runCompleted,
      'failed' => t.run.failed,
      'timeout' => t.run.agentTimeout,
      'cancelled' => t.run.runCancelled,
      _ => status,
    };

/// The flowrun/node LIFECYCLE status → its word (running/completed/failed/parked/cancelled) — a
/// DIFFERENT closed set from [runStatusWord]'s exec domain (ok/timeout), which would leak the raw
/// wire word for `completed`/`running`/`parked` (复审 0717-晚: the matrix tooltips spoke English in
/// zh-CN). `parked` reuses the node ledger's wait word — same surface, same vocabulary.
/// flowrun/节点**生命周期**状态词——与 runStatusWord 的执行域(ok/timeout)是两个封闭集,错用会把
/// completed/running/parked 的线缆词漏成英文;parked 复用节点台账的「等待」同词。
String flowrunStatusWord(Translations t, String status) => switch (status) {
      'running' => t.run.runStatusRunning,
      'completed' => t.run.runCompleted,
      'failed' => t.run.failed,
      'parked' => t.run.nodeWait,
      'cancelled' => t.run.runCancelled,
      _ => status,
    };

/// A run's provenance line — WHERE it came from. Navigable coordinates (conversation → /chat, trigger →
/// its panel) are ref pills; non-panel coordinates (message / firing / node#iteration) are mono
/// copy-badges (they have no deep-link target, NEVER a dead pill). ProvenanceLine 出处行。
class ProvenanceLine extends StatelessWidget {
  const ProvenanceLine({
    this.conversationId,
    this.messageId,
    this.flowrunId,
    this.triggerId,
    this.triggerName,
    this.firingId,
    this.nodeId,
    this.iteration,
    super.key,
  });

  final String? conversationId;
  final String? messageId;
  final String? flowrunId;
  final String? triggerId;

  /// The trigger's HUMAN name when the caller has it resolved (需求⑤ id 人话化) — the pill then
  /// speaks «trigger 每日 09:00» instead of a mono id (which drops to the tooltip).
  /// 调用方解出的 trigger 真名——药丸念「trigger 每日 09:00」而非 mono id(id 降 tooltip)。
  final String? triggerName;
  final String? firingId;
  final String? nodeId;
  final int? iteration;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final items = <Widget>[
      if (conversationId != null && conversationId!.isNotEmpty)
        toolNavPill(context, kind: 'conversation', label: '${t.run.provConversation} ${truncate(conversationId!, AnTrunc.id)}', id: conversationId),
      if (triggerId != null && triggerId!.isNotEmpty)
        toolNavPill(context,
            kind: 'trigger',
            label:
                '${t.run.provTrigger} ${triggerName != null && triggerName!.isNotEmpty ? truncate(triggerName!, AnTrunc.word) : truncate(triggerId!, AnTrunc.id)}',
            id: triggerId),
      // Non-navigable coordinates become COPY chips (批5 A-047 关联 A-037 — the bare grey text
      // lied about being «mono copy-badges»; flowrun has no panel entry, cockpit needs workflowId).
      // 非导航坐标改真复制芯片(旧裸灰字谎称 mono copy-badges);截断走族档、copy 保全量。
      if (flowrunId != null && flowrunId!.isNotEmpty)
        AnChip('${t.run.provFlowrun} ${truncate(flowrunId!, AnTrunc.id)}',
            look: AnChipLook.outlined, mono: true, copyValue: flowrunId!),
      if (messageId != null && messageId!.isNotEmpty)
        AnChip('${t.run.provMessage} ${truncate(messageId!, AnTrunc.id)}',
            look: AnChipLook.outlined, mono: true, copyValue: messageId!),
      if (firingId != null && firingId!.isNotEmpty)
        AnChip('${t.run.provFiring} ${truncate(firingId!, AnTrunc.id)}',
            look: AnChipLook.outlined, mono: true, copyValue: firingId!),
      if (nodeId != null && nodeId!.isNotEmpty)
        AnChip('${t.run.provNode} $nodeId${(iteration ?? 0) > 0 ? '#$iteration' : ''}',
            look: AnChipLook.outlined, mono: true, copyValue: nodeId!),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: AnGap.inline, runSpacing: AnGap.stackTight, crossAxisAlignment: WrapCrossAlignment.center, children: items);
  }
}
