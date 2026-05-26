// Re-export shim — implementation lives in shared/api. Import from here
// keeps existing 36+ consumers unchanged while the shared layer is built out.
//
// re-export shim：实现已迁至 shared/api，此处保持现有 import 路径不变。
export { apiFetch, ApiError, pickList, EMPTY_ARRAY } from "@shared/api/httpClient";
export { qk } from "@shared/api/queryKeys";
