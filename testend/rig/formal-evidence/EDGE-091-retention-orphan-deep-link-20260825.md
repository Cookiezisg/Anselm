# EDGE-091 保留清理后的孤儿深链

- **结论**：pass（frontend scheduler regression）
- **验证目标**：run 所属 workflow 被清理/删除后，run 深链仍可打开；workflow 404、钉版图缺失被诚实呈现为 host-deleted/tombstone，不白屏、不伪造当前图；不可解析 id 显示可行动句子。
- **Focused command**：`cd frontend && mise exec -- flutter test test/features/scheduler/scheduler_run_test.dart test/features/scheduler/demo_fixture_test.dart`
- **结果**：77 tests passed。覆盖 orphan run 的 host 404、墓碑徽标、仅 replay 操作、无图 fallback、不可解析深链句子，以及 run flagship 在真实 fixture 下不 blank。

Levels 2-5 are intentionally `na`: this is a deterministic frontend fixture/UI regression; no independent Computer Use frame, timing, beauty, or discoverability session was captured in this ledger cell.
