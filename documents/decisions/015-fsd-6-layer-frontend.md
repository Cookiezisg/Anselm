---
id: ADR-015
title: FSD 6-layer architecture for frontend
status: accepted
date: 2026-05-27
supersedes:
superseded-by:
---

# ADR-015: FSD 6-layer architecture for frontend

## Status

accepted — 2026-05-27

## Context

The original frontend had a flat component structure with mixed concerns, circular dependencies, and no clear rules for where new code should live. During the V1.2 revamp, a scalable architecture was needed. Feature-Sliced Design (FSD) emerged from the React community as a disciplined approach for complex frontends.

## Decision

Adopt FSD 6-layer architecture with strict downward dependency rules:

```
app → pages → widgets → features → entities → shared
```

Enforced by `steiger` + `eslint-plugin-boundaries` at lint time (`make lint-frontend`). Each slice exposes a public API via `index.ts` barrel only.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Flat component structure | Previous state — circular dependencies, no ownership clarity |
| Next.js app router conventions | Not using Next.js; Wails desktop doesn't benefit from SSR conventions |
| Domain-driven folder structure | Less community tooling; FSD has steiger for automated enforcement |

## Consequences

**Positive:**
- Dependency rules enforced by tooling, not convention
- New features follow a predictable placement pattern
- DIP pattern resolves shared↔upper-layer communication cleanly

**Negative / Trade-offs:**
- `index.ts` barrel required per slice (boilerplate)
- Learning curve for engineers unfamiliar with FSD
- `steiger` adds ~2s to lint time
