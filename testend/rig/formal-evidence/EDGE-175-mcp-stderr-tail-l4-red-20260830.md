# EDGE-175 · MCP 失败附 stderr 尾 · real App L4 red

## 判定

- Formal session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-182257`
- Level: L4 (visual craft)
- Law: `E1` (error three-part honesty)
- Verdict: `fail`

## Product defect

The final real-App frame `/private/tmp/edge175-final-20260830/final.png` shows the same
transport failure in three user-facing forms: the MCP result window, a second red `Error`
section, and the assistant's prose. The right Activity island repeats the failure again. The
main expanded card exposes `mcp tool call failed (reason=calling "tools/call": EOF)` as primary
copy, including an internal RPC method and raw EOF wording.

This is not merely duplicated audit detail. The user sees an error label, a technical string, and
an assistant explanation without one coherent failure presentation. The card does not provide a
single calm human summary of what happened and what to do next; the machine detail is not
visibly separated as optional diagnostics. The frame has no clipping or overflow, but that does
not satisfy the product craft bar.

## Cross-channel fact

The defect is bound to the same formal session as the existing L2/L3 evidence. Backend, SSE,
frontend console, and managed LLM wire all agree that this was one failed MCP call, so the red
result is a product presentation defect rather than a recording or data-integrity failure.
