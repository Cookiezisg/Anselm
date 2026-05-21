// EntityRelMeta — "· 与 X · Y 相关 [···]" strip for any entity header.
//
// Uses /relations/neighborhood?kind=&id=&depth=1 — this is the actual
// entity-filtered endpoint. /relations?entityId= was silently dropped by
// the backend filter, leaking arbitrary edges into every meta strip.
// Renders nothing when the entity has zero edges (孤岛不显示).
//
// EntityRelMeta —— 实体头部的引用条；neighborhood 端点按实体过滤；零关联
// 时整条不渲染。

import { useNeighborhood } from "../../api/relations.js";
import { EntityLink } from "./EntityLink.jsx";
import { RelMore } from "./RelGraph.jsx";

// Prefix → entity kind (closed enum the backend uses for relation rows).
function guessKind(id) {
  if (!id) return "function";
  const p = id.split("_")[0];
  return {
    f: "function", fn: "function",
    h: "handler",  hd: "handler",
    w: "workflow", wf: "workflow",
    cv: "conversation",
    d: "document", doc: "document",
    s: "skill", sk: "skill",
    mcp: "mcp",
    m: "memory", mem: "memory",
    fr: "flowrun",
  }[p] || "function";
}

export function EntityRelMeta({ entityId, kind, limit = 3 }) {
  const guessedKind = kind || guessKind(entityId);
  const { data: rels = [] } = useNeighborhood({ kind: guessedKind, id: entityId, depth: 1 });

  if (!entityId) return null;

  // Pick the other side of each edge as the neighbour. Dedupe (multi-edge
  // pairs like both forged_from + uses would otherwise list the same id
  // twice).
  const neighbours = [];
  const seen = new Set([entityId]);
  for (const r of rels || []) {
    const otherId = r.fromId === entityId ? r.toId : r.fromId;
    if (!otherId || seen.has(otherId)) continue;
    seen.add(otherId);
    neighbours.push(otherId);
    if (neighbours.length >= limit) break;
  }

  if (neighbours.length === 0) return null;

  return (
    <span style={{ fontSize: 11, color: "var(--fg-faint)", display: "inline-flex", alignItems: "center", gap: 4, flexWrap: "wrap" }}>
      <span>· 与</span>
      {neighbours.map((id, i) => (
        <span key={id} style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
          <EntityLink id={id} />
          {i < neighbours.length - 1 && <span>·</span>}
        </span>
      ))}
      <span>相关</span>
      <RelMore entityId={entityId} kind={guessedKind} label="查看引用关系" />
    </span>
  );
}
