import { useQuery } from "@tanstack/react-query";
import { useConvStore } from "@/stores/conv";
import { useChatStore, type BlockNode } from "@/stores/chat";
import { getJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import type { Conversation } from "@frontend/entities/conversation/model/types";
import { EmptyView } from "@/ui";

const ROLE_COLORS: Record<string, string> = {
  hot: "#4a7cc4",
  warm: "#d4a017",
  cold: "#6b6862",
  archived: "#c43d3d",
};

function flattenAll(blocks: BlockNode[] | undefined, acc: BlockNode[] = []): BlockNode[] {
  if (!blocks) return acc;
  for (const b of blocks) {
    acc.push(b);
    flattenAll(b.children, acc);
  }
  return acc;
}

export function Compaction() {
  const { activeId } = useConvStore();
  const chat = useChatStore();
  const { data: conv } = useQuery({
    queryKey: qk.conversation(activeId ?? ""),
    queryFn: () => getJSON<Conversation>(`/api/v1/conversations/${activeId}`),
    enabled: !!activeId,
  });

  if (!activeId) return <EmptyView>pick a conversation</EmptyView>;

  const messages = chat.byConv[activeId]?.messages ?? [];
  const allBlocks = messages.flatMap((m) => flattenAll(m.blocks));
  const compactionBlocks = allBlocks.filter((b) => b.type === "compaction");

  const roleCounts: Record<string, number> = { hot: 0, warm: 0, cold: 0, archived: 0 };
  for (const b of allBlocks) {
    const role = (b as BlockNode & { contextRole?: string }).contextRole ?? "hot";
    if (role in roleCounts) roleCounts[role]! += 1;
  }
  const total = Object.values(roleCounts).reduce((a, b) => a + b, 0) || 1;

  return (
    <div style={{ height: "100%", overflow: "auto", padding: 12 }}>
      <h3 style={{ marginTop: 0 }}>Summary</h3>
      {conv?.summary ? (
        <div style={{ padding: 12, background: "var(--bg-elev)", borderRadius: 4 }}>
          <div className="muted" style={{ fontSize: 11, marginBottom: 6 }}>
            covers up to seq {conv.summaryCoversUpToSeq ?? "?"}
          </div>
          <pre style={{ whiteSpace: "pre-wrap", margin: 0, fontFamily: "var(--mono)", fontSize: 12 }}>
            {conv.summary}
          </pre>
        </div>
      ) : (
        <div className="muted">no compaction summary yet</div>
      )}

      <h3>Block Distribution by contextRole</h3>
      <div style={{ display: "flex", height: 32, borderRadius: 4, overflow: "hidden" }}>
        {Object.entries(roleCounts).map(([role, n]) => {
          const pct = (n / total) * 100;
          if (pct === 0) return null;
          return (
            <div key={role} style={{ width: `${pct}%`, background: ROLE_COLORS[role] }} title={`${role}: ${n} (${pct.toFixed(1)}%)`} />
          );
        })}
      </div>
      <div style={{ display: "flex", gap: 12, marginTop: 6, fontSize: 11 }}>
        {Object.entries(roleCounts).map(([role, n]) => (
          <span key={role} style={{ display: "flex", alignItems: "center", gap: 4 }}>
            <span style={{ width: 12, height: 12, background: ROLE_COLORS[role], display: "inline-block", borderRadius: 2 }} />
            {role}: {n}
          </span>
        ))}
      </div>

      <h3>Compaction Blocks ({compactionBlocks.length})</h3>
      {compactionBlocks.length === 0 ? (
        <div className="muted">no compaction blocks emitted yet</div>
      ) : (
        <table className="dt">
          <thead>
            <tr>
              <th>id</th><th>coversFromSeq</th><th>coversToSeq</th><th>blocksArchived</th><th>generatedBy</th>
            </tr>
          </thead>
          <tbody>
            {compactionBlocks.map((b) => {
              const a = (b.attrs ?? {}) as Record<string, unknown>;
              return (
                <tr key={b.id}>
                  <td className="mono" style={{ fontSize: 10 }}>{b.id}</td>
                  <td>{String(a.coversFromSeq ?? "—")}</td>
                  <td>{String(a.coversToSeq ?? "—")}</td>
                  <td>{String(a.blocksArchived ?? "—")}</td>
                  <td className="muted">{String(a.generatedBy ?? "—")}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </div>
  );
}
