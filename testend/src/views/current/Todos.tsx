import { useQuery } from "@tanstack/react-query";
import { useConvStore } from "@/stores/conv";
import { getJSON } from "@/api/devClient";
import { EmptyView, StatusBadge, RelTime } from "@/ui";

interface Todo {
  id: string;
  subject: string;
  status: string;
  activeForm?: string;
  owner?: string;
  createdAt: string;
  updatedAt: string;
}

export function Todos() {
  const { activeId } = useConvStore();
  const { data, isLoading, isError } = useQuery({
    queryKey: ["todos", activeId],
    queryFn: () => getJSON<Todo[]>(`/api/v1/conversations/${activeId}/todos`),
    enabled: !!activeId,
  });
  if (!activeId) return <EmptyView>pick a conversation</EmptyView>;
  if (isLoading) return <EmptyView>loading…</EmptyView>;
  if (isError) return <EmptyView>load error</EmptyView>;
  if (!data || data.length === 0) return <EmptyView>no todos in this conv</EmptyView>;
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 8 }}>
      <table className="dt">
        <thead>
          <tr><th>id</th><th>subject</th><th>status</th><th>activeForm</th><th>owner</th><th>updated</th></tr>
        </thead>
        <tbody>
          {data.map((t) => (
            <tr key={t.id}>
              <td className="mono" style={{ fontSize: 10 }}>{t.id}</td>
              <td>{t.subject}</td>
              <td><StatusBadge status={t.status} /></td>
              <td className="muted">{t.activeForm ?? "—"}</td>
              <td className="muted">{t.owner ?? "—"}</td>
              <td className="muted"><RelTime ts={t.updatedAt} /></td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
