// Test harness for TanStack Query hooks. Each test renders a hook
// inside a fresh QueryClientProvider and a mocked apiFetch so the
// real network never fires.

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { renderHook, waitFor } from "@testing-library/react";
import { vi, expect } from "vitest";
import { createElement } from "react";

export interface FetchCall {
  url: string;
  method: string;
  body: string;
  headers: HeadersInit | undefined;
}

export function makeClient(): QueryClient {
  return new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0, staleTime: 0 },
      mutations: { retry: false },
    },
  });
}

export function wrap(client: QueryClient) {
  return ({ children }: { children: React.ReactNode }) =>
    createElement(QueryClientProvider, { client }, children);
}

export async function mockFetchOnce(
  json: unknown,
  { status = 200, ok = true } = {},
): Promise<void> {
  // Cast needed: mock doesn't fully satisfy the overloaded fetch signature.
  globalThis.fetch = vi.fn().mockResolvedValueOnce({
    ok,
    status,
    json: async () => json,
  }) as unknown as typeof fetch;
}

export async function renderQuery<T>(hookFn: () => T): Promise<{
  result: { current: T };
  client: QueryClient;
}> {
  const client = makeClient();
  const { result } = renderHook(hookFn, { wrapper: wrap(client) });
  await waitFor(() =>
    expect(
      (result.current as { isSuccess?: boolean; isError?: boolean }).isSuccess ||
        (result.current as { isSuccess?: boolean; isError?: boolean }).isError,
    ).toBe(true),
  );
  return { result, client };
}

export async function renderMutation<T>(hookFn: () => T): Promise<{
  result: { current: T };
  client: QueryClient;
}> {
  const client = makeClient();
  const { result } = renderHook(hookFn, { wrapper: wrap(client) });
  return { result, client };
}

// Captures the calls fetch was invoked with so tests can verify URL
// + method + body without coupling to apiFetch internals.
export function setupFetchSpy(): FetchCall[] {
  const calls: FetchCall[] = [];
  // Cast needed: vi.fn mock doesn't fully satisfy the overloaded fetch signature.
  globalThis.fetch = vi.fn(async (url: string | URL, init: RequestInit = {}) => {
    calls.push({
      url: typeof url === "string" ? url : url.toString(),
      method: (init.method as string) || "GET",
      body: (init.body as string) ?? "",
      headers: init.headers,
    });
    return { ok: true, status: 200, json: async () => ({ data: {} }) };
  }) as unknown as typeof fetch;
  return calls;
}
