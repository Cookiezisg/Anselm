import '../../core/contract/messages/block_content.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../core/sse/frame.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// V3c builds — the platform's soul family: the authored content STREAMS into the machine
// window as the LLM emits args (plain mono while flowing, highlighted editor once settled),
// then the RESULT BAR lands: id · vN · env outcome (the honest half-success — the entity
// landed but its sandbox env may still be building or failed).
//
// V3c 构建族——平台灵魂:创作内容随 LLM 吐 args **流进机器窗**(流动期纯等宽,落定换高亮编辑器),
// 然后**结果条**落地:id · vN · env 结局(诚实半成功——实体落了,沙箱 env 可能还在建或已失败)。

BlockNode _call(
  String id,
  String name, {
  String status = 'completed',
  String? args,
  String? summary,
  String? result,
}) {
  final node = BlockNode(id: 'tc_$id', kind: BlockKind.toolCall)
    ..status = status
    ..content = {'name': name, 'arguments': ?args, 'summary': ?summary};
  if (result != null) {
    node.children.add(BlockNode(id: 'tr_$id', kind: BlockKind.toolResult)
      ..status = 'completed'
      ..content = {'content': result});
  }
  return node;
}

/// Mid-stream create_function: set_code's `code` value still OPEN — the live window shows
/// exactly what has streamed so far. 流中 create_function:code 值未闭合,活窗显已流入部分。
BlockNode _streamingBuild() {
  const scope = StreamScope(kind: 'conversation', id: 'cv_g');
  final r = BlockTreeReducer()
    ..apply(const StreamEnvelope(
        seq: 1, scope: scope, id: 'tc_bstream',
        frame: FrameOpen(node: StreamNode(type: 'tool_call', content: {'name': 'create_function'}))))
    ..apply(const StreamEnvelope(
        seq: 0, scope: scope, id: 'tc_bstream',
        frame: FrameDelta(
            chunk: '{"summary":"Create the quarterly rollup","ops":[{"op":"set_meta","name":"quarterly_rollup",'
                '"description":"按季度聚合发票"},{"op":"set_code","code":"import json\\n\\ndef rollup(items):\\n'
                '    by_quarter = {}\\n    for it in items:\\n        q = quarter_of(it.date)\\n'
                '        by_quarter.setdefault(q, 0)\\n        by_quar')));
  return r.roots.single;
}

const String _fnArgs =
    '{"ops":[{"op":"set_meta","name":"quarterly_rollup","description":"按季度聚合发票"},'
    '{"op":"set_code","code":"import json\\n\\ndef rollup(items):\\n    by_quarter = {}\\n'
    '    for it in items:\\n        q = quarter_of(it.date)\\n        by_quarter.setdefault(q, 0)\\n'
    '        by_quarter[q] += it.amount\\n    return by_quarter\\n"}]}';

final toolCardBuildsGalleryItem = GalleryItem(
  'ChatToolCard · builds 族',
  'F4:动词带类名词(正在创建函数);create 目标=流中 args.name;**活代码窗**(内容随 args 流入,'
      '流动期纯等宽、落定换高亮编辑器);结果条 id·vN·env(半成功诚实:failed=危险色回执+自动展开+envError 红)。',
  [
    GallerySpecimen('args 流入中 · 活代码窗(本族主打:代码随打字流进窗)',
        (c) => ChatToolCard(node: _streamingBuild()), span: true),
    GallerySpecimen('已创建函数 · v1 · env 就绪(展开:高亮代码+结果条)',
        (c) => ChatToolCard(
            node: _call('fn-ok', 'create_function',
                args: _fnArgs, summary: 'Create the quarterly rollup',
                result:
                    '{"id":"fn_1a2b3c4d5e6f7a8b","versionId":"fnv_0011223344556677","version":1,"envStatus":"ready","opsApplied":2}')),
        span: true),
    GallerySpecimen('env 失败 · 半成功(危险色回执,自动展开,envError 红)',
        (c) => ChatToolCard(
            node: _call('fn-env', 'create_function',
                args: _fnArgs, summary: 'Create the quarterly rollup',
                result:
                    '{"id":"fn_1a2b3c4d5e6f7a8b","versionId":"fnv_0011223344556677","version":1,"envStatus":"failed","opsApplied":2,"envError":"pip install pandas==9.9.9: no matching distribution found"}')),
        span: true),
    GallerySpecimen('已创建函数 · env 自愈(装错重试→治好,EnvFixTimeline)',
        (c) => ChatToolCard(
            node: _call('fn-heal', 'create_function',
                args: _fnArgs, summary: 'Create the quarterly rollup',
                result:
                    '{"id":"fn_1a2b3c4d5e6f7a8b","version":2,"envStatus":"ready","opsApplied":2,"envFixAttempts":[{"attempt":1,"deps":["pandas==9.9.9","numpy"],"ok":false,"error":"ERROR: No matching distribution found for pandas==9.9.9"},{"attempt":2,"deps":["pandas","numpy"],"ok":true}]}')),
        span: true),
    GallerySpecimen('已更新处理器 · crashed(真 brick:env 好但 __init__ 坏,红 warning 自动展开)',
        (c) => ChatToolCard(
            node: _call('hd-crash', 'edit_handler',
                args: '{"handlerId":"hd_5c4b3a2f1e0d9c8b","ops":[{"op":"add_method","method":{"name":"charge","body":"raise RuntimeError()"}}]}',
                summary: 'Add the charge method',
                result:
                    '{"id":"hd_5c4b3a2f1e0d9c8b","version":5,"envStatus":"ready","opsApplied":1,"runtimeState":"crashed","runtimeWarning":"the resident instance is not running after this edit — the new version may have a broken __init__ or need config; call get_handler for crash/config details, fix the code, or revert_handler to the last good version"}')),
        span: true),
    GallerySpecimen('已更新处理器 · stopped(良性:纯改名、从未 spawn,静音徽不报警)',
        (c) => ChatToolCard(
            node: _call('hd-stop', 'edit_handler',
                args: '{"handlerId":"hd_5c4b3a2f1e0d9c8b","ops":[{"op":"set_meta","name":"billing-webhook"}]}',
                summary: 'Rename the handler',
                result: '{"id":"hd_5c4b3a2f1e0d9c8b","version":3,"envStatus":"ready","opsApplied":1,"runtimeState":"stopped"}')),
        span: true),
    GallerySpecimen('已更新智能体 · v3(prompt 窗)',
        (c) => ChatToolCard(
            node: _call('ag-edit', 'edit_agent',
                args:
                    '{"agentId":"ag_9f8e7d6c5b4a3f2e","prompt":"You are the invoice triager.\\nClassify each incoming invoice by quarter and flag any refund lines.\\nWhen totals mismatch, open an issue instead of guessing."}',
                summary: 'Sharpen the triager prompt',
                result: '{"id":"ag_9f8e7d6c5b4a3f2e","versionId":"agv_8877665544332211","version":3}')),
        span: true),
    GallerySpecimen('已创建文档(markdown 内容;散文输出→无结果条)',
        (c) => ChatToolCard(
            node: _call('doc', 'create_document',
                args:
                    '{"name":"季度汇总口径","content":"# 季度汇总口径\\n\\n- 退款行计入当季(冲减)\\n- 多币种先归一到本位币\\n- 净额为主列,含税总额附加"}',
                summary: 'Write down the rollup rules',
                result: 'Created document "季度汇总口径" (id=doc_5566778899aabbcc, path=/specs/季度汇总口径)')),
        span: true),
    GallerySpecimen('已创建工作流 · v1 · 未激活(★两幕生长:展开→图回放生长)',
        (c) => ChatToolCard(
            node: _call('wf', 'create_workflow',
                args:
                    '{"name":"invoice_sync","ops":[{"op":"add_node","node":{"id":"on_invoice","kind":"trigger","ref":"发票到达"}},{"op":"add_node","node":{"id":"sync","kind":"action","ref":"抓取行项目"}},{"op":"add_node","node":{"id":"classify","kind":"agent","ref":"按季度分类"}},{"op":"add_node","node":{"id":"gate","kind":"control","ref":"金额>阈值?"}},{"op":"add_node","node":{"id":"approve","kind":"approval","ref":"人工复核"}},{"op":"add_edge","edge":{"id":"e1","from":"on_invoice","to":"sync"}},{"op":"add_edge","edge":{"id":"e2","from":"sync","to":"classify"}},{"op":"add_edge","edge":{"id":"e3","from":"classify","to":"gate"}},{"op":"add_edge","edge":{"id":"e4","from":"gate","fromPort":"yes","to":"approve"}}]}',
                summary: 'Wire the invoice sync pipeline',
                result: '{"id":"wf_00ff00ff00ff00ff","versionId":"wfv_1122334455667788","version":1,"active":false,"lifecycleState":"inactive"}')),
        span: true, stress: true),
    GallerySpecimen('已更新工作流 · v5(★morph 花名册:绿添 · 琥珀改 · 红删划线)',
        (c) => ChatToolCard(
            node: _call('wfe', 'edit_workflow',
                args:
                    '{"workflowId":"wf_00ff00ff00ff00ff","ops":[{"op":"add_node","node":{"id":"notify","kind":"action","ref":"通知 Slack"}},{"op":"update_node","id":"classify","patch":{"ref":"更快的分类器"}},{"op":"delete_node","id":"gate"},{"op":"add_edge","edge":{"id":"e5","from":"classify","to":"notify"}},{"op":"delete_edge","id":"e3"}]}',
                summary: 'Simplify: drop the gate, add a Slack notify',
                result: '{"id":"wf_00ff00ff00ff00ff","versionId":"wfv_5566778899aabbcc","version":5}')),
        span: true, stress: true),
    GallerySpecimen('已创建控制 · 决策梯(有序 port/when/emit + 否则钉底)',
        (c) => ChatToolCard(
            node: _call('ctl', 'create_control',
                args:
                    '{"name":"金额路由","branches":[{"port":"高额","when":"input.amount > 10000","emit":{"tier":"\\"critical\\""}},{"port":"常规","when":"input.amount > 1000"},{"port":"直放","when":"true"}]}',
                summary: 'Route invoices by amount tier',
                result: '{"id":"ctl_7d4c9e0112233445","activeVersionId":"ctlv_1122334455667788","version":1}')),
        span: true),
    GallerySpecimen('已创建审批 · 表单预览(审批人视角 + 规则条 + mock 决策)',
        (c) => ChatToolCard(
            node: _call('apf', 'create_approval',
                args:
                    '{"name":"采购放行","template":"# 采购放行审批\\n\\n供应商 {{ input.vendor }} 提交金额 **{{ input.amount }}** 元的采购申请。\\n\\n请确认预算与合规后决定是否放行。","allowReason":true,"timeout":"30d","timeoutBehavior":"reject"}',
                summary: 'Draft the spend approval form',
                result: '{"id":"apf_2e9b5c3344556677","activeVersionId":"apfv_1122334455667788","version":1}')),
        span: true),
    GallerySpecimen('已创建技能 · 稿子 + allowedTools 警示药丸(预授权=权限让渡)',
        (c) => ChatToolCard(
            node: _call('skl', 'create_skill',
                args:
                    '{"name":"invoice-triage","description":"分类发票并标记退款行","body":"# 发票分类\\n\\n1. 读取行项目\\n2. 按季度归类\\n3. 标记退款(负额)\\n4. 金额异常时开 issue","context":"inline","allowedTools":["Read","Grep","edit_document"]}',
                summary: 'Author the invoice-triage skill',
                result: '{"created":"invoice-triage"}')),
        span: true),
    // trigger ★ TriggerConfigCard — the four faces by kind (cron/webhook/fsnotify/sensor). create
    // returns 未监听 (an active workflow reference starts it). trigger 四 kind 配置脸。
    GallerySpecimen('已创建触发器 · cron(表达式加重 + 未监听注记)',
        (c) => ChatToolCard(
            node: _call('trg-cron', 'create_trigger',
                args:
                    '{"name":"每日收盘","kind":"cron","config":{"expression":"0 30 17 * * MON-FRI"}}',
                summary: 'Fire at market close on weekdays',
                result: '{"id":"trg_11aa22bb33cc44dd","version":1,"listening":false}')),
        span: true),
    GallerySpecimen('已创建触发器 · webhook(可复制 URL + 密钥 + 签名算法)',
        (c) => ChatToolCard(
            node: _call('trg-hook', 'create_trigger',
                args:
                    '{"name":"发票入站","kind":"webhook","config":{"path":"invoice","secret":"whsec_abc123","signatureAlgo":"hmac-sha256"}}',
                summary: 'Receive invoice posts',
                result: '{"id":"trg_55ee66ff77aa88bb","version":1,"listening":false}')),
        span: true),
    GallerySpecimen('已创建触发器 · fsnotify(路径 + 事件 chips + glob)',
        (c) => ChatToolCard(
            node: _call('trg-fs', 'create_trigger',
                args:
                    '{"name":"落盘监听","kind":"fsnotify","config":{"path":"/inbox/invoices","events":["create","write"],"pattern":"*.pdf"}}',
                summary: 'Watch the invoices inbox',
                result: '{"id":"trg_99cc00dd11ee22ff","version":1,"listening":false}')),
        span: true),
    GallerySpecimen('已更新触发器 · sensor(目标药丸 + 轮询周期 + CEL 条件/输出 · 热更新)',
        (c) => ChatToolCard(
            node: _call('trg-sensor', 'edit_trigger',
                args:
                    '{"triggerId":"trg_aabb001122334455","kind":"sensor","config":{"targetKind":"function","targetId":"fn_1a2b3c4d5e6f7a8b","method":"rollup","intervalSec":60,"condition":"result.total > 10000","output":"{\\"total\\": result.total}"}}',
                summary: 'Poll the rollup every minute',
                result: '{"id":"trg_aabb001122334455","version":4,"listening":true}')),
        span: true),
  ],
);
