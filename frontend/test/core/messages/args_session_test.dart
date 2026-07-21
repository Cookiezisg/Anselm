import 'package:anselm/core/messages/args_session.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:flutter_test/flutter_test.dart';

// argsSessionOf (WRK-061 W0) — the per-node incremental args parse: feeds only the unseen tail on each
// access (same session instance across reads), rebuilds ONCE on the open→closed source flip (delta →
// close snapshot), and rebuilds on a shrinking text. 每节点增量 args 会话:只喂未见尾段、关帧翻转重建一次。

const _scope = StreamScope(kind: 'conversation', id: 'cv');

void main() {
  test(
    'live: same session across reads; only the tail is fed; events accumulate',
    () {
      final r = BlockTreeReducer()
        ..apply(
          const StreamEnvelope(
            seq: 1,
            scope: _scope,
            id: 'tc',
            frame: FrameOpen(
              node: StreamNode(
                type: 'tool_call',
                content: {'name': 'create_document'},
              ),
            ),
          ),
        );
      final node = r.nodeById('tc')!;

      r.apply(
        const StreamEnvelope(
          seq: 0,
          scope: _scope,
          id: 'tc',
          frame: FrameDelta(chunk: '{"name":"n",'),
        ),
      );
      final s1 = argsSessionOf(node);
      expect(s1.events.single.value, 'n');

      r.apply(
        const StreamEnvelope(
          seq: 0,
          scope: _scope,
          id: 'tc',
          frame: FrameDelta(chunk: '"content":"hel'),
        ),
      );
      final s2 = argsSessionOf(node);
      expect(
        identical(s2, s1),
        isTrue,
      ); // SAME session — incremental, not rebuilt 同一会话,增量非重建
      expect(s2.inFlightStringAt(['content']), 'hel');
      expect(s2.liveStringNamed('content'), 'hel');

      r.apply(
        const StreamEnvelope(
          seq: 0,
          scope: _scope,
          id: 'tc',
          frame: FrameDelta(chunk: 'lo"}'),
        ),
      );
      expect(argsSessionOf(node).closedValueAt(['content']), 'hello');
    },
  );

  test(
    'open→closed flip (delta → snapshot) rebuilds the session ONCE from the snapshot',
    () {
      final r = BlockTreeReducer()
        ..apply(
          const StreamEnvelope(
            seq: 1,
            scope: _scope,
            id: 'tc',
            frame: FrameOpen(
              node: StreamNode(type: 'tool_call', content: {'name': 'Write'}),
            ),
          ),
        );
      final node = r.nodeById('tc')!;
      r.apply(
        const StreamEnvelope(
          seq: 0,
          scope: _scope,
          id: 'tc',
          frame: FrameDelta(chunk: '{"content":"par'),
        ),
      );
      final live = argsSessionOf(node);
      expect(live.inFlightStringAt(['content']), 'par');

      // Close with the FULL snapshot (byte-wise different from the truncated deltas). 关帧带完整快照。
      r.apply(
        const StreamEnvelope(
          seq: 2,
          scope: _scope,
          id: 'tc',
          frame: FrameClose(
            status: 'completed',
            result: StreamNode(
              type: 'tool_call',
              content: {
                'name': 'Write',
                'arguments': '{"content":"partial no more"}',
              },
            ),
          ),
        ),
      );
      final settled = argsSessionOf(node);
      expect(identical(settled, live), isFalse); // rebuilt 已重建
      expect(settled.closedValueAt(['content']), 'partial no more');
      expect(settled.done, isTrue);
      // A second read after the flip returns the SAME rebuilt session (once, not every read). 只重建一次。
      expect(identical(argsSessionOf(node), settled), isTrue);
    },
  );

  test('a node closed from the start (hydration) parses its snapshot once', () {
    final r = BlockTreeReducer()
      ..apply(
        const StreamEnvelope(
          seq: 1,
          scope: _scope,
          id: 'tc',
          frame: FrameOpen(
            node: StreamNode(type: 'tool_call', content: {'name': 'Bash'}),
          ),
        ),
      )
      ..apply(
        const StreamEnvelope(
          seq: 2,
          scope: _scope,
          id: 'tc',
          frame: FrameClose(
            status: 'completed',
            result: StreamNode(
              type: 'tool_call',
              content: {'name': 'Bash', 'arguments': '{"command":"ls"}'},
            ),
          ),
        ),
      );
    final node = r.nodeById('tc')!;
    final s = argsSessionOf(node);
    expect(s.closedValueAt(['command']), 'ls');
    expect(identical(argsSessionOf(node), s), isTrue);
  });
}
