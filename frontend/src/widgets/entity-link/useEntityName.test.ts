// useEntityName — prefix-based dispatch to the right list query.
// We mock the entity hooks so test data is deterministic without HTTP.

import { describe, expect, it, vi } from "vitest";
import { renderHook } from "@testing-library/react";

vi.mock("@entities/function", () => ({
  useFunctions:    () => ({ data: [{ id: "fn_1", name: "func one" }, { id: "fn_2", name: "func two" }] }),
}));
vi.mock("@entities/handler", () => ({
  useHandlers:     () => ({ data: [{ id: "hd_1", name: "handler one" }] }),
}));
vi.mock("@entities/workflow", () => ({
  useWorkflows:    () => ({ data: [{ id: "wf_1", name: "workflow one" }] }),
}));
vi.mock("@entities/agent", () => ({
  useAgents:       () => ({ data: [{ id: "ag_1", name: "agent one" }] }),
}));
vi.mock("@entities/document", () => ({
  useDocuments:    () => ({ data: [{ id: "doc_1", name: "doc one", title: "fallback title" }, { id: "doc_2", title: "title only" }] }),
}));
vi.mock("@entities/skill", () => ({
  useSkills:       () => ({ data: [{ id: "sk_1", name: "skill one" }] }),
}));
vi.mock("@entities/mcp", () => ({
  useMcpServers:   () => ({ data: [{ id: "mcp_1", name: "mcp one" }] }),
}));
vi.mock("@entities/conversation", () => ({
  useConversations: () => ({ data: [{ id: "cv_1", title: "conv one" }] }),
}));
vi.mock("@entities/flowrun", () => ({
  useFlowRuns:      () => ({ data: [{ id: "fr_1", workflow: "wf one" }, { id: "fr_2", workflowId: "wf_2" }] }),
}));

import { useEntityName } from "./useEntityName";

describe("useEntityName", () => {
  it("useEntityName_nullId_returnsNull", () => {
    const { result } = renderHook(() => useEntityName(null));
    expect(result.current).toBeNull();
  });

  it("useEntityName_emptyString_returnsNull", () => {
    const { result } = renderHook(() => useEntityName(""));
    expect(result.current).toBeNull();
  });

  it("useEntityName_functionPrefix_resolvesName", () => {
    const { result } = renderHook(() => useEntityName("fn_1"));
    expect(result.current).toBe("func one");
  });

  it("useEntityName_handlerPrefix_resolvesName", () => {
    const { result } = renderHook(() => useEntityName("hd_1"));
    expect(result.current).toBe("handler one");
  });

  it("useEntityName_workflowPrefix_resolvesName", () => {
    const { result } = renderHook(() => useEntityName("wf_1"));
    expect(result.current).toBe("workflow one");
  });

  it("useEntityName_agentPrefix_resolvesName", () => {
    const { result } = renderHook(() => useEntityName("ag_1"));
    expect(result.current).toBe("agent one");
  });

  it("useEntityName_docPrefix_preferName", () => {
    const { result } = renderHook(() => useEntityName("doc_1"));
    expect(result.current).toBe("doc one");
  });

  it("useEntityName_docPrefix_fallbackToTitleWhenNameMissing", () => {
    const { result } = renderHook(() => useEntityName("doc_2"));
    expect(result.current).toBe("title only");
  });

  it("useEntityName_skillPrefix_resolves", () => {
    const { result } = renderHook(() => useEntityName("sk_1"));
    expect(result.current).toBe("skill one");
  });

  it("useEntityName_mcpPrefix_resolves", () => {
    const { result } = renderHook(() => useEntityName("mcp_1"));
    expect(result.current).toBe("mcp one");
  });

  it("useEntityName_convPrefix_resolves", () => {
    const { result } = renderHook(() => useEntityName("cv_1"));
    expect(result.current).toBe("conv one");
  });

  it("useEntityName_flowrunPrefix_prefersWorkflowOverWorkflowId", () => {
    const { result } = renderHook(() => useEntityName("fr_1"));
    expect(result.current).toBe("wf one");
  });

  it("useEntityName_flowrunPrefix_fallbackToWorkflowId", () => {
    const { result } = renderHook(() => useEntityName("fr_2"));
    expect(result.current).toBe("wf_2");
  });

  it("useEntityName_unknownId_returnsNull", () => {
    const { result } = renderHook(() => useEntityName("fn_does_not_exist"));
    expect(result.current).toBeNull();
  });

  it("useEntityName_unknownPrefix_returnsNull", () => {
    const { result } = renderHook(() => useEntityName("zzz_999"));
    expect(result.current).toBeNull();
  });
});
