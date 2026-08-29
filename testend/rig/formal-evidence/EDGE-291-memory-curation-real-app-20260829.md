# EDGE-291 · memory 更新保留策展：真实 App L2

## 目的

验证 AI 通过 `write_memory` 更新一条已有记忆时，只修改内容与描述，不静默清除用户已经做出的置顶策展，也不把 `source=user` 改成 `source=ai`。

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-145816`
- data=`/private/tmp/anselm-data-edge291-real-20260829-r1`
- workspace=`ws_c7e240b31152790e`
- App/window=`36195/6157`；录屏=`300.600000s`
- 对话关键帧=`sessions/20260829-145816/evidence/EDGE-291-memory-chat.jpeg`
- Settings 关键帧=`sessions/20260829-145816/evidence/EDGE-291-memory-panel.jpeg`

## 场景与结果

1. 通过真实 Memory 面板对应的 API 创建 `edge291-rule`，初始 `source=user`，随后通过真实产品动作 pin，得到 `pinned=true`。
2. 在真实 App 新建对话，用一条不含换行的真实 Composer 消息要求使用 `write_memory` 更新 `edge291-rule` 的描述和内容。
3. App 回执为“已更新 edge291-rule 记忆，描述和内容均已修改”，并展示 `Memorized edge291-rule`；没有工具错误、卡死或未完成态。
4. 切入真实 Settings → Memory，画面仍显示 `edge291-rule` 的置顶图钉、更新后的描述、`user` 来源和日期；没有把它从 Pinned 语义中移除。

## 五通道证据

- **Channel 1 / Computer Use + 录屏**：真实聊天完成态与 Memory 面板关键帧均已封存；单行消息没有被输入换行拆分，更新回执清晰，Settings 面板显示 pin 图标与 `user`。
- **Channel 2 / backend journal**：真实 chat/tool 执行完成，无应用级 WARN/ERROR/panic/Flutter/Dart/RenderFlex/Unhandled 红线。
- **Channel 3 / SSE tap**：notifications 流收到 `memory.updated`，durable seq 单调；最终更新对应 `seq=27`，无断流或重复的同一耐久事件。
- **Channel 4 / frontend 错误面**：`rig-check` 通过真实 App/window 归属、录屏遮挡、三流连接和 recorder lifecycle 检查；真实 UI 无错误卡、残留 loading 或不可解释空态。
- **Channel 5 / LLM tap**：最终正式单消息的 chat-completions continuation 链均返回 `200`；wire 中出现恰好一条 `write_memory` 工具调用，随后回合完成。早先含 `\n` 的两次输入实验被明确排除：`type_text` 将换行解释为 Return，导致用户消息拆分，不作为产品证据。
- **耐久对账**：最终 `GET /api/v1/memories/edge291-rule` 返回 `pinned=true`、`source=user`，描述与内容为本轮更新值；SQLite `integrity_check=ok`，`foreign_key_check` 为空。

## 判定

本证据支持 L2 `F1`：真实 App 的用户目的已完成，且 UI、REST、SQLite、SSE 与 LLM wire 共同证明更新保留了用户 pin/source。L3-L5 不在本次证据中猜测，继续保持 `na`。
