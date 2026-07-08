import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/shell/shell_chrome.dart';
import '../../../core/ui/an_page.dart';
import '../../../core/ui/an_state.dart';
import '../../../i18n/strings.g.dart';
import '../model/settings_catalog.dart';
import '../state/settings_panel_provider.dart';
import 'panels/settings_panels.dart';

/// The settings ocean center — ONE [AnPage] document per panel: a big title + the panel body from
/// the panel registry ([buildSettingsPanelBody]). Thin chrome, the entities/documents grammar:
/// binds「设置 / 面板」to the floating breadcrumb, collapses it past the title, panel switch
/// re-opens at the top. 设置海洋中心——每面板一页 AnPage 文档:大标题+面板体(注册表出)。薄 chrome,
/// 同 entities/documents 文法:浮层头绑「设置 / 面板」、过标题折叠、换面板回顶。
class SettingsOcean extends ConsumerStatefulWidget {
  const SettingsOcean({super.key});

  @override
  ConsumerState<SettingsOcean> createState() => _SettingsOceanState();
}

class _SettingsOceanState extends ConsumerState<SettingsOcean> {
  final ScrollController _scroll = ScrollController();
  static const double _collapseAt = 64;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    ref.read(shellHeadProvider.notifier).setCollapsed(_scroll.offset > _collapseAt);
  }

  void _bindHead(String crumb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(shellHeadProvider.notifier).bind(crumb, () {
        if (_scroll.hasClients) {
          _scroll.animateTo(0, duration: AnMotion.mid, curve: Curves.easeOutCubic);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final panel = ref.watch(settingsPanelProvider);
    final entry = settingsCatalog.firstWhere((e) => e.panel == panel);
    final label = entry.labelOf(t);
    _bindHead('${t.settings.title} / $label');
    // Panel switch: fresh page opens at the top with its big title visible. 换面板从顶部开。
    ref.listen(settingsPanelProvider, (prev, next) {
      if (prev != next && _scroll.hasClients) {
        _scroll.jumpTo(0);
        ref.read(shellHeadProvider.notifier).setCollapsed(false);
      }
    });
    return AnPage(
      controller: _scroll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s24, bottom: AnSpace.s16),
            child: Text(label, style: AnText.readingH1.copyWith(color: c.ink)),
          ),
          buildSettingsPanelBody(context, panel),
        ],
      ),
    );
  }
}

/// The placeholder body a panel renders until its build slice lands. 面板未建时的占位体。
class SettingsPanelPlaceholder extends StatelessWidget {
  const SettingsPanelPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s24),
      child: AnState(
        kind: AnStateKind.empty,
        title: t.settings.building,
        hint: t.settings.buildingHint,
        size: AnStateSize.inset,
      ),
    );
  }
}
