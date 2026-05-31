---
id: ADR-008
title: No shared OpenAI-compat provider (R5 refactor)
status: accepted
date: 2026-05-30
supersedes:
superseded-by:
---

# ADR-008: No shared OpenAI-compat provider (R5 refactor)

## Status

accepted — 2026-05-30

## Context

After ADR-006, infra/llm had a `openAICompatProvider` struct shared by 9 providers (deepseek, qwen, zhipu, moonshot, doubao, openrouter, ollama, custom, openai). Each provider called the shared BuildRequest/ParseStream. As provider-specific quirks accumulated (different auth headers, different thinking encoding, different tool call formats), the shared struct grew complex conditional logic.

## Decision

R5 refactor: delete `openAICompatProvider`. Each of the 9 providers gets its own complete `BuildRequest` and `ParseStream` implementation matching its official API docs exactly.

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| Keep shared struct with more conditionals | Conditional branches were already unreadable; would get worse |
| Code generation | Overkill for 9 providers |

## Consequences

**Positive:**
- Each provider file is self-contained and readable
- Provider-specific bugs are isolated; changes don't affect other providers
- Matches each provider's official API exactly

**Negative / Trade-offs:**
- ~3× more code across provider files
- Common patterns (retry, timeout) handled in shared `transport.go`
