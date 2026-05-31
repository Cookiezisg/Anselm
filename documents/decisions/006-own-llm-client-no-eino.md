---
id: ADR-006
title: Own LLM client, eject Eino
status: accepted
date: 2026-05-12
supersedes:
superseded-by:
---

# ADR-006: Own LLM client, eject Eino

## Status

accepted — 2026-05-12

## Context

Forgify originally used ByteDance's Eino framework for LLM orchestration. Eino added significant complexity: framework-specific types, opaque middleware chains, and constraints on how streaming worked. As provider requirements diverged (Anthropic native protocol, Gemini native, thinking blocks, tool calling), the framework became a bottleneck.

## Decision

Eject Eino entirely. Build `infra/llm` from scratch:
- `Provider` interface (`Name/DefaultBaseURL/BuildRequest/ParseStream`)
- Shared transport layer (`transport.go`, 120s `*http.Client`, `doRequest`, `classifyHTTPError`)
- `providerRegistry` with named providers
- Each of 11 providers fully self-contained

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Keep Eino | Framework constraints prevented native Anthropic/Gemini support; thinking blocks required hacks |
| LangChain Go | Same problem; framework-first rather than protocol-first |
| OpenAI SDK only | Cannot handle Anthropic/Gemini native protocols |

## Consequences

**Positive:**
- Each provider matches its official API exactly
- Thinking blocks, tool use, streaming all work natively
- Zero framework dependency, full control

**Negative / Trade-offs:**
- ~800 lines of infra/llm to maintain
- New provider requires implementing BuildRequest + ParseStream
