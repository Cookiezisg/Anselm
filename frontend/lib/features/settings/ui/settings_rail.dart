import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/model/sidebar_model.dart';
import '../../../core/ui/an_sidebar_list.dart';
import '../../../i18n/strings.g.dart';
import '../model/settings_catalog.dart';
import '../state/settings_panel_provider.dart';

/// PURE projection: the settings directory as a sidebar model — one flat group, three static
/// sections (偏好/资源/系统), one row per catalog panel. Derives ENTIRELY from [settingsCatalog]
/// (the three-equal gate counts on it). 纯投影:目录=单平铺组+静态三段+每面板一行,全量派生自目录表。
SidebarModel buildSettingsRailModel(Translations t) {
  SidebarType section(SettingsSection s, String label) => SidebarType(
        label: label,
        rows: [
          for (final e in settingsCatalog)
            if (e.section == s) SidebarRow(id: e.panel.name, label: e.labelOf(t), icon: e.icon),
        ],
      );
  return SidebarModel(
    groups: [
      SidebarGroup(types: [
        section(SettingsSection.prefs, t.settings.sections.prefs),
        section(SettingsSection.resources, t.settings.sections.resources),
        section(SettingsSection.system, t.settings.sections.system),
      ]),
    ],
    filterPlaceholder: t.settings.filter,
  );
}

/// The settings directory (left island) — [AnSidebarList] over the catalog projection: static three
/// sections, built-in panel-granularity filter (the v1 search ruling), no New row, no pagination.
/// Selecting a row drives [settingsPanelProvider]. 设置目录(左岛):目录表投影,内建面板粒度过滤(v1
/// 搜索裁决),无 New 无分页;选行驱动 settingsPanelProvider。
class SettingsRail extends ConsumerWidget {
  const SettingsRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final selected = ref.watch(settingsPanelProvider);
    return AnSidebarList(
      model: buildSettingsRailModel(t),
      selectedId: selected.name,
      showNew: false,
      onSelect: (id) {
        final panel = SettingsPanel.values.asNameMap()[id];
        if (panel != null) ref.read(settingsPanelProvider.notifier).select(panel);
      },
    );
  }
}
