import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { getJSON, postJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, StatusBadge, RelTime, Pill } from "@/ui";
import { MonacoEditor } from "@/ui/MonacoEditor";
import type { Handler, HandlerVersion, HandlerConfig } from "@frontend/entities/handler/model/types";

type Tab = "init" | "methods" | "config" | "call" | "env";

export function HandlerDetail() {
  const { id } = useParams<{ id: string }>();
  const qc = useQueryClient();
  const [tab, setTab] = useState<Tab>("init");
  const [method, setMethod] = useState("");
  const [args, setArgs] = useState("{}");

  const { data: h } = useQuery({
    queryKey: qk.handler(id ?? ""),
    queryFn: () => getJSON<Handler>(`/api/v1/handlers/${id}`),
    enabled: !!id,
  });
  const { data: versions = [] } = useQuery({
    queryKey: qk.handlerVersions(id ?? ""),
    queryFn: () => getJSON<HandlerVersion[]>(`/api/v1/handlers/${id}/versions`),
    enabled: !!id,
  });
  const { data: cfg } = useQuery({
    queryKey: qk.handlerConfig(id ?? ""),
    queryFn: () => getJSON<HandlerConfig>(`/api/v1/handlers/${id}/config`),
    enabled: !!id,
  });
  const accept = useMutation({
    mutationFn: () => postJSON(`/api/v1/handlers/${id}:accept`, {}),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.handler(id ?? "") }),
  });
  const reject = useMutation({
    mutationFn: () => postJSON(`/api/v1/handlers/${id}:reject`, {}),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.handler(id ?? "") }),
  });
  const call = useMutation<unknown, Error, void>({
    mutationFn: () => postJSON(`/api/v1/handlers/${id}:call`, { method, args: JSON.parse(args) }),
  });

  if (!id || !h) return <EmptyView>loading…</EmptyView>;
  const active = versions.find((v) => v.id === h.activeVersionId);
  const pending = versions.find((v) => v.status === "pending");

  return (
    <div style={{ display: "flex", height: "100%" }}>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>
        <div style={{ padding: 12, borderBottom: "1px solid var(--border)" }}>
          <div style={{ display: "flex", gap: 8, alignItems: "baseline" }}>
            <h2 style={{ margin: 0 }}>{h.name}</h2>
            <span className="mono muted" style={{ fontSize: 11 }}>{h.id}</span>
            {h.configState && (
              <Pill kind={h.configState === "ready" ? "success" : "warn"}>{h.configState}</Pill>
            )}
            {h.envStatus && <StatusBadge status={h.envStatus} />}
          </div>
          <div className="muted" style={{ fontSize: 12, marginTop: 4 }}>{h.description}</div>
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
          {(["init", "methods", "config", "call", "env"] as Tab[]).map((t) => (
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
          {tab === "init" && active && (
            <>
              <h4>Imports</h4>
              <pre className="raw-json">{JSON.stringify(active.imports ?? [], null, 2)}</pre>
              <h4>Init Body</h4>
              <MonacoEditor value={active.initBody ?? ""} language="python" height={200} readOnly />
              <h4>Init Args Schema</h4>
              <pre className="raw-json">{JSON.stringify(active.initArgsSchema ?? {}, null, 2)}</pre>
            </>
          )}
          {tab === "methods" && (
            <pre className="raw-json">{JSON.stringify(active?.methods ?? [], null, 2)}</pre>
          )}
          {tab === "config" && cfg && (
            <>
              <div className="muted" style={{ marginBottom: 8 }}>
                state: <Pill kind="info">{cfg.configState}</Pill>
              </div>
              <pre className="raw-json">{JSON.stringify(cfg.config ?? {}, null, 2)}</pre>
            </>
          )}
          {tab === "call" && (
            <>
              <h4>Call</h4>
              <div style={{ display: "flex", gap: 8, marginBottom: 8 }}>
                <input
                  value={method}
                  onChange={(e) => setMethod(e.target.value)}
                  placeholder="method name"
                  style={{ padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12 }}
                />
              </div>
              <textarea
                value={args}
                onChange={(e) => setArgs(e.target.value)}
                style={{
                  width: "100%", minHeight: 80, padding: 6,
                  border: "1px solid var(--border)", borderRadius: 3,
                  fontFamily: "var(--mono)", fontSize: 12,
                }}
              />
              <button
                onClick={() => call.mutate()}
                disabled={call.isPending || !method}
                style={{
                  marginTop: 8, padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)",
                  border: "none", borderRadius: 4, fontSize: 12, cursor: "pointer",
                }}
              >Call</button>
              {call.data != null && (
                <pre className="raw-json" style={{ marginTop: 8 }}>{JSON.stringify(call.data, null, 2)}</pre>
              )}
              {call.isError && (
                <div style={{ color: "var(--status-error)", marginTop: 8 }}>{call.error.message}</div>
              )}
            </>
          )}
          {tab === "env" && active && (
            <dl className="mono" style={{ fontSize: 12 }}>
              <dt>pythonVersion</dt><dd>{active.pythonVersion ?? "—"}</dd>
              <dt>envId</dt><dd>{active.envId ?? "—"}</dd>
              <dt>envStatus</dt><dd>{active.envStatus ?? "—"}</dd>
              <dt>dependencies</dt>
              <dd><pre className="raw-json">{JSON.stringify(active.dependencies ?? [], null, 2)}</pre></dd>
            </dl>
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
              background: v.id === h.activeVersionId ? "var(--bg-elev)" : "transparent",
              borderLeft: v.id === h.activeVersionId ? "2px solid var(--accent)" : "2px solid transparent",
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
