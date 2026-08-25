# EDGE-352 分叉携带附件与 subagent 树

- 判定对象：含附件、@ 快照、嵌套 subagent block 的对话分叉。
- 证据：`TestChatFork_AttachmentsSharedNotCopied`、`TestChatFork_SeqRenumberedAndNestedRemapped` 及 `TestLiveManaged_ForkPreservesParallelSubagentTrees` 已覆盖；本轮黑盒 `TestChatFork_` 定向套件通过。
- 产品判断：附件引用共享而不复制，block/message/parent/retry 血缘在新分支内重映射，源对话不被改写；真实 managed 五通道重跑仍是 L2 待办。
- 法条：F1、F5。

