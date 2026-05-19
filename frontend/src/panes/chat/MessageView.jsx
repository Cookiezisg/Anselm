// MessageView — one message (user or assistant). Meta row + body + opt
// attachments. msg-actions hide by default and fade in on hover.
//
// MessageView —— 单条消息：meta + body + 附件；actions hover 才显示。

import { memo } from "react";
import { useChatStore } from "../../store/chat.js";
import { Icon } from "../../components/primitives/Icon.jsx";
import { RelTime } from "../../components/shared/RelTime.jsx";
import { Badge } from "../../components/primitives/Badge.jsx";
import { BlockList } from "./BlockRenderer.jsx";

export const MessageView = memo(function MessageView({ convId, msgId }) {
  const message = useChatStore((s) => s.convs[convId]?.messages.get(msgId));
  if (!message) return null;

  const isUser = message.role === "user";
  const provider = (message.model || "").split("-")[0]?.toUpperCase().slice(0, 2) || (isUser ? "Y" : "AI");

  return (
    <div className={"msg role-" + message.role} data-comment-anchor={message.id}>
      <div className="msg-meta">
        <div className="msg-author">
          <div className={"msg-author-avatar " + (isUser ? "user" : "ai")}>
            {isUser ? "Y" : provider}
          </div>
          <span>{isUser ? "你" : message.model || "Forgify"}</span>
        </div>
        <span>·</span>
        <RelTime ts={message.createdAt} />
        {!isUser && message.inputTokens != null && (
          <>
            <span>·</span>
            <span className="msg-tokens">
              <span style={{ color: "var(--fg-muted)" }}>{message.inputTokens.toLocaleString()}</span>
              <span className="sep"> ↓ ↑ </span>
              <span style={{ color: "var(--fg-muted)" }}>{message.outputTokens?.toLocaleString() ?? "—"}</span>
            </span>
          </>
        )}
        {message.status === "streaming" && (
          <Badge kind="streaming">streaming</Badge>
        )}
        {message.status === "error" && (
          <Badge kind="error">error</Badge>
        )}
        <div style={{ flex: 1 }} />
        <div className="msg-actions">
          <button className="msg-action" title="复制"
                  onClick={() => navigator.clipboard?.writeText(extractText(convId, message)).catch(() => {})}>
            <Icon.Copy />
          </button>
          {!isUser && <button className="msg-action" title="重新生成"><Icon.Refresh /></button>}
          {isUser && <button className="msg-action" title="编辑并重发"><Icon.Wrench /></button>}
          <button className="msg-action" title="从这里分叉新对话"><Icon.GitBranch /></button>
          <button className="msg-action" title="更多"><Icon.MoreHorizontal /></button>
        </div>
      </div>
      <div className="msg-body">
        <BlockList convId={convId} blockIds={message.blocks} defaultOpenTools={false} />
        {message.attachments?.length > 0 && (
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginTop: 12 }}>
            {message.attachments.map((a) => (
              <div className="attached-pill" key={a.id || a.fileName}>
                {(a.mimeType || "").startsWith("image/")
                  ? <Icon.Image className="file-icon" />
                  : <Icon.File className="file-icon" />}
                <span>{a.fileName}</span>
                {typeof a.sizeBytes === "number" && (
                  <span className="file-meta">{Math.round(a.sizeBytes / 1024)}kb</span>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
});

function extractText(convId, message) {
  const store = useChatStore.getState();
  const blocks = store.convs[convId]?.blocks;
  if (!blocks) return "";
  return message.blocks
    .map((bid) => blocks.get(bid))
    .filter((b) => b && b.type === "text")
    .map((b) => b.content)
    .join("\n\n");
}
