import { useState } from "react";
import { useNotificationsStore } from "@/stores/notifications";
import { useUIStore } from "@/stores/ui";
import { EmptyView, RelTime } from "@/ui";

export function NotificationHistory() {
  const list = useNotificationsStore((s) => s.list);
  const clear = useNotificationsStore((s) => s.clear);
  const ui = useUIStore();
  const [filter, setFilter] = useState("");
  const filtered = list.filter((n) =>
    !filter || n.type.includes(filter) || (n.action ?? "").includes(filter)
  );
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, display: "flex", gap: 8, borderBottom: "1px solid var(--border)" }}>
        <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="filter type/action…" style={{
          flex: 1, padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12,
        }} />
        <span className="muted" style={{ fontSize: 11, alignSelf: "center" }}>{filtered.length} / {list.length}</span>
        <button onClick={clear} style={{ padding: "2px 8px", fontSize: 11 }}>clear</button>
      </div>
      <div style={{ flex: 1, overflow: "auto" }}>
        {filtered.length === 0 ? <EmptyView>no notifications yet</EmptyView> : (
          <table className="dt">
            <thead>
              <tr><th>time</th><th>type</th><th>action</th><th>convId</th><th>data preview</th></tr>
            </thead>
            <tbody>
              {filtered.map((n, i) => (
                <tr key={i} onClick={() => ui.showRaw(`${n.type}/${n.action ?? ""}`, n)} style={{ cursor: "pointer" }}>
                  <td className="muted"><RelTime ts={n.receivedAt} /></td>
                  <td><code>{n.type}</code></td>
                  <td className="muted">{n.action ?? "—"}</td>
                  <td className="mono" style={{ fontSize: 10 }}>{n.conversationId?.slice(-8) ?? "—"}</td>
                  <td className="mono" style={{ fontSize: 10, maxWidth: 500, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                    {n.data ? JSON.stringify(n.data).slice(0, 200) : "—"}
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
