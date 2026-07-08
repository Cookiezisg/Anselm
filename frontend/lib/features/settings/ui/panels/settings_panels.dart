import 'package:flutter/widgets.dart';

import '../../model/settings_catalog.dart';
import '../settings_ocean.dart';
import 'chat_panel.dart';
import 'general_panel.dart';
import 'about_panel.dart';
import 'memory_panel.dart';
import 'models_keys_panel.dart';
import 'notifications_panel.dart';
import 'workspaces_panel.dart';

/// The panel-body registry — one builder per [SettingsPanel]. Panels light up slice by slice
/// (S1 偏好域 → S2 模型与密钥 → …); an unbuilt panel renders the shared placeholder so the
/// directory is complete-and-honest from S0 on. The exhaustive switch keeps «new panel without a
/// body» a compile error. 面板体注册表——每面板一个 builder,随切片逐个点亮;未建面板渲共享占位
/// (目录从 S0 起完整而诚实)。穷尽 switch 让「加面板忘接体」直接编译错。
Widget buildSettingsPanelBody(BuildContext context, SettingsPanel panel) {
  return switch (panel) {
    SettingsPanel.general => const GeneralPanel(),
    SettingsPanel.notifications => const NotificationsPanel(),
    SettingsPanel.chat => const ChatPanel(),
    SettingsPanel.modelsKeys => const ModelsKeysPanel(),
    SettingsPanel.mcp => const SettingsPanelPlaceholder(),
    SettingsPanel.memory => const MemoryPanel(),
    SettingsPanel.sandbox => const SettingsPanelPlaceholder(),
    SettingsPanel.workspaces => const WorkspacesPanel(),
    SettingsPanel.storage => const SettingsPanelPlaceholder(),
    SettingsPanel.limits => const SettingsPanelPlaceholder(),
    SettingsPanel.network => const SettingsPanelPlaceholder(),
    SettingsPanel.shortcuts => const SettingsPanelPlaceholder(),
    SettingsPanel.about => const AboutPanel(),
  };
}
