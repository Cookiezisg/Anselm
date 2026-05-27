import { useState } from "react";
import { Link } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { getJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, StatusBadge, RelTime, Pill } from "@/ui";
import type { Handler } from "@frontend/entities/handler/model/types";

export function Handlers() {
  const [filter, setFilter] = useState("");
  const { data = [], isLoading } = useQuery({
    queryKey: qk.handlers(),
    queryFn: () => getJSON<Handler[]>("/api/v1/handlers"),
  });
  if (isLoading) return <EmptyView>loading…</EmptyView>;
  const filtered = data.filter((h) => !filter || h.name.includes(filter));
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
              <th>name</th><th>description</th><th>configState</th>
              <th>liveInstances</th><th>env</th><th>updated</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((h) => (
              <tr key={h.id}>
                <td>
                  <Link to={`/forge/handlers/${h.id}`} style={{ color: "var(--accent)", textDecoration: "none" }}>
                    {h.name}
                  </Link>
                </td>
                <td className="muted">{h.description?.slice(0, 80) ?? "—"}</td>
                <td>
                  {h.configState
                    ? <Pill kind={h.configState === "ready" ? "success" : "warn"}>{h.configState}</Pill>
                    : "—"}
                </td>
                <td className="muted">{h.liveInstances ?? 0}</td>
                <td>{h.envStatus ? <StatusBadge status={h.envStatus} /> : "—"}</td>
                <td className="muted"><RelTime ts={h.updatedAt} /></td>
              </tr>
            ))}
          </tbody>
        </table>
        {filtered.length === 0 && <EmptyView>no handlers match filter</EmptyView>}
      </div>
    </div>
  );
}
