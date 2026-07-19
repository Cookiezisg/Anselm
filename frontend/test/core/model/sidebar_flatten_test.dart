import 'package:anselm/core/model/sidebar_flatten.dart';
import 'package:anselm/core/model/sidebar_model.dart';
import 'package:flutter_test/flutter_test.dart';

// The pure flatten core of the virtualized sidebar (slice 2, stage A) — driven entirely through
// SidebarModel, no widget pump. Pins: groups→types→rows flatten with section heads + a pagination
// footer; collapse hides descendants (semantic keys, no positional fusing); a query keeps matches +
// force-expands ancestors; the ancestor chain is carried for sticky; five-battery edges.

SidebarModel _model() => SidebarModel(groups: [
      // label-null group with two icon'd sections (mirrors entities/chat): one paginated, one with a tree
      SidebarGroup(types: [
        SidebarType(label: 'Functions', pageKey: 'function', hasMore: true, rows: const [
          SidebarRow(id: 'fn1', label: 'alpha'),
          SidebarRow(id: 'fn2', label: 'beta'),
        ]),
        SidebarType(label: 'Docs', rows: [
          SidebarRow(id: 'd1', label: 'docs', children: const [
            SidebarRow(id: 'd2', label: 'guide'),
          ]),
        ]),
      ]),
    ]);

void main() {
  test('flattens groups→types→rows with section heads + a pagination footer', () {
    final flat = flattenSidebar(_model());
    expect(flat.map((n) => n.kind), [
      SidebarNodeKind.typeHead, // Functions
      SidebarNodeKind.row, SidebarNodeKind.row, // fn1, fn2
      SidebarNodeKind.footer, // Functions footer (hasMore)
      SidebarNodeKind.typeHead, // Docs
      SidebarNodeKind.row, SidebarNodeKind.row, // docs (branch), guide
    ]);
  });

  test('depth: label-null group → head + rows at 0, branch child at +1', () {
    final flat = flattenSidebar(_model());
    expect(flat.firstWhere((n) => n.type?.label == 'Docs').depth, 0); // section head
    expect(flat.firstWhere((n) => n.row?.id == 'd1').depth, 0); // row sits at the head's level
    expect(flat.firstWhere((n) => n.row?.id == 'd2').depth, 1); // branch child nests +1
  });

  test('collapsed section contributes its head only — no rows, no footer', () {
    final flat = flattenSidebar(_model(), collapsed: {'t:function'});
    expect(flat.any((n) => n.row?.id == 'fn1'), isFalse);
    expect(flat.any((n) => n.row?.id == 'fn2'), isFalse);
    expect(flat.any((n) => n.type?.label == 'Functions'), isTrue); // head stays
    expect(flat.any((n) => n.kind == SidebarNodeKind.footer), isFalse); // footer gone under a collapsed section
  });

  test('collapsed branch row hides its children', () {
    final flat = flattenSidebar(_model(), collapsed: {'r:d1'});
    expect(flat.any((n) => n.row?.id == 'd1'), isTrue); // docs head stays
    expect(flat.any((n) => n.row?.id == 'd2'), isFalse); // guide hidden
  });

  test('ancestor chain: a deep row carries its section head + branch head', () {
    final guide = flattenSidebar(_model()).firstWhere((n) => n.row?.id == 'd2');
    expect(guide.ancestors.map((a) => a.type?.label ?? a.row?.id), ['Docs', 'd1']);
  });

  test('query keeps only matching rows + force-expands ancestors, drops the footer', () {
    final flat = flattenSidebar(_model(), query: 'guide');
    expect(flat.any((n) => n.row?.id == 'd2'), isTrue); // the match
    expect(flat.any((n) => n.row?.id == 'd1'), isTrue); // ancestor revealed
    expect(flat.any((n) => n.row?.id == 'fn1'), isFalse); // non-match dropped
    expect(flat.any((n) => n.type?.label == 'Functions'), isFalse); // section with no visible row dropped
    expect(flat.any((n) => n.kind == SidebarNodeKind.footer), isFalse); // search paginates via re-fetch, not the tail
  });

  test('semantic fold keys — folding one section never fuses with a sibling', () {
    final flat = flattenSidebar(_model(), collapsed: {'t:function'});
    expect(flat.any((n) => n.row?.id == 'd1'), isTrue); // Docs unaffected by Functions being folded
  });

  // ── five-battery ──────────────────────────────────────────────────────────
  test('battery empty: empty model → empty flat', () {
    expect(flattenSidebar(const SidebarModel()), isEmpty);
  });

  test('battery massive: a 5000-row section flattens without blowup', () {
    final big = SidebarModel(groups: [
      SidebarGroup(types: [
        SidebarType(label: 'All', rows: [for (var i = 0; i < 5000; i++) SidebarRow(id: 'a$i', label: 'e$i')]),
      ]),
    ]);
    expect(flattenSidebar(big).length, 5001); // 1 head + 5000 rows
  });

  test('battery injection/overlong: markup + long labels are inert plain data (no throw)', () {
    final m = SidebarModel(groups: [
      SidebarGroup(types: [
        SidebarType(label: '<b>x</b> & 很长' * 20, rows: const [SidebarRow(id: 'x', label: '注入 <i>y</i>')]),
      ]),
    ]);
    expect(() => flattenSidebar(m, query: '<i>'), returnsNormally);
  });
}
