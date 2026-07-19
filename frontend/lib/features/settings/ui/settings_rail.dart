import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/sidebar_model.dart';
import '../../../core/ui/an_rail_filter_field.dart';
import '../../../core/ui/an_row.dart';
import '../../../core/ui/an_sidebar_list.dart';
import '../../../i18n/strings.g.dart';
import '../model/settings_catalog.dart';
import '../model/settings_search.dart';
import '../state/settings_detail_provider.dart';
import '../state/settings_jump_provider.dart';
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

/// The settings directory (left island). The search box is LIFTED OUT of [AnSidebarList] (showFilter:
/// false) so one field drives two views: empty query → the catalog directory (three sections, panel
/// rows); a query → SETTING-ITEM results grouped by panel ([buildSettingsSearchGroups]) — the macOS /
/// VS Code settings-search shape. A panel header row jumps to the panel; an item row jumps to the
/// panel AND scrolls-to + washes the row (via [settingsJumpProvider] → the panel's `SettingsAnchor`).
/// Selecting or jumping clears the search (returns to the directory with the target selected). No
/// match → one quiet line. 设置目录(左岛):搜索框抽出 AnSidebarList(showFilter:false),一个框驱动两态:
/// 空 query→目录;有 query→按面板分组的**设置项**结果(macOS / VS Code 设置搜索形态)。面板头行跳面板、
/// 项行跳面板+滚动洗亮(经 settingsJumpProvider → 面板的 SettingsAnchor);选中/跳转即清搜索回目录;无匹配=一句安静句。
class SettingsRail extends ConsumerStatefulWidget {
  const SettingsRail({super.key});

  @override
  ConsumerState<SettingsRail> createState() => _SettingsRailState();
}

class _SettingsRailState extends ConsumerState<SettingsRail> {
  final TextEditingController _filter = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _filter.clear();
    if (_query.isNotEmpty) setState(() => _query = '');
  }

  /// Open a panel. Re-selecting the CURRENT panel while a detail is pushed returns to its root — the
  /// pre-existing rail behaviour, preserved. 打开面板;重点当前面板(有推入详情)=回面板根。
  void _openPanel(SettingsPanel panel) {
    final currentDetail = ref.read(settingsDetailProvider);
    if (panel == ref.read(settingsPanelProvider) && currentDetail != null) {
      ref.read(settingsDetailProvider.notifier).pop();
    } else {
      ref.read(settingsPanelProvider.notifier).select(panel);
    }
    _clearSearch();
  }

  /// Jump to a setting item: select its panel, then arm the item target so the now-mounted panel's
  /// [SettingsAnchor] scrolls-to + washes it. 跳到设置项:选面板,再点亮项目标让面板锚滚动洗亮。
  void _jumpToItem(SettingsSearchItem item) {
    ref.read(settingsPanelProvider.notifier).select(item.panel);
    ref.read(settingsJumpProvider.notifier).request(item.anchor);
    _clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final q = _query.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnRailFilterField(
          controller: _filter,
          placeholder: t.settings.filter,
          onChanged: (v) => setState(() => _query = v),
        ),
        Expanded(child: q.isEmpty ? _directory(t) : _results(t, q)),
      ],
    );
  }

  Widget _directory(Translations t) {
    final selected = ref.watch(settingsPanelProvider);
    return AnSidebarList(
      model: buildSettingsRailModel(t),
      selectedId: selected.name,
      showNew: false,
      showFilter: false, // the field is lifted out (this stateful widget owns it) 搜索框已抽出
      onSelect: (id) {
        final panel = SettingsPanel.values.asNameMap()[id];
        if (panel != null) _openPanel(panel);
      },
    );
  }

  Widget _results(Translations t, String q) {
    final groups = buildSettingsSearchGroups(t, q);
    if (groups.isEmpty) {
      // Zero-prose empty state: the empty list IS the answer, at most one quiet line. 空态零人话:一句安静句。
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s16),
        child: Text(t.settings.searchNoMatch,
            style: AnText.meta.copyWith(color: context.colors.inkFaint)),
      );
    }
    final current = ref.watch(settingsPanelProvider);
    return ListView(
      padding: const EdgeInsets.only(top: AnSpace.s4, bottom: AnSpace.s8),
      children: [
        for (final g in groups) ...[
          // Panel header = a jump-to-panel hit (the 面板行 — panel-granularity backward compat). 面板头行。
          AnRow(
            icon: g.entry.icon,
            label: g.entry.labelOf(t),
            selected: g.entry.panel == current,
            onSelect: () => _openPanel(g.entry.panel),
          ),
          // Matching items under it — jump + scroll-to + wash. 其下匹配项:跳转+滚动+洗亮。
          for (final it in g.items)
            AnRow(
              depth: 1,
              leadless: true,
              label: it.labelOf(t),
              onSelect: () => _jumpToItem(it),
            ),
        ],
      ],
    );
  }
}
