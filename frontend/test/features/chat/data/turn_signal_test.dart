import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/data/turn_signal.dart';
import 'package:flutter_test/flutter_test.dart';

// The dots' frame filter — the PURE mapper the raw workspace feed runs through. Pins: durable
// top-level message open/close map, everything else (deltas, block frames, nested opens, foreign
// scopes) dies here, interaction signals map regardless of seq.
// 活态点的帧过滤纯函数。钉:顶层耐久 message open/close 映射;delta/块帧/嵌套 open/异 scope 全灭;
// interaction 信号无论 seq 都映射。

const _scope = StreamScope(kind: 'conversation', id: 'cv_1');

StreamEnvelope _env(StreamFrame f, {int seq = 5, StreamScope scope = _scope}) =>
    StreamEnvelope(seq: seq, scope: scope, id: 'x', frame: f);

void main() {
  test('durable top-level message open → turnOpen', () {
    final s = turnSignalFromEnvelope(
        _env(const FrameOpen(node: StreamNode(type: 'message', content: {'role': 'user'}))));
    expect(s, (conversationId: 'cv_1', kind: TurnSignalKind.turnOpen));
  });

  test('durable message close → turnClose (any status)', () {
    final s = turnSignalFromEnvelope(_env(const FrameClose(
        status: 'error',
        result: StreamNode(type: 'message', content: {'status': 'error'}))));
    expect(s, (conversationId: 'cv_1', kind: TurnSignalKind.turnClose));
  });

  test('interaction signal maps even at seq=0 (ephemeral by design)', () {
    final s = turnSignalFromEnvelope(
        _env(const FrameSignal(node: StreamNode(type: 'interaction')), seq: 0));
    expect(s?.kind, TurnSignalKind.interaction);
  });

  test('noise dies: deltas, block frames, nested message opens, ephemeral opens, foreign scopes', () {
    expect(turnSignalFromEnvelope(_env(const FrameDelta(chunk: 'x'), seq: 0)), isNull);
    expect(
        turnSignalFromEnvelope(
            _env(const FrameOpen(node: StreamNode(type: 'text', content: {'content': ''})))),
        isNull); // block open 块帧
    expect(
        turnSignalFromEnvelope(_env(
            const FrameOpen(parentId: 'blk_1', node: StreamNode(type: 'message')))),
        isNull); // nested subagent open 嵌套
    expect(
        turnSignalFromEnvelope(
            _env(const FrameOpen(node: StreamNode(type: 'message')), seq: 0)),
        isNull); // ephemeral open 瞬时
    expect(
        turnSignalFromEnvelope(_env(
            const FrameClose(status: 'completed', result: StreamNode(type: 'text'))))
        , isNull); // block close 块 close
    expect(
        turnSignalFromEnvelope(_env(const FrameOpen(node: StreamNode(type: 'message')),
            scope: const StreamScope(kind: 'run', id: 'r1'))),
        isNull); // foreign scope 异 scope
  });
}
