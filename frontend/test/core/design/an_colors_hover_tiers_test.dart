import 'package:anselm/core/design/colors.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// The inline-button hover tier ladder (WRK-070 / 0719 «钮淹死在行底里» fix). Three distinguishable resting
// fills must never collide, in BOTH themes: a hovered ROW = surfaceHover, an inline icon/ghost BUTTON on
// that row = surfaceHoverStrong (a clear notch deeper), a SELECTED row = surfaceActive. If a future retune
// slides one onto another the inline button vanishes into its row again — this guard reddens first.
// 行内钮 hover 三档阶梯守卫:行 hover / 钮 hover / 选中 三值在明暗两主题都必须互异,撞色即钮糊回行底。
void main() {
  for (final (name, c) in [
    ('light', AnColors.light),
    ('dark', AnColors.dark),
  ]) {
    test(
      '$name: row-hover / inline-button-hover / selection are three distinct fills',
      () {
        final tiers = <Color>{
          c.surfaceHover,
          c.surfaceHoverStrong,
          c.surfaceActive,
        };
        expect(
          tiers.length,
          3,
          reason:
              '$name: surfaceHover, surfaceHoverStrong, surfaceActive must be mutually distinct',
        );
      },
    );

    test(
      '$name: inline-button hover is a CLEAR notch off the row hover (not a hair)',
      () {
        // Perceptual gap on the luminance axis — a 1-unit token drift would technically pass the distinct
        // guard yet be invisible. Require a real step. 亮度轴上真实一档(非发丝差),1 单位漂移虽「互异」却看不见。
        int lum(Color x) =>
            ((x.r * 255).round() + (x.g * 255).round() + (x.b * 255).round()) ~/
            3;
        expect(
          (lum(c.surfaceHover) - lum(c.surfaceHoverStrong)).abs(),
          greaterThanOrEqualTo(8),
          reason:
              '$name: surfaceHoverStrong must be a visible notch off surfaceHover',
        );
      },
    );
  }
}
