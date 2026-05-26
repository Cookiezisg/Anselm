// Toast queue — a UI-only primitive with no business semantics.
// Kept in shared/ui so both the shell renderer (ToastTray) and any
// layer that imports shared can push notifications without depending
// on the God Store.
//
// Toast 队列 —— 无业务语义的纯 UI 通知原语；shared/ui 层，
// ToastTray 渲染，其他层 pushToast 均从此 import。

import { create } from "zustand";

export type ToastKind = "success" | "error" | "warn" | "info";

export interface Toast {
  id: string;
  kind?: ToastKind;
  title?: string;
  desc?: string;
  duration?: number;
  undo?: () => void;
}

interface ToastState {
  toasts: Toast[];
  pushToast: (t: Omit<Toast, "id">) => string;
  dismissToast: (id: string) => void;
}

export const useToastStore = create<ToastState>((set, get) => ({
  toasts: [],
  pushToast: (t) => {
    const id = Math.random().toString(36).slice(2, 9);
    const toast: Toast = { id, ...t };
    set((s) => ({ toasts: [...s.toasts, toast] }));
    if (t.duration !== 0) {
      setTimeout(() => {
        set((s) => ({ toasts: s.toasts.filter((x) => x.id !== id) }));
      }, t.duration || 5000);
    }
    return id;
  },
  dismissToast: (id) => set((s) => ({ toasts: s.toasts.filter((x) => x.id !== id) })),
}));
