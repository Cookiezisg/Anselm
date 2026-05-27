import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { getPage } from "@/api/devClient";
import { useUIStore } from "@/stores/ui";
import { EmptyView, StatusBadge, RelTime } from "@/ui";

type Tab = "function" | "handler" | "mcp" | "skill";

interface ExecRow {
  id: string;
  entityId?: string;
  entityName?: string;
  status: string;
  elapsedMs?: number;
  startedAt?: string;
  errorCode?: string;
}

const ENDPOINTS: Record<Tab, string> = {
  function: "/api/v1/function-executions",
  handler: "/api/v1/handler-calls",
  mcp: "/api/v1/mcp-calls",
  skill: "/api/v1/skill-executions",
};

export function Executions() {
  const [tab, setTab] = useState<Tab>("function");
  const [filter, setFilter] = useState("");
  const ui = useUIStore();
  const { data, isLoading } = useQuery({
    queryKey: ["executions", tab],
    queryFn: () => getPage<ExecRow>(ENDPOINTS[tab], { limit: 50 }),
  });
  const filtered = (data?.data ?? []).filter((r) =>
    !filter || r.entityName?.includes(filter) || r.entityId?.includes(filter)
  );
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, display: "flex", gap: 8, borderBottom: "1px solid var(--border)" }}>
        {(["function", "handler", "mcp", "skill"] as Tab[]).map((t) => (
          <button key={t} onClick={() => setTab(t)} style={{
            padding: "4px 12px", fontSize: 12,
            background: tab === t ? "var(--accent)" : "var(--bg-elev)",
            color: tab === t ? "var(--accent-fg)" : "var(--fg-body)",
            border: "none", borderRadius: 3, cursor: "pointer",
          }}>{t}</button>
        ))}
        <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="filter by entity name/id…" style={{
          flex: 1, padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12,
        }} />
      </div>
      <div style={{ flex: 1, overflow: "auto" }}>
        {isLoading ? <EmptyView>loading…</EmptyView> : filtered.length === 0 ? (
          <EmptyView>no {tab} executions match</EmptyView>
        ) : (
          <table className="dt">
            <thead>
              <tr><th>id</th><th>entity</th><th>status</th><th>elapsed</th><th>started</th><th>error</th><th></th></tr>
            </thead>
            <tbody>
              {filtered.map((r) => (
                <tr key={r.id}>
                  <td className="mono" style={{ fontSize: 10 }}>{r.id.slice(-12)}</td>
                  <td className="mono" style={{ fontSize: 10 }}>{r.entityName ?? r.entityId ?? "—"}</td>
                  <td><StatusBadge status={r.status} /></td>
                  <td className="muted">{r.elapsedMs ?? "—"}ms</td>
                  <td className="muted"><RelTime ts={r.startedAt} /></td>
                  <td>{r.errorCode && <code style={{ color: "var(--status-error)" }}>{r.errorCode}</code>}</td>
                  <td>
                    <button onClick={() => ui.showRaw(r.id, r)} className="muted" style={{
                      background: "none", border: "1px solid var(--border)",
                      padding: "1px 6px", borderRadius: 3, fontSize: 10, cursor: "pointer",
                    }}>raw</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
