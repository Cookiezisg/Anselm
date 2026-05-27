import { create } from "zustand";
import { persist } from "zustand/middleware";

interface Toast {
  id: string;
  kind?: "success" | "error" | "warn" | "info";
  title?: string;
  desc?: string;
  duration?: number;
}

interface RawJsonModalState {
  open: boolean;
  title?: string;
  payload?: unknown;
}

interface State {
  colConv: number;
  colChat: number;
  colNav: number;
  expanded: boolean;
  palette: boolean;
  rawJson: RawJsonModalState;
  toasts: Toast[];
  setColConv: (w: number) => void;
  setColChat: (w: number) => void;
  setColNav: (w: number) => void;
  setExpanded: (e: boolean) => void;
  openPalette: () => void;
  closePalette: () => void;
  showRaw: (title: string, payload: unknown) => void;
  closeRaw: () => void;
  toast: (t: Omit<Toast, "id">) => string;
  dismissToast: (id: string) => void;
}

export const useUIStore = create<State>()(
  persist(
    (set, get) => ({
      colConv: 200,
      colChat: 420,
      colNav: 220,
      expanded: false,
      palette: false,
      rawJson: { open: false },
      toasts: [],
      setColConv: (w) => set({ colConv: w }),
      setColChat: (w) => set({ colChat: w }),
      setColNav: (w) => set({ colNav: w }),
      setExpanded: (expanded) => set({ expanded }),
      openPalette: () => set({ palette: true }),
      closePalette: () => set({ palette: false }),
      showRaw: (title, payload) => set({ rawJson: { open: true, title, payload } }),
      closeRaw: () => set({ rawJson: { open: false } }),
      toast: (t) => {
        const id = crypto.randomUUID();
        const toast: Toast = { id, ...t };
        set({ toasts: [...get().toasts, toast] });
        const duration = t.duration ?? 5000;
        if (duration > 0) setTimeout(() => get().dismissToast(id), duration);
        return id;
      },
      dismissToast: (id) => set({ toasts: get().toasts.filter((x) => x.id !== id) }),
    }),
    {
      name: "testend-ui",
      partialize: (s) => ({
        colConv: s.colConv,
        colChat: s.colChat,
        colNav: s.colNav,
        expanded: s.expanded,
      }),
    },
  ),
);
