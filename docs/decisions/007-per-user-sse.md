---
id: ADR-007
title: Per-user SSE subscriptions
status: accepted
date: 2026-05-12
supersedes:
superseded-by:
---

# ADR-007: Per-user SSE subscriptions

## Status

accepted — 2026-05-12

## Context

SSE subscriptions could be scoped per-resource (per conversation, per flowrun) or per-user. Per-resource is more granular but requires managing N connections per user.

## Decision

All three SSE streams subscribe by `user_id`. The client receives all events for the user and filters client-side by `conversationId`, `scope`, etc.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Per-resource SSE | Requires managing N connections per user; incompatible with the 3-stream cap (ADR-005) |
| Per-session SSE | Session concept doesn't exist in local-first single-user model |

## Consequences

**Positive:**
- Always exactly 3 connections (matches ADR-005 cap)
- No subscription management complexity
- Works perfectly for single-user local app

**Negative / Trade-offs:**
- Client receives events it doesn't need and must filter
- Multi-user (future SaaS) would require re-evaluation
