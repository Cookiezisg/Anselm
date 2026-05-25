// Dashboard — Gemini-style welcome page. Single centered greeting + pill
// input + optional smart context strip. Enter submits the first message
// (creates conv → sends → switches to chat pane).
//
// Dashboard —— Gemini-style 欢迎页。居中问候 + pill 输入 + 可选智能条;
// Enter 串行新建 conv + 发首条消息 + 切到 chat pane。

import { useState } from "react";
import { useTranslation } from "react-i18next";
import { RelTime } from "../../components/shared/RelTime.jsx";
import { useUIStore } from "../../store/ui.js";
import { useConversations, useCreateConversation } from "../../api/conversations.js";
import { useDisplayName } from "../../hooks/useDisplayName.js";
import { apiFetch } from "../../api/client.js";
import { WelcomeInput } from "./WelcomeInput.jsx";
import { useGreeting } from "./useGreeting.js";
import { useContextStrip } from "./useContextStrip.js";

function ContextStrip({ strip, onJump }) {
  const { t } = useTranslation("dashboard");
  if (!strip) return null;
  if (strip.kind === "waiting") {
    return (
      <div className="wel-strip">
        <span className="wel-strip-dot" style={{ background: "var(--status-warn)" }} />
        <span dangerouslySetInnerHTML={{ __html: t("contextStrip.waiting", { count: strip.payload.count }) }} />{" · "}
        <button className="wel-strip-link" onClick={() => onJump("execute")}>{strip.payload.flowName}</button>
      </div>
    );
  }
  if (strip.kind === "failed") {
    return (
      <div className="wel-strip">
        <span className="wel-strip-dot" style={{ background: "var(--status-error)" }} />
        <span dangerouslySetInnerHTML={{ __html: t("contextStrip.failed", { count: strip.payload.count }) }} />{" · "}
        <button className="wel-strip-link" onClick={() => onJump("execute")}>{t("contextStrip.failedLink")}</button>
      </div>
    );
  }
  if (strip.kind === "running") {
    return (
      <div className="wel-strip">
        <span className="wel-strip-dot" style={{ background: "var(--status-info)" }} />
        <span dangerouslySetInnerHTML={{ __html: t("contextStrip.running", { count: strip.payload.count }) }} />{" · "}
        {t("contextStrip.runningLinkPrefix")} <RelTime ts={strip.payload.latestStartedAt} />{" "}{t("contextStrip.runningLinkSuffix")}
      </div>
    );
  }
  if (strip.kind === "recent") {
    return (
      <div className="wel-strip">
        <span className="wel-strip-dot" style={{ background: "var(--fg-faint)" }} />
        <span>{t("contextStrip.recent")} · <button className="wel-strip-link" onClick={() => onJump("chat", strip.payload.convId)}>{strip.payload.convTitle}</button> · <RelTime ts={strip.payload.updatedAt} /></span>
      </div>
    );
  }
  return null;
}

export function Dashboard() {
  const openPane      = useUIStore((s) => s.openPane);
  const setActiveConv = useUIStore((s) => s.setActiveConv);
  const pushToast     = useUIStore((s) => s.pushToast);

  const { data: conversations = [] } = useConversations();
  const [displayName] = useDisplayName();
  const create = useCreateConversation();

  const hasRecentConv = conversations.some(
    (c) => c.updatedAt && Date.now() - new Date(c.updatedAt).getTime() < 24 * 60 * 60 * 1000
  );
  const greeting = useGreeting({ hasRecentConv, displayName });
  const strip = useContextStrip();

  const { t } = useTranslation("dashboard");
  const [submitting, setSubmitting] = useState(false);

  const onSubmit = async (text) => {
    setSubmitting(true);
    try {
      const created = await create.mutateAsync({});
      if (created?.id) {
        setActiveConv(created.id);
        openPane("chat");
        await apiFetch(`/conversations/${created.id}/messages`, { method: "POST", body: { content: text } });
      }
    } catch (err) {
      pushToast({ kind: "error", title: t("sendFailed"), desc: err.message });
    } finally {
      setSubmitting(false);
    }
  };

  const onJump = (pane, convId) => {
    if (convId) setActiveConv(convId);
    openPane(pane);
  };

  return (
    <div className="wel">
      <div className="wel-greet">{greeting}</div>
      <WelcomeInput onSubmit={onSubmit} isSubmitting={submitting} />
      <ContextStrip strip={strip} onJump={onJump} />
    </div>
  );
}
