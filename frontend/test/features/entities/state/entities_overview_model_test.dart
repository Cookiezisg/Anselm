import 'package:anselm/core/contract/entities/relation.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_row.dart';
import 'package:anselm/features/entities/state/entities_overview_model.dart';
import 'package:anselm/features/entities/state/entity_list_state.dart';
import 'package:anselm/features/entities/state/rail_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure projections behind the Entities Overview (WRK-072): structural subgraph, five-card counts,
/// recent top-N, relation groups. Headless.
EntityNode _n(String kind, String id) => EntityNode(kind: kind, id: id, name: id);
EntityRelation _e(String verb, String from, String to) =>
    EntityRelation(id: '$from>$to>$verb', kind: verb, fromId: from, toId: to);

EntityRow _row(EntityKind kind, String id, DateTime updated) =>
    EntityRow(kind: kind, id: id, name: id, createdAt: updated, updatedAt: updated);

RailGroup _group(EntityKind kind, List<EntityRow> rows) => RailGroup(
      kind: kind,
      state: AsyncData(EntityListState(rows: rows)),
    );

void main() {
  group('structuralSubgraph', () {
    final g = EntityRelGraph(
      nodes: [_n('workflow', 'wf'), _n('function', 'fn'), _n('conversation', 'cv'), _n('agent', 'ag')],
      edges: [
        _e('equip', 'wf', 'fn'),
        _e('link', 'ag', 'fn'),
        _e('create', 'cv', 'wf'), // provenance — dropped
        _e('edit', 'cv', 'fn'), // provenance — dropped
      ],
    );

    test('keeps only equip/link edges', () {
      final sub = structuralSubgraph(g);
      expect(sub.edges.map((e) => e.kind).toSet(), {'equip', 'link'});
      expect(sub.edges.length, 2);
    });

    test('keeps only nodes touched by a structural edge (drops the conversation)', () {
      final sub = structuralSubgraph(g);
      final ids = sub.nodes.map((n) => n.id).toSet();
      expect(ids, {'wf', 'fn', 'ag'});
      expect(ids.contains('cv'), isFalse, reason: 'the conversation node has no structural edge');
    });
  });

  group('overviewCounts', () {
    test('four Quadrinity + accessory total (trigger+control+approval)', () {
      final groups = [
        _group(EntityKind.function, [_row(EntityKind.function, 'a', DateTime(2026))]),
        _group(EntityKind.handler, []),
        _group(EntityKind.agent, [_row(EntityKind.agent, 'b', DateTime(2026)), _row(EntityKind.agent, 'c', DateTime(2026))]),
        _group(EntityKind.workflow, [_row(EntityKind.workflow, 'd', DateTime(2026))]),
        _group(EntityKind.trigger, [_row(EntityKind.trigger, 'e', DateTime(2026))]),
        _group(EntityKind.control, [_row(EntityKind.control, 'f', DateTime(2026))]),
        _group(EntityKind.approval, [_row(EntityKind.approval, 'g', DateTime(2026))]),
      ];
      final c = overviewCounts(groups);
      expect(c.function, 1);
      expect(c.handler, 0, reason: '0 is a real answer, not omitted');
      expect(c.agent, 2);
      expect(c.workflow, 1);
      expect(c.accessory, 3, reason: 'trigger + control + approval fold into Parts');
    });
  });

  group('recentEntities', () {
    test('merges all kinds, sorts updatedAt desc, takes top-N', () {
      final groups = [
        _group(EntityKind.function, [
          _row(EntityKind.function, 'old', DateTime(2026, 1, 1)),
          _row(EntityKind.function, 'newest', DateTime(2026, 6, 1)),
        ]),
        _group(EntityKind.workflow, [_row(EntityKind.workflow, 'mid', DateTime(2026, 3, 1))]),
      ];
      final recent = recentEntities(groups, max: 2);
      expect(recent.map((r) => r.id).toList(), ['newest', 'mid']);
    });

    test('deterministic tiebreak by name on equal updatedAt', () {
      final t = DateTime(2026, 5, 5);
      final groups = [
        _group(EntityKind.function, [_row(EntityKind.function, 'zeta', t), _row(EntityKind.function, 'alpha', t)]),
      ];
      expect(recentEntities(groups).map((r) => r.id).toList(), ['alpha', 'zeta']);
    });
  });

  group('relationGroupsFor', () {
    final edges = [
      _e('equip', 'x', 'a'), // x equips a (a is referenced-by x)
      _e('equip', 'y', 'x'), // y equips x (x referenced-by y)
      _e('link', 'x', 'b'), // x links b
      _e('link', 'z', 'x'), // z links x (x referenced-by z)
    ];

    test('splits equips (out equip) / referencedBy (in equip+link) / links (out link)', () {
      final g = relationGroupsFor('x', edges);
      expect(g.equips.map((e) => e.toId).toList(), ['a']);
      expect(g.links.map((e) => e.toId).toList(), ['b']);
      expect(g.referencedBy.map((e) => e.fromId).toSet(), {'y', 'z'});
    });

    test('a node with no edges has empty groups', () {
      expect(relationGroupsFor('none', edges).isEmpty, isTrue);
    });
  });
}
