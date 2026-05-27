import { useEffect, useRef, useState } from "react";
import { subscribeLogs, type LogEntry } from "@/api/logs";

const LEVEL_COLOR: Record<string, string> = {
  info: "var(--status-success)",
  warn: "var(--status-warn)",
  error: "var(--status-error)",
  debug: "var(--fg-muted)",
};

export function BackendLogs() {
  const [entries, setEntries] = useState<LogEntry[]>([]);
  const [filter, setFilter] = useState("");
  const [auto, setAuto] = useState(true);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    return subscribeLogs((e) => setEntries((cur) => [...cur.slice(-2000), e]));
  }, []);

  useEffect(() => {
    if (auto && ref.current) ref.current.scrollTop = ref.current.scrollHeight;
  }, [entries.length, auto]);

  const filtered = entries.filter((e) =>
    !filter || e.msg.includes(filter) || (e.fields && JSON.stringify(e.fields).includes(filter))
  );

  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, display: "flex", gap: 8, alignItems: "center", borderBottom: "1px solid var(--border)" }}>
        <input value={filter} onChange={(e) => setFilter(e.target.value)} placeholder="filter…" style={{
          flex: 1, padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12,
        }} />
        <label style={{ fontSize: 11 }}>
          <input type="checkbox" checked={auto} onChange={(e) => setAuto(e.target.checked)} /> auto-scroll
        </label>
        <button onClick={() => setEntries([])} style={{ padding: "2px 8px", fontSize: 11 }}>clear</button>
      </div>
      <div ref={ref} style={{ flex: 1, overflow: "auto", fontFamily: "var(--mono)", fontSize: 11, padding: 4 }}>
        {filtered.map((e, i) => (
          <div key={i} style={{ display: "flex", gap: 8, padding: "1px 4px" }}>
            <span className="muted" style={{ width: 80 }}>{new Date(e.time).toLocaleTimeString()}</span>
            <span style={{ color: LEVEL_COLOR[e.level], width: 50 }}>{e.level.toUpperCase()}</span>
            <span style={{ flex: 1 }}>{e.msg}</span>
            {e.fields && <span className="muted">{JSON.stringify(e.fields)}</span>}
          </div>
        ))}
      </div>
    </div>
  );
}
