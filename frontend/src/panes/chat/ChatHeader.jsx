// ChatHeader — title row + model selector + secondary controls.
//
// ChatHeader —— 标题 + 模型 + 副控件。

import { Icon } from "../../components/primitives/Icon.jsx";
import { EntityRelMeta } from "../../components/shared/EntityRelMeta.jsx";

export function ChatHeader({ conv, onClose }) {
  if (!conv) return null;
  return (
    <div className="chat-header">
      <div className="chat-title-row" style={{ flexDirection: "column", alignItems: "flex-start", gap: 2 }}>
        <div className="chat-title-text">{conv.title || "(无标题)"}</div>
        <div style={{ fontSize: 11, color: "var(--fg-muted)", display: "flex", alignItems: "center", gap: 4 }}>
          <code style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--fg-faint)" }}>{conv.id}</code>
          <EntityRelMeta entityId={conv.id} />
        </div>
      </div>
      <div className="chat-header-actions">
        <div className="model-tag" title={"当前模型: " + (conv.model || "default")}>
          <span className="provider">{(conv.model || "AI").slice(0, 2).toUpperCase()}</span>
          <span>{conv.model || "default"}</span>
        </div>
        {onClose && (
          <button className="icon-btn" title="关闭" onClick={onClose}>
            <Icon.X />
          </button>
        )}
      </div>
    </div>
  );
}
