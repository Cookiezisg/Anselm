import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/model/status_state.dart';
import '../../../../core/ui/an_chip.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_crumbs.dart';
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
  const EntityOceanHeader({required this.detail, this.onFire, this.onRename, super.key});

  final EntityDetail detail;

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
      // «Entities / <Kind>» — the root navigates to the Overview; the kind is a rail grouping with no
      // page of its own, so it's inert. The entity's OWN name is the big title, never a crumb (面包屑律)。
      // 根导航到总览;kind 是 rail 分组、无独立页故惰性;实体自己的名是大标题、绝不入面包屑。
      crumbs: [
        AnCrumb(d.crumbRoot, onTap: () => context.go('/entities')),
        AnCrumb(detail.ref.kind.typeLabel(t)),
      ],
      meta: _badges(t),
      // The run verb CTA is RETIRED (0718 拍板「唯一执行点」: execution lives only in the right-island
      // debugger — two Run doors confused which to press); trigger keeps its Fire CTA (an activation,
      // not a run — different act, not a second door). 动词 CTA 退役(唯一执行点=右岛调试台;两扇 Run 门
      // 分不清点哪个);trigger 保留 Fire(那是催一发 activation,不是第二扇执行门)。
      actions: [
        if (detail.ref.kind == EntityKind.trigger)
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
