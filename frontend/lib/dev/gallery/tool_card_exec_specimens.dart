import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F08 exec bodies (B5.1) — run_function / call_handler over their real wire results. run_function's
// tool_result is the marshaled ExecutionResult {ok, output, errorMsg, elapsedMs, logs}; call_handler's
// is {result} plus any streamed `progress` yields. Both settle onto ToolIOSection's hard render rules
// (input → logs → output) + the exec result bar. F08 执行卡真机:输入→日志→输出 + 结果条。

BlockNode _node(String name, String args, String result, {String? progress, String status = 'completed'}) {
  final call = BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
    ..status = status
    ..content = {'name': name, 'arguments': args};
  if (progress != null) {
    call.children.add(BlockNode(id: 'pg_$name', kind: BlockKind.progress)
      ..status = 'completed'
      ..content = {'text': progress});
  }
  call.children.add(BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
    ..status = status
    ..content = {'content': result});
  return call;
}

final toolCardExecGalleryItem = GalleryItem(
  'ChatToolCard · F08 执行卡',
  'F08 执行:输入→黑箱→输出的可核账凭据。run_function 收 ExecutionResult(ok/output/errorMsg/elapsedMs/logs)'
      '→ ToolIOSection 逐键陈列 + 日志抽屉 + 结果条(成功耗时 / 失败红自动展开);call_handler 收 {result} + 流式 '
      'progress yield,无耗时字段(绝不编造)。',
  [
    GallerySpecimen('run_function · 成功 + 标量输出 + 耗时',
        (c) => ChatToolCard(
            node: _node('run_function', '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{"url":"https://x.io/api","retries":3}}',
                '{"ok":true,"output":{"status":200,"bytes":18422},"errorMsg":"","elapsedMs":942}')),
        span: true),
    GallerySpecimen('run_function · 成功 + 日志抽屉 + 长文本输出',
        (c) => ChatToolCard(
            node: _node('run_function', '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{"query":"季度汇总"}}',
                '{"ok":true,"output":"共归并 47 张发票,冲减退款 6 笔,本位币合计 ¥182,400.00。多币种已按当日中间价归一。","errorMsg":"","elapsedMs":1240,"logs":"fetch page 1/3\\nfetch page 2/3\\nfetch page 3/3\\nnormalize currency\\ndone"}')),
        span: true),
    GallerySpecimen('run_function · 失败(ok:false)→ 红结果条 + errorMsg',
        (c) => ChatToolCard(
            node: _node('run_function', '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{"url":"https://down.example"}}',
                '{"ok":false,"output":null,"errorMsg":"ConnectionError: max retries exceeded (3) — Name or service not known","elapsedMs":30021}')),
        span: true),
    GallerySpecimen('call_handler · 方法() + 标量 result',
        (c) => ChatToolCard(
            node: _node('call_handler', '{"handlerId":"hd_5c4b3a2f1e0d9c8b","method":"balance","args":{"account":"acct_88"}}',
                '{"result":18240.5}')),
        span: true),
    GallerySpecimen('call_handler · 对象 result + 流式 progress',
        (c) => ChatToolCard(
            node: _node('call_handler', '{"handlerId":"hd_5c4b3a2f1e0d9c8b","method":"reconcile","args":{"quarter":"2026Q2"}}',
                '{"result":{"matched":312,"unmatched":4,"total":316}}',
                progress: 'scanning ledger…\nmatched 312 rows\n4 rows need review')),
        span: true),
  ],
);
