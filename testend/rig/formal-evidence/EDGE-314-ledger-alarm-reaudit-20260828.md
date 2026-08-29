# EDGE-314 · 账本与统计警报复核

- 新增裁决：`EDGE-314 编辑器唯一光标铁律` Level 2 `pass`，法典引用 `F1`，真实五通道证据见 `EDGE-314-editor-single-caret-real-app-20260828.md`。
- 警报 `discovery-collapse` 在写入后打开，原因是最近 50 个裁决的 fail 占比为 0%；这不是降低标准或改阈值的理由。
- 复核前重新运行 `anchors.py check`：10/10 通过，anchor set hash 未变。
- 本次真实 App 证据包含录屏、backend、SSE、frontend console、LLM wire 和 rig 收台记录；没有把静态测试或历史复验冒充实机证据。
- 结论：按既有规则 ack 本次统计提示，保留原阈值、算法、法典和 sequence gate；下一格继续按未完成的 `~` 推进。
