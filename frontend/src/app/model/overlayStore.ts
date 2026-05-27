// Overlay visibility state — command palette, notifications drawer,
// ask-user modal, settings modal, and the pending ask payload.
//
// overlay 开关状态：命令面板、通知抽屉、ask-user 弹窗、设置弹窗，
// 以及 pendingAsk 载荷（SSE 推送后落这里，modal 消费）。

import { create } from "zustand";
import type { PendingAsk } from "@shared/api";

export type { PendingAsk };

export interface OverlayState {
  cmdkOpen: boolean;
  notifsOpen: boolean;
  askOpen: boolean;
  settingsOpen: boolean;
  pendingAsk: PendingAsk | null;

  setCmdkOpen(b: boolean): void;
  setNotifsOpen(b: boolean): void;
  setAskOpen(b: boolean): void;
  setSettingsOpen(b: boolean): void;
  setPendingAsk(v: PendingAsk | null): void;
}

export const useOverlayStore = create<OverlayState>()((set) => ({
  cmdkOpen: false,
  notifsOpen: false,
  askOpen: false,
  settingsOpen: false,
  pendingAsk: null,

  setCmdkOpen: (b) => set({ cmdkOpen: !!b }),
  setNotifsOpen: (b) => set({ notifsOpen: !!b }),
  setAskOpen: (b) => set({ askOpen: !!b }),
  setSettingsOpen: (b) => set({ settingsOpen: !!b }),
  setPendingAsk: (v) => set({ pendingAsk: v }),
}));
