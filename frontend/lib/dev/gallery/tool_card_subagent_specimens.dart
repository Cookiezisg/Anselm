import 'dart:convert';

import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F15 nested conversation (B6) — the Subagent card (live nested trajectory + settled answer) and
// get_subagent_trace (list / hydrated detail). The nested E3 subtree is built as real child BlockNodes
// under the tool_call. F15 嵌套对话真机:嵌套轨迹活窗 + 轨迹回放。

BlockNode _blk(String type, String content, {String? tool, String? summary}) {
  final n = BlockNode(
    id: 'b_${type}_$content'.hashCode.toString(),
    kind: blockKindFromWire(type),
  )..status = 'completed';
  if (type == 'tool_call') {
    n.content = {'name': tool, 'arguments': content, 'summary': ?summary};
  } else {
    n.content = {'content': content};
  }
  return n;
}

BlockNode _subagent(
  String args, {
  String? result,
  List<BlockNode> nested = const [],
  bool open = false,
}) {
  final node = BlockNode(id: 'tc_sub', kind: BlockKind.toolCall)
    ..status = open ? 'open' : 'completed'
    ..content = {'name': 'Subagent', 'arguments': args};
  for (final n in nested) {
    node.children.add(n);
  }
  if (result != null) {
    node.children.add(
      BlockNode(id: 'tr_sub', kind: BlockKind.toolResult)
        ..status = 'completed'
        ..content = {'content': result},
    );
  }
  return node;
}

BlockNode _trace(String args, Map<String, dynamic> result) =>
    BlockNode(id: 'tc_tr', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': 'get_subagent_trace', 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_tr', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': jsonEncode(result)},
      );

final _traj = [
  _blk('reasoning', '先定位 catalog 注册表在哪个文件。'),
  _blk(
    'tool_call',
    '{"pattern":"toolCardSpecFor"}',
    tool: 'Grep',
    summary: '搜注册表',
  ),
  _blk('text', '找到 tool_card_catalog.dart,注册在 _catalog Map。'),
];

final toolCardSubagentGalleryItem = GalleryItem(
  'ChatToolCard · F15 嵌套对话',
  'F15:Subagent 派子代理跑隔离子任务、返回终答;E3 嵌套轨迹活期流在卡下(NestedRunPane 机器窗、末行微光)。'
      '落定=任务 + 轨迹 + 回答散文;重载后轨迹去 get_subagent_trace 回放。trace 双形:list 运行台账 / '
      'detail 水合 TranscriptPeek。',
  [
    GallerySpecimen(
      'Subagent · 活期(嵌套轨迹流入,末行微光)',
      (c) => ChatToolCard(
        node: _subagent(
          '{"subagent_type":"Explore","prompt":"找 catalog 注册表"}',
          nested: [
            _blk('reasoning', '先定位 catalog 注册表在哪个文件。'),
            BlockNode(id: 'b_open', kind: BlockKind.toolCall)
              ..status = 'open'
              ..content = {
                'name': 'Grep',
                'arguments': '{"pattern":"toolCardSpecFor"}',
                'summary': '搜注册表',
              },
          ],
          open: true,
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'Subagent · 落定(任务 + 轨迹 + 回答散文)',
      (c) => ChatToolCard(
        node: _subagent(
          '{"subagent_type":"Explore","prompt":"找 catalog 注册表并说明如何加一条"}',
          nested: _traj,
          result:
              '# 注册表位置\n\n`tool_card_catalog.dart` 的 `_catalog` Map。加一条:在 Map 里加 `\'tool_name\': ToolCardSpec(...)`,verb/target/receipt/body 四槽按需填。',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'get_subagent_trace · list(本对话子代理运行台账)',
      (c) => ChatToolCard(
        node: _trace('{}', {
          'count': 2,
          'subagentRuns': [
            {
              'subagentRunId': 'subagt_01',
              'status': 'ok',
              'finalText': '找到注册表在 tool_card_catalog.dart',
              'blockCount': 3,
              'spawningToolCallId': 'tc_a',
            },
            {
              'subagentRunId': 'subagt_02',
              'status': 'failed',
              'finalText': '未找到匹配文件',
              'blockCount': 2,
              'spawningToolCallId': 'tc_b',
            },
          ],
        }),
      ),
      span: true,
    ),
    GallerySpecimen(
      'get_subagent_trace · detail(水合 TranscriptPeek)',
      (c) => ChatToolCard(
        node: _trace('{"subagentRunId":"subagt_01"}', {
          'subagentRunId': 'subagt_01',
          'spawningToolCallId': 'tc_a',
          'blocks': [
            {'type': 'reasoning', 'content': '定位注册表文件。', 'status': 'completed'},
            {
              'type': 'tool_call',
              'content': '{"pattern":"toolCardSpecFor"}',
              'status': 'completed',
            },
            {
              'type': 'text',
              'content': '注册表在 tool_card_catalog.dart。',
              'status': 'completed',
            },
          ],
        }),
      ),
      span: true,
    ),
  ],
);
