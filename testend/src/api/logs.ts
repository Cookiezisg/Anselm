export interface LogEntry {
  time: string;
  level: "debug" | "info" | "warn" | "error";
  msg: string;
  fields?: Record<string, unknown>;
}

export function subscribeLogs(onEntry: (e: LogEntry) => void): () => void {
  const es = new EventSource("/dev/logs");
  es.onmessage = (ev) => {
    try { onEntry(JSON.parse(ev.data)); } catch { /* skip */ }
  };
  return () => es.close();
}
