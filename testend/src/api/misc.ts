/**
 * Misc small APIs — attachments only. Subagent + todo intentionally have
 * NO HTTP routes:
 *
 *   - Subagent runs live in the unified `messages` table with
 *     `attrs.kind=subagent_run` + `parentBlockId` pointing at the tool_call
 *     that spawned them. UI reads via `/api/v1/conversations/{id}/messages`.
 *
 *   - Todos are tool-driven (TaskCreate / TaskUpdate / TaskList / TaskGet
 *     system tools). UI observes them via the `notifications` SSE stream
 *     with `type=todo` and refetches via `messages` (todos persist as
 *     blocks attached to the spawning conversation).
 */

import { getJSON, postJSON } from './client';
import type { Attachment } from '@/types/domain';

/* ───────── attachments ───────── */
export const attachmentAPI = {
  /** multipart upload — backend returns 201 with the persisted Attachment. */
  upload: (file: File, conversationId?: string) => {
    const fd = new FormData();
    fd.append('file', file);
    if (conversationId) fd.append('conversationId', conversationId);
    return postJSON<Attachment>('/api/v1/attachments', fd);
  },
};

/* ───────── usage (§4.2 / §4.9) ───────── */
export interface UsageByModel {
  provider: string;
  modelId: string;
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  costEstimateUsd: number;
  costKnown: boolean;
}
export interface UsageResponse {
  scope: string;
  conversationId?: string;
  period?: { since: string; until: string };
  inputTokens: number;
  outputTokens: number;
  totalTokens: number;
  costEstimateUsd: number;
  byModel: UsageByModel[];
  note?: string;
}

export const usageAPI = {
  forPeriod: (period: 'day' | 'week' | 'month' | 'all') =>
    getJSON<UsageResponse>(`/api/v1/usage?period=${period}`),
  forConversation: (id: string) =>
    getJSON<UsageResponse>(`/api/v1/usage?conversationId=${encodeURIComponent(id)}`),
};

/* ───────── metrics dashboard (§4.5) ───────── */
export interface MetricsBucket {
  source: string;
  okCount: number;
  failedCount: number;
  cancelledCount: number;
  timeoutCount: number;
  totalCount: number;
  successRatePercent: number;
  avgElapsedMs: number;
  p95ElapsedMs: number;
}
export interface MetricsResponse {
  since: string;
  until: string;
  window: string;
  buckets: MetricsBucket[];
}

export const metricsAPI = {
  tools: (since = '7d') =>
    getJSON<MetricsResponse>(`/api/v1/metrics/tools?since=${since}`),
};

/* ───────── catalog history (§4.7) ───────── */
export interface CatalogHistoryEntry {
  id: string;
  version: number;
  fingerprint: string;
  generatedBy: string;
  generatedAt: string;
  summary: string;
  coverage: Record<string, string[]>;
}
export interface CatalogDiff {
  from: number;
  to: number;
  fromFp: string;
  toFp: string;
  added: Record<string, string[]>;
  removed: Record<string, string[]>;
}

export const catalogHistoryAPI = {
  list: (limit = 50) =>
    getJSON<CatalogHistoryEntry[]>(`/api/v1/catalog/history?limit=${limit}`),
  diff: (from: number, to: number) =>
    getJSON<CatalogDiff>(`/api/v1/catalog/diff?from=${from}&to=${to}`),
};

/* ───────── context stats (§4.8) ───────── */
export interface ContextSection {
  section: string;
  chars: number;
  estTokens: number;
}
export interface ContextStats {
  conversationId: string;
  sections: ContextSection[];
  static: { chars: number; estTokens: number };
  history: { inputTokens: number; outputTokens: number };
  note: string;
}

export const contextStatsAPI = {
  forConversation: (id: string) =>
    getJSON<ContextStats>(`/api/v1/conversations/${encodeURIComponent(id)}/context-stats`),
};
