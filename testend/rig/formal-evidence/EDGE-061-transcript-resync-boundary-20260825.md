# EDGE-061 · transcriptResync 不可与 lifecycleResync 互顶

## Verification

The two resync signals remain distinct at the repository boundary:

- `lifecycleResync()` is backed by `StreamName.notifications` and belongs to conversation/entity/
  library lifecycle projections.
- `transcriptResync()` is backed by `StreamName.messages` and belongs to the live transcript,
  pending interaction gates, rundown, touchpoints, and activity dots.
- `ConversationListNotifier` intentionally subscribes to both because its rail contains both kinds
  of state; `ConversationStreamNotifier` subscribes only to `transcriptResync()` for live transcript
  recovery.

## Focused evidence

Command:

```text
cd frontend
mise exec -- dart format --output=none --set-exit-if-changed \
  test/features/chat/state/conversation_stream_provider_test.dart
mise exec -- flutter test \
  test/features/chat/state/conversation_stream_provider_test.dart \
  test/features/chat/state/pending_interactions_provider_test.dart \
  test/features/chat/state/conversation_list_provider_test.dart \
  test/features/chat/model/conversation_transcript_test.dart \
  test/features/chat/state/touchpoint_ledger_test.dart \
  test/features/chat/state/transcript_jump_test.dart
```

Result: **104 tests passed**. The added regression test emits a notifications resync while a live
assistant turn is open and proves the live layer remains present; it then emits a messages resync
and proves the durable completed head replaces the live turn. The suite also covers interactions
appearing/pruning across a messages gap, transcript hydration, touchpoint recovery, and jump
re-hydration.

## Five-level applicability

- L1 pass: separate stream mapping plus the cross-stream regression establish the protocol boundary.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.

