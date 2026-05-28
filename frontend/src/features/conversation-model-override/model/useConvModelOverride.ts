// useConvModelOverride — sets or clears a conversation's modelOverride.
// PATCH /conversations/:id with {modelOverride: ...} or {modelOverride: null}
// to clear; invalidates the conversation query so ChatHeader re-renders.
//
// 改 / 清当前对话的 modelOverride;PATCH 后 invalidate 让 ChatHeader 重渲。

import { useMutation, useQueryClient } from "@tanstack/react-query";
import { apiFetch, qk } from "@shared/api";
import type { Conversation, ModelRef } from "@entities/conversation";

interface SetOverrideVars {
  conversationId: string;
  override: ModelRef | null;
}

export function useConvModelOverride() {
  const qc = useQueryClient();
  return useMutation<Conversation, Error, SetOverrideVars>({
    mutationFn: ({ conversationId, override }) =>
      apiFetch(`/conversations/${conversationId}`, {
        method: "PATCH",
        body: { modelOverride: override },
      }),
    onSuccess: (_data, { conversationId }) => {
      qc.invalidateQueries({ queryKey: qk.conversation(conversationId) });
      qc.invalidateQueries({ queryKey: qk.conversations() });
    },
  });
}
