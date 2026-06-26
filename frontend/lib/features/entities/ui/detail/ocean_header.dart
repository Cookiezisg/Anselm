import 'package:flutter/widgets.dart';

import '../../../../core/model/status_state.dart';
import '../../../../core/ui/an_badge.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_ocean_header.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_kind.dart';
import '../../state/detail/entity_detail.dart';

/// The detail ocean header — breadcrumb + entity name + per-kind status badges + the verb CTA. In STEP 4
/// the title is read-only (rename is an edit → STEP 5) and the CTA + more-menu are DISABLED stubs
/// (wiring the verb to the right-island run terminal is STEP 5). Pure function of [EntityDetail].
/// 详情海洋页头:面包屑 + 名称 + 各 kind 状态徽 + 动词 CTA(STEP 4 标题只读、CTA/更多 为禁用占位,STEP 5 接)。
class EntityOceanHeader extends StatelessWidget {
  const EntityOceanHeader({required this.detail, super.key});

  final EntityDetail detail;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final d = t.entities.detail;
    return AnOceanHeader(
      title: detail.name,
      crumbs: [d.crumbRoot, _kindLabel(t, detail.ref.kind)],
      meta: _badges(t),
      actions: [
        AnButton(
          label: _verbLabel(t, detail.ref.kind),
          icon: AnIcons.byKey(detail.ref.kind.scopeKind),
          variant: AnButtonVariant.primary,
          onPressed: null, // STEP 5: wire to right-island run terminal
        ),
        AnButton.iconOnly(
          AnIcons.byKey('more'),
          onPressed: null,
          semanticLabel: d.moreActions,
        ),
      ],
    );
  }

  List<Widget> _badges(Translations t) {
    final kv = t.entities.detail;
    switch (detail.ref.kind) {
      case EntityKind.function:
        final v = detail.function?.activeVersion;
        if (v == null) return const [];
        return [AnBadge('v${v.version} · ${v.envStatus}', tone: AnStatus.fromRaw(v.envStatus).tone)];
      case EntityKind.handler:
        final hd = detail.handler;
        final v = hd?.activeVersion;
        return [
          if (v != null && hd?.runtimeState != null)
            AnBadge('v${v.version} · ${hd!.runtimeState}', tone: AnStatus.fromRaw(hd.runtimeState).tone),
          if (hd?.configState != null)
            AnBadge(hd!.configState!, tone: AnStatus.fromRaw(hd.configState).tone),
        ];
      case EntityKind.agent:
        final v = detail.agent?.activeVersion;
        final mh = detail.mountHealth;
        return [
          if (v != null) AnBadge('v${v.version}', tone: AnTone.none),
          if (mh != null)
            mh.allHealthy
                ? AnBadge(kv.mounts.healthy, tone: AnTone.ok)
                : AnBadge(kv.mounts.unhealthy(count: mh.mounts.where((m) => !m.healthy).length),
                    tone: AnTone.danger),
        ];
      case EntityKind.workflow:
        final wf = detail.workflow;
        if (wf == null) return const [];
        return [
          AnBadge(wf.lifecycleState, tone: AnStatus.fromRaw(wf.lifecycleState).tone),
          AnBadge(wf.concurrency, tone: AnTone.none),
          if (wf.needsAttention)
            AnBadge(wf.attentionReason ?? kv.val.needsAttention, tone: AnTone.warn),
        ];
    }
  }

  String _kindLabel(Translations t, EntityKind k) => switch (k) {
        EntityKind.function => t.ref.function,
        EntityKind.handler => t.ref.handler,
        EntityKind.agent => t.ref.agent,
        EntityKind.workflow => t.ref.workflow,
      };

  String _verbLabel(Translations t, EntityKind k) => switch (k) {
        EntityKind.function => t.entities.detail.verb.run,
        EntityKind.handler => t.entities.detail.verb.call,
        EntityKind.agent => t.entities.detail.verb.invoke,
        EntityKind.workflow => t.entities.detail.verb.trigger,
      };
}
