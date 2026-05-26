// Re-export shim — implementation lives in shared/api/sse. Import from
// here keeps existing consumers unchanged while the shared layer is built out.
//
// re-export shim：实现已迁至 shared/api/sse，此处保持现有 import 路径不变。
export * from "@shared/api/sse";
