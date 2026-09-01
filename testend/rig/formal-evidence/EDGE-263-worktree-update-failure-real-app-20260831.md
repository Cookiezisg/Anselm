# EDGE-263 · worktree 建成后切驻地失败

## 现场

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-221640`
- workspace: `ws_cee284e99b62b8d4`
- conversation: `cv_f7eece35070559f0`
- repository: `/private/tmp/anselm-edge263-repo.qGepjk`
- created worktree: `/private/tmp/anselm-edge263-repo.qGepjk-partial`
- fixed frame: `EDGE-263-worktree-update-failure-fixed.jpg`
- pre-fix frame: `EDGE-263-worktree-update-failure-red.jpg`

The real App created a fresh conversation, mounted the real Git repository on `main`,
and completed a managed-gateway baseline chat (`EDGE263-BASELINE-FIXED`). Computer Use
opened the worktree action, entered `partial` with the real keyboard, and submitted it.
The acceptance-only `ANSELM_RIG_FAIL_WORKDIR_UPDATE=1` seam failed only the final
conversation-residency persistence step after Git had created the worktree.

## Stop and fix

The first real run returned an unmapped 500 and the App incorrectly said:
`That did not work, and nothing was changed. Try again.`. This was false: Git had already
created the sibling worktree. The run was stopped before judgment. The service now returns
the structured `CONVERSATION_WORKTREE_RESIDENCY_UPDATE_FAILED` error with `details.path`;
the App maps it to an explicit partial-state recovery message rather than claiming that
nothing changed. Focused backend normal/race tests and the frontend workdir suite passed
after the fix.

## Result

The fixed real App kept the dialog open, preserved `partial`, and displayed:

```text
The worktree was created, but this conversation stayed in its current directory. Switch to it from the menu before trying again.
```

The backend journal records the real action as HTTP 500. The durable conversation remains
on `/private/tmp/anselm-edge263-repo.qGepjk` with `branch=main`; it was not falsely moved
to the new worktree and no workdir marker was emitted. Git independently proves both
directories exist, the new directory is on `wt/partial`, and both trees point at commit
`99e9a70`.

A second real request for the same name returned HTTP 409
`CONVERSATION_WORKTREE_EXISTS` with the derived path, proving the created worktree was
not silently discarded and that retrying does not create a second checkout.

## Five channels

- frame: Computer Use inspected the fixed dialog; the complete partial-state message, input,
  and retry action are visible in `EDGE-263-worktree-update-failure-fixed.jpg`.
- backend: `backend.log` records the real add-worktree request as 500 with no panic, fatal,
  unmapped-error, or application error line; the subsequent duplicate request is 409.
- SSE: `sse.jsonl` independently connected `notifications`, `messages`, and `entities`;
  the failed residency write emitted no false workdir mutation signal.
- frontend: `frontend.log` contains only the known macOS IMK diagnostic; no Dart, Flutter,
  RenderFlex, overflow, unhandled exception, or application error.
- LLM wire: `llm.jsonl` records managed challenge/install/models and two real chat
  completions, including the baseline response `EDGE263-BASELINE-FIXED`, all successful.

`rig-check` passed all five channels while the App and recorder were live. `rig-down`
finalized the `234.660000s` recording and stopped all conductor-owned processes.

## Five levels

- L2 `F2`: the visible partial-state message, HTTP failure, durable old residency, Git
  worktree list, and duplicate-name 409 agree on the actual half-state.
- L3 `B2`: the failed action resolves immediately into a stable, actionable state; the
  entered name remains available and the user is told exactly how to recover.
- L4 `C5`: the bounded dialog wraps the longer recovery copy cleanly; the red message is
  readable, the input is aligned, and the primary action remains available without
  clipping, overflow, or reflow damage.
- L5 `G1`: a normal user can recover from the message alone by switching into the created
  worktree from the menu; no Git internals or acceptance-rig knowledge is required.
