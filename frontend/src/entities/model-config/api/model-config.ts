import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type { ModelConfig, Provider, Scenario, ScenarioEntry, UpsertModelConfigBody } from "../model/types";

export function useProviders() {
  return useQuery<Provider[]>({
    queryKey: qk.providers(),
    queryFn: () => apiFetch("/providers"),
  });
}

// useScenarios — backend's authoritative scenario whitelist. Closed 3-set
// (dialogue/utility/agent); kept as a hook so UIs can iterate without
// hardcoding the union.
//
// 后端 scenario 白名单权威源(3 set);hook 暴露便于 UI 迭代而不硬编码。
export function useScenarios() {
  return useQuery<ScenarioEntry[]>({
    queryKey: qk.scenarios(),
    queryFn: () => apiFetch("/scenarios"),
    select: pickList<ScenarioEntry>,
    staleTime: 5 * 60 * 1000,
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
