import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type {
  FlowRun,
  FlowRunNode,
  FlowRunsParams,
  ApproveNodeVars,
  RejectNodeVars,
} from "../model/types";

export function useFlowRuns(params: FlowRunsParams = {}) {
  const merged = { limit: "100", ...params } as Record<string, string>;
  const qs = new URLSearchParams(merged).toString();
  return useQuery<FlowRun[]>({
    queryKey: [...qk.flowruns(), params],
    queryFn: () => apiFetch(`/flowruns?${qs}`),
    select: pickList<FlowRun>,
  });
}

export function useFlowRun(id: string) {
  return useQuery<FlowRun>({
    queryKey: qk.flowrun(id),
    queryFn: () => apiFetch(`/flowruns/${id}`),
    enabled: !!id,
  });
}

export function useFlowRunNodes(id: string) {
  return useQuery<FlowRunNode[]>({
    queryKey: qk.flowrunNodes(id),
    queryFn: () => apiFetch(`/flowruns/${id}/nodes`),
    select: pickList<FlowRunNode>,
    enabled: !!id,
  });
}

// Backend: cancel = DELETE /flowruns/{id} (not POST :cancel).
// 后端 cancel 走 DELETE，不是 :cancel。
export function useCancelFlowRun() {
  const qc = useQueryClient();
  return useMutation<unknown, Error, string>({
    mutationFn: (id) => apiFetch(`/flowruns/${id}`, { method: "DELETE" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.flowruns() });
      qc.invalidateQueries({ queryKey: qk.flowrun(id) });
    },
  });
}

// Backend: POST /flowruns/{id}/approvals/{nodeId} with {decision, reason}.
// decision MUST be "approved" / "rejected" (backend canon; anything else → 400
// FLOWRUN_APPROVAL_DECISION_INVALID).
// 后端 /approvals/{nodeId}，body 带 decision（值必须是 approved/rejected，否则 400）。
export function useApproveNode() {
  const qc = useQueryClient();
  return useMutation<unknown, Error, ApproveNodeVars>({
    mutationFn: ({ runId, nodeId, decision = "approved", reason = "" }) =>
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
  return useMutation<unknown, Error, RejectNodeVars>({
    mutationFn: ({ runId, nodeId, reason = "" }) =>
      apiFetch(`/flowruns/${runId}/approvals/${nodeId}`, {
        method: "POST",
        body: { decision: "rejected", reason },
      }),
    onSuccess: (_, { runId }) => {
      qc.invalidateQueries({ queryKey: qk.flowruns() });
      qc.invalidateQueries({ queryKey: qk.flowrun(runId) });
    },
  });
}

export function useTriageFlowRun() {
  return useMutation<unknown, Error, string>({
    mutationFn: (id) => apiFetch(`/flowruns/${id}:triage`, { method: "POST" }),
  });
}
