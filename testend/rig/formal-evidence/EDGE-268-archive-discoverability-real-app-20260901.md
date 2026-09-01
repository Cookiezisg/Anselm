# EDGE-268 L5 · 驻地分组批量归档重跑 · 真实 App 可发现性

## 现场路径

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-235910`
- Recording: `screen.mov`, `3104x1844`, `60fps`, `112.430s`
- Relevant frames: `screen.mov` at approximately `81s` (hovered group row), `82s` (group
  action menu), and the sealed confirmation frame `frames-l3/f00220.png`.
- Product goal: archive every conversation in a named workdir group without touching pinned
  conversations.

## Discoverability result

The normal Chat rail exposes the named workdir group and its conversation count. Hovering the
group reveals the `…` action affordance; opening it presents the plain-language action
`Archive all conversations`, alongside the separately colored destructive `Delete all
conversations` and the unrelated `Reveal in Finder`. This gives a user a direct route from the
visible group to the intended bulk action without knowing an API, command, or internal entity
name.

The next confirmation state makes the consequence explicit before commitment: it says that `2`
conversations move to the archive, that they can be brought back, and that pinned threads are
left alone. The user can therefore distinguish archive from delete and verify scope before
confirming. After confirmation, the group disappears from the active rail while the unrelated
Recents conversation remains available.

## Boundary

This is a discoverability judgment only. The companion L4 evidence covers visual craft and the
companion L3 evidence covers transition smoothness; neither is reused as the basis for this
claim. The path was exercised in the real App under the same sealed five-channel session.

## Judgment

`G1` pass. A first-time user can locate the group action from the normal Chat surface, identify
the intended archive operation, understand its scope and reversibility, and complete it without
internal knowledge.
