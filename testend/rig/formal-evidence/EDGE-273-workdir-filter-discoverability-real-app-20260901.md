# EDGE-273 L5 · `?workDir=` 三态 presence · 真实 App 可发现性

## 现场路径

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-093314`
- Product goal: distinguish conversations in a named workdir from conversations with no workdir.

## Discoverability result

The ordinary Chat rail exposes the named workdir as a folder-like group and exposes unmounted
threads under the plainly named `Recents` section. The group counts are visible (`2` and `3`), and
the user can expand either header directly. No user needs to know the `workDir` query parameter,
query-key presence semantics, or conversation IDs. The observed result makes the important product
meaning discoverable: a thread with no residency is not silently included in a named folder, and a
named folder does not absorb Recents.

The fixture intentionally included two mounted threads, two unmounted test threads, and the seeded
unmounted demo thread. The user-visible separation therefore exercised the normal path with both
states present rather than a one-state empty example.

## Boundary

This is a discoverability judgment only. The companion L3 evidence covers transition behavior and
the companion L4 evidence covers visual craft; neither is reused as the basis for this claim.

## Judgment

`G1` pass: a first-time user can discover and understand the mounted/unmounted split from the
normal Chat rail without internal API knowledge.
