import '../model/partial_json.dart';
import 'block_tree_reducer.dart';

/// The per-tool_call INCREMENTAL args parse session (WRK-061 W0): one [PartialJsonSession] per
/// [BlockNode], fed only the UNSEEN TAIL of [BlockNode.argumentsText] on each access — the O(delta)
/// replacement for re-scanning the whole fragment every build (which is O(n²) over a stream and falls
/// over on MB-scale args). Sessions ride an [Expando], so they're reclaimed with their node.
///
/// Source flip: while the node is open the text is the delta accumulator (append-only → incremental
/// feed is sound); the close snapshot may differ byte-wise from the deltas (it's the backend's final
/// JSON), so on the open→closed flip the session is REBUILT once from the snapshot. A shrinking text
/// (unexpected source change) also rebuilds — honesty over cleverness.
///
/// 每 tool_call 一个增量 args 解析会话:每次访问只喂 [argumentsText] 未见过的尾段——O(delta) 取代整段
/// 重扫(流上 O(n²),MB 级必炸)。挂 Expando,随节点回收。源翻转:open 期是 delta 累加器(只增,增量喂
/// 成立);close 快照与 delta 可能字节不同(后端最终 JSON)——open→closed 翻转时整段重建一次;文本收缩
/// (意外换源)同样重建,诚实优先。
PartialJsonSession argsSessionOf(BlockNode node) {
  var e = _entries[node];
  if (e == null || (e.wasOpen && !node.isOpen)) {
    e = _Entry(wasOpen: node.isOpen);
    _entries[node] = e;
  }
  final args = node.argumentsText;
  if (args.length < e.fed) {
    e = _Entry(wasOpen: node.isOpen); // shrank → rebuild 收缩→重建
    _entries[node] = e;
  }
  if (args.length > e.fed) {
    e.session.append(args.substring(e.fed));
    e.fed = args.length;
  }
  return e.session;
}

class _Entry {
  _Entry({required this.wasOpen});
  final PartialJsonSession session = PartialJsonSession();
  int fed = 0; // chars of argumentsText already fed 已喂字符数
  final bool wasOpen; // openness at creation — a close flips the source (delta→snapshot) 创建时的开合态
}

final Expando<_Entry> _entries = Expando('argsSession');
