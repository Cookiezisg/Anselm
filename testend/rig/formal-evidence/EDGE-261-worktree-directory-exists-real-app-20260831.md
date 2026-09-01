# EDGE-261 · worktree 目录已存在

## 现场

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-213052`
- workspace: `ws_0d8de0e2205b8498`
- conversation: `cv_cfd1940740935016`
- repository: `/private/tmp/anselm-edge261-repo.JMXK9e`
- collision path: `/private/tmp/anselm-edge261-repo.JMXK9e-taken`
- fixed frame: `EDGE-261-worktree-directory-exists-fixed.jpg`
- recording: `screen.mov`, `3104x1844`, finalized duration `430.556667s`

The real App mounted the real Git repository on `main`. A sibling directory with the
requested name already existed and contained `SENTINEL.txt`. Computer Use opened the
conversation worktree dialog, entered `taken`, and clicked `Open worktree`.

## Result

The backend journal records the real request:

```text
POST /api/v1/conversations/cv_cfd1940740935016/workdir:add-worktree 409
```

The App kept the dialog open, preserved `taken`, and showed the complete recovery copy:
`That folder already exists. Pick another name, or switch this conversation into it from the menu.`
The final frame has no ellipsis, clipping, blank state, or layout jump.

The collision directory was not taken over: its sentinel hash remained
`70e85898d13a5318b2a0c59dad361eb2d9cd5be94208b5b16a3e1c21cc31c4cb`. The mounted
repository remained on `main`; no `wt/taken` branch or new worktree was created.

## Five channels

- frame: Computer Use inspected the dialog before and after submit; the error state and
  recovery action are fully visible in `EDGE-261-worktree-directory-exists-fixed.jpg`.
- backend: `backend.log` records the 409 refusal and no warning, error, panic, or fatal line.
- SSE: `sse.jsonl` has the independent messages, entities, and notifications connections;
  the refusal produced no false mutation signal.
- frontend: `frontend.log` has only the known macOS IMK/TSM diagnostics; no Dart, Flutter,
  RenderFlex, overflow, or unhandled application error.
- LLM wire: `llm.jsonl` records the managed challenge/install/models bootstrap through the
  real recording tap. This Git refusal does not require a chat completion, so none is
  claimed.

`rig-check` passed all five channels and `rig-down` finalized the recording and collected
all owned processes.

## Five levels

- L2 `F2`: the visible refusal, HTTP 409, durable workdir projection, repository branch,
  collision sentinel, and absence of a created worktree agree.
- L3 `B2`: the refusal is immediate and deterministic; the input remains available for
  correction and the user receives a direct next step rather than a dead-end dismissal.
- L4 `C5`: the final dialog preserves the original input, uses a bounded error line that is
  fully readable, and keeps the primary action available without clipping or reflow.
- L5 `G1`: a normal user can recover from the sentence alone by choosing another name or
  switching into the existing worktree; Git internals are not required.

Focused regression from `testend` also passed:

```text
go test ./scenarios -run '^TestChatWorkDirGit_WorktreeOneShot$' -count=1 -v
```
