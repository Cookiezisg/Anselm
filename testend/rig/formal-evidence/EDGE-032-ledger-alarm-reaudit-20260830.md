# EDGE-032 · convQueue 5 分钟自毁后重建 · 账本与警报复核

`TestSendAfterIdleQueueTeardownRecreatesQueue` 在普通和 race 模式均通过：第一轮完成后
空闲队列从 registry 移除，第二轮 Send 创建不同的 queue 实例并正常收尾。该测试使用
缩短的内部 timeout seam，不改变生产策略的五分钟配置。

本轮新增的 L2/L3 是适用性裁定，不是缺少现场证据的 waiver：队列自毁/重建是 chat 的
内存生命周期，没有独立持久实体、用户反馈时延、动画、Flutter 视觉表面或导航入口；
消息、composer 队列反馈和 chat 导航由宿主旅程覆盖。既有 L1/L4/L5 证据保持不变。

本轮告警复核只确认 focused/race 事实和顺序 gate 的正确推进，不修改阈值、算法、CODEX
法条、锚点集、五级标准或人工队列策略。
