// shared/api/httpClient — apiFetch wrapper, qk factories, pickList, ApiError.
// Migrated from src/api/client.test.js (4b.5 recovery).

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

beforeEach(async () => {
  const bridge = await import("../bridge/wails");
  await bridge.initBaseUrl();
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("ApiError", () => {
  it("ApiError_defaults_unknownCodeZeroStatus", () => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const e = new (ApiErrorImport as any)();
    expect(e.code).toBe("UNKNOWN");
    expect(e.status).toBe(0);
  });

  it("ApiError_carriesCodeStatusDetails", async () => {
    const { ApiError } = await import("./httpClient");
    const e = new ApiError("nope", { code: "NOT_FOUND", status: 404, details: { x: 1 } });
    expect(e.code).toBe("NOT_FOUND");
    expect(e.status).toBe(404);
    expect(e.details).toEqual({ x: 1 });
    expect(e.message).toBe("nope");
  });
});

let ApiErrorImport: typeof import("./httpClient").ApiError;
beforeEach(async () => {
  const m = await import("./httpClient");
  ApiErrorImport = m.ApiError;
});

describe("pickList", () => {
  it("pickList_arrayInput_returnsSameArray", async () => {
    const { pickList } = await import("./httpClient");
    const arr = [{ id: 1 }];
    expect(pickList(arr)).toBe(arr);
  });

  it("pickList_pagedShape_returnsItems", async () => {
    const { pickList } = await import("./httpClient");
    const items = [1, 2, 3];
    expect(pickList({ items, nextCursor: "x", hasMore: false })).toBe(items);
  });

  it("pickList_emptyInput_returnsStableEmptyArray", async () => {
    const { pickList, EMPTY_ARRAY } = await import("./httpClient");
    expect(pickList(undefined)).toBe(EMPTY_ARRAY);
    expect(pickList(null)).toBe(EMPTY_ARRAY);
    expect(pickList({})).toBe(EMPTY_ARRAY);
    expect(pickList(null)).toBe(pickList(undefined));
  });

  it("EMPTY_ARRAY_isFrozen", async () => {
    const { EMPTY_ARRAY } = await import("./httpClient");
    expect(Object.isFrozen(EMPTY_ARRAY)).toBe(true);
  });
});

describe("qk — query key factory", () => {
  it("qk_simpleKey_returnsStableShape", async () => {
    const { qk } = await import("./queryKeys");
    expect(qk.users()).toEqual(["users"]);
    expect(qk.conversations()).toEqual(["conversations"]);
  });

  it("qk_parameterised_includesIdInKey", async () => {
    const { qk } = await import("./queryKeys");
    expect(qk.conversation("cv_x")).toEqual(["conv", "cv_x"]);
    expect(qk.messages("cv_x")).toEqual(["conv-messages", "cv_x"]);
    expect(qk.function("fn_y")).toEqual(["function", "fn_y"]);
  });

  it("qk_memories_fallbackKey_whenTypeMissing", async () => {
    const { qk } = await import("./queryKeys");
    expect(qk.memories()).toEqual(["memories", "all"]);
    expect(qk.memories("pin")).toEqual(["memories", "pin"]);
  });
});

describe("apiFetch", () => {
  it("apiFetch_success_returnsUnwrappedData", async () => {
    const { apiFetch } = await import("./httpClient");
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ data: { id: "u_1" } }),
    });
    const r = await apiFetch("/users");
    expect(r).toEqual({ id: "u_1" });
  });

  it("apiFetch_pagedResponse_returnsItemsWithCursor", async () => {
    const { apiFetch } = await import("./httpClient");
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ data: [1, 2], nextCursor: "n", hasMore: true }),
    });
    const r = await apiFetch("/items");
    expect(r).toEqual({ items: [1, 2], nextCursor: "n", hasMore: true });
  });

  it("apiFetch_204_returnsNull", async () => {
    const { apiFetch } = await import("./httpClient");
    globalThis.fetch = vi.fn().mockResolvedValue({ ok: true, status: 204 });
    const r = await apiFetch("/x", { method: "DELETE" });
    expect(r).toBe(null);
  });

  it("apiFetch_errorWithEnvelope_throwsApiErrorWithCode", async () => {
    const { apiFetch } = await import("./httpClient");
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 404,
      statusText: "Not Found",
      json: async () => ({ error: { code: "DOC_NOT_FOUND", message: "missing", details: { id: "x" } } }),
    });
    await expect(apiFetch("/docs/x")).rejects.toMatchObject({
      code: "DOC_NOT_FOUND",
      status: 404,
      message: "missing",
      details: { id: "x" },
    });
  });

  it("apiFetch_errorWithoutEnvelope_derivesCodeFromStatus", async () => {
    const { apiFetch } = await import("./httpClient");
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: false,
      status: 500,
      statusText: "Server Error",
      json: async () => { throw new Error("no json"); },
    });
    await expect(apiFetch("/x")).rejects.toMatchObject({ code: "HTTP_500", status: 500 });
  });

  it("apiFetch_networkFailure_throwsNetworkApiError", async () => {
    const { apiFetch } = await import("./httpClient");
    globalThis.fetch = vi.fn().mockRejectedValue(new Error("offline"));
    await expect(apiFetch("/x")).rejects.toMatchObject({ code: "NETWORK", status: 0 });
  });

  it("apiFetch_bodyObject_serializesToJSONAndSetsContentType", async () => {
    const { apiFetch } = await import("./httpClient");
    const spy = vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ data: {} }) });
    globalThis.fetch = spy;
    await apiFetch("/x", { method: "POST", body: { foo: 1 } });
    const init = spy.mock.calls[0][1];
    expect(init.body).toBe(JSON.stringify({ foo: 1 }));
    expect(init.headers["Content-Type"]).toBe("application/json");
  });

  it("apiFetch_activeUserId_sentAsHeader", async () => {
    const { useSessionStore } = await import("@entities/session");
    const { setUserIdProvider } = await import("./authProvider");
    setUserIdProvider(() => useSessionStore.getState().currentUserId);
    useSessionStore.setState({ currentUserId: "u_abc" });
    const { apiFetch } = await import("./httpClient");
    const spy = vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ data: {} }) });
    globalThis.fetch = spy;
    await apiFetch("/x");
    expect(spy.mock.calls[0][1].headers["X-Forgify-User-ID"]).toBe("u_abc");
    useSessionStore.setState({ currentUserId: null });
  });

  it("apiFetch_noActiveUser_omitsHeader", async () => {
    const { useSessionStore } = await import("@entities/session");
    const { setUserIdProvider } = await import("./authProvider");
    setUserIdProvider(() => useSessionStore.getState().currentUserId);
    useSessionStore.setState({ currentUserId: null });
    const { apiFetch } = await import("./httpClient");
    const spy = vi.fn().mockResolvedValue({ ok: true, status: 200, json: async () => ({ data: {} }) });
    globalThis.fetch = spy;
    await apiFetch("/x");
    expect(spy.mock.calls[0][1].headers["X-Forgify-User-ID"]).toBeUndefined();
  });

  it("apiFetch_parseJSONFalse_returnsRawResponse", async () => {
    const { apiFetch } = await import("./httpClient");
    const fakeRes = { ok: true, status: 200, body: "raw" };
    globalThis.fetch = vi.fn().mockResolvedValue(fakeRes);
    const r = await apiFetch("/x", { parseJSON: false });
    expect(r).toBe(fakeRes);
  });
});
