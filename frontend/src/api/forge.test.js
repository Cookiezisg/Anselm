// api/forge — function / handler / workflow trinity hooks.

import { beforeEach, describe, expect, it, vi } from "vitest";
import { waitFor } from "@testing-library/react";
import { setupFetchSpy, renderMutation } from "./_testHarness.js";
import {
  useAcceptFunction, useRejectFunction, useRevertFunction,
  useRunFunction, useDeleteFunction,
  useAcceptHandler, useCallHandler, useDeleteHandler,
  useAcceptWorkflow, useRejectWorkflow, useDeleteWorkflow,
  useUpdateWorkflow, useRunWorkflow, useEditWorkflow,
  useCapabilityCheck, useIterateForge,
} from "./forge.js";

let calls;
beforeEach(async () => {
  calls = setupFetchSpy();
  const bridge = await import("../bridge/wails.js");
  await bridge.initBaseUrl();
});

describe("function mutations", () => {
  it("useAcceptFunction_postsToPendingAccept", async () => {
    const { result } = await renderMutation(useAcceptFunction);
    result.current.mutate("fn_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/functions/fn_1/pending:accept", method: "POST" });
  });

  it("useRejectFunction_postsToPendingReject", async () => {
    const { result } = await renderMutation(useRejectFunction);
    result.current.mutate("fn_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/functions/fn_1/pending:reject", method: "POST" });
  });

  it("useRevertFunction_usesRevertActionSuffix", async () => {
    const { result } = await renderMutation(useRevertFunction);
    result.current.mutate("fn_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/functions/fn_1:revert", method: "POST" });
  });

  it("useRunFunction_includesInputsBody", async () => {
    const { result } = await renderMutation(useRunFunction);
    result.current.mutate({ id: "fn_1", inputs: { x: 1 } });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(JSON.parse(calls[0].body)).toEqual({ inputs: { x: 1 } });
  });

  it("useDeleteFunction_deletesById", async () => {
    const { result } = await renderMutation(useDeleteFunction);
    result.current.mutate("fn_x");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/functions/fn_x", method: "DELETE" });
  });
});

describe("handler mutations", () => {
  it("useAcceptHandler_postsToPendingAccept", async () => {
    const { result } = await renderMutation(useAcceptHandler);
    result.current.mutate("hd_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/handlers/hd_1/pending:accept" });
  });

  it("useCallHandler_postsMethodAndArgs", async () => {
    const { result } = await renderMutation(useCallHandler);
    result.current.mutate({ id: "hd_1", method: "do", args: [1, 2] });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0].url).toBe("/api/v1/handlers/hd_1:call");
    expect(JSON.parse(calls[0].body)).toEqual({ method: "do", args: [1, 2] });
  });

  it("useDeleteHandler_deletesById", async () => {
    const { result } = await renderMutation(useDeleteHandler);
    result.current.mutate("hd_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/handlers/hd_1", method: "DELETE" });
  });
});

describe("workflow mutations", () => {
  it("useAcceptWorkflow_postsToPendingAccept", async () => {
    const { result } = await renderMutation(useAcceptWorkflow);
    result.current.mutate("wf_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/workflows/wf_1/pending:accept" });
  });

  it("useUpdateWorkflow_patchesWithBody", async () => {
    const { result } = await renderMutation(() => useUpdateWorkflow("wf_1"));
    result.current.mutate({ name: "newName" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/workflows/wf_1", method: "PATCH" });
  });

  it("useRunWorkflow_postsTrigger_defaultEmptyInput", async () => {
    const { result } = await renderMutation(useRunWorkflow);
    result.current.mutate({ id: "wf_1" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/workflows/wf_1:trigger" });
    expect(JSON.parse(calls[0].body)).toEqual({ input: {} });
  });

  it("useEditWorkflow_postsOpsWithDefaultReason", async () => {
    const { result } = await renderMutation(() => useEditWorkflow("wf_1"));
    result.current.mutate({ ops: [{ type: "add" }] });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/workflows/wf_1:edit" });
    expect(JSON.parse(calls[0].body)).toEqual({ ops: [{ type: "add" }], changeReason: "manual edit" });
  });

  it("useCapabilityCheck_postsToActionSuffix", async () => {
    const { result } = await renderMutation(useCapabilityCheck);
    result.current.mutate("wf_x");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/workflows/wf_x:capability-check" });
  });
});

describe("useIterateForge", () => {
  it("buildsKindSpecificEndpoint", async () => {
    const { result } = await renderMutation(useIterateForge);
    result.current.mutate({ kind: "function", id: "fn_1", prompt: "rename" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/functions/fn_1:iterate" });
    expect(JSON.parse(calls[0].body)).toEqual({ prompt: "rename" });
  });
});
