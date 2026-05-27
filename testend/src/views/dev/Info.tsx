import { useQuery } from "@tanstack/react-query";
import { infoAPI } from "@/api/info";
import { qk } from "@/hooks/queryKeys";
import { useUIStore } from "@/stores/ui";
import { EmptyView } from "@/ui";

export function Info() {
  const ui = useUIStore();
  const { data: info } = useQuery({ queryKey: qk.devInfo(), queryFn: () => infoAPI.info() });
  const { data: home } = useQuery({ queryKey: qk.devForgifyHome(), queryFn: () => infoAPI.forgifyHome() });
  if (!info) return <EmptyView>loading…</EmptyView>;
  return (
    <div style={{ padding: 12, overflow: "auto", height: "100%" }}>
      <h3>Server</h3>
      <dl className="mono" style={{ fontSize: 12 }}>
        <dt>port</dt><dd>{info.port}</dd>
        <dt>home</dt><dd>{info.home}</dd>
        <dt>forgifyHome</dt><dd>{info.forgifyHome}</dd>
        <dt>testendDir</dt><dd>{info.testendDir}</dd>
        <dt>mcpConfigPath</dt><dd>{info.mcpConfigPath}</dd>
        <dt>skillsDir</dt><dd>{info.skillsDir}</dd>
        <dt>catalogCachePath</dt><dd>{info.catalogCachePath}</dd>
        <dt>build</dt><dd>{info.buildID} / {info.goVersion}</dd>
        <dt>startedAt</dt><dd>{info.startedAt}</dd>
      </dl>
      {info.tableCounts && (
        <>
          <h3>Table Counts</h3>
          <table className="dt">
            <thead><tr><th>table</th><th>rows</th></tr></thead>
            <tbody>
              {Object.entries(info.tableCounts).sort().map(([t, n]) => (
                <tr key={t}><td>{t}</td><td>{n}</td></tr>
              ))}
            </tbody>
          </table>
        </>
      )}
      {home?.tree && (
        <>
          <h3>~/.forgify tree (at startup)</h3>
          <button onClick={() => ui.showRaw("~/.forgify tree", home.tree)} className="muted" style={{ fontSize: 11 }}>
            show raw
          </button>
        </>
      )}
    </div>
  );
}
