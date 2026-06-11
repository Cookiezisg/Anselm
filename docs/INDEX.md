# Forgify Documentation Index

> AI session entry point. Read this first, then follow links.

## What Are You Looking For?

| Question | Go here |
|---|---|
| System architecture, phase roadmap, vision | `concepts/architecture.md` |
| Engineering rules + work discipline (S/T/N/D/E series) | `../CLAUDE.md` |
| Doc governance (types, mutability, sync rules) | `GOVERNANCE.md` |

## Status — docs reset (V0.2 → V-next)

The reference layer (API / DB / events / error-codes / 36 backend domains / frontend slices),
the ADRs (`decisions/`), the how-to guides, and the working/archive notes were **cleared** at the
V0.2 → V-next reset: the backend rewrite is complete and about to be covered back, and the frontend
will be rebuilt — docs will be **regenerated against the new structure** as it lands.

Only the two survivors are kept here: `concepts/architecture.md` (the north star) and `GOVERNANCE.md`
(how docs are organized).

**The previous version's complete docs are archived on the `version-0.2` git branch.** Recover any
of them with, e.g., `git checkout version-0.2 -- docs/references/backend`.

## Authority Hierarchy

`CLAUDE.md` > `concepts/architecture.md` > `GOVERNANCE.md`
