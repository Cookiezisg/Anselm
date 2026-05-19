// FlowRun hooks — list, detail (with nodes), node-level approve/reject,
// cancel, triage spawner.
//
// FlowRun 相关 hooks。

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, qk, pickList } from "./client.js";

export function useFlowRuns(params = {}) {
  const qs = new URLSearchParams({ limit: "100", ...params }).toString();
  return useQuery({
    queryKey: [...qk.flowruns(), params],
    queryFn: () => apiFetch(`/flowruns?${qs}`),
    select: pickList,
  });
}

export function useFlowRun(id) {
  return useQuery({
    queryKey: qk.flowrun(id),
    queryFn: () => apiFetch(`/flowruns/${id}`),
    enabled: !!id,
  });
}

export function useFlowRunNodes(id) {
  return useQuery({
    queryKey: qk.flowrunNodes(id),
    queryFn: () => apiFetch(`/flowruns/${id}/nodes`),
    select: pickList,
    enabled: !!id,
  });
}

export function useCancelFlowRun() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/flowruns/${id}:cancel`, { method: "POST" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.flowruns() });
      qc.invalidateQueries({ queryKey: qk.flowrun(id) });
    },
  });
}

export function useApproveNode() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ runId, nodeId }) =>
      apiFetch(`/flowruns/${runId}/nodes/${nodeId}:approve`, { method: "POST" }),
    onSuccess: (_, { runId }) => {
      qc.invalidateQueries({ queryKey: qk.flowruns() });
      qc.invalidateQueries({ queryKey: qk.flowrun(runId) });
      qc.invalidateQueries({ queryKey: qk.flowrunNodes(runId) });
    },
  });
}

export function useRejectNode() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ runId, nodeId }) =>
      apiFetch(`/flowruns/${runId}/nodes/${nodeId}:reject`, { method: "POST" }),
    onSuccess: (_, { runId }) => {
      qc.invalidateQueries({ queryKey: qk.flowruns() });
      qc.invalidateQueries({ queryKey: qk.flowrun(runId) });
    },
  });
}

export function useTriageFlowRun() {
  return useMutation({
    mutationFn: (id) => apiFetch(`/flowruns/${id}:triage`, { method: "POST" }),
  });
}
