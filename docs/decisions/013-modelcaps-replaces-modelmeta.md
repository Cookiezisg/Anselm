---
id: ADR-013
title: modelcaps replaces modelmeta
status: accepted
date: 2026-05-30
supersedes:
superseded-by:
---

# ADR-013: modelcaps replaces modelmeta

## Status

accepted — 2026-05-30

## Context

`pkg/modelmeta` stored static model metadata (context window, max output). It could not express per-provider-and-model capability differences (thinking shape, tool call support variance) or allow user-level overrides without code changes.

## Decision

Replace with `pkg/modelcaps`: per-(provider, model) ability catalog using family rules + per-model precise overrides. `CapabilityService.ResolveCapabilities` merges: user override (`model_cap_overrides` table) > static per-model rule > family default.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Extend modelmeta with override table | Same problem — the abstraction was too flat; needed a full resolution pipeline |
| Hardcode per-model capabilities | Cannot be updated without code deployment; no user override path |

## Consequences

**Positive:**
- Users can override capability assumptions without code changes
- Handles provider-specific thinking shapes (Anthropic budget_tokens vs Gemini thinkingConfig)
- Per-model precision where family rules are wrong

**Negative / Trade-offs:**
- More complex resolution pipeline (three-tier merge)
- Static rules must be kept current as providers release new models
