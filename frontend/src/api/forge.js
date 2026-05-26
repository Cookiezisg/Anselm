// Forge hooks — trinity (function / handler / workflow) read + mutate.
//
// trinity 锻造相关 hooks。

import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { apiFetch, qk, pickList } from "./client.js";
import { useSettings } from "../store/settings.js";

// Function hooks — implementation lives in @entities/function (FSD 阶段2迁移).
export {
  useFunctions,
  useFunction,
  useFunctionVersions,
  useAcceptFunction,
  useRejectFunction,
  useRevertFunction,
  useRunFunction,
  useDeleteFunction,
} from "@entities/function";

// Handler hooks — implementation lives in @entities/handler (FSD 阶段2迁移).
export {
  useHandlers,
  useHandler,
  useHandlerVersions,
  useHandlerConfig,
  useAcceptHandler,
  useRejectHandler,
  useCallHandler,
  useDeleteHandler,
} from "@entities/handler";

// ── Workflow ─────────────────────────────────────────────────────────
export function useWorkflows() {
  const uid = useSettings((s) => s.activeUserId);
  return useQuery({
    queryKey: qk.workflows(),
    queryFn: () => apiFetch("/workflows?limit=200"),
    select: pickList,
    enabled: !!uid,
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
