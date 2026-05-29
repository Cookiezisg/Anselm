import type { ModelCapability } from "./types";

// Exact (provider, modelId) lookup — avoids partial matches on prefix-similar model IDs.
//
// 精确匹配 (provider, modelId)；避免前缀相似的 modelId 误命中。
export function capabilityFor(
  caps: ModelCapability[],
  provider: string,
  modelId: string,
): ModelCapability | undefined {
  return caps.find((c) => c.provider === provider && c.modelId === modelId);
}
