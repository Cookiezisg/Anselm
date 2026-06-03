// entities/agent api — query + mutation hooks coverage. Mirrors
// handler.test.ts / forge.test.ts: asserts URL + method + body for the
// full agent surface (CRUD + version lifecycle + invoke + iterate).

import { beforeEach, describe, expect, it } from "vitest";
import { renderHook, waitFor } from "@testing-library/react";
import { setupFetchSpy, renderQuery, renderMutation, makeClient, wrap, type FetchCall } from "../../../shared/api/_testHarness";
import {
  useAgents,
  useAgent,
  useAgentVersions,
  useAgentVersion,
  useAgentExecutions,
  useAgentExecution,
  useCreateAgent,
  useUpdateAgentMeta,
  useEditAgent,
  useInvokeAgent,
  useRevertAgent,
  useIterateAgent,
  useAcceptAgent,
  useRejectAgent,
  useDeleteAgent,
} from "./agent.js";

let calls: FetchCall[];
beforeEach(async () => {
  calls = setupFetchSpy();
  const bridge = await import("../../../shared/bridge/wails.js");
  await bridge.initBaseUrl();
});

describe("agent query hooks", () => {
  it("useAgents_fetchesAgentsList", async () => {
    const { result } = await renderQuery(useAgents);
    expect(calls[0].url).toContain("/agents");
    expect(calls[0].method).toBe("GET");
    expect(result.current.isSuccess).toBe(true);
  });

  it("useAgent_fetchesSingleAgent", async () => {
    const { result } = await renderQuery(() => useAgent("ag_1"));
    expect(calls[0].url).toContain("/agents/ag_1");
    expect(result.current.isSuccess).toBe(true);
  });

  it("useAgentVersions_fetchesVersionsList", async () => {
    const { result } = await renderQuery(() => useAgentVersions("ag_1"));
    expect(calls[0].url).toContain("/agents/ag_1/versions");
    expect(result.current.isSuccess).toBe(true);
  });

  it("useAgentVersion_fetchesSpecificVersion", async () => {
    const { result } = await renderQuery(() => useAgentVersion("ag_1", 2));
    expect(calls[0].url).toContain("/agents/ag_1/versions/2");
    expect(result.current.isSuccess).toBe(true);
  });

  it("useAgentExecutions_fetchesExecutions_withStatusFilter", async () => {
    const { result } = await renderQuery(() => useAgentExecutions("ag_1", "ok"));
    expect(calls[0].url).toContain("/agents/ag_1/executions?status=ok");
    expect(result.current.isSuccess).toBe(true);
  });

  it("useAgentExecution_fetchesSingleExecution", async () => {
    const { result } = await renderQuery(() => useAgentExecution("agx_1"));
    expect(calls[0].url).toContain("/agent-executions/agx_1");
    expect(result.current.isSuccess).toBe(true);
  });

  it("useAgent_emptyId_disabled", () => {
    const client = makeClient();
    const { result } = renderHook(() => useAgent(""), { wrapper: wrap(client) });
    expect(calls).toHaveLength(0);
    expect(result.current.fetchStatus).toBe("idle");
  });
});

describe("agent mutations", () => {
  it("useCreateAgent_postsBody", async () => {
    const { result } = await renderMutation(useCreateAgent);
    result.current.mutate({ name: "Triage", prompt: "you triage" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/agents", method: "POST" });
    expect(JSON.parse(calls[0].body)).toEqual({ name: "Triage", prompt: "you triage" });
  });

  it("useUpdateAgentMeta_patchesWithBody", async () => {
    const { result } = await renderMutation(() => useUpdateAgentMeta("ag_1"));
    result.current.mutate({ name: "newName" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/agents/ag_1", method: "PATCH" });
    expect(JSON.parse(calls[0].body)).toEqual({ name: "newName" });
  });

  it("useEditAgent_postsToEditAction", async () => {
    const { result } = await renderMutation(() => useEditAgent("ag_1"));
    result.current.mutate({ prompt: "tighter" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/agents/ag_1:edit", method: "POST" });
    expect(JSON.parse(calls[0].body)).toEqual({ prompt: "tighter" });
  });

  it("useInvokeAgent_postsInputAndVersion", async () => {
    const { result } = await renderMutation(useInvokeAgent);
    result.current.mutate({ id: "ag_1", version: 3, input: { q: "hi" } });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/agents/ag_1:invoke", method: "POST" });
    expect(JSON.parse(calls[0].body)).toEqual({ version: 3, input: { q: "hi" } });
  });

  it("useInvokeAgent_defaultsEmptyInput_andOmitsVersion", async () => {
    const { result } = await renderMutation(useInvokeAgent);
    result.current.mutate({ id: "ag_1" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(JSON.parse(calls[0].body)).toEqual({ input: {} });
  });

  it("useRevertAgent_postsTargetVersion", async () => {
    const { result } = await renderMutation(() => useRevertAgent("ag_1"));
    result.current.mutate(2);
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/agents/ag_1:revert", method: "POST" });
    expect(JSON.parse(calls[0].body)).toEqual({ targetVersion: 2 });
  });

  it("useIterateAgent_postsPrompt", async () => {
    const { result } = await renderMutation(useIterateAgent);
    result.current.mutate({ id: "ag_1", prompt: "rename it" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/agents/ag_1:iterate", method: "POST" });
    expect(JSON.parse(calls[0].body)).toEqual({ prompt: "rename it" });
  });

  it("useAcceptAgent_postsToPendingAccept", async () => {
    const { result } = await renderMutation(useAcceptAgent);
    result.current.mutate("ag_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/agents/ag_1/pending:accept", method: "POST" });
  });

  it("useRejectAgent_postsToPendingReject", async () => {
    const { result } = await renderMutation(useRejectAgent);
    result.current.mutate("ag_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/agents/ag_1/pending:reject", method: "POST" });
  });

  it("useDeleteAgent_deletesById", async () => {
    const { result } = await renderMutation(useDeleteAgent);
    result.current.mutate("ag_x");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/agents/ag_x", method: "DELETE" });
  });
});
