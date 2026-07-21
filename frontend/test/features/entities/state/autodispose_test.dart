import 'dart:async';

import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/state/detail/entity_detail_provider.dart';
import 'package:anselm/features/entities/state/run/run_terminal_controller.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 6 follow-up — the deliberate autoDispose policy. The detail + run-terminal FAMILIES free their
// notifiers (and their SSE subscriptions) when the entity is deselected (no watcher), so browsing N
// entities doesn't leak N subscription sets. A RUN pins its controller via keepAlive so it keeps streaming
// in the BACKGROUND across deselection, then frees once it settles. "Freed" is observed as a FRESH notifier
// instance on the next read (a non-autoDispose family would hand back the same cached instance forever).

const _fnRef = EntityRef(EntityKind.function, 'fn_1');
final _t = DateTime.utc(2026, 6, 27);
FunctionEntity _fn() =>
    FunctionEntity(id: 'fn_1', name: 'f', createdAt: _t, updatedAt: _t);

FixtureEntityRepository _repo() =>
    FixtureEntityRepository(runDelay: Duration.zero, functions: [_fn()]);

/// A repo whose `runFunction` is gated on a [Completer], so a run can be held open while we deselect.
/// 运行被 Completer 闸控,使我们能在运行进行中切走选区。
class _GatedRepo extends FixtureEntityRepository {
  _GatedRepo() : super(runDelay: Duration.zero, functions: [_fn()]);
  final gate = Completer<FunctionRunResult>();
  @override
  Future<FunctionRunResult> runFunction(
    String id, {
    required Map<String, dynamic> args,
    int? version,
  }) => gate.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // the run controller's CoalescingNotifier touches SchedulerBinding

  test(
    'entityDetailProvider frees on deselect (fresh instance on re-select)',
    () async {
      final c = ProviderContainer(
        overrides: [entityRepositoryProvider.overrideWithValue(_repo())],
      );
      addTearDown(c.dispose);
      final sub = c.listen(
        entityDetailProvider(_fnRef),
        (_, _) {},
      ); // "selected"
      final first = c.read(entityDetailProvider(_fnRef).notifier);
      sub.close(); // "deselect" → no watcher
      await pumpEventQueue();
      final second = c.read(entityDetailProvider(_fnRef).notifier);
      expect(
        identical(first, second),
        isFalse,
      ); // disposed + rebuilt → its life/panel subs were cancelled
    },
  );

  test('runTerminalProvider frees on deselect when idle (no run)', () async {
    final c = ProviderContainer(
      overrides: [entityRepositoryProvider.overrideWithValue(_repo())],
    );
    addTearDown(c.dispose);
    final sub = c.listen(runTerminalProvider(_fnRef), (_, _) {});
    final first = c.read(runTerminalProvider(_fnRef).notifier);
    sub.close();
    await pumpEventQueue();
    final second = c.read(runTerminalProvider(_fnRef).notifier);
    expect(
      identical(first, second),
      isFalse,
    ); // freed → its panel subscription was cancelled
  });

  test(
    'a run pins the controller across deselect (background streaming), frees after it settles',
    () async {
      final repo = _GatedRepo();
      final c = ProviderContainer(
        overrides: [entityRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      final sub = c.listen(runTerminalProvider(_fnRef), (_, _) {});
      final ctl = c.read(runTerminalProvider(_fnRef).notifier);

      final runFut = ctl
          .run(); // keepAlive taken synchronously, before the gated await
      sub.close(); // deselect WHILE the run is in flight
      await pumpEventQueue();
      // keepAlive pinned it → still the SAME controller (the run keeps streaming in the background).
      expect(
        identical(c.read(runTerminalProvider(_fnRef).notifier), ctl),
        isTrue,
      );

      repo.gate.complete(const FunctionRunResult(ok: true));
      await runFut; // the run settles → its `finally` releases the keepAlive
      await pumpEventQueue();
      // now unpinned + unwatched → freed; re-selecting builds a fresh controller.
      expect(
        identical(c.read(runTerminalProvider(_fnRef).notifier), ctl),
        isFalse,
      );
    },
  );
}
