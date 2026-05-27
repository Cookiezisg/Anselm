import { useState } from "react";
import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { getJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, RelTime, Pill } from "@/ui";
import type { Workflow } from "@frontend/entities/workflow/model/types";

export function Workflows() {
  const [filter, setFilter] = useState("");
  const { data = [], isLoading } = useQuery({
    queryKey: qk.workflows(),
    queryFn: () => getJSON<Workflow[]>("/api/v1/workflows"),
  });
  if (isLoading) return <EmptyView>loading…</EmptyView>;
  const filtered = data.filter((w) => !filter || w.name.includes(filter));
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, borderBottom: "1px solid var(--border)" }}>
        <input
          value={filter}
          onChange={(e) => setFilter(e.target.value)}
          placeholder="filter…"
          style={{ width: "100%", padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12 }}
        />
      </div>
      <div style={{ flex: 1, overflow: "auto" }}>
        <table className="dt">
          <thead>
            <tr>
              <th>name</th><th>description</th><th>enabled</th>
              <th>concurrency</th><th>needsAttention</th><th>liveRuns</th><th>lastFired</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((w) => (
              <tr key={w.id}>
                <td>
                  <Link to={`/forge/workflows/${w.id}`} style={{ color: "var(--accent)", textDecoration: "none" }}>
                    {w.name}
                  </Link>
                </td>
                <td className="muted">{w.description?.slice(0, 60) ?? "—"}</td>
                <td>{w.enabled ? <Pill kind="success">on</Pill> : <Pill>off</Pill>}</td>
                <td className="muted">{w.concurrency ?? "—"}</td>
                <td>{w.needsAttention ? <Pill kind="warn">attention</Pill> : "—"}</td>
                <td className="muted">{w.liveRuns ?? 0}</td>
                <td className="muted"><RelTime ts={w.lastFiredAt} /></td>
              </tr>
            ))}
          </tbody>
        </table>
        {filtered.length === 0 && <EmptyView>no workflows match filter</EmptyView>}
      </div>
    </div>
  );
}
