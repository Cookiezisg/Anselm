import { getJSON } from "./devClient";

export interface LLMTraceEntry {
  startedAt: string;
  endedAt?: string;
  provider: string;
  model: string;
  scenario?: string;
  inputTokens?: number;
  outputTokens?: number;
  status: "ok" | "error" | "cancelled";
  errorCode?: string;
  errorMessage?: string;
}

export const traceAPI = {
  list: () => getJSON<LLMTraceEntry[]>("/dev/llm/trace"),
};
