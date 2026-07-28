---
id: WRK-026-HISTORY
type: working
status: active
owner: @weilin
created: 2026-07-29
reviewed: 2026-07-29
review-due: 2026-10-27
audience: [human, ai]
---

# History · 已收口战役与旧体系

## 已收口的相关战役

| 工作 | 状态 | 可继承的结论 | 当前入口 |
|---|---|---|---|
| WRK-082 · 全模态平台 | archived | `MediaRef` 为跨执行面的值类型；生成是工具；真实媒体验收需保留线缆与字节 | [归档原文](../../archive/multimodal-output/README.md)；ADR 0013–0020 |
| WRK-085 · BYOK 治理 | active | 写入受管、读取目录；BYOK 多模态输入开放；目录能力与方言实现分工 | [工作原文](../byok-governance/README.md) |
| 旧 Iteration Loop | superseded as structure | 八拍循环、先泛化后修、后端真相裁决仍有效；其场景表不再代表当前覆盖 | [`legacy/`](legacy/) |

## legacy 的地位

`legacy/` 保存重构前的文档原貌，供定位旧 finding、历史覆盖快照和系统正确性线索使用：

- `README.md`：旧操作手册。
- `TASKS.md`：旧任务索引。
- `ARCHIVE.md`：旧的已探格与 frontier。
- `COVERAGE.md`：2026-07-02 冻结产品面的 649 行快照，**不是当前覆盖率**。
- `LOG.md`：旧 finding 索引。
- `systems-correctness.md`、`leak-hunt-0717.md`：系统性风险历史。

旧材料可以触发 reprobe，但不能直接宣称“已通过”。要复用其中一个结论时，在当前 `FRONTIER.md` 建立新的路径，按当前路由、媒体与网关边界重新判定。
