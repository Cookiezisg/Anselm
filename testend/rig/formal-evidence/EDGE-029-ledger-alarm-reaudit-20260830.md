# EDGE-029 · 重复 resolve interaction · 账本与警报复核

`TestResolveInteraction_ConversationScoped` 在普通和 race 模式均通过。该测试先
完成同一 conversation/tool-call 的第一次 resolve，再重复提交同一决议，确认第二次
返回 `NO_PENDING_INTERACTION`，不会重放答案、重新打开交互或产生第二次状态转换；
同一测试也确认跨 conversation 的请求不会消耗原 pending 项。

本条的 L1 由既有 focused evidence 收口。本轮只补 L2/L3 的适用性裁定：重复 resolve
是 broker/API 的内部幂等边界，不新增独立持久业务状态，也没有独立用户反馈时延、
等待、动画或 Flutter 视觉表面；可见交互反馈由 chat interaction 旅程覆盖。既有
L4/L5 适用性结论保持不变。

本轮未修改阈值、算法、CODEX 法条、锚点集、顺序 gate 或五级标准。告警复核只检查
这两个单元的证据完整性，不把集中账本写入冒充真实 App 体验通过。
