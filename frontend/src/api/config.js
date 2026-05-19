// Config-related hooks — api-keys / providers / model-configs.
//
// 设置相关 hooks。

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, qk, pickList } from "./client.js";

export function useApiKeys() {
  return useQuery({
    queryKey: qk.apikeys(),
    queryFn: () => apiFetch("/api-keys?limit=100"),
    select: pickList,
  });
}

export function useProviders() {
  return useQuery({
    queryKey: qk.providers(),
    queryFn: () => apiFetch("/providers"),
  });
}

export function useCreateApiKey() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body) =>
      apiFetch("/api-keys", { method: "POST", body }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.apikeys() }),
  });
}

export function useUpdateApiKey(id) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (patch) =>
      apiFetch(`/api-keys/${id}`, { method: "PATCH", body: patch }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.apikeys() }),
  });
}

export function useDeleteApiKey() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) =>
      apiFetch(`/api-keys/${id}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.apikeys() }),
  });
}

export function useTestApiKey() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) =>
      apiFetch(`/api-keys/${id}:test`, { method: "POST" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.apikeys() }),
  });
}

export function useModelConfigs() {
  return useQuery({
    queryKey: qk.modelConfigs(),
    queryFn: () => apiFetch("/model-configs"),
    select: pickList,
  });
}

export function useUpsertModelConfig() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ scenario, ...body }) =>
      apiFetch(`/model-configs/${scenario}`, { method: "PUT", body }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.modelConfigs() }),
  });
}
