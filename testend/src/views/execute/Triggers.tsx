import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { getJSON, postJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, StatusBadge, RelTime } from "@/ui";

interface Trigger {
  id: string;
  workflowId: string;
  workflowName?: string;
  kind: "cron" | "fsnotify" | "webhook" | "manual" | string;
  state: string;
  spec?: unknown;
  lastFiredAt?: string;
  nextFireAt?: string;
}

export function Triggers() {
  const qc = useQueryClient();
  const { data = [], isLoading } = useQuery({
    queryKey: qk.triggers(),
    queryFn: () => getJSON<Trigger[]>("/api/v1/triggers"),
  });
  const fire = useMutation({
    mutationFn: ({ wfId, tId }: { wfId: string; tId: string }) =>
      postJSON(`/api/v1/workflows/${wfId}/triggers/${tId}:fire-manual`, {}),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.triggers() }),
  });
  if (isLoading) return <EmptyView>loading…</EmptyView>;
  if (data.length === 0) return <EmptyView>no triggers</EmptyView>;
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 8 }}>
      <table className="dt">
        <thead>
          <tr><th>workflow</th><th>kind</th><th>state</th><th>lastFired</th><th>nextFire</th><th></th></tr>
        </thead>
        <tbody>
          {data.map((t) => (
            <tr key={t.id}>
              <td className="mono" style={{ fontSize: 10 }}>{t.workflowName ?? t.workflowId}</td>
              <td><code>{t.kind}</code></td>
              <td><StatusBadge status={t.state} /></td>
              <td className="muted"><RelTime ts={t.lastFiredAt} /></td>
              <td className="muted"><RelTime ts={t.nextFireAt} /></td>
              <td>
                <button onClick={() => fire.mutate({ wfId: t.workflowId, tId: t.id })} style={{
                  padding: "2px 8px", fontSize: 10, background: "var(--accent)",
                  color: "var(--accent-fg)", border: "none", borderRadius: 3, cursor: "pointer",
                }}>fire</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
