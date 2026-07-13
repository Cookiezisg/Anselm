import 'dart:math' as math;

import 'package:flutter/services.dart';
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
import '../state/settings_detail_provider.dart';
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
  final GlobalKey _headerKey = GlobalKey();
  double _threshold = AnSpace.s64; // pre-measure fallback; recomputed from the measured header height (A-102, entity/document ocean 同法) 测量前兜底,据测得头高重算

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
    ref.read(shellHeadProvider.notifier).setCollapsed(_scroll.offset > _threshold);
  }

  void _bindHead(String crumb) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Measure the big title block (the collapse threshold = its height past the head band) —
      // the entity/document oceans' pattern, no per-ocean magic number (A-102). 实测大标题块高定阈
      // (头高−islandHead),同 entity/document 海洋,不再私铸魔数。
      final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        _threshold = math.max(AnSpace.s8, box.size.height - AnSize.islandHead);
      }
      ref.read(shellHeadProvider.notifier).bind(crumb, () {
        if (_scroll.hasClients) {
          _scroll.animateTo(0, duration: AnMotion.mid, curve: AnMotion.easeOut);
        }
      });
    });
  }

  /// The pushed-in detail's crumb segment (WRK-062 §1 third level). 推入级面包屑段。
  String? _detailLabel(Translations t, SettingsDetail? d) => switch (d?.kind) {
        'addKey' => t.settings.keys.addKey,
        'editKey' => t.settings.keys.editKey,
        'sandboxInstall' => t.settings.sandbox.installTitle,
        'mcpServer' => d?.id,
        'mcpAdd' => t.settings.mcp.manualAdd,
        'mcpImport' => t.settings.mcp.importTitle,
        'mcpMarket' => t.settings.mcp.market,
        'mcpInstall' => (d?.id ?? '').split('/').last,
        'addMemory' => t.settings.mem.newMemory,
        'memory' => d?.id,
        'addWorkspace' => t.settings.ws.newWorkspace,
        'workspace' => t.settings.ws.edit,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final panel = ref.watch(settingsPanelProvider);
    final detail = ref.watch(settingsDetailProvider);
    final entry = settingsCatalog.firstWhere((e) => e.panel == panel);
    final label = entry.labelOf(t);
    final detailLabel = _detailLabel(t, detail);
    _bindHead(
        '${t.settings.title} / $label${detailLabel == null ? '' : ' / $detailLabel'}');
    // Panel switch: pop any pushed detail + fresh page opens at the top. 换面板弹出详情+回顶。
    ref.listen(settingsPanelProvider, (prev, next) {
      if (prev != next) {
        ref.read(settingsDetailProvider.notifier).pop();
        if (_scroll.hasClients) _scroll.jumpTo(0);
        ref.read(shellHeadProvider.notifier).setCollapsed(false);
      }
    });
    return CallbackShortcuts(
      bindings: {
        // Esc returns from the pushed third level (§1). Esc 从推入级返回。
        if (detail != null)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              ref.read(settingsDetailProvider.notifier).pop(),
      },
      child: Focus(
        autofocus: false,
        child: AnPage(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KeyedSubtree(
                key: _headerKey,
                child: Padding(
                  padding: const EdgeInsets.only(top: AnSpace.s24, bottom: AnSpace.s16),
                  child: Text(detailLabel ?? label, style: AnText.readingH1.copyWith(color: c.ink)),
                ),
              ),
              buildSettingsPanelBody(context, panel),
            ],
          ),
        ),
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
