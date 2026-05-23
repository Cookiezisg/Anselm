// wails — base URL resolution. Module state is reset between tests via
// dynamic re-import so each spec sees a fresh _baseUrl=null.

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

let bridge;
beforeEach(async () => {
  vi.resetModules();
  bridge = await import("./wails.js");
});

afterEach(() => {
  delete window.go;
});

describe("wails bridge", () => {
  it("initBaseUrl_withoutWailsRuntime_returnsEmptyString", async () => {
    const r = await bridge.initBaseUrl();
    expect(r).toBe("");
    expect(bridge.getBaseUrl()).toBe("");
  });

  it("initBaseUrl_withWailsRuntime_resolvesToLocalhostPort", async () => {
    window.go = { main: { App: { GetBackendPort: async () => 9876 } } };
    const r = await bridge.initBaseUrl();
    expect(r).toBe("http://localhost:9876");
    expect(bridge.getBaseUrl()).toBe("http://localhost:9876");
  });

  it("getBaseUrl_beforeInit_throws", () => {
    expect(() => bridge.getBaseUrl()).toThrow(/not initialized/);
  });

  it("apiUrl_browserMode_returnsRelativePath", async () => {
    await bridge.initBaseUrl();
    expect(bridge.apiUrl("/api/v1/users")).toBe("/api/v1/users");
  });

  it("apiUrl_wailsMode_returnsAbsoluteUrl", async () => {
    window.go = { main: { App: { GetBackendPort: async () => 7788 } } };
    await bridge.initBaseUrl();
    expect(bridge.apiUrl("/api/v1/users")).toBe("http://localhost:7788/api/v1/users");
  });
});
