// Library hooks — skills / mcp servers / memory / documents.
//
// 资源库 hooks。

import { useQuery } from "@tanstack/react-query";
import { apiFetch, qk, pickList } from "./client.js";

// ── Skills ───────────────────────────────────────────────────────────
export { useSkills, useSkill } from "@entities/skill";

// ── MCP ──────────────────────────────────────────────────────────────
export { useMcpServers, useReconnectMcp, useRemoveMcp } from "@entities/mcp";

// ── Memory ───────────────────────────────────────────────────────────
export {
  useMemories,
  useMemory,
  useCreateMemory,
  useUpdateMemory,
  useDeleteMemory,
  usePinMemory,
} from "@entities/memory";

// ── Documents ────────────────────────────────────────────────────────
export {
  useDocumentTree,
  useDocuments,
  useDocument,
  useCreateDocument,
  useUpdateDocument,
  useDeleteDocument,
  useMoveDocument,
} from "@entities/document";

// ── Relations (EntityRelMeta) ────────────────────────────────────────
export function useRelations(entityId, limit = 5) {
  return useQuery({
    queryKey: qk.relations(entityId),
    queryFn: () => apiFetch(`/relations?entityId=${encodeURIComponent(entityId)}&limit=${limit}`),
    select: pickList,
    enabled: !!entityId,
  });
}
