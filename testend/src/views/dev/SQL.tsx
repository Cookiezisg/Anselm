import { useState } from "react";
import { useMutation } from "@tanstack/react-query";
import { sqlAPI, type SqlResult } from "@/api/sql";
import { MonacoEditor } from "@/ui/MonacoEditor";

const QUICK = [
  "conversations", "messages", "message_blocks", "api_keys", "model_configs",
  "functions", "function_versions", "handlers", "handler_versions",
  "workflows", "workflow_versions", "flowruns", "flowrun_nodes",
  "documents", "memories", "mcp_health_history", "sandbox_runtimes", "sandbox_envs",
];

export function SQL() {
  const [sql, setSql] = useState("SELECT id, title FROM conversations ORDER BY created_at DESC LIMIT 50;");
  const run = useMutation<SqlResult, Error, string>({ mutationFn: (q) => sqlAPI.run(q) });
  return (
    <div style={{ display: "flex", flexDirection: "column", height: "100%" }}>
      <div style={{ padding: 8, display: "flex", gap: 4, flexWrap: "wrap", borderBottom: "1px solid var(--border)" }}>
        {QUICK.map((t) => (
          <button key={t} onClick={() => setSql(`SELECT * FROM ${t} ORDER BY rowid DESC LIMIT 50;`)} style={{
            padding: "2px 8px", fontSize: 11, background: "var(--bg-elev)",
            border: "1px solid var(--border)", borderRadius: 3, cursor: "pointer",
          }}>{t}</button>
        ))}
      </div>
      <div style={{ height: 240, borderBottom: "1px solid var(--border)" }}>
        <MonacoEditor value={sql} onChange={setSql} language="sql" height={240} />
      </div>
      <div style={{ padding: 8 }}>
        <button onClick={() => run.mutate(sql)} disabled={run.isPending} style={{
          padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)",
          border: "none", borderRadius: 4, cursor: "pointer", fontSize: 12,
        }}>{run.isPending ? "running…" : "Run"}</button>
        {run.isError && (
          <span style={{ marginLeft: 12, color: "var(--status-error)" }}>
            {(run.error as Error).message}
          </span>
        )}
      </div>
      <div style={{ flex: 1, overflow: "auto", padding: 8 }}>
        {run.data && (
          <table className="dt">
            <thead>
              <tr>{run.data.columns.map((c) => <th key={c}>{c}</th>)}</tr>
            </thead>
            <tbody>
              {run.data.rows.map((row, i) => (
                <tr key={i}>
                  {row.map((v, j) => <td key={j}><code style={{ fontSize: 11 }}>{String(v)}</code></td>)}
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
