import { create } from "zustand";
import { getJSON } from "@/api/devClient";

export interface Catalog {
  generatedAt: string;
  fingerprint: string;
  items: Array<{
    source: "function" | "handler" | "workflow" | "skill" | "mcp";
    name: string;
    description: string;
    granularity: "PerItem" | "PerServer" | "PerCollection";
  }>;
}

interface State {
  current: Catalog | null;
  loading: boolean;
  refresh: () => Promise<void>;
}

export const useCatalogStore = create<State>((set) => ({
  current: null,
  loading: false,
  refresh: async () => {
    set({ loading: true });
    try {
      const c = await getJSON<Catalog | null>("/api/v1/catalog");
      set({ current: c, loading: false });
    } catch {
      set({ loading: false });
    }
  },
}));
