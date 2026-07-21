import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';

/// How fresh a touchpoint is (WRK-061 §7.4): AGING IS DESATURATION, never transparency — an old row is
/// still fully readable, it has just settled into grey. Tiers: <2min a soft accent halo still glows;
/// <1h full saturation, halo gone; <1d ink; older sinks to muted. Computed per build from [lastAt]
/// (visible rows only — the list rebuilds on ledger changes; no per-row ticker).
///
/// 触点新鲜度:**衰老=去饱和、绝非透明化**——旧行仍全可读,只是沉淀成灰。四档:<2min 余晖光晕;<1h 全饱和
/// 无晕;<1d 正墨;更老沉灰。按 build 时的年龄静算(仅可视行;无逐行 ticker)。
enum AnFreshness { glowing, fresh, settled, aged }

AnFreshness freshnessOf(DateTime lastAt, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(lastAt);
  if (age < const Duration(minutes: 2)) return AnFreshness.glowing;
  if (age < const Duration(hours: 1)) return AnFreshness.fresh;
  if (age < const Duration(days: 1)) return AnFreshness.settled;
  return AnFreshness.aged;
}

/// The ink tone a row of this freshness writes with. 该新鲜度的墨色。
Color freshnessInk(AnFreshness f, AnColors c) => switch (f) {
  AnFreshness.glowing || AnFreshness.fresh => c.ink,
  AnFreshness.settled => c.inkMuted,
  AnFreshness.aged => c.inkFaint,
};

/// Wraps a Cast row's leading glyph with the freshness halo: only [AnFreshness.glowing] carries the
/// soft accent bloom (the "just happened" afterglow); every other tier renders the bare child.
/// 包裹行首字形:仅 glowing 档带柔和 accent 余晖,余档裸渲。
class AnFreshnessHalo extends StatelessWidget {
  const AnFreshnessHalo({
    required this.freshness,
    required this.child,
    super.key,
  });

  final AnFreshness freshness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (freshness != AnFreshness.glowing) return child;
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: c.accentSoft,
            blurRadius: AnSpace.s6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: child,
    );
  }
}
