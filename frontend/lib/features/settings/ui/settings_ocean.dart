import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/perf/frame_safe.dart';
import '../../../core/shell/oceans.dart';
import '../../../core/shell/shell_chrome.dart';
import '../../../core/ui/an_crumbs.dart';
import '../../../core/ui/an_page.dart';
import '../../../core/ui/an_state.dart';
import '../../../i18n/strings.g.dart';
import '../model/settings_catalog.dart';
import '../state/api_keys_provider.dart' show voicesProvider;
import '../state/sandbox_providers.dart'
    show sandboxBootstrapProvider, sandboxEnvsProvider, sandboxRuntimesProvider;
import '../state/settings_detail_provider.dart';
import '../state/settings_panel_provider.dart';
import 'panels/settings_panels.dart';
import 'panels/storage_panel.dart' show sandboxDiskProvider;

/// The settings ocean center — ONE [AnPage] document per panel: a grey parent-path crumb over a big
/// title + the panel body from the panel registry ([buildSettingsPanelBody]). Thin chrome, the
/// entities/documents grammar (用户 0719 面包屑律): the in-page crumb is the PARENT path — «Settings» for a
/// panel, «Settings / [panel]» for a pushed detail — and the big black title is the page's own name
/// (panel / detail); the floating head binds ONLY that title (zero path). Collapses past the title, panel
/// switch re-opens at the top. 设置海洋中心——每面板一页:灰父路径面包屑 + 大黑字标题 + 面板体。面包屑=到
/// 上一级的路径(面板级「Settings」/详情级「Settings / 面板」),黑字=自己(面板/详情);浮层头只绑黑字标题、零路径。
class SettingsOcean extends ConsumerStatefulWidget {
  const SettingsOcean({super.key});

  @override
  ConsumerState<SettingsOcean> createState() => _SettingsOceanState();
}

class _SettingsOceanState extends ConsumerState<SettingsOcean> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _headerKey = GlobalKey();
  double _threshold = AnSpace
      .s64; // pre-measure fallback; recomputed from the measured header height (A-102, entity/document ocean 同法) 测量前兜底,据测得头高重算

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
    final collapsed = _scroll.hasClients && _scroll.offset > _threshold;
    // Read the offset HERE, dirty the head LATER if a frame is in flight (CR-1b). 先读偏移,帧在飞则延后弄脏。
    runFrameSafe(() {
      if (!mounted) return;
      ref.read(shellHeadProvider.notifier).setCollapsed(collapsed);
    });
  }

  void _bindHead(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Measure the big header block (the collapse threshold = its height past the head band) —
      // the entity/document oceans' pattern, no per-ocean magic number (A-102). 实测头块高定阈
      // (头高−islandHead),同 entity/document 海洋,不再私铸魔数。
      final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        _threshold = math.max(AnSpace.s8, box.size.height - AnSize.islandHead);
      }
      // The floating head carries ONLY the page's own title, never the path (面包屑律③). 浮层头只绑黑字标题。
      ref.read(shellHeadProvider.notifier).bind(title, () {
        if (_scroll.hasClients) {
          _scroll.animateTo(0, duration: AnMotion.mid, curve: AnMotion.easeOut);
        }
      });
    });
  }

  void _refreshSandboxProjections() {
    // Settings can stay mounted in the lazy shell after an external entity run. Refresh every
    // machine/env projection on re-entry so a cached empty list never contradicts REST truth.
    // 设置海洋在懒壳中可能常驻;重新进入时重取全机/环境投影,避免缓存空态违背 REST 真相。
    ref.invalidate(sandboxBootstrapProvider);
    ref.invalidate(sandboxRuntimesProvider);
    ref.invalidate(sandboxDiskProvider);
    ref.invalidate(sandboxEnvsProvider);
  }

  void _refreshModelsKeysProjections() {
    // Enrollment is initiated from Chat, while the inventory lives in Settings. The settings
    // ocean stays mounted in the shell, so reopening Models & keys must cross-check the durable
    // voice inventory instead of showing the pre-enrollment AsyncData forever.
    // 登记从 Chat 发起、库存却住在 Settings。设置海洋在壳中常驻,重新打开模型与密钥必须重读权威库存,
    // 不能让登记前的 AsyncData 永远留在屏幕上。
    ref.invalidate(voicesProvider);
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
    // Black title = the page's own name (the pushed detail, else the panel); grey crumb = the PARENT path.
    // At the panel level «Settings» is the current root (inert); at the pushed detail level the panel
    // segment navigates BACK to it (pop the detail). 黑字=自己;灰路径=父级(详情级的面板段点击=弹回面板)。
    final blackTitle = detailLabel ?? label;
    final crumbs = <AnCrumb>[
      AnCrumb(t.settings.title),
      if (detailLabel != null)
        AnCrumb(
          label,
          onTap: () {
            ref.read(settingsDetailProvider.notifier).requestPop();
          },
        ),
    ];
    _bindHead(blackTitle);
    // Panel switch: pop any pushed detail + fresh page opens at the top. 换面板弹出详情+回顶。
    ref.listen(settingsPanelProvider, (prev, next) {
      if (prev != next) {
        if (next == SettingsPanel.sandbox) {
          // SettingsOcean is kept in the app's lazy IndexedStack. Entering Sandbox must therefore
          // invalidate all of its projections instead of trusting a prior visit. 设置海洋在懒
          // IndexedStack 中常驻,进入沙箱面必须失效全套投影,不能信上一轮访问的缓存。
          _refreshSandboxProjections();
        } else if (next == SettingsPanel.storage) {
          ref.invalidate(sandboxDiskProvider);
        } else if (next == SettingsPanel.modelsKeys) {
          _refreshModelsKeysProjections();
        }
        ref.read(settingsDetailProvider.notifier).pop();
        // No-op in a safe phase (runs inline); only defers if a frame is in flight — jumpTo notifies
        // scroll listeners SYNCHRONOUSLY (CR-1b). 安全相位下同步直执行,只在帧在飞时延后——jumpTo 会**同步**通知滚动监听器。
        runFrameSafe(() {
          if (!mounted) return;
          if (_scroll.hasClients) _scroll.jumpTo(0);
          ref.read(shellHeadProvider.notifier).setCollapsed(false);
        });
      }
    });
    ref.listen(selectedOceanProvider, (prev, next) {
      if (next == OceanKind.settings && prev != next) {
        // Leaving and re-entering Settings is another panel-open boundary even though the ocean
        // widget itself remains mounted. 离开再进入设置也是一次打开边界,即使海洋 widget 没卸载。
        if (ref.read(settingsPanelProvider) == SettingsPanel.sandbox) {
          _refreshSandboxProjections();
        } else if (ref.read(settingsPanelProvider) ==
            SettingsPanel.modelsKeys) {
          _refreshModelsKeysProjections();
        } else {
          ref.invalidate(sandboxDiskProvider);
        }
      }
    });
    return CallbackShortcuts(
      bindings: {
        // Esc returns from the pushed third level (§1). Esc 从推入级返回。
        if (detail != null)
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              ref.read(settingsDetailProvider.notifier).requestPop(),
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
                  padding: const EdgeInsets.only(
                    top: AnSpace.s24,
                    bottom: AnSpace.s16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnCrumbs(crumbs, style: AnText.meta),
                      const SizedBox(height: AnSpace.s8),
                      Text(
                        blackTitle,
                        style: AnText.readingH1.copyWith(color: c.ink),
                      ),
                    ],
                  ),
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
