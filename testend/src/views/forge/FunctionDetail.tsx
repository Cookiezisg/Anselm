import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { getJSON, postJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, StatusBadge, RelTime } from "@/ui";
import { MonacoEditor } from "@/ui/MonacoEditor";
import type { FunctionEntity, FunctionVersion } from "@frontend/entities/function/model/types";

type Tab = "code" | "params" | "return" | "deps" | "env";

export function FunctionDetail() {
  const { id } = useParams<{ id: string }>();
  const qc = useQueryClient();
  const [tab, setTab] = useState<Tab>("code");
  const [inputs, setInputs] = useState("{}");
  const { data: fn } = useQuery({
    queryKey: qk.function(id ?? ""),
    queryFn: () => getJSON<FunctionEntity>(`/api/v1/functions/${id}`),
    enabled: !!id,
  });
  const { data: versions = [] } = useQuery({
    queryKey: qk.functionVersions(id ?? ""),
    queryFn: () => getJSON<FunctionVersion[]>(`/api/v1/functions/${id}/versions`),
    enabled: !!id,
  });
  const accept = useMutation({
    mutationFn: () => postJSON(`/api/v1/functions/${id}:accept`, {}),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.function(id ?? "") }),
  });
  const reject = useMutation({
    mutationFn: () => postJSON(`/api/v1/functions/${id}:reject`, {}),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.function(id ?? "") }),
  });
  const run = useMutation<{ output: unknown; elapsedMs?: number }, Error, void>({
    mutationFn: () => postJSON(`/api/v1/functions/${id}:run`, { inputs: JSON.parse(inputs) }),
  });

  if (!id || !fn) return <EmptyView>loading…</EmptyView>;
  const active = versions.find((v) => v.id === fn.activeVersionId);
  const pending = versions.find((v) => v.status === "pending");

  return (
    <div style={{ display: "flex", height: "100%" }}>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>
        <div style={{ padding: 12, borderBottom: "1px solid var(--border)" }}>
          <div style={{ display: "flex", gap: 8, alignItems: "baseline" }}>
            <h2 style={{ margin: 0 }}>{fn.name}</h2>
            <span className="mono muted" style={{ fontSize: 11 }}>{fn.id}</span>
            {fn.envStatus && <StatusBadge status={fn.envStatus} />}
          </div>
          <div className="muted" style={{ fontSize: 12, marginTop: 4 }}>{fn.description}</div>
          {pending && (
            <div style={{
              marginTop: 8, padding: "6px 12px", background: "var(--accent-soft)",
              borderRadius: 4, display: "flex", justifyContent: "space-between", alignItems: "center",
            }}>
              <span>pending version <code>{pending.id}</code></span>
              <span>
                <button onClick={() => accept.mutate()} style={{ marginRight: 6, padding: "2px 10px", fontSize: 11 }}>Accept</button>
                <button onClick={() => reject.mutate()} style={{ padding: "2px 10px", fontSize: 11 }}>Reject</button>
              </span>
            </div>
          )}
        </div>
        <div style={{ display: "flex", gap: 4, padding: "6px 12px", borderBottom: "1px solid var(--border)" }}>
          {(["code", "params", "return", "deps", "env"] as Tab[]).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              style={{
                padding: "4px 12px", fontSize: 12,
                background: tab === t ? "var(--accent)" : "var(--bg-elev)",
                color: tab === t ? "var(--accent-fg)" : "var(--fg-body)",
                border: "none", borderRadius: 3, cursor: "pointer",
              }}
            >{t}</button>
          ))}
        </div>
        <div style={{ flex: 1, overflow: "auto", padding: 12 }}>
          {tab === "code" && active && (
            <MonacoEditor value={active.code ?? ""} language="python" height={400} readOnly />
          )}
          {tab === "params" && (
            <pre className="raw-json">{JSON.stringify(active?.parameters ?? {}, null, 2)}</pre>
          )}
          {tab === "return" && (
            <pre className="raw-json">{JSON.stringify(active?.returnSchema ?? {}, null, 2)}</pre>
          )}
          {tab === "deps" && (
            <pre className="raw-json">{JSON.stringify(active?.dependencies ?? [], null, 2)}</pre>
          )}
          {tab === "env" && active && (
            <dl className="mono" style={{ fontSize: 12 }}>
              <dt>pythonVersion</dt><dd>{active.pythonVersion ?? "—"}</dd>
              <dt>envId</dt><dd>{active.envId ?? "—"}</dd>
              <dt>envStatus</dt><dd>{active.envStatus ?? "—"}</dd>
              <dt>envSyncStage</dt><dd>{active.envSyncStage ?? "—"}</dd>
            </dl>
          )}
        </div>
        <div style={{ borderTop: "1px solid var(--border)", padding: 12 }}>
          <strong style={{ fontSize: 12 }}>Run</strong>
          <textarea
            value={inputs}
            onChange={(e) => setInputs(e.target.value)}
            style={{
              width: "100%", minHeight: 60, marginTop: 4, padding: 6,
              border: "1px solid var(--border)", borderRadius: 3,
              fontFamily: "var(--mono)", fontSize: 12,
            }}
          />
          <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4 }}>
            <span className="muted" style={{ fontSize: 11 }}>{run.isPending ? "running…" : ""}</span>
            <button
              onClick={() => run.mutate()}
              disabled={run.isPending}
              style={{
                padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)",
                border: "none", borderRadius: 4, fontSize: 12, cursor: "pointer",
              }}
            >Run</button>
          </div>
          {run.data && (
            <pre className="raw-json" style={{ marginTop: 6 }}>{JSON.stringify(run.data, null, 2)}</pre>
          )}
          {run.isError && (
            <div style={{ color: "var(--status-error)", marginTop: 6, fontSize: 11 }}>{run.error.message}</div>
          )}
        </div>
      </div>
      <aside style={{ width: 220, borderLeft: "1px solid var(--border)", overflowY: "auto" }}>
        <div style={{ padding: "8px 12px", fontSize: 11, color: "var(--fg-muted)", textTransform: "uppercase" }}>
          Versions
        </div>
        {versions.map((v) => (
          <div
            key={v.id}
            style={{
              padding: "4px 12px", fontSize: 11,
              background: v.id === fn.activeVersionId ? "var(--bg-elev)" : "transparent",
              borderLeft: v.id === fn.activeVersionId ? "2px solid var(--accent)" : "2px solid transparent",
            }}
          >
            <code style={{ fontSize: 10 }}>{v.id.slice(-8)}</code> <StatusBadge status={v.status} />
            <div className="muted" style={{ fontSize: 10 }}><RelTime ts={v.createdAt} /></div>
          </div>
        ))}
      </aside>
    </div>
  );
}
