import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_row.dart';
import 'package:anselm/features/entities/state/rail_sort.dart';
import 'package:flutter_test/flutter_test.dart';

// The rail's in-section ordering. recent = newest updatedAt first, created = newest createdAt first
// (both name tiebreak), name = A→Z (id tiebreak); all stable + non-mutating. created is given its own
// axis so a row can be old-by-update yet new-by-create (and vice versa).

EntityRow _row(String id, String name, DateTime updated, {DateTime? created}) => EntityRow(
      kind: EntityKind.function,
      id: id,
      name: name,
      createdAt: created ?? updated,
      updatedAt: updated,
    );

void main() {
  final t1 = DateTime.utc(2026, 6, 1);
  final t2 = DateTime.utc(2026, 6, 2);
  final t3 = DateTime.utc(2026, 6, 3);

  test('recent → newest updatedAt first', () {
    final rows = [_row('a', 'alpha', t1), _row('b', 'beta', t3), _row('c', 'gamma', t2)];
    final out = sortRows(rows, RailSort.recent);
    expect(out.map((r) => r.id), ['b', 'c', 'a']);
  });

  test('created → newest createdAt first (independent of updatedAt)', () {
    // updatedAt is identical across all three, so only createdAt drives the order.
    final rows = [
      _row('a', 'alpha', t3, created: t1),
      _row('b', 'beta', t3, created: t3),
      _row('c', 'gamma', t3, created: t2),
    ];
    final out = sortRows(rows, RailSort.created);
    expect(out.map((r) => r.id), ['b', 'c', 'a']);
  });

  test('created ties break by name (deterministic)', () {
    final rows = [_row('a', 'beta', t2, created: t1), _row('b', 'alpha', t3, created: t1)];
    expect(sortRows(rows, RailSort.created).map((r) => r.id), ['b', 'a']);
  });

  test('name → case-insensitive A→Z', () {
    final rows = [_row('a', 'Zebra', t1), _row('b', 'apple', t2), _row('c', 'Mango', t3)];
    final out = sortRows(rows, RailSort.name);
    expect(out.map((r) => r.name), ['apple', 'Mango', 'Zebra']);
  });

  test('recent ties break by name (deterministic, no jitter)', () {
    final rows = [_row('a', 'beta', t1), _row('b', 'alpha', t1)];
    expect(sortRows(rows, RailSort.recent).map((r) => r.id), ['b', 'a']);
  });

  test('does not mutate the input list', () {
    final rows = [_row('a', 'b', t1), _row('b', 'a', t2)];
    final before = [...rows];
    sortRows(rows, RailSort.name);
    expect(rows, before);
  });
}
