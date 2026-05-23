// store/settings — persistence round-trip + theme/accent resolution.

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

beforeEach(() => {
  localStorage.clear();
  vi.resetModules();
});

afterEach(() => {
  delete document.documentElement.dataset.theme;
  delete document.documentElement.dataset.accent;
  delete document.documentElement.dataset.density;
  delete document.documentElement.dataset.lang;
});

describe("useSettings", () => {
  it("useSettings_defaults_matchSpec", async () => {
    const { useSettings } = await import("./settings.js");
    const s = useSettings.getState();
    expect(s.theme).toBe("system");
    expect(s.accent).toBe("claude");
    expect(s.density).toBe("cozy");
    expect(s.lang).toBe("zh");
    expect(s.activeUserId).toBeNull();
    expect(s.onboarded).toBe(false);
  });

  it("set_mergesPartialPatch", async () => {
    const { useSettings } = await import("./settings.js");
    useSettings.getState().set({ theme: "dark", accent: "blue" });
    const s = useSettings.getState();
    expect(s.theme).toBe("dark");
    expect(s.accent).toBe("blue");
    expect(s.density).toBe("cozy");
  });

  it("reset_restoresDefaults", async () => {
    const { useSettings } = await import("./settings.js");
    useSettings.getState().set({ theme: "dark", lang: "en", onboarded: true });
    useSettings.getState().reset();
    const s = useSettings.getState();
    expect(s.theme).toBe("system");
    expect(s.lang).toBe("zh");
    expect(s.onboarded).toBe(false);
  });

  it("persist_writesToLocalStorage", async () => {
    const { useSettings } = await import("./settings.js");
    useSettings.getState().set({ accent: "green" });
    const stored = localStorage.getItem("forgify-settings");
    expect(stored).toBeTruthy();
    expect(JSON.parse(stored).state.accent).toBe("green");
  });
});

describe("resolveTheme", () => {
  it("resolveTheme_lightOrDark_passesThrough", async () => {
    const { resolveTheme } = await import("./settings.js");
    expect(resolveTheme("light")).toBe("light");
    expect(resolveTheme("dark")).toBe("dark");
  });

  it("resolveTheme_system_collapsesViaMediaQuery", async () => {
    window.matchMedia = vi.fn().mockReturnValue({ matches: true });
    const { resolveTheme } = await import("./settings.js");
    expect(resolveTheme("system")).toBe("dark");
    window.matchMedia = vi.fn().mockReturnValue({ matches: false });
    expect(resolveTheme("system")).toBe("light");
  });
});

describe("applyTheme", () => {
  it("applyTheme_writesDatasetAttrs", async () => {
    const { applyTheme } = await import("./settings.js");
    applyTheme({ theme: "dark", accent: "blue", density: "compact", lang: "en" });
    expect(document.documentElement.dataset.theme).toBe("dark");
    expect(document.documentElement.dataset.accent).toBe("blue");
    expect(document.documentElement.dataset.density).toBe("compact");
    expect(document.documentElement.dataset.lang).toBe("en");
  });

  it("applyTheme_systemTheme_resolvesBeforeWriting", async () => {
    window.matchMedia = vi.fn().mockReturnValue({ matches: true });
    const { applyTheme } = await import("./settings.js");
    applyTheme({ theme: "system", accent: "blue", density: "cozy", lang: "zh" });
    expect(document.documentElement.dataset.theme).toBe("dark");
  });
});
