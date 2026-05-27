import { useQuery } from "@tanstack/react-query";
import { mockLLMAPI } from "@/api/mockllm";
import { qk } from "@/hooks/queryKeys";
import { EmptyView, RelTime } from "@/ui";

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

export function ToolsRegistry() {
  const { data } = useQuery({
    queryKey: qk.lastPrompt(),
    queryFn: () => mockLLMAPI.lastPrompt(),
  });

  if (!data || !data.tools) {
    return <EmptyView>no prompt captured yet — trigger a chat send first</EmptyView>;
  }

  const toolList = data.tools as Array<{ name?: string; description?: string }>;
  const groups: Record<string, Array<{ name: string; description?: string }>> = { RESIDENT: [] };
  for (const t of toolList) {
    if (!t.name) continue;
    const cat = categorize(t.name);
    (groups[cat] ??= []).push({ name: t.name, description: t.description });
  }

  return (
    <div style={{ height: "100%", overflow: "auto", padding: 12 }}>
      <h3 style={{ marginTop: 0 }}>Active Toolset</h3>
      <p className="muted" style={{ fontSize: 11 }}>
        Heuristic categorization by name prefix. <strong>RESIDENT</strong> = always present.
        Others = present only after activate_tools(&lt;category&gt;) ran.
        {data.capturedAt && <> &nbsp;captured <RelTime ts={data.capturedAt} /></>}
      </p>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: 12 }}>
        {Object.entries(groups).map(([cat, tools]) => (
          <div key={cat} style={{ border: "1px solid var(--border)", borderRadius: 4 }}>
            <div style={{
              padding: "6px 10px",
              background: cat === "RESIDENT" ? "var(--bg-elev-2)" : "var(--bg-elev)",
              fontSize: 11, fontWeight: 500,
            }}>
              {cat} <span className="muted">({tools.length})</span>
            </div>
            <ul style={{ margin: 0, padding: "6px 0 6px 24px", fontSize: 11 }}>
              {tools.sort((a, b) => a.name.localeCompare(b.name)).map((t) => (
                <li key={t.name}>
                  <code style={{ fontSize: 10 }}>{t.name}</code>
                  {t.description && (
                    <span className="muted" style={{ marginLeft: 6 }}>
                      — {t.description.slice(0, 60)}
                    </span>
                  )}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </div>
  );
}
