import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F05 lifecycle (B3.6) — the «极薄卡» family: verb + an undeniable receipt + a minimal body. Distinct
// shapes: revert (⤺ rewind) / delete (impact audit) / restart (green-but-broken) / deactivate
// (draining half-state) / kill / update_meta (dynamic rename verb). F05 极薄卡各族形态。

BlockNode _call(String name, String args, String result) =>
    BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
      ..status = 'completed'
      ..content = {'name': name, 'arguments': args}
      ..children.add(BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
        ..status = 'completed'
        ..content = {'content': result});

final toolCardLifecycleGalleryItem = GalleryItem(
  'ChatToolCard · F05 lifecycle 极薄卡',
  'F05:一行陈述 + 不可抵赖凭据。回执三色(none/warn/draining/danger 自动展开)+ 删除审计(N 处引用受影响 + '
      '可点药丸跳修)+ 「工具绿但物已坏」重分类(restart error 键→失败)+ 动态改名动词 + 单端倒带。',
  [
    GallerySpecimen('revert_function · ⤺ v3(倒带 + 注记)',
        (c) => ChatToolCard(node: _call('revert_function', '{"functionId":"fn_1a2b"}', '{"id":"fn_1a2b","activeVersionId":"fnv_9","version":3}')),
        span: true),
    GallerySpecimen('delete_function · 删除审计(3 处引用受影响 + 跳修药丸)',
        (c) => ChatToolCard(
            node: _call('delete_function', '{"functionId":"fn_1a2b"}',
                '{"id":"fn_1a2b","deleted":true,"dependentCount":3,"dependents":[{"kind":"agent","id":"ag_1"},{"kind":"workflow","id":"wf_2"},{"kind":"handler","id":"hd_3"}],"note":"this entity was referenced by other entities"}')),
        span: true),
    GallerySpecimen('delete_agent · 字符串形依赖(前缀派生 kind)',
        (c) => ChatToolCard(
            node: _call('delete_agent', '{"agentId":"ag_9f8e"}',
                'Deleted agent ag_9f8e. Referenced by: [wf_1 ctl_2 fn_3]')),
        span: true),
    GallerySpecimen('restart_handler · 绿壳红事实(error 键→失败态自动展开)',
        (c) => ChatToolCard(
            node: _call('restart_handler', '{"handlerId":"hd_5c4b"}',
                '{"id":"hd_5c4b","runtimeState":"crashed","error":"__init__ raised: missing config key STRIPE_KEY"}')),
        span: true),
    GallerySpecimen('deactivate_workflow · draining 半态(琥珀,不自动展开)',
        (c) => ChatToolCard(node: _call('deactivate_workflow', '{"workflowId":"wf_00ff"}', '{"workflowId":"wf_00ff","lifecycleState":"draining"}')),
        span: true),
    GallerySpecimen('kill_workflow · 杀停 3 个在途运行(红核自动展开)',
        (c) => ChatToolCard(node: _call('kill_workflow', '{"workflowId":"wf_00ff"}', '{"workflowId":"wf_00ff","killed":3}')),
        span: true),
    GallerySpecimen('update_function_meta · 纯改名(动态动词 已改名 + 单端 → b)',
        (c) => ChatToolCard(node: _call('update_function_meta', '{"functionId":"fn_1a2b","name":"data-fetcher"}', '{"id":"fn_1a2b","name":"data-fetcher"}')),
        span: true),
    GallerySpecimen('activate_workflow · 上线 → 监听中',
        (c) => ChatToolCard(node: _call('activate_workflow', '{"workflowId":"wf_00ff"}', '{"workflowId":"wf_00ff","lifecycleState":"active","active":true}')),
        span: true),
  ],
);
