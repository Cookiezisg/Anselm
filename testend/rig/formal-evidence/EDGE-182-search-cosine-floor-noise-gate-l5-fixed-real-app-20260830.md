# EDGE-182 cosineFloor 噪声闸：L5 修复后真实 App 可发现性

- 结论：`pass`。
- 正式路径：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-222330`。

从新对话和真实 workspace 出发，用户无需知道 cosineFloor、EmbeddingGemma、semantic-only 或内部 REST。直接说“找我的文档”即可得到两种诚实结果：对自然乱码明确显示没有匹配，不猜测；对“dependable software experience”这类不同措辞的目标，真实搜索找到 `EDGE182 Semantic Recall Fixture` 并解释其意义。用户目的分别是“确认不存在”和“找到并理解内容”，两者均在 App 内完成，没有要求打开设置、终端或重试内部索引。

Computer Use 录屏、backend、三路 SSE、frontend console 和 managed LLM wire 对同一 session 的结果相互一致；旧红场及其修复过程均保留在证据目录。

判定依据：`CODEX G1`。
