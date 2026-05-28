// ChatHeader — title row + per-conv model override button + close.
// modelOverride takes precedence; otherwise the dialogue default is implicit
// (shown as "default" label, accent-muted).
//
// 标题 + 对话级模型覆盖按钮 + 关闭。
// 有 override 时高亮显示该 modelId;否则灰显"默认"。

import { useState } from "react";
import { useTranslation } from "react-i18next";
import { Icon } from "@shared/ui/Icon";
import { EntityRelMeta } from "../../../widgets/entity-rel-meta/EntityRelMeta.tsx";
import type { Conversation } from "@entities/conversation";
import { ModelOverrideEditor } from "@features/conversation-model-override";

type ConvRow = Partial<Conversation> & { id: string; model?: string };

interface ChatHeaderProps {
  conv: ConvRow | null | undefined;
  onClose?: () => void;
}

export function ChatHeader({ conv, onClose }: ChatHeaderProps) {
  const { t } = useTranslation(["conv", "common"]);
  const [editorOpen, setEditorOpen] = useState(false);
  if (!conv) return null;

  const override = conv.modelOverride ?? null;
  const label = override ? override.modelId : t("modelOverride.useDefault");

  return (
    <div className="chat-header">
      <div className="chat-title-row" style={{ flexDirection: "column", alignItems: "flex-start", gap: 2 }}>
        <div className="chat-title-text">{conv.title || t("header.noTitle")}</div>
        <div style={{ fontSize: 11, color: "var(--fg-muted)", display: "flex", alignItems: "center", gap: 4 }}>
          <code style={{ fontFamily: "var(--font-mono)", fontSize: 11, color: "var(--fg-faint)" }}>{conv.id}</code>
          <EntityRelMeta entityId={conv.id} kind="conversation" />
        </div>
      </div>
      <div className="chat-header-actions" style={{ position: "relative" }}>
        <button
          className={"header-model-btn" + (override ? " is-active" : "")}
          onClick={() => setEditorOpen((v) => !v)}
          title={t("modelOverride.tooltip")}
        >
          <Icon.Settings />
          <span>{label}</span>
        </button>
        {editorOpen && (
          <ModelOverrideEditor
            conversationId={conv.id}
            current={override}
            onClose={() => setEditorOpen(false)}
          />
        )}
        {onClose && (
          <button className="icon-btn" title={t("common:close")} onClick={onClose}>
            <Icon.X />
          </button>
        )}
      </div>
    </div>
  );
}
