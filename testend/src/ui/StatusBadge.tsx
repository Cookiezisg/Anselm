const KIND: Record<string, "success" | "error" | "warn" | "info" | "streaming"> = {
  ready: "success", ok: "success", completed: "success", accepted: "success",
  pending: "info", streaming: "streaming", running: "streaming", connecting: "warn",
  degraded: "warn", paused: "warn",
  failed: "error", error: "error", cancelled: "error", rejected: "error",
  disconnected: "error", evicted: "error",
};

export function StatusBadge({ status }: { status: string }) {
  return <span className={`pill ${KIND[status] ?? ""}`}>{status}</span>;
}
