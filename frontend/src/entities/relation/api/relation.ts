import { useQuery } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type { Relation, RelationFilter, NeighborhoodVars } from "../model/types";

export function useAllRelations() {
  return useQuery<Relation[]>({
    queryKey: ["relations", "all"],
    queryFn: () => apiFetch("/relations?limit=1000"),
    select: pickList<Relation>,
  });
}

export function useRelationFilter(filter: RelationFilter = {}) {
  const qs = new URLSearchParams(filter as Record<string, string>).toString();
  return useQuery<Relation[]>({
    queryKey: ["relations", "filter", filter],
    queryFn: () => apiFetch(`/relations${qs ? "?" + qs : ""}`),
    select: pickList<Relation>,
  });
}

export function useNeighborhood({ kind, id, depth = 1 }: NeighborhoodVars) {
  return useQuery<Relation[]>({
    queryKey: ["relations", "neighborhood", kind, id, depth],
    queryFn: () =>
      apiFetch(`/relations/neighborhood?kind=${encodeURIComponent(kind)}&id=${encodeURIComponent(id)}&depth=${depth}`),
    enabled: !!(kind && id),
  });
}

export function useRelations(entityId: string, limit = 5) {
  return useQuery<Relation[]>({
    queryKey: qk.relations(entityId),
    queryFn: () => apiFetch(`/relations?entityId=${encodeURIComponent(entityId)}&limit=${limit}`),
    select: pickList<Relation>,
    enabled: !!entityId,
  });
}
