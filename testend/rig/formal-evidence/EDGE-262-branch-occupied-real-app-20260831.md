# EDGE-262 · worktree 分支已存在

## 现场

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-215145`
- workspace: `ws_ecf86636e456d809`
- conversation: `cv_4906192ef9d5a0a0`
- repository: `/private/tmp/anselm-edge262-repo.pq0ZA4`
- occupied worktree: `/private/tmp/anselm-edge262-other-worktree.pq0ZA4`
- reusable worktree: `/private/tmp/anselm-edge262-repo.pq0ZA4-kept`
- fixed frame: `EDGE-262-branch-occupied-fixed.jpg`
- pre-fix frame: `EDGE-262-branch-occupied-red.jpg`

The real App mounted the fixture repository and first reused the existing `wt/kept`
branch, creating the sibling worktree and moving the conversation into it. The fixture
then kept `wt/occupied` checked out in a different directory while leaving the derived
`...-occupied` target absent. Computer Use entered `occupied` and submitted the same
worktree action.

## Stop and fix

The first real run exposed a product defect: the frontend reduced Git stderr to its first
line, hiding the path that explains where the branch was already checked out. The run
was stopped before judgment. `_gitReason` now preserves the complete backend-forwarded
stderr, and the focused frontend regression was rerun successfully.

## Result

The fixed real App kept the dialog open and displayed the complete actionable error:

```text
Git refused: Preparing worktree (checking out 'wt/occupied')
fatal: 'wt/occupied' is already used by worktree at '/private/tmp/anselm-edge262-other-worktree.pq0ZA4'
```

The backend journal records the real refusal:

```text
POST /api/v1/conversations/cv_4906192ef9d5a0a0/workdir:add-worktree 422
```

The first line and the full occupied-worktree path are visible in the fixed frame with
no clipping or overflow. The repository remains on `main`; `wt/occupied` remains owned by
the external worktree; the derived occupied target was not created; the conversation
remains in the previously created `...-kept` worktree. The successful reuse path and the
occupied-branch refusal therefore both hold in one real fixture.

## Five channels

- frame: Computer Use inspected the fixed dialog and the pre-fix red state; the complete
  stderr is visible in `EDGE-262-branch-occupied-fixed.jpg`.
- backend: `backend.log` records the 422 refusal and no warning, error, panic, or fatal
  application log.
- SSE: `sse.jsonl` has independent messages, entities, and notifications connections;
  the refusal emits no false mutation signal.
- frontend: `frontend.log` has only the known macOS IMK diagnostic; no Dart, Flutter,
  RenderFlex, overflow, or unhandled application error.
- LLM wire: `llm.jsonl` records the managed challenge/install/models bootstrap through
  the real recording tap. This Git action does not require a chat completion, so none is
  claimed.

`rig-check` passed all five channels while the App and recorder were live. The session
was then ready for `rig-down` finalization without leaving an owned process behind.

## Five levels

- L2 `F2`: HTTP 422, visible complete stderr, durable workdir, Git worktree list, and
  target-directory absence agree.
- L3 `B2`: the refusal is immediate, preserves the entered name, and explains the exact
  conflicting directory instead of presenting an opaque failure.
- L4 `C5`: the bounded dialog wraps the evidence cleanly; both stderr lines remain
  readable and the retry action remains available without layout damage.
- L5 `G1`: a user can choose a different branch name or resolve the named external
  worktree directly; no Git diagnosis is required beyond the presented path.

Focused regression:

```text
cd frontend && mise exec -- flutter test test/features/chat/ui/chat_work_dir_button_test.dart
00:01 +23: All tests passed!
```
