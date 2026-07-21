import 'package:anselm/core/contract/interaction.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/pending_interactions_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The three-source interaction truth (WRK-056 F16 §族律4): ephemeral signal ⊕ GET snapshot ⊕ resolved
// signal, keyed by toolCallId. Batteries: signal adds, resolved removes, snapshot seeds, resolve()
// freezes optimistically + records the POST, POST failure restores (fail-safe), and a resolution signal
// never erases a locally-decided provenance章.

const _conv = 'conv_1';

StreamEnvelope _sig(String toolCallId, Map<String, dynamic> content) =>
    StreamEnvelope(
      seq: 0,
      scope: const StreamScope(kind: 'conversation', id: _conv),
      id: toolCallId,
      frame: FrameSignal(
        node: StreamNode(type: 'interaction', content: content),
      ),
    );

StreamEnvelope _danger(String id) => _sig(id, {
  'toolCallId': id,
  'kind': 'danger',
  'tool': 'Bash',
  'conversationId': _conv,
  'prompt': {
    'summary': 'run it',
    'args': {'command': 'rm -rf x'},
  },
});

StreamEnvelope _ask(String id, {List<String>? options}) => _sig(id, {
  'toolCallId': id,
  'kind': 'ask',
  'tool': 'ask_user',
  'conversationId': _conv,
  'prompt': {'message': 'Which day?', 'options': ?options},
});

StreamEnvelope _resolved(String id) => _sig(id, {
  'toolCallId': id,
  'kind': '',
  'tool': '',
  'conversationId': _conv,
  'resolved': true,
});

ProviderContainer _container(FixtureChatRepository repo) {
  final c = ProviderContainer(
    overrides: [chatRepositoryProvider.overrideWithValue(repo)],
  );
  // Keep the autoDispose family alive (mirrors a mounted transcript). 保活(镜像挂载的 transcript)。
  c.listen(pendingInteractionsProvider(_conv), (_, _) {});
  addTearDown(c.dispose);
  return c;
}

Map<String, InteractionRecord> _map(ProviderContainer c) =>
    c.read(pendingInteractionsProvider(_conv));

// Let build's subscription + the async snapshot fetch + a broadcast delivery flush. 让订阅/异步快照/广播投递泄流。
Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('ephemeral danger signal records an AWAITING interaction', () async {
    final repo = FixtureChatRepository();
    final c = _container(repo);
    await _tick();
    repo.emitFrame(_conv, _danger('blk_1'));
    await _tick();
    final rec = _map(c)['blk_1']!;
    expect(rec.isAwaiting, isTrue);
    expect(rec.decided, isNull);
    expect(rec.interaction.kind, InteractionKind.danger);
    expect(rec.interaction.summary, 'run it');
    expect(rec.interaction.args, {'command': 'rm -rf x'});
  });

  test('ask signal carries message + options', () async {
    final repo = FixtureChatRepository();
    final c = _container(repo);
    await _tick();
    repo.emitFrame(_conv, _ask('blk_2', options: ['Mon', 'Tue']));
    await _tick();
    final rec = _map(c)['blk_2']!;
    expect(rec.interaction.kind, InteractionKind.ask);
    expect(rec.interaction.message, 'Which day?');
    expect(rec.interaction.options, ['Mon', 'Tue']);
  });

  test('resolution signal removes an awaiting record', () async {
    final repo = FixtureChatRepository();
    final c = _container(repo);
    await _tick();
    repo.emitFrame(_conv, _danger('blk_1'));
    await _tick();
    expect(_map(c).containsKey('blk_1'), isTrue);
    repo.emitFrame(_conv, _resolved('blk_1'));
    await _tick();
    expect(_map(c).containsKey('blk_1'), isFalse);
  });

  test('GET snapshot seeds the reconnect truth', () async {
    final repo = FixtureChatRepository()
      ..interactions[_conv] = [
        const Interaction(
          toolCallId: 'blk_seed',
          kind: InteractionKind.danger,
          tool: 'delete_agent',
          resolved: false,
          summary: 'delete it',
        ),
      ];
    final c = _container(repo);
    await _tick();
    final rec = _map(c)['blk_seed']!;
    expect(rec.isAwaiting, isTrue);
    expect(rec.interaction.tool, 'delete_agent');
  });

  test(
    'a live signal wins over a stale snapshot row for the same toolCallId',
    () async {
      // Snapshot says awaiting; but a resolved signal already landed → the live truth (removed) holds.
      final repo = FixtureChatRepository()
        ..interactions[_conv] = [
          const Interaction(
            toolCallId: 'blk_x',
            kind: InteractionKind.danger,
            tool: 'Bash',
            resolved: false,
          ),
        ];
      final c = _container(repo);
      // Force the signal to land BEFORE the snapshot merge by emitting immediately, then tick once.
      repo.emitFrame(_conv, _danger('blk_x'));
      await _tick();
      repo.emitFrame(_conv, _resolved('blk_x'));
      await _tick();
      expect(
        _map(c).containsKey('blk_x'),
        isFalse,
        reason: 'resolved live signal wins over snapshot',
      );
    },
  );

  test(
    'a mid-session resync RE-FETCHES interactions — a gate raised in the disconnect appears (M6)',
    () async {
      final repo = FixtureChatRepository();
      final c = _container(repo);
      await _tick();
      expect(_map(c), isEmpty); // cold build sees no gate
      // A danger gate was raised while disconnected — its ephemeral signal was lost, but GET interactions
      // now lists it. A resync must re-fetch it (else the gate never shows + the turn stays blocked).
      repo.interactions[_conv] = [
        const Interaction(
          toolCallId: 'blk_late',
          kind: InteractionKind.danger,
          tool: 'Bash',
          resolved: false,
        ),
      ];
      repo.emitResync();
      await _tick();
      expect(_map(c)['blk_late']?.isAwaiting, isTrue);
    },
  );

  test(
    'a resync PRUNES a phantom awaiting gate the snapshot no longer lists (M6)',
    () async {
      final repo = FixtureChatRepository()
        ..interactions[_conv] = [
          const Interaction(
            toolCallId: 'blk_ph',
            kind: InteractionKind.danger,
            tool: 'delete_agent',
            resolved: false,
          ),
        ];
      final c = _container(repo);
      await _tick();
      expect(_map(c)['blk_ph']?.isAwaiting, isTrue);
      // Resolved elsewhere during the disconnect → gone from the authoritative snapshot. A resync prunes it.
      repo.interactions[_conv] = [];
      repo.emitResync();
      await _tick();
      expect(_map(c).containsKey('blk_ph'), isFalse);
    },
  );

  test('resolve() freezes optimistically + records the POST action', () async {
    final repo = FixtureChatRepository();
    final c = _container(repo);
    await _tick();
    repo.emitFrame(_conv, _danger('blk_1'));
    await _tick();
    await c
        .read(pendingInteractionsProvider(_conv).notifier)
        .resolve('blk_1', InteractionAction.approve);
    final rec = _map(c)['blk_1']!;
    expect(rec.isAwaiting, isFalse);
    expect(rec.decided, InteractionAction.approve);
    expect(repo.resolvedInteractions.single.toolCallId, 'blk_1');
    expect(repo.resolvedInteractions.single.action, InteractionAction.approve);
  });

  test('resolve() with an answer forwards it (ask accept)', () async {
    final repo = FixtureChatRepository();
    final c = _container(repo);
    await _tick();
    repo.emitFrame(_conv, _ask('blk_2', options: ['Mon']));
    await _tick();
    await c
        .read(pendingInteractionsProvider(_conv).notifier)
        .resolve('blk_2', InteractionAction.accept, answer: 'Tuesday');
    expect(repo.resolvedInteractions.single.answer, 'Tuesday');
    expect(_map(c)['blk_2']!.decided, InteractionAction.accept);
  });

  test(
    'POST failure restores the awaiting record (fail-safe: nothing executed)',
    () async {
      final repo = FixtureChatRepository()..failNextResolve = true;
      final c = _container(repo);
      await _tick();
      repo.emitFrame(_conv, _danger('blk_1'));
      await _tick();
      await expectLater(
        c
            .read(pendingInteractionsProvider(_conv).notifier)
            .resolve('blk_1', InteractionAction.approve),
        throwsA(isA<StateError>()),
      );
      final rec = _map(c)['blk_1']!;
      expect(rec.isAwaiting, isTrue, reason: 'restored so the user can retry');
      expect(rec.decided, isNull);
    },
  );

  test(
    'a resolution signal does NOT erase a locally-decided provenance章',
    () async {
      final repo = FixtureChatRepository();
      final c = _container(repo);
      await _tick();
      repo.emitFrame(_conv, _danger('blk_1'));
      await _tick();
      await c
          .read(pendingInteractionsProvider(_conv).notifier)
          .resolve('blk_1', InteractionAction.approve);
      // Our own POST echoes back a resolved signal — the frozen章 must survive it. 自身回声不得抹章。
      repo.emitFrame(_conv, _resolved('blk_1'));
      await _tick();
      final rec = _map(c)['blk_1']!;
      expect(
        rec.decided,
        InteractionAction.approve,
        reason: 'the approve章 is session provenance',
      );
    },
  );

  test('resolve() on an unknown / already-decided record is a no-op', () async {
    final repo = FixtureChatRepository();
    final c = _container(repo);
    await _tick();
    await c
        .read(pendingInteractionsProvider(_conv).notifier)
        .resolve('nope', InteractionAction.deny);
    expect(repo.resolvedInteractions, isEmpty);
  });
}
