import { useEffect, useState } from "react";

export function RelTime({ ts }: { ts: string | number | undefined }) {
  const [tick, setTick] = useState(0);
  useEffect(() => {
    const i = setInterval(() => setTick((x) => x + 1), 30_000);
    return () => clearInterval(i);
  }, []);
  void tick;
  if (!ts) return <span className="muted">—</span>;
  const d = typeof ts === "string" ? new Date(ts).getTime() : ts;
  if (!Number.isFinite(d)) return <span className="muted">—</span>;
  const diff = (Date.now() - d) / 1000;
  let s = "刚刚";
  if (diff > 60 && diff < 3600) s = `${Math.floor(diff / 60)} 分钟前`;
  else if (diff < 86400) s = `${Math.floor(diff / 3600)} 小时前`;
  else if (diff < 86400 * 30) s = `${Math.floor(diff / 86400)} 天前`;
  else s = new Date(d).toLocaleDateString();
  return <span title={new Date(d).toLocaleString()}>{s}</span>;
}
