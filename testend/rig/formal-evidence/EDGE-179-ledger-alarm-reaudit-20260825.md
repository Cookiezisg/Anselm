# EDGE-179 ledger alarm re-audit

- 触发：本格五格按协议连续入账，统计窗口可能出现裁决间隔/发现率警报。
- 复审对象：`testend/rig/formal-evidence/EDGE-179-search-first-download-shutdown-20260825.md`。
- 复审结论：`TestBuiltin_CloseBoundedDuringDownload` 以 `-race` 证明首用 installer cancellation、Close bounded return 与锁释放；真实下载/App 五通道未执行，L2-L5 保持 `na`。
- 处置：仅按本复审记录串行 ack；不改阈值、算法、法典或锚点。
