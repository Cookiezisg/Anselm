// Session store — persisted session-local state (activeUserId / onboarded /
// leftPct). Preferences (theme/accent/density/lang/reasoningDefault) live in
// entities/settings/model/settingsStore.
//
// 会话状态持久化；偏好字段已迁至 entities/settings。

import { create } from "zustand";
import { persist } from "zustand/middleware";

const DEFAULTS = {
  activeUserId: null,    // local profile id; null → backend default local-user
  onboarded: false,      // first-run wizard completed flag
  leftPct: 50,           // saved pane split (read by ui.js; kept here for legacy persist)
};

export const useSettings = create(
  persist(
    (set) => ({
      ...DEFAULTS,
      set: (patch) => set((s) => ({ ...s, ...patch })),
      reset: () => set(DEFAULTS),
    }),
    { name: "forgify-session", version: 1 }
  )
);
