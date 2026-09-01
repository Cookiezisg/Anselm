# EDGE-272 L5 · 分组计数跨翻页不漂移 · 真实 App 可发现性

## 现场路径

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-091811`
- Product goal: inspect all conversations belonging to a workdir group without losing the
  meaning of the group total while scrolling.

## Discoverability result

The normal Chat rail exposes the named workdir group and its count directly in the group header.
A user can expand that visible group and scroll its rows in the same rail; no API, pagination
parameter, or internal conversation id is needed. The count reads as the group's total active
membership, while the separately marked pinned thread and the other workdir group communicate
their different scopes. As more rows appear, the unchanged `31` confirms the intuitive meaning
of the number instead of making it look like a per-page count.

The path was exercised in the real App with 31 active unpinned members, one archived member,
one pinned member excluded from the group, and three members in another group. The final view
therefore tests the user's natural route through a non-trivial list, not a one-row demo.

## Boundary

This is a discoverability judgment only. The companion L3 evidence covers the transition and the
companion L4 evidence covers visual craft; neither is reused as the basis for this claim.

## Judgment

`G1` pass: a new user can understand the group count and reach additional group members through
the ordinary Chat rail without knowing that the implementation uses paginated requests.
