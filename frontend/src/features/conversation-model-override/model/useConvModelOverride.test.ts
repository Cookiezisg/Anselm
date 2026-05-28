// useConvModelOverride — PATCH /conversations/:id with {modelOverride}.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { renderHook, act } from "@testing-library/react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { createElement } from "react";

const mockApiFetch = vi.fn();
const mockInvalidateQueries = vi.fn();

vi.mock("@shared/api", () => ({
  apiFetch: (path: string, opts: any) => mockApiFetch(path, opts),
  qk: {
    conversation: (id: string) => ["conv", id],
    conversations: () => ["conversations"],
  },
}));

vi.mock("@tanstack/react-query", async () => {
  const actual = await vi.importActual("@tanstack/react-query");
  return {
    ...(actual as object),
    useQueryClient: () => ({ invalidateQueries: mockInvalidateQueries }),
  };
});

import { useConvModelOverride } from "./useConvModelOverride";

function wrapper({ children }: { children: React.ReactNode }) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  return createElement(QueryClientProvider, { client }, children);
}

beforeEach(() => {
  vi.clearAllMocks();
  mockApiFetch.mockResolvedValue({ id: "cv_a" });
});

describe("useConvModelOverride", () => {
  it("setOverride_sendsPatchWithModelOverrideRef", async () => {
    const { result } = renderHook(() => useConvModelOverride(), { wrapper });
    await act(async () => {
      await result.current.mutateAsync({
        conversationId: "cv_a",
        override: { apiKeyId: "aki_1", modelId: "deepseek-chat" },
      });
    });
    expect(mockApiFetch).toHaveBeenCalledWith("/conversations/cv_a", {
      method: "PATCH",
      body: { modelOverride: { apiKeyId: "aki_1", modelId: "deepseek-chat" } },
    });
  });

  it("clearOverride_sendsPatchWithNull", async () => {
    const { result } = renderHook(() => useConvModelOverride(), { wrapper });
    await act(async () => {
      await result.current.mutateAsync({ conversationId: "cv_b", override: null });
    });
    expect(mockApiFetch).toHaveBeenCalledWith("/conversations/cv_b", {
      method: "PATCH",
      body: { modelOverride: null },
    });
  });

  it("success_invalidatesConversationQuery", async () => {
    const { result } = renderHook(() => useConvModelOverride(), { wrapper });
    await act(async () => {
      await result.current.mutateAsync({
        conversationId: "cv_c",
        override: { apiKeyId: "aki_x", modelId: "m_x" },
      });
    });
    expect(mockInvalidateQueries).toHaveBeenCalledWith({ queryKey: ["conv", "cv_c"] });
    expect(mockInvalidateQueries).toHaveBeenCalledWith({ queryKey: ["conversations"] });
  });
});
