import { describe, it, expect, vi, beforeEach } from "vitest";
import { renderHook } from "@testing-library/react";
import { useContextStrip } from "./useContextStrip.js";

vi.mock("@entities/flowrun", () => ({
  useFlowRuns: vi.fn(),
}));
vi.mock("@entities/conversation", () => ({
  useConversations: vi.fn(),
}));

import type { FlowRun } from "@entities/flowrun";
import type { Conversation } from "@entities/conversation";
import { useFlowRuns } from "@entities/flowrun";
import { useConversations } from "@entities/conversation";

const mockUseFlowRuns = vi.mocked(useFlowRuns);
const mockUseConversations = vi.mocked(useConversations);

// Helpers to build partial test fixtures — the hook only accesses a few
// fields from FlowRun/Conversation; cast to full type for mocking.
function mockFlowRuns(data: Partial<FlowRun>[]): void {
  mockUseFlowRuns.mockReturnValue({
    data: data as FlowRun[],
  } as ReturnType<typeof useFlowRuns>);
}
function mockConversations(data: Partial<Conversation>[]): void {
  mockUseConversations.mockReturnValue({
    data: data as Conversation[],
  } as ReturnType<typeof useConversations>);
}

beforeEach(() => {
  vi.useFakeTimers();
  vi.setSystemTime(new Date("2026-05-25T12:00:00"));
});

describe("useContextStrip", () => {
  it("returns null when there's nothing of interest", () => {
    mockFlowRuns([]);
    mockConversations([]);
    const { result } = renderHook(() => useContextStrip());
    expect(result.current).toBeNull();
  });

  it("P1 waiting wins over P2/P3/P4", () => {
    mockFlowRuns([
      // waiting_approval is a known extension beyond the closed FlowRunStatus enum.
      { id: "fr_1", status: "waiting_approval" as FlowRun["status"], workflowId: "data-pipeline", startedAt: "2026-05-25T11:00:00Z" },
      { id: "fr_2", status: "failed", workflowId: "etl", startedAt: "2026-05-25T10:00:00Z" },
      { id: "fr_3", status: "running", workflowId: "build", startedAt: "2026-05-25T11:30:00Z" },
    ]);
    mockConversations([
      { id: "cv_a", title: "RAG 数据准备", updatedAt: "2026-05-25T11:55:00Z" },
    ]);
    const { result } = renderHook(() => useContextStrip());
    expect(result.current!.kind).toBe("waiting");
    expect(result.current!.payload.count).toBe(1);
    // hook falls back to workflowId when workflow field absent.
    expect(result.current!.payload.flowName).toBe("data-pipeline");
  });

  it("P2 failed wins over P3/P4 when no waiting", () => {
    mockFlowRuns([{ id: "fr_x", status: "failed", workflowId: "etl" }]);
    mockConversations([{ id: "cv_a", title: "x", updatedAt: "2026-05-25T11:00:00Z" }]);
    const { result } = renderHook(() => useContextStrip());
    expect(result.current!.kind).toBe("failed");
    expect(result.current!.payload.count).toBe(1);
  });

  it("P3 running wins over P4 recent", () => {
    mockFlowRuns([{ id: "fr_x", status: "running", workflowId: "build", startedAt: "2026-05-25T11:30:00Z" }]);
    mockConversations([{ id: "cv_a", title: "x", updatedAt: "2026-05-25T11:00:00Z" }]);
    const { result } = renderHook(() => useContextStrip());
    expect(result.current!.kind).toBe("running");
    expect(result.current!.payload.count).toBe(1);
    expect(result.current!.payload.latestStartedAt).toBe("2026-05-25T11:30:00Z");
  });

  it("P4 recent: shows newest conv within 24h", () => {
    mockFlowRuns([]);
    mockConversations([
      { id: "cv_old", title: "stale", updatedAt: "2026-05-20T00:00:00Z" },
      { id: "cv_new", title: "RAG", updatedAt: "2026-05-25T11:00:00Z" },
    ]);
    const { result } = renderHook(() => useContextStrip());
    expect(result.current!.kind).toBe("recent");
    expect(result.current!.payload.convId).toBe("cv_new");
    expect(result.current!.payload.convTitle).toBe("RAG");
  });

  it("P4 ignores convs older than 24h", () => {
    mockFlowRuns([]);
    mockConversations([{ id: "cv_old", title: "stale", updatedAt: "2026-05-20T00:00:00Z" }]);
    const { result } = renderHook(() => useContextStrip());
    expect(result.current).toBeNull();
  });
});
