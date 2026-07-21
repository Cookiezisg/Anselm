import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../core/sse/frame.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F07 searches (B3.1) — the COLLAPSED-ROW grammar: dual-channel verb (search↔list), the query as a
// mono chip, and the searchReceipt count (N / N·共M / 无匹配 / 空). The settled ToolHitList body lands
// in B3.3; here the row already reads like a directory line. F07 检索收起行:双声道 + query chip + 计数回执。

BlockNode _call(String id, String name, {String? args, String? result}) {
  final node = BlockNode(id: 'tc_$id', kind: BlockKind.toolCall)
    ..status = 'completed'
    ..content = {'name': name, 'arguments': ?args};
  if (result != null) {
    node.children.add(
      BlockNode(id: 'tr_$id', kind: BlockKind.toolResult)
        ..status = 'completed'
        ..content = {'content': result},
    );
  }
  return node;
}

/// Mid-stream search_function: the query has NOT streamed yet — the row must LOCK the search channel
/// (never flip to «列» just because query is momentarily absent). 流中:query 未到,锁搜索声道。
BlockNode _streaming() {
  const scope = StreamScope(kind: 'conversation', id: 'cv_s');
  final r = BlockTreeReducer()
    ..apply(
      const StreamEnvelope(
        seq: 1,
        scope: scope,
        id: 'tc_sstream',
        frame: FrameOpen(
          node: StreamNode(
            type: 'tool_call',
            content: {'name': 'search_function'},
          ),
        ),
      ),
    )
    ..apply(
      const StreamEnvelope(
        seq: 0,
        scope: scope,
        id: 'tc_sstream',
        frame: FrameDelta(chunk: '{"que'),
      ),
    );
  return r.roots.single;
}

final toolCardEntitySearchGalleryItem = GalleryItem(
  'ChatToolCard · F07 searches 收起行',
  'F07:双声道动词(有 query→已搜索X / 空→已列X)+ query mono chip + searchReceipt(N / N·共M 服务端截断 / '
      '无匹配 / 空);双形状(engine 带 total / fallback 无)+ nil 列表防御。命中窗体(ToolHitList)B3.3 落。',
  [
    GallerySpecimen(
      'search_function · 有 query · 12 个(fallback 无 total)',
      (c) => ChatToolCard(
        node: _call(
          'sf',
          'search_function',
          args: '{"query":"http 重试"}',
          result:
              '{"count":12,"functions":[{"id":"fn_1","name":"fetch_with_retry","description":"指数退避重试"}]}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'search_agent · 有 query · 20·共47(engine 服务端截断)',
      (c) => ChatToolCard(
        node: _call(
          'sa',
          'search_agent',
          args: '{"query":"发票分类"}',
          result:
              '{"count":20,"total":47,"agents":[{"id":"ag_1","name":"invoice_triager","description":"按季度分类…"}]}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'search_workflow · 空 query → 已列工作流 · 3 个',
      (c) => ChatToolCard(
        node: _call(
          'sw',
          'search_workflow',
          args: '{"query":""}',
          result:
              '{"count":3,"workflows":[{"id":"wf_1","name":"invoice_sync","lifecycleState":"active","active":true}]}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'search_blocks · 无匹配(软空串)',
      (c) => ChatToolCard(
        node: _call(
          'sb',
          'search_blocks',
          args: '{"query":"量子退火"}',
          result:
              'No blocks matched "量子退火". Try different capability keywords, or create the block.',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'list_documents · listOnly → 已列文档 · 空',
      (c) => ChatToolCard(
        node: _call(
          'ld',
          'list_documents',
          args: '{}',
          result: '{"count":0,"documents":null}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'list_attachments · 已列附件 · 5 个',
      (c) => ChatToolCard(
        node: _call(
          'la',
          'list_attachments',
          args: '{}',
          result:
              '{"count":5,"attachments":[{"id":"att_1","filename":"q3.pdf","mime":"application/pdf","kind":"document","sizeBytes":48210,"createdAt":"2026-07-01T09:00:00Z"}]}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'search_function · args 流入中 · 锁搜索声道(query 未到)',
      (c) => ChatToolCard(node: _streaming()),
      span: true,
    ),
  ],
);
