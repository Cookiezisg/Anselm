import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Brand / project icon — one widget, three sources (port of demo `brand-icon.js`):
///   • [AnBrandIcon.anselm] — the bundled app mark (pixel-F squircle SVG); self-coloured, framed
///     with a hairline so the white squircle reads on a white surface.
///   • [AnBrandIcon.svg] — an inline SVG logo string (provider brands), tinted to ink via
///     `currentColor`; self-presents with no plate.
///   • [AnBrandIcon.glyph] — a letter fallback on a rounded plate, for projects with no logo.
/// [managed] paints the accent plate (the free-tier "spark"); [elevated] floats it. Sizes map to
/// the demo's sm(lead) / md(ctl) / lg(≈88, welcome) so brand chrome stays dimensionally coherent.
///
/// 品牌/项目图标——一个 widget 三源(移植 brand-icon.js):anselm 随包 app 标(像素 F squircle,自着色 +
/// 细边让白 squircle 在白面可辨)· svg 内联 logo 串(随 ink 着色、无底自呈现)· glyph 字母兜底(圆角底)。
/// managed=accent 底(免费档火花);elevated=浮起。尺寸 sm/md/lg 对齐 demo 保持品牌 chrome 尺寸自洽。
enum AnBrandSize { sm, md, lg }

class AnBrandIcon extends StatelessWidget {
  /// The Anselm app brand mark (bundled SVG asset). Anselm app 品牌标(随包 SVG)。
  const AnBrandIcon.anselm({this.size = AnBrandSize.md, super.key})
      : _asset = _anselmAsset,
        _svg = null,
        _glyph = null,
        managed = false,
        elevated = false;

  /// An inline SVG logo string (currentColor → ink). 内联 SVG logo 串(随 ink 着色)。
  const AnBrandIcon.svg(String svg, {this.size = AnBrandSize.md, this.managed = false, this.elevated = false, super.key})
      : _svg = svg,
        _asset = null,
        _glyph = null;

  /// A letter-glyph fallback when no logo is available. 无 logo 时的字母兜底。
  const AnBrandIcon.glyph(String letter, {this.size = AnBrandSize.md, this.managed = false, this.elevated = false, super.key})
      : _glyph = letter,
        _asset = null,
        _svg = null;

  final AnBrandSize size;
  final bool managed;
  final bool elevated;
  final String? _asset;
  final String? _svg;
  final String? _glyph;

  static const String _anselmAsset = 'assets/brand/anselm-icon.svg';

  // The app-icon SVG's squircle corner ratio (rx 114 of a 512 viewBox) — used to trace its edge.
  // app 图标 SVG 的 squircle 圆角比(512 视框上 rx 114)。
  static const double _squircleRatio = 114 / 512;

  double get _side => switch (size) {
        AnBrandSize.sm => AnSize.icon, // lead
        AnBrandSize.md => AnSize.control, // ctl
        AnBrandSize.lg => AnSize.islandHead * 2, // 88, welcome hero
      };

  // Plate radius for glyph/managed backgrounds. lg gets the island radius; otherwise the tag radius.
  // 底盘圆角:lg 用 island 圆角,其余 tag。
  double get _plateRadius => size == AnBrandSize.lg ? AnRadius.island : AnRadius.tag;

  double get _glyphSize => switch (size) {
        AnBrandSize.sm => AnSize.icon, // 16
        AnBrandSize.md => AnSize.icon + AnSpace.s4, // 20
        AnBrandSize.lg => AnSize.islandHead, // 44
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final side = _side;
    Widget child;
    Decoration? plate;

    if (_asset != null) {
      // App mark: the SVG carries its own white squircle + dark F. Frame with a hairline at the
      // squircle radius so it reads on any surface. 自带白 squircle,细边描其轮廓。
      final r = side * _squircleRatio;
      return _elevate(
        ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: Container(
            width: side,
            height: side,
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(r),
              border: Border.all(color: c.line, width: AnSize.hairline),
            ),
            child: SvgPicture.asset(_asset, width: side, height: side),
          ),
        ),
        radius: r,
      );
    } else if (_svg != null) {
      // Provider logo: self-presents, tinted. managed → accent plate + accent tint. 自呈现,着色。
      child = SvgPicture.string(
        _svg,
        width: side,
        height: side,
        colorFilter: ColorFilter.mode(managed ? c.accent : c.ink, BlendMode.srcIn),
      );
      if (managed) {
        plate = BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(_plateRadius));
      }
    } else {
      // Letter fallback on a rounded plate. 字母圆角底兜底。
      child = Text(
        (_glyph != null && _glyph.isNotEmpty) ? _glyph.characters.first.toUpperCase() : '?',
        style: AnText.strong.copyWith(
          fontSize: _glyphSize,
          height: 1,
          color: managed ? c.accent : c.inkMuted,
        ),
      );
      plate = BoxDecoration(
        color: managed ? c.accentSoft : c.surfaceHover,
        borderRadius: BorderRadius.circular(_plateRadius),
      );
    }

    return _elevate(
      Container(
        width: side,
        height: side,
        alignment: Alignment.center,
        decoration: plate,
        child: child,
      ),
      radius: _plateRadius,
    );
  }

  Widget _elevate(Widget child, {required double radius}) {
    if (!elevated) return child;
    return Builder(builder: (context) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: context.colors.shadowFloat,
        ),
        child: child,
      );
    });
  }
}
