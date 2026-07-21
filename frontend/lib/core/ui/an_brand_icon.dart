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
      _brandAsset = null,
      _glyph = null,
      _bare = false,
      managed = false,
      elevated = false;

  /// The NAKED brand mark — just the 6 blocks, monochrome **inkMuted** (the nav icons' grey, not the
  /// wordmark's ink — locked on-device: grey blends with the stroked nav icons far better than solid black),
  /// NO white plate + NO frame — for placing INLINE beside the nav icons (the fullscreen/Win-Linux
  /// window-controls brand). Its blocks are sized to the nav icons' OPTICAL glyph, not the icon box, then
  /// centered in that box so it box-aligns AND reads the same visual size as them ([_markContentRatio]).
  /// 裸品牌 mark:仅 6 方块、单色 **inkMuted**(nav 图标那档灰、非 wordmark 的 ink——真机定:灰比实心黑更融入描边 nav 图标)、
  /// 无白底无边框——供侧栏行内、和 nav 图标同列;方块按 nav 图标可见字形大小(非盒)取、居中于盒,故盒对齐且视觉同大([_markContentRatio])。
  const AnBrandIcon.mark({this.size = AnBrandSize.sm, super.key})
    : _asset = _anselmMarkAsset,
      _bare = true,
      _svg = null,
      _brandAsset = null,
      _glyph = null,
      managed = false,
      elevated = false;

  /// An inline SVG logo string (currentColor → ink). 内联 SVG logo 串(随 ink 着色)。
  const AnBrandIcon.svg(
    String svg, {
    this.size = AnBrandSize.md,
    this.managed = false,
    this.elevated = false,
    super.key,
  }) : _svg = svg,
       _asset = null,
       _brandAsset = null,
       _glyph = null,
       _bare = false;

  /// A vendored brand-logo SVG asset (`assets/brand/<slug>.svg`, lobe-icons/simple-icons — see
  /// `LICENSES.md` there), ink-tinted like [AnBrandIcon.svg]; callers resolve slugs through the
  /// brand registry and fall back to [AnBrandIcon.glyph] when no asset exists. 品牌 SVG 资产
  /// (随包,随 ink 着色);slug 经品牌注册表解析,缺者走字母兜底。
  const AnBrandIcon.brand(
    String assetPath, {
    this.size = AnBrandSize.md,
    this.managed = false,
    this.elevated = false,
    super.key,
  }) : _brandAsset = assetPath,
       _svg = null,
       _asset = null,
       _glyph = null,
       _bare = false;

  /// A letter-glyph fallback when no logo is available. 无 logo 时的字母兜底。
  const AnBrandIcon.glyph(
    String letter, {
    this.size = AnBrandSize.md,
    this.managed = false,
    this.elevated = false,
    super.key,
  }) : _glyph = letter,
       _asset = null,
       _brandAsset = null,
       _svg = null,
       _bare = false;

  final AnBrandSize size;
  final bool managed;
  final bool elevated;
  final bool _bare;
  final String? _asset;
  final String? _brandAsset;
  final String? _svg;
  final String? _glyph;

  static const String _anselmAsset = 'assets/brand/anselm-icon.svg';
  static const String _anselmMarkAsset = 'assets/brand/anselm-mark.svg';

  // The naked mark's block extent as a fraction of the icon box — matched to the nav icons' visible glyph
  // (measured ~13 in a 16 box). Tuned on-device: a solid mark reads heavier than a stroked glyph, so this
  // sits a touch under the raw ratio. 裸 mark 方块占盒比,对齐 nav 图标可见字形(实测 ~13/16);实心比描边重故略收,真机调。
  static const double _markContentRatio = 0.8125;

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
  double get _plateRadius =>
      size == AnBrandSize.lg ? AnRadius.island : AnRadius.tag;

  double get _glyphSize => switch (size) {
    AnBrandSize.sm => AnSize.icon, // 16
    AnBrandSize.md => AnSize.iconLg, // 20
    AnBrandSize.lg => AnSize.islandHead, // 44
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final side = _side;
    Widget child;
    Decoration? plate;

    if (_bare && _asset != null) {
      // Naked mark: the blocks-only SVG, ink-tinted, sized to the nav-icon OPTICAL glyph ([_markContentRatio])
      // and CENTERED in the [side] icon box so it both box-aligns and reads the same size as the nav icons.
      // 裸 mark:仅方块 SVG、ink 着色、按 optical 比取、居中于盒,故盒对齐且视觉同大。
      return SizedBox(
        width: side,
        height: side,
        child: Center(
          child: SvgPicture.asset(
            _asset,
            width: side * _markContentRatio,
            height: side * _markContentRatio,
            colorFilter: ColorFilter.mode(c.inkMuted, BlendMode.srcIn),
          ),
        ),
      );
    }

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
    } else if (_svg != null || _brandAsset != null) {
      // Provider logo (inline string or vendored asset): self-presents, tinted. managed → accent
      // plate + accent tint. 自呈现,着色(内联串或随包资产同径)。
      final filter = ColorFilter.mode(
        managed ? c.accent : c.ink,
        BlendMode.srcIn,
      );
      // The glyph sits a step under the box (like the letter face) so tight-viewBox marks don't
      // bleed to the plate edge. 字形略小于盒(同字母脸),满框 viewBox 不顶边。
      child = _svg != null
          ? SvgPicture.string(
              _svg,
              width: side,
              height: side,
              colorFilter: filter,
            )
          : SvgPicture.asset(
              _brandAsset!,
              width: _glyphSize,
              height: _glyphSize,
              colorFilter: filter,
            );
      if (managed || _brandAsset != null) {
        plate = BoxDecoration(
          color: managed ? c.accentSoft : c.surfaceHover,
          borderRadius: BorderRadius.circular(_plateRadius),
        );
      }
    } else {
      // Letter fallback on a rounded plate. 字母圆角底兜底。
      child = Text(
        (_glyph != null && _glyph.isNotEmpty)
            ? _glyph.characters.first.toUpperCase()
            : '?',
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
    return Builder(
      builder: (context) {
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: context.colors.shadowFloat,
          ),
          child: child,
        );
      },
    );
  }
}
