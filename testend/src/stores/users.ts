import { create } from "zustand";
import { persist } from "zustand/middleware";
import type { User } from "@frontend/entities/user/model/types";

interface State {
  list: User[];
  activeId: string | null;
  refresh: () => Promise<void>;
  setActive: (id: string) => void;
}

export const useUsersStore = create<State>()(
  persist(
    (set, get) => ({
      list: [],
      activeId: null,
      refresh: async () => {
        const res = await fetch("/api/v1/users");
        const json = await res.json();
        const list: User[] = json.data ?? [];
        set({ list });
        if (list.length === 1 && !get().activeId) {
          set({ activeId: list[0]!.id });
        }
        if (get().activeId && !list.some((u) => u.id === get().activeId)) {
          set({ activeId: null });
        }
      },
      setActive: (id) => set({ activeId: id }),
    }),
    { name: "testend-active-user", partialize: (s) => ({ activeId: s.activeId }) },
  ),
);
