import '../../core/contract/interaction.dart';
import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../core/sse/frame.dart';
import '../../features/chat/state/pending_interactions_provider.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// ChatToolCard — the V3a tool-call chassis (WRK-053): borderless lifecycle line + generic expanded
// body. Specimens cover EVERY phase (args-streaming / running / awaiting-confirm / succeeded /
// failed[auto-expands] / denied / cancelled) plus the stress battery's favourite pathologies
// (monster args, prose result, deep JSON, progress tail, absurd tool names). Node fixtures are
// hand-built BlockNode trees — exactly the shape both live frames and settled hydration produce.
//
// ChatToolCard——V3a 工具卡底盘(WRK-053):无边框生命线 + 通用展开体。specimen 覆盖**全部相位**
// + 应力病理(巨参数/散文结果/深 JSON/进度尾巴/离谱工具名)。夹具=手搭 BlockNode 树——与 live 帧
// 和 settled 水化同形。

BlockNode _call(
  String name, {
  String status = 'completed',
  String? args,
  String? summary,
  String? danger,
  String? result,
  String? resultError,
  String? progress,
  bool progressLive = false,
}) {
  final node = BlockNode(id: 'tc_$name', kind: BlockKind.toolCall)
    ..status = status
    ..content = {
      'name': name,
      'arguments': ?args,
      'summary': ?summary,
      'danger': ?danger,
    };
  if (progress != null) {
    node.children.add(BlockNode(id: 'pr_$name', kind: BlockKind.progress)
      ..status = progressLive ? 'open' : 'completed'
      ..content = {'text': progress});
  }
  if (result != null || resultError != null) {
    node.children.add(BlockNode(id: 'tr_$name', kind: BlockKind.toolResult)
      ..status = resultError != null ? 'error' : 'completed'
      ..error = resultError
      ..content = {'content': result ?? resultError ?? ''});
  }
  return node;
}

/// An args-streaming node built through the REAL reducer path (Open + Delta frames) — the
/// fixture goes through production plumbing, not a private seam.
/// args 流入中节点走**真** reducer 路径(Open+Delta 帧)——夹具过生产管道、不开私缝。
BlockNode _streamingArgs() {
  const scope = StreamScope(kind: 'conversation', id: 'cv_g');
  final r = BlockTreeReducer()
    ..apply(const StreamEnvelope(
        seq: 1, scope: scope, id: 'tc_stream',
        frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'create_function'}))))
    ..apply(const StreamEnvelope(
        seq: 0, scope: scope, id: 'tc_stream',
        frame: FrameDelta(
            chunk: '{"summary":"Create the quarterly rollup","ops":[{"op":"set_meta","name":"quarterly_rollup"')));
  return r.roots.single;
}

const String _bashProgress = '\$ npm test\n'
    '> anselm@0.1.0 test\n'
    '> vitest run\n\n'
    ' ✓ src/rollup.test.ts (8 tests) 214ms\n'
    ' ✓ src/quarters.test.ts (5 tests) 88ms\n'
    ' ✓ src/currency.test.ts (3 tests) 41ms\n'
    'Test Files  3 passed (3)\n'
    '     Tests  16 passed (16)\n'
    '  Start at  10:24:01\n'
    '  Duration  1.92s\n'
    '[exit code: 0]';

final chatToolCardGalleryItem = GalleryItem(
  'ChatToolCard',
  'V3a 工具卡底盘(WRK-053):无边框生命线(流光动词+等宽目标+灰回执+3s 读秒)+ 通用展开体(意图/参数/'
      '进度尾/结果 JSON 树/错误);失败自动展开、拒绝·中断一等公民;族皮肤 V3b+ 逐批替换体。',
  [
    GallerySpecimen('args 流入中(动词流光,无展开体)',
        (c) => ChatToolCard(node: _streamingArgs()), span: true),
    GallerySpecimen('执行中(已关未果,读秒在 3s 后浮现)',
        (c) => ChatToolCard(
            node: _call('run_function',
                args: '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{"quarter":"Q3"}}',
                summary: 'Run the rollup for Q3', danger: 'safe')),
        span: true),
    GallerySpecimen('V6 危险门 · 待决(裸行 + 锁定展开人闸)',
        (c) => ChatToolCard(
            node: _call('delete_agent',
                args: '{"agentId":"ag_9f8e7d6c5b4a3f2e"}',
                summary: 'Remove the obsolete triager', danger: 'dangerous'),
            interaction: const InteractionRecord(
                interaction: Interaction(
              toolCallId: 'blk_del',
              kind: InteractionKind.danger,
              tool: 'delete_agent',
              resolved: false,
              summary: '这个 triager 已经废弃了,把它删掉以免误触发。',
              args: {'agentId': 'ag_9f8e7d6c5b4a3f2e'},
            ))),
        span: true),
    GallerySpecimen('V6 危险门 · 已允许(出处章 + 正常生命周期)',
        (c) => ChatToolCard(
            node: _call('delete_agent',
                args: '{"agentId":"ag_9f8e7d6c5b4a3f2e"}',
                summary: 'Remove the obsolete triager', danger: 'dangerous',
                result: '{"deleted":"ag_9f8e7d6c5b4a3f2e"}'),
            interaction: const InteractionRecord(
                interaction: Interaction(
                  toolCallId: 'blk_del',
                  kind: InteractionKind.danger,
                  tool: 'delete_agent',
                  resolved: false,
                  summary: '这个 triager 已经废弃了,把它删掉以免误触发。',
                  args: {'agentId': 'ag_9f8e7d6c5b4a3f2e'},
                ),
                decided: InteractionAction.approve)),
        span: true),
    GallerySpecimen('ask_user · 已回答·选项(选中章 + 余淡出)',
        (c) => ChatToolCard(
            node: _call('ask_user',
                args: '{"message":"这几张发票币种不一致,按哪种本位币归一?","options":["人民币 CNY","美元 USD","欧元 EUR"]}',
                result: '美元 USD')),
        span: true),
    GallerySpecimen('ask_user · 已回答·自由文本(引用)',
        (c) => ChatToolCard(
            node: _call('ask_user',
                args: '{"message":"你希望这份报告用什么口径?"}',
                result: '按不含税净额,并附一列含税总额。')),
        span: true),
    GallerySpecimen('ask_user · 已跳过(decline 散文 → 已跳过)',
        (c) => ChatToolCard(
            node: _call('ask_user',
                args: '{"message":"要我顺手把旧版本清理掉吗?","options":["好","不用"]}',
                result: 'The user declined to answer this question. Proceed without it or ask differently.')),
        span: true),
    GallerySpecimen('decide_approval · 已批准(判词章 + 理由 + 后果条)',
        (c) => ChatToolCard(
            node: _call('decide_approval',
                args: '{"flowrunId":"flr_7a1b2c3d4e5f6a7b","nodeId":"approve_spend","decision":"yes","reason":"金额在季度预算内,且申请人是授权审批人,批准放行。"}',
                result: '{"flowrun":{"status":"running"},"nodes":[{"status":"completed"},{"status":"completed"},{"status":"running"}]}')),
        span: true),
    GallerySpecimen('decide_approval · 已否决(红章 + 理由 + failed 后果)',
        (c) => ChatToolCard(
            node: _call('decide_approval',
                args: '{"flowrunId":"flr_7a1b2c3d4e5f6a7b","nodeId":"approve_spend","decision":"no","reason":"超出本季度预算上限,需先走额度调整流程。"}',
                result: '{"flowrun":{"status":"failed"},"nodes":[{"status":"completed"},{"status":"failed"}]}')),
        span: true),
    GallerySpecimen('decide_approval · NOT_PARKED(产品正常态,友好呈现非红崩)',
        (c) => ChatToolCard(
            node: _call('decide_approval',
                args: '{"flowrunId":"flr_7a1b2c3d4e5f6a7b","nodeId":"approve_spend","decision":"yes"}',
                resultError: 'approval node is not awaiting a decision')),
        span: true),
    GallerySpecimen('成功 · JSON 结果(点行展开:意图/参数/结果树)',
        (c) => ChatToolCard(
            node: _call('create_function',
                args: '{"ops":[{"op":"set_meta","name":"quarterly_rollup","description":"按季度聚合发票"},{"op":"set_code","code":"def rollup(): ..."}]}',
                summary: 'Create the quarterly rollup function',
                danger: 'safe',
                result:
                    '{"id":"fn_1a2b3c4d5e6f7a8b","versionId":"fnv_0011223344556677","version":1,"envStatus":"ready","opsApplied":2}')),
        span: true),
    GallerySpecimen('成功 · 进度尾巴(shell 形,完整流窗随 V3b)',
        (c) => ChatToolCard(
            node: _call('Bash',
                args: '{"command":"npm test"}',
                summary: 'Run the test suite', danger: 'cautious',
                progress: _bashProgress,
                result: 'Test Files  3 passed (3)\n[exit code: 0]')),
        span: true),
    GallerySpecimen('失败(自动展开,回执带失败标记)',
        (c) => ChatToolCard(
            node: _call('edit_workflow',
                args: '{"workflowId":"wf_00ff00ff00ff00ff"}',
                summary: 'Rewire the sync graph',
                resultError: 'WORKFLOW_GRAPH_CYCLE: node "sync" reaches itself via "retry" — break the loop or mark it as an intended cycle')),
        span: true),
    GallerySpecimen('已拒绝(一等公民,不消失)',
        (c) => ChatToolCard(
            node: _call('delete_agent',
                args: '{"agentId":"ag_9f8e7d6c5b4a3f2e"}',
                summary: 'Remove the obsolete triager', danger: 'dangerous',
                result:
                    'The user denied running this tool. Do not retry it unless the user explicitly asks.')),
        span: true),
    GallerySpecimen('已中断(运行前取消)',
        (c) => ChatToolCard(
            node: _call('run_function',
                args: '{"functionId":"fn_1a2b3c4d5e6f7a8b"}',
                result: 'The run was cancelled before this tool ran.')),
        span: true),
    GallerySpecimen('散文结果 · 超限截断(诚实注记)',
        (c) => ChatToolCard(
            node: _call('read_document',
                args: '{"id":"doc_5566778899aabbcc"}',
                result: '# 项目章程\n\n${'这份文档很长,足以触发通用皮肤的显示上限并给出诚实的截断注记。' * 200}')),
        stress: true, span: true),
    GallerySpecimen('MCP 动态 · 离谱名与深 JSON(schema-less 兜底)',
        (c) => ChatToolCard(
            node: _call('mcp__context7__resolve_library_docs____v2',
                args: '{"libraryName":"react","topic":"hooks"}',
                summary: 'Fetch React hook docs',
                danger: 'cautious',
                result:
                    '{"library":{"id":"/facebook/react","versions":[{"tag":"19.2","docs":{"hooks":{"useEffect":{"signature":"useEffect(setup, deps?)","notes":["cleanup runs before re-run","strict-mode double-invokes"]}}}}]},"tookMs":412}')),
        stress: true, span: true),
  ],
);
