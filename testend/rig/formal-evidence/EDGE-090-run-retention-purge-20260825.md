# EDGE-090 run 历史保留清理

- **结论**：pass（boot wiring + store retention）
- **验证目标**：保留线到期时清理旧终态 run 的 header、node rows、四类审计行；running/parked 不清；`0` 表示永久保留。
- **Focused commands**：`mise exec -- go test ./internal/bootstrap -run 'TestRetentionWiring_BootSweepPurgesPastTheLine|TestRetentionWiring_ForeverNeverSweeps' -count=1 -v`；以及 flowrun store retention focused tests。
- **结果**：Boot wiring 场景 PASS：30d 线清掉 100d old completed run，fresh 与 900d old running 存活；0 线不清 ancient completed。store cascade/boundary/batch/workspace tests 同批通过。

Levels 2-5 are intentionally `na`: no independent real-app frame, timing, beauty, or discoverability evidence was captured for retention storage governance.
