import { useConvStore } from "@/stores/conv";
import { useChatStore } from "@/stores/chat";
import { useUIStore } from "@/stores/ui";
import { EmptyView, StatusBadge } from "@/ui";

export function SubAgents() {
  const { activeId } = useConvStore();
  const chat = useChatStore();
  const ui = useUIStore();
  if (!activeId) return <EmptyView>pick a conversation</EmptyView>;
  const messages = chat.byConv[activeId]?.messages ?? [];
  const subagentRuns = messages.filter((m) => {
    const attrs = m.attrs as Record<string, unknown> | undefined;
    return attrs?.kind === "subagent_run";
  });
  if (subagentRuns.length === 0) return <EmptyView>no subagent runs in this conv</EmptyView>;
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 8 }}>
      <table className="dt">
        <thead>
          <tr>
            <th>id</th><th>type</th><th>status</th><th>maxTurns</th><th>tokens (in/out)</th><th></th>
          </tr>
        </thead>
        <tbody>
          {subagentRuns.map((m) => {
            const a = (m.attrs ?? {}) as Record<string, unknown>;
            return (
              <tr key={m.id}>
                <td className="mono" style={{ fontSize: 10 }}>{m.id}</td>
                <td>{String(a.type ?? "—")}</td>
                <td><StatusBadge status={m.status} /></td>
                <td>{String(a.maxTurns ?? "—")}</td>
                <td className="muted">{m.inputTokens ?? "—"} / {m.outputTokens ?? "—"}</td>
                <td>
                  <button onClick={() => ui.showRaw(`subagent ${m.id}`, m)} className="muted" style={{
                    background: "none", border: "1px solid var(--border)",
                    padding: "1px 6px", borderRadius: 3, fontSize: 10, cursor: "pointer",
                  }}>raw</button>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
