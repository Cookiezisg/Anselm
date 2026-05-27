import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { mockLLMAPI } from "@/api/mockllm";
import { qk } from "@/hooks/queryKeys";
import { EmptyView } from "@/ui";

interface Msg { role: string; content: string }

// 5/27 chat-prompt-redesign segments: identity / how_to_work / tools / environment.
// multi_agent_forging segment removed.
function splitBySections(s: string): Record<string, string> {
  const lines = s.split("\n");
  const out: Record<string, string> = {};
  let cur = "preamble";
  let buf: string[] = [];
  for (const ln of lines) {
    const m = ln.match(/^##\s+(.+)$/);
    if (m) {
      if (buf.length) out[cur] = buf.join("\n").trim();
      cur = (m[1] ?? "").trim();
      buf = [];
    } else {
      buf.push(ln);
    }
  }
  if (buf.length) out[cur] = buf.join("\n").trim();
  return out;
}

export function Prompts() {
  const { data } = useQuery({ queryKey: qk.lastPrompt(), queryFn: () => mockLLMAPI.lastPrompt() });
  const [openSeg, setOpenSeg] = useState<Record<string, boolean>>({});
  if (!data || !data.messages) {
    return <EmptyView>no prompt captured yet — trigger a chat send first</EmptyView>;
  }
  const messages = data.messages as Msg[];
  const system = messages.find((m) => m.role === "system");
  const segments = system ? splitBySections(system.content) : {};
  return (
    <div style={{ height: "100%", overflow: "auto", padding: 12 }}>
      <h3>System Prompt — Segments</h3>
      <p className="muted" style={{ fontSize: 11 }}>
        5/27 chat-prompt-redesign segments: identity / how_to_work / tools / environment.
        multi_agent_forging removed.
      </p>
      {Object.entries(segments).map(([name, body]) => (
        <div key={name} style={{ marginBottom: 6, border: "1px solid var(--border)", borderRadius: 4 }}>
          <div onClick={() => setOpenSeg((o) => ({ ...o, [name]: !o[name] }))} style={{
            padding: "4px 8px", background: "var(--bg-elev)", cursor: "pointer", fontSize: 12,
          }}>
            {openSeg[name] ? "▾" : "▸"} <strong>{name}</strong>
            <span className="muted"> {body.length} chars</span>
          </div>
          {openSeg[name] && <pre className="raw-json" style={{ margin: 0 }}>{body}</pre>}
        </div>
      ))}
      <h3>User + Assistant Messages</h3>
      <pre className="raw-json">{JSON.stringify(messages.filter((m) => m.role !== "system"), null, 2)}</pre>
      {data.tools && (data.tools as unknown[]).length > 0 && (
        <>
          <h3>Tools ({(data.tools as unknown[]).length})</h3>
          <pre className="raw-json">{JSON.stringify(data.tools, null, 2)}</pre>
        </>
      )}
    </div>
  );
}
