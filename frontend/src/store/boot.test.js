import { describe, it, expect, vi, afterEach } from "vitest";
import { computeBootState, detectLang } from "./boot.js";

describe("computeBootState", () => {
  const base = { onboardingActive: false, usersLoading: false, usersError: false, users: [], activeUserId: null };

  it("latched onboarding wins over everything", () => {
    expect(computeBootState({ ...base, onboardingActive: true, users: [{ id: "u_1" }], activeUserId: "u_1" })).toBe("onboarding");
  });
  it("users still loading -> booting", () => {
    expect(computeBootState({ ...base, usersLoading: true })).toBe("booting");
  });
  it("fresh install (zero users) -> onboarding", () => {
    expect(computeBootState({ ...base, users: [] })).toBe("onboarding");
  });
  it("users exist but activeUserId null -> booting (waiting on self-heal)", () => {
    expect(computeBootState({ ...base, users: [{ id: "u_1" }], activeUserId: null })).toBe("booting");
  });
  it("STALE activeUserId not in users -> booting, never ready", () => {
    expect(computeBootState({ ...base, users: [{ id: "u_1" }], activeUserId: "u_dead" })).toBe("booting");
  });
  it("valid activeUserId in users -> ready", () => {
    expect(computeBootState({ ...base, users: [{ id: "u_1" }], activeUserId: "u_1" })).toBe("ready");
  });
  it("users error with no users -> booting (do not flash onboarding on fetch error)", () => {
    expect(computeBootState({ ...base, usersError: true, users: [] })).toBe("booting");
  });
});

describe("detectLang", () => {
  afterEach(() => vi.unstubAllGlobals());
  it("zh-* -> zh", () => {
    vi.stubGlobal("navigator", { language: "zh-CN" });
    expect(detectLang()).toBe("zh");
  });
  it("en-US -> en", () => {
    vi.stubGlobal("navigator", { language: "en-US" });
    expect(detectLang()).toBe("en");
  });
  it("other locale -> en", () => {
    vi.stubGlobal("navigator", { language: "fr-FR" });
    expect(detectLang()).toBe("en");
  });
});
