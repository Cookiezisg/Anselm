import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/status_state.dart';
import '../../../../core/overlay/an_overlay.dart';
import '../../../../core/settings/app_prefs_providers.dart';
import '../../../../core/settings/follow_mode.dart';
import '../../../../core/settings/settings_prefs.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_scope_badge.dart';
import '../../../../core/ui/an_section.dart';
import '../../../../core/ui/an_segmented.dart';
import '../../../../core/ui/an_setting_row.dart';
import '../../../../i18n/strings.g.dart';
import '../../model/settings_catalog.dart';
import '../../state/settings_panel_provider.dart';
import '../../state/workspace_prefs_provider.dart';

/// ③ 对话 — the sidestage auto-open three-notch (READS the shared core [followModeProvider]:
/// one state, two homes — the sidestage head menu and this row must never diverge), the send key,
/// and the workspace-scope web-fetch mode. Tail ghost link jumps to Models & keys (single source
/// for the default model — never re-rendered here). 对话面板:右岛自动登台三档(读 core 的
/// followModeProvider——一份状态两处家)/发送键/工作区级抓取模式;尾部 ghost 链跳模型与密钥(默认模型
/// 单一事实源,绝不在此重复渲)。
class ChatPanel extends ConsumerWidget {
  const ChatPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final c = context.colors;
    final follow = ref.watch(followModeProvider);
    final sendKey = ref.watch(stringSettingProvider(SettingsKeys.chatSendKey));
    final ws = ref.watch(workspacePrefsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnSection(
          label: t.settings.panels.chat,
          variant: AnSectionVariant.quiet,
          actions: const [AnScopeBadge(AnSettingScope.device)],
          children: [
            AnSettingRow(
              label: t.settings.autoStage,
              desc: t.settings.autoStageDesc,
              modified: follow != FollowMode.always,
              onReset: () => ref.read(followModeProvider.notifier).set(FollowMode.always),
              resetLabel: t.settings.resetToDefault,
              child: SizedBox(
                width: AnSize.ctlSlotLg,
                child: AnSegmented<FollowMode>(
                  options: [
                    AnSegmentedOption(value: FollowMode.never, label: t.settings.stageNever),
                    AnSegmentedOption(
                        value: FollowMode.firstPerConversation, label: t.settings.stageFirst),
                    AnSegmentedOption(value: FollowMode.always, label: t.settings.stageAlways),
                  ],
                  value: follow,
                  onChanged: (v) => ref.read(followModeProvider.notifier).set(v),
                ),
              ),
            ),
            const SizedBox(height: AnSpace.s4),
            AnSettingRow(
              label: t.settings.sendKey,
              desc: t.settings.sendKeyDesc,
              modified: sendKey != SettingsKeys.chatSendKey.def,
              onReset: () =>
                  ref.read(stringSettingProvider(SettingsKeys.chatSendKey).notifier).reset(),
              resetLabel: t.settings.resetToDefault,
              child: SizedBox(
                width: AnSize.ctlSlot,
                child: AnSegmented<String>(
                  options: [
                    AnSegmentedOption(value: 'enter', label: t.settings.sendEnter),
                    AnSegmentedOption(value: 'cmdEnter', label: t.settings.sendCmdEnter),
                  ],
                  value: sendKey,
                  onChanged: (v) =>
                      ref.read(stringSettingProvider(SettingsKeys.chatSendKey).notifier).set(v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AnSpace.s24),
        AnSection(
          label: t.settings.webFetch,
          variant: AnSectionVariant.quiet,
          actions: const [AnScopeBadge(AnSettingScope.workspace)],
          children: [
            AnSettingRow(
              label: t.settings.webFetch,
              desc: t.settings.webFetchDesc,
              modified: (ws.value?.webFetchMode ?? 'local') != 'local',
              onReset: () => _setWebFetch(ref, context, 'local'),
              resetLabel: t.settings.resetToDefault,
              enabled: ws.hasValue,
              child: SizedBox(
                width: AnSize.ctlSlot,
                child: AnSegmented<String>(
                  options: [
                    AnSegmentedOption(value: 'local', label: t.settings.webLocal),
                    AnSegmentedOption(value: 'jina', label: t.settings.webJina),
                  ],
                  value: ws.value?.webFetchMode ?? 'local',
                  onChanged: (v) => _setWebFetch(ref, context, v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AnSpace.s16),
        // Single-source ghost: the default chat model LIVES in Models & keys — link, don't re-render.
        // 单一事实源 ghost 链:默认对话模型住模型与密钥,只链不重复渲。
        AnButton(
          label: t.settings.defaultModelLink,
          variant: AnButtonVariant.ghost,
          onPressed: () =>
              ref.read(settingsPanelProvider.notifier).select(SettingsPanel.modelsKeys),
        ),
        // The async row's error voice (load failure) — the settings inline-error grammar:
        // label(13)+danger, not a red wall. 载入失败行:行内错文法 label+danger。
        if (ws.hasError)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s8),
            child: Text(t.settings.patchFailed, style: AnText.label.copyWith(color: c.danger)),
          ),
      ],
    );
  }

  void _setWebFetch(WidgetRef ref, BuildContext context, String mode) {
    final t = Translations.of(context);
    ref.read(workspacePrefsProvider.notifier).setWebFetchMode(mode).catchError((_) {
      ref.read(overlayProvider.notifier).showToast(t.settings.patchFailed, tone: AnTone.danger);
    });
  }
}
