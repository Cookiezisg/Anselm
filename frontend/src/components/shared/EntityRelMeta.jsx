// EntityRelMeta — inline strip showing related entities (up to N).
// Reads /api/v1/relations?entityId=...; fails silently (just renders
// nothing) so it's safe to drop next to any entity title.
//
// EntityRelMeta —— "与 X · Y 相关" 内联条；relations API；失败静默不渲染。

import { useRelations } from "../../api/library.js";
import { EntityLink } from "./EntityLink.jsx";

export function EntityRelMeta({ entityId, limit = 3 }) {
  const { data: relations = [] } = useRelations(entityId, limit);
  if (!relations || relations.length === 0) return null;

  const neighbours = relations.slice(0, limit).map((r) => r.targetId || r.toId || r.id).filter(Boolean);
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
    </span>
  );
}
