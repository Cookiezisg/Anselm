import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type {
  FlowRun,
  FlowRunNode,
  FlowRunsParams,
  ApproveNodeVars,
  RejectNodeVars,
  Approval,
  FailureRecord,
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

// Backend: GET /approvals → the caller's currently-parked approvals (17 §9 inbox).
// The journal is execution truth; this projection tells the banner WHICH node is
// parked. Banner filters the list by runId. Invalidated on every approve/reject.
//
// 后端 /approvals 返回当前用户所有 parked approval(inbox 投影);banner 按 runId 过滤。
export function useApprovalInbox() {
  return useQuery<Approval[]>({
    queryKey: qk.approvals(),
    queryFn: () => apiFetch("/approvals"),
    select: pickList<Approval>,
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
      qc.invalidateQueries({ queryKey: qk.approvals() });
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
      qc.invalidateQueries({ queryKey: qk.approvals() });
    },
  });
}

export function useTriageFlowRun() {
  return useMutation<unknown, Error, string>({
    mutationFn: (id) => apiFetch(`/flowruns/${id}:triage`, { method: "POST" }),
  });
}

// useReplayFlowRun — POST /flowruns/{id}:replay re-runs a failed flowrun at a new generation
// (generation++; ADR-019). Returns 202 {runId, resumed:true}. 422 FLOWRUN_NOT_REPLAYABLE if not failed.
//
// useReplayFlowRun — 重跑失败 run;202 返 {runId, resumed:true}。
export function useReplayFlowRun() {
  const qc = useQueryClient();
  return useMutation<unknown, Error, string>({
    mutationFn: (id) => apiFetch(`/flowruns/${id}:replay`, { method: "POST" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.flowruns() });
      qc.invalidateQueries({ queryKey: qk.flowrun(id) });
    },
  });
}

// useFlowRunFailures — GET /flowruns/{id}/failures returns node_failed events (highest-generation
// wins; a step re-run successfully no longer appears, ADR-019 §M6).
//
// useFlowRunFailures — 节点失败列表;最高代胜出,重跑成功的步不再显示。
export function useFlowRunFailures(runId: string) {
  return useQuery<FailureRecord[]>({
    queryKey: [...qk.flowrun(runId), "failures"],
    queryFn: () => apiFetch(`/flowruns/${runId}/failures`),
    select: pickList<FailureRecord>,
    enabled: !!runId,
  });
}

// useFlowRunTrace — GET /flowruns/{id}/trace?nodeId=X projects the flowrun journal (durable truth)
// for the orchestration UI's per-node inline diagnostic (08 §6). nodeId="" returns the whole run;
// nodeId set filters to one node (loop iterations stay distinguishable via iterationKey).
// Read-only — never touches the running engine. Reconnect full-pull (CANON-X4).
//
// useFlowRunTrace 读 flowrun journal 投影(08 §6 trace API);nodeId 过滤单节点；loop 多轮按 iterationKey 区分。
// TraceEntry shape (mirrors backend schedulerapp.TraceEntry JSON).
export interface TraceEntry {
  seq: number;
  type: string;
  nodeId: string;
  iterationKey: number;
  generation: number;
  turn?: number;
  toolCallId?: string;  // present for agent_step_started/completed events (ADR-010)
  result?: Record<string, unknown>;
  at: string;
}

export function useFlowRunTrace(runId: string, nodeId?: string) {
  const qs = nodeId ? `?nodeId=${encodeURIComponent(nodeId)}` : "";
  return useQuery<TraceEntry[]>({
    queryKey: [...qk.flowrun(runId), "trace", nodeId ?? ""],
    queryFn: () => apiFetch(`/flowruns/${runId}/trace${qs}`),
    select: pickList<TraceEntry>,
    enabled: !!runId,
    // Stale after 10s — read-only journal projection; re-fetch on focus to stay fresh.
    staleTime: 10_000,
  });
}
