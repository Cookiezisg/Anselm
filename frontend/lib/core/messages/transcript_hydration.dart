import '../sse/frame.dart';
import 'block_tree_reducer.dart';

// Transcript hydration (WRK-056 #F09 §5) — rebuild a stored block array into the SAME [BlockNode] tree
// the live SSE stream produces, by replaying it through [BlockTreeReducer]. A settled Execution.transcript
// (get_agent_execution) / an invoke_agent card reload (B6) / the right-island run terminal (B8) all read
// their durable record through THIS one adapter, so the reload path can never drift from the live path.
//
// The stored block is a backend messages.Block: {id, parentBlockId?, type, content, attrs?, status,
// error?}. The reducer's BlockNode reads its content map by the keys {content, arguments, name, summary,
// danger} — so a tool_call's args live in `content` (the argsJSON string, → content['arguments']) and its
// name/summary/danger in `attrs` (→ content['name'] off attrs['tool'], etc.); text/reasoning/tool_result
// put their text in `content` (→ content['content']). 转写水合:把存储 block 数组重放成 live 同构树。

/// The block's own id — a full messages.Block uses `id`; the leaner get_subagent_trace blockView uses
/// `blockId`. Accept BOTH so a trace-detail's children nest (else they orphan on a synthetic id and
/// vanish). block 自身 id:完整块用 id、精简 blockView 用 blockId,两者都收(否则子块孤儿消失)。
String? _blockId(Map<String, dynamic> b) {
  final id = b['id'] as String?;
  if (id != null && id.isNotEmpty) return id;
  final bid = b['blockId'] as String?;
  return (bid != null && bid.isNotEmpty) ? bid : null;
}

/// Map ONE stored block to the frame node.content map BlockNode expects. 一 block → node.content 映射。
Map<String, dynamic> _nodeContent(Map<String, dynamic> b, String type) {
  final raw = b['content'] as String? ?? '';
  if (type == 'tool_call') {
    final attrs = (b['attrs'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Full block: name in attrs['tool']. Leaner blockView (trace): no attrs — fall back to a top-level
    // `tool` key if the projection carries one. 完整块名在 attrs['tool'];精简 blockView 回落顶层 tool 键。
    return {
      'name': ?(attrs['tool'] ?? b['tool']),
      'arguments': raw,
      'summary': ?attrs['summary'],
      'danger': ?attrs['danger'],
    };
  }
  // progress snapshots its text under `text` (loop/progress.go), NOT `content` — align with the live
  // close frame + conversation_transcript's hydrateBlockContent so a replayed progress block (e.g. a
  // get_subagent_trace detail) never renders empty. progress 快照在 `text` 键,与 live/另一水化路对齐。
  if (type == 'progress') return {'text': raw};
  // text / reasoning / tool_result → the text sits in `content`. 文本类。
  return {'content': raw};
}

/// Convert a stored transcript (a list of block maps) into the [StreamEnvelope] sequence that, replayed
/// through a [BlockTreeReducer], reproduces the live tree: one Open (with the settled content) + one
/// Close (final status) per block. A block missing an id gets a stable index-derived one (a top-level
/// text block has none) so the reducer's `_byId` never collides. 存储转写 → 帧序。
List<StreamEnvelope> hydrateTranscript(List<dynamic> blocks, {String scopeId = ''}) {
  final scope = StreamScope(kind: 'conversation', id: scopeId);
  final out = <StreamEnvelope>[];
  var seq = 1;
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    if (b is! Map) continue;
    final block = b.cast<String, dynamic>();
    final id = _blockId(block) ?? 'hblk_$i';
    final parentId = block['parentBlockId'] as String?;
    final type = block['type'] as String? ?? '';
    final content = _nodeContent(block, type);
    out.add(StreamEnvelope(seq: seq++, scope: scope, id: id,
        frame: FrameOpen(parentId: parentId, node: StreamNode(type: type, content: content))));
    final status = (block['status'] as String?)?.isNotEmpty == true ? block['status'] as String : 'completed';
    out.add(StreamEnvelope(seq: seq++, scope: scope, id: id, frame: FrameClose(status: status, error: block['error'] as String?)));
  }
  return out;
}

/// Hydrate a stored transcript straight into its nested [BlockNode] roots (the common case — a reader
/// that wants the tree, not the frames). 直接水合成 BlockNode 树根。
List<BlockNode> hydrateTranscriptTree(List<dynamic> blocks, {String scopeId = ''}) {
  final reducer = BlockTreeReducer();
  for (final env in hydrateTranscript(blocks, scopeId: scopeId)) {
    reducer.apply(env);
  }
  return reducer.roots;
}
