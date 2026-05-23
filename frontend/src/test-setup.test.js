// Smoke test — proves vitest + jsdom + test-setup mocks all wire up.

import { describe, expect, it } from "vitest";

describe("test-setup", () => {
  it("matchMedia_isStubbed", () => {
    expect(window.matchMedia("(prefers-color-scheme: dark)").matches).toBe(false);
  });

  it("ResizeObserver_isStubbed", () => {
    const ro = new window.ResizeObserver(() => {});
    expect(typeof ro.observe).toBe("function");
  });

  it("EventSource_globalIsMockable", () => {
    const es = new EventSource("/x");
    expect(es).toBeInstanceOf(EventTarget);
    es.close();
  });
});
