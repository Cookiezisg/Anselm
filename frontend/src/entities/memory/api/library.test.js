// entities/memory+document+mcp api — library mutations.
// Migrated from src/api/library.test.js (4b.5 recovery).

import { beforeEach, describe, expect, it } from "vitest";
import { waitFor } from "@testing-library/react";
import { setupFetchSpy, renderMutation } from "../../../shared/api/_testHarness.js";
import {
  useUpdateMemory, useCreateMemory, useDeleteMemory, usePinMemory,
} from "./memory.js";
import { useReconnectMcp, useRemoveMcp } from "../../mcp/api/mcp.js";
import {
  useCreateDocument, useUpdateDocument, useDeleteDocument, useMoveDocument,
} from "../../document/api/document.js";

let calls;
beforeEach(async () => {
  calls = setupFetchSpy();
  const bridge = await import("../../../shared/bridge/wails.js");
  await bridge.initBaseUrl();
});

describe("mcp mutations", () => {
  it("useReconnectMcp_postsReconnectAction", async () => {
    const { result } = await renderMutation(useReconnectMcp);
    result.current.mutate("mcp_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/mcp-servers/mcp_1:reconnect", method: "POST" });
  });

  it("useRemoveMcp_deletesById", async () => {
    const { result } = await renderMutation(useRemoveMcp);
    result.current.mutate("mcp_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/mcp-servers/mcp_1", method: "DELETE" });
  });
});

describe("memory mutations", () => {
  it("useUpdateMemory_patchesWithEncodedName", async () => {
    const { result } = await renderMutation(useUpdateMemory);
    result.current.mutate({ name: "my note", body: { content: "x" } });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/memories/my%20note", method: "PATCH" });
  });

  it("useCreateMemory_postsToMemories", async () => {
    const { result } = await renderMutation(useCreateMemory);
    result.current.mutate({ name: "n", content: "c" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/memories", method: "POST" });
  });

  it("useDeleteMemory_deletesEncodedName", async () => {
    const { result } = await renderMutation(useDeleteMemory);
    result.current.mutate("special name");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/memories/special%20name", method: "DELETE" });
  });

  it("usePinMemory_patchesPinnedFlag", async () => {
    const { result } = await renderMutation(usePinMemory);
    result.current.mutate({ name: "x", pinned: true });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(JSON.parse(calls[0].body)).toEqual({ pinned: true });
  });
});

describe("document mutations", () => {
  it("useCreateDocument_postsBody", async () => {
    const { result } = await renderMutation(useCreateDocument);
    result.current.mutate({ name: "Notes", parentId: null });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/documents", method: "POST" });
  });

  it("useUpdateDocument_patchesById", async () => {
    const { result } = await renderMutation(() => useUpdateDocument("doc_1"));
    result.current.mutate({ content: "new" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/documents/doc_1", method: "PATCH" });
  });

  it("useDeleteDocument_deletesById", async () => {
    const { result } = await renderMutation(useDeleteDocument);
    result.current.mutate("doc_1");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/documents/doc_1", method: "DELETE" });
  });

  it("useMoveDocument_postsMoveActionWithParentAndPosition", async () => {
    const { result } = await renderMutation(useMoveDocument);
    result.current.mutate({ id: "doc_x", parentId: "doc_p", position: 2 });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0]).toMatchObject({ url: "/api/v1/documents/doc_x:move", method: "POST" });
    expect(JSON.parse(calls[0].body)).toEqual({ parentId: "doc_p", position: 2 });
  });

  it("useMoveDocument_nullParent_serializedAsNull", async () => {
    const { result } = await renderMutation(useMoveDocument);
    result.current.mutate({ id: "doc_x", parentId: undefined, position: 0 });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(JSON.parse(calls[0].body)).toEqual({ parentId: null, position: 0 });
  });
});
