// EntityRelMeta — inline strip showing related entities + RelMore "…" trigger
// that opens the focused neighborhood popover.
//
// EntityRelMeta —— 内联引用条 + "…" 触发 RelMore（聚焦邻域图）。

import { useRelations } from "../../api/library.js";
import { EntityLink } from "./EntityLink.jsx";
import { RelMore } from "./RelGraph.jsx";

export function EntityRelMeta({ entityId, kind, limit = 3 }) {
  const { data: relations = [] } = useRelations(entityId, limit);

  const neighbours = (relations || []).slice(0, limit)
    .map((r) => r.targetId || r.toId || r.id)
    .filter(Boolean);

  if (!entityId) return null;

  return (
    <span style={{ fontSize: 11, color: "var(--fg-faint)", display: "inline-flex", alignItems: "center", gap: 4, flexWrap: "wrap" }}>
      {neighbours.length > 0 && (
        <>
          <span>· 与</span>
          {neighbours.map((id, i) => (
            <span key={id} style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
              <EntityLink id={id} />
              {i < neighbours.length - 1 && <span>·</span>}
            </span>
          ))}
          <span>相关</span>
        </>
      )}
      <RelMore entityId={entityId} kind={kind} label="查看引用关系" />
    </span>
  );
}
