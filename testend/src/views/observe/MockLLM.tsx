import { useState } from "react";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { mockLLMAPI } from "@/api/mockllm";
import { qk } from "@/hooks/queryKeys";
import { MonacoEditor } from "@/ui/MonacoEditor";
import { EmptyView } from "@/ui";

export function MockLLM() {
  const qc = useQueryClient();
  const [scripts, setScripts] = useState(`[
  { "delayMs": 0, "type": "text", "content": "Hello from mock!" }
]`);
  const { data: queue } = useQuery({
    queryKey: ["mock-llm-queue"],
    queryFn: () => mockLLMAPI.queue(),
    refetchInterval: 2000,
  });
  const { data: last } = useQuery({
    queryKey: qk.lastPrompt(),
    queryFn: () => mockLLMAPI.lastPrompt(),
    refetchInterval: 5000,
  });
  const push = useMutation({
    mutationFn: (s: unknown[]) => mockLLMAPI.push(s),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["mock-llm-queue"] }),
  });
  const clear = useMutation({
    mutationFn: () => mockLLMAPI.clear(),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["mock-llm-queue"] }),
  });
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 12 }}>
      <h3 style={{ marginTop: 0 }}>Push Mock Scripts</h3>
      <p className="muted" style={{ fontSize: 11 }}>
        JSON array — each item describes a mock response chunk. Sent in order on next LLM call.
      </p>
      <div style={{ border: "1px solid var(--border)", borderRadius: 4 }}>
        <MonacoEditor value={scripts} onChange={setScripts} language="json" height={200} />
      </div>
      <div style={{ marginTop: 8, display: "flex", gap: 8 }}>
        <button onClick={() => {
          try { push.mutate(JSON.parse(scripts)); } catch (e) { alert(`bad JSON: ${(e as Error).message}`); }
        }} disabled={push.isPending} style={{
          padding: "4px 12px", background: "var(--accent)", color: "var(--accent-fg)",
          border: "none", borderRadius: 4, fontSize: 12, cursor: "pointer",
        }}>Push</button>
        <button onClick={() => clear.mutate()} disabled={clear.isPending} style={{
          padding: "4px 12px", fontSize: 12,
        }}>Clear queue</button>
        {push.data && <span className="muted" style={{ alignSelf: "center" }}>pushed {push.data.pushed}</span>}
      </div>

      <h3>Queue ({queue?.count ?? 0})</h3>
      {queue && queue.scripts.length > 0 ? (
        <pre className="raw-json">{JSON.stringify(queue.scripts, null, 2)}</pre>
      ) : (
        <EmptyView>queue empty</EmptyView>
      )}

      <h3>Last Captured Prompt</h3>
      {last && last.messages ? (
        <>
          <div className="muted" style={{ fontSize: 11, marginBottom: 6 }}>
            captured: {last.capturedAt ?? "—"}
          </div>
          <pre className="raw-json" style={{ maxHeight: 400, overflow: "auto" }}>
            {JSON.stringify({ messages: last.messages, tools: last.tools }, null, 2)}
          </pre>
        </>
      ) : (
        <EmptyView>no prompt captured yet</EmptyView>
      )}
    </div>
  );
}
