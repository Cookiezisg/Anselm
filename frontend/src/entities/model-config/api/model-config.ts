import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type {
  CapabilityOverrideBody,
  ModelCapability,
  ModelConfig,
  Provider,
  Scenario,
  UpsertModelConfigBody,
} from "../model/types";

export function useProviders() {
  return useQuery<Provider[]>({
    queryKey: qk.providers(),
    queryFn: () => apiFetch("/providers"),
  });
}

export function useModelConfigs() {
  return useQuery<ModelConfig[]>({
    queryKey: qk.modelConfigs(),
    queryFn: () => apiFetch("/model-configs"),
    select: pickList<ModelConfig>,
  });
}

export function useUpsertModelConfig() {
  const qc = useQueryClient();
  return useMutation<ModelConfig, Error, { scenario: Scenario } & UpsertModelConfigBody>({
    mutationFn: ({ scenario, ...body }) =>
      apiFetch(`/model-configs/${scenario}`, { method: "PUT", body }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.modelConfigs() }),
  });
}

export function useModelCapabilities() {
  return useQuery<ModelCapability[]>({
    queryKey: qk.modelCapabilities(),
    queryFn: () => apiFetch("/model-capabilities"),
    select: pickList<ModelCapability>,
  });
}

export function useSetModelCapabilityOverride() {
  const qc = useQueryClient();
  return useMutation<void, Error, { provider: string; modelId: string } & CapabilityOverrideBody>({
    mutationFn: ({ provider, modelId, ...body }) =>
      apiFetch(`/model-capabilities/${provider}/${encodeURIComponent(modelId)}`, {
        method: "PUT",
        body,
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.modelCapabilities() }),
  });
}

export function useClearModelCapabilityOverride() {
  const qc = useQueryClient();
  return useMutation<void, Error, { provider: string; modelId: string }>({
    mutationFn: ({ provider, modelId }) =>
      apiFetch(`/model-capabilities/${provider}/${encodeURIComponent(modelId)}`, {
        method: "DELETE",
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.modelCapabilities() }),
  });
}
