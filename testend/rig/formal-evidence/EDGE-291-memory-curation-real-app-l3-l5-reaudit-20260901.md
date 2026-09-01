# EDGE-291 · memory 更新保留策展 · L3-L5 真实 App 复审

- 日期：2026-09-01
- 复审对象：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145816`
- 原始 L2 证据：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145816/evidence/EDGE-291-memory-curation-real-app-20260829.md`
- 复审依据：同场 `screen.mov`、`EDGE-291-memory-chat.jpeg`、`EDGE-291-memory-panel.jpeg`、backend/SSE/frontend/LLM 记录，以及当前代码 focused/race 回归。

## 复审结论

真实 App 的完成态从聊天回执自然落到 Memory 面板：用户能看到更新后的描述，同时金色 pin 和 `user` 来源仍然存在。聊天页的完成回执、左侧会话列表、底部 composer 和 Settings 面板均保持稳定，没有旧值回闪、残留 loading、空白内容或非用户触发的布局跳动。Memory 列表的 pin 是行内可操作控件，更新后不需要重新理解内部 source/pinned 字段。

当前代码复核了 `MemoriesController.setPinned` 的权威行内替换、`MemoryEditor` 的编辑保存路径，以及 `s4_memory_test.dart` 的列表投影、单飞 busy、错误恢复、durable signal/410 重取、编辑不取消 pin、删除和外部删除收敛场景；backend memory/tool 普通与 race 回归均通过。

## 五通道复审

- 画面与录屏：真实聊天完成帧和 Memory 面板帧已封存；面板中 `edge291-rule` 的 pin、描述、`user` 来源和日期可读。
- 后端：原 session journal 非空且无应用级错误；L2 已记录 SQLite 完整性检查通过。
- SSE：原 session 收到对应 `memory.updated` durable signal，序号单调。
- 前端：原 session 的 App 画面无错误卡、残留 spinner 或 Flutter/Dart/Layout 红线；当前 widget 回归全绿。
- LLM wire：原 session 的正式 continuation 链为 `200`，恰有一条 `write_memory` 调用并完成；本次复审不重复调用网关。

## 级别裁决

- L3 `B2`：完成态与面板切换无非用户跳变、旧值回闪或视口争夺；代码单飞与原地对账测试覆盖更新时序。
- L4 `C4`：Memory 面板的分组、列表行、pin 控件和输入控件使用既有卡片/控件圆角与间距尺度；封存关键帧未见错位、裁切或不一致高度。
- L5 `G1`：从 Settings → Memory 可直接找到列表、Pinned 语义和行内 pin；更新后的来源与置顶状态用用户可理解的标签呈现，不要求阅读内部工具/API 文档。

本次复审未发现需要 stop-and-fix 的产品问题。
