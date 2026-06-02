import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type {
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
