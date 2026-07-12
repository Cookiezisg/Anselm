import 'package:flutter/widgets.dart';

import '../../../../core/model/status_state.dart';
import '../../../../core/ui/an_chip.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_ocean_header.dart';
import '../../../../core/ui/icons.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/entity_kind.dart';
import '../../data/entity_labels.dart';
import '../../state/detail/entity_detail.dart';

/// The detail ocean header — breadcrumb + entity name (inline-renamable when [onRename] is given) +
/// per-kind status badges + the verb CTA (Run/Call/Invoke/Trigger → the right-island run terminal,
/// [onVerb]). Version content is read-only here (AI edits it via chat; hand-editing covers meta only).
/// 详情海洋页头:面包屑 + 名称(onRename 时就地改名)+ 状态徽 + 动词 CTA。版本内容此处只读。
class EntityOceanHeader extends StatelessWidget {
  const EntityOceanHeader({required this.detail, this.onVerb, this.onFire, this.onRename, super.key});

  final EntityDetail detail;

  /// Press the verb CTA → open the run terminal for this entity (null = disabled). 动词 CTA → 开 run 终端。
  final VoidCallback? onVerb;

  /// Press the trigger's Fire CTA → `:fire` a manual signal (trigger only; produces an activation, NOT a
  /// run terminal — the payload is always `{manual:true}`, so there's no input form). 手动 Fire(仅 trigger)。
  final VoidCallback? onFire;

  /// Non-null → the title renames in place (meta PATCH, no version bump). 非空则标题就地改名。
  final ValueChanged<String>? onRename;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final d = t.entities.detail;
    return AnOceanHeader(
      title: detail.name,
      onTitleChange: onRename,
      crumbs: [d.crumbRoot, detail.ref.kind.typeLabel(t)],
      meta: _badges(t),
      // Executable kinds get the run verb CTA (→ run terminal); trigger gets a Fire CTA (→ an activation,
      // not a run); other support kinds have no action. 可执行 kind 动词 CTA;trigger 有 Fire;余支撑 kind 无。
      actions: [
        if (detail.ref.kind.executable)
          AnButton(
            label: detail.ref.kind.verbLabel(t),
            icon: AnIcons.byKey(detail.ref.kind.scopeKind),
            variant: AnButtonVariant.primary,
            onPressed: onVerb,
          )
        else if (detail.ref.kind == EntityKind.trigger)
          AnButton(
            label: t.entities.detail.trigger.fire,
            icon: AnIcons.byKey(EntityKind.trigger.scopeKind),
            variant: AnButtonVariant.primary,
            onPressed: onFire,
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
        return [AnChip('v${v.version} · ${v.envStatus}', tone: AnStatus.fromRaw(v.envStatus).tone)];
      case EntityKind.handler:
        final hd = detail.handler;
        final v = hd?.activeVersion;
        return [
          if (v != null && hd?.runtimeState != null)
            AnChip('v${v.version} · ${hd!.runtimeState}', tone: AnStatus.fromRaw(hd.runtimeState).tone),
          if (hd?.configState != null)
            AnChip(hd!.configState!, tone: AnStatus.fromRaw(hd.configState).tone),
        ];
      case EntityKind.agent:
        final v = detail.agent?.activeVersion;
        final mh = detail.mountHealth;
        return [
          if (v != null) AnChip('v${v.version}', tone: AnTone.none),
          if (mh != null)
            mh.allHealthy
                ? AnChip(kv.mounts.healthy, tone: AnTone.ok)
                : AnChip(kv.mounts.unhealthy(count: mh.mounts.where((m) => !m.healthy).length),
                    tone: AnTone.danger),
        ];
      case EntityKind.workflow:
        final wf = detail.workflow;
        if (wf == null) return const [];
        return [
          // vN badge aligns workflow with the other versioned kinds (W2). 版本徽与余 kind 对齐。
          if (wf.activeVersion != null) AnChip('v${wf.activeVersion!.version}', tone: AnTone.none),
          AnChip(wf.lifecycleState, tone: AnStatus.fromRaw(wf.lifecycleState).tone),
          AnChip(wf.concurrency, tone: AnTone.none),
          if (wf.needsAttention)
            AnChip(wf.attentionReason ?? kv.val.needsAttention, tone: AnTone.warn),
        ];
      case EntityKind.control:
        final v = detail.control?.activeVersion;
        return [if (v != null) AnChip('v${v.version}', tone: AnTone.none)];
      case EntityKind.approval:
        final v = detail.approval?.activeVersion;
        return [if (v != null) AnChip('v${v.version}', tone: AnTone.none)];
      case EntityKind.trigger:
        final tr = detail.trigger;
        if (tr == null) return const [];
        return [
          AnChip(tr.kind.name, tone: AnTone.none), // source kind (cron/webhook/fsnotify/sensor)
          // The live signal: is its listener hot (≥1 active workflow references it). 活信号:listener 热否。
          tr.listening
              ? AnChip(kv.trigger.listening, tone: AnStatus.run.tone)
              : AnChip(kv.trigger.idle, tone: AnTone.none),
        ];
    }
  }

}
