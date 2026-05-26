// Orchestrates answer submission for AskUser questions.
// Extracted verbatim from AskUserModal submit so the component only renders.
//
// 封装 AskUser 应答编排;AskUserModal 只负责渲染,不再含业务决策。

import { useState } from "react";
import { useTranslation } from "react-i18next";
import { apiFetch } from "@shared/api";
import { useToastStore } from "@shared/ui/toastStore";

interface PendingAsk {
  id: string;
  conversationId: string;
  toolCallId: string;
  question?: string;
  context?: string;
  options?: Array<{ id?: string; value?: string; text?: string; label?: string; sub?: string }>;
}

interface UseAskUserAnswerOptions {
  // The component (AskUserModal) reads overlay store and passes these down;
  // feature owns only the submit logic, not navigation/overlay state.
  //
  // 组件读 overlay store 后传入；feature 只持有提交逻辑，不感知 overlay 状态。
  pending: PendingAsk | null;
  onClose: () => void;
}

export function useAskUserAnswer({ pending, onClose }: UseAskUserAnswerOptions) {
  const { t } = useTranslation("conv");
  const pushToast = useToastStore((s) => s.pushToast);

  const [submitting, setSubmitting] = useState(false);

  const submit = async (answer: string) => {
    if (!answer) return;
    setSubmitting(true);
    try {
      await apiFetch(`/conversations/${pending!.conversationId}/pending-questions/${pending!.toolCallId}:resolve`, {
        method: "POST", body: { answer },
      });
      pushToast({ kind: "success", title: t("ask.submitSuccess") });
      onClose();
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
    submitting,
    submit,
  };
}
