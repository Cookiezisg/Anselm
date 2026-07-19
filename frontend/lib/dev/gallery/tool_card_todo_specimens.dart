import 'dart:convert';

import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F11 todo (B7.1) — the task checklist. todo_write projects its args' structured items; todo_read parses
// the rendered `- [x]/[→]/[ ]` markdown. Both → AnRundownList (批6:全 App 一张三态清单脸).
// F11 任务清单真机。

BlockNode _todoWrite(List<Map<String, String>> items) => BlockNode(id: 'tc_tw', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': 'todo_write', 'arguments': jsonEncode({'items': items})}
  ..children.add(BlockNode(id: 'tr_tw', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': 'checklist updated'});

BlockNode _todoRead(String rendered) => BlockNode(id: 'tc_tr', kind: BlockKind.toolCall)
  ..status = 'completed'
  ..content = {'name': 'todo_read', 'arguments': '{}'}
  ..children.add(BlockNode(id: 'tr_tr', kind: BlockKind.toolResult)
    ..status = 'completed'
    ..content = {'content': rendered});

final toolCardTodoGalleryItem = GalleryItem(
  'ChatToolCard · F11 任务清单',
  'F11 todo:todo_write 投影 args 结构项(content/activeForm/status),todo_read 解析渲染的 - [x]/[→]/[ ] 行。'
      '皆成 AnRundownList(批6 归一):✓ 完成(划线灰)/ 进行中(accent 实点、activeForm)/ ☐ 待办。回执 N 项·M 完成。',
  [
    GallerySpecimen('todo_write · 混合状态(进行中显 activeForm)',
        (c) => ChatToolCard(node: _todoWrite([
              {'content': '盘点后端契约', 'status': 'completed'},
              {'content': '设计 tool 卡', 'activeForm': '正在设计 tool 卡', 'status': 'in_progress'},
              {'content': '写 widget 测试', 'status': 'pending'},
              {'content': '真机截图审', 'status': 'pending'},
            ])),
        span: true),
    GallerySpecimen('todo_read · 从渲染行解析',
        (c) => ChatToolCard(node: _todoRead(
            '- [x] 盘点后端契约\n- [→] 正在设计 tool 卡\n- [ ] 写 widget 测试\n- [ ] 真机截图审')),
        span: true),
    GallerySpecimen('todo_write · 清空(空 items)',
        (c) => ChatToolCard(node: _todoWrite([])),
        span: true),
  ],
);
