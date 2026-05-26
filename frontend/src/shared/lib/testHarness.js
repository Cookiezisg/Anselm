// Test harness for TanStack Query hooks. Each test renders a hook
// inside a fresh QueryClientProvider and a mocked apiFetch so the
// real network never fires.

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { renderHook, waitFor } from "@testing-library/react";
import { vi } from "vitest";
import { createElement } from "react";

export function makeClient() {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0, staleTime: 0 },
      mutations: { retry: false },
    },
  });
}

export function wrap(client) {
  return ({ children }) => createElement(QueryClientProvider, { client }, children);
}

export async function mockFetchOnce(json, { status = 200, ok = true } = {}) {
  globalThis.fetch = vi.fn().mockResolvedValueOnce({
    ok, status,
    json: async () => json,
  });
}

export async function renderQuery(hookFn) {
  const client = makeClient();
  const { result } = renderHook(hookFn, { wrapper: wrap(client) });
  await waitFor(() => expect(result.current.isSuccess || result.current.isError).toBe(true));
  return { result, client };
}

export async function renderMutation(hookFn) {
  const client = makeClient();
  const { result } = renderHook(hookFn, { wrapper: wrap(client) });
  return { result, client };
}

// Captures the calls fetch was invoked with so tests can verify URL
// + method + body without coupling to apiFetch internals.
export function setupFetchSpy() {
  const calls = [];
  globalThis.fetch = vi.fn(async (url, init = {}) => {
    calls.push({
      url: typeof url === "string" ? url : url.toString(),
      method: init.method || "GET",
      body: init.body,
      headers: init.headers,
    });
    return { ok: true, status: 200, json: async () => ({ data: {} }) };
  });
  return calls;
}
