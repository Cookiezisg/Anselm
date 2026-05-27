import { useConvStore } from "@/stores/conv";
import { useChatStore, type BlockNode } from "@/stores/chat";
import { BlockView, EmptyView, StatusBadge } from "@/ui";

interface FlatRow { depth: number; node: BlockNode }

function flatten(blocks: BlockNode[] | undefined, depth = 0, acc: FlatRow[] = []): FlatRow[] {
  if (!blocks) return acc;
  for (const b of blocks) {
    acc.push({ depth, node: b });
    flatten(b.children, depth + 1, acc);
  }
  return acc;
}

export function WireTrace() {
  const { activeId } = useConvStore();
  const chat = useChatStore();
  if (!activeId) return <EmptyView>pick a conversation</EmptyView>;
  const messages = chat.byConv[activeId]?.messages ?? [];
  if (messages.length === 0) return <EmptyView>no messages yet</EmptyView>;
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 12 }}>
      {messages.map((m) => {
        const rows = flatten(m.blocks);
        return (
          <details key={m.id} open style={{ marginBottom: 12, border: "1px solid var(--border)", borderRadius: 4 }}>
            <summary style={{ padding: "6px 10px", background: "var(--bg-elev)", cursor: "pointer", fontSize: 12 }}>
              <strong>{m.role}</strong>
              <span className="mono muted" style={{ marginLeft: 8, fontSize: 10 }}>{m.id}</span>
              <span style={{ marginLeft: 8 }}><StatusBadge status={m.status} /></span>
              <span className="muted" style={{ marginLeft: 8, fontSize: 11 }}>
                {rows.length} blocks
                {m.parentBlockId ? ` · parentBlockId: ${m.parentBlockId}` : ""}
              </span>
            </summary>
            <div style={{ padding: 8 }}>
              {m.blocks?.map((b) => <BlockView key={b.id} block={b} />)}
            </div>
          </details>
        );
      })}
    </div>
  );
}
