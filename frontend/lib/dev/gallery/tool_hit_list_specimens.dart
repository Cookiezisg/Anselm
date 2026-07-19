import 'package:flutter/widgets.dart';

import '../../core/design/typography.dart';
import '../../core/ui/icons.dart';
import '../../features/chat/ui/tool_hit_list.dart';
import 'specimen.dart';

// ToolHitList (B3.2, WRK-056 #10) — the shared machine-window hit/enumeration list. Each row is
// glyph + name(15) + snippet(13) + tail meta; tappable iff the kind has a panel; «当前» marker; two
// footer states (local over-cap escape hatch vs server-truncated note); one-time cascade reveal.
// 机器窗命中行列:双截断态 + 「当前」记 + 级联淡入。

ToolHitRow _hit(String kind, String id, String name, [String? snippet]) => ToolHitRow(
      glyph: AnIcons.entityKindGlyph(kind),
      title: name,
      subtitle: snippet,
      kind: kind,
      id: id,
      trailing: Text(id, style: AnText.mono),
    );

final _fnHits = [
  _hit('function', 'fn_1a2b', 'fetch_with_retry', '指数退避重试,最多 5 次'),
  _hit('function', 'fn_3c4d', 'parse_invoice', '解析发票行项目为结构化 JSON'),
  _hit('function', 'fn_5e6f', 'quarter_of', '把日期归到财季'),
  _hit('agent', 'ag_7a8b', 'invoice_triager', '按季度分类发票并标记退款'),
];

final toolHitListGalleryItem = GalleryItem(
  'ToolHitList 命中行列(#10)',
  '机器窗内命中/枚举行列:glyph+主文15+次行13+尾 id;行可点(kind 有面板)→ 跳实体面板,无面板惰性;'
      '「当前」记;两截断态(本地超封顶逃生口「前N·共M」可点换全量 JSON / 服务端截断只读注记);级联淡入一次。',
  [
    GallerySpecimen('搜索命中 · 可点行 + 尾 id(级联淡入)',
        (c) => ToolHitList(rows: _fnHits, cap: 20, animate: true, onRowTap: (_, _) {}), span: true),
    GallerySpecimen('「当前」记(currentId 行戴记)',
        (c) => ToolHitList(rows: _fnHits, cap: 20, currentId: 'fn_3c4d', onRowTap: (_, _) {}), span: true),
    GallerySpecimen('服务端截断 · 只读注记(前 4 · 共 47,不可点)',
        (c) => ToolHitList(rows: _fnHits, cap: 20, total: 47, serverTruncated: true, onRowTap: (_, _) {}),
        span: true),
    GallerySpecimen('本地超封顶 · 逃生口(前 3 · 共 4,点→全量 JSON)',
        (c) => ToolHitList(
            rows: _fnHits,
            cap: 3,
            rawJson: '{"count":4,"functions":[{"id":"fn_1a2b","name":"fetch_with_retry"},'
                '{"id":"fn_3c4d","name":"parse_invoice"},{"id":"fn_5e6f","name":"quarter_of"},'
                '{"id":"ag_7a8b","name":"invoice_triager"}]}',
            onRowTap: (_, _) {}),
        span: true),
    GallerySpecimen('无面板 kind · 行惰性(block/memory 不放死链)',
        (c) => ToolHitList(rows: [
              ToolHitRow(glyph: AnIcons.entityKindGlyph('block'), title: 'block: 定价规则草案', kind: 'block', id: 'bk_1'),
              ToolHitRow(glyph: AnIcons.entityKindGlyph('memory'), title: 'memory: 用户偏好', kind: 'memory', id: 'mem_1'),
            ], cap: 20, onRowTap: (_, _) {}),
        span: true),
  ],
);
