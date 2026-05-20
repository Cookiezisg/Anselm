// FlowRunDetail — header + DAG + node inspector + Gantt timeline.
// Triage panel + run-diff panel surface as inline collapsibles above
// the DAG when toggled.
//
// FlowRunDetail —— 头部 + DAG + 节点 inspector + Gantt；triage / diff
// 面板 inline 折叠。

import { useState } from "react";
import { Icon } from "../../components/primitives/Icon.jsx";
import { Button } from "../../components/primitives/Button.jsx";
import { Badge } from "../../components/primitives/Badge.jsx";
import { RelTime } from "../../components/shared/RelTime.jsx";
import { EntityRelMeta } from "../../components/shared/EntityRelMeta.jsx";
import { ApprovalBanner } from "./ApprovalBanner.jsx";
import {
  useFlowRun, useFlowRunNodes, useCancelFlowRun, useApproveNode,
  useRejectNode, useTriageFlowRun,
} from "../../api/flowruns.js";
import { useUIStore } from "../../store/ui.js";

const STATUS_KIND = {
  running: "streaming",
  completed: "success",
  failed: "error",
  waiting_approval: "warn",
  paused: "info",
  cancelled: "muted",
};
const STATUS_LABEL = {
  running: "运行中", completed: "完成", failed: "失败",
  waiting_approval: "待批准", paused: "已暂停", cancelled: "已取消",
};

function statusBadge(s) {
  return <Badge kind={STATUS_KIND[s] || "muted"}>{STATUS_LABEL[s] || s}</Badge>;
}

function fmtDuration(ms) {
  if (ms == null) return "—";
  if (ms < 1000) return ms + "ms";
  if (ms < 60_000) return (ms / 1000).toFixed(1) + "s";
  const m = Math.floor(ms / 60_000);
  const s = Math.round((ms % 60_000) / 1000);
  return `${m}m ${s}s`;
}

export function FlowRunDetail({ runId, onBack }) {
  const { data: fr } = useFlowRun(runId);
  const { data: nodes = [] } = useFlowRunNodes(runId);
  const cancel = useCancelFlowRun();
  const triage = useTriageFlowRun();
  const pushToast = useUIStore((s) => s.pushToast);
  const setActiveConv = useUIStore((s) => s.setActiveConv);
  const openPane = useUIStore((s) => s.openPane);

  const [selectedNodeId, setSelectedNodeId] = useState(null);

  if (!fr) return <div className="empty" style={{ padding: 48 }}><div className="sub">加载 flowrun…</div></div>;

  const okCount   = nodes.filter((n) => n.status === "ok"      || n.status === "completed").length;
  const failCount = nodes.filter((n) => n.status === "fail"    || n.status === "failed").length;
  const skipCount = nodes.filter((n) => n.status === "skip"    || n.status === "pending").length;
  const failedNode = nodes.find((n) => n.status === "fail"     || n.status === "failed");
  const selected = nodes.find((n) => n.id === selectedNodeId) || nodes[0];

  const onTriage = async () => {
    try {
      const res = await triage.mutateAsync(runId);
      const cid = res?.conversationId;
      if (cid) {
        setActiveConv(cid);
        openPane("chat");
        pushToast({ kind: "success", title: "AI 排查对话已开启" });
      }
    } catch (e) {
      pushToast({ kind: "error", title: "排查失败", desc: e.message });
    }
  };

  return (
    <div className="page">
      <div className="page-header" style={{ paddingTop: 18 }}>
        <div className="page-header-text" style={{ gap: 6 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 12, color: "var(--fg-muted)" }}>
            <Button size="xs" variant="ghost" onClick={onBack}>← 返回</Button>
            <span>·</span>
            <span className="cell-mono">{fr.id}</span>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <div className="page-title" style={{ fontFamily: "var(--font-mono)" }}>{fr.workflow || fr.workflowId}</div>
            {statusBadge(fr.status)}
          </div>
          <div className="page-subtitle" style={{ display: "flex", alignItems: "center", gap: 4, flexWrap: "wrap" }}>
            <span>
              由 <code style={{ fontFamily: "var(--font-mono)" }}>{fr.trigger || fr.triggerKind || "?"}</code> 触发 · <RelTime ts={fr.startedAt} />
            </span>
            <span style={{ color: "var(--status-success)" }}> · {okCount} ok</span>
            {failCount > 0 && <span style={{ color: "var(--status-error)" }}> · {failCount} fail</span>}
            {skipCount > 0 && <span style={{ color: "var(--fg-faint)" }}> · {skipCount} skip</span>}
            <EntityRelMeta entityId={fr.id} />
          </div>
        </div>
        <div className="page-actions">
          {fr.status === "running" && (
            <Button size="sm" variant="danger" onClick={() => cancel.mutate(runId)}>
              <Icon.StopCircle /> 取消
            </Button>
          )}
          {fr.status === "failed" && (
            <Button size="sm" onClick={onTriage}>
              <Icon.Sparkles /> AI 排查
            </Button>
          )}
          <Button size="sm"><Icon.Refresh /> 重跑</Button>
        </div>
      </div>

      <ApprovalBanner runId={runId} nodes={nodes} />

      <div className="fr-shell">
        <FlowRunDag nodes={nodes} selected={selected?.id} onSelect={setSelectedNodeId} />
        <NodeInspector node={selected} fr={fr} />
      </div>
      <GanttTimeline nodes={nodes} />
    </div>
  );
}

function nodeStatusIcon(status) {
  if (status === "ok" || status === "completed") return <Icon.Check style={{ width: 12, height: 12, color: "var(--status-success)" }} />;
  if (status === "fail" || status === "failed") return <Icon.X style={{ width: 12, height: 12, color: "var(--status-error)" }} />;
  if (status === "running") return <span className="spinner" style={{ width: 12, height: 12, borderColor: "color-mix(in srgb, var(--accent) 30%, transparent)", borderTopColor: "var(--accent)" }} />;
  if (status === "waiting" || status === "wait") return <Icon.Clock style={{ width: 12, height: 12, color: "var(--status-warn)" }} />;
  return <span style={{ width: 8, height: 8, borderRadius: "50%", border: "1.5px dashed var(--fg-faint)" }} />;
}

function FlowRunDag({ nodes, selected, onSelect }) {
  if (!nodes || nodes.length === 0) {
    return <div className="empty" style={{ padding: 32, flex: 1 }}><div className="sub">没有节点数据</div></div>;
  }
  // Lay out nodes by their layer (if absent, simple stack).
  const positioned = nodes.map((n, i) => ({
    ...n,
    x: typeof n.x === "number" ? n.x : 220 * (i % 4),
    y: typeof n.y === "number" ? n.y : 100 * Math.floor(i / 4),
  }));
  const byId = Object.fromEntries(positioned.map((n) => [n.id, n]));
  const edges = nodes.flatMap((n) => (n.dependsOn || n.parents || []).map((from) => ({ from, to: n.id })));

  return (
    <div className="fr-dag">
      <svg className="fr-dag-edges" width="100%" height="100%">
        <defs>
          <marker id="fr-arr" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
            <path d="M0 0 L10 5 L0 10 z" fill="var(--border-strong)" />
          </marker>
        </defs>
        {edges.map((e, i) => {
          const a = byId[e.from], b = byId[e.to];
          if (!a || !b) return null;
          const sx = a.x + 92, sy = a.y + 60;
          const ex = b.x + 92, ey = b.y;
          const dy = Math.max(30, (ey - sy) / 2);
          const d = `M ${sx} ${sy} C ${sx} ${sy + dy}, ${ex} ${ey - dy}, ${ex} ${ey}`;
          return <path key={i} d={d} fill="none" stroke="var(--border-strong)" strokeWidth="1.4" markerEnd="url(#fr-arr)" />;
        })}
      </svg>
      {positioned.map((n) => (
        <div
          key={n.id}
          className={"fr-dag-node fr-status-" + (n.status || "pending") + (selected === n.id ? " is-selected" : "")}
          style={{ left: n.x, top: n.y }}
          onClick={() => onSelect(n.id)}
          title={n.id}
        >
          <div className="fr-dag-node-head">
            {nodeStatusIcon(n.status)}
            <span className="cell-mono" style={{ fontSize: 10, color: "var(--fg-muted)" }}>{n.kind || "?"}</span>
          </div>
          <div className="fr-dag-node-title">{n.label || n.id}</div>
          <div className="fr-dag-node-sub">
            {n.durationMs != null ? fmtDuration(n.durationMs) : n.status === "running" ? "运行中…" : n.status === "pending" ? "等待" : "—"}
          </div>
        </div>
      ))}
    </div>
  );
}

function NodeInspector({ node, fr }) {
  if (!node) {
    return (
      <div className="fr-inspector">
        <div className="empty" style={{ padding: "32px 16px" }}>
          <Icon.Filter className="icon" />
          <div className="title">点节点查看细节</div>
          <div className="sub">input · output · log · 重试</div>
        </div>
      </div>
    );
  }
  return (
    <div className="fr-inspector">
      <div className="fr-inspector-head">
        <div className="fr-inspector-title">
          {nodeStatusIcon(node.status)}
          <span>{node.label || node.id}</span>
        </div>
        <div className="fr-inspector-meta">
          {node.kind && <span className="kind-chip fn">{node.kind}</span>}
          {node.durationMs != null && <span className="cell-mono">{fmtDuration(node.durationMs)}</span>}
        </div>
        {node.error && <div className="fr-inspector-error">{node.error}</div>}
      </div>
      <div className="fr-inspector-body">
        {node.input != null && (
          <div className="fr-section">
            <div className="fr-section-label">Input</div>
            <pre className="code-block" style={{ fontSize: 11 }}>{prettyJSON(node.input)}</pre>
          </div>
        )}
        {node.output != null && (
          <div className="fr-section">
            <div className="fr-section-label">Output</div>
            <pre className="code-block" style={{ fontSize: 11 }}>{prettyJSON(node.output)}</pre>
          </div>
        )}
        {Array.isArray(node.log) && node.log.length > 0 && (
          <div className="fr-section">
            <div className="fr-section-label">Log</div>
            <div className="fr-log">
              {node.log.map((l, i) => (
                <div key={i} className={"fr-log-row level-" + (l.level || "info")}>
                  <span className="fr-log-time">{l.time}</span>
                  <span className="fr-log-level">{l.level || "info"}</span>
                  <span className="fr-log-msg">{l.msg}</span>
                </div>
              ))}
            </div>
          </div>
        )}
        {node.input == null && node.output == null && (!node.log || node.log.length === 0) && (
          <div className="empty" style={{ padding: 20 }}>
            <div className="sub" style={{ color: "var(--fg-faint)" }}>没有 input/output/log（跳过或未运行）</div>
          </div>
        )}
      </div>
    </div>
  );
}

function prettyJSON(v) {
  try { return JSON.stringify(v, null, 2); } catch { return String(v); }
}

function GanttTimeline({ nodes }) {
  if (!nodes || nodes.length === 0) return null;
  const total = Math.max(...nodes.map((n) => (n.startedMs ?? 0) + (n.durationMs ?? 0)), 1);
  return (
    <div className="fr-gantt">
      <div className="fr-gantt-head">
        <span className="fr-gantt-title">时间线</span>
        <span className="cell-mono" style={{ color: "var(--fg-faint)" }}>
          总耗时 {fmtDuration(total)} · 0ms 起点
        </span>
      </div>
      <div className="fr-gantt-body">
        {nodes.map((n) => {
          const start = n.startedMs ?? 0;
          const dur = n.durationMs ?? 0;
          const left = (start / total * 100).toFixed(1) + "%";
          const width = Math.max(0.5, (dur / total) * 100).toFixed(1) + "%";
          const color = n.status === "fail" || n.status === "failed" ? "var(--status-error)"
            : n.status === "running" ? "var(--accent)"
            : n.status === "ok" || n.status === "completed" ? "var(--status-success)"
            : "var(--fg-faint)";
          return (
            <div key={n.id} className="fr-gantt-row">
              <div className="fr-gantt-label">{n.label || n.id}</div>
              <div className="fr-gantt-track">
                {n.startedMs != null
                  ? <div className={"fr-gantt-bar status-" + (n.status || "pending")} style={{ left, width, background: color }} />
                  : <div className="fr-gantt-pending">未运行</div>}
              </div>
              <div className="fr-gantt-dur cell-mono">{dur ? fmtDuration(dur) : "—"}</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
