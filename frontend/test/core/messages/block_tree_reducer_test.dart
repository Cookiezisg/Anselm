import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 5 gate (pure model) — the BlockTreeReducer folds open/delta/close into a nested tree: live deltas
// before close, the close snapshot wins, E3 parentId nesting, danger/args on tool_call, and defensive
// handling of unknown types / orphan frames / signals (no throw, no spurious node).

const _scope = StreamScope(kind: 'agent', id: 'a');

StreamEnvelope _open(
  String id,
  String type, {
  String? parent,
  Map<String, dynamic>? content,
}) => StreamEnvelope(
  seq: 1,
  scope: _scope,
  id: id,
  frame: FrameOpen(
    parentId: parent,
    node: StreamNode(type: type, content: content),
  ),
);
StreamEnvelope _delta(String id, String chunk) => StreamEnvelope(
  seq: 0,
  scope: _scope,
  id: id,
  frame: FrameDelta(chunk: chunk),
);
StreamEnvelope _close(String id, String type, Map<String, dynamic> content) =>
    StreamEnvelope(
      seq: 2,
      scope: _scope,
      id: id,
      frame: FrameClose(
        status: 'completed',
        result: StreamNode(type: type, content: content),
      ),
    );
StreamEnvelope _closeBare(
  String id, {
  String status = 'completed',
  String? error,
}) => StreamEnvelope(
  seq: 2,
  scope: _scope,
  id: id,
  frame: FrameClose(status: status, error: error),
);

void main() {
  // P5 (C-025 linchpin) — `revision` is a SUBTREE-MAX: `_bump` walks from the changed node up through
  // every ancestor, so a change to a NESTED subagent block also bumps its parent tool_call's revision.
  // This is what makes a `liveBlock(parentId).revision` selector safe — it cannot miss a nested update.
  // C-025 命门:revision 是子树最大值(_bump 上抛全祖先),嵌套子块变更也抬父块 revision→父块 revision 选择器不漏嵌套。
  test(
    'revision is a subtree-max: a nested/descendant change bumps every ancestor',
    () {
      final r = BlockTreeReducer();
      r.apply(_open('parent', 'tool_call', content: {'name': 'delegate'}));
      r.apply(
        _open('child', 'message', parent: 'parent'),
      ); // a nested subagent block 嵌套子块
      final revA = r.nodeById('parent')!.revision;

      r.apply(_delta('child', 'x')); // change the CHILD 改子块
      expect(
        r.nodeById('parent')!.revision,
        greaterThan(revA),
        reason:
            'a nested change must propagate to the ancestor revision, else a parent-revision selector '
            'would miss nested subagent-tree updates (stale UI)',
      );

      final revB = r.nodeById('parent')!.revision;
      r.apply(
        _open('grandchild', 'text', parent: 'child'),
      ); // deeper still 更深一层
      r.apply(_delta('grandchild', 'y'));
      expect(
        r.nodeById('parent')!.revision,
        greaterThan(revB),
        reason:
            'a grandchild change must also reach the root ancestor revision',
      );
    },
  );

  test('open→delta→close: live deltas before close, snapshot wins after', () {
    final r = BlockTreeReducer();
    r.apply(_open('b1', 'text'));
    r.apply(_delta('b1', 'Hel'));
    r.apply(_delta('b1', 'lo'));
    expect(r.roots.single.displayText, 'Hello'); // live deltas
    r.apply(_close('b1', 'text', {'content': 'Hello world'}));
    expect(r.roots.single.kind, BlockKind.text);
    expect(r.roots.single.displayText, 'Hello world'); // durable snapshot wins
    expect(r.roots.single.status, 'completed');
  });

  test('tool_result nests under its tool_call (E3 parentId)', () {
    final r = BlockTreeReducer();
    r.apply(_open('tc', 'tool_call', content: {'name': 'web-search'}));
    r.apply(
      _open('tr', 'tool_result', parent: 'tc', content: {'content': '3 hits'}),
    );
    r.apply(_closeBare('tr'));
    expect(r.roots.length, 1); // only the tool_call is a root
    final tc = r.roots.single;
    expect(tc.kind, BlockKind.toolCall);
    expect(tc.name, 'web-search');
    expect(tc.children.single.kind, BlockKind.toolResult);
    expect(tc.children.single.displayText, '3 hits');
  });

  test('tool_call carries danger + the final arguments snapshot', () {
    final r = BlockTreeReducer();
    r.apply(_open('tc', 'tool_call', content: {'name': 'rm'}));
    r.apply(_delta('tc', '{"path"'));
    r.apply(
      _close('tc', 'tool_call', {
        'name': 'rm',
        'arguments': '{"path":"/"}',
        'danger': 'dangerous',
      }),
    );
    final tc = r.roots.single;
    expect(tc.danger, 'dangerous');
    expect(tc.argumentsText, '{"path":"/"}');
  });

  test('unknown node type → BlockKind.unknown (forward-compat, no throw)', () {
    final r = BlockTreeReducer();
    r.apply(_open('x', 'some_future_type'));
    expect(r.roots.single.kind, BlockKind.unknown);
  });

  test('orphan delta/close for an unseen id is a no-op', () {
    final r = BlockTreeReducer();
    r.apply(_delta('ghost', 'x'));
    r.apply(_closeBare('ghost'));
    expect(r.isEmpty, isTrue);
  });

  test('a signal builds no tree node', () {
    final r = BlockTreeReducer();
    r.apply(
      StreamEnvelope(
        seq: 0,
        scope: const StreamScope(kind: 'workflow'),
        id: 's',
        frame: const FrameSignal(
          node: StreamNode(type: 'run', content: {'nodeId': 'n1'}),
        ),
      ),
    );
    expect(r.isEmpty, isTrue);
  });

  test('open with an unseen parent attaches to roots (defensive)', () {
    final r = BlockTreeReducer();
    r.apply(_open('child', 'text', parent: 'missing'));
    expect(r.roots.single.id, 'child');
  });

  test('error close marks isError + carries the error', () {
    final r = BlockTreeReducer();
    r.apply(_open('tr', 'tool_result', content: {'content': ''}));
    r.apply(_closeBare('tr', status: 'error', error: 'boom'));
    expect(r.roots.single.isError, isTrue);
    expect(r.roots.single.error, 'boom');
  });

  test('re-open of the same id is idempotent (no duplicate node)', () {
    final r = BlockTreeReducer();
    r.apply(_open('b1', 'text'));
    r.apply(_open('b1', 'text'));
    expect(r.roots.length, 1);
    expect(r.nodeCount, 1);
  });

  // ── WRK-061 W0: revision / memoization / delta release ──────────────────────────────────────────

  test(
    'revision: every frame bumps the node AND its ancestor chain (subtree version)',
    () {
      final r = BlockTreeReducer();
      r.apply(_open('tc', 'tool_call'));
      final tc = r.nodeById('tc')!;
      final r0 = tc.revision;
      r.apply(_open('tr', 'tool_result', parent: 'tc'));
      expect(
        tc.revision,
        greaterThan(r0),
      ); // child open bumps the parent 子块 open 抬父版本
      final r1 = tc.revision;
      r.apply(_delta('tr', 'partial'));
      expect(
        tc.revision,
        greaterThan(r1),
      ); // child delta bumps the parent 子块 delta 抬父版本
      final r2 = tc.revision;
      r.apply(_closeBare('tr'));
      expect(
        tc.revision,
        greaterThan(r2),
      ); // child close bumps the parent 子块 close 抬父版本
    },
  );

  test(
    'deltaText is memoized by length (same instance until the buffer grows)',
    () {
      final r = BlockTreeReducer();
      r.apply(_open('b1', 'text'));
      r.apply(_delta('b1', 'abc'));
      final n = r.nodeById('b1')!;
      expect(identical(n.deltaText, n.deltaText), isTrue); // 同长→同实例
      final before = n.deltaText;
      r.apply(_delta('b1', 'd'));
      expect(n.deltaText, 'abcd');
      expect(identical(n.deltaText, before), isFalse);
    },
  );

  test(
    'close WITH a covering snapshot releases the delta buffer (no double residency)',
    () {
      final r = BlockTreeReducer();
      r.apply(_open('b1', 'text'));
      r.apply(_delta('b1', 'Hello'));
      r.apply(_close('b1', 'text', {'content': 'Hello world'}));
      final n = r.nodeById('b1')!;
      expect(n.deltaText, isEmpty); // buffer freed 缓冲已释放
      expect(n.displayText, 'Hello world'); // snapshot is the truth 快照即真相

      // tool_call: the covering key is `arguments`. tool_call 的覆盖键是 arguments。
      r.apply(_open('tc', 'tool_call', content: {'name': 'rm'}));
      r.apply(_delta('tc', '{"path"'));
      r.apply(
        _close('tc', 'tool_call', {'name': 'rm', 'arguments': '{"path":"/"}'}),
      );
      final tc = r.nodeById('tc')!;
      expect(tc.deltaText, isEmpty);
      expect(tc.argumentsText, '{"path":"/"}');
    },
  );

  test(
    'close WITHOUT a covering snapshot keeps the delta buffer (honest fallback intact)',
    () {
      final r = BlockTreeReducer();
      r.apply(_open('tc', 'tool_call', content: {'name': 'rm'}));
      r.apply(_delta('tc', '{"path":"/tmp"}'));
      // close snapshot lacks `arguments` — argumentsText must still render the streamed fragment.
      // close 快照缺 arguments——argumentsText 仍须渲已流入片段。
      r.apply(_close('tc', 'tool_call', {'name': 'rm'}));
      expect(r.nodeById('tc')!.argumentsText, '{"path":"/tmp"}');
    },
  );

  test('derivedCache slot: a frame invalidates the owner\'s revision key', () {
    final r = BlockTreeReducer();
    r.apply(_open('tc', 'tool_call'));
    final n = r.nodeById('tc')!;
    n.derivedCache = 'projection';
    n.derivedCacheRev = n.revision;
    expect(n.derivedCacheRev == n.revision, isTrue);
    r.apply(_delta('tc', '{'));
    expect(
      n.derivedCacheRev == n.revision,
      isFalse,
    ); // stale → owner re-derives 过期→重派生
  });
}
