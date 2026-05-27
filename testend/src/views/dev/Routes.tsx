import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { routesAPI } from "@/api/routes";
import { qk } from "@/hooks/queryKeys";

export function Routes() {
  const [filter, setFilter] = useState("");
  const { data: routes = [] } = useQuery({ queryKey: qk.devRoutes(), queryFn: () => routesAPI.list() });
  const filtered = routes.filter((r) =>
    !filter || r.path.includes(filter) || r.method.includes(filter.toUpperCase())
  );
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, borderBottom: "1px solid var(--border)" }}>
        <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="filter… (method or path)" style={{
          width: "100%", padding: "4px 8px", border: "1px solid var(--border)",
          borderRadius: 3, fontSize: 12,
        }} />
        <span className="muted" style={{ marginLeft: 8, fontSize: 11 }}>
          {filtered.length} / {routes.length}
        </span>
      </div>
      <div style={{ flex: 1, overflow: "auto" }}>
        <table className="dt">
          <thead><tr><th style={{ width: 80 }}>method</th><th>path</th></tr></thead>
          <tbody>
            {filtered.map((r, i) => (
              <tr key={i}><td><code>{r.method}</code></td><td className="mono">{r.path}</td></tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
