import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type { ApiKey, CreateApiKeyBody, UpdateApiKeyPatch, TestApiKeyResult } from "../model/types";

export function useApiKeys() {
  return useQuery<ApiKey[]>({
    queryKey: qk.apikeys(),
    queryFn: () => apiFetch("/api-keys?limit=100"),
    select: pickList<ApiKey>,
  });
}

export function useCreateApiKey() {
  const qc = useQueryClient();
  return useMutation<ApiKey, Error, CreateApiKeyBody>({
    mutationFn: (body) =>
      apiFetch("/api-keys", { method: "POST", body }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.apikeys() });
      qc.invalidateQueries({ queryKey: qk.modelCapabilities() });
    },
  });
}

export function useUpdateApiKey(id: string) {
  const qc = useQueryClient();
  return useMutation<ApiKey, Error, UpdateApiKeyPatch>({
    mutationFn: (patch) =>
      apiFetch(`/api-keys/${id}`, { method: "PATCH", body: patch }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.apikeys() });
      qc.invalidateQueries({ queryKey: qk.modelCapabilities() });
    },
  });
}

export function useDeleteApiKey() {
  const qc = useQueryClient();
  return useMutation<null, Error, string>({
    mutationFn: (id) =>
      apiFetch(`/api-keys/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.apikeys() });
      qc.invalidateQueries({ queryKey: qk.modelCapabilities() });
    },
  });
}

export function useTestApiKey() {
  const qc = useQueryClient();
  return useMutation<TestApiKeyResult, Error, string>({
    mutationFn: (id) =>
      apiFetch(`/api-keys/${id}:test`, { method: "POST" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.apikeys() });
      qc.invalidateQueries({ queryKey: qk.modelCapabilities() });
    },
  });
}
