// Issue #4 workaround: chat.Block.Attrs arrives as JSON string from REST
// and as object from SSE. Normalize to object before render.
//
// Issue #4 兜底:REST 拿到 attrs 是字符串,SSE 是对象;此处统一成对象。
import type { Block } from "@frontend/entities/conversation/model/types";

// Not a real React hook (no state/effects) — named with `use` for
// discoverability; safe to call outside components.
export function useNormalizedBlock(block: Block): Block {
  if (block.attrs && typeof block.attrs === "string") {
    try {
      return { ...block, attrs: JSON.parse(block.attrs as unknown as string) };
    } catch {
      return { ...block, attrs: {} };
    }
  }
  return block;
}

export function normalizeBlocks(blocks: Block[] | undefined): Block[] {
  if (!blocks) return [];
  return blocks.map((b) => {
    const nb = useNormalizedBlock(b);
    return nb;
  });
}
