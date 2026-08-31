# EDGE-259 · 切分支名拼错 · real App 五级证据

- result: `PASS` after stop-and-fix
- session red: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-210547`
- session fixed: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-211452`
- workspace: `ws_a5dfdbd204e93a56`
- conversation: `cv_23e917c75ad8fe7f`
- fixture: `/private/tmp/anselm-edge259-repo.hPQeK6`

## Scenario

The real App mounted a real Git repository on `main`. The fixture had a local `typo-target`
branch and a matching `remotes/origin/typo-target` ref. The branch menu was opened while the
local branch existed. Before clicking the visible row, the local ref was deleted externally,
leaving only the remote ref. The stale menu row was then clicked through Computer Use.

The server returned real `404` on
`POST /api/v1/conversations/cv_23e917c75ad8fe7f/workdir:switch-branch` and the frontend mapped
the wire code to its branch-missing notice. The working-directory projection remained on
`main`; Git truth after the action was also `main` with only `remotes/origin/typo-target`. No
tracking branch was created and no residency mutation occurred.

## Stop-and-fix

The first real App frame exposed a product defect in the fixed-width top notice: the original
English copy was visually ellipsized as `That branch is gone. Reopen the menu to ...`, hiding
the recovery action. Red frame:
`EDGE-259-branch-typo-red.png`.

The copy was shortened to `Branch gone. Reopen.` without widening the shared 340px notice
island. A render-level test now asserts that this refusal copy does not exceed the one-line
paragraph limit. The fixed real App frame shows the full sentence:
`EDGE-259-branch-typo-fixed.png`.

## Five channels

- frame: Computer Use inspected the stale branch row and the fixed notice; the fixed frame has
  no ellipsis, clipping, blank surface, or layout jump.
- backend: `backend.log` records the 404 switch request; subsequent workdir read is `200`,
  still `branch=main`, `dirty=false`.
- SSE: `sse.jsonl` was connected by the independent witness; the session was shut down cleanly.
- frontend: `frontend.log` contains only the known macOS IMK diagnostic; no Dart/Flutter/
  RenderFlex/overflow/Unhandled application error.
- LLM wire: `llm.jsonl` is present and the managed bootstrap wiring is valid; this journey does
  not require a chat completion, so none is claimed.

Both sessions passed `rig-check` and `rig-down`. The fixed recording is
`3104x1844/60fps/75.398333s`; all owned processes were collected.

## Five levels

- L2 `F2`: the UI, HTTP status, durable projection, and Git refs agree on a rejected stale
  branch without DWIM tracking-branch creation.
- L3 `B2`: stale-menu failure changes the notice deterministically to an actionable recovery
  sentence; no loading loop or stale branch projection remains.
- L4 `C5`: the red frame's hidden recovery copy was fixed; the final notice is a compact,
  fully readable island with the existing close affordance and no overflow.
- L5 `G1`: the notice itself tells a normal user what happened and what to do next: reopen the
  menu; no knowledge of Git remotes or internal wire codes is required.

Focused regressions also pass:

```text
backend: go test ./internal/app/conversation ./internal/transport/httpapi/handlers ./internal/infra/gitinfo -run 'Test(SwitchBranch|WorkDir|Status|Branch)' -count=1
frontend: flutter test test/features/chat/ui/chat_work_dir_button_test.dart
frontend notice: flutter test test/core/ui/an_notice_capsule_test.dart
```
