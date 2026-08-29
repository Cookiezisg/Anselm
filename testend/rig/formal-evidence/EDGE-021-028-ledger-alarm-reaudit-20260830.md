# EDGE-021..028 · 账本与警报独立复核

## Scope

本次新增的八个 L3 `na` 裁决分别对应：对话删除后的内存授权清理、驻地越界写
安全闸、不可判定路径的安全回退、驻地外读取、skill 信任门、`allowed-tools`
变更后的授权重置、无交互用户的 `ask_user` 失败，以及 interaction action
枚举校验。它们不是把用户可见的 chat、workdir、skill 或 interaction 旅程
改判为 `na`；这些旅程仍由各自 COVERAGE 行负责。

## Independent checks

以下命令在 2026-08-30 于当前工作树执行，均通过：

```text
mise exec -- go test -count=1 ./internal/app/chat ./internal/app/humanloop \
  -run 'TestForgetConversationClearsOnlyDeletedConversationGrants|TestForgetDropsConversationGrants'
ok

mise exec -- go test -race -count=1 ./internal/app/chat ./internal/app/humanloop \
  -run 'TestForgetConversationClearsOnlyDeletedConversationGrants|TestForgetDropsConversationGrants|TestResolveInteractionRejectsUnknownActionLoudly|TestResolveInteraction_ConversationScoped'
ok

mise exec -- go test -race -count=1 ./internal/app/loop \
  -run 'TestDispatchWithGate_(OutsideWorkDirForcesGate|OutsideWorkDirIgnoresApproveAlways|OutsideWorkDirIgnoresSkillPreApproval|UndeterminableTargetFallsBackToDangerGate|ApprovedUndeterminableTargetReachesExecuteValidation|NonWriterToolNeverPathGated)'
ok

mise exec -- go test -race -count=1 ./internal/app/skill \
  -run 'TestTrustGate_WithholdsUntilApproved|TestPreauthorizeActiveSkill_InlineGrantsForkSkips|TestUpdateInstalled_DriftRefusalAndToolChangeResetsGate|TestUpdateInstalled_UnchangedToolsKeepApproval'
ok

mise exec -- go test -race -count=1 ./internal/app/tool/ask \
  -run 'TestExecuteWithoutInteractiveUserFailsLoudly'
ok
```

测试锁定的事实包括：删除只清理目标 conversation 的 `approve_always` 授权；
越界写入无论自报等级、会话白名单或 skill 预授权都必须进入人闸；无法解析的
目标在批准后仍由 Execute 做最终拒绝；非写入读取不被错误地路径加闸；skill
正文可以激活但未批准时不预授权，修改工具集合后授权重置；非交互 `ask_user`
立即返回 `ASK_NO_INTERACTIVE_USER`；非法 action 在查询 broker 前返回结构化
`INTERACTION_INVALID_ACTION`；跨会话和重复决议不会消耗另一会话的 pending 项。

## Alarm disposition

`pass-burst` 与 `discovery-collapse` 是本批内部协议复核造成的统计信号。它们
没有被忽略：本记录保留了逐条测试和适用性边界，前一批真实 App 证据仍在盘上，
锚点复核保持 `10/10`。本次只销账当前告警实例，不调整阈值、算法、CODEX 法条、
锚点集、顺序 gate 或五级标准；后续自主前线仍按单格顺序推进。
