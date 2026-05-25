// Library hooks — skills / mcp servers / memory / documents.
//
// 资源库 hooks。

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, qk, pickList } from "./client.js";
import { useSettings } from "../store/settings.js";

// ── Skills ───────────────────────────────────────────────────────────
export function useSkills() {
  return useQuery({
    queryKey: qk.skills(),
    queryFn: () => apiFetch("/skills?limit=200"),
    select: pickList,
  });
}
export function useSkill(id) {
  return useQuery({
    queryKey: qk.skill(id),
    queryFn: () => apiFetch(`/skills/${id}`),
    enabled: !!id,
  });
}

// ── MCP ──────────────────────────────────────────────────────────────
export function useMcpServers() {
  return useQuery({
    queryKey: qk.mcpServers(),
    queryFn: () => apiFetch("/mcp-servers?limit=100"),
    select: pickList,
  });
}
export function useReconnectMcp() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/mcp-servers/${id}:reconnect`, { method: "POST" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.mcpServers() }),
  });
}
export function useRemoveMcp() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/mcp-servers/${id}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.mcpServers() }),
  });
}

// ── Memory ───────────────────────────────────────────────────────────
export function useMemories(type) {
  const qs = type ? `?type=${type}` : "";
  return useQuery({
    queryKey: qk.memories(type),
    queryFn: () => apiFetch("/memories" + qs),
    select: pickList,
  });
}
export function useMemory(name) {
  return useQuery({
    queryKey: qk.memory(name),
    queryFn: () => apiFetch(`/memories/${encodeURIComponent(name)}`),
    enabled: !!name,
  });
}
// Backend: PATCH /memories/{name} (not PUT).
export function useUpdateMemory() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ name, body }) =>
      apiFetch(`/memories/${encodeURIComponent(name)}`, { method: "PATCH", body }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["memories"] }),
  });
}
export function useCreateMemory() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body) => apiFetch("/memories", { method: "POST", body }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["memories"] }),
  });
}
export function useDeleteMemory() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (name) =>
      apiFetch(`/memories/${encodeURIComponent(name)}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["memories"] }),
  });
}
// Pin/unpin via PATCH with pinned bool. Backend Update accepts the field.
export function usePinMemory() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ name, pinned }) =>
      apiFetch(`/memories/${encodeURIComponent(name)}`, {
        method: "PATCH", body: { pinned },
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["memories"] }),
  });
}

// ── Documents ────────────────────────────────────────────────────────
// Notion-style tree: useDocumentTree = flat metadata list (root + every
// descendant; no content). Sidebar consumes once and renders the tree.
export function useDocumentTree() {
  return useQuery({
    queryKey: ["documents", "tree"],
    queryFn: () => apiFetch("/documents/tree"),
  });
}
export function useDocuments() {
  const uid = useSettings((s) => s.activeUserId);
  return useQuery({
    queryKey: qk.documents(),
    queryFn: () => apiFetch("/documents?limit=200"),
    select: pickList,
    enabled: !!uid,
  });
}
export function useDocument(id) {
  return useQuery({
    queryKey: qk.document(id),
    queryFn: () => apiFetch(`/documents/${id}`),
    enabled: !!id,
  });
}
export function useCreateDocument() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (body) => apiFetch("/documents", { method: "POST", body }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.documents() });
      qc.invalidateQueries({ queryKey: ["documents", "tree"] });
    },
  });
}
export function useUpdateDocument(id) {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (patch) => apiFetch(`/documents/${id}`, { method: "PATCH", body: patch }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.document(id) });
      qc.invalidateQueries({ queryKey: ["documents", "tree"] });
    },
  });
}
export function useDeleteDocument() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id) => apiFetch(`/documents/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.documents() });
      qc.invalidateQueries({ queryKey: ["documents", "tree"] });
    },
  });
}
export function useMoveDocument() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ id, parentId, position }) =>
      apiFetch(`/documents/${id}:move`, {
        method: "POST",
        body: { parentId: parentId || null, position },
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["documents", "tree"] }),
  });
}

// ── Relations (EntityRelMeta) ────────────────────────────────────────
export function useRelations(entityId, limit = 5) {
  return useQuery({
    queryKey: qk.relations(entityId),
    queryFn: () => apiFetch(`/relations?entityId=${encodeURIComponent(entityId)}&limit=${limit}`),
    select: pickList,
    enabled: !!entityId,
  });
}
