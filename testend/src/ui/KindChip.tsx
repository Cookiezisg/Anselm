const COLORS: Record<string, string> = {
  function: "#4a7cc4",
  handler: "#4a8c4a",
  workflow: "#d4a017",
  skill: "#8b5cf6",
  mcp: "#d97757",
  document: "#6b6862",
};

export function KindChip({ kind }: { kind: string }) {
  const color = COLORS[kind] ?? "#9b988f";
  return (
    <span className="pill" style={{ background: `${color}22`, color }}>{kind}</span>
  );
}
