// Orchestrates answer submission for AskUser questions.
// Extracted verbatim from AskUserModal submit so the component only renders.
//
// 封装 AskUser 应答编排;AskUserModal 只负责渲染,不再含业务决策。

import { useState } from "react";
import { useTranslation } from "react-i18next";
import { apiFetch } from "@shared/api";
// TODO(4b): pages props 化后移除 feature-tmp→app 过渡反向引用
// eslint-disable-next-line boundaries/dependencies
import { useOverlayStore } from "@app/model";
import { useToastStore } from "@shared/ui/toastStore";

export function useAskUserAnswer() {
  const { t } = useTranslation("conv");
  const pending = useOverlayStore((s) => s.pendingAsk);
  const askOpen = useOverlayStore((s) => s.askOpen);
  const setAskOpen = useOverlayStore((s) => s.setAskOpen);
  const setPendingAsk = useOverlayStore((s) => s.setPendingAsk);
  const pushToast = useToastStore((s) => s.pushToast);

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
      // apiFetch is called directly (no useMutation), so global MutationCache
      // onError does not fire. Feature handles this error toast itself.
      //
      // 直接调 apiFetch 不经 useMutation，全局 onError 不触发，此处保留 toast。
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
