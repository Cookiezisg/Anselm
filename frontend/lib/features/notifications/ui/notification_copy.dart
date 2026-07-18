import 'package:flutter/widgets.dart';

import '../../../core/contract/notification.dart';
import '../../../core/model/status_state.dart';
import '../../../core/router/panel_registry.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';

/// The human-readable projection of ONE [NotificationItem] — the backend produces no copy (just a
/// `<domain>.<action>` type + a payload), so the frontend owns the type→sentence map. A line reads
/// `{lead}「{name}」{trail}` (e.g. "Function 「fetch_data」 created"): [lead] is the muted entity-kind
/// label, [name] the emphasized object (w400), [trail] the muted verb phrase. [tone] drives the icon +
/// (for the important 7) an accent; [detail] is an optional muted second line (an error / a count).
///
/// 一条通知的人类可读投影——后端不产文案(只给 type + payload),故 type→句子 映射归前端。一行读作
/// `{lead}「{name}」{trail}`(如「函数『fetch_data』已创建」):lead=灰实体类标签、name=强调宾语(w400)、
/// trail=灰动词。tone 驱动图标 +(重要 7 类)accent;detail=可选灰第二行(错误/计数)。
@immutable
class NotificationLine {
  const NotificationLine({
    required this.icon,
    this.lead,
    this.name,
    required this.trail,
    this.tone = AnTone.none,
    this.detail,
  });

  final IconData icon;
  final String? lead;
  final String? name;
  final String trail;

  /// The visual weight — none (most lifecycle), warn (attention / approval-pending / dependency-broken),
  /// danger (failures / crashes). The shared semantic [AnTone] (批7 B-041 — the private enum was a strict
  /// subset). 通知视觉权重=公共 AnTone(私有枚举是真子集)。
  final AnTone tone;
  final String? detail;
}

/// Project a notification row into a rendered line. Never throws — every payload key is read
/// defensively and an unrecognized type degrades to a generic "New activity" line (open vocab +
/// unknown fallback, the contract rule). 投影成一行;绝不抛,未知 type 降级为通用行。
NotificationLine notificationLine(NotificationItem n, Translations t) {
  final nt = t.notifications;
  final payload = n.payload;
  final domain = n.domain;
  final action = n.action;

  // The object name: most entities carry `name` (N2a enrichment); document uses its path; sandbox has
  // no name (env). Empty → an explicit "(unnamed)" so a nameless row is never a dangling label.
  // 宾语名:多数实体带 name;document 用 path;sandbox 无名。空→显式(未命名)。
  String? nameOf() {
    final raw = (payload['name'] as String?) ?? (payload['path'] as String?);
    if (raw != null && raw.isNotEmpty) return raw;
    return null;
  }

  final kindLead = _kindLabel(domain, t);

  // ── the important 7 + a few specials (bespoke tone / trail / detail) ──
  switch (n.type) {
    case 'workflow.run_failed':
      return NotificationLine(
        icon: AnIcons.error, lead: kindLead, name: nameOf(), trail: nt.verb.runFailed,
        tone: AnTone.danger, detail: (payload['error'] as String?)?.trim().nullIfEmpty);
    case 'handler.crashed':
      return NotificationLine(
        icon: AnIcons.error, lead: kindLead, name: nameOf(), trail: nt.verb.crashed,
        tone: AnTone.danger);
    case 'workflow.approval_pending':
      return NotificationLine(
        icon: AnIcons.inbox, lead: kindLead, name: nameOf(), trail: nt.verb.waitingApproval,
        tone: AnTone.warn);
    case 'relation.dependency_broken':
      final deps = (payload['dependents'] as List?) ?? const [];
      final deletedKind = payload['deletedKind'] as String?;
      final deletedId = (payload['deletedId'] as String?)?.nullIfEmpty;
      // A STANDARD subject clause (0719 «句式归队»): «{Kind} 「{id}」 was deleted, leaving N references
      // dangling» — the deleted entity IS the subject (lead kind + id name), the dangling dependents ride
      // the detail line. Named by id, not name: at notify time the entity is already purged, so its display
      // name is no longer resolvable (see relation.go notifyDependencyBroken — payload carries deletedId,
      // never deletedName). 标准主语句:被删实体作主语(kind lead + id name),被依赖者进详情行;按 id 命名——
      // 发通知时实体已 purge、显示名不再可解(后端 payload 只带 deletedId、无 deletedName)。
      return NotificationLine(
        icon: AnIcons.relations,
        lead: deletedKind != null ? _kindLabel(deletedKind, t) : null,
        name: deletedId,
        trail: deps.length == 1 ? nt.depBrokenOne : nt.depBrokenMany(n: deps.length),
        tone: AnTone.warn,
        detail: _dependentNames(deps));
  }

  // handler.restarted splits by outcome (ok:false is the only inbox row; ok:true is frame-only). The tone
  // matters even for the frame-only success: the toast dispatcher reads this line's tone, so a success
  // rendered as danger would pop a false "restart failed" toast (+ OS notification when unfocused).
  // handler.restarted 按结局分(仅 ok:false 落行);ok:true 虽仅帧,tone 决定 toast——成功渲成 danger 会弹假失败。
  if (n.type == 'handler.restarted') {
    final ok = payload['ok'] == true;
    return NotificationLine(
      icon: ok ? AnIcons.success : AnIcons.error,
      lead: kindLead, name: nameOf(),
      trail: ok ? nt.verb.recovered : nt.verb.restartFailed,
      tone: ok ? AnTone.none : AnTone.danger);
  }

  // workflow.attention_changed: needsAttention true → warn "needs attention"; the self-heal clear
  // (false) → neutral "recovered". attention_changed:点亮 warn / 熄灭 neutral。
  if (n.type == 'workflow.attention_changed') {
    final needs = payload['needsAttention'] == true;
    return NotificationLine(
      icon: needs ? AnIcons.warning : AnIcons.success,
      lead: kindLead, name: nameOf(),
      trail: needs ? nt.verb.needsAttention : nt.verb.recovered,
      tone: needs ? AnTone.warn : AnTone.none,
      detail: needs ? (payload['attentionReason'] as String?)?.trim().nullIfEmpty : null);
  }

  // sandbox.env_status_changed row is a terminal state (installing is frame-only): failed → danger,
  // else ready. No entity name (env). sandbox 落行=终态(installing 仅帧):failed danger / else ready。
  if (n.type == 'sandbox.env_status_changed') {
    final failed = payload['status'] == 'failed';
    // No kind lead — the verb ("environment build failed"/"environment ready") already names the env.
    // 无 kind lead——动词本身已含「环境」。
    return NotificationLine(
      icon: failed ? AnIcons.error : AnIcons.success,
      trail: failed ? nt.verb.envFailed : nt.verb.envReady,
      tone: failed ? AnTone.danger : AnTone.none,
      detail: failed ? (payload['errorMsg'] as String?)?.trim().nullIfEmpty : null);
  }

  // mcp.reconnected carries an outcome status (N0 enrichment): connected/ready → reconnected, else fail.
  // mcp.reconnected 带结局 status:ready → 重连 / else 失败。
  if (n.type == 'mcp.reconnected') {
    final ok = payload['status'] == 'ready' || payload['status'] == 'connected' || payload['status'] == 'degraded';
    return NotificationLine(
      icon: AnIcons.mcp, lead: kindLead, name: nameOf(),
      trail: ok ? nt.verb.reconnected : nt.verb.reconnectFailed,
      tone: ok ? AnTone.none : AnTone.danger);
  }

  // ── the compositional lifecycle bulk: kind icon + name + a verb from the action ──
  final verb = _verbLabel(action, t);
  if (verb != null) {
    return NotificationLine(icon: _kindIcon(domain), lead: kindLead, name: nameOf(), trail: verb);
  }

  // Unknown type (open vocab) → a generic, honest line. 未知 type → 通用诚实行。
  return NotificationLine(icon: AnIcons.bell, trail: nt.unknown);
}

/// The go_router deep-link for a notification's source object, or null if its kind has no panel (mcp /
/// memory / sandbox / relation → an inert, non-navigating row — never a dead link). The id lives in the
/// payload as `<domain>Id` (skill/document use name/documentId); workflow-scoped events (run_failed /
/// approval_pending / attention / lifecycle) all target the workflow. 通知源对象的深链;无面板 kind → null。
String? notificationLocation(NotificationItem n) {
  final p = n.payload;
  final domain = n.domain;
  final id = switch (domain) {
    'skill' => p['name'] as String?, // skill id = slug/name
    'document' => p['documentId'] as String?,
    _ => p['${domain}Id'] as String?, // functionId / handlerId / … / workflowId
  };
  if (id == null || id.isEmpty) return null;
  return panelLocationFor(domain, id);
}

/// The joined dependent names for a dependency-broken detail line, or null if none carried a name.
/// 依赖断裂详情行的被依赖者名(逗点连接);均无名则 null。
String? _dependentNames(List deps) {
  final names = deps
      .whereType<Map>()
      .map((d) => d['name'] as String?)
      .where((s) => s != null && s.isNotEmpty)
      .cast<String>()
      .toList();
  return names.isEmpty ? null : names.join(' · ');
}

IconData _kindIcon(String domain) => switch (domain) {
      'function' => AnIcons.function,
      'handler' => AnIcons.handler,
      'agent' => AnIcons.agent,
      'workflow' => AnIcons.workflow,
      'control' => AnIcons.control,
      'approval' => AnIcons.approval,
      'skill' => AnIcons.skill,
      'memory' => AnIcons.memory,
      'document' => AnIcons.doc,
      'mcp' => AnIcons.mcp,
      'sandbox' => AnIcons.layers,
      'relation' => AnIcons.relations,
      _ => AnIcons.bell,
    };

String? _kindLabel(String domain, Translations t) => switch (domain) {
      'function' => t.ref.function,
      'handler' => t.ref.handler,
      'agent' => t.ref.agent,
      'workflow' => t.ref.workflow,
      'control' => t.ref.control,
      'approval' => t.ref.approval,
      'skill' => t.ref.skill,
      'mcp' => t.ref.mcp,
      'document' => t.ref.document,
      'memory' => t.notifications.kind.memory,
      'sandbox' => t.notifications.kind.sandbox,
      'relation' => t.notifications.kind.relation,
      _ => null,
    };

String? _verbLabel(String action, Translations t) {
  final v = t.notifications.verb;
  return switch (action) {
    'created' => v.created,
    'edited' => v.edited,
    'reverted' => v.reverted,
    'updated' => v.updated,
    'deleted' => v.deleted,
    'env_rebuilt' => v.envRebuilt,
    'config_updated' => v.configUpdated,
    'config_cleared' => v.configCleared,
    'installed' => v.installed,
    'removed' => v.removed,
    _ => null, // reconnected / restarted / crashed / run_failed handled above 上面已处理
  };
}

extension _NullIfEmpty on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}
