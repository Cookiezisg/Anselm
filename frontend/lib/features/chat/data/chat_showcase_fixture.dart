import '../../../core/contract/conversation.dart';
import '../../../core/contract/messages/chat_message.dart';

// The tool-card SHOWCASE seed (make demo) — themed conversations whose assistant turns exercise the
// full 113-tool card catalog (B1–B7), so `make demo` displays every card family live in a real
// transcript (not just the gallery). Each tool card = a tool_call block (attrs.tool = name, content =
// argsJSON) + a nested tool_result block (parentBlockId = the call id, content = the wire result).
// 工具卡展台种子:主题对话逐族触发全 113 工具卡,make demo 真 transcript 里看全部效果。

/// A tool_call block — the card's identity + args. tool_call 块。
ChatBlock tc(String id, String tool, String args, {String summary = '', String danger = 'safe'}) => ChatBlock(
      id: id,
      type: 'tool_call',
      content: args,
      status: 'completed',
      attrs: {'tool': tool, if (summary.isNotEmpty) 'summary': summary, if (danger.isNotEmpty) 'danger': danger},
    );

/// A tool_result block nested under [callId] — the wire result the card renders. tool_result 子块。
ChatBlock tr(String callId, String result, {bool error = false}) => ChatBlock(
      id: 'tr_$callId',
      parentBlockId: callId,
      type: 'tool_result',
      content: result,
      status: error ? 'error' : 'completed',
      error: error ? result : '',
    );

/// A text/reasoning block. 文本/思考块。
ChatBlock txt(String id, String type, String content) => ChatBlock(id: id, type: type, content: content, status: 'completed');

/// A themed showcase conversation + its assistant turn carrying the tool cards. 一个展台对话。
({Conversation conv, List<ChatMessage> messages}) showcase(
  String id,
  String title,
  Duration since, {
  required String userText,
  required List<ChatBlock> assistantBlocks,
  String? lead,
}) {
  final at = DateTime.now().toUtc().subtract(since);
  return (
    conv: Conversation(
      id: id,
      title: title,
      autoTitled: true,
      createdAt: at.subtract(const Duration(minutes: 5)),
      updatedAt: at,
      lastMessageAt: at,
    ),
    messages: [
      ChatMessage(id: '${id}_u', conversationId: id, role: 'user', status: 'completed', createdAt: at.subtract(const Duration(minutes: 2)), blocks: [
        txt('${id}_ub', 'text', userText),
      ]),
      ChatMessage(id: '${id}_a', conversationId: id, role: 'assistant', status: 'completed', stopReason: 'end_turn', inputTokens: 320, outputTokens: 210, createdAt: at, blocks: [
        if (lead != null) txt('${id}_lead', 'text', lead),
        ...assistantBlocks,
      ]),
    ],
  );
}

// ── The showcase conversations (B5–B7 authored from verified wire shapes; B1–B4 merged from audit) ──

/// Every showcase conversation + its messages, ready to fold into the demo seed. 全部展台对话。
List<({Conversation conv, List<ChatMessage> messages})> showcaseConversations() => [
      // B5 执行与档案 — run/call/invoke/flowrun/exec-history 逐族.
      showcase('cv_show_exec', '展台 · 执行与档案', const Duration(minutes: 4),
          userText: '跑一下 fetch_with_retry,再看看这个 workflow 这次跑得怎么样,顺便查它的执行史',
          lead: '好,我依次执行并调阅记录:',
          assistantBlocks: [
            tc('ec1', 'run_function', '{"functionId":"fn_1a2b3c4d5e6f7a8b","args":{"url":"https://x.io/api","retries":3}}',
                summary: '带重试抓取', danger: 'safe'),
            tr('ec1', '{"ok":true,"output":{"status":200,"bytes":18422},"errorMsg":"","elapsedMs":942,"logs":"fetch page 1/3\\nfetch page 2/3\\nfetch page 3/3\\ndone"}'),
            tc('ec2', 'call_handler', '{"handlerId":"hd_5c4b3a2f1e0d9c8b","method":"reconcile","args":{"quarter":"2026Q2"}}',
                summary: '对账季度账目', danger: 'safe'),
            tr('ec2', '{"result":{"matched":312,"unmatched":4,"total":316}}'),
            tc('ec3', 'invoke_agent', '{"agentId":"ag_9f8e7d6c5b4a3f2e","input":{"quarter":"2026Q2"}}',
                summary: '归类本季度发票', danger: 'safe'),
            tr('ec3', '{"executionId":"agexec_1a2b3c4d5e6f7a8b","ok":true,"output":"共 312 张发票已归类:退款 6 笔冲减,跨境 18 笔按当日中间价归一。无异常需人工复核。","status":"ok","steps":9,"tokensIn":8420,"tokensOut":1203,"elapsedMs":8400}'),
            tc('ec4', 'get_flowrun', '{"flowrunId":"fr_9a8b7c6d5e4f3a2b"}',
                summary: '看这次运行的节点', danger: 'safe'),
            tr('ec4', '{"flowrun":{"id":"fr_9a8b7c6d5e4f3a2b","workflowId":"wf_1a2b3c4d5e6f7a8b","versionId":"wfv_1","status":"failed","replayCount":1,"error":"run halted at node charge","pinnedRefs":{},"triggerId":"trg_7a8b9c0d1e2f3a4b","updatedAt":"2026-07-05T14:05:00Z"},"nodes":[{"id":"frn_trg","flowrunId":"fr_9a8b7c6d5e4f3a2b","nodeId":"trigger","iteration":0,"kind":"trigger","ref":"trigger:x","status":"completed","result":{},"createdAt":"2026-07-05T14:00:00Z","updatedAt":"2026-07-05T14:00:00Z"},{"id":"frn_fetch","flowrunId":"fr_9a8b7c6d5e4f3a2b","nodeId":"fetch","iteration":0,"kind":"action","ref":"action:x","status":"completed","result":{},"createdAt":"2026-07-05T14:01:00Z","updatedAt":"2026-07-05T14:01:00Z"},{"id":"frn_charge","flowrunId":"fr_9a8b7c6d5e4f3a2b","nodeId":"charge","iteration":0,"kind":"action","ref":"action:x","status":"failed","error":"HANDLER_RPC_TIMEOUT: charge() exceeded 30s","result":{},"createdAt":"2026-07-05T14:02:00Z","updatedAt":"2026-07-05T14:02:00Z"}]}'),
            tc('ec5', 'search_function_executions', '{"functionId":"fn_1a2b3c4d5e6f7a8b"}',
                summary: '翻它的执行史', danger: 'safe'),
            tr('ec5', '{"executions":[{"id":"fnexec_01","status":"ok","triggeredBy":"chat","elapsedMs":942,"startedAt":"2026-07-05T14:03:00Z"},{"id":"fnexec_02","status":"failed","triggeredBy":"agent","elapsedMs":30021,"startedAt":"2026-07-05T13:40:00Z"},{"id":"fnexec_03","status":"ok","triggeredBy":"workflow","elapsedMs":610,"startedAt":"2026-07-05T12:10:00Z"}],"hasMore":true,"aggregates":{"okCount":41,"failedCount":4}}'),
            txt('cv_show_exec_end', 'text', '**小结**:函数与对账都正常,但这次 workflow 在 `charge` 节点超时失败了(见节点台账)。要我 `replay_flowrun` 重跑失败节点吗?'),
          ]),

      // B6 嵌套子代理 — Subagent(带 E3 嵌套轨迹)+ get_subagent_trace.
      showcase('cv_show_nested', '展台 · 嵌套子代理', const Duration(minutes: 8),
          userText: '派个子代理去代码库里找 catalog 注册表在哪,再把刚才那次子代理的轨迹调出来',
          lead: '我派一个 Explore 子代理去找:',
          assistantBlocks: [
            tc('sb1', 'Subagent', '{"subagent_type":"Explore","prompt":"找 catalog 注册表在哪个文件、如何加一条"}',
                summary: '探查注册表位置', danger: 'safe'),
            // The E3 nested trajectory — child blocks of the Subagent call (parentBlockId = 'sb1'), so the
            // card renders the NestedRunPane. E3 嵌套轨迹子块(parentBlockId=sb1),卡片渲 NestedRunPane.
            ChatBlock(id: 'sb1_n1', parentBlockId: 'sb1', type: 'reasoning', status: 'completed', content: '先定位 catalog 注册表在哪个文件,用 Grep 搜关键符号。'),
            ChatBlock(id: 'sb1_n2', parentBlockId: 'sb1', type: 'tool_call', status: 'completed', content: '{"pattern":"toolCardSpecFor"}', attrs: const {'tool': 'Grep', 'summary': '搜注册表'}),
            ChatBlock(id: 'sb1_n3', parentBlockId: 'sb1', type: 'text', status: 'completed', content: '找到 tool_card_catalog.dart,注册在 _catalog Map。'),
            tr('sb1', '# 注册表位置\n\n`tool_card_catalog.dart` 的 `_catalog` Map。加一条:在 Map 里加 `\'tool_name\': ToolCardSpec(...)`,verb/target/receipt/body 四槽按需填。'),
            tc('sb2', 'get_subagent_trace', '{}',
                summary: '列本对话的子代理运行', danger: 'safe'),
            tr('sb2', '{"count":2,"subagentRuns":[{"subagentRunId":"subagt_01","status":"ok","finalText":"找到注册表在 tool_card_catalog.dart","blockCount":3,"spawningToolCallId":"sb1"},{"subagentRunId":"subagt_02","status":"failed","finalText":"未找到匹配文件","blockCount":2,"spawningToolCallId":"sb0"}]}'),
            txt('cv_show_nested_end', 'text', '子代理已定位:注册表在 `tool_card_catalog.dart` 的 `_catalog` Map。上面是本对话两次子代理运行的台账。'),
          ]),

      // B7 生态收尾 — todo/relations/capability/mcp.
      showcase('cv_show_eco', '展台 · 生态工具', const Duration(minutes: 12),
          userText: '规划一下这次改造的清单,查一下这个 agent 依赖了谁,给工作流做个体检,再把 acme MCP 重连一下',
          lead: '这就安排:',
          assistantBlocks: [
            tc('eo1', 'todo_write', '{"items":[{"content":"盘点后端契约","status":"completed"},{"content":"设计 tool 卡","activeForm":"正在设计 tool 卡","status":"in_progress"},{"content":"写 widget 测试","status":"pending"},{"content":"真机截图审","status":"pending"}]}',
                summary: '更新任务清单', danger: 'safe'),
            tr('eo1', '- [x] 盘点后端契约\n- [→] 正在设计 tool 卡\n- [ ] 写 widget 测试\n- [ ] 真机截图审\nKeep exactly one task in_progress; mark a task completed as soon as it is done.'),
            tc('eo2', 'get_relations', '{"kind":"agent","id":"ag_9f8e7d6c5b4a3f2e"}',
                summary: '查依赖邻域', danger: 'safe'),
            tr('eo2', '{"count":3,"edges":[{"fromKind":"agent","fromId":"ag_9f8e7d6c5b4a3f2e","fromName":"invoice_triager","toKind":"function","toId":"fn_1a2b3c4d5e6f7a8b","toName":"fetch_with_retry"},{"fromKind":"agent","fromId":"ag_9f8e7d6c5b4a3f2e","fromName":"invoice_triager","toKind":"handler","toId":"hd_5c4b3a2f1e0d9c8b","toName":"charge"},{"fromKind":"workflow","fromId":"wf_1a2b3c4d5e6f7a8b","fromName":"quarter_close","toKind":"agent","toId":"ag_9f8e7d6c5b4a3f2e","toName":"invoice_triager"}]}'),
            tc('eo3', 'capability_check_workflow', '{"workflowId":"wf_1a2b3c4d5e6f7a8b"}',
                summary: '工作流结构体检', danger: 'safe'),
            tr('eo3', '{"id":"wf_1a2b3c4d5e6f7a8b","ok":false,"structurallyValid":true,"resolved":false,"problems":["node charge references handler hd_x which was deleted","entry trigger has no downstream edge"],"warnings":["agent triager has no outputSchema — downstream nodes read free text"]}'),
            tc('eo4', 'reconnect_mcp', '{"name":"acme"}',
                summary: '重连 acme 服务器', danger: 'cautious'),
            tr('eo4', '{"id":"mcp_1","name":"acme","status":"connected","consecutiveFailures":0,"totalCalls":42,"totalFailures":1,"tools":[{"name":"search_docs"},{"name":"fetch_page"},{"name":"create_issue"}]}'),
            txt('cv_show_eco_end', 'text', '清单已更新、依赖已列出;**体检发现工作流有 2 个阻塞问题**(见红色项),acme 已重连(3 个工具)。建议先修体检问题再跑。'),
          ]),
      showcase('cv_show_human', '展台 · 人在环', const Duration(minutes: 16),
          userText: '这批发票要放款,先确认下环境,批准放款审批,再看看还有哪些待审批的',
          lead: '好,依次处理人在环节点:',
          assistantBlocks: [
            tc('human0', 'ask_user', '{"message":"这批发票要部署到哪个环境?","options":["生产环境","预发环境","测试环境"]}', summary: '向用户确认部署环境,得到「生产环境」。', danger: 'safe'),
            tr('human0', '生产环境'),
            tc('human1', 'decide_approval', '{"flowrunId":"flr_a1b2c3d4e5f60718","nodeId":"approve_payout","decision":"yes","reason":"金额在授权额度内,采购单与发票一致,批准放款。"}', summary: '批准 flr_a1b2… 的放款审批,run 随即完成。', danger: 'cautious'),
            tr('human1', '{"flowrun":{"id":"flr_a1b2c3d4e5f60718","workflowId":"wfl_7788990011223344","versionId":"wfv_1122334455667788","pinnedRefs":{"apr_payout_gate":"apv_9911"},"status":"completed","replayCount":0,"startedAt":"2026-07-06T09:12:03Z","completedAt":"2026-07-06T09:15:44Z","updatedAt":"2026-07-06T09:15:44Z"},"nodes":[{"id":"frn_01","flowrunId":"flr_a1b2c3d4e5f60718","nodeId":"trigger","iteration":0,"kind":"trigger","ref":"trg_manual","status":"completed","result":{},"createdAt":"2026-07-06T09:12:03Z","completedAt":"2026-07-06T09:12:03Z","updatedAt":"2026-07-06T09:12:03Z"},{"id":"frn_02","flowrunId":"flr_a1b2c3d4e5f60718","nodeId":"approve_payout","iteration":0,"kind":"approval","ref":"apr_payout_gate","status":"completed","result":{"decision":"yes","reason":"金额在授权额度内"},"createdAt":"2026-07-06T08:40:11Z","completedAt":"2026-07-06T09:15:40Z","updatedAt":"2026-07-06T09:15:40Z"},{"id":"frn_03","flowrunId":"flr_a1b2c3d4e5f60718","nodeId":"payout","iteration":0,"kind":"action","ref":"fn_bank_payout","status":"completed","result":{"ok":true,"txId":"pay_5521"},"createdAt":"2026-07-06T09:15:41Z","completedAt":"2026-07-06T09:15:44Z","updatedAt":"2026-07-06T09:15:44Z"}]}'),
            tc('human2', 'list_approval_inbox', '{}', summary: '列出当前停泊等待人工审批的 3 个 run。', danger: 'safe'),
            tr('human2', '{"parked":[{"flowrunId":"flr_a1b2c3d4e5f60718","nodeId":"approve_payout","ref":"apr_payout_gate","rendered":"# 放款审批\\n供应商 华东物流 请款 ¥48,200.00,请复核采购单 PO-2026-0715 后决定。","parkedAt":"2026-07-06T08:40:11Z"},{"flowrunId":"flr_c3d4e5f6a7b80920","nodeId":"approve_refund","ref":"apr_refund_gate","rendered":"# 退款审批\\n订单 SO-2026-1180 申请退款 ¥1,260.00,原因:客户取消。","parkedAt":"2026-07-06T08:52:47Z"},{"flowrunId":"flr_e5f6a7b8c9d01122","nodeId":"approve_publish","ref":"apr_report_gate","rendered":"# 报表发布审批\\n6 月经营月报已生成,待批准对外发布。","parkedAt":"2026-07-06T09:03:12Z"}],"count":3}'),
            tc('human3', 'decide_approval', '{"flowrunId":"flr_ffee00112233aabb","nodeId":"approve_payout","decision":"no","reason":"金额超授权额度"}', summary: '尝试否决放款审批,但该节点已不在等待决策(首决已胜)。', danger: 'cautious'),
            tr('human3', 'approval node is not awaiting a decision'),
          ]),
      showcase('cv_show_build', '展台 · 建造实体', const Duration(minutes: 20),
          userText: '帮我把整套发票对账搭起来:工作流、拉取函数、webhook 触发器、金额控制器、退款审批、模板文档',
          lead: '这就逐个建造:',
          assistantBlocks: [
            tc('build0', 'create_workflow', '{"name":"invoice_reconcile","description":"每日对账发票并异常审批","ops":[{"op":"add_node","node":{"id":"start","kind":"trigger","ref":"trg_9a1f"}},{"op":"add_node","node":{"id":"fetch","kind":"action","ref":"fn_pull_invoices"}},{"op":"add_node","node":{"id":"gate","kind":"control","ref":"ctl_amount_gate"}},{"op":"add_node","node":{"id":"approve","kind":"approval","ref":"apf_refund"}},{"op":"add_edge","edge":{"id":"e1","from":"start","to":"fetch"}},{"op":"add_edge","edge":{"id":"e2","from":"fetch","to":"gate"}},{"op":"add_edge","edge":{"id":"e3","from":"gate","to":"approve","fromPort":"high"}}],"changeReason":"新建发票对账流"}', summary: '新建发票对账工作流:触发→拉取→金额门→退款审批四节点,门的 high 分支进审批', danger: 'cautious'),
            tr('build0', '{"id":"wf_3c7e21","versionId":"wfv_88a0","version":1,"active":false,"lifecycleState":"inactive"}'),
            tc('build1', 'create_function', '{"ops":[{"op":"set_meta","name":"pull_invoices","description":"从 ERP 拉取当日待对账发票","tags":["finance","erp"]},{"op":"set_inputs","inputs":[{"name":"date","type":"string","description":"账期 YYYY-MM-DD"}]},{"op":"set_outputs","outputs":[{"name":"invoices","type":"array","description":"发票列表"}]},{"op":"set_dependencies","dependencies":["requests==2.31","pandas"]},{"op":"set_code","code":"def main(date: str) -> dict:\\n    import requests\\n    r = requests.get(f\\"https://erp.local/invoices?date={date}\\")\\n    return {\\"invoices\\": r.json()}"}],"changeReason":"新建发票拉取函数"}', summary: '新建 pull_invoices 函数,pandas 依赖自动修一次后装成 (env ready)', danger: 'cautious'),
            tr('build1', '{"id":"fn_5b2d90","versionId":"fnv_1a20","version":1,"envStatus":"ready","opsApplied":5,"envFixAttempts":[{"attempt":1,"deps":["requests==2.31","pandas"],"ok":false,"error":"ERROR: Could not find a version that satisfies pandas"},{"attempt":2,"deps":["requests==2.31","pandas==2.2.2"],"ok":true}]}'),
            tc('build2', 'create_trigger', '{"name":"github_push","kind":"webhook","config":{"path":"github","secret":"whsec_8f2a3c","signatureAlgo":"hmac-sha256-hex"}}', summary: '新建 github_push webhook 触发器,HMAC-SHA256 签名校验,未被激活 workflow 引用故未监听', danger: 'cautious'),
            tr('build2', '{"id":"trg_4d9c11","name":"github_push","description":"","kind":"webhook","config":{"path":"github","secret":"whsec_8f2a3c","signatureAlgo":"hmac-sha256-hex"},"outputs":[{"name":"firedAt","type":"string","description":"When the request arrived (RFC3339)."},{"name":"method","type":"string","description":"HTTP method of the request."},{"name":"path","type":"string","description":"The mounted webhook path that was hit."},{"name":"headers","type":"object","description":"Request headers (flattened)."},{"name":"body","type":"object","description":"Posted body parsed as JSON (present when the body is valid JSON)."},{"name":"bodyRaw","type":"string","description":"Raw body string (present when the body is not JSON)."}],"createdAt":"2026-07-06T09:12:44Z","updatedAt":"2026-07-06T09:12:44Z","refCount":0,"listening":false}'),
            tc('build3', 'create_control', '{"name":"amount_gate","description":"按金额分流退款审批","inputs":[{"name":"amount","type":"number","description":"退款金额"}],"branches":[{"port":"high","when":"input.amount >= 1000","emit":{"level":"\'high\'"}},{"port":"mid","when":"input.amount >= 100","emit":{"level":"\'mid\'"}},{"port":"low","when":"true","emit":{"level":"\'low\'"}}]}', summary: '新建 amount_gate 控制器,按退款金额三档分流 high/mid/low', danger: 'safe'),
            tr('build3', '{"id":"ctl_2a8f30","name":"amount_gate","activeVersionId":"ctlv_77b1","version":1}'),
            tc('build4', 'create_approval', '{"name":"refund_approval","description":"退款审批表单","inputs":[{"name":"user","type":"string"},{"name":"amount","type":"number"}],"template":"批准对 {{ input.user }} 的退款 **{{ input.amount }}** 元?","allowReason":true,"timeout":"2h","timeoutBehavior":"reject"}', summary: '新建退款审批表单,2 小时超时自动驳回,含理由输入', danger: 'safe'),
            tr('build4', '{"id":"apf_6c1e90","name":"refund_approval","activeVersionId":"apfv_33d0","version":1}'),
            tc('build5', 'create_document', '{"name":"月度对账模板","content":"# 月度对账模板\\n\\n## 目标\\n每月核对 ERP 发票与银行流水,标记异常项。\\n\\n## 步骤\\n1. 拉取当月发票\\n2. 匹配银行流水\\n3. 异常项提交审批\\n","tags":["finance","sop"]}', summary: '新建月度对账模板文档,含目标与三步流程', danger: 'safe'),
            tr('build5', 'Created document "月度对账模板" (id=doc_7f3a2b, path=/月度对账模板).'),
          ]),
      showcase('cv_show_census', '展台 · 查阅与检索', const Duration(minutes: 24),
          userText: '看下这个函数和工作流、搜一下发票相关函数、这个 agent 能删吗、重启下 handler、列一下对话',
          lead: '我来查阅:',
          assistantBlocks: [
            tc('census0', 'get_function', '{"functionId":"fn_a1b2c3d4e5f60718"}', summary: '查看函数「抓取发票明细」的活跃版本代码与签名', danger: 'safe'),
            tr('census0', '{"id":"fn_a1b2c3d4e5f60718","name":"抓取发票明细","description":"按发票号从财务系统拉取明细行","tags":["财务","发票"],"activeVersionId":"fnv_9f8e7d6c5b4a3021","createdAt":"2026-06-28T09:12:00Z","updatedAt":"2026-07-01T14:30:00Z","activeVersion":{"id":"fnv_9f8e7d6c5b4a3021","functionId":"fn_a1b2c3d4e5f60718","version":3,"code":"import httpx\\n\\ndef main(invoice_no: str) -> dict:\\n    resp = httpx.get(f\\"https://erp.local/api/invoices/{invoice_no}\\")\\n    resp.raise_for_status()\\n    data = resp.json()\\n    return {\\"lines\\": data[\\"lines\\"], \\"total\\": data[\\"total\\"]}\\n","inputs":[{"name":"invoice_no","type":"string"}],"outputs":[{"name":"lines","type":"array"},{"name":"total","type":"number"}],"dependencies":["httpx==0.27.0"],"pythonVersion":"3.12","envId":"env_1122334455667788","envStatus":"ready"}}'),
            tc('census1', 'get_workflow', '{"workflowId":"wf_5a6b7c8d9e0f1122"}', summary: '查看工作流「月度对账流程」的图与状态(需关注:引用的函数已被删除)', danger: 'safe'),
            tr('census1', '{"id":"wf_5a6b7c8d9e0f1122","name":"月度对账流程","description":"每月拉取银行流水与账面比对并生成差异报告","tags":["对账"],"active":true,"lifecycleState":"active","concurrency":"serial","needsAttention":true,"attentionReason":"节点「生成差异报告」引用的函数已被删除","lastActionBy":"ai","activeVersionId":"wfv_aabbccdd11223344","createdAt":"2026-06-20T08:00:00Z","updatedAt":"2026-07-02T10:15:00Z","activeVersion":{"id":"wfv_aabbccdd11223344","workflowId":"wf_5a6b7c8d9e0f1122","version":5,"graphParsed":{"nodes":[{"id":"n1","kind":"function","ref":"fn_bank"},{"id":"n2","kind":"function","ref":"fn_ledger"},{"id":"n3","kind":"control","ref":"ctl_diff"},{"id":"n4","kind":"agent","ref":"ag_report"}],"edges":[{"id":"e1","from":"n1","to":"n3"},{"id":"e2","from":"n2","to":"n3"},{"id":"e3","from":"n3","to":"n4"}]}}}'),
            tc('census2', 'search_function', '{"query":"发票"}', summary: '搜索「发票」相关函数,命中 3 个', danger: 'safe'),
            tr('census2', '{"count":3,"total":3,"functions":[{"id":"fn_a1b2c3d4e5f60718","name":"抓取发票明细","description":"按发票号从财务系统拉取明细行"},{"id":"fn_2233445566778899","name":"发票合规校验","description":"校验发票抬头、税号、金额一致性"},{"id":"fn_00aabbccddeeff11","name":"发票批量导出","description":"导出指定月份全部发票为 Excel"}]}'),
            tc('census3', 'delete_agent', '{"agentId":"ag_7788990011223344"}', summary: '删除 agent,2 个工作流仍引用它、可能失效', danger: 'dangerous'),
            tr('census3', 'Deleted agent "ag_7788990011223344". Note: this entity was referenced by other entities (workflows/agents that equipped it, or documents that linked it); they may now fail — the referencing entities are listed in `dependents`; edit each to drop or repoint the now-dead reference. Referencing entities: [wf_5a6b7c8d9e0f1122 wf_1020304050607080].'),
            tc('census4', 'restart_handler', '{"handlerId":"hd_3344556677889900"}', summary: '重启 handler 失败——crashed:缺 DB_DSN 配置', danger: 'cautious'),
            tr('census4', '{"id":"hd_3344556677889900","runtimeState":"crashed","error":"__init__ raised: KeyError: \'DB_DSN\' — set the config value then restart"}'),
            tc('census5', 'list_conversations', '{"includeArchived":false,"limit":50}', summary: '列出全部对话,共 3 个(含一条空标题)', danger: 'safe'),
            tr('census5', '{"conversations":[{"conversationId":"cv_a1b2c3d4e5f6a7b8","title":"重构对账工作流","archived":false,"pinned":true,"lastMessageAt":"2026-07-05T16:20:00Z"},{"conversationId":"cv_1122334455667788","title":"发票函数联调","archived":false,"pinned":false,"lastMessageAt":"2026-07-04T11:05:00Z"},{"conversationId":"cv_99aabbccddeeff00","title":"","archived":false,"pinned":false,"lastMessageAt":"2026-07-03T09:40:00Z"}],"count":3}'),
          ]),
      showcase('cv_show_shell', '展台 · 文件与终端', const Duration(minutes: 28),
          userText: '跑下单测、看后台任务、写个归一化函数、改下回落值、搜一下 applyDiscount、找找 py 文件',
          lead: '动手:',
          assistantBlocks: [
            tc('shell0', 'Bash', '{"command":"go test ./internal/app/tool/... -run TestInvoice"}', summary: '跑发票相关函数单测,两个包全过 exit 0', danger: 'cautious'),
            tr('shell0', 'ok   anselm/internal/app/tool/function   0.842s\nok   anselm/internal/app/tool/handler   0.311s\n\n[exit code: 0]'),
            tc('shell1', 'BashOutput', '{"bash_id":"bsh_a1b2c3d4e5f60718"}', summary: '轮询后台会话,报表生成进行中(running)', danger: 'safe'),
            tr('shell1', '[2/4] 生成月度报表 inv_2026Q2…\n[3/4] 汇总应收账款…\n\n[status: running]'),
            tc('shell2', 'Write', '{"file_path":"/Users/anselm/foryx/functions/normalize_invoice.py","content":"def normalize(inv: dict) -> dict:\\n    inv[\\"amount\\"] = round(float(inv[\\"amount\\"]), 2)\\n    inv[\\"currency\\"] = inv.get(\\"currency\\", \\"CNY\\")\\n    return inv\\n"}', summary: '新建 normalize_invoice.py 归一化函数', danger: 'cautious'),
            tr('shell2', 'Wrote /Users/anselm/foryx/functions/normalize_invoice.py'),
            tc('shell3', 'Edit', '{"file_path":"/Users/anselm/foryx/functions/normalize_invoice.py","old_string":"inv[\\"currency\\"] = inv.get(\\"currency\\", \\"CNY\\")","new_string":"inv[\\"currency\\"] = inv.get(\\"currency\\", \\"CNY\\").upper()"}', summary: '把 currency 回落值改为大写归一化', danger: 'cautious'),
            tr('shell3', 'Replaced 1 occurrence in /Users/anselm/foryx/functions/normalize_invoice.py.'),
            tc('shell4', 'Grep', '{"pattern":"applyDiscount","path":"/Users/anselm/foryx/functions","output_mode":"content","-n":true}', summary: '在 functions 下检索 applyDiscount,命中 3 行', danger: 'safe'),
            tr('shell4', '/Users/anselm/foryx/functions/checkout.py:42:    total = applyDiscount(total, coupon)\n/Users/anselm/foryx/functions/checkout.py:88:    return applyDiscount(subtotal, 0.1)\n/Users/anselm/foryx/functions/pricing.py:15:def applyDiscount(amount, rate):'),
            tc('shell5', 'Glob', '{"pattern":"**/*.py","path":"/Users/anselm/foryx/functions"}', summary: '按 **/*.py 找到 2 个文件,按 mtime 降序', danger: 'safe'),
            tr('shell5', '{"root":"/Users/anselm/foryx/functions","matches":[{"path":"/Users/anselm/foryx/functions/pricing.py","type":"file","size":1840,"mtime":"2026-07-06T14:28:11+08:00"},{"path":"/Users/anselm/foryx/functions/checkout.py","type":"file","size":3120,"mtime":"2026-07-06T14:12:03+08:00"}],"total":2,"truncated":false}'),
          ]),
    ];
