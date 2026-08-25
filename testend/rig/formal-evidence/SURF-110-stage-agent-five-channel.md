# SURF-110 stage/agent five-channel evidence

- **Frames / Computer Use**: session screen recording finalized at `572.313333s`, `2784x1808`; settled frame shows the v2 prompt and preserved `greet`, `上手指南`, `anselm-auto`, metadata and version. Representative post-settle frames are under `sessions/20260825-100206/evidence/frames/`.
- **Backend journal**: 714 lines. The only WARNs are the two deliberately malformed create attempts and one expected context-cancelled finalize retry; no panic/fatal or unexplained application failure.
- **SSE witness**: all three streams connected. Durable sequences are `messages 1..77` (77 unique), `entities 7..10` (4 unique), and `notifications 16..19` (4 unique), with no gap or duplicate. The messages close contains the successful v2 answer and final `stopReason=end_turn`.
- **Frontend console**: 5 lines; no Flutter/Dart/RenderFlex/Unhandled error. The only platform error is the known macOS `IMKCFRunLoopWakeUpReliable` noise, disclosed rather than suppressed.
- **LLM wire**: 47 journal lines; managed proof/install/models and chat completions are recorded, with 30 observed upstream responses all HTTP 200. Request bodies and response bodies are retained in the session directories.

The REST readback was independently checked against `ag_5f61179bfce0af74`: active v2, exact document/function references, full model override object, preserved metadata, and the appended prompt sentence.
