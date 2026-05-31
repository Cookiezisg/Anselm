---
id: ADR-011
title: CEL for workflow conditions
status: accepted
date: 2026-05-31
supersedes:
superseded-by:
---

# ADR-011: CEL for workflow conditions

## Status

accepted — 2026-05-31

## Context

Workflow Case nodes require a condition language for branch selection. Options: custom DSL, CEL (Common Expression Language), JavaScript eval, or template string comparison.

## Decision

CEL (Common Expression Language) — the same expression language used by Kubernetes admission controllers, Firebase Rules, and Google's API filtering.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Custom DSL | No existing parser, debugger, or LLM training data; would need ongoing maintenance |
| JavaScript eval | Security risk in sandbox context; not suitable for simple boolean conditions |
| Template string comparison | Too limited for complex conditions (AND/OR, type coercion, null safety) |

## Consequences

**Positive:**
- Existing spec, test libraries, documentation
- LLMs write correct CEL expressions reliably (well-represented in training data)
- Type-safe evaluation

**Negative / Trade-offs:**
- External dependency (`google/cel-go`)
- Learning curve for engineers unfamiliar with CEL
