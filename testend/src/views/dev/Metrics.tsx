import { useQuery } from "@tanstack/react-query";
import { infoAPI } from "@/api/info";
import { qk } from "@/hooks/queryKeys";
import { EmptyView } from "@/ui";

function fmtBytes(b: number | undefined): string {
  if (b == null) return "—";
  if (b < 1024) return `${b} B`;
  if (b < 1024 ** 2) return `${(b / 1024).toFixed(1)} KB`;
  if (b < 1024 ** 3) return `${(b / 1024 ** 2).toFixed(1)} MB`;
  return `${(b / 1024 ** 3).toFixed(2)} GB`;
}

function fmtUptime(sec: number): string {
  if (sec < 60) return `${sec}s`;
  if (sec < 3600) return `${Math.floor(sec / 60)}m ${sec % 60}s`;
  const h = Math.floor(sec / 3600);
  const m = Math.floor((sec % 3600) / 60);
  return `${h}h ${m}m`;
}

function Card({ label, value }: { label: string; value: string | number }) {
  return (
    <div style={{
      padding: 16, background: "var(--bg-paper)", border: "1px solid var(--border)",
      borderRadius: 6, minWidth: 160,
    }}>
      <div className="muted" style={{ fontSize: 11, textTransform: "uppercase" }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 500, marginTop: 4 }}>{value}</div>
    </div>
  );
}

export function Metrics() {
  const { data } = useQuery({
    queryKey: qk.devRuntime(),
    queryFn: () => infoAPI.runtime(),
    refetchInterval: 2000,
  });
  if (!data) return <EmptyView>loading…</EmptyView>;
  return (
    <div style={{ padding: 16, display: "flex", flexWrap: "wrap", gap: 12 }}>
      <Card label="uptime" value={fmtUptime(data.uptimeSec)} />
      <Card label="goroutines" value={data.numGoroutine} />
      <Card label="mem alloc" value={fmtBytes(data.memAllocBytes)} />
      <Card label="mem sys" value={fmtBytes(data.memSysBytes)} />
      <Card label="GC cycles" value={data.numGC} />
      <Card label="db size" value={fmtBytes(data.dbSizeBytes)} />
    </div>
  );
}
