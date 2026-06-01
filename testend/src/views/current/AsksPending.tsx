import { useState } from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { postJSON } from "@/api/devClient";
import { qk } from "@/hooks/queryKeys";
import { useConvStore } from "@/stores/conv";
import { useNotificationsStore } from "@/stores/notifications";
import { EmptyView, RelTime } from "@/ui";

interface AskData {
  id?: string;
  toolCallId?: string;
  question?: string;
  header?: string;
  options?: Array<{ label: string; description?: string }>;
  multiSelect?: boolean;
}

export function AsksPending() {
  const { activeId } = useConvStore();
  const notifs = useNotificationsStore((s) => s.list);
  const qc = useQueryClient();
  const [answers, setAnswers] = useState<Record<string, string>>({});

  const answer = useMutation({
    mutationFn: ({ askId, text }: { askId: string; text: string }) =>
      postJSON(`/api/v1/conversations/${activeId}/asks/${askId}:answer`, { answer: text }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.notificationsSnap() }),
  });

  if (!activeId) return <EmptyView>pick a conversation</EmptyView>;
  const pending = notifs.filter((n) =>
    n.conversationId === activeId && n.type === "ask" && n.action === "pending"
  );
  if (pending.length === 0) return <EmptyView>no pending asks</EmptyView>;

  return (
    <div style={{ height: "100%", overflow: "auto", padding: 12 }}>
      {pending.map((n) => {
        const d = (n.data ?? {}) as AskData;
        const askId = d.id ?? n.id;
        const text = answers[askId] ?? "";
        return (
          <div key={askId} style={{
            marginBottom: 12, border: "1px solid var(--border)", borderRadius: 4, padding: 12,
          }}>
            <div style={{ fontSize: 12, fontWeight: 500 }}>{d.header ?? "Ask"}</div>
            <div style={{ marginTop: 4 }}>{d.question ?? "(no question text)"}</div>
            {d.options && d.options.length > 0 && (
              <ul style={{ fontSize: 11, marginTop: 6 }}>
                {d.options.map((o, i) => <li key={i}><strong>{o.label}</strong> — <span className="muted">{o.description}</span></li>)}
              </ul>
            )}
            <textarea value={text} onChange={(e) => setAnswers((a) => ({ ...a, [askId]: e.target.value }))} placeholder="your answer…" style={{
              width: "100%", minHeight: 60, padding: 6, marginTop: 8,
              border: "1px solid var(--border)", borderRadius: 3, background: "var(--bg-paper)",
              fontFamily: "var(--mono)", fontSize: 12, resize: "vertical",
            }} />
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 4 }}>
              <span className="muted" style={{ fontSize: 10 }}><RelTime ts={n.receivedAt} /></span>
              <button onClick={() => answer.mutate({ askId, text })} disabled={!text.trim() || answer.isPending} style={{
                padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)",
                border: "none", borderRadius: 4, cursor: "pointer", fontSize: 12,
              }}>answer</button>
            </div>
          </div>
        );
      })}
    </div>
  );
}
