import 'package:flutter/widgets.dart';

import '../../../../core/model/status_state.dart';
import '../../../../core/ui/an_badge.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_ocean_header.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_labels.dart';
import '../../state/detail/entity_detail.dart';

/// The detail ocean header — breadcrumb + entity name + per-kind status badges + the verb CTA. The verb
/// CTA (Run/Call/Invoke/Trigger) opens the right-island run terminal for this entity ([onVerb], STEP 5);
/// the title is read-only and the more-menu is a disabled stub (rename / actions land later). Pure
/// function of [EntityDetail] + [onVerb]. 详情海洋页头:面包屑 + 名称 + 各 kind 状态徽 + 动词 CTA(开右岛 run 终端)。
class EntityOceanHeader extends StatelessWidget {
  const EntityOceanHeader({required this.detail, this.onVerb, super.key});

  final EntityDetail detail;

  /// Press the verb CTA → open the run terminal for this entity (null = disabled). 动词 CTA → 开 run 终端。
  final VoidCallback? onVerb;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final d = t.entities.detail;
    return AnOceanHeader(
      title: detail.name,
      crumbs: [d.crumbRoot, detail.ref.kind.typeLabel(t)],
      meta: _badges(t),
      actions: [
        AnButton(
          label: detail.ref.kind.verbLabel(t),
          icon: AnIcons.byKey(detail.ref.kind.scopeKind),
          variant: AnButtonVariant.primary,
          onPressed: onVerb,
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

}
