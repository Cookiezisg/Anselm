// EntityLink — clickable entity-ID chip. Detects prefix → routes to the
// right pane via ui store. Used by TextBlock renderInline + anywhere we
// inline-reference an entity.
//
// EntityLink —— 实体 ID 可点击 chip；按前缀路由到对应 pane。

import { Icon } from "../primitives/Icon.jsx";
import { useUIStore } from "../../store/ui.js";

const PREFIX_META = {
  fn:  { pane: "forge",   icon: "Code",          label: "Function" },
  hd:  { pane: "forge",   icon: "Server",        label: "Handler" },
  wf:  { pane: "forge",   icon: "Workflow",      label: "Workflow" },
  sk:  { pane: "skills",  icon: "Sparkles",      label: "Skill" },
  mcp: { pane: "mcp",     icon: "Server",        label: "MCP" },
  mem: { pane: "memory",  icon: "Brain",         label: "Memory" },
  cv:  { pane: "chat",    icon: "MessageSquare", label: "对话" },
  fr:  { pane: "execute", icon: "Play",          label: "FlowRun" },
  doc: { pane: "documents", icon: "FileText",    label: "Document" },
};

export function EntityLink({ id }) {
  const openEntity = useUIStore((s) => s.openEntity);
  const setActiveConv = useUIStore((s) => s.setActiveConv);
  const openPane = useUIStore((s) => s.openPane);

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

  return (
    <button
      className="entity-link"
      title={`${meta.label} · 点击在右侧打开`}
      onClick={onClick}
    >
      <Ic className="icon" />
      <span>{id}</span>
    </button>
  );
}
