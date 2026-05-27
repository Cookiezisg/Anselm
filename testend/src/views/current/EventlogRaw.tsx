import { useEffect, useState } from "react";
import { subscribe, type StreamEvent } from "@/api/sse";
import { useConvStore } from "@/stores/conv";
import { useUIStore } from "@/stores/ui";
import { EmptyView } from "@/ui";

export function EventlogRaw() {
  const { activeId } = useConvStore();
  const ui = useUIStore();
  const [events, setEvents] = useState<StreamEvent[]>([]);
  const [filter, setFilter] = useState("");

  useEffect(() => {
    if (!activeId) return;
    setEvents([]);
    return subscribe("eventlog", (e) => {
      if ((e.data as { conversationId?: string }).conversationId !== activeId) return;
      setEvents((cur) => [...cur.slice(-500), e]);
    });
  }, [activeId]);

  if (!activeId) return <EmptyView>pick a conversation</EmptyView>;
  const filtered = events.filter((e) => !filter || e.event.includes(filter));
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, borderBottom: "1px solid var(--border)" }}>
        <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="filter event name…" style={{
          width: "100%", padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12,
        }} />
        <span className="muted" style={{ marginLeft: 8, fontSize: 11 }}>{filtered.length} events</span>
      </div>
      <div style={{ flex: 1, overflow: "auto", fontFamily: "var(--mono)", fontSize: 11 }}>
        {filtered.map((e, i) => (
          <div key={i} onClick={() => ui.showRaw(`#${e.id} ${e.event}`, e.data)} style={{
            padding: "2px 8px", borderBottom: "1px solid var(--border-soft)",
            cursor: "pointer", display: "flex", gap: 8,
          }}>
            <span className="muted" style={{ width: 60 }}>{e.id}</span>
            <span style={{ width: 120 }}>{e.event}</span>
            <span style={{ flex: 1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
              {JSON.stringify(e.data).slice(0, 200)}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}
