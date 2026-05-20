// Relations hooks — full list + neighborhood graph queries.
//
// Relations hooks。

import { useQuery } from "@tanstack/react-query";
import { apiFetch, pickList } from "./client.js";

export function useAllRelations() {
  return useQuery({
    queryKey: ["relations", "all"],
    queryFn: () => apiFetch("/relations?limit=1000"),
    select: pickList,
  });
}

// fromKind/toKind/kind optional filter.
export function useRelationFilter(filter = {}) {
  const qs = new URLSearchParams(filter).toString();
  return useQuery({
    queryKey: ["relations", "filter", filter],
    queryFn: () => apiFetch(`/relations${qs ? "?" + qs : ""}`),
    select: pickList,
  });
}

// Neighborhood: { kind, id, depth } → graph nodes+edges within depth.
export function useNeighborhood({ kind, id, depth = 1 }) {
  return useQuery({
    queryKey: ["relations", "neighborhood", kind, id, depth],
    queryFn: () =>
      apiFetch(`/relations/neighborhood?kind=${encodeURIComponent(kind)}&id=${encodeURIComponent(id)}&depth=${depth}`),
    enabled: !!(kind && id),
  });
}
