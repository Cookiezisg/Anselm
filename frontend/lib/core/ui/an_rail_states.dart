import 'package:flutter/widgets.dart';

import 'an_button.dart';
import 'an_deferred_loading.dart';
import 'an_rail_skeleton.dart';
import 'an_state.dart';

/// The i18n strings a rail's first-screen needs — the error + empty [AnState] copy and the retry label.
/// Bundled so the shared [AnRailStates] stays i18n-agnostic (each rail passes its own feature strings).
///
/// rail 首屏所需的 i18n 串——错误/空 AnState 文案 + 重试标签。打包使共享 AnRailStates 与 i18n 解耦。
class AnRailStrings {
  const AnRailStrings({
    required this.errorTitle,
    required this.errorHint,
    required this.retry,
    required this.emptyTitle,
    required this.emptyHint,
  });

  final String errorTitle;
  final String errorHint;
  final String retry;
  final String emptyTitle;
  final String emptyHint;
}

/// Resolves a left-island rail's first screen — one of: a deferred loading skeleton / an error screen with
/// retry / an empty screen / the list itself. Precedence is loading > error > empty > list. The CALLER
/// derives the three booleans (each rail computes them differently — chat over ONE AsyncValue, entities as
/// an AGGREGATE over 4 kind lists), so only the identical RENDERING of the four outcomes is shared here, not
/// the divergent resolution logic (that would be a leaky abstraction).
///
/// 解出左岛 rail 首屏之一:延迟骨架 / 错误+重试 / 空 / 列表本身。优先级 loading > error > empty > list。
/// 三个布尔由**调用方**推导(各 rail 算法不同——chat 单 AsyncValue、entities 4 kind 列表聚合),故此处只共享
/// 四种结果的**渲染**、不共享分叉的解析逻辑(强并会成漏抽象)。
class AnRailStates extends StatelessWidget {
  const AnRailStates({
    required this.loading,
    required this.error,
    required this.empty,
    required this.strings,
    required this.onRetry,
    required this.builder,
    super.key,
  });

  final bool loading;
  final bool error;
  final bool empty;
  final AnRailStrings strings;
  final VoidCallback onRetry;

  /// The list screen, built lazily so it only runs when none of the three placeholder states apply.
  /// 列表屏,惰构:仅当三种占位态都不适用时才跑。
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
    if (empty) {
      return AnState(kind: AnStateKind.empty, title: strings.emptyTitle, hint: strings.emptyHint);
    }
    return builder();
  }
}
