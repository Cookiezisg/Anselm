// api/conversations — verifies each hook hits the correct endpoint
// with the correct method + body, and mutations invalidate the right
// query keys.

import { beforeEach, describe, expect, it } from "vitest";
import { waitFor } from "@testing-library/react";
import { setupFetchSpy, renderMutation } from "./_testHarness.js";
import {
  useCreateConversation, useUpdateConversation, useDeleteConversation,
  useSendMessage, useCancelStream,
} from "./conversations.js";

let calls;
beforeEach(async () => {
  calls = setupFetchSpy();
  const bridge = await import("../bridge/wails.js");
  await bridge.initBaseUrl();
});

describe("useCreateConversation", () => {
  it("postsToConversations_emptyBodyDefault", async () => {
    const { result, client } = await renderMutation(useCreateConversation);
    result.current.mutate(undefined);
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0].url).toBe("/api/v1/conversations");
    expect(calls[0].method).toBe("POST");
    expect(calls[0].body).toBe("{}");
  });

  it("invalidatesConversationsListOnSuccess", async () => {
    const { result, client } = await renderMutation(useCreateConversation);
    const invSpy = vi.spyOn(client, "invalidateQueries");
    result.current.mutate({ title: "x" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(invSpy).toHaveBeenCalledWith({ queryKey: ["conversations"] });
  });
});

describe("useUpdateConversation", () => {
  it("patchesEndpointWithId", async () => {
    const { result } = await renderMutation(() => useUpdateConversation("cv_x"));
    result.current.mutate({ pinned: true });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0].url).toBe("/api/v1/conversations/cv_x");
    expect(calls[0].method).toBe("PATCH");
    expect(JSON.parse(calls[0].body)).toEqual({ pinned: true });
  });

  it("invalidatesListAndDetail", async () => {
    const { result, client } = await renderMutation(() => useUpdateConversation("cv_x"));
    const spy = vi.spyOn(client, "invalidateQueries");
    result.current.mutate({ title: "new" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(spy).toHaveBeenCalledWith({ queryKey: ["conversations"] });
    expect(spy).toHaveBeenCalledWith({ queryKey: ["conv", "cv_x"] });
  });
});

describe("useDeleteConversation", () => {
  it("deletesById", async () => {
    const { result } = await renderMutation(useDeleteConversation);
    result.current.mutate("cv_kill");
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0].url).toBe("/api/v1/conversations/cv_kill");
    expect(calls[0].method).toBe("DELETE");
  });
});

describe("useSendMessage", () => {
  it("postsToMessagesEndpointForGivenConv", async () => {
    const { result } = await renderMutation(() => useSendMessage("cv_z"));
    result.current.mutate({ content: "hi" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0].url).toBe("/api/v1/conversations/cv_z/messages");
    expect(calls[0].method).toBe("POST");
    expect(JSON.parse(calls[0].body)).toEqual({ content: "hi" });
  });

  it("doesNotInvalidateAnyQuery_SSEDrivesUI", async () => {
    const { result, client } = await renderMutation(() => useSendMessage("cv_z"));
    const spy = vi.spyOn(client, "invalidateQueries");
    result.current.mutate({ content: "hi" });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(spy).not.toHaveBeenCalled();
  });
});

describe("useCancelStream", () => {
  it("deletesStreamEndpoint", async () => {
    const { result } = await renderMutation(() => useCancelStream("cv_z"));
    result.current.mutate();
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(calls[0].url).toBe("/api/v1/conversations/cv_z/stream");
    expect(calls[0].method).toBe("DELETE");
  });
});

import { vi } from "vitest";
