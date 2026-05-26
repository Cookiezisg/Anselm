// Sidebar collapse / expansion state, persisted to localStorage.
//
// sidebar 折叠 + 分组展开状态，持久化到 localStorage。

import { create } from "zustand";

function readBool(key: string, fallback: boolean): boolean {
  try {
    const v = localStorage.getItem(key);
    if (v === null) return fallback;
    return v === "1";
  } catch { return fallback; }
}
function writeBool(key: string, value: boolean): void {
  // Swallow QuotaExceededError — sidebar state is cosmetic, not critical.
  try { localStorage.setItem(key, value ? "1" : "0"); } catch { /* intentional */ }
}

type BoolSetter = boolean | ((prev: boolean) => boolean);

export interface SidebarState {
  collapsed: boolean;
  toolsExpanded: boolean;
  recentExpanded: boolean;
  archivedExpanded: boolean;

  setCollapsed(b: BoolSetter): void;
  setToolsExpanded(b: BoolSetter): void;
  setRecentExpanded(b: BoolSetter): void;
  setArchivedExpanded(b: BoolSetter): void;
}

export const useSidebarStore = create<SidebarState>()((set, get) => ({
  collapsed:        readBool("sidebar.collapsed",        false),
  toolsExpanded:    readBool("sidebar.toolsExpanded",    true),
  recentExpanded:   readBool("sidebar.recentExpanded",   true),
  archivedExpanded: readBool("sidebar.archivedExpanded", false),

  setCollapsed: (b) => {
    const next = typeof b === "function" ? b(get().collapsed) : !!b;
    writeBool("sidebar.collapsed", next);
    set({ collapsed: next });
  },

  setToolsExpanded: (b) => {
    const next = typeof b === "function" ? b(get().toolsExpanded) : !!b;
    writeBool("sidebar.toolsExpanded", next);
    set({ toolsExpanded: next });
  },

  setRecentExpanded: (b) => {
    const next = typeof b === "function" ? b(get().recentExpanded) : !!b;
    writeBool("sidebar.recentExpanded", next);
    set({ recentExpanded: next });
  },

  setArchivedExpanded: (b) => {
    const next = typeof b === "function" ? b(get().archivedExpanded) : !!b;
    writeBool("sidebar.archivedExpanded", next);
    set({ archivedExpanded: next });
  },
}));
