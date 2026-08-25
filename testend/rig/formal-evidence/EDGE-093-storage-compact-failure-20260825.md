# EDGE-093 手动 VACUUM 压缩失败

- **结论**：pass（storage app failure contract）
- **验证目标**：当 VACUUM 的文件写入阶段失败时，用户得到稳定的 `STORAGE_COMPACT_FAILED` 500 语义，数据库不变且可以重试；底层失败原因只进日志，不伪装成成功或空结果。
- **Focused command**：`cd backend && mise exec -- go test ./internal/app/storage -run 'TestService_(CompactFailureIsRetryableAndPreservesDB|StatThenCompact)' -count=1 -race -v`
- **结果**：`TestService_CompactFailureIsRetryableAndPreservesDB` 以只读 SQLite handle 确定性模拟文件写入拒绝，验证 `errors.Is(err, ErrCompactFailed)`、数据库文件大小不变、`compact_probe` 行数不变；`TestService_StatThenCompact` 同组通过，确认成功路径仍可回收并保持 `migrated=false`。真实磁盘 ENOSPC 不在开发机上制造；只读句柄是对同一写失败契约的安全替身，不被记录为 ENOSPC 观测。

Levels 2-5 are intentionally `na`: no independent real-app frame, timing, beauty, or discoverability capture was made for this storage failure contract.
