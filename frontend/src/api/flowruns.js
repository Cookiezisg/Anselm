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

// Backend: cancel = DELETE /flowruns/{id} (not POST :cancel).
// 后端 cancel 走 DELETE，不是 :cancel。
export function useCancelFlowRun() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/flowruns/${id}`, { method: "DELETE" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.flowruns() });
      qc.invalidateQueries({ queryKey: qk.flowrun(id) });
    },
  });
}

// Backend: POST /flowruns/{id}/approvals/{nodeId} with {decision, reason}.
// decision: "approve" / "reject".
// 后端是 /approvals/{nodeId}（不是 /nodes/{nodeId}:approve），body 带 decision。
export function useApproveNode() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ runId, nodeId, decision = "approve", reason = "" }) =>
      apiFetch(`/flowruns/${runId}/approvals/${nodeId}`, {
        method: "POST",
        body: { decision, reason },
      }),
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
    mutationFn: ({ runId, nodeId, reason = "" }) =>
      apiFetch(`/flowruns/${runId}/approvals/${nodeId}`, {
        method: "POST",
        body: { decision: "reject", reason },
      }),
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
