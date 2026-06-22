import 'package:flutter/widgets.dart';

/// Declarative gallery catalog model (port of the demo's catalog.js) — the single source the
/// gallery + the widget-test matrix both read. One [GallerySpecimen] = one component in one state;
/// the renderer is dumb. [stress] flags the pressure-bed specimens (空/超长/海量/极值/注入) that
/// catch overflow/escape regressions the happy-path can't.
///
/// 声明式画廊目录模型(移植 catalog.js)——画廊与 widget-test 矩阵共读的单源。一个 specimen=一个组件一态;
/// 渲染器哑。stress 标压力床 specimen(空/超长/海量/极值/注入),抓 happy-path 漏的溢出/转义回归。
@immutable
class GallerySpecimen {
  const GallerySpecimen(this.label, this.builder, {this.span = false, this.stress = false});

  final String label;
  final WidgetBuilder builder;

  /// Full-width cell (vs the 2-col grid default). 占满宽(默认 2 列栅格)。
  final bool span;

  /// A pressure-bed specimen (empty / overlong / massive / extreme / injection). 压力床 specimen。
  final bool stress;
}

@immutable
class GalleryItem {
  const GalleryItem(this.name, this.blurb, this.specimens);

  final String name;
  final String blurb;
  final List<GallerySpecimen> specimens;
}

@immutable
class GalleryCategory {
  const GalleryCategory(this.label, this.icon, this.items);

  final String label;
  final IconData icon;
  final List<GalleryItem> items;
}
