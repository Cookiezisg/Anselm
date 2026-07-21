import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F01 mount skins (B4 F01.5) — the per-agent dynamic mount tools routed by NAME: mcp__<server>__<tool>
// (raw string, never markdown) / <handler>__<method> ({result} JSON). mount 三式:按名字路由。

BlockNode _call(String name, String args, String result) =>
    BlockNode(id: 'tc_${name.hashCode}', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(
        BlockNode(id: 'tr_${name.hashCode}', kind: BlockKind.toolResult)
          ..status = 'completed'
          ..content = {'content': result},
      );

final toolCardMountGalleryItem = GalleryItem(
  'ChatToolCard · mount 三式(动态挂载)',
  'F01 mount:agent 装备的能力作合成工具、按名字路由——mcp__server__tool(纯字符串结果、绝不当 markdown)/ '
      'handler__method({result} JSON + yield 流)。MCP 解析错→红回执自动展开。',
  [
    GallerySpecimen(
      'mcp__linear__create_issue(server/tool chip + 纯字符串结果)',
      (c) => ChatToolCard(
        node: _call(
          'mcp__linear__create_issue',
          '{"title":"Fix rollup","team":"ENG"}',
          'Created issue ENG-421: "Fix rollup"\nURL: https://linear.app/eng/issue/ENG-421',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'mcp__linear__x · 服务器离线(MCP 错误红,自动展开)',
      (c) => ChatToolCard(
        node: _call(
          'mcp__linear__create_issue',
          '{"title":"x"}',
          'mcp server "linear" is not connected: MCP_SERVER_NOT_CONNECTED',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'billing_webhook__charge(handler.method() chip + {result} JSON 树)',
      (c) => ChatToolCard(
        node: _call(
          'billing_webhook__charge',
          '{"amount":4200,"currency":"USD"}',
          '{"result":{"chargeId":"ch_1a2b","status":"succeeded","amount":4200}}',
        ),
      ),
      span: true,
    ),
  ],
);
