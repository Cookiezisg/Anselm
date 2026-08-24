# SURF-085 · ledger/alarm independent re-audit

- source session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-021948`
- excluded red session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-021142`
- scope: five SURF-085 judgments only; no threshold, law, anchor, or gate changes.

The red session correctly stopped on the Chinese Chat placeholder leak. The source locale, generated slang output, and bilingual regression were then repaired before the green session. The green session was freshly launched and exercised the same Library → Skill → Chat path.

The green evidence is independently re-read across all five channels: final frame shows `想聊点什么？` and the complete two-row answer; the LLM response contains both `5` documents and `3` skills; SSE durable sequences are monotonic; SQLite is intact; backend has no application redline; frontend has only the known macOS IMK host warning. The temporary `gap-too-fast` signal from serialized five-level writes is statistical batching, not a product regression; it is acknowledged here without changing the alarm algorithm or threshold.

Conclusion: the five judgments are admissible and the alarm state remains governed by the unchanged gate.
