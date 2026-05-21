// EntityLink — clickable entity-ID chip. Detects prefix → routes to the
// right pane via ui store. Used by TextBlock renderInline + anywhere we
// inline-reference an entity.
//
// EntityLink —— 实体 ID 可点击 chip；按前缀路由到对应 pane。

import { Icon } from "../primitives/Icon.jsx";
import { useUIStore } from "../../store/ui.js";
import { useEntityName } from "../../hooks/useEntityName.js";

const PREFIX_META = {
  f:   { pane: "forge",   icon: "Code",          label: "Function" },
  fn:  { pane: "forge",   icon: "Code",          label: "Function" },
  h:   { pane: "forge",   icon: "Server",        label: "Handler" },
  hd:  { pane: "forge",   icon: "Server",        label: "Handler" },
  w:   { pane: "forge",   icon: "Workflow",      label: "Workflow" },
  wf:  { pane: "forge",   icon: "Workflow",      label: "Workflow" },
  s:   { pane: "skills",  icon: "Sparkles",      label: "Skill" },
  sk:  { pane: "skills",  icon: "Sparkles",      label: "Skill" },
  mcp: { pane: "mcp",     icon: "Server",        label: "MCP" },
  m:   { pane: "memory",  icon: "Brain",         label: "Memory" },
  mem: { pane: "memory",  icon: "Brain",         label: "Memory" },
  cv:  { pane: "chat",    icon: "MessageSquare", label: "对话" },
  fr:  { pane: "execute", icon: "Play",          label: "FlowRun" },
  d:   { pane: "documents", icon: "FileText",    label: "Document" },
  doc: { pane: "documents", icon: "FileText",    label: "Document" },
};

export function EntityLink({ id }) {
  const openEntity = useUIStore((s) => s.openEntity);
  const setActiveConv = useUIStore((s) => s.setActiveConv);
  const openPane = useUIStore((s) => s.openPane);
  const name = useEntityName(id);

  const prefix = id.split("_")[0];
  const meta = PREFIX_META[prefix] || { pane: "forge", icon: "Hammer", label: prefix };
  const Ic = Icon[meta.icon] || Icon.Hammer;

  const onClick = (e) => {
    e.stopPropagation();
    if (prefix === "cv") {
      setActiveConv(id);
      openPane("chat");
    } else {
      openEntity(meta.pane, id);
    }
  };

  const display = name || id;
  const tip = name ? `${meta.label} · ${name} · ${id}` : `${meta.label} · ${id}`;

  return (
    <button className="entity-link" title={tip} onClick={onClick}>
      <Ic className="icon" />
      <span>{display}</span>
    </button>
  );
}
