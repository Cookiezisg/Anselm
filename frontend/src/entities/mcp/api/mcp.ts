import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { apiFetch, pickList, qk } from "@shared/api";
import type { McpServer, ReconnectMcpResult } from "../model/types";

export function useMcpServers() {
  return useQuery<McpServer[]>({
    queryKey: qk.mcpServers(),
    queryFn: () => apiFetch("/mcp-servers?limit=100"),
    select: pickList<McpServer>,
  });
}

export function useReconnectMcp() {
  const qc = useQueryClient();
  return useMutation<ReconnectMcpResult, Error, string>({
    mutationFn: (id) => apiFetch(`/mcp-servers/${id}:reconnect`, { method: "POST" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.mcpServers() }),
  });
}

export function useRemoveMcp() {
  const qc = useQueryClient();
  return useMutation<null, Error, string>({
    mutationFn: (id) => apiFetch(`/mcp-servers/${id}`, { method: "DELETE" }),
    onSuccess: () => qc.invalidateQueries({ queryKey: qk.mcpServers() }),
  });
}
