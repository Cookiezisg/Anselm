// User preference store — persisted single-instance entity (theme/accent/
// density/lang/reasoningDefault). Lives in entities so downstream components
// can import directly without going through app/features (downward allowed).
//
// 用户偏好持久存储；entities 层，下游组件可直接 import（顺向依赖）。

import { create } from "zustand";
import { persist } from "zustand/middleware";

// Detect device language for the first-run default; mirrors store/boot.js#detectLang.
// Inlined here so entities/settings has no shared-tmp dependency.
function detectLang(): string {
  if (typeof navigator === "undefined") return "zh";
  const l = ((navigator as Navigator & { userLanguage?: string }).language || (navigator as Navigator & { userLanguage?: string }).userLanguage || "").toLowerCase();
  return l.startsWith("zh") ? "zh" : "en";
}

export interface SettingsState {
  theme: "system" | "light" | "dark";
  accent: "claude" | "blue" | "ink" | "green" | "purple";
  density: "compact" | "cozy" | "comfortable";
  lang: "zh" | "en";
  reasoningDefault: "collapsed" | "expanded";
  set: (patch: Partial<Omit<SettingsState, "set" | "reset">>) => void;
  reset: () => void;
}

const DEFAULTS: Omit<SettingsState, "set" | "reset"> = {
  theme: "system",
  accent: "claude",
  density: "cozy",
  lang: detectLang() as "zh" | "en",
  reasoningDefault: "collapsed",
};

export const useSettingsStore = create<SettingsState>()(
  persist(
    (set) => ({
      ...DEFAULTS,
      set: (patch) => set((s) => ({ ...s, ...patch })),
      reset: () => set(DEFAULTS),
    }),
    { name: "forgify-settings", version: 1 }
  )
);

// resolveTheme — collapses "system" to "light"/"dark" using prefers-color-scheme.
export function resolveTheme(theme: string): "light" | "dark" {
  if (theme !== "system") return theme as "light" | "dark";
  if (typeof window === "undefined") return "light";
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

// applyTheme — write theme/accent/density data-attrs to <html>.
// Idempotent; safe to call on every settings change.
export function applyTheme(settings: Pick<SettingsState, "theme" | "accent" | "density" | "lang">): void {
  const root = document.documentElement;
  root.dataset.theme = resolveTheme(settings.theme);
  root.dataset.accent = settings.accent;
  root.dataset.density = settings.density;
  root.dataset.lang = settings.lang;
}
