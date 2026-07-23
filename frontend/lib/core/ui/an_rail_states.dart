import 'package:flutter/widgets.dart';

import 'an_button.dart';
import 'an_content_in.dart';
import 'an_deferred_loading.dart';
import 'an_rail_skeleton.dart';
import 'an_state.dart';

/// The i18n strings a rail's first-screen needs — the error [AnState] copy and the retry label. Bundled so
/// the shared [AnRailStates] stays i18n-agnostic (each rail passes its own feature strings). There is NO
/// empty copy: an empty rail is not a placeholder screen — see [AnRailStates].
///
/// rail 首屏所需的 i18n 串——错误 AnState 文案 + 重试标签。打包使共享 AnRailStates 与 i18n 解耦。无空态文案:空
/// rail 不是占位屏——见 AnRailStates。
class AnRailStrings {
  const AnRailStrings({
    required this.errorTitle,
    required this.errorHint,
    required this.retry,
  });

  final String errorTitle;
  final String errorHint;
  final String retry;
}

/// Resolves a left-island rail's first screen — one of: a deferred loading skeleton / an error screen with
/// retry / the list itself. Precedence is loading > error > list. The CALLER derives the two booleans (each
/// rail computes them differently — chat over ONE AsyncValue, entities as an AGGREGATE over 4 kind lists),
/// so only the identical RENDERING of the outcomes is shared here, not the divergent resolution logic (that
/// would be a leaky abstraction).
///
/// **There is deliberately no empty state (用户 0718 拍板 · 新人之旅第一站).** An empty rail = the FULL rail
/// with its rows removed: the list's own chrome (New / search / ⚙ / group heads) always renders, so a
/// zero-data rail resolves straight to [builder] and reads as the collapsed shape of the populated one —
/// structure IS the guidance, zero prose. The old full-area «No conversations yet / Create a … to get
/// started» tombstones (which swallowed that chrome by replacing the whole list) are retired. Only loading
/// (a skeleton) and error (a retry) still replace the whole area — both are transient non-states, not "the
/// rail is simply empty".
///
/// 解出左岛 rail 首屏之一:延迟骨架 / 错误+重试 / 列表本身。优先级 loading > error > list。两个布尔由**调用方**
/// 推导(各 rail 算法不同——chat 单 AsyncValue、entities 4 kind 列表聚合),故此处只共享结果的**渲染**、不共享
/// 分叉的解析逻辑(强并会成漏抽象)。
///
/// **刻意无空态(用户 0718 拍板 · 新人之旅第一站)。** 空 rail = 满 rail 去掉行:列表自带的 chrome(新建 / 搜索 /
/// ⚙ / 分组头)恒渲,故零数据 rail 直落 builder、读作满态收起的形状——**结构即引导、零文案**。旧的全区墓碑
/// (把整列表连同 chrome 一起替换成「还没有…」)物理退役。仅 loading(骨架)与 error(重试)仍替换整区——二者是
/// 瞬时非态,不是「rail 本就空」。
class AnRailStates extends StatelessWidget {
  const AnRailStates({
    required this.loading,
    required this.error,
    required this.strings,
    required this.onRetry,
    required this.builder,
    super.key,
  });

  final bool loading;
  final bool error;
  final AnRailStrings strings;
  final VoidCallback onRetry;

  /// The list screen, built lazily so it only runs when neither placeholder state applies. An empty list is
  /// still this — the list renders its chrome with no rows. 列表屏,惰构:两占位态都不适用时才跑;空列表也走它(渲 chrome、无行)。
  final Widget Function() builder;

  @override
  Widget build(BuildContext context) {
    // A shaped skeleton reads faster than a spinner; deferred so a fast first load never flashes it.
    // 骨架比转圈更快读懂;延迟防快速首载闪现。
    if (loading) return const AnDeferredLoading(child: AnRailSkeleton());
    if (error) {
      return AnState(
        kind: AnStateKind.error,
        title: strings.errorTitle,
        hint: strings.errorHint,
        action: AnButton(label: strings.retry, onPressed: onRetry),
      );
    }
    // The list SURFACES (S5): a one-shot fade when it replaces the skeleton/error screen; in-place
    // data updates re-run [builder] at the same element position and never replay it.
    // 列表浮现(S5):替换骨架/错误屏时一次性淡入;原地数据更新同位重跑 builder、不重播。
    return AnContentIn(child: builder());
  }
}
