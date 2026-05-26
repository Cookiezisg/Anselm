// forgeProgress — SSE real-time projection keyed by "{kind}:{id}".
// Placed in shared/model so widgets, pages, and entities can read it
// without reversing the FSD dependency graph (app → shared is fine).
//
// forgeProgress —— SSE 实时投影,按 scopeKey 存储；放 shared/model
// 使下层顺向读取,同 toastStore 惯例。

import { create } from "zustand";

export interface ForgeProgress {
  scope?: { kind: string; id: string };
  operation?: string;
  conversationId?: string;
  toolCallId?: string;
  ops?: Array<{ index: number; op: unknown }>;
  envAttempts?: Array<{ attempt: number; status: string; stage?: string; detail?: string; error?: string }>;
  status: string;
  versionId?: string;
  envStatus?: string;
  attemptsUsed?: number;
  error?: string;
  finishedAt?: number;
}

interface ForgeProgressState {
  active: Record<string, ForgeProgress>;
  put: (scopeKey: string, value: ForgeProgress) => void;
  clear: (scopeKey: string) => void;
}

export const useForgeProgress = create<ForgeProgressState>((set) => ({
  active: {},

  put(scopeKey, value) {
    set((s) => ({ active: { ...s.active, [scopeKey]: value } }));
  },
  clear(scopeKey) {
    set((s) => {
      const next = { ...s.active };
      delete next[scopeKey];
      return { active: next };
    });
  },
}));
