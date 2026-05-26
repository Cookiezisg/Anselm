import { useQuery } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type { Skill } from "../model/types";

export function useSkills() {
  return useQuery<Skill[]>({
    queryKey: qk.skills(),
    queryFn: () => apiFetch("/skills?limit=200"),
    select: pickList<Skill>,
  });
}

export function useSkill(id: string) {
  return useQuery<Skill>({
    queryKey: qk.skill(id),
    queryFn: () => apiFetch(`/skills/${id}`),
    enabled: !!id,
  });
}
