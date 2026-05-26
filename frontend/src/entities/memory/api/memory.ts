import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type { Memory, CreateMemoryBody, UpdateMemoryBody, PinMemoryVars } from "../model/types";

export function useMemories(type?: string) {
  const qs = type ? `?type=${type}` : "";
  return useQuery<Memory[]>({
    queryKey: qk.memories(type),
    queryFn: () => apiFetch("/memories" + qs),
    select: pickList<Memory>,
  });
}

export function useMemory(name: string) {
  return useQuery<Memory>({
    queryKey: qk.memory(name),
    queryFn: () => apiFetch(`/memories/${encodeURIComponent(name)}`),
    enabled: !!name,
  });
}

// Backend: PATCH /memories/{name} (not PUT).
export function useUpdateMemory() {
  const qc = useQueryClient();
  return useMutation<Memory, Error, { name: string; body: UpdateMemoryBody }>({
    mutationFn: ({ name, body }) =>
      apiFetch(`/memories/${encodeURIComponent(name)}`, { method: "PATCH", body }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["memories"] }),
  });
}

export function useCreateMemory() {
  const qc = useQueryClient();
  return useMutation<Memory, Error, CreateMemoryBody>({
    mutationFn: (body) => apiFetch("/memories", { method: "POST", body }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["memories"] }),
  });
}

export function useDeleteMemory() {
  const qc = useQueryClient();
  return useMutation<null, Error, string>({
    mutationFn: (name) =>
      apiFetch(`/memories/${encodeURIComponent(name)}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["memories"] }),
  });
}

// Pin/unpin via PATCH with pinned bool. Backend Update accepts the field.
export function usePinMemory() {
  const qc = useQueryClient();
  return useMutation<Memory, Error, PinMemoryVars>({
    mutationFn: ({ name, pinned }) =>
      apiFetch(`/memories/${encodeURIComponent(name)}`, {
        method: "PATCH", body: { pinned },
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["memories"] }),
  });
}
