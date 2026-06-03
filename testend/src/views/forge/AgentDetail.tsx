import { useState } from "react";
import { useParams } from "react-router-dom";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { getJSON, postJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, Pill, StatusBadge, RelTime } from "@/ui";
import type { Agent, AgentVersion, SearchExecutionsResult, InvokeResult } from "./agentTypes";

type Tab = "prompt" | "tools" | "knowledge" | "output" | "model" | "executions";

export function AgentDetail() {
  const { id } = useParams<{ id: string }>();
  const qc = useQueryClient();
  const [tab, setTab] = useState<Tab>("prompt");
  const [input, setInput] = useState("{}");
  const [iterPrompt, setIterPrompt] = useState("");

  const { data: ag } = useQuery({
    queryKey: qk.agent(id ?? ""),
    queryFn: () => getJSON<Agent>(`/api/v1/agents/${id}`),
    enabled: !!id,
  });
  const { data: versions = [] } = useQuery({
    queryKey: qk.agentVersions(id ?? ""),
    queryFn: () => getJSON<AgentVersion[]>(`/api/v1/agents/${id}/versions`),
    enabled: !!id,
  });
  const { data: execs } = useQuery({
    queryKey: qk.agentExecutions(id ?? ""),
    queryFn: () => getJSON<SearchExecutionsResult>(`/api/v1/agents/${id}/executions`),
    enabled: !!id && tab === "executions",
  });

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: qk.agent(id ?? "") });
    qc.invalidateQueries({ queryKey: qk.agentVersions(id ?? "") });
  };
  const accept = useMutation({
    mutationFn: () => postJSON(`/api/v1/agents/${id}/pending:accept`, {}),
    onSuccess: invalidate,
  });
  const reject = useMutation({
    mutationFn: () => postJSON(`/api/v1/agents/${id}/pending:reject`, {}),
    onSuccess: invalidate,
  });
  const invoke = useMutation<InvokeResult, Error, void>({
    mutationFn: () => postJSON(`/api/v1/agents/${id}:invoke`, { input: JSON.parse(input) }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.agentExecutions(id ?? "") }),
  });
  const revert = useMutation<unknown, Error, number>({
    mutationFn: (targetVersion) => postJSON(`/api/v1/agents/${id}:revert`, { targetVersion }),
    onSuccess: invalidate,
  });
  const iterate = useMutation<{ conversationId: string }, Error, void>({
    mutationFn: () => postJSON(`/api/v1/agents/${id}:iterate`, { prompt: iterPrompt }),
  });

  if (!id || !ag) return <EmptyView>loading…</EmptyView>;
  const active = ag.activeVersion ?? versions.find((v) => v.id === ag.activeVersionId);
  const pending = ag.pending ?? versions.find((v) => v.status === "pending");

  return (
    <div style={{ display: "flex", height: "100%" }}>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>
        <div style={{ padding: 12, borderBottom: "1px solid var(--border)" }}>
          <div style={{ display: "flex", gap: 8, alignItems: "baseline" }}>
            <h2 style={{ margin: 0 }}>{ag.name}</h2>
            <span className="mono muted" style={{ fontSize: 11 }}>{ag.id}</span>
            {active?.version != null && <Pill kind="info">v{active.version}</Pill>}
            {ag.needsAttention && <Pill kind="warn">attention</Pill>}
          </div>
          <div className="muted" style={{ fontSize: 12, marginTop: 4 }}>{ag.description}</div>
          {ag.tags?.length > 0 && (
            <div style={{ marginTop: 4 }}>
              {ag.tags.map((t) => <span key={t} className="mono" style={{ fontSize: 10, marginRight: 6 }}>#{t}</span>)}
            </div>
          )}
          {pending && (
            <div style={{
              marginTop: 8, padding: "6px 12px", background: "var(--accent-soft)",
              borderRadius: 4, display: "flex", justifyContent: "space-between", alignItems: "center",
            }}>
              <span>pending version <code>{pending.id}</code></span>
              <span>
                <button onClick={() => accept.mutate()} disabled={accept.isPending} style={{ marginRight: 6, padding: "2px 10px", fontSize: 11 }}>Accept</button>
                <button onClick={() => reject.mutate()} disabled={reject.isPending} style={{ padding: "2px 10px", fontSize: 11 }}>Reject</button>
              </span>
            </div>
          )}
        </div>
        <div style={{ display: "flex", gap: 4, padding: "6px 12px", borderBottom: "1px solid var(--border)" }}>
          {(["prompt", "tools", "knowledge", "output", "model", "executions"] as Tab[]).map((t) => (
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
          {tab === "prompt" && (
            <>
              {active?.skill && (
                <div style={{ marginBottom: 8 }}>
                  skill: <Pill kind="info">{active.skill}</Pill>
                </div>
              )}
              <pre className="raw-json" style={{ whiteSpace: "pre-wrap" }}>{active?.prompt ?? "—"}</pre>
            </>
          )}
          {tab === "tools" && (
            <pre className="raw-json">{JSON.stringify(active?.tools ?? [], null, 2)}</pre>
          )}
          {tab === "knowledge" && (
            <pre className="raw-json">{JSON.stringify(active?.knowledge ?? [], null, 2)}</pre>
          )}
          {tab === "output" && (
            <pre className="raw-json">{JSON.stringify(active?.outputSchema ?? { kind: "free_text" }, null, 2)}</pre>
          )}
          {tab === "model" && (
            <pre className="raw-json">{JSON.stringify(active?.modelOverride ?? "default agent scenario model", null, 2)}</pre>
          )}
          {tab === "executions" && (
            <>
              {execs?.aggregates && (
                <div className="muted" style={{ fontSize: 11, marginBottom: 8 }}>
                  ok {execs.aggregates.okCount} · failed {execs.aggregates.failedCount} ·
                  cancelled {execs.aggregates.cancelledCount} · timeout {execs.aggregates.timeoutCount} ·
                  avg {execs.aggregates.avgElapsedMs}ms · p95 {execs.aggregates.p95ElapsedMs}ms
                </div>
              )}
              <table className="dt">
                <thead>
                  <tr><th>id</th><th>status</th><th>by</th><th>elapsed</th><th>model</th><th>started</th></tr>
                </thead>
                <tbody>
                  {(execs?.executions ?? []).map((e) => (
                    <tr key={e.id}>
                      <td className="mono" style={{ fontSize: 10 }}>{e.id}</td>
                      <td><StatusBadge status={e.status} /></td>
                      <td className="muted" style={{ fontSize: 11 }}>{e.triggeredBy}</td>
                      <td className="muted">{e.elapsedMs}ms</td>
                      <td className="mono" style={{ fontSize: 10 }}>{e.modelId || "—"}</td>
                      <td className="muted"><RelTime ts={e.startedAt} /></td>
                    </tr>
                  ))}
                </tbody>
              </table>
              {(execs?.executions?.length ?? 0) === 0 && <EmptyView>no executions yet</EmptyView>}
            </>
          )}
        </div>
        <div style={{ borderTop: "1px solid var(--border)", padding: 12 }}>
          <strong style={{ fontSize: 12 }}>Invoke</strong>
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            placeholder='input JSON, e.g. {"text":"hi"}'
            style={{
              width: "100%", minHeight: 60, marginTop: 4, padding: 6,
              border: "1px solid var(--border)", borderRadius: 3,
              fontFamily: "var(--mono)", fontSize: 12,
            }}
          />
          <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4 }}>
            <span className="muted" style={{ fontSize: 11 }}>{invoke.isPending ? "running…" : ""}</span>
            <button
              onClick={() => invoke.mutate()}
              disabled={invoke.isPending}
              style={{
                padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)",
                border: "none", borderRadius: 4, fontSize: 12, cursor: "pointer",
              }}
            >Invoke</button>
          </div>
          {invoke.data && (
            <pre className="raw-json" style={{ marginTop: 6 }}>{JSON.stringify(invoke.data, null, 2)}</pre>
          )}
          {invoke.isError && (
            <div style={{ color: "var(--status-error)", marginTop: 6, fontSize: 11 }}>{invoke.error.message}</div>
          )}

          <strong style={{ fontSize: 12, display: "block", marginTop: 12 }}>Iterate (AI edit)</strong>
          <div style={{ display: "flex", gap: 8, marginTop: 4 }}>
            <input
              value={iterPrompt}
              onChange={(e) => setIterPrompt(e.target.value)}
              placeholder="describe the change…"
              style={{ flex: 1, padding: "4px 8px", border: "1px solid var(--border)", borderRadius: 3, fontSize: 12 }}
            />
            <button
              onClick={() => iterate.mutate()}
              disabled={iterate.isPending || !iterPrompt}
              style={{
                padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)",
                border: "none", borderRadius: 4, fontSize: 12, cursor: "pointer",
              }}
            >Iterate</button>
          </div>
          {iterate.data && (
            <div className="muted" style={{ fontSize: 11, marginTop: 6 }}>
              conversation: <code>{iterate.data.conversationId}</code>{" "}
              (open <a href={`#/current/eventlog`} style={{ color: "var(--accent)" }}>eventlog</a> to watch)
            </div>
          )}
          {iterate.isError && (
            <div style={{ color: "var(--status-error)", marginTop: 6, fontSize: 11 }}>{iterate.error.message}</div>
          )}
        </div>
      </div>
      <aside style={{ width: 220, borderLeft: "1px solid var(--border)", overflowY: "auto" }}>
        <div style={{ padding: "8px 12px", fontSize: 11, color: "var(--fg-muted)", textTransform: "uppercase" }}>
          Versions
        </div>
        {versions.map((v) => {
          const isActive = v.id === ag.activeVersionId;
          return (
            <div
              key={v.id}
              style={{
                padding: "4px 12px", fontSize: 11,
                background: isActive ? "var(--bg-elev)" : "transparent",
                borderLeft: isActive ? "2px solid var(--accent)" : "2px solid transparent",
              }}
            >
              <code style={{ fontSize: 10 }}>{v.version != null ? `v${v.version}` : v.id.slice(-8)}</code>{" "}
              <StatusBadge status={v.status} />
              <div className="muted" style={{ fontSize: 10 }}><RelTime ts={v.createdAt} /></div>
              {v.status === "accepted" && !isActive && v.version != null && (
                <button
                  onClick={() => revert.mutate(v.version!)}
                  disabled={revert.isPending}
                  style={{ marginTop: 2, padding: "1px 8px", fontSize: 10, cursor: "pointer" }}
                >Revert here</button>
              )}
            </div>
          );
        })}
      </aside>
    </div>
  );
}
