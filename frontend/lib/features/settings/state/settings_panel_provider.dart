import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_prefs.dart';
import '../model/settings_catalog.dart';

/// Which settings panel is open — provider-first navigation (拍板 #8): a plain persisted state, the
/// same grammar as the ocean switcher; upgrades to /settings/:panel when the oceans route. Restores
/// synchronously from [SettingsPrefs] (loaded before runApp), with a byName guard so a renamed enum
/// falls back to general instead of crashing.
///
/// 当前设置面板——provider 先行导航(拍板 #8):普通持久化状态,与海洋切换同文法;海洋路由化时升格
/// /settings/:panel。从 SettingsPrefs 同步恢复(runApp 前已载),byName 守卫防旧枚举名。
class SettingsPanelController extends Notifier<SettingsPanel> {
  @override
  SettingsPanel build() {
    final stored = ref
        .read(settingsPrefsProvider)
        .getString(SettingsKeys.settingsPanel);
    return SettingsPanel.values.asNameMap()[stored] ?? SettingsPanel.general;
  }

  void select(SettingsPanel panel) {
    if (panel == state) return;
    state = panel;
    ref
        .read(settingsPrefsProvider)
        .setString(SettingsKeys.settingsPanel, panel.name);
  }
}

final settingsPanelProvider =
    NotifierProvider<SettingsPanelController, SettingsPanel>(
      SettingsPanelController.new,
    );
