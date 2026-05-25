// Conversation hooks — list/detail/messages/CRUD/send. Send doesn't
// invalidate; the eventlog SSE drives UI updates instead.
//
// 对话相关 hooks；发送不 invalidate，让 SSE 推回事件驱动 UI。

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiFetch, qk, pickList } from "./client.js";
import { useSettings } from "../store/settings.js";

export function useConversations() {
  const uid = useSettings((s) => s.activeUserId);
  return useQuery({
    queryKey: qk.conversations(),
    queryFn: () => apiFetch("/conversations?limit=100"),
    select: pickList,
    enabled: !!uid,
  });
}

export function useConversation(id) {
  return useQuery({
    queryKey: qk.conversation(id),
    queryFn: () => apiFetch(`/conversations/${id}`),
    enabled: !!id,
  });
}

export function useConversationMessages(convId) {
  return useQuery({
    queryKey: qk.messages(convId),
    queryFn: () => apiFetch(`/conversations/${convId}/messages?limit=200`),
    select: pickList,
    enabled: !!convId,
  });
}

export function useCreateConversation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body) =>
      apiFetch("/conversations", { method: "POST", body: body || {} }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.conversations() }),
  });
}

export function useUpdateConversation(id) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (patch) =>
      apiFetch(`/conversations/${id}`, { method: "PATCH", body: patch }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.conversations() });
      qc.invalidateQueries({ queryKey: qk.conversation(id) });
    },
  });
}

export function useDeleteConversation() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) =>
      apiFetch(`/conversations/${id}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.conversations() }),
  });
}

export function useSendMessage(convId) {
  return useMutation({
    mutationFn: (body) =>
      apiFetch(`/conversations/${convId}/messages`, { method: "POST", body }),
  });
}

export function useCancelStream(convId) {
  return useMutation({
    mutationFn: () =>
      apiFetch(`/conversations/${convId}/stream`, { method: "DELETE" }),
  });
}
