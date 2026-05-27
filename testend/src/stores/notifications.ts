import { create } from "zustand";
import { subscribe } from "@/api/sse";

export interface NotifEvent {
  type: string;
  id: string;
  data?: Record<string, unknown>;
  conversationId?: string;
  action?: string;
  receivedAt: number;
}

interface State {
  list: NotifEvent[];
  cap: number;
  unsub: (() => void) | null;
  start: () => void;
  stop: () => void;
  clear: () => void;
}

export const useNotificationsStore = create<State>((set, get) => ({
  list: [],
  cap: 200,
  unsub: null,
  start: () => {
    if (get().unsub) return;
    const u = subscribe("notifications", (e) => {
      const data = e.data as Record<string, unknown>;
      set((s) => ({
        list: [
          ...s.list.slice(Math.max(0, s.list.length - s.cap + 1)),
          { ...(data as unknown as NotifEvent), receivedAt: e.receivedAt },
        ],
      }));
    });
    set({ unsub: u });
  },
  stop: () => {
    get().unsub?.();
    set({ unsub: null });
  },
  clear: () => set({ list: [] }),
}));
