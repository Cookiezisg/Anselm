import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F06 get bodies (B3.5) — the actual get tool cards over real entity JSON: each projects onto the
// EntityGetBody four-part exhibit. Distinct shapes: agent (capability pills) / control (decision
// ladder) / skill (allowedTools + body) / trigger (kind face) / read_document (rendered prose).
// F06 get 卡真机 JSON 投影,各族形态。

BlockNode _get(String name, String result) => BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': name, 'arguments': '{"id":"x"}'}
  ..children.add(BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': result});

final toolCardGetGalleryItem = GalleryItem(
  'ChatToolCard · F06 get 卡',
  'F06 get:动词带类名词(已查看X)+ chip 落定换名(id→name)+ 四段陈列体(身份/KV/内容/原始底账)。'
      '各族形态:agent 能力药丸 / control 决策梯 / skill allowedTools+body / trigger kind 脸 / read_document 排版稿子。',
  [
    GallerySpecimen('get_function · env ready + 代码窗',
        (c) => ChatToolCard(
            node: _get('get_function',
                '{"id":"fn_1a2b3c4d5e6f7a8b","name":"fetch_with_retry","description":"指数退避重试","tags":["net"],"updatedAt":"2026-07-01T09:00:00Z","activeVersion":{"version":3,"envStatus":"ready","pythonVersion":"3.12","dependencies":["requests==2.31"],"code":"def fetch(url):\\n    return http_get(url)\\n","inputs":[{"name":"url","type":"string"}],"outputs":[{"name":"body","type":"string"}]}}')),
        span: true),
    GallerySpecimen('get_agent · 能力药丸(tools/knowledge)+ prompt 窗',
        (c) => ChatToolCard(
            node: _get('get_agent',
                '{"id":"ag_9f8e7d6c5b4a3f2e","name":"invoice_triager","description":"按季度分类发票","updatedAt":"2026-07-01T09:00:00Z","activeVersion":{"version":4,"prompt":"# 发票分类\\n按季度归类每张发票。","tools":[{"kind":"function","name":"fetch_with_retry","id":"fn_1a2b3c4d5e6f7a8b"},{"kind":"handler","name":"charge","id":"hd_5c4b3a2f1e0d9c8b"}],"knowledge":["doc_5566"]}}')),
        span: true),
    GallerySpecimen('get_control · 决策梯',
        (c) => ChatToolCard(
            node: _get('get_control',
                '{"id":"ctl_7d4c9e0112233445","name":"金额路由","description":"按金额分档","updatedAt":"2026-07-01T09:00:00Z","activeVersion":{"version":3,"branches":[{"port":"高额","when":"input.amount > 10000","emit":{"tier":"\\"critical\\""}},{"port":"常规","when":"input.amount > 1000"},{"port":"直放","when":"true"}]}}')),
        span: true),
    GallerySpecimen('get_skill · allowedTools 警示 + body 窗',
        (c) => ChatToolCard(
            node: _get('get_skill',
                '{"name":"invoice-triage","description":"分类发票并标记退款","context":"inline","source":"ai","body":"# 发票分类\\n1. 读取行项目\\n2. 按季度归类","updatedAt":"2026-07-01T09:00:00Z","frontmatter":{"allowedTools":["Read","Grep","edit_document"]}}')),
        span: true),
    GallerySpecimen('read_document · 排版稿子(渲染 markdown)',
        (c) => ChatToolCard(
            node: _get('read_document',
                '# 季度汇总口径\n\nPath: /specs/季度汇总口径\nID: doc_5566778899aabbcc\nDescription: 汇总口径说明\nTags: 财务, 口径\n\n---\n\n# 季度汇总口径\n\n- 退款行计入当季(冲减)\n- 多币种先归一到本位币')),
        span: true),
  ],
);
