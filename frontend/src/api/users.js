// User (local profile) CRUD hooks. Backend identifies the active user
// via X-Forgify-User-ID header (or ?userID= for SSE); switching the
// active user in the UI is a settings.set({ activeUserId }) call +
// global queryClient.invalidateQueries() so all per-user data refreshes.
//
// 本地 profile CRUD；切换 user = 改 settings.activeUserId + 全量 invalidate。

// user hooks 已迁移至 entities/user (FSD 阶段2);此处转 re-export 保持调用点零改。
export { useUsers, useCreateUser, useUpdateUser, useDeleteUser } from "@entities/user";
