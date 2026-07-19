import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/ui/an_wash_highlight.dart';
import '../state/settings_jump_provider.dart';

/// Wraps a searchable settings ROW so an item-level search result can jump to it: when
/// [settingsJumpProvider] points at this [item], the anchor scrolls ITSELF into view
/// ([Scrollable.ensureVisible], seated below the floating ocean head) and one-shot washes (the
/// scheduler deep-jump recipe: [AnWashHighlight] under a fresh key), then releases the target.
///
/// **The widget IS the registry marker.** The search-index guard pumps each panel and asserts the
/// mounted anchors' [item]s equal the index declared for that panel — isomorphic to the catalog's
/// three-equal gate: adding a searchable row without declaring it (or declaring one no panel mounts)
/// fails the gate. At rest the anchor is a pure pass-through — zero layout change, so every existing
/// panel test still finds the row exactly where it was.
///
/// 包住可搜索的设置行,让项级搜索结果跳到它:jump 目标指向本 item 时,锚自滚入视(ensureVisible,坐浮层头
/// 之下)+ 一次性洗亮(scheduler 深跳配方:换新 key 的 AnWashHighlight)后放开目标。**本 widget 即注册表
/// 标记**——搜索索引守卫 pump 每面板、断言挂载锚的 item 集恒等于该面板声明的索引(与目录三相等门禁同构:
/// 加了可搜索行却不声明、或声明了无面板挂载的项,都过不了门禁)。静息=纯透传,零布局变化。
class SettingsAnchor extends ConsumerStatefulWidget {
  const SettingsAnchor({required this.item, required this.child, super.key});

  final String item;
  final Widget child;

  @override
  ConsumerState<SettingsAnchor> createState() => _SettingsAnchorState();
}

class _SettingsAnchorState extends ConsumerState<SettingsAnchor> {
  int _washSeq = 0;
  String? _handled;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _trigger() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduced = AnMotionPref.reduced(context);
      // Scroll self into view against the enclosing ocean scroll region (no ScrollController handle
      // needed — ensureVisible walks up to the Scrollable). alignment seats it just under the head band.
      // 对着外层海洋滚动区自滚入视(无需持控制器——ensureVisible 上溯 Scrollable);alignment 让它坐头栏之下。
      Scrollable.ensureVisible(
        context,
        alignment: 0.12,
        duration: reduced ? Duration.zero : AnMotion.slow,
        curve: AnMotion.easeOut,
      );
      // Re-key the one-shot wash so it restarts from full. 换 key 让一次性洗亮从满值重跑。
      _timer?.cancel();
      setState(() => _washSeq++);
      _timer = Timer(reduced ? Duration.zero : AnMotion.wash, () {
        if (mounted) setState(() => _washSeq = 0);
      });
      // Release the target so re-searching the SAME item re-fires. 放开目标,重搜同项能再触发。
      ref.read(settingsJumpProvider.notifier).clear(widget.item);
    });
  }

  @override
  Widget build(BuildContext context) {
    final target = ref.watch(settingsJumpProvider);
    // Fire once per distinct arrival at this item (covers both a fresh mount whose target is already
    // set, and a live retarget while mounted); reset when the target moves away so a repeat re-fires.
    // 每次「目标落到本项」触发一次(涵盖挂载时目标已就位、与挂载中的实时换靶);目标离开即复位,重来能再触发。
    if (target == widget.item) {
      if (_handled != target) {
        _handled = target;
        _trigger();
      }
    } else {
      _handled = null;
    }
    if (_washSeq == 0) return widget.child;
    return AnWashHighlight(
      key: ValueKey('settings-anchor-${widget.item}-$_washSeq'),
      child: widget.child,
    );
  }
}
