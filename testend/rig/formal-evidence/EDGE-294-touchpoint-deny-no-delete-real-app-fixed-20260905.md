# EDGE-294 · 触点不记幽灵删除：真实 App 修复后五通道验收

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260905-edge294-fix/sessions/20260905-034944`
- data=`/private/tmp/anselm-data-edge294-fix-20260905`
- workspace=`ws_ac0e9d4a41a211e3`
- conversation=`cv_e8098d91262ba398`
- fixture Agent=`ag_49bee80e87f8d9c2`
- recording=`screen.mov`, `191.311667s`; 本场使用 `RIG_ENGINE_SWITCHES=enable-impeller=false` 作为采集稳定性 workaround，不把它写成 Impeller 产品修复。
- cleanup 在取完 `pre-cleanup.json` 后才执行；因此 cleanup 产生的删除通知与本场负向断言分开处理。

## Stop-and-fix 链

前置真实 App 场发现：第一次拒绝后再次发送同一删除目标并再次拒绝时，loop 虽然正确抑制了重复
`delete_agent`，但直接以 `repeatedCall` 收尾，没有生成最终文本块。旧红证据保留在
`EDGE-294-duplicate-repeat-no-final-red-20260905.md`，该证据不用于任何绿色裁决。

修复为在重复调用被抑制后写入并持久化确定性的用户可见终态文本，同时保持“不二次执行、不二次审批”
不变量；`backend/internal/app/loop/loop.go` 的回归测试同时断言文本 block 与 `Result.LastMessage`。

## 场景与用户结果

在真实 App Chat 中发送自然语言目标：
`Delete the agent named EDGE294 repeat fix 1788551448. Do not do anything else.`

两次均由 `testend/rig/interaction_operator.py` 对精确 `delete_agent` 做 `deny`。第一次显示正常取消
说明；第二次遇到同一 turn 内重复调用时，App 显示：

`The repeated tool request was not run again because the same operation was already handled earlier in this turn.`

第二次不再出现空白收尾；Agent 在收台前仍可 GET，touchpoints 为空。关键帧为：

- `sessions/20260905-034944/evidence/EDGE-294-fix-pending.png`
- `sessions/20260905-034944/evidence/EDGE-294-fix-repeat-pending.png`
- `sessions/20260905-034944/evidence/EDGE-294-fix-final.png`

## 五通道事实

- **Channel 1 / Computer Use + 录屏**：真实 App 显示危险确认卡、`Deny`/`Always allow`/`Allow` 三个决议入口；
  长确认文案完整换行，无裁切或等待态空洞。两次拒绝路径都在录屏中留下可见终态，第二次包含修复后的最终文本。
- **Channel 2 / backend journal**：交互决议各返回 `204`；正式场景收尾前没有
  `DELETE /api/v1/agents/ag_49bee80e87f8d9c2`。收尾前 Agent GET=`200`，touchpoints=`[]`。
  收台后的直接 cleanup DELETE 不属于拒绝路径，另有明确 HTTP 记录。
- **Channel 3 / independent SSE witness**：messages durable `seq=40` 为重复 tool result open，
  `seq=41` 为 suppression close；随后 `seq=42` text open、ephemeral delta 为完整 notice、
  `seq=43` text close，`seq=44` message close=`completed/end_turn`。这证明修复同时进入实时帧和持久收尾。
  `agent.deleted` 与 `conversation.deleted` 只在收台 cleanup 后出现，不属于拒绝路径。
- **Channel 4 / frontend console**：`frontend.log` 仅有启动、Dart VM service 和已分类的 macOS IMKCFRunLoopWakeUpReliable
  系统行；没有 Flutter/Dart/RenderFlex/RenderBox/Unhandled 应用红线。正式 session 的 `rig-check.sh` 与
  `rig-down.sh` 通过，录屏已封口。
- **Channel 5 / LLM wire**：proof challenge/install/models 与本场 7 次 chat completion 均返回 `200`；
  request bodies 保存在 session 的 `llm-bodies/`，工具调用的 `dangerous` 字段保持不变。重复抑制由 loop
  ledger 完成，不是模型重试，也没有第二次真实删除。

## 裁决

- L1：沿用既有 focused contract 证据。
- L2：`pass(F1)`，以本 session 重新验证用户界面、backend 状态、SSE durable 收尾和 touchpoints 真相一致。
- L3：`pass(A4)`，危险操作有明确等待/决议状态；重复路径在决议后以可见终态结束，没有无反馈的空收尾。
- L4：`pass(C4)`，确认卡和最终文本在真实窗口中保持稳定层级、换行和边界；修复后关键帧没有残留空白收尾。
- L5：`pass(G1)`，用户只需表达“删除这个 Agent”的自然目标，不需要内部 ID 或工具知识；App 自然发现目标、
  展示危险边界，并在拒绝与重复拒绝后给出可理解的结果。

本证据不抹除前置红场；它记录的是红场触发、代码修复、真实 App 复跑和五通道闭合后的最终状态。
