# EDGE-273 L3 · `?workDir=` 三态 presence · 真实 App 顺滑性

## 现场

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-093314`
- Recording: `screen.mov`, `3104x1844`, `60fps`, `111.780s`
- Product surface: Chat rail's named workdir group and `Recents` group.

## Smoothness result

After the fixture was corrected, the real App refreshed from the same backend session and showed a
named workdir group with `2` members and `Recents` with `3` members. Expanding and collapsing the
workdir group changed only its own two rows; expanding and collapsing `Recents` changed only its
own three rows. The other group's header and count stayed in place. There was no blank list,
duplicate row, stale count, loading residue, or unrequested whole-rail reflow in the observed
transitions.

The evidence deliberately does not claim an artificial millisecond number for a short list
toggle. It establishes the product-visible invariant: a user can switch the visible section
without the rail jumping, mixing scopes, or rewriting an unrelated section.

## Cross-channel boundary

`rig-check.sh` passed before the interaction and `rig-down.sh` sealed the recording and stopped all
owned processes. The backend journal contains two preparatory `PATCH /conversations/null` 404s from
the first fixture helper attempt; those were caused by the harness extracting the new API envelope
incorrectly, were corrected before product observation, and are not presented as product failures.
No Flutter/Dart/RenderFlex/overflow/Unhandled application error was recorded.

## Judgment

`B2` pass: the real App's three-state residency sections transition without visible jump, scope
mixing, blank state, duplicate, stale count, or loading residue.
