import { useQuery } from "@tanstack/react-query";
import { useConvStore } from "@/stores/conv";
import { useChatStore, type BlockNode } from "@/stores/chat";
import { mockLLMAPI } from "@/api/mockllm";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, StatusBadge, RelTime } from "@/ui";

interface CallRow { msgId: string; block: BlockNode }

function flattenToolCalls(blocks: BlockNode[] | undefined, msgId: string, acc: CallRow[] = []): CallRow[] {
  if (!blocks) return acc;
  for (const b of blocks) {
    if (b.type === "tool_call") acc.push({ msgId, block: b });
    flattenToolCalls(b.children, msgId, acc);
  }
  return acc;
}

export function ToolCalls() {
  const { activeId } = useConvStore();
  const chat = useChatStore();
  const { data: prompt } = useQuery({
    queryKey: qk.lastPrompt(),
    queryFn: () => mockLLMAPI.lastPrompt(),
  });
  if (!activeId) return <EmptyView>pick a conversation</EmptyView>;
  const messages = chat.byConv[activeId]?.messages ?? [];
  const calls = messages.flatMap((m) => flattenToolCalls(m.blocks, m.id));

  const offeredTools = (prompt?.tools as Array<{ name?: string }> | undefined) ?? [];

  return (
    <div style={{ height: "100%", overflow: "auto", padding: 8 }}>
      <h3 style={{ marginTop: 0 }}>Tool Calls in current conv</h3>
      {calls.length === 0 ? (
        <div className="muted">no tool_call blocks yet</div>
      ) : (
        <table className="dt">
          <thead>
            <tr><th>tool</th><th>status</th><th>group</th><th>destructive</th><th>duration</th></tr>
          </thead>
          <tbody>
            {calls.map(({ block }) => {
              const a = (block.attrs ?? {}) as Record<string, unknown>;
              return (
                <tr key={block.id}>
                  <td className="mono">{String(a.toolName ?? "?")}</td>
                  <td><StatusBadge status={block.status} /></td>
                  <td>{a.executionGroup != null ? String(a.executionGroup) : "—"}</td>
                  <td>{a.destructive ? <span className="pill error">destructive</span> : "—"}</td>
                  <td className="muted">{block.durationMs != null ? `${block.durationMs}ms` : "—"}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}

      <h3>Active Toolset (from last captured prompt)</h3>
      <p className="muted" style={{ fontSize: 11 }}>
        Heuristic categorization by name prefix. Resident = always present.
        Lazy = present only after activate_tools(&lt;category&gt;) ran.
        {prompt?.capturedAt && <> &nbsp;captured <RelTime ts={prompt.capturedAt} /></>}
      </p>
      {offeredTools.length === 0 ? (
        <div className="muted">no prompt captured — trigger a chat send first</div>
      ) : (
        <ToolGroups tools={offeredTools.map((t) => String(t.name ?? "?"))} />
      )}
    </div>
  );
}

const CATEGORY_PREFIXES: Record<string, RegExp> = {
  function: /^(search_function|get_function|create_function|edit_function|revert_function|delete_function|run_function|search_function_executions|get_function_execution)$/,
  handler: /^(search_handler|get_handler|create_handler|edit_handler|revert_handler|delete_handler|call_handler|update_handler_config|search_handler_calls|get_handler_call)$/,
  workflow: /^(search_workflow|get_workflow|create_workflow|edit_workflow|revert_workflow|delete_workflow|search_workflow_executions|get_workflow_execution|trigger_workflow)$/,
  mcp: /^(search_mcp_tools|call_mcp_tool)$/,
  skill: /^(search_skills|activate_skill)$/,
  document: /^(search_documents|get_document|create_document|edit_document|delete_document)$/,
};

function categorize(name: string): string {
  for (const [cat, re] of Object.entries(CATEGORY_PREFIXES)) {
    if (re.test(name)) return cat;
  }
  return "RESIDENT";
}

function ToolGroups({ tools }: { tools: string[] }) {
  const groups: Record<string, string[]> = { RESIDENT: [] };
  for (const t of tools) {
    const cat = categorize(t);
    (groups[cat] ??= []).push(t);
  }
  return (
    <div style={{ display: "flex", flexWrap: "wrap", gap: 12 }}>
      {Object.entries(groups).map(([cat, names]) => (
        <div key={cat} style={{ minWidth: 200, border: "1px solid var(--border)", borderRadius: 4 }}>
          <div style={{ padding: "4px 8px", background: "var(--bg-elev)", fontSize: 11, fontWeight: 500 }}>
            {cat} <span className="muted">({names.length})</span>
          </div>
          <ul style={{ margin: 0, padding: "4px 0 4px 24px", fontSize: 11 }}>
            {names.sort().map((n) => <li key={n} className="mono">{n}</li>)}
          </ul>
        </div>
      ))}
    </div>
  );
}
