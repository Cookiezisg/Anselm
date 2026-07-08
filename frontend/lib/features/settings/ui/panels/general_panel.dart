import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/tokens.dart';
import '../../../../core/overlay/an_overlay.dart';
import '../../../../core/platform/launch_at_login.dart';
import '../../../../core/platform/window_zoom.dart';
import '../../../../core/settings/app_prefs_providers.dart';
import '../../../../core/settings/settings_prefs.dart';
import '../../../../core/ui/an_dropdown.dart';
import '../../../../core/ui/an_scope_badge.dart';
import '../../../../core/ui/an_section.dart';
import '../../../../core/ui/an_segmented.dart';
import '../../../../core/ui/an_setting_row.dart';
import '../../../../core/ui/an_switch.dart';
import '../../../../core/ui/an_toast.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/workspace_prefs_provider.dart';

/// ① 通用 — appearance / language / window & startup / updates (WRK-062 §3-①). Instant-apply
/// throughout; the language row DOUBLE-WRITES (拍板 #2): UI locale (app scope) + the active
/// workspace's AI output language, and says so in its description. A failed workspace PATCH rolls
/// back and toasts. 通用面板:外观/语言/窗口与启动/更新。全即时生效;语言行**双写**(界面 locale +
/// 当前工作区 AI 输出语言,描述言明);PATCH 失败回滚+toast。
class GeneralPanel extends ConsumerWidget {
  const GeneralPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final theme = ref.watch(themePreferenceProvider);
    final locale = ref.watch(localePreferenceProvider);
    final remember = ref.watch(boolSettingProvider(SettingsKeys.windowRemember));
    final atLogin = ref.watch(boolSettingProvider(SettingsKeys.launchAtStartup));
    final updateCheck = ref.watch(boolSettingProvider(SettingsKeys.updateCheck));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnSection(
          label: t.settings.appearance,
          variant: AnSectionVariant.quiet,
          actions: const [AnScopeBadge(AnSettingScope.device)],
          children: [
            AnSettingRow(
              label: t.settings.theme,
              desc: t.settings.themeDesc,
              modified: theme != ThemePreference.light,
              onReset: () => ref.read(themePreferenceProvider.notifier).set(ThemePreference.light),
              resetLabel: t.settings.resetToDefault,
              child: SizedBox(
                width: 280,
                child: AnSegmented<ThemePreference>(
                  options: [
                    AnSegmentedOption(value: ThemePreference.light, label: t.settings.themeLight),
                    AnSegmentedOption(value: ThemePreference.dark, label: t.settings.themeDark),
                    AnSegmentedOption(value: ThemePreference.system, label: t.settings.themeSystem),
                  ],
                  value: theme,
                  onChanged: (v) => ref.read(themePreferenceProvider.notifier).set(v),
                ),
              ),
            ),
            const SizedBox(height: AnSpace.s4),
            _ZoomRow(t: t),
          ],
        ),
        const SizedBox(height: AnSpace.s24),
        AnSection(
          label: t.settings.language,
          variant: AnSectionVariant.quiet,
          actions: const [AnScopeBadge(AnSettingScope.device)],
          children: [
            AnSettingRow(
              label: t.settings.languageRow,
              desc: t.settings.languageDesc,
              modified: locale != 'system',
              onReset: () => _setLanguage(ref, context, 'system'),
              resetLabel: t.settings.resetToDefault,
              child: SizedBox(
                width: 200,
                child: AnDropdown<String>(
                  options: [
                    AnDropdownOption(value: 'system', label: t.settings.langSystem),
                    AnDropdownOption(value: 'en', label: t.settings.langEn),
                    AnDropdownOption(value: 'zh-CN', label: t.settings.langZh),
                  ],
                  value: locale,
                  onChanged: (v) => _setLanguage(ref, context, v),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AnSpace.s24),
        AnSection(
          label: t.settings.window,
          variant: AnSectionVariant.quiet,
          actions: const [AnScopeBadge(AnSettingScope.device)],
          children: [
            AnSettingRow(
              label: t.settings.rememberWindow,
              desc: t.settings.rememberWindowDesc,
              modified: remember != SettingsKeys.windowRemember.def,
              onReset: () =>
                  ref.read(boolSettingProvider(SettingsKeys.windowRemember).notifier).reset(),
              resetLabel: t.settings.resetToDefault,
              child: AnSwitch(
                value: remember,
                onChanged: (v) =>
                    ref.read(boolSettingProvider(SettingsKeys.windowRemember).notifier).set(v),
              ),
            ),
            const SizedBox(height: AnSpace.s4),
            AnSettingRow(
              label: t.settings.launchAtLogin,
              desc: t.settings.launchAtLoginDesc,
              modified: atLogin != SettingsKeys.launchAtStartup.def,
              onReset: () => _setLaunchAtLogin(ref, false),
              resetLabel: t.settings.resetToDefault,
              child: AnSwitch(
                value: atLogin,
                onChanged: (v) => _setLaunchAtLogin(ref, v),
              ),
            ),
          ],
        ),
        const SizedBox(height: AnSpace.s24),
        AnSection(
          label: t.settings.updates,
          variant: AnSectionVariant.quiet,
          actions: const [AnScopeBadge(AnSettingScope.device)],
          children: [
            AnSettingRow(
              label: t.settings.updateCheck,
              desc: t.settings.updateCheckDesc,
              modified: updateCheck != SettingsKeys.updateCheck.def,
              onReset: () =>
                  ref.read(boolSettingProvider(SettingsKeys.updateCheck).notifier).reset(),
              resetLabel: t.settings.resetToDefault,
              child: AnSwitch(
                value: updateCheck,
                onChanged: (v) =>
                    ref.read(boolSettingProvider(SettingsKeys.updateCheck).notifier).set(v),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The double-write (拍板 #2): UI locale now + the workspace's AI language. The workspace half is
  /// best-effort-with-honesty: a failed PATCH rolls back (provider) and toasts. 双写:UI 即时,workspace
  /// 侧失败回滚+toast。
  void _setLanguage(WidgetRef ref, BuildContext context, String value) {
    final t = Translations.of(context);
    ref.read(localePreferenceProvider.notifier).set(value);
    // Map the UI choice onto the backend's closed language set. `system` resolves to the device's
    // best match. 映射到后端封闭语言集;system 解析设备最佳匹配。
    final resolved = value == 'system'
        ? (LocaleSettings.currentLocale == AppLocale.zhCn ? 'zh-CN' : 'en')
        : value;
    ref.read(workspacePrefsProvider.notifier).setLanguage(resolved).catchError((_) {
      ref.read(overlayProvider.notifier).showToast(t.settings.patchFailed, tone: AnToastTone.danger);
    });
  }

  void _setLaunchAtLogin(WidgetRef ref, bool value) {
    ref.read(boolSettingProvider(SettingsKeys.launchAtStartup).notifier).set(value);
    applyLaunchAtLogin(value);
  }
}

/// UI zoom — mirrors [WindowZoom.factor] (a ValueNotifier, so the ⌘ shortcuts and this control stay
/// in lockstep); steps beyond the live screen cap render disabled. 界面缩放:镜像 WindowZoom.factor
/// (快捷键与本控件同步);超出当前屏 cap 的档渲 disabled。
class _ZoomRow extends StatelessWidget {
  const _ZoomRow({required this.t});

  final Translations t;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: WindowZoom.factor,
      builder: (context, factor, _) {
        final cap = WindowZoom.maxFactor();
        return AnSettingRow(
          label: t.settings.zoom,
          desc: t.settings.zoomDesc,
          modified: factor != WindowZoom.defaultFactor,
          onReset: WindowZoom.reset,
          resetLabel: t.settings.resetToDefault,
          child: SizedBox(
            width: 320,
            child: AnSegmented<double>(
              options: [
                for (final s in WindowZoom.steps)
                  AnSegmentedOption(value: s, label: '$s×', disabled: s > cap),
              ],
              value: factor,
              onChanged: WindowZoom.set,
            ),
          ),
        );
      },
    );
  }
}
