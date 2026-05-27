import { create } from "zustand";

interface State {
  activeId: string | null;
  filter: string;
  showArchived: boolean;
  setActive: (id: string | null) => void;
  setFilter: (q: string) => void;
  setShowArchived: (b: boolean) => void;
}

export const useConvStore = create<State>((set) => ({
  activeId: null,
  filter: "",
  showArchived: false,
  setActive: (id) => set({ activeId: id }),
  setFilter: (q) => set({ filter: q }),
  setShowArchived: (b) => set({ showArchived: b }),
}));
