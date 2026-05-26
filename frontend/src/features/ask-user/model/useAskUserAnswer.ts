// Orchestrates answer submission for AskUser questions.
// Extracted verbatim from AskUserModal submit so the component only renders.
//
// 封装 AskUser 应答编排;AskUserModal 只负责渲染,不再含业务决策。

import { useState } from "react";
import { useTranslation } from "react-i18next";
import { apiFetch } from "@shared/api";
// TODO(阶段4): ui store 拆进 app/model 后,将此 import 替换为正式 FSD 路径。
// eslint-disable-next-line boundaries/dependencies
import { useUIStore } from "../../../store/ui.js";

export function useAskUserAnswer() {
  const { t } = useTranslation("conv");
  const pending = useUIStore((s: { pendingAsk: { id: string; conversationId: string; toolCallId: string; question?: string; context?: string; options?: Array<{ id?: string; value?: string; text?: string; label?: string; sub?: string }> } | null }) => s.pendingAsk);
  const askOpen = useUIStore((s: { askOpen: boolean }) => s.askOpen);
  const setAskOpen = useUIStore((s: { setAskOpen: (b: boolean) => void }) => s.setAskOpen);
  const setPendingAsk = useUIStore((s: { setPendingAsk: (v: null) => void }) => s.setPendingAsk);
  const pushToast = useUIStore((s: { pushToast: (toast: { kind: string; title: string; desc?: string }) => void }) => s.pushToast);

  const [submitting, setSubmitting] = useState(false);

  const isOpen = askOpen || !!pending;

  const close = () => {
    setAskOpen(false);
    setPendingAsk(null);
  };

  const submit = async (answer: string) => {
    if (!answer) return;
    setSubmitting(true);
    try {
      await apiFetch(`/conversations/${pending!.conversationId}/pending-questions/${pending!.toolCallId}:resolve`, {
        method: "POST", body: { answer },
      });
      pushToast({ kind: "success", title: t("ask.submitSuccess") });
      close();
    } catch (err) {
      pushToast({ kind: "error", title: t("ask.submitFail"), desc: (err as Error).message });
    } finally {
      setSubmitting(false);
    }
  };

  return {
    pending,
    askOpen,
    isOpen,
    submitting,
    close,
    submit,
  };
}
