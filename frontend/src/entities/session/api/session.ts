import { apiFetch, pickList } from "@shared/api";
import type { User } from "@entities/user/@x/session";

// Direct apiFetch — no TanStack cache layer — so resolve always sees the
// network-fresh list, never a stale query snapshot.
//
// 不经 TanStack 缓存直接 fetch，确保 resolve 永远基于最新 /users 数据。
export function fetchUsers(): Promise<User[]> {
  return apiFetch("/users").then(pickList<User>);
}
