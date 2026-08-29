# EDGE-352 分叉携带附件与 subagent 树 · 真实 App 五通道实证

- **判定**：L2 `pass`；L3（顺滑）、L4（独立视觉 craft）、L5（可发现性）本次不判定。
- **正式 session**：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-013112`
- **真实路径**：conductor 启动当前代码的真实 macOS App、同一 workspace 的 sidecar、三路独立 SSE witness、llmtap 和 Anselm 窗口录屏；从真实 Transcript 的 `从这里分叉` 入口创建新线程。
- **受控数据**：独立数据目录 `/private/tmp/anselm-data-edge352-app-20260828` 预置一条 durable 源线程，含 1 个 user 回合的 `attachments` 与冻结 `mentions` 快照、1 个 `Subagent` tool_call、1 个 subagent 回合及父 `tool_result`。附件复用现有内容寻址行 `att_3d5417ef309fe60a`，没有复制附件行或 blob。
- **产品结果**：源线程加载后，附件卡、`edge352_reference` @ 药丸和 `已派子代理` 均可见；展开卡后能看到任务、回复和回答三段嵌套内容。点击 `从这里分叉` 后，新线程立即打开，源线程仍留在 rail；新线程中附件、@ 快照、subagent 展开态均可读。分叉头部的血缘按钮展开为 `分叉自 EDGE-352 fork source`，点击后可回到源线程。
- **持久真相**：fork=`cv_8628f3ef127bf9c3`，source=`cv_edge352_src`；两边均为 5 条 message、8 个 block。fork 的 1 条 subagent message 保留 `subagent_id`；其 `parentBlockId` 与子 block parent 均已重映射到 fork 自己的 `blk_150c89e9af2e92b0`，不存在指向 source 的 parent。fork block seq 为连续 `1..8`；source 的原始 IDs、parent 和 seq 保持不变。fork 的附件数组与 mention snapshot 和 source 逐字相同；附件表中该 id 仍只有 1 行。
- **REST / SSE**：App 导航到 fork 后通过 `GET /conversations/{id}/messages` 重新水化完整 durable 前缀；通知流记录唯一的 `conversation.created`，messages/entities/notifications 三流均已连接。复制后的历史不伪装成重新发送的逐块消息，故没有虚假的 messages durable 帧。
- **LLM 线缆**：llmtap 只有 `event=ready`，没有 chat completion 请求；本地 fork 不需要模型调用，也没有把“模型看见了附件”作为证据。
- **五通道**：`rig-check` 通过；`rig-down` 成功封口 `screen.mov`，录屏时长 `142.600000s` 且可由 ffprobe 读取；backend 无 `WARN/ERROR/panic/FATAL`；frontend 无 `FlutterError/DartError/RenderFlex/Unhandled exception`，仅有已审阅的 macOS `IMKCFRunLoopWakeUpReliable` 宿主警告；ssetap 三流均连接；llmtap 已绑定受管 key 接线并在线。
- **Fixture 校正记录**：早期两次只读启动发现测试夹具分别缺失合法 `end_turn` 和父 `tool_result`/`parent_block_id`；均在独立数据目录收台后修正，未改产品代码，最终 session 使用校正后的完整 durable 形状。不能把这些夹具错误当作产品红场。
- **回归**：`mise exec -- go test ./internal/app/chat ./internal/infra/store/messages` 通过；`mise exec -- flutter test test/features/chat/ui/chat_transcript_test.dart test/features/chat/model/conversation_transcript_test.dart` 通过（65/65）；`python3 testend/rig/gen_coverage.py --check` clean；focused session 无未解释 runtime marker。
- **法条**：F1、F2、F3、F4。

这次只证明“真实 App 能完成分叉，且分叉后的 durable 数据与源的可共享内容和独立树结构一致”。没有把一次预置 fixture 的静态等待时间、视觉 craft 细节或入口可发现性冒充 L3-L5 结论。
