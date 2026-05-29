// FSD cross-slice public API for entities/conversation.
// Exposes ThinkingSpec so ModelRef can carry thinking config without
// conversation re-defining the type.
//
// 给 entities/conversation 用的 cross-slice 出口；只暴露 ThinkingSpec 类型。
export type { ThinkingSpec } from "../model/types";
