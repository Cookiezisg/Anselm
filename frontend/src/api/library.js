// Library hooks — skills / mcp servers / memory / documents.
//
// 资源库 hooks。

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, qk } from "./client.js";

// ── Skills ───────────────────────────────────────────────────────────
export function useSkills() {
  return useQuery({
    queryKey: qk.skills(),
    queryFn: () => apiFetch("/skills?limit=200"),
    select: (d) => (Array.isArray(d) ? d : d?.items || []),
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
    select: (d) => (Array.isArray(d) ? d : d?.items || []),
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
    select: (d) => (Array.isArray(d) ? d : d?.items || []),
  });
}
export function useMemory(name) {
  return useQuery({
    queryKey: qk.memory(name),
    queryFn: () => apiFetch(`/memories/${encodeURIComponent(name)}`),
    enabled: !!name,
  });
}
export function useUpdateMemory() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ name, body }) =>
      apiFetch(`/memories/${encodeURIComponent(name)}`, { method: "PUT", body }),
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
export function usePinMemory() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({ name, pinned }) =>
      apiFetch(`/memories/${encodeURIComponent(name)}:pin`, { method: "PATCH", body: { pinned } }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["memories"] }),
  });
}

// ── Documents ────────────────────────────────────────────────────────
export function useDocuments() {
  return useQuery({
    queryKey: qk.documents(),
    queryFn: () => apiFetch("/documents?limit=200"),
    select: (d) => (Array.isArray(d) ? d : d?.items || []),
  });
}
export function useDocument(id) {
  return useQuery({
    queryKey: qk.document(id),
    queryFn: () => apiFetch(`/documents/${id}`),
    enabled: !!id,
  });
}

// ── Relations (EntityRelMeta) ────────────────────────────────────────
export function useRelations(entityId, limit = 5) {
  return useQuery({
    queryKey: qk.relations(entityId),
    queryFn: () => apiFetch(`/relations?entityId=${encodeURIComponent(entityId)}&limit=${limit}`),
    select: (d) => (Array.isArray(d) ? d : d?.items || []),
    enabled: !!entityId,
  });
}
