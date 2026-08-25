# EDGE-060 · lifecycleResync 六处配对

## Verification

The notifications-stream 410 contract is wired to every lifecycle consumer, not only to the
repository seam. The following six consumers subscribe to `lifecycleSignals(...)` and the same
stream's `lifecycleResync()`:

- `frontend/lib/features/chat/ui/conversation_rail.dart` — re-reads the selected conversation.
- `frontend/lib/features/chat/state/conversation_header.dart` — invalidates the open header.
- `frontend/lib/features/chat/state/conversation_list_provider.dart` — re-pages the rail.
- `frontend/lib/features/entities/state/entity_list_provider.dart` — invalidates the entity list.
- `frontend/lib/features/entities/state/detail/entity_detail_provider.dart` — invalidates detail.
- `frontend/lib/features/library/state/library_state.dart` — debounced refetch for both document tree
  and Skill list.

The source guard `frontend/test/guards/lifecycle_resync_guard_test.dart` rejects any future
notifications lifecycle consumer that lacks the paired resync subscription.

## Focused evidence

Command:

```text
cd frontend
mise exec -- flutter test test/guards/lifecycle_resync_guard_test.dart \
  test/features/chat/state/conversation_list_provider_test.dart \
  test/features/chat/state/conversation_header_test.dart \
  test/features/entities/state/entity_list_provider_test.dart \
  test/features/entities/state/detail/entity_detail_provider_test.dart \
  test/features/library/library_test.dart
```

Result: **115 tests passed**. The focused suite includes the notifications-stream 410 rail test,
which changes a conversation during the gap without emitting a lifecycle signal and verifies that
the refetch recovers the renamed row. It also covers document-tree and Skill lifecycle refetch,
held-row patching, and entity lifecycle reconciliation.

## Five-level applicability

- L1 pass: static pairing plus focused behavioral tests establish the lifecycle resync invariant.
- L2 na: no independent formal five-channel App session was captured for this row.
- L3 na: no frame-timing evidence was captured for this row.
- L4 na: no visual artifact was captured for this row.
- L5 na: no Computer Use discoverability session was captured for this row.

