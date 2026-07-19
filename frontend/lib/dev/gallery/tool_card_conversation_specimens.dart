import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F17 conversation (B3.7) — the «thin card» family: manage echoes status (rename plays through the
// autoname typewriter off-card), list/search render a mini-rail of tappable doors. F17 对话薄卡。

BlockNode _call(String name, String args, String result) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
        ..status = 'completed'
        ..content = {'content': result});

final toolCardConversationGalleryItem = GalleryItem(
  'ChatToolCard · F17 conversation 薄卡',
  'F17:manage 动词随 action 分派(归档/置顶/改名…+ fallback)+ 状态回显;软失败(ctx 无对话)→ 中性已调用 + '
      '原文;list/search = 迷你 rail 命中门(置顶字形 / 归档徽 / 时间 / snippet / ×N chunks,行点击切对话)。',
  [
    GallerySpecimen('manage · rename(已重命名对话 + 标题 chip + 状态回显)',
        (c) => ChatToolCard(node: _call('manage_conversation', '{"action":"rename","title":"发票对账排查"}', '{"conversationId":"cv_1","action":"rename","title":"发票对账排查","archived":false,"pinned":false}')),
        span: true),
    GallerySpecimen('manage · archive(状态回显 + 归档产品事实)',
        (c) => ChatToolCard(node: _call('manage_conversation', '{"action":"archive"}', '{"conversationId":"cv_1","action":"archive","title":"旧线程","archived":true,"pinned":false}')),
        span: true),
    GallerySpecimen('manage · 软失败(ctx 无对话 → 中性已调用 + 原文)',
        (c) => ChatToolCard(node: _call('manage_conversation', '{"action":"pin"}', 'manage_conversation is only available inside a conversation (no conversationId in context).')),
        span: true),
    GallerySpecimen('list_conversations · 迷你 rail(置顶字形 / 归档徽 / 时间 · 续页注记)',
        (c) => ChatToolCard(
            node: _call('list_conversations', '{"includeArchived":true}',
                '{"count":3,"conversations":[{"conversationId":"cv_1","title":"发票对账排查","archived":false,"pinned":true,"lastMessageAt":"2026-07-05T14:00:00Z"},{"conversationId":"cv_2","title":"季度汇总口径","archived":false,"pinned":false,"lastMessageAt":"2026-07-04T09:30:00Z"},{"conversationId":"cv_3","title":"旧线程","archived":true,"pinned":false,"lastMessageAt":"2026-06-20T11:00:00Z"}],"nextCursor":"c_next"}')),
        span: true),
    GallerySpecimen('search_conversations · 命中门(snippet 次行 + ×N chunks + 截断注记)',
        (c) => ChatToolCard(
            node: _call('search_conversations', '{"query":"退款 冲减"}',
                '{"total":9,"hits":[{"conversationId":"cv_1","title":"发票对账排查","snippet":"…退款行计入当季冲减,多币种先归一…","matchedChunks":3,"messageId":"msg_9"},{"conversationId":"cv_2","title":"季度汇总口径","snippet":"…净额为主列,含税总额附加…","matchedChunks":1}]}')),
        span: true),
  ],
);
