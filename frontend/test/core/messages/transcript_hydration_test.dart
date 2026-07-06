import 'package:anselm/core/contract/messages/block_content.dart';
import 'package:anselm/core/messages/transcript_hydration.dart';
import 'package:flutter_test/flutter_test.dart';

// The shared transcript hydration adapter (B5.10) — a pure, widget-free rebuild of a stored block array
// into the live [BlockNode] tree. Locks: block-type content mapping, parentBlockId nesting (E3 subagent
// subtree), id generation for id-less blocks, settled status. 转写水合适配器纯单测。

void main() {
  test('text/reasoning/tool_call/tool_result map to the right BlockNode content', () {
    final roots = hydrateTranscriptTree([
      {'type': 'reasoning', 'content': 'thinking about it', 'status': 'completed'},
      {'type': 'text', 'content': 'here is the plan', 'status': 'completed'},
      {'id': 'tc_1', 'type': 'tool_call', 'content': '{"path":"/x"}', 'attrs': {'tool': 'Write', 'summary': 'writing', 'danger': 'dangerous'}, 'status': 'completed'},
      {'id': 'tr_1', 'parentBlockId': 'tc_1', 'type': 'tool_result', 'content': 'wrote 12 lines', 'status': 'completed'},
    ]);
    // reasoning, text, tool_call are top-level; tool_result nests under tool_call. reasoning/text/tool_call 顶层,tool_result 嵌套。
    expect(roots.length, 3);
    expect(roots[0].kind, BlockKind.reasoning);
    expect(roots[0].displayText, 'thinking about it');
    expect(roots[1].kind, BlockKind.text);
    expect(roots[1].displayText, 'here is the plan');
    final call = roots[2];
    expect(call.kind, BlockKind.toolCall);
    expect(call.name, 'Write'); // from attrs['tool']
    expect(call.argumentsText, '{"path":"/x"}'); // from content
    expect(call.summary, 'writing');
    expect(call.danger, 'dangerous');
    // The tool_result nests under the tool_call (E3). tool_result 挂 tool_call 之下。
    expect(call.children.length, 1);
    expect(call.children[0].kind, BlockKind.toolResult);
    expect(call.children[0].displayText, 'wrote 12 lines');
  });

  test('every block settles (status completed), never stuck open', () {
    final roots = hydrateTranscriptTree([
      {'type': 'text', 'content': 'x'},
    ]);
    expect(roots.single.isOpen, isFalse);
    expect(roots.single.status, 'completed');
  });

  test('id-less blocks get unique ids (no _byId collision drops blocks)', () {
    // Three text blocks all lack an id — the adapter must give each a distinct id so none is dropped.
    // 三个无 id 文本块——适配器须各给唯一 id、一个都不能丢。
    final roots = hydrateTranscriptTree([
      {'type': 'text', 'content': 'a'},
      {'type': 'text', 'content': 'b'},
      {'type': 'text', 'content': 'c'},
    ]);
    expect(roots.length, 3);
    expect(roots.map((r) => r.displayText).toList(), ['a', 'b', 'c']);
  });

  test('a nested subagent subtree (E3): a tool_call whose result holds child blocks', () {
    // invoke_agent's inner blocks nest under the tool_call via parentBlockId — the reload path. E3 嵌套。
    final roots = hydrateTranscriptTree([
      {'id': 'tc_sub', 'type': 'tool_call', 'content': '{"agentId":"ag_1"}', 'attrs': {'tool': 'invoke_agent'}},
      {'id': 'sub_reason', 'parentBlockId': 'tc_sub', 'type': 'reasoning', 'content': 'inner thought'},
      {'id': 'sub_text', 'parentBlockId': 'tc_sub', 'type': 'text', 'content': 'inner answer'},
    ]);
    expect(roots.length, 1);
    expect(roots[0].children.length, 2);
    expect(roots[0].children[0].displayText, 'inner thought');
    expect(roots[0].children[1].displayText, 'inner answer');
  });

  test('empty transcript → empty roots (honest absence, no crash)', () {
    expect(hydrateTranscriptTree([]).isEmpty, isTrue);
    expect(hydrateTranscriptTree(['not a map', 42]).isEmpty, isTrue);
  });
}
