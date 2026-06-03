// KindChip — entity kind label with color coding.
// kinds: function | handler | workflow | agent | skill | mcp
//
// CSS defines .kind-chip.fn/.hd/.wf/.ag/.sk/.mcp.

interface KindChipProps {
  kind: string;
}

const META: Record<string, { cls: string; label: string }> = {
  function: { cls: "fn", label: "Function" },
  handler:  { cls: "hd", label: "Handler" },
  workflow: { cls: "wf", label: "Workflow" },
  agent:    { cls: "ag", label: "Agent" },
  skill:    { cls: "sk", label: "Skill" },
  mcp:      { cls: "mcp", label: "MCP" },
};

export function KindChip({ kind }: KindChipProps) {
  const m = META[kind] || { cls: "fn", label: kind };
  return <span className={`kind-chip ${m.cls}`}>{m.label}</span>;
}
