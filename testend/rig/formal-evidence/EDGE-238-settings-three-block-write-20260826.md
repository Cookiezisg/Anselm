# EDGE-238 · settings 三段整体写

## L1 focused evidence

- `backend/internal/app/settings/settings_test.go:TestPatch_PersistsAndHotSwaps`、`TestPatchNetwork`、`TestRetention_CrossBlockPreservation` 通过，PATCH 单段后 limits/network/retention 其余段仍保留。
- Flutter `s5_storage_limits_test.dart` 覆盖 limits、retention、reset 的 wire 驱动与错误回收；33 tests passed。

## 判定

L1=`F1`：设置 UI/API/磁盘的三段持久化不互相抹除。L2-L5 本轮未重新走真实 Settings App 录屏，记 `na`。
