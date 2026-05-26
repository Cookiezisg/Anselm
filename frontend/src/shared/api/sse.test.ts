// shared/api/sse — createSSE factory: URL construction (incl. currentUserId
// query param), event handler wiring, status callbacks.
// Migrated from src/sse/shared.test.js (4b.5 recovery).

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { MockEventSource } from "../../test-setup.js";

beforeEach(async () => {
  MockEventSource.reset();
  globalThis.EventSource = MockEventSource as unknown as typeof EventSource;
  const bridge = await import("../bridge/wails");
  await bridge.initBaseUrl();
  const { useSessionStore } = await import("@entities/session");
  const { setUserIdProvider } = await import("./authProvider");
  setUserIdProvider(() => useSessionStore.getState().currentUserId);
  useSessionStore.setState({ currentUserId: null });
});

afterEach(() => vi.restoreAllMocks());

describe("createSSE", () => {
  it("createSSE_noActiveUser_skipsConnection", async () => {
    const { createSSE } = await import("./sse");
    const onStatus = vi.fn();
    const ctrl = createSSE({ path: "/eventlog", eventHandlers: {}, onStatus });
    expect(MockEventSource.instances.length).toBe(0);
    expect(onStatus).toHaveBeenCalledWith("disconnected");
    expect(() => ctrl.close()).not.toThrow();
  });

  it("createSSE_activeUserId_appendsUserIdQuery", async () => {
    const { useSessionStore } = await import("@entities/session");
    useSessionStore.setState({ currentUserId: "u_test_123" });
    const { createSSE } = await import("./sse");
    createSSE({ path: "/eventlog", eventHandlers: {} });
    const es = MockEventSource.instances.at(-1);
    expect(es.url).toContain("userID=u_test_123");
    useSessionStore.setState({ currentUserId: null });
  });

  it("createSSE_pathWithExistingQuery_usesAmpersand", async () => {
    const { useSessionStore } = await import("@entities/session");
    useSessionStore.setState({ currentUserId: "u_q" });
    const { createSSE } = await import("./sse");
    createSSE({ path: "/eventlog?a=1", eventHandlers: {} });
    const es = MockEventSource.instances.at(-1);
    expect(es.url).toBe("/api/v1/eventlog?a=1&userID=u_q");
    useSessionStore.setState({ currentUserId: null });
  });

  it("createSSE_dispatchesParsedJSONToHandler", async () => {
    const { useSessionStore } = await import("@entities/session");
    useSessionStore.setState({ currentUserId: "u_d" });
    const { createSSE } = await import("./sse");
    const onDelta = vi.fn();
    createSSE({ path: "/eventlog", eventHandlers: { block_delta: onDelta } });
    const es = MockEventSource.instances.at(-1);
    es.emit("block_delta", { id: "blk_1", delta: "hi" }, "42");
    expect(onDelta).toHaveBeenCalledWith({ id: "blk_1", delta: "hi" }, { seq: 42, raw: '{"id":"blk_1","delta":"hi"}' });
    useSessionStore.setState({ currentUserId: null });
  });

  it("createSSE_invalidJSON_passesNullPayload", async () => {
    const { useSessionStore } = await import("@entities/session");
    useSessionStore.setState({ currentUserId: "u_j" });
    const { createSSE } = await import("./sse");
    const handler = vi.fn();
    createSSE({ path: "/eventlog", eventHandlers: { x: handler } });
    const es = MockEventSource.instances.at(-1);
    es.emit("x", "not-json{");
    expect(handler.mock.calls[0][0]).toBeNull();
    useSessionStore.setState({ currentUserId: null });
  });

  it("createSSE_handlerThrows_catchesAndDoesNotPropagate", async () => {
    const { useSessionStore } = await import("@entities/session");
    useSessionStore.setState({ currentUserId: "u_t" });
    const { createSSE } = await import("./sse");
    const errSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    createSSE({
      path: "/eventlog",
      eventHandlers: { bad: () => { throw new Error("boom"); } },
    });
    const es = MockEventSource.instances.at(-1);
    expect(() => es.emit("bad", {})).not.toThrow();
    expect(errSpy).toHaveBeenCalled();
    useSessionStore.setState({ currentUserId: null });
  });

  it("createSSE_close_callsEventSourceClose", async () => {
    const { useSessionStore } = await import("@entities/session");
    useSessionStore.setState({ currentUserId: "u_close" });
    const { createSSE } = await import("./sse");
    const ctrl = createSSE({ path: "/eventlog", eventHandlers: {} });
    const es = MockEventSource.instances.at(-1);
    ctrl.close();
    expect(es.readyState).toBe(MockEventSource.CLOSED);
    useSessionStore.setState({ currentUserId: null });
  });

  it("createSSE_closedWhileUidStillActive_callsNotifyAuthFailure", async () => {
    const { useSessionStore } = await import("@entities/session");
    const { setOnAuthFailure } = await import("./authProvider");
    const mockAuthFailure = vi.fn();
    setOnAuthFailure(mockAuthFailure);
    useSessionStore.setState({ currentUserId: "u_heal" });
    const { createSSE } = await import("./sse");
    createSSE({ path: "/eventlog", eventHandlers: {} });
    const es = MockEventSource.instances.at(-1);
    es.readyState = MockEventSource.CLOSED;
    es.emit("error", null);
    expect(mockAuthFailure).toHaveBeenCalled();
    setOnAuthFailure(() => {});
  });

  it("createSSE_closedAfterUidChanged_doesNotCallNotify", async () => {
    const { useSessionStore } = await import("@entities/session");
    const { setOnAuthFailure } = await import("./authProvider");
    const mockAuthFailure = vi.fn();
    setOnAuthFailure(mockAuthFailure);
    useSessionStore.setState({ currentUserId: "u_old" });
    const { createSSE } = await import("./sse");
    createSSE({ path: "/eventlog", eventHandlers: {} });
    const es = MockEventSource.instances.at(-1);
    useSessionStore.setState({ currentUserId: "u_new" });
    es.readyState = MockEventSource.CLOSED;
    es.emit("error", null);
    expect(mockAuthFailure).not.toHaveBeenCalled();
    setOnAuthFailure(() => {});
    useSessionStore.setState({ currentUserId: null });
  });
});
