// Re-export shim — chatStore has moved to entities/conversation/model.
// All consumers (BlockRenderer, useEventLog, tests, etc.) continue to
// import from this path unchanged.
export {
  useChatStore,
  selectTopMessageIds,
  selectBlock,
  selectChildIds,
} from "@entities/conversation";
