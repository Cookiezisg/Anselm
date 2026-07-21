import 'package:flutter/widgets.dart';

import '../../core/design/tokens.dart';
import '../../core/ui/ui.dart';
import 'specimen.dart';

/// AnPager 标本(WRK-070 B4)。裁决速记:单页不渲(有处可去才存在);页码带开窗(1 … 当前±1 … 末);
/// 跳页小格「#」24 盒+合法数字滑出 ↵ 确认钮(0718 拍板)+回车钳制;当前页加重+底色。
/// gallery dev-only,文案中文直写(i18n 豁免)。
final _strings = AnPagerStrings(
  prevLabel: '上一页',
  nextLabel: '下一页',
  jumpHint: '页码',
  pageLabel: (n) => '第 $n 页',
  jumpToLabel: (n) => '跳转到第 $n 页',
);

class _Host extends StatefulWidget {
  const _Host({required this.pageCount, this.initial = 1});
  final int pageCount;
  final int initial;
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late int _page = widget.initial;
  @override
  Widget build(BuildContext context) => AnPager(
    page: _page,
    pageCount: widget.pageCount,
    onPage: (p) => setState(() => _page = p),
    strings: _strings,
  );
}

final anPagerGalleryItem = GalleryItem(
  'AnPager 翻页器',
  '标准页码翻页器:‹/› + 开窗页码带(1 … 当前±1 … 末,当前加重)+ 跳页小格「#」(合法数字滑出 ↵ 确认钮,回车钳制);单页不渲',
  [
    GallerySpecimen(
      '多页 · 12 页居中(开窗带双 …)',
      (_) => const Padding(
        padding: EdgeInsets.all(AnSpace.s16),
        child: _Host(pageCount: 12, initial: 6),
      ),
      height: 72,
    ),
    GallerySpecimen(
      '首页(‹ 压灰)',
      (_) => const Padding(
        padding: EdgeInsets.all(AnSpace.s16),
        child: _Host(pageCount: 5),
      ),
      height: 72,
    ),
    GallerySpecimen(
      '单页(不渲——空白即正确)',
      (_) => const Padding(
        padding: EdgeInsets.all(AnSpace.s16),
        child: _Host(pageCount: 1),
      ),
      height: 48,
    ),
  ],
);
