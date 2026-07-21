import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// F08 exec bodies (B5.1) — run_function / call_handler over their real wire results. run_function's
// tool_result is the marshaled ExecutionResult {ok, output, errorMsg, elapsedMs, logs}; call_handler's
// is {result} plus any streamed `progress` yields. Both settle onto ToolIOSection's hard render rules
// (input → logs → output) + the exec result bar. F08 执行卡真机:输入→日志→输出 + 结果条。

BlockNode _node(
  String name,
  String args,
  String result, {
  String? progress,
  String status = 'completed',
}) {
  final call = BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
    ..status = status
    ..content = {'name': name, 'arguments': args};
  if (progress != null) {
    call.children.add(
      BlockNode(id: 'pg_$name', kind: BlockKind.progress)
        ..status = 'completed'
        ..content = {'text': progress},
    );
  }
  call.children.add(
    BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
      ..status = status
      ..content = {'content': result},
  );
  return call;
}

final toolCardExecGalleryItem = GalleryItem(
  'ChatToolCard · F08 执行卡',
  'F08 执行:输入→黑箱→输出的可核账凭据。run_function 收 ExecutionResult(ok/output/errorMsg/elapsedMs/logs)'
      '→ ToolIOSection 逐键陈列 + 日志抽屉 + 结果条(成功耗时 / 失败红自动展开);call_handler 收 {result} + 流式 '
      'progress yield,无耗时字段(绝不编造)。',
  [
    GallerySpecimen(
      'run_function · 成功 + 标量输出 + 耗时',
      (c) => ChatToolCard(
        node: _node(
          'run_function',
          '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{"url":"https://x.io/api","retries":3}}',
          '{"ok":true,"output":{"status":200,"bytes":18422},"errorMsg":"","elapsedMs":942}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'run_function · 成功 + 日志抽屉 + 长文本输出',
      (c) => ChatToolCard(
        node: _node(
          'run_function',
          '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{"query":"季度汇总"}}',
          '{"ok":true,"output":"共归并 47 张发票,冲减退款 6 笔,本位币合计 ¥182,400.00。多币种已按当日中间价归一。","errorMsg":"","elapsedMs":1240,"logs":"fetch page 1/3\\nfetch page 2/3\\nfetch page 3/3\\nnormalize currency\\ndone"}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'run_function · 失败(ok:false)→ 红结果条 + errorMsg',
      (c) => ChatToolCard(
        node: _node(
          'run_function',
          '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{"url":"https://down.example"}}',
          '{"ok":false,"output":null,"errorMsg":"ConnectionError: max retries exceeded (3) — Name or service not known","elapsedMs":30021}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'call_handler · 方法() + 标量 result',
      (c) => ChatToolCard(
        node: _node(
          'call_handler',
          '{"handlerId":"hd_5c4b3a2f1e0d9c8b","method":"balance","args":{"account":"acct_88"}}',
          '{"result":18240.5}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'call_handler · 对象 result + 流式 progress',
      (c) => ChatToolCard(
        node: _node(
          'call_handler',
          '{"handlerId":"hd_5c4b3a2f1e0d9c8b","method":"reconcile","args":{"quarter":"2026Q2"}}',
          '{"result":{"matched":312,"unmatched":4,"total":316}}',
          progress: 'scanning ledger…\nmatched 312 rows\n4 rows need review',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'fire_trigger · 薄卡(触发器药丸 + 活化 id + payload 灰注)',
      (c) => ChatToolCard(
        node: _node(
          'fire_trigger',
          '{"triggerId":"trg_7a8b9c0d1e2f3a4b"}',
          '{"fired":true,"triggerId":"trg_7a8b9c0d1e2f3a4b","activationId":"act_1f2e3d4c5b6a7980"}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'invoke_agent · 成功 + 散文终答(steps/tokens 结果条 + agent 药丸)',
      (c) => ChatToolCard(
        node: _node(
          'invoke_agent',
          '{"agentId":"ag_9f8e7d6c5b4a3f2e","input":{"quarter":"2026Q2"}}',
          '{"executionId":"agexec_1a2b3c4d5e6f7a8b","ok":true,"output":"本季度共 312 张发票已归类:退款 6 笔冲减,跨境 18 笔按当日中间价归一。无异常需人工复核。","status":"ok","steps":9,"tokensIn":8420,"tokensOut":1203,"elapsedMs":8400}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'invoke_agent · 成功 + 声明输出对象(逐键陈列)',
      (c) => ChatToolCard(
        node: _node(
          'invoke_agent',
          '{"agentId":"ag_9f8e7d6c5b4a3f2e","input":{}}',
          '{"executionId":"agexec_2b3c4d5e6f7a8b9c","ok":true,"output":{"total":312,"refunds":6,"flagged":0},"status":"ok","steps":6,"tokensIn":4210,"tokensOut":402,"elapsedMs":3100}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'invoke_agent · 失败(auto-expand,红 errorMsg)',
      (c) => ChatToolCard(
        node: _node(
          'invoke_agent',
          '{"agentId":"ag_9f8e7d6c5b4a3f2e","input":{"quarter":"bad"}}',
          '{"executionId":"agexec_3c4d5e6f7a8b9c0d","ok":false,"output":null,"status":"failed","stopReason":"error","steps":3,"tokensIn":1820,"tokensOut":88,"errorMsg":"AGENT_OUTPUT_NOT_STRUCTURED: model returned prose but outputSchema requires {total:int}","elapsedMs":2400}',
        ),
      ),
      span: true,
    ),
    GallerySpecimen(
      'invoke_agent · 已取消(中性灰,不自动展开)',
      (c) => ChatToolCard(
        node: _node(
          'invoke_agent',
          '{"agentId":"ag_9f8e7d6c5b4a3f2e","input":{}}',
          '{"executionId":"agexec_4d5e6f7a8b9c0d1e","ok":false,"output":null,"status":"cancelled","steps":2,"tokensIn":900,"tokensOut":40,"elapsedMs":1200}',
        ),
      ),
      span: true,
    ),
  ],
);
