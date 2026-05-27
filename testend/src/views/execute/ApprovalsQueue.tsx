import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { getPage } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, RelTime, StatusBadge } from "@/ui";
import type { FlowRun } from "@frontend/entities/flowrun/model/types";

export function ApprovalsQueue() {
  const { data } = useQuery({
    queryKey: qk.flowruns({ status: "paused" }),
    queryFn: () => getPage<FlowRun>("/api/v1/flowruns", { status: "paused", limit: 50 }),
  });
  if (!data || data.data.length === 0) return <EmptyView>no paused flowruns awaiting approval</EmptyView>;
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 12, display: "flex", flexDirection: "column", gap: 8 }}>
      {data.data.map((r) => (
        <div key={r.id} style={{
          padding: 12, border: "1px solid var(--border)", borderRadius: 4,
          display: "flex", justifyContent: "space-between", alignItems: "center",
        }}>
          <div>
            <div>
              <span className="mono">workflow</span> <code>{r.workflowId}</code> · run <code>{r.id.slice(-12)}</code>
              <span style={{ marginLeft: 8 }}><StatusBadge status={r.status} /></span>
            </div>
            <div className="muted" style={{ fontSize: 11, marginTop: 4 }}>
              started <RelTime ts={r.startedAt} /> · trigger {r.triggerKind}
            </div>
            {r.pausedState && (
              <div className="muted mono" style={{ fontSize: 10, marginTop: 4 }}>
                paused: {JSON.stringify(r.pausedState).slice(0, 100)}
              </div>
            )}
          </div>
          <Link to={`/execute/flowruns/${r.id}`} style={{
            padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)",
            borderRadius: 4, textDecoration: "none", fontSize: 12,
          }}>open & approve</Link>
        </div>
      ))}
    </div>
  );
}
