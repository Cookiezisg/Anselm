# EDGE-259 · ledger and alarm re-audit

- item: `EDGE|切分支名拼错`
- judgments: L2=`F2`, L3=`B2`, L4=`C5`, L5=`G1`
- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-211452`
- red/fixed evidence: `EDGE-259-branch-typo-real-app-20260831.md`

The ledger accepted all four new levels only after the level-2 session-local witness and the
fixed real-App evidence were present. The initial L2 attempt using a repository-level evidence
file was refused by `judge.py`; the correction proves the session binding is active rather than
being bypassed.

After each level, `discovery-collapse` was re-audited and acknowledged. After the final level,
the original `gap-too-fast` and `discovery-collapse` signals were also re-audited and
acknowledged. The review checked the 10/10 anchor calibration, the red-to-fixed recording pair,
the backend 404, the unchanged `main` projection, the remote-only ref, and all five channel
journals. No threshold, curve algorithm, CODEX law, anchor answer, five-level standard, or
sequence gate was changed.

Final checks: `gen_coverage.py --check` reports `848 rows, 848 carried judgments, 0 tombstones`;
anchors report `10/10`; the final alarm check was clean after the last acknowledgement. The
next autonomous frontier remains `EDGE|worktree 目录已存在`; forced/manual interaction stays
in its queue.
