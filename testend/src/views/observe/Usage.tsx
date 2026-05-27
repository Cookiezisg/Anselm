import { useQuery } from "@tanstack/react-query";
import { getJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { useUsersStore } from "@/stores/users";
import { EmptyView, RelTime } from "@/ui";
import type { Conversation, Message } from "@frontend/entities/conversation/model/types";

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

export function Usage() {
  const { activeId } = useUsersStore();
  const { data: convs = [] } = useQuery({
    queryKey: qk.conversations(),
    queryFn: () => getJSON<Conversation[]>("/api/v1/conversations"),
    enabled: !!activeId,
  });

  // Sample top 10 most recent conversations for token aggregation.
  const sampled = convs.slice(0, 10);
  const messageQueries = sampled.map((c) => ({
    convId: c.id,
    title: c.title,
  }));
  const { data: allMessages = [] } = useQuery({
    queryKey: ["usage-aggregate", sampled.map((c) => c.id).join(",")],
    queryFn: async () => {
      const all: Array<{ convId: string; title: string; msgs: Message[] }> = [];
      for (const c of sampled) {
        try {
          const msgs = await getJSON<Message[]>(`/api/v1/conversations/${c.id}/messages`);
          all.push({ convId: c.id, title: c.title, msgs });
        } catch {
          all.push({ convId: c.id, title: c.title, msgs: [] });
        }
      }
      return all;
    },
    enabled: sampled.length > 0,
  });

  if (!activeId) return <EmptyView>no active user</EmptyView>;
  const totalIn = allMessages.reduce((s, c) => s + c.msgs.reduce((ss, m) => ss + (m.inputTokens ?? 0), 0), 0);
  const totalOut = allMessages.reduce((s, c) => s + c.msgs.reduce((ss, m) => ss + (m.outputTokens ?? 0), 0), 0);

  // Static rates per 1k tokens (rough est, USD).
  const RATE_IN = 0.0003;
  const RATE_OUT = 0.0015;
  const cost = (totalIn / 1000) * RATE_IN + (totalOut / 1000) * RATE_OUT;

  return (
    <div style={{ height: "100%", overflow: "auto", padding: 16 }}>
      <p className="muted" style={{ fontSize: 11 }}>
        Token totals across the {sampled.length} most-recent conversations. Cost estimate uses static $0.0003 in / $0.0015 out per 1k token.
      </p>
      <div style={{ display: "flex", gap: 12, flexWrap: "wrap", marginBottom: 16 }}>
        <Card label="input tokens" value={totalIn.toLocaleString()} />
        <Card label="output tokens" value={totalOut.toLocaleString()} />
        <Card label="est. cost" value={`$${cost.toFixed(3)}`} />
        <Card label="conversations" value={messageQueries.length} />
      </div>
      <h3>Per-conversation breakdown</h3>
      <table className="dt">
        <thead><tr><th>conversation</th><th>messages</th><th>in</th><th>out</th><th>updated</th></tr></thead>
        <tbody>
          {allMessages.map((c) => {
            const conv = convs.find((x) => x.id === c.convId);
            const i = c.msgs.reduce((s, m) => s + (m.inputTokens ?? 0), 0);
            const o = c.msgs.reduce((s, m) => s + (m.outputTokens ?? 0), 0);
            return (
              <tr key={c.convId}>
                <td>{c.title ?? "(untitled)"}</td>
                <td>{c.msgs.length}</td>
                <td>{i.toLocaleString()}</td>
                <td>{o.toLocaleString()}</td>
                <td className="muted"><RelTime ts={conv?.updatedAt} /></td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
}
