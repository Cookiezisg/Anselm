import 'package:flutter/widgets.dart';

import '../../../core/settings/settings_prefs.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';

/// The 13 panels — the settings ocean's closed navigation set. Enum NAME is the wire/persistence
/// key ('an.settings.panel' stores it; go_router upgrade will path on it). 13 面板——settings 的封闭
/// 导航集。枚举名即持久化/路由键。
enum SettingsPanel {
  // 偏好 preferences
  general, notifications, chat,
  // 资源 resources
  modelsKeys, mcp, memory, sandbox, workspaces,
  // 系统 system
  storage, limits, network, shortcuts, about,
}

/// The three directory sections. 目录三段。
enum SettingsSection { prefs, resources, system }

/// One catalog entry — a panel's identity: section, label, glyph, and the app-level preference keys
/// it OWNS (the gate's material: every declared key must be owned by exactly one entry or listed in
/// [implicitKeys]). 一条目录项:段/标签/字形/该面板**拥有**的 app 级偏好键(门禁原料:每个声明键必须被
/// 恰一个面板拥有,或登记在 implicitKeys)。
class SettingsCatalogEntry {
  const SettingsCatalogEntry({
    required this.panel,
    required this.section,
    required this.labelOf,
    required this.icon,
    this.ownedKeys = const [],
  });

  final SettingsPanel panel;
  final SettingsSection section;
  final String Function(Translations t) labelOf;
  final IconData icon;
  final List<SettingsKey<dynamic>> ownedKeys;
}

/// THE settings catalog — panels in directory order. The search index, the rail model and the
/// three-equal gate all derive from this one table; nothing registers anywhere else.
/// 唯一目录表——面板按目录序。搜索索引/rail 模型/三相等门禁全部由此派生,别处零登记。
final List<SettingsCatalogEntry> settingsCatalog = [
  SettingsCatalogEntry(
    panel: SettingsPanel.general,
    section: SettingsSection.prefs,
    labelOf: (t) => t.settings.panels.general,
    icon: AnIcons.gear,
    ownedKeys: const [
      SettingsKeys.theme, SettingsKeys.locale, SettingsKeys.windowZoom,
      SettingsKeys.windowRemember, SettingsKeys.windowBounds,
      SettingsKeys.launchAtStartup, SettingsKeys.updateCheck,
    ],
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.notifications,
    section: SettingsSection.prefs,
    labelOf: (t) => t.settings.panels.notifications,
    icon: AnIcons.bell,
    ownedKeys: const [SettingsKeys.notifyLevel, SettingsKeys.notifyOs, SettingsKeys.notifyToast],
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.chat,
    section: SettingsSection.prefs,
    labelOf: (t) => t.settings.panels.chat,
    icon: AnIcons.chat,
    ownedKeys: const [SettingsKeys.chatSendKey, SettingsKeys.chatAutoStage],
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.modelsKeys,
    section: SettingsSection.resources,
    labelOf: (t) => t.settings.panels.modelsKeys,
    icon: AnIcons.model,
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.mcp,
    section: SettingsSection.resources,
    labelOf: (t) => t.settings.panels.mcp,
    icon: AnIcons.mcp,
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.memory,
    section: SettingsSection.resources,
    labelOf: (t) => t.settings.panels.memory,
    icon: AnIcons.memory,
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.sandbox,
    section: SettingsSection.resources,
    labelOf: (t) => t.settings.panels.sandbox,
    icon: AnIcons.terminal,
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.workspaces,
    section: SettingsSection.resources,
    labelOf: (t) => t.settings.panels.workspaces,
    icon: AnIcons.workspaceScope,
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.storage,
    section: SettingsSection.system,
    labelOf: (t) => t.settings.panels.storage,
    icon: AnIcons.machineScope,
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.limits,
    section: SettingsSection.system,
    labelOf: (t) => t.settings.panels.limits,
    icon: AnIcons.sliders,
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.network,
    section: SettingsSection.system,
    labelOf: (t) => t.settings.panels.network,
    icon: AnIcons.globe,
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.shortcuts,
    section: SettingsSection.system,
    labelOf: (t) => t.settings.panels.shortcuts,
    icon: AnIcons.keyboard,
    ownedKeys: const [SettingsKeys.shortcuts],
  ),
  SettingsCatalogEntry(
    panel: SettingsPanel.about,
    section: SettingsSection.system,
    labelOf: (t) => t.settings.panels.about,
    icon: AnIcons.info,
  ),
];

/// Declared keys that are USER PREFERENCES but live outside the 13 panels (shell chrome, ocean
/// memory, chat-rail ⚙ toggles) — the gate's second bucket. Every [SettingsKeys.all] member must be
/// in exactly one panel's ownedKeys or here. 面板外的隐式偏好(壳/海洋记忆/chat rail 开关)——门禁第二桶。
const List<SettingsKey<dynamic>> settingsImplicitKeys = [
  SettingsKeys.sideCollapsed, SettingsKeys.sideWidth, SettingsKeys.rightWidth,
  SettingsKeys.ocean, SettingsKeys.settingsPanel,
  SettingsKeys.chatShowArchived, SettingsKeys.chatShowGroupCount, SettingsKeys.chatShowTime,
];
