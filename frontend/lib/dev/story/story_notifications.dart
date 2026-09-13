/// The story dataset's notification ledger — every row points at a bible id so the bell tells the same
/// week as the chat, entity, scheduler and library surfaces (the parked digest review, the invoice
/// parser outage, the replayed fetch). Selected by `--dart-define=ANSELM_DEMO_DATASET=story`.
///
/// Only types `notification_copy.dart` has a template for are seeded: an unknown type degrades to a
/// toneless "New activity" row, which would falsify a marketing screenshot. Beats the backend has no
/// Emit event for (a completed run, a decided approval, a finished generation) therefore ride the
/// closest durable type — `attention_changed(false)` for "healthy again", `approval.updated` for a
/// decision, `sandbox.env_status_changed` for a conversation's sandbox outcome — with the story detail
/// carried in payload extras the ledger ignores but a story approvals band can read.
///
/// story 数据集的通知账本——每行都指向故事总纲里的 id，铃铛与聊天、实体、调度、资料库讲同一周
/// （待审的周报、发票解析故障、重放过的抓取）。只播种 `notification_copy.dart` 有模板的 type：未知 type
/// 会退化成无 tone 的「新活动」行，营销截图会失真。后端没有 Emit 事件的情节（run 完成、审批已决、
/// 生成完毕）借最接近的耐久 type 表达，故事细节放在账本忽略、但审批带可读的 payload 扩展键里。
library;

import '../../core/contract/notification.dart';
import '../../features/notifications/data/notification_fixture.dart';
import 'story_bible.dart';
import 'story_locale.dart';

/// Newest-first, as the backend list returns. Three rows stay unread so the bell wears a badge.
/// 最新优先（同后端 list）；三行保持未读，铃铛才有徽标。
FixtureNotificationRepository storyNotificationRepository(StoryLocale l) {
  NotificationItem row(
    String id,
    String type,
    Map<String, dynamic> payload,
    DateTime at, {
    bool read = true,
  }) => NotificationItem(
    id: id,
    type: type,
    payload: payload,
    createdAt: at,
    // A read row is stamped at its own instant: the fixture only needs "some past time" and this keeps
    // the ledger free of a second clock. 已读时戳取行自身时刻——fixture 只需“过去某刻”，免引入第二口钟。
    readAt: read ? at : null,
  );

  return FixtureNotificationRepository(
    seed: [
      // ── Needs you ── the two parked approvals (the approvals band shows the cards; these rows are the
      // durable companions the bell counts). 待你处理：两条停车审批（卡片由审批带出，此处为账本耐久行）。
      row(
        'noti_a1f4c7e29b3d5068',
        'workflow.approval_pending',
        {
          'name': wfDigestName,
          'workflowId': wfDigest,
          'flowrunId': frDigestParked,
          'nodeId': apfDigestName,
          'approvalId': apfDigest,
          'title': l.t('Weekly Digest Review', '周报待审批'),
          'body': digestApprovalBody(l),
          'deadlineAt': ahead(hours: 23).toIso8601String(),
        },
        ago(hours: 1),
        read: false,
      ),
      row(
        'noti_b2e5d8f30c4e6179',
        'workflow.approval_pending',
        {
          'name': apfRefundName,
          'workflowId': wfTriage,
          'flowrunId': frTriageRunning,
          'nodeId': apfRefundName,
          'approvalId': apfRefund,
          'conversationId': cvRefund,
          'title': cvRefundTitle(l),
          'body': l.t(
            'Refund #4821 · \$129.00 · customer Maya Chen (Pro annual)\n'
                'Ticket routed as "billing / high" by route_by_severity. Approve to issue the refund.',
            '退款 #4821 · \$129.00 · 客户 Maya Chen（Pro 年付）\n'
                '工单由 route_by_severity 判为“账单 / 高”。批准即发起退款。',
          ),
        },
        ago(minutes: 26),
        read: false,
      ),

      // ── Today ── 今天
      // The invoice workflow flips to "needs attention" right after its run fails; the env retry is the
      // reason line. 发票工作流在 run 失败后立刻点亮“需关注”，环境重试是其原因行。
      row('noti_c3f6e9a41d5f7280', 'workflow.attention_changed', {
        'name': wfInvoiceName,
        'workflowId': wfInvoice,
        'needsAttention': true,
        'attentionReason': l.t(
          '$fnParseInvoiceName: dependency pdfplumber failed to install, retrying',
          '$fnParseInvoiceName：依赖 pdfplumber 安装失败，正在重试',
        ),
        'functionId': fnParseInvoice,
      }, ago(minutes: 46)),
      row(
        'noti_d4a7f0b52e6a8391',
        'workflow.run_failed',
        {
          'name': wfInvoiceName,
          'workflowId': wfInvoice,
          'flowrunId': frInvoiceFailed,
          'error':
              'pdfplumber.pdf.PDFSyntaxError: No /Root object! - Is this really a PDF? '
              '(invoices/2026-09-12_acme.pdf)',
        },
        ago(minutes: 48),
        read: false,
      ),
      // Overnight triage finished cleanly — the workflow's attention clears (the ledger's only "ok" verb
      // for a workflow). 昨夜工单处理顺利完成——工作流“需关注”熄灭（账本里工作流唯一的 ok 动词）。
      row('noti_e5b8a1c63f7b94a2', 'workflow.attention_changed', {
        'name': wfTriageName,
        'workflowId': wfTriage,
        'flowrunId': frTriageDone1,
        'needsAttention': false,
      }, ago(hours: 2)),
      // The earlier digest review was decided "no"; the decision rides the approval's lifecycle row.
      // 上一次周报审批被驳回；决定挂在审批实体的生命周期行上。
      row('noti_f6c9b2d74a8ca5b3', 'approval.updated', {
        'name': apfDigestName,
        'approvalId': apfDigest,
        'workflowId': wfDigest,
        'flowrunId': frDigestRejected,
        'decision': 'no',
        'reason': l.t(
          'Empty week — widen the lookback window',
          '本周无内容——请放宽回溯窗口',
        ),
      }, ago(hours: 3)),
      // A conversation's failed turn is not an inbox event; its sandbox outcome is. 对话轮次失败不落账本，
      // 其沙箱终态才落。
      row('noti_07d0c3e85b9db6c4', 'sandbox.env_status_changed', {
        'status': 'failed',
        'ownerKind': 'conversation',
        'ownerId': cvFlakyTest,
        'conversationId': cvFlakyTest,
        'errorMsg': l.t(
          'pytest exited 1 · test_parse_invoice_totals failed again on retry 2/2',
          'pytest 退出码 1 · test_parse_invoice_totals 第 2/2 次重试仍失败',
        ),
      }, ago(hours: 4)),
      // The hero-image generation finished; the resize function's env reports ready. 首屏图生成完毕，
      // 压缩函数的环境报告就绪。
      row('noti_18e1d4f96caec7d5', 'sandbox.env_status_changed', {
        'status': 'ready',
        'ownerKind': 'function',
        'ownerId': fnResizeImage,
        'functionId': fnResizeImage,
        'conversationId': cvHeroImages,
        'generated': 3,
        'summary': l.t('3 images generated', '已生成 3 张图片'),
      }, ago(hours: 5)),
      // The MCP mount the digest's GitHub fetch leans on failed to come back after a reconnect.
      // 周报抓取依赖的 MCP 挂载在重连后未恢复。
      row('noti_29f2e5a07dbfd8e6', 'mcp.reconnected', {
        'name': 'github',
        'status': 'failed',
        'error': l.t(
          'mount timed out after 30s — the digest fetch falls back to REST',
          '挂载 30 秒超时——周报抓取回退到 REST',
        ),
      }, ago(hours: 7)),

      // ── Earlier ── 更早
      row('noti_3a03f6b18ec0e9f7', 'skill.created', {
        'name': skillInvoiceParsing,
      }, ago(days: 2, hours: 3)),
      row('noti_4b14a7c29fd1fa08', 'workflow.created', {
        'name': wfReleaseName,
        'workflowId': wfRelease,
      }, ago(days: 3, hours: 1)),
      // The digest fetch failed on GitHub's 502, was replayed, and the workflow recovered — two rows,
      // newest first. 周报抓取因 GitHub 502 失败、经重放后恢复——两行，新者在前。
      row('noti_5c25b8d3a0e20b19', 'workflow.attention_changed', {
        'name': wfDigestName,
        'workflowId': wfDigest,
        'flowrunId': frDigestFailed,
        'needsAttention': false,
        'replayed': true,
      }, ago(days: 5, hours: 2)),
      // Only `fetch_commits` failed; its two parallel siblings (`fetch_pulls`, `fetch_issues`)
      // completed, see `digestRunOutcomes`. 只有 `fetch_commits` 失败，两个并行兄弟节点已完成。
      row('noti_6d36c9e4b1f31c2a', 'workflow.run_failed', {
        'name': wfDigestName,
        'workflowId': wfDigest,
        'flowrunId': frDigestFailed,
        'nodeId': 'fetch_commits',
        'error': l.t(
          'node fetch_commits — HandlerError: $fnFetchGithubName: 502 Bad Gateway (api.github.com)',
          '节点 fetch_commits — HandlerError: $fnFetchGithubName: 502 Bad Gateway (api.github.com)',
        ),
      }, ago(days: 5, hours: 3)),
    ],
  );
}
