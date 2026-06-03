import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type {
  Agent,
  AgentVersion,
  AgentExecution,
  AgentExecutionsResult,
  CreateAgentVars,
  UpdateAgentMetaVars,
  EditAgentVars,
  InvokeAgentVars,
  InvokeAgentResult,
} from "../model/types";

export function useAgents() {
  return useQuery<Agent[]>({
    queryKey: qk.agents(),
    queryFn: () => apiFetch("/agents?limit=200"),
    select: pickList<Agent>,
  });
}

export function useAgent(id: string) {
  return useQuery<Agent>({
    queryKey: qk.agent(id),
    queryFn: () => apiFetch(`/agents/${id}`),
    enabled: !!id,
  });
}

export function useAgentVersions(id: string) {
  return useQuery<AgentVersion[]>({
    queryKey: qk.agentVersions(id),
    queryFn: () => apiFetch(`/agents/${id}/versions`),
    select: pickList<AgentVersion>,
    enabled: !!id,
  });
}

// version is the integer ordinal or a versionId (agv_...).
export function useAgentVersion(id: string, version: number | string) {
  return useQuery<AgentVersion>({
    queryKey: [...qk.agentVersions(id), version] as const,
    queryFn: () => apiFetch(`/agents/${id}/versions/${version}`),
    enabled: !!id && version != null && version !== "",
  });
}

// Pending probe — 404 AGENT_NO_PENDING is surfaced as an ApiError; callers
// gate on isSuccess. retry:false so the 404 doesn't thrash.
export function useAgentPending(id: string) {
  return useQuery<AgentVersion>({
    queryKey: [...qk.agent(id), "pending"] as const,
    queryFn: () => apiFetch(`/agents/${id}/pending`),
    enabled: !!id,
    retry: false,
  });
}

// Executions list — backend wraps with { count, executions, aggregates }
// (not the standard §N4 { items } list), so we keep the raw envelope.
export function useAgentExecutions(id: string, status?: string) {
  const q = status ? `?status=${encodeURIComponent(status)}` : "";
  return useQuery<AgentExecutionsResult>({
    queryKey: [...qk.agentExecutions(id), status ?? "all"] as const,
    queryFn: () => apiFetch(`/agents/${id}/executions${q}`),
    enabled: !!id,
  });
}

export function useAgentExecution(execId: string) {
  return useQuery<AgentExecution>({
    queryKey: ["agent-execution", execId] as const,
    queryFn: () => apiFetch(`/agent-executions/${execId}`),
    enabled: !!execId,
  });
}

export function useCreateAgent() {
  const qc = useQueryClient();
  return useMutation<Agent, Error, CreateAgentVars>({
    mutationFn: (body) => apiFetch("/agents", { method: "POST", body }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.agents() }),
  });
}

export function useUpdateAgentMeta(id: string) {
  const qc = useQueryClient();
  return useMutation<Agent, Error, UpdateAgentMetaVars>({
    mutationFn: (patch) => apiFetch(`/agents/${id}`, { method: "PATCH", body: patch }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.agents() });
      qc.invalidateQueries({ queryKey: qk.agent(id) });
    },
  });
}

// Apply an edit → produces/iterates a pending AgentVersion (status=pending).
export function useEditAgent(id: string) {
  const qc = useQueryClient();
  return useMutation<AgentVersion, Error, EditAgentVars>({
    mutationFn: (body) => apiFetch(`/agents/${id}:edit`, { method: "POST", body }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.agent(id) });
      qc.invalidateQueries({ queryKey: qk.agentVersions(id) });
    },
  });
}

// Synchronous invoke — runs the agent loop, returns a terminal execution.
export function useInvokeAgent() {
  const qc = useQueryClient();
  return useMutation<InvokeAgentResult, Error, InvokeAgentVars>({
    mutationFn: ({ id, version, input }) =>
      apiFetch(`/agents/${id}:invoke`, {
        method: "POST",
        body: { ...(version != null ? { version } : {}), input: input || {} },
      }),
    onSuccess: (_, { id }) => qc.invalidateQueries({ queryKey: qk.agentExecutions(id) }),
  });
}

// Backend accept/reject under /agents/{id}/pending:accept (not the {idAction}
// dispatch). Revert lives on the {idAction} switch and needs a targetVersion.
//
// 后端 accept/reject 走 /agents/{id}/pending:accept，与 :revert 路径不同。
export function useAcceptAgent() {
  const qc = useQueryClient();
  return useMutation<{ versionId: string; accepted: boolean }, Error, string>({
    mutationFn: (id) => apiFetch(`/agents/${id}/pending:accept`, { method: "POST" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.agents() });
      qc.invalidateQueries({ queryKey: qk.agent(id) });
      qc.invalidateQueries({ queryKey: qk.agentVersions(id) });
    },
  });
}

export function useRejectAgent() {
  const qc = useQueryClient();
  return useMutation<{ rejected: boolean }, Error, string>({
    mutationFn: (id) => apiFetch(`/agents/${id}/pending:reject`, { method: "POST" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.agents() });
      qc.invalidateQueries({ queryKey: qk.agent(id) });
      qc.invalidateQueries({ queryKey: qk.agentVersions(id) });
    },
  });
}

// Revert active pointer to a prior accepted version (creates a new version).
export function useRevertAgent(id: string) {
  const qc = useQueryClient();
  return useMutation<AgentVersion, Error, number>({
    mutationFn: (targetVersion) =>
      apiFetch(`/agents/${id}:revert`, { method: "POST", body: { targetVersion } }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.agents() });
      qc.invalidateQueries({ queryKey: qk.agent(id) });
      qc.invalidateQueries({ queryKey: qk.agentVersions(id) });
    },
  });
}

// Iterate — opens an AI editing conversation, returns { conversationId }.
export function useIterateAgent() {
  return useMutation<{ conversationId: string }, Error, { id: string; prompt: string }>({
    mutationFn: ({ id, prompt }) =>
      apiFetch(`/agents/${id}:iterate`, { method: "POST", body: { prompt } }),
  });
}

export function useDeleteAgent() {
  const qc = useQueryClient();
  return useMutation<null, Error, string>({
    mutationFn: (id) => apiFetch(`/agents/${id}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.agents() }),
  });
}
