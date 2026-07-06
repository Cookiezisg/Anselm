import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/messages/block_tree_reducer.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/features/chat/model/tool_card_state.dart';
import 'package:flutter_test/flutter_test.dart';

// The phase derivation contract (WRK-053 §2) — wire anchors, not heuristics: open=argsStreaming;
// closed-no-result=running; the four terminals split on the tool_result child (error status /
// the backend's FIXED deny/cancel prose / success). Plus the progress `text` wire asymmetry.
// 相位派生契约(WRK-053 §2)——线缆锚点非启发式;外加 progress `text` 键的线缆不对称。

BlockNode _call({String status = 'completed', Map<String, dynamic>? content}) =>
    BlockNode(id: 'tc_1', kind: BlockKind.toolCall)
      ..status = status
      ..content = content ?? {'name': 'run_function'};

BlockNode _result(String text, {bool error = false}) =>
    BlockNode(id: 'tr_1', kind: BlockKind.toolResult)
      ..status = error ? 'error' : 'completed'
      ..error = error ? text : null
      ..content = {'content': text};

void main() {
  test('open node → argsStreaming; streamed deltas surface as argsText', () {
    const scope = StreamScope(kind: 'conversation', id: 'cv_1');
    final r = BlockTreeReducer()
      ..apply(const StreamEnvelope(
          seq: 1, scope: scope, id: 'tc_1',
          frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'Bash'}))))
      ..apply(const StreamEnvelope(
          seq: 0, scope: scope, id: 'tc_1', frame: FrameDelta(chunk: '{"command":"ls')));
    final s = ToolCardState.of(r.roots.single);
    expect(s.phase, ToolCardPhase.argsStreaming);
    expect(s.toolName, 'Bash');
    expect(s.argsText, '{"command":"ls');
  });

  test('closed without tool_result → running; awaitingConfirm overlay wins', () {
    final node = _call();
    expect(ToolCardState.of(node).phase, ToolCardPhase.running);
    expect(ToolCardState.of(node, awaitingConfirm: true).phase, ToolCardPhase.awaitingConfirm);
  });

  test('terminals split on the tool_result child', () {
    final ok = _call()..children.add(_result('{"ok":true}'));
    expect(ToolCardState.of(ok).phase, ToolCardPhase.succeeded);

    final failed = _call()..children.add(_result('FN_NOT_FOUND: no such function', error: true));
    final fs = ToolCardState.of(failed);
    expect(fs.phase, ToolCardPhase.failed);
    expect(fs.errorText, contains('FN_NOT_FOUND'));

    final denied = _call()
      ..children.add(_result(
          'The user denied running this tool. Do not retry it unless the user explicitly asks.'));
    expect(ToolCardState.of(denied).phase, ToolCardPhase.denied);

    final declined = _call()
      ..children.add(_result(
          'The user declined to answer this question. Proceed without it or ask differently.'));
    expect(ToolCardState.of(declined).phase, ToolCardPhase.denied);

    final gateCancelled = _call()
      ..children.add(_result('The run was cancelled before this tool ran.'));
    expect(ToolCardState.of(gateCancelled).phase, ToolCardPhase.cancelled);
  });

  test('cancelled tool_call (args-phase kill) → cancelled regardless of children', () {
    final s = ToolCardState.of(_call(status: 'cancelled'));
    expect(s.phase, ToolCardPhase.cancelled);
  });

  test('awaitingConfirm never overrides a landed result', () {
    final ok = _call()..children.add(_result('{"ok":true}'));
    expect(ToolCardState.of(ok, awaitingConfirm: true).phase, ToolCardPhase.succeeded);
  });

  test('progress text reads the wire `text` key (snapshot) and falls back to deltas (live)', () {
    final settled = _call()
      ..children.add(BlockNode(id: 'pr_1', kind: BlockKind.progress)
        ..status = 'completed'
        ..content = {'text': 'line1\nline2'});
    final s = ToolCardState.of(settled);
    expect(s.progressText, 'line1\nline2');
    expect(s.progressLive, isFalse);

    const scope = StreamScope(kind: 'conversation', id: 'cv_1');
    final r = BlockTreeReducer()
      ..apply(const StreamEnvelope(
          seq: 1, scope: scope, id: 'tc_2',
          frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'Bash'}))))
      ..apply(const StreamEnvelope(
          seq: 2, scope: scope, id: 'pr_2',
          frame: FrameOpen(parentId: 'tc_2', node: StreamNode(type: 'progress'))))
      ..apply(const StreamEnvelope(
          seq: 0, scope: scope, id: 'pr_2', frame: FrameDelta(chunk: 'tick 1\n')));
    // tool_call still open here — but the progress projection must already flow. 进度投影先行可用。
    final live = ToolCardState.of(r.roots.single);
    expect(live.progressText, 'tick 1\n');
    expect(live.progressLive, isTrue);
  });

  test('metadata (summary/danger) and hasBody honesty', () {
    final bare = _call(content: {'name': 'x'});
    expect(ToolCardState.of(bare).hasBody, isFalse);

    final rich = _call(content: {
      'name': 'create_function',
      'summary': 'Build the rollup',
      'danger': 'safe',
      'arguments': '{"ops":[]}',
    })
      ..children.add(_result('{"id":"fn_1"}'));
    final s = ToolCardState.of(rich);
    expect(s.summary, 'Build the rollup');
    expect(s.danger, 'safe');
    expect(s.hasBody, isTrue);
  });

  test('nested subagent MESSAGE wrapper is flattened into the trajectory (real backend shape)', () {
    // Live E3: a Subagent turn arrives as a `message` node under the tool_call, whose reasoning/text/
    // tool_call blocks are ITS children. of() must flatten it so the peek pane sees the trace, not an
    // empty wrapper (subagent/emit.go). 真后端:嵌套回合是 message 包装,轨迹在其子块——须摊平。
    final call = _call(content: {'name': 'Subagent'});
    final msg = BlockNode(id: 'sub_msg', kind: BlockKind.message)..status = 'completed';
    msg.children.addAll([
      BlockNode(id: 'n1', kind: BlockKind.reasoning)..content = {'content': '先定位注册表'},
      BlockNode(id: 'n2', kind: BlockKind.toolCall)..content = {'name': 'Grep'},
      BlockNode(id: 'n3', kind: BlockKind.text)..content = {'content': '找到了'},
    ]);
    call.children.add(msg);

    final s = ToolCardState.of(call);
    expect(s.nested.length, 3, reason: 'the message wrapper must be flattened to its 3 trajectory blocks');
    expect(s.nested.map((n) => n.kind), [BlockKind.reasoning, BlockKind.toolCall, BlockKind.text]);
    // The wrapper itself must NOT appear (it would render as an empty shrink row). 包装本身不入 nested。
    expect(s.nested.any((n) => n.kind == BlockKind.message), isFalse);
  });

  test('raw E3 blocks directly under the call still nest (fixture / reload path)', () {
    final call = _call(content: {'name': 'invoke_agent'});
    call.children.addAll([
      BlockNode(id: 'n1', kind: BlockKind.reasoning)..content = {'content': 'x'},
      BlockNode(id: 'n2', kind: BlockKind.text)..content = {'content': 'y'},
    ]);
    expect(ToolCardState.of(call).nested.length, 2);
  });
}
