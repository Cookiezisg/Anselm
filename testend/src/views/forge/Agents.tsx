import { useState } from "react";
import { Link } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { getJSON, postJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, Pill, RelTime } from "@/ui";
import type { Agent } from "./agentTypes";

// No frontend entity exists for agents yet (no src/entities/agent in frontend), so types live in
// ./agentTypes for this dev tool. Mirror Functions.tsx 1:1; agents carry no env, but a pending flag.
export function Agents() {
  const [filter, setFilter] = useState("");
  const qc = useQueryClient();
  const { data = [], isLoading, isError } = useQuery({
    queryKey: qk.agents(),
    queryFn: () => getJSON<Agent[]>("/api/v1/agents"),
  });
  const create = useMutation({
    mutationFn: () =>
      postJSON<Agent>("/api/v1/agents", {
        name: `new_agent_${Date.now().toString(36)}`,
        description: "",
        prompt: "You are a helpful worker.",
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.agents() }),
  });
  if (isLoading) return <EmptyView>loading…</EmptyView>;
  if (isError) return <EmptyView>error</EmptyView>;
  const filtered = data.filter((a) => !filter || a.name.includes(filter));
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, display: "flex", gap: 8, borderBottom: "1px solid var(--border)" }}>
        <input
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          placeholder="filter…"
          style={{ flex: 1, padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12 }}
        />
        <button
          onClick={() => create.mutate()}
          style={{
            padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)",
            border: "none", borderRadius: 4, cursor: "pointer", fontSize: 12,
          }}
        >+ new</button>
      </div>
      <div style={{ flex: 1, overflow: "auto" }}>
        <table className="dt">
          <thead>
            <tr><th>name</th><th>description</th><th>activeVersion</th><th>tags</th><th>attention</th><th>updated</th></tr>
          </thead>
          <tbody>
            {filtered.map((a) => (
              <tr key={a.id}>
                <td>
                  <Link to={`/forge/agents/${a.id}`} style={{ color: "var(--accent)", textDecoration: "none" }}>
                    {a.name}
                  </Link>
                </td>
                <td className="muted">{a.description?.slice(0, 80) || "—"}</td>
                <td className="mono" style={{ fontSize: 10 }}>{a.activeVersionId ?? "—"}</td>
                <td className="muted" style={{ fontSize: 11 }}>{a.tags?.length ? a.tags.join(", ") : "—"}</td>
                <td>{a.needsAttention ? <Pill kind="warn">attention</Pill> : "—"}</td>
                <td className="muted"><RelTime ts={a.updatedAt} /></td>
              </tr>
            ))}
          </tbody>
        </table>
        {filtered.length === 0 && <EmptyView>no agents match filter</EmptyView>}
      </div>
    </div>
  );
}
