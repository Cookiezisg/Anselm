import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/notice/notice_center.dart';
import '../../../../core/settings/app_prefs_providers.dart';
import '../../../../core/settings/settings_prefs.dart';
import '../../../../core/ui/an_scope_badge.dart';
import '../../../../core/ui/an_section.dart';
import '../../../../core/ui/an_segmented.dart';
import '../../../../core/ui/an_setting_row.dart';
import '../../../../core/ui/an_switch.dart';
import '../../../../i18n/strings.g.dart';
import '../../model/settings_search.dart';
import '../settings_anchor.dart';

/// ② 通知 — level (three notches) + the OS / in-app delivery switches (WRK-062 §3-②). The level
/// consumer is the event notice dispatcher; «needs you» items always reach the bell (read-only line says
/// so). Switching to silent confirms once in the top band. 通知面板:三档级别+OS/应用内两开关;事件派发器
/// 消费该闸;「需你处理」永远进铃(只读行言明);切静音在顶带给一次中性确认。
class NotificationsPanel extends ConsumerWidget {
  const NotificationsPanel({super.key});

  /// The level's storage values. 级别存储值。
  static const levels = ['all', 'important', 'silent'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final level = ref.watch(stringSettingProvider(SettingsKeys.notifyLevel));
    final os = ref.watch(boolSettingProvider(SettingsKeys.notifyOs));
    final toast = ref.watch(boolSettingProvider(SettingsKeys.notifyToast));
    final capFail = ref.watch(boolSettingProvider(SettingsKeys.capsuleFailures));
    final capAppr = ref.watch(boolSettingProvider(SettingsKeys.capsuleApprovals));
    final capAttn = ref.watch(boolSettingProvider(SettingsKeys.capsuleAttention));

    // Actions-only head — the panel title already says «Notifications»; a same-named group head was
    // pure repetition (0719 审计 P1-1). The badge keeps its seat. 徽章头——面板大题已言「通知」,
    // 同名组头纯重复;域徽留座。
    return AnSection(
      label: '',
      variant: AnSectionVariant.quiet,
      actions: const [AnScopeBadge(AnSettingScope.device)],
      children: [
        SettingsAnchor(
          item: SettingsItem.notifLevel,
          child: AnSettingRow(
            label: t.settings.notifLevel,
            desc: t.settings.notifLevelDesc,
            modified: level != SettingsKeys.notifyLevel.def,
            onReset: () =>
                ref.read(stringSettingProvider(SettingsKeys.notifyLevel).notifier).reset(),
            resetLabel: t.settings.resetToDefault,
            child: SizedBox(
              width: AnSize.ctlSlotLg,
              child: AnSegmented<String>(
                options: [
                  AnSegmentedOption(value: 'all', label: t.settings.levelAll),
                  AnSegmentedOption(value: 'important', label: t.settings.levelImportant),
                  AnSegmentedOption(value: 'silent', label: t.settings.levelSilent),
                ],
                value: level,
                onChanged: (v) {
                  ref.read(stringSettingProvider(SettingsKeys.notifyLevel).notifier).set(v);
                  if (v == 'silent') {
                    // One-shot confirmation microcopy (S-8). 一次性确认微文案。
                    ref.read(noticeCenterProvider.notifier).show(t.settings.silentHint);
                  }
                },
              ),
            ),
          ),
        ),
        SettingsAnchor(
          item: SettingsItem.notifOs,
          child: AnSettingRow(
            label: t.settings.notifOs,
            desc: t.settings.notifOsDesc,
            modified: os != SettingsKeys.notifyOs.def,
            onReset: () => ref.read(boolSettingProvider(SettingsKeys.notifyOs).notifier).reset(),
            resetLabel: t.settings.resetToDefault,
            child: AnSwitch(
              value: os,
              onChanged: (v) => ref.read(boolSettingProvider(SettingsKeys.notifyOs).notifier).set(v),
            ),
          ),
        ),
        const SizedBox(height: AnSpace.s4),
        SettingsAnchor(
          item: SettingsItem.notifToast,
          child: AnSettingRow(
            label: t.settings.notifToast,
            desc: t.settings.notifToastDesc,
            modified: toast != SettingsKeys.notifyToast.def,
            onReset: () => ref.read(boolSettingProvider(SettingsKeys.notifyToast).notifier).reset(),
            resetLabel: t.settings.resetToDefault,
            child: AnSwitch(
              value: toast,
              onChanged: (v) =>
                  ref.read(boolSettingProvider(SettingsKeys.notifyToast).notifier).set(v),
            ),
          ),
        ),
        const SizedBox(height: AnSpace.s4),
        // The capsule REGISTRY (用户 0720): which event classes may pop the band capsule. Rows are
        // plain settings switches — one per class, tone dot colors live in the capsule itself.
        // 胶囊登记:哪些事件类可上顶带。逐类开关;分级点色在胶囊自身。
        _capsuleRow(ref, t, SettingsKeys.capsuleFailures, capFail, t.settings.capsuleFailures,
            t.settings.capsuleFailuresDesc),
        const SizedBox(height: AnSpace.s4),
        _capsuleRow(ref, t, SettingsKeys.capsuleApprovals, capAppr, t.settings.capsuleApprovals,
            t.settings.capsuleApprovalsDesc),
        const SizedBox(height: AnSpace.s4),
        _capsuleRow(ref, t, SettingsKeys.capsuleAttention, capAttn, t.settings.capsuleAttention,
            t.settings.capsuleAttentionDesc),
      ],
    );
  }

  Widget _capsuleRow(WidgetRef ref, Translations t, SettingsKey<bool> key, bool value, String label,
          String desc) =>
      AnSettingRow(
        label: label,
        desc: desc,
        modified: value != key.def,
        onReset: () => ref.read(boolSettingProvider(key).notifier).reset(),
        resetLabel: t.settings.resetToDefault,
        child: AnSwitch(
          value: value,
          onChanged: (v) => ref.read(boolSettingProvider(key).notifier).set(v),
        ),
      );
}
