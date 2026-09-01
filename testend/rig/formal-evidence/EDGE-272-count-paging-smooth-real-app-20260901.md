# EDGE-272 L3 · 分组计数跨翻页不漂移 · 真实 App 顺滑性

## 现场

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-091811`
- Recording: `screen.mov`, `3104x1844`, `60fps`, `138.343s`
- Fixture: workdir group `/private/tmp/anselm-edge272-group-20260901`
- Product action: Computer Use opened the real Chat rail group and scrolled through the loaded
  group rows while the group was expanded.

## Smoothness result

The group head showed `31` before the tail rows were loaded and still showed `31` after the
scroll. The visible rows changed as expected for user-directed scrolling; there was no blank
group, duplicate row, stale `7`/`6` count, blocking spinner, or unexplained reflow. The live
Computer Use screenshots and the sealed recording show the same stable group header before and
after the pagination boundary. The extracted 1fps inspection frames include the final top and
tail states (`f0078`, `f0098`, `f0099` in `/private/tmp/edge272-frames-1fps/`).

This is a stateful pagination path, so the evidence does not claim an artificial millisecond
latency for the user's scroll. It claims the product-visible invariant that loading more rows
does not interrupt the user's reading position or rewrite the group total.

## Cross-check

- The group projection remained `activeCount=31`, `archivedCount=1` after every one of 16 API
  pages, while the real App showed the same active total.
- No frontend Flutter/Dart/RenderFlex/overflow/Unhandled application error was recorded; only
  the known macOS IMK diagnostic was present.
- `rig-check.sh` passed before the interaction and `rig-down.sh` passed after it; the recording
  and all owned processes were collected.

## Judgment

`B2` pass: the user-triggered scroll and pagination transition preserve the existing group
header and provide the next rows without an unrequested jump, blank state, or loading residue.
