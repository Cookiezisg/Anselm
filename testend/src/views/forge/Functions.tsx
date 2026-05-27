import { useState } from "react";
import { Link } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { getJSON, postJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, StatusBadge, RelTime } from "@/ui";
import type { FunctionEntity } from "@frontend/entities/function/model/types";

export function Functions() {
  const [filter, setFilter] = useState("");
  const qc = useQueryClient();
  const { data = [], isLoading, isError } = useQuery({
    queryKey: qk.functions(),
    queryFn: () => getJSON<FunctionEntity[]>("/api/v1/functions"),
  });
  const create = useMutation({
    mutationFn: () => postJSON<FunctionEntity>("/api/v1/functions", { name: "new_function", description: "" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.functions() }),
  });
  if (isLoading) return <EmptyView>loading…</EmptyView>;
  if (isError) return <EmptyView>error</EmptyView>;
  const filtered = data.filter((f) => !filter || f.name.includes(filter));
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
            <tr><th>name</th><th>description</th><th>activeVersion</th><th>env</th><th>updated</th></tr>
          </thead>
          <tbody>
            {filtered.map((f) => (
              <tr key={f.id}>
                <td>
                  <Link to={`/forge/functions/${f.id}`} style={{ color: "var(--accent)", textDecoration: "none" }}>
                    {f.name}
                  </Link>
                </td>
                <td className="muted">{f.description?.slice(0, 80) ?? "—"}</td>
                <td className="mono" style={{ fontSize: 10 }}>{f.activeVersionId ?? "—"}</td>
                <td>{f.envStatus ? <StatusBadge status={f.envStatus} /> : "—"}</td>
                <td className="muted"><RelTime ts={f.updatedAt} /></td>
              </tr>
            ))}
          </tbody>
        </table>
        {filtered.length === 0 && <EmptyView>no functions match filter</EmptyView>}
      </div>
    </div>
  );
}
