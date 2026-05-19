// PaneFrame — the chrome shared by every non-chat pane: a thin top bar
// with crumbs + close. Chat skips the bar (its own header is taller).
//
// PaneFrame —— 非 chat pane 的统一外壳：薄顶栏 + 面包屑 + 关闭。
// chat 有自己的 header，不走 pane-bar。

import { Icon } from "../primitives/Icon.jsx";

export const PANE_META = {
  chat:      { icon: "MessageSquare", label: "对话" },
  forge:     { icon: "Hammer",        label: "锻造" },
  execute:   { icon: "Play",          label: "执行" },
  documents: { icon: "FileText",      label: "文档" },
  skills:    { icon: "Sparkles",      label: "Skills" },
  mcp:       { icon: "Server",        label: "MCP" },
  memory:    { icon: "Brain",         label: "Memory" },
  observe:   { icon: "Activity",      label: "洞察" },
  config:    { icon: "Settings",      label: "设置" },
};

export function PaneFrame({ kind, onClose, crumbs, children }) {
  const meta = PANE_META[kind] || { icon: "Square", label: kind };
  const I = Icon[meta.icon] || Icon.MoreHorizontal;

  if (kind === "chat") {
    return (
      <div className="pane" data-kind={kind}>
        <div className="pane-body">{children}</div>
      </div>
    );
  }

  const cs = crumbs && crumbs.length > 0 ? crumbs : [meta.label];

  return (
    <div className="pane" data-kind={kind}>
      <div className="pane-bar">
        <div className="pane-crumbs">
          <I className="icon" />
          <span className={cs.length === 1 ? "cur" : ""}>{cs[0]}</span>
          {cs.slice(1).map((c, i) => (
            <span key={i} style={{ display: "contents" }}>
              <Icon.ChevronRight className="sep" />
              <span className={i === cs.length - 2 ? "cur" : ""}>{c}</span>
            </span>
          ))}
        </div>
        <div className="pane-actions">
          <button className="icon-btn" title="更多"><Icon.MoreHorizontal /></button>
          <button className="icon-btn" title="关闭" onClick={onClose}><Icon.X /></button>
        </div>
      </div>
      <div className="pane-body">{children}</div>
    </div>
  );
}
