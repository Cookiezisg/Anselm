# EDGE-300 L3 丝滑证据（2026-09-01）

正式 session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-144816`。

真实 App 在 Chat ocean 中保持 approval current，用户通过 AX `Dismiss` 推进。录制的两段序列分别为 `unique-1 → unique-2 → unique-3 → unique-4 → normal-0` 和 `unique-5 → unique-6 → unique-7 → normal-1`；每次切换均保留当前卡的完整生命周期，没有瞬间跳过文字或冻结顶带。session 内 `handoff-sequence.json` 和 `fairness-cycle-2.json` 记录了每步的时间戳，关键帧在 `edge300-fairness-frames/`。

approval 卡持续可操作，普通卡在候场公平点接班；这是“顺滑且不牺牲人在环控制”的产品行为。`an_notice_capsule.dart` 的 560ms enter、420ms reverse，以及有积压时 2800ms readable dwell 与现场录屏一致。三条 SSE 流、backend、frontend 与录屏均在同一收台 session 中，`rig-check`/`rig-down` 通过。法条：A4。
