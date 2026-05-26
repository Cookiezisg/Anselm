import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type { User, CreateUserBody, UpdateUserPatch } from "../model/types";

export function useUsers() {
  return useQuery<User[]>({
    queryKey: qk.users(),
    queryFn: () => apiFetch("/users"),
    select: pickList<User>,
  });
}

export function useCreateUser() {
  const qc = useQueryClient();
  return useMutation<User, Error, CreateUserBody>({
    mutationFn: (body) => apiFetch("/users", { method: "POST", body }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.users() }),
  });
}

export function useUpdateUser() {
  const qc = useQueryClient();
  return useMutation<User, Error, { id: string; patch: UpdateUserPatch }>({
    mutationFn: ({ id, patch }) =>
      apiFetch(`/users/${id}`, { method: "PATCH", body: patch }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.users() }),
  });
}

export function useDeleteUser() {
  const qc = useQueryClient();
  return useMutation<null, Error, string>({
    mutationFn: (id) => apiFetch(`/users/${id}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.users() }),
  });
}
