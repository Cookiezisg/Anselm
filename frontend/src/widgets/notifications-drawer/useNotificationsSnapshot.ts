// Notifications REST snapshot — read recent notifications without subscribing
// to SSE. SSE delivery itself is in app/sse/useNotifications.js.
//
// 通知 REST 快照；SSE 推送在 app/sse/useNotifications.js。

import { useQuery } from "@tanstack/react-query";
import { apiFetch, pickList } from "@shared/api/httpClient";
import { qk } from "@shared/api/queryKeys";
import { useSessionStore } from "@entities/session";

export function useNotificationsSnapshot(limit = 50) {
  const uid = useSessionStore((s) => s.currentUserId);
  return useQuery({
    queryKey: qk.notificationsSnap(),
    queryFn: () => apiFetch(`/notifications?limit=${limit}`, { headers: { Accept: "application/json" } }),
    select: pickList,
    enabled: !!uid,
  });
}
