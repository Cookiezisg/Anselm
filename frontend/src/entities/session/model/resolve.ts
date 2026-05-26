import { useSessionStore } from "./sessionStore";
import { fetchUsers } from "../api/session";

// resolveSession — identity resolution always based on a fresh /users fetch.
// Mirrors computeBootState's onboarding/valid logic (boot.js) but the data
// source is a direct network call, never a stale TanStack snapshot.
//
// 永远基于 fresh /users 解析身份；复刻 boot.js computeBootState 的判定；
// stale/null currentUserId → 选 users[0]，绝不从 stale 喂回循环。
export async function resolveSession(): Promise<void> {
  const s = useSessionStore.getState();
  s.setStatus("loading");
  const users = await fetchUsers();
  if (users.length === 0) {
    s.setStatus("onboarding");
    return;
  }
  const valid = !!s.currentUserId && users.some((u) => u.id === s.currentUserId);
  if (!valid) s.setCurrentUser(users[0].id);
  s.setStatus("ready");
}
