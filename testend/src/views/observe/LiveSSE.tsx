import { useEffect, useState } from "react";
import { subscribe, status as sseStatus, reconnect, type StreamEvent, type StreamID } from "@/api/sse";
import { useUIStore } from "@/stores/ui";
import { Pill } from "@/ui";

function Pane({ stream }: { stream: StreamID }) {
  const ui = useUIStore();
  const [events, setEvents] = useState<StreamEvent[]>([]);
  const [, setTick] = useState(0);
  useEffect(() => {
    return subscribe(stream, (e) => setEvents((cur) => [...cur.slice(-100), e]));
  }, [stream]);
  useEffect(() => {
    const i = setInterval(() => setTick((x) => x + 1), 1000);
    return () => clearInterval(i);
  }, []);
  const s = sseStatus(stream);
  return (
    <div style={{ display: "flex", flexDirection: "column", flex: 1, minWidth: 0, borderRight: "1px solid var(--border)" }}>
      <div style={{ padding: 8, display: "flex", justifyContent: "space-between", alignItems: "center", borderBottom: "1px solid var(--border)" }}>
        <div>
          <strong>{stream}</strong>
          <span style={{ marginLeft: 8 }}><Pill kind={s.connected ? "success" : "error"}>{s.connected ? "connected" : "disconnected"}</Pill></span>
          {s.lastError && <span style={{ marginLeft: 8, color: "var(--status-error)", fontSize: 10 }}>{s.lastError}</span>}
        </div>
        <button onClick={() => { setEvents([]); reconnect(stream); }} style={{
          padding: "2px 8px", fontSize: 10, background: "var(--bg-elev)",
          border: "1px solid var(--border)", borderRadius: 3, cursor: "pointer",
        }}>reset</button>
      </div>
      <div style={{ flex: 1, overflow: "auto", fontFamily: "var(--mono)", fontSize: 10, padding: 4 }}>
        {events.map((e, i) => (
          <div key={i} onClick={() => ui.showRaw(`#${e.id} ${e.event}`, e.data)} style={{
            padding: "1px 4px", cursor: "pointer", borderBottom: "1px solid var(--border-soft)",
            display: "flex", gap: 6,
          }}>
            <span className="muted" style={{ width: 40 }}>{e.id}</span>
            <span style={{ width: 100 }}>{e.event}</span>
            <span style={{ flex: 1, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
              {JSON.stringify(e.data).slice(0, 120)}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

export function LiveSSE() {
  return (
    <div style={{ display: "flex", height: "100%" }}>
      <Pane stream="eventlog" />
      <Pane stream="notifications" />
      <Pane stream="forge" />
    </div>
  );
}
