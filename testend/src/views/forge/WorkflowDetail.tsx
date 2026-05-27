import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import ReactFlow, { Background, Controls, type Edge, type Node } from "reactflow";
import "reactflow/dist/style.css";
import { getJSON, postJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, Pill } from "@/ui";
import type { Workflow, WorkflowVersion, Graph } from "@frontend/entities/workflow/model/types";

type Tab = "graph" | "capability" | "runs" | "variables";

export function WorkflowDetail() {
  const { id } = useParams<{ id: string }>();
  const qc = useQueryClient();
  const [tab, setTab] = useState<Tab>("graph");
  const [dryRun, setDryRun] = useState(true);

  const { data: w } = useQuery({
    queryKey: qk.workflow(id ?? ""),
    queryFn: () => getJSON<Workflow>(`/api/v1/workflows/${id}`),
    enabled: !!id,
  });
  const { data: versions = [] } = useQuery({
    queryKey: qk.workflowVersions(id ?? ""),
    queryFn: () => getJSON<WorkflowVersion[]>(`/api/v1/workflows/${id}/versions`),
    enabled: !!id,
  });
  const accept = useMutation({
    mutationFn: () => postJSON(`/api/v1/workflows/${id}:accept`, {}),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.workflow(id ?? "") }),
  });
  const reject = useMutation({
    mutationFn: () => postJSON(`/api/v1/workflows/${id}:reject`, {}),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.workflow(id ?? "") }),
  });
  const run = useMutation<unknown, Error, void>({
    mutationFn: () => postJSON(`/api/v1/workflows/${id}:trigger`, { dryRun, source: "manual" }),
  });
  const capCheck = useMutation<{ ok: boolean; issues?: unknown[] }, Error, void>({
    mutationFn: () => postJSON(`/api/v1/workflows/${id}:check-capabilities`, {}),
  });

  if (!id || !w) return <EmptyView>loading…</EmptyView>;
  const active = versions.find((v) => v.id === w.activeVersionId);
  const pending = versions.find((v) => v.status === "pending");
  const parsed: Graph | undefined = active?.graphParsed;

  const rfNodes: Node[] = (parsed?.nodes ?? []).map((n, i) => ({
    id: n.id,
    data: { label: `${n.type}\n${n.id}` },
    position: (n as unknown as { position?: { x: number; y: number } }).position
      ?? { x: (i % 5) * 180, y: Math.floor(i / 5) * 100 },
    style: {
      background: "var(--bg-paper)", border: "1px solid var(--border)",
      fontSize: 11, padding: 6, borderRadius: 4,
    },
  }));
  const rfEdges: Edge[] = (parsed?.edges ?? []).map((e) => ({
    id: e.id, source: e.from, target: e.to,
  }));

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 12, borderBottom: "1px solid var(--border)" }}>
        <div style={{ display: "flex", gap: 8, alignItems: "baseline" }}>
          <h2 style={{ margin: 0 }}>{w.name}</h2>
          <span className="mono muted" style={{ fontSize: 11 }}>{w.id}</span>
          {w.enabled ? <Pill kind="success">enabled</Pill> : <Pill>disabled</Pill>}
        </div>
        <div className="muted" style={{ fontSize: 12, marginTop: 4 }}>{w.description}</div>
        {pending && (
          <div style={{
            marginTop: 8, padding: "6px 12px", background: "var(--accent-soft)",
            borderRadius: 4, display: "flex", justifyContent: "space-between", alignItems: "center",
          }}>
            <span>pending version <code>{pending.id}</code></span>
            <span>
              <button onClick={() => accept.mutate()} style={{ marginRight: 6, padding: "2px 10px", fontSize: 11 }}>Accept</button>
              <button onClick={() => reject.mutate()} style={{ padding: "2px 10px", fontSize: 11 }}>Reject</button>
            </span>
          </div>
        )}
        <div style={{ marginTop: 8, display: "flex", gap: 8, alignItems: "center" }}>
          <label style={{ fontSize: 11, display: "flex", alignItems: "center", gap: 4 }}>
            <input type="checkbox" checked={dryRun} onChange={(e) => setDryRun(e.target.checked)} />
            dry-run
          </label>
          <button
            onClick={() => run.mutate()}
            disabled={run.isPending}
            style={{
              padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)",
              border: "none", borderRadius: 4, fontSize: 12, cursor: "pointer",
            }}
          >Trigger</button>
        </div>
        {run.data != null && (
          <pre className="raw-json" style={{ marginTop: 8 }}>{JSON.stringify(run.data, null, 2)}</pre>
        )}
      </div>
      <div style={{ display: "flex", gap: 4, padding: "6px 12px", borderBottom: "1px solid var(--border)" }}>
        {(["graph", "capability", "runs", "variables"] as Tab[]).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            style={{
              padding: "4px 12px", fontSize: 12,
              background: tab === t ? "var(--accent)" : "var(--bg-elev)",
              color: tab === t ? "var(--accent-fg)" : "var(--fg-body)",
              border: "none", borderRadius: 3, cursor: "pointer",
            }}
          >{t}</button>
        ))}
      </div>
      <div style={{ flex: 1, overflow: "auto", position: "relative" }}>
        {tab === "graph" && parsed ? (
          <div style={{ width: "100%", height: "100%" }}>
            <ReactFlow nodes={rfNodes} edges={rfEdges} fitView>
              <Background />
              <Controls />
            </ReactFlow>
          </div>
        ) : tab === "graph" ? (
          <EmptyView>no parsed graph on active version</EmptyView>
        ) : null}
        {tab === "capability" && (
          <div style={{ padding: 12 }}>
            <button
              onClick={() => capCheck.mutate()}
              disabled={capCheck.isPending}
              style={{
                padding: "4px 12px", marginBottom: 12,
                background: "var(--accent)", color: "var(--accent-fg)",
                border: "none", borderRadius: 4, fontSize: 12, cursor: "pointer",
              }}
            >Check capabilities</button>
            {capCheck.data && (
              <div>
                <div>ok: {capCheck.data.ok ? "yes" : "no"}</div>
                <pre className="raw-json">{JSON.stringify(capCheck.data.issues ?? [], null, 2)}</pre>
              </div>
            )}
            {capCheck.isError && (
              <div style={{ color: "var(--status-error)" }}>{capCheck.error.message}</div>
            )}
          </div>
        )}
        {tab === "runs" && (
          <div style={{ padding: 12 }}>
            <p className="muted" style={{ fontSize: 12 }}>
              See <a href={`#/execute/flowruns?workflowId=${id}`} style={{ color: "var(--accent)" }}>execute &rsaquo; FlowRuns</a> for run history.
            </p>
          </div>
        )}
        {tab === "variables" && (
          <div style={{ padding: 12 }}>
            <pre className="raw-json">{JSON.stringify(parsed?.variables ?? [], null, 2)}</pre>
          </div>
        )}
      </div>
    </div>
  );
}
