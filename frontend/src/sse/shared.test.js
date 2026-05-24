// sse/shared — createSSE factory: URL construction (incl. activeUserId
// query param), event handler wiring, status callbacks.

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { MockEventSource } from "../test-setup.js";

beforeEach(async () => {
  MockEventSource.reset();
  globalThis.EventSource = MockEventSource;
  const bridge = await import("../bridge/wails.js");
  await bridge.initBaseUrl();
  const { useSettings } = await import("../store/settings.js");
  useSettings.setState({ activeUserId: null });
});

afterEach(() => vi.restoreAllMocks());

describe("createSSE", () => {
  it("createSSE_noActiveUser_skipsConnection", async () => {
    const { createSSE } = await import("./shared.js");
    const onStatus = vi.fn();
    const ctrl = createSSE({ path: "/eventlog", eventHandlers: {}, onStatus });
    // No EventSource constructed when activeUserId is null — would 401 anyway.
    expect(MockEventSource.instances.length).toBe(0);
    expect(onStatus).toHaveBeenCalledWith("disconnected");
    // Controller is a no-op so callers can still call close() safely.
    expect(() => ctrl.close()).not.toThrow();
  });

  it("createSSE_activeUserId_appendsUserIdQuery", async () => {
    const { useSettings } = await import("../store/settings.js");
    useSettings.setState({ activeUserId: "u_test_123" });
    const { createSSE } = await import("./shared.js");
    createSSE({ path: "/eventlog", eventHandlers: {} });
    const es = MockEventSource.instances.at(-1);
    expect(es.url).toContain("userID=u_test_123");
    useSettings.setState({ activeUserId: null });
  });

  it("createSSE_pathWithExistingQuery_usesAmpersand", async () => {
    const { useSettings } = await import("../store/settings.js");
    useSettings.setState({ activeUserId: "u_q" });
    const { createSSE } = await import("./shared.js");
    createSSE({ path: "/eventlog?a=1", eventHandlers: {} });
    const es = MockEventSource.instances.at(-1);
    expect(es.url).toBe("/api/v1/eventlog?a=1&userID=u_q");
    useSettings.setState({ activeUserId: null });
  });

  it("createSSE_dispatchesParsedJSONToHandler", async () => {
    const { useSettings } = await import("../store/settings.js");
    useSettings.setState({ activeUserId: "u_d" });
    const { createSSE } = await import("./shared.js");
    const onDelta = vi.fn();
    createSSE({ path: "/eventlog", eventHandlers: { block_delta: onDelta } });
    const es = MockEventSource.instances.at(-1);
    es.emit("block_delta", { id: "blk_1", delta: "hi" }, "42");
    expect(onDelta).toHaveBeenCalledWith({ id: "blk_1", delta: "hi" }, { seq: 42, raw: '{"id":"blk_1","delta":"hi"}' });
    useSettings.setState({ activeUserId: null });
  });

  it("createSSE_invalidJSON_passesNullPayload", async () => {
    const { useSettings } = await import("../store/settings.js");
    useSettings.setState({ activeUserId: "u_j" });
    const { createSSE } = await import("./shared.js");
    const handler = vi.fn();
    createSSE({ path: "/eventlog", eventHandlers: { x: handler } });
    const es = MockEventSource.instances.at(-1);
    es.emit("x", "not-json{");
    expect(handler.mock.calls[0][0]).toBeNull();
    useSettings.setState({ activeUserId: null });
  });

  it("createSSE_handlerThrows_catchesAndDoesNotPropagate", async () => {
    const { useSettings } = await import("../store/settings.js");
    useSettings.setState({ activeUserId: "u_t" });
    const { createSSE } = await import("./shared.js");
    const errSpy = vi.spyOn(console, "error").mockImplementation(() => {});
    createSSE({
      path: "/eventlog",
      eventHandlers: { bad: () => { throw new Error("boom"); } },
    });
    const es = MockEventSource.instances.at(-1);
    expect(() => es.emit("bad", {})).not.toThrow();
    expect(errSpy).toHaveBeenCalled();
    useSettings.setState({ activeUserId: null });
  });

  it("createSSE_close_callsEventSourceClose", async () => {
    const { useSettings } = await import("../store/settings.js");
    useSettings.setState({ activeUserId: "u_close" });
    const { createSSE } = await import("./shared.js");
    const ctrl = createSSE({ path: "/eventlog", eventHandlers: {} });
    const es = MockEventSource.instances.at(-1);
    ctrl.close();
    expect(es.readyState).toBe(MockEventSource.CLOSED);
    useSettings.setState({ activeUserId: null });
  });

  it("createSSE_closedWhileUidStillActive_selfHeals", async () => {
    const { useSettings } = await import("../store/settings.js");
    useSettings.setState({ activeUserId: "u_heal" });
    const { createSSE } = await import("./shared.js");
    createSSE({ path: "/eventlog", eventHandlers: {} });
    const es = MockEventSource.instances.at(-1);
    // Simulate backend rejection: connection closed permanently.
    es.readyState = MockEventSource.CLOSED;
    es.emit("error", null);
    // Self-heal cleared activeUserId.
    expect(useSettings.getState().activeUserId).toBeNull();
  });

  it("createSSE_closedAfterUidChanged_doesNotClobber", async () => {
    const { useSettings } = await import("../store/settings.js");
    useSettings.setState({ activeUserId: "u_old" });
    const { createSSE } = await import("./shared.js");
    createSSE({ path: "/eventlog", eventHandlers: {} });
    const es = MockEventSource.instances.at(-1);
    // User already switched accounts before this connection died.
    useSettings.setState({ activeUserId: "u_new" });
    es.readyState = MockEventSource.CLOSED;
    es.emit("error", null);
    // Self-heal must NOT clobber the new active id.
    expect(useSettings.getState().activeUserId).toBe("u_new");
    useSettings.setState({ activeUserId: null });
  });
});
