# Contributing to Anselm

Thanks for helping. This page is the short version for people; the full engineering rules that
both people and AI agents follow live in [`CLAUDE.md`](CLAUDE.md), and the documentation rules in
[`docs/GOVERNANCE.md`](docs/GOVERNANCE.md).

## Set up

Toolchain versions are pinned in [`mise.toml`](mise.toml). Install [mise](https://mise.jdx.dev),
then:

```bash
make setup            # installs Go, Flutter, Node at the pinned versions and fetches dependencies
make -C backend run   # Go sidecar on the dev port
make -C frontend app  # desktop app against that sidecar (ANSELM_BACKEND_URL)
```

Linux desktop builds also need the system packages the CI installs in
[`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## Make a change

1. Read the reference for the area first: [`docs/INDEX.md`](docs/INDEX.md) is the entry point. The
   backend wire contract, database, events and error codes are documented precisely and the
   frontend DTOs mirror them.
2. Keep the dependency direction: `transport → app → (domain ∪ infra/store) → infra/db` in Go;
   `core → features → app` in Dart. `domain` imports no external packages.
3. Change the documentation in the same commit as the code. A reference that no longer matches
   the code is treated like a compile error, and `make -C docs verify` enforces the checkable parts.
4. Run the gate for what you touched while iterating, and the root gate before pushing:

```bash
make -C backend verify
make -C frontend verify   # or `make -C frontend quick` for the diff-driven inner loop
make -C docs verify
make verify               # everything, run before you push
```

Black-box acceptance (`make -C backend testend`) and real-model evaluations
(`make -C backend evals`) are opt-in; the second one costs money.

## Commits and pull requests

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org):
`feat(scope): …`, `fix(scope): …`, `docs: …`, `chore: …`. Release notes are generated from them.
Explain the why in the body when it is not obvious from the diff.

Open the pull request against `main`. CI runs the same gates as `make verify`; a green run is the
bar for review. Keep pull requests focused on one change, and mention which reference or ADR you
updated if the change touched a contract.

## Reporting problems

Use the issue templates. For security problems, follow [`SECURITY.md`](SECURITY.md) instead of
opening a public issue.
