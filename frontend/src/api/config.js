// Config-related hooks — api-keys / providers / scenarios / model-configs.
//
// 设置相关 hooks。

// apikey hooks 已迁移至 entities/apikey (FSD 阶段2);此处转 re-export 保持调用点零改。
export { useApiKeys, useCreateApiKey, useUpdateApiKey, useDeleteApiKey, useTestApiKey } from "@entities/apikey";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, qk, pickList } from "./client.js";

export function useProviders() {
  return useQuery({
    queryKey: qk.providers(),
    queryFn: () => apiFetch("/providers"),
  });
}

// useScenarios — backend's authoritative scenario whitelist. Replaces the
// old hardcoded fallback in ModelsTab that drifted from backend (3 of 5
// scenarios silently 400'd as INVALID_SCENARIO).
//
// 后端 scenario 白名单权威源;ModelsTab 旧硬编码 5 项里 3 项后端不支持,
// 改从这里取。
export function useScenarios() {
  return useQuery({
    queryKey: qk.scenarios(),
    queryFn: () => apiFetch("/scenarios"),
    select: pickList,
    staleTime: 5 * 60 * 1000,
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
