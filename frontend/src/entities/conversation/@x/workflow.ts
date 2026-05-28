// FSD cross-slice public API for entities/workflow.
// Exposes ModelRef (stable apiKeyId+modelId pair) so NodeSpec can carry
// a per-node modelOverride without conversation re-defining the type.
//
// 给 entities/workflow 用的 cross-slice 出口;只暴露 ModelRef 类型。
export type { ModelRef } from "../model/types";
