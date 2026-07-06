import 'package:flutter/widgets.dart';

/// Carries the chassis's «did I witness this call settle THIS session?» signal down to a settle-only
/// family body (e.g. [ToolHitList]) so it can play its one-time reveal on first mount ONLY when the
/// transition was witnessed — never on a history reload / scroll-back re-mount. The chassis wraps the
/// expanded body in this; a body reads [ToolCardReveal.of] and defaults its `animate` to
/// [revealOnMount]. A body rendered with no wrapper (gallery / capture) reads `false` = instant.
///
/// 把底盘「本会话是否亲历此调用落定」信号下传给 settle-only 族体([ToolHitList]),使其仅在亲历过渡时首
/// 挂载播一次揭示,历史重载/滚回重挂绝不重放。无包裹(gallery/截图)→ false = 即显。
class ToolCardReveal extends InheritedWidget {
  const ToolCardReveal({required this.revealOnMount, required super.child, super.key});

  /// True when the chassis witnessed running→settled this session — a fresh reveal is warranted.
  /// 底盘本会话亲历 running→落定为真——值得播一次揭示。
  final bool revealOnMount;

  static ToolCardReveal? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ToolCardReveal>();

  @override
  bool updateShouldNotify(ToolCardReveal old) => old.revealOnMount != revealOnMount;
}
