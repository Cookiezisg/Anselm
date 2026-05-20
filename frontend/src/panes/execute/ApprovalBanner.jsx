// ApprovalBanner — sticky banner shown at top of FlowRunDetail when one
// or more nodes are waiting_approval. Each row has approve/reject with
// optional reason. Hits POST /flowruns/{id}/approvals/{nodeId}.
//
// ApprovalBanner —— flowrun 顶部 sticky banner；每个 waiting_approval 节点
// 接 approve/reject + 可选 reason。

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Icon } from "../../components/primitives/Icon.jsx";
import { Button } from "../../components/primitives/Button.jsx";
import { useApproveNode, useRejectNode } from "../../api/flowruns.js";
import { useUIStore } from "../../store/ui.js";
import { slideDown } from "../../motion/tokens.js";

export function ApprovalBanner({ runId, nodes }) {
  const pending = (nodes || []).filter((n) =>
    n.status === "waiting_approval" || n.status === "waiting" || n.status === "wait"
  );
  if (pending.length === 0) return null;

  return (
    <motion.div className="approval-banner" {...slideDown}>
      <div className="approval-banner-head">
        <Icon.Pause style={{ width: 14, height: 14, color: "var(--status-warn)" }} />
        <strong>等待审批</strong>
        <span style={{ color: "var(--fg-muted)" }}>· {pending.length} 个节点需要决定</span>
      </div>
      <div className="approval-banner-list">
        {pending.map((n) => (
          <ApprovalRow key={n.id} runId={runId} node={n} />
        ))}
      </div>
    </motion.div>
  );
}

function ApprovalRow({ runId, node }) {
  const approve = useApproveNode();
  const reject = useRejectNode();
  const pushToast = useUIStore((s) => s.pushToast);
  const [reasonOpen, setReasonOpen] = useState(false);
  const [reason, setReason] = useState("");
  const [decided, setDecided] = useState(null);

  const onApprove = () => {
    approve.mutate(
      { runId, nodeId: node.id, decision: "approve", reason },
      {
        onSuccess: () => { setDecided("approved"); pushToast({ kind: "success", title: "已批准", desc: node.label || node.id }); },
        onError: (e) => pushToast({ kind: "error", title: "批准失败", desc: e.message }),
      }
    );
  };
  const onReject = () => {
    reject.mutate(
      { runId, nodeId: node.id, reason },
      {
        onSuccess: () => { setDecided("rejected"); pushToast({ kind: "warn", title: "已拒绝", desc: node.label || node.id }); },
        onError: (e) => pushToast({ kind: "error", title: "拒绝失败", desc: e.message }),
      }
    );
  };

  if (decided) {
    return (
      <div className={"approval-row is-" + decided}>
        <Icon.Check style={{ width: 12, height: 12 }} />
        <span className="cell-mono">{node.label || node.id}</span>
        <span style={{ color: "var(--fg-muted)" }}>{decided === "approved" ? "已批准" : "已拒绝"}</span>
        {reason && <span style={{ color: "var(--fg-faint)", fontSize: 11 }}>· {reason}</span>}
      </div>
    );
  }

  const busy = approve.isPending || reject.isPending;

  return (
    <div className="approval-row">
      <div className="approval-row-head">
        <Icon.Clock style={{ width: 12, height: 12, color: "var(--status-warn)" }} />
        <span className="cell-mono">{node.label || node.id}</span>
        {node.kind && <span className="kind-chip">{node.kind}</span>}
        <div style={{ flex: 1 }} />
        <Button size="xs" variant="ghost" onClick={() => setReasonOpen((o) => !o)}>
          {reasonOpen ? "收起" : "加理由"}
        </Button>
        <Button size="xs" variant="danger" onClick={onReject} disabled={busy}>
          <Icon.X /> 拒绝
        </Button>
        <Button size="xs" variant="accent" onClick={onApprove} disabled={busy}>
          <Icon.Check /> 批准
        </Button>
      </div>
      <AnimatePresence>
        {reasonOpen && (
          <motion.input
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: "auto" }}
            exit={{ opacity: 0, height: 0 }}
            className="cfg-input"
            style={{ marginTop: 6 }}
            placeholder="审批理由（可选，会写到 flowrun 日志）"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
          />
        )}
      </AnimatePresence>
    </div>
  );
}
