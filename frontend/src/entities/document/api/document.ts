import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
// eslint-disable-next-line boundaries/dependencies
import { useSettings } from "../../../store/settings.js"; // TODO(阶段4): identity store 接管 activeUserId 后移除
import type {
  Document,
  DocTreeNode,
  CreateDocumentBody,
  UpdateDocumentPatch,
  MoveDocumentVars,
} from "../model/types";

export function useDocumentTree() {
  return useQuery<DocTreeNode[]>({
    queryKey: ["documents", "tree"],
    queryFn: () => apiFetch("/documents/tree"),
  });
}

export function useDocuments() {
  const uid = useSettings((s) => s.activeUserId);
  return useQuery<Document[]>({
    queryKey: qk.documents(),
    queryFn: () => apiFetch("/documents?limit=200"),
    select: pickList<Document>,
    enabled: !!uid,
  });
}

export function useDocument(id: string) {
  return useQuery<Document>({
    queryKey: qk.document(id),
    queryFn: () => apiFetch(`/documents/${id}`),
    enabled: !!id,
  });
}

export function useCreateDocument() {
  const qc = useQueryClient();
  return useMutation<Document, Error, CreateDocumentBody>({
    mutationFn: (body) => apiFetch("/documents", { method: "POST", body }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.documents() });
      qc.invalidateQueries({ queryKey: ["documents", "tree"] });
    },
  });
}

export function useUpdateDocument(id: string) {
  const qc = useQueryClient();
  return useMutation<Document, Error, UpdateDocumentPatch>({
    mutationFn: (patch) => apiFetch(`/documents/${id}`, { method: "PATCH", body: patch }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.document(id) });
      qc.invalidateQueries({ queryKey: ["documents", "tree"] });
    },
  });
}

export function useDeleteDocument() {
  const qc = useQueryClient();
  return useMutation<null, Error, string>({
    mutationFn: (id) => apiFetch(`/documents/${id}`, { method: "DELETE" }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: qk.documents() });
      qc.invalidateQueries({ queryKey: ["documents", "tree"] });
    },
  });
}

export function useMoveDocument() {
  const qc = useQueryClient();
  return useMutation<Document, Error, MoveDocumentVars>({
    mutationFn: ({ id, parentId, position }) =>
      apiFetch(`/documents/${id}:move`, {
        method: "POST",
        body: { parentId: parentId || null, position },
      }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ["documents", "tree"] }),
  });
}
