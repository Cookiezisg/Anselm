# EDGE-021 · 白名单随对话删除清除 · 适用性复核

`TestForgetConversationClearsOnlyDeletedConversationGrants` 与
`TestForgetDropsConversationGrants`（普通和 race）共同证明删除生命周期钩子会清掉被删对话的
全部 `approve_always` 授权，同时保留另一存活对话的授权。该安全状态没有独立实体或用户入口。

- L2 `na`: 授权是内存态会话安全状态，不新增独立持久业务状态；删除与消息真相由 conversation/chat 旅程覆盖。
- L3 `na`: 清授权没有独立的用户反馈时延、等待或动画表面。
- L4 `na`: 清授权没有独立 Flutter 控件、布局、颜色或动效表面。
- L5 `na`: 清授权不是用户可发现或可导航的入口，授权入口由 interaction 旅程覆盖。

这是适用性裁定，不是缺少真实 App 证据的 waiver；没有修改标准、阈值、法条、锚点或 gate。
