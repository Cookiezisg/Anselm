---
id: ADR-014
title: Sandbox v2 with embedded mise binary
status: accepted
date: 2026-05-13
supersedes:
superseded-by:
---

# ADR-014: Sandbox v2 with embedded mise binary

## Status

accepted — 2026-05-13

## Context

Sandbox v1 required users to have Python/Node/etc. installed separately. The install experience was poor and fragile — different system versions caused reproducibility issues.

## Decision

Bundle `mise` (a polyglot version manager) binary via `go:embed`. `make resources` downloads the platform-appropriate binary to `mise/<goos>-<goarch>/`. The embedded binary manages sandbox runtime installation. Sandbox v1 is deprecated.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Require system Python/Node | Poor install experience; version inconsistencies |
| Bundle full Python/Node runtimes | Binary size too large (~500MB+) |
| Docker-based sandbox | Requires Docker daemon; heavy dependency for desktop app |

## Consequences

**Positive:**
- Zero external dependencies for sandbox setup
- Reproducible runtime versions across machines
- Self-contained single binary (mise handles runtime management)

**Negative / Trade-offs:**
- Binary size increases (~30MB for mise)
- `make resources` must be run once before `make e2e`
- Platform-specific binaries must be kept current with mise releases
