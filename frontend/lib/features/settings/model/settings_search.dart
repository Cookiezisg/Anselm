import '../../../i18n/strings.g.dart';
import 'settings_catalog.dart';

/// Stable anchor ids for every searchable settings ITEM. Each string is referenced in exactly two
/// places — this file's [settingsSearchIndex] (the declaration) and the panel that wraps its row in
/// `SettingsAnchor` (the mount). One id per row, `<panel>.<item>`. Adding a row to a panel means
/// adding a const here + an index entry + a SettingsAnchor wrap; the anchor-mount guard fails if any
/// of the three drift. 每个可搜索设置项的稳定锚 id:恰在两处被引用——本文件索引(声明)与面板里包住该行的
/// SettingsAnchor(挂载)。命名 `<面板>.<项>`;三者漂移即被锚挂载守卫抓住。
abstract final class SettingsItem {
  // 通用 general
  static const generalTheme = 'general.theme';
  static const generalZoom = 'general.zoom';
  static const generalLanguage = 'general.language';
  static const generalRememberWindow = 'general.rememberWindow';
  static const generalLaunchAtLogin = 'general.launchAtLogin';
  static const generalUpdateCheck = 'general.updateCheck';

  // 通知 notifications
  static const notifLevel = 'notifications.level';
  static const notifOs = 'notifications.os';
  static const notifToast = 'notifications.toast';

  // 对话 chat
  static const chatAutoStage = 'chat.autoStage';
  static const chatSendKey = 'chat.sendKey';
  static const chatWebFetch = 'chat.webFetch';

  // 网络 network
  static const networkHttpProxy = 'network.httpProxy';
  static const networkHttpsProxy = 'network.httpsProxy';
  static const networkNoProxy = 'network.noProxy';

  // 存储与日志 storage
  static const storageDataDir = 'storage.dataDir';
  static const storageDiskUsage = 'storage.diskUsage';
  static const storageDiagnostics = 'storage.diagnostics';
  static const storageRetention = 'storage.retention';
  static const storageDatabase = 'storage.database';
  static const storageResetPrefs = 'storage.resetPrefs';
  static const storageFactory = 'storage.factory';

  // 快捷键 shortcuts (one per global command) 全局命令逐个
  static const shortcutToggleLeft = 'shortcuts.toggleLeft';
  static const shortcutToggleRight = 'shortcuts.toggleRight';
  static const shortcutOpenSettings = 'shortcuts.openSettings';
  static const shortcutZoomIn = 'shortcuts.zoomIn';
  static const shortcutZoomOut = 'shortcuts.zoomOut';
  static const shortcutZoomReset = 'shortcuts.zoomReset';

  // 关于 about
  static const aboutAppVersion = 'about.appVersion';
  static const aboutBackendVersion = 'about.backendVersion';
  static const aboutDiagnostics = 'about.diagnostics';
}

/// One searchable settings item — the panel it lives in, its jump [anchor] (matching the
/// [SettingsAnchor] that wraps the row), and locale-resolved [labelOf] / optional [hintOf] text.
/// The search index is built from label + hint under the CURRENT locale, so a Chinese UI searches
/// Chinese words and an English UI English (拍板). 一个可搜索设置项:所属面板、跳转锚(与包行的
/// SettingsAnchor 对应)、按当前 locale 解析的标签/可选提示。索引按当前 locale 的标签+提示建。
class SettingsSearchItem {
  const SettingsSearchItem({
    required this.panel,
    required this.anchor,
    required this.labelOf,
    this.hintOf,
  });

  final SettingsPanel panel;
  final String anchor;
  final String Function(Translations t) labelOf;
  final String Function(Translations t)? hintOf;
}

/// THE settings search index — every searchable item, in panel order. The rail's item-level search,
/// the two-locale i18n guard and the anchor-mount guard all read this one table. Panels whose content
/// is dynamic DATA (models & keys, MCP servers, memories, workspaces, schema-driven limits, the
/// gated sandbox) declare no items here — they stay panel-name searchable (backward compatible) via
/// the catalog, and index only their STATIC configuration rows.
///
/// 唯一设置搜索索引——每个可搜索项按面板序。rail 项级搜索/双 locale i18n 守卫/锚挂载守卫全读此表。
/// 内容是动态数据的面板(模型与密钥/MCP/记忆/工作区/schema 驱动的限额/带健康门的沙箱)不在此声明项——
/// 它们经目录仍可按面板名搜索(向下兼容),此处只收静态配置行。
final List<SettingsSearchItem> settingsSearchIndex = [
  // ── 通用 general ──
  SettingsSearchItem(
    panel: SettingsPanel.general,
    anchor: SettingsItem.generalTheme,
    labelOf: (t) => t.settings.theme,
    hintOf: (t) => t.settings.themeDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.general,
    anchor: SettingsItem.generalZoom,
    labelOf: (t) => t.settings.zoom,
    hintOf: (t) => t.settings.zoomDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.general,
    anchor: SettingsItem.generalLanguage,
    labelOf: (t) => t.settings.languageRow,
    hintOf: (t) => t.settings.languageDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.general,
    anchor: SettingsItem.generalRememberWindow,
    labelOf: (t) => t.settings.rememberWindow,
    hintOf: (t) => t.settings.rememberWindowDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.general,
    anchor: SettingsItem.generalLaunchAtLogin,
    labelOf: (t) => t.settings.launchAtLogin,
    hintOf: (t) => t.settings.launchAtLoginDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.general,
    anchor: SettingsItem.generalUpdateCheck,
    labelOf: (t) => t.settings.updateCheck,
    hintOf: (t) => t.settings.updateCheckDesc,
  ),
  // ── 通知 notifications ──
  SettingsSearchItem(
    panel: SettingsPanel.notifications,
    anchor: SettingsItem.notifLevel,
    labelOf: (t) => t.settings.notifLevel,
    hintOf: (t) => t.settings.notifLevelDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.notifications,
    anchor: SettingsItem.notifOs,
    labelOf: (t) => t.settings.notifOs,
    hintOf: (t) => t.settings.notifOsDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.notifications,
    anchor: SettingsItem.notifToast,
    labelOf: (t) => t.settings.notifToast,
    hintOf: (t) => t.settings.notifToastDesc,
  ),
  // ── 对话 chat ──
  SettingsSearchItem(
    panel: SettingsPanel.chat,
    anchor: SettingsItem.chatAutoStage,
    labelOf: (t) => t.settings.autoStage,
    hintOf: (t) => t.settings.autoStageDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.chat,
    anchor: SettingsItem.chatSendKey,
    labelOf: (t) => t.settings.sendKey,
    hintOf: (t) => t.settings.sendKeyDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.chat,
    anchor: SettingsItem.chatWebFetch,
    labelOf: (t) => t.settings.webFetch,
    hintOf: (t) => t.settings.webFetchDesc,
  ),
  // ── 网络 network (shared outbound-proxy hint helps 出站 / outbound match) ──
  SettingsSearchItem(
    panel: SettingsPanel.network,
    anchor: SettingsItem.networkHttpProxy,
    labelOf: (t) => t.settings.network.httpProxy,
    hintOf: (t) => t.settings.network.proxyHint,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.network,
    anchor: SettingsItem.networkHttpsProxy,
    labelOf: (t) => t.settings.network.httpsProxy,
    hintOf: (t) => t.settings.network.proxyHint,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.network,
    anchor: SettingsItem.networkNoProxy,
    labelOf: (t) => t.settings.network.noProxy,
    hintOf: (t) => t.settings.network.proxyHint,
  ),
  // ── 存储与日志 storage ──
  SettingsSearchItem(
    panel: SettingsPanel.storage,
    anchor: SettingsItem.storageDataDir,
    labelOf: (t) => t.settings.storage.dataDir,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.storage,
    anchor: SettingsItem.storageDiskUsage,
    labelOf: (t) => t.settings.storage.diskUsage,
    hintOf: (t) => t.settings.storage.diskSandbox,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.storage,
    anchor: SettingsItem.storageDiagnostics,
    labelOf: (t) => t.settings.about.diagnostics,
    hintOf: (t) => t.settings.about.diagDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.storage,
    anchor: SettingsItem.storageRetention,
    labelOf: (t) => t.settings.storage.retention,
    hintOf: (t) => t.settings.storage.retentionDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.storage,
    anchor: SettingsItem.storageDatabase,
    labelOf: (t) => t.settings.storage.database,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.storage,
    anchor: SettingsItem.storageResetPrefs,
    labelOf: (t) => t.settings.storage.resetPrefs,
    hintOf: (t) => t.settings.storage.resetPrefsDesc,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.storage,
    anchor: SettingsItem.storageFactory,
    labelOf: (t) => t.settings.storage.factoryTitle,
    hintOf: (t) => t.settings.storage.factoryWarn,
  ),
  // ── 快捷键 shortcuts ──
  SettingsSearchItem(
    panel: SettingsPanel.shortcuts,
    anchor: SettingsItem.shortcutToggleLeft,
    labelOf: (t) => t.settings.shortcuts.cmdToggleLeft,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.shortcuts,
    anchor: SettingsItem.shortcutToggleRight,
    labelOf: (t) => t.settings.shortcuts.cmdToggleRight,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.shortcuts,
    anchor: SettingsItem.shortcutOpenSettings,
    labelOf: (t) => t.settings.shortcuts.cmdOpenSettings,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.shortcuts,
    anchor: SettingsItem.shortcutZoomIn,
    labelOf: (t) => t.settings.shortcuts.cmdZoomIn,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.shortcuts,
    anchor: SettingsItem.shortcutZoomOut,
    labelOf: (t) => t.settings.shortcuts.cmdZoomOut,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.shortcuts,
    anchor: SettingsItem.shortcutZoomReset,
    labelOf: (t) => t.settings.shortcuts.cmdZoomReset,
  ),
  // ── 关于 about ──
  SettingsSearchItem(
    panel: SettingsPanel.about,
    anchor: SettingsItem.aboutAppVersion,
    labelOf: (t) => t.settings.about.appVersion,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.about,
    anchor: SettingsItem.aboutBackendVersion,
    labelOf: (t) => t.settings.about.backendVersion,
  ),
  SettingsSearchItem(
    panel: SettingsPanel.about,
    anchor: SettingsItem.aboutDiagnostics,
    labelOf: (t) => t.settings.about.diagnostics,
    hintOf: (t) => t.settings.about.diagDesc,
  ),
];

/// One panel's slice of a search result: the catalog [entry] (icon + name → the panel HEADER row,
/// itself a jump-to-panel hit) and the matching [items] under it. [panelMatched] = the panel NAME
/// itself matched the query. 一个面板的搜索结果切片:目录项(图标+名→面板头行,本身即跳面板命中)+
/// 其下匹配项;panelMatched=面板名本身命中。
class SettingsSearchGroup {
  const SettingsSearchGroup({
    required this.entry,
    required this.items,
    required this.panelMatched,
  });

  final SettingsCatalogEntry entry;
  final List<SettingsSearchItem> items;
  final bool panelMatched;
}

/// PURE grouping — the query (case-insensitive, current locale) grouped by panel in catalog order.
/// Rules: a panel is included when its NAME matches OR any of its items match. When the panel NAME
/// matches, ALL its items show (searching a category surfaces everything under it — «搜「网络」既出
/// 面板行也出其下项»); otherwise only the items whose label/hint match. The header row is always the
/// panel itself (a jump-to-panel hit → the old panel-granularity search stays backward compatible,
/// even for panels that declare no items). Empty query → no groups (the rail shows the directory).
///
/// 纯分组——query(大小写不敏感、当前 locale)按面板目录序分组。规则:面板名命中**或**任一项命中即收入;
/// 面板名命中时其**全部**项都出(搜类别即看见其下全部——「搜网络既出面板行也出其下项」),否则只出 label/hint
/// 命中的项。头行恒为面板本身(跳面板命中→旧的面板粒度搜索向下兼容,连无项声明的面板也是)。空 query→空(rail 显目录)。
List<SettingsSearchGroup> buildSettingsSearchGroups(Translations t, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return const [];
  bool hit(String s) => s.toLowerCase().contains(q);
  final out = <SettingsSearchGroup>[];
  for (final entry in settingsCatalog) {
    final panelMatched = hit(entry.labelOf(t));
    final all = [for (final it in settingsSearchIndex) if (it.panel == entry.panel) it];
    final items = [
      for (final it in all)
        if (panelMatched || hit(it.labelOf(t)) || (it.hintOf != null && hit(it.hintOf!(t)))) it,
    ];
    if (panelMatched || items.isNotEmpty) {
      out.add(SettingsSearchGroup(entry: entry, items: items, panelMatched: panelMatched));
    }
  }
  return out;
}
