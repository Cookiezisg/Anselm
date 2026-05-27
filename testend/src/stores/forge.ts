import { create } from "zustand";
import { subscribe } from "@/api/sse";

export interface ForgeEvent {
  event: string;
  scope: { kind: "function" | "handler" | "workflow"; id: string };
  conversationId?: string;
  toolCallId?: string;
  index?: number;
  op?: unknown;
  attempt?: number;
  status?: string;
  stage?: string;
  detail?: string;
  error?: string;
  versionId?: string;
  envStatus?: string;
  attemptsUsed?: number;
  receivedAt: number;
}

interface State {
  events: ForgeEvent[];
  cap: number;
  unsub: (() => void) | null;
  start: () => void;
  stop: () => void;
  clear: () => void;
}

export const useForgeStore = create<State>((set, get) => ({
  events: [],
  cap: 200,
  unsub: null,
  start: () => {
    if (get().unsub) return;
    const u = subscribe("forge", (e) => {
      const data = e.data as Record<string, unknown>;
      const fe = { event: e.event, ...(data as object), receivedAt: e.receivedAt } as ForgeEvent;
      set((s) => ({
        events: [...s.events.slice(Math.max(0, s.events.length - s.cap + 1)), fe],
      }));
    });
    set({ unsub: u });
  },
  stop: () => {
    get().unsub?.();
    set({ unsub: null });
  },
  clear: () => set({ events: [] }),
}));
