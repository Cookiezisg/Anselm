import { useConvStore } from "@/stores/conv";
import { useNotificationsStore } from "@/stores/notifications";
import { useUIStore } from "@/stores/ui";
import { EmptyView, RelTime } from "@/ui";

export function Notifications() {
  const { activeId } = useConvStore();
  const ui = useUIStore();
  const all = useNotificationsStore((s) => s.list);
  if (!activeId) return <EmptyView>pick a conversation</EmptyView>;
  const scoped = all.filter((n) => n.conversationId === activeId);
  if (scoped.length === 0) return <EmptyView>no notifications for this conv</EmptyView>;
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 8 }}>
      <table className="dt">
        <thead><tr><th>time</th><th>type</th><th>action</th><th>data preview</th></tr></thead>
        <tbody>
          {scoped.map((n, i) => (
            <tr key={i} onClick={() => ui.showRaw(`${n.type}/${n.action ?? ""}`, n)} style={{ cursor: "pointer" }}>
              <td className="muted"><RelTime ts={n.receivedAt} /></td>
              <td><code>{n.type}</code></td>
              <td className="muted">{n.action ?? "—"}</td>
              <td className="mono" style={{ fontSize: 10, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", maxWidth: 600 }}>
                {n.data ? JSON.stringify(n.data).slice(0, 200) : "—"}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
