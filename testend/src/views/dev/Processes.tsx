import { useQuery } from "@tanstack/react-query";
import { infoAPI } from "@/api/info";
import { qk } from "@/hooks/queryKeys";
import { RelTime, StatusBadge, EmptyView } from "@/ui";

export function Processes() {
  const { data } = useQuery({
    queryKey: qk.devBashProcesses(),
    queryFn: () => infoAPI.bashProcesses(),
    refetchInterval: 5000,
  });
  if (!data) return <EmptyView>loading…</EmptyView>;
  if (data.processes.length === 0) return <EmptyView>no bash subprocesses</EmptyView>;
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 8 }}>
      <table className="dt">
        <thead>
          <tr>
            <th>id</th>
            <th>command</th>
            <th>cwd</th>
            <th>started</th>
            <th>status</th>
            <th>exit</th>
          </tr>
        </thead>
        <tbody>
          {data.processes.map((p) => (
            <tr key={p.id}>
              <td className="mono">{p.id}</td>
              <td><code>{p.command}</code></td>
              <td className="muted">{p.cwd}</td>
              <td><RelTime ts={p.startedAt} /></td>
              <td><StatusBadge status={p.status} /></td>
              <td>{p.exitCode ?? "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
