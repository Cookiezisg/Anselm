// Pane layout state — open panes list, active conv/flowrun/document,
// split percentage, narrow mode, focus-entity queue.
//
// Pane 布局状态：打开的 pane 列表、当前活跃资源、分屏比例、窄屏模式、
// 一次性聚焦队列。Cross-user 清理（activeConv/Run/Doc）由 4a.6 接 session 触发。

import { create } from "zustand";

const MAX_PANES = 2;

export interface PaneState {
  openPanes: string[];
  activeConv: string | null;
  activeFlowRun: string | null;
  activeDocument: string | null;
  leftPct: number;
  narrow: boolean;
  activeNarrowPane: string | null;
  focusEntity: Record<string, string>;

  setActiveConv(id: string | null): void;
  setActiveFlowRun(id: string | null): void;
  setActiveDocument(id: string | null): void;

  togglePane(k: string): void;
  openPane(k: string): void;
  closePane(k: string): void;
  openEntity(pane: string, id: string): void;
  consumeFocusEntity(pane: string): string | null;

  setLeftPct(n: number): void;
  setNarrow(b: unknown): void;
  setActiveNarrowPane(k: string | null): void;
}

export const usePaneStore = create<PaneState>()((set, get) => ({
  openPanes: ["chat"],
  activeConv: null,
  activeFlowRun: null,
  activeDocument: null,
  leftPct: 50,
  narrow: false,
  activeNarrowPane: null,
  focusEntity: {},

  setActiveConv: (id) => set({ activeConv: id }),
  setActiveFlowRun: (id) => set({ activeFlowRun: id }),
  setActiveDocument: (id) => set({ activeDocument: id }),

  togglePane: (k) =>
    set((s) => {
      if (s.openPanes.includes(k)) {
        const next = s.openPanes.filter((x) => x !== k);
        const nextActive = s.activeNarrowPane === k ? next[next.length - 1] || null : s.activeNarrowPane;
        return { openPanes: next, activeNarrowPane: nextActive };
      }
      if (s.openPanes.length >= MAX_PANES) {
        return { openPanes: [s.openPanes[1], k], activeNarrowPane: k };
      }
      return { openPanes: [...s.openPanes, k], activeNarrowPane: k };
    }),

  openPane: (k) =>
    set((s) => {
      if (s.openPanes.includes(k)) return { activeNarrowPane: k };
      if (s.openPanes.length >= MAX_PANES) {
        return { openPanes: [s.openPanes[1], k], activeNarrowPane: k };
      }
      return { openPanes: [...s.openPanes, k], activeNarrowPane: k };
    }),

  closePane: (k) =>
    set((s) => {
      const next = s.openPanes.filter((x) => x !== k);
      const nextActive = s.activeNarrowPane === k ? next[next.length - 1] || null : s.activeNarrowPane;
      return { openPanes: next, activeNarrowPane: nextActive };
    }),

  openEntity: (pane, id) =>
    set((s) => {
      const focus = { ...s.focusEntity, [pane]: id };
      const open = s.openPanes.includes(pane) ? s.openPanes
        : s.openPanes.length >= MAX_PANES
          ? [s.openPanes[1], pane]
          : [...s.openPanes, pane];
      return { openPanes: open, focusEntity: focus, activeNarrowPane: pane };
    }),

  consumeFocusEntity: (pane) => {
    const id = get().focusEntity[pane];
    if (!id) return null;
    set((s) => {
      const next = { ...s.focusEntity };
      delete next[pane];
      return { focusEntity: next };
    });
    return id;
  },

  setLeftPct: (n) => set({ leftPct: Math.max(20, Math.min(80, n)) }),
  setNarrow: (b) => set({ narrow: !!b }),
  setActiveNarrowPane: (k) => set({ activeNarrowPane: k }),
}));
