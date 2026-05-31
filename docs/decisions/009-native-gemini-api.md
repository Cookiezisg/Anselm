---
id: ADR-009
title: Native Gemini generateContent, no OpenAI shim
status: accepted
date: 2026-05-30
supersedes:
superseded-by:
---

# ADR-009: Native Gemini generateContent, no OpenAI shim

## Status

accepted — 2026-05-30

## Context

Google provides both a native `generateContent` API and an OpenAI-compatible endpoint. The OpenAI shim would allow reusing existing OpenAI provider code. However, the native API exposes capabilities the shim doesn't: `thoughtSignature` round-tripping (required for Gemini 3 multi-turn tool loops), `thought: true` reasoning parts, and `systemInstruction`.

## Decision

Implement a native `geminiProvider` targeting `v1beta` `streamGenerateContent?alt=sse`:
- Model in URL path (not request body)
- `x-goog-api-key` header auth
- `contents/parts`, `systemInstruction`, `tools.functionDeclarations`
- `generationConfig.thinkingConfig` for reasoning
- Round-trip `thoughtSignature` for Gemini 3 multi-turn

## Rejected Alternatives

| Alternative | Reason Rejected |
|---|---|
| OpenAI-compat shim | Cannot round-trip `thoughtSignature`; no reasoning part access |

## Consequences

**Positive:**
- Full Gemini 3 multi-turn tool loop support
- Reasoning text (`thought: true` parts) accessible
- `thoughtSignature` preserved across turns

**Negative / Trade-offs:**
- Separate code path from other providers
- Changes to Gemini API require updating native implementation
