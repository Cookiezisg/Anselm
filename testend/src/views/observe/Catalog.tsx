import { useCatalogStore } from "@/stores/catalog";
import { EmptyView, RelTime } from "@/ui";

export function Catalog() {
  const { current, loading, refresh } = useCatalogStore();
  if (loading) return <EmptyView>loading…</EmptyView>;
  if (!current) return (
    <div style={{ height: "100%", overflow: "auto", padding: 12 }}>
      <button onClick={() => refresh()} style={{ padding: "4px 12px", fontSize: 12 }}>Refresh</button>
      <EmptyView>no catalog yet</EmptyView>
    </div>
  );
  const grouped: Record<string, typeof current.items> = {};
  for (const item of current.items) {
    (grouped[item.source] ??= []).push(item);
  }
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 12 }}>
      <div style={{ display: "flex", gap: 16, alignItems: "baseline", marginBottom: 12 }}>
        <strong>Catalog</strong>
        <span className="muted">generated <RelTime ts={current.generatedAt} /></span>
        <span className="mono muted" style={{ fontSize: 10 }}>fp: {current.fingerprint.slice(0, 12)}</span>
        <span className="muted">{current.items.length} items</span>
        <button onClick={() => refresh()} style={{ padding: "2px 8px", fontSize: 11 }}>refresh</button>
      </div>
      {Object.entries(grouped).map(([source, items]) => (
        <details key={source} open style={{ marginBottom: 8 }}>
          <summary style={{ padding: "4px 8px", background: "var(--bg-elev)", cursor: "pointer", fontSize: 12 }}>
            <strong>{source}</strong> <span className="muted">({items.length})</span>
          </summary>
          <table className="dt">
            <thead><tr><th>name</th><th>description</th><th>granularity</th></tr></thead>
            <tbody>
              {items.map((it) => (
                <tr key={`${it.source}:${it.name}`}>
                  <td className="mono">{it.name}</td>
                  <td className="muted" style={{ maxWidth: 600 }}>{it.description.slice(0, 200)}</td>
                  <td><code style={{ fontSize: 10 }}>{it.granularity}</code></td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      ))}
    </div>
  );
}
