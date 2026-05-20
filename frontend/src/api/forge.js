// Forge hooks — trinity (function / handler / workflow) read + mutate.
//
// trinity 锻造相关 hooks。

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiFetch, qk, pickList } from "./client.js";

// ── Function ─────────────────────────────────────────────────────────
export function useFunctions() {
  return useQuery({
    queryKey: qk.functions(),
    queryFn: () => apiFetch("/functions?limit=200"),
    select: pickList,
  });
}
export function useFunction(id) {
  return useQuery({
    queryKey: qk.function(id),
    queryFn: () => apiFetch(`/functions/${id}`),
    enabled: !!id,
  });
}
export function useFunctionVersions(id) {
  return useQuery({
    queryKey: qk.functionVersions(id),
    queryFn: () => apiFetch(`/functions/${id}/versions`),
    select: pickList,
    enabled: !!id,
  });
}
// Backend routes pending accept/reject under /{kind}s/{id}/pending:accept
// (not the {idAction} dispatch). Revert lives on the {idAction} switch.
//
// 后端 accept/reject 走 /{kind}s/{id}/pending:accept，与 :revert 路径不同。
export function useAcceptFunction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/functions/${id}/pending:accept`, { method: "POST" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.functions() });
      qc.invalidateQueries({ queryKey: qk.function(id) });
      qc.invalidateQueries({ queryKey: qk.functionVersions(id) });
    },
  });
}
export function useRejectFunction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/functions/${id}/pending:reject`, { method: "POST" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.functions() });
      qc.invalidateQueries({ queryKey: qk.function(id) });
      qc.invalidateQueries({ queryKey: qk.functionVersions(id) });
    },
  });
}
export function useRevertFunction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/functions/${id}:revert`, { method: "POST" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.functions() });
      qc.invalidateQueries({ queryKey: qk.function(id) });
    },
  });
}
export function useRunFunction() {
  return useMutation({
    mutationFn: ({ id, inputs }) =>
      apiFetch(`/functions/${id}:run`, { method: "POST", body: { inputs } }),
  });
}
export function useDeleteFunction() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/functions/${id}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.functions() }),
  });
}

// ── Handler ──────────────────────────────────────────────────────────
export function useHandlers() {
  return useQuery({
    queryKey: qk.handlers(),
    queryFn: () => apiFetch("/handlers?limit=200"),
    select: pickList,
  });
}
export function useHandler(id) {
  return useQuery({
    queryKey: qk.handler(id),
    queryFn: () => apiFetch(`/handlers/${id}`),
    enabled: !!id,
  });
}
export function useHandlerVersions(id) {
  return useQuery({
    queryKey: qk.handlerVersions(id),
    queryFn: () => apiFetch(`/handlers/${id}/versions`),
    select: pickList,
    enabled: !!id,
  });
}
export function useHandlerConfig(id) {
  return useQuery({
    queryKey: qk.handlerConfig(id),
    queryFn: () => apiFetch(`/handlers/${id}/config`),
    enabled: !!id,
  });
}
export function useAcceptHandler() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/handlers/${id}/pending:accept`, { method: "POST" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.handlers() });
      qc.invalidateQueries({ queryKey: qk.handler(id) });
      qc.invalidateQueries({ queryKey: qk.handlerVersions(id) });
    },
  });
}
export function useRejectHandler() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/handlers/${id}/pending:reject`, { method: "POST" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.handlers() });
      qc.invalidateQueries({ queryKey: qk.handler(id) });
      qc.invalidateQueries({ queryKey: qk.handlerVersions(id) });
    },
  });
}
export function useCallHandler() {
  return useMutation({
    mutationFn: ({ id, method, args }) =>
      apiFetch(`/handlers/${id}:call`, { method: "POST", body: { method, args } }),
  });
}
export function useDeleteHandler() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/handlers/${id}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.handlers() }),
  });
}

// ── Workflow ─────────────────────────────────────────────────────────
export function useWorkflows() {
  return useQuery({
    queryKey: qk.workflows(),
    queryFn: () => apiFetch("/workflows?limit=200"),
    select: pickList,
  });
}
export function useWorkflow(id) {
  return useQuery({
    queryKey: qk.workflow(id),
    queryFn: () => apiFetch(`/workflows/${id}`),
    enabled: !!id,
  });
}
export function useWorkflowVersions(id) {
  return useQuery({
    queryKey: qk.workflowVersions(id),
    queryFn: () => apiFetch(`/workflows/${id}/versions`),
    select: pickList,
    enabled: !!id,
  });
}
export function useAcceptWorkflow() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/workflows/${id}/pending:accept`, { method: "POST" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.workflows() });
      qc.invalidateQueries({ queryKey: qk.workflow(id) });
      qc.invalidateQueries({ queryKey: qk.workflowVersions(id) });
    },
  });
}
export function useRejectWorkflow() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/workflows/${id}/pending:reject`, { method: "POST" }),
    onSuccess: (_, id) => {
      qc.invalidateQueries({ queryKey: qk.workflows() });
      qc.invalidateQueries({ queryKey: qk.workflow(id) });
      qc.invalidateQueries({ queryKey: qk.workflowVersions(id) });
    },
  });
}
export function useDeleteWorkflow() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/workflows/${id}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.workflows() }),
  });
}
export function useUpdateWorkflow(id) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (patch) =>
      apiFetch(`/workflows/${id}`, { method: "PATCH", body: patch }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.workflow(id) });
      qc.invalidateQueries({ queryKey: qk.workflowVersions(id) });
    },
  });
}
// Manual workflow trigger (= scheduler StartRun with kind=manual).
// Backend: POST /workflows/{id}:trigger or :run (idAction switch).
export function useRunWorkflow() {
  return useMutation({
    mutationFn: ({ id, input }) =>
      apiFetch(`/workflows/${id}:trigger`, { method: "POST", body: { input: input || {} } }),
  });
}
// Apply edit ops (creates/iterates pending version). Used by WorkflowEditor
// autosave: diff vs original → ops array → POST :edit.
// 把 ops 应用到当前 workflow，产/迭代 pending；编辑器 autosave 用。
export function useEditWorkflow(id) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ ops, changeReason }) =>
      apiFetch(`/workflows/${id}:edit`, {
        method: "POST",
        body: { ops, changeReason: changeReason || "manual edit" },
      }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.workflow(id) });
      qc.invalidateQueries({ queryKey: qk.workflowVersions(id) });
    },
  });
}
// Capability check: POST /workflows/{id}:capability-check.
export function useCapabilityCheck() {
  return useMutation({
    mutationFn: (id) =>
      apiFetch(`/workflows/${id}:capability-check`, { method: "POST" }),
  });
}

// ── AskAI iterate (for FunctionDetail / HandlerDetail / WorkflowDetail) ──
export function useIterateForge() {
  return useMutation({
    mutationFn: ({ kind, id, prompt }) =>
      apiFetch(`/${kind}s/${id}:iterate`, { method: "POST", body: { prompt } }),
  });
}
