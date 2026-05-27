import { delJSON, getJSON, postJSON } from "./devClient";

export const mockLLMAPI = {
  push: (scripts: unknown[]) => postJSON<{ pushed: number }>("/dev/mock-llm/scripts", { scripts }),
  queue: () => getJSON<{ scripts: unknown[]; count: number }>("/dev/mock-llm/queue"),
  clear: () => delJSON<void>("/dev/mock-llm/scripts"),
  lastPrompt: () => getJSON<{ messages: unknown[]; tools?: unknown[]; capturedAt?: string }>("/dev/mock-llm/last-prompt"),
};
