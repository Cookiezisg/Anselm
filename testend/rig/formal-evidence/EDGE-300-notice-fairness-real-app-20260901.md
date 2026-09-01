# EDGE-300 顶带公平调度：真实 App 证据（2026-09-01）

## 结论

本格在正式 session `20260901-144816` 中完成真实 App 的 priority/normal 混合调度验收。结果为通过：在当前 approval 卡由用户 `Dismiss` 完成后，连续三次 priority promotion 后，等待中的 normal notice 接班；该行为在两个连续周期中重复出现。approval 卡不会因为普通通知到达而被抢占，也不会在无人操作时自动消失。

## 现场与五通道

- 正式 session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-144816`
- workspace：`ws_dc313a983f2f972a`
- 真实 App：macOS debug build，PID `18019`，录屏 `3104x1844 / 60fps / 1012.203333s`
- channel 1：窗口录屏与逐张现场截图，`rig-check`、`rig-down` 通过
- channel 2：后端 PID `17491` 持有 `:8742`，`rig-check` 通过
- channel 3：独立 ssetap 连接 `messages`、`entities`、`notifications` 三条 SSE，均有真实连接；durable notification seq 连续递增
- channel 4：Computer Use 读取真实 App AX 树并执行真实 `Dismiss`，不是 demo showcase 或 widget test
- channel 5：llmtap 连接真实 `https://api.anselm.website`；本格不需要 LLM completion，因此不把不存在的 completion 伪造为本格结果

## 构造

1. 在隔离 workspace 创建 12 个唯一 workflow，每个 workflow 为 `trg_manual -> approval`，approval 节点真实停在 `parked`。
2. 每轮提交三个不同 workflow 的真实 `POST /api/v1/flowruns`，制造三个唯一 `workflow.approval_pending` priority 事件；每轮再创建一个唯一 skill，制造 `skill.created` normal 事件。
3. 由于通知中心按 `type + entity` 去重，第一轮相同 workflow 的重复审批不作为正式结果；随后改用唯一 workflow 实体重跑，排除了去重干扰。
4. App 保持在 Chat ocean，通知级别通过 Settings -> Notifications -> All 设定；收台前恢复为 `important`。

## 后端与 SSE 事实

唯一实体场景在 notifications SSE 中得到 12 个 approval pending 与 4 个 skill created。其 durable seq 为连续区间 `53..68`，无缺口；严格相关事件顺序为：

```text
approval unique-1, unique-2, unique-3, normal-0,
approval unique-4, unique-5, unique-6, normal-1,
approval unique-7, unique-8, unique-9, normal-2,
approval unique-10, unique-11, unique-12, normal-3
```

原始 SSE 事件和完整顺序保存在 session 的 `sse.jsonl`。本场景中还保留了一次刻意漏掉 approval input 映射的负向 probe；它真实落为 `workflow.run_failed`，不计入本格成功路径，且没有未解释的 backend WARN/ERROR 或 panic。

## Computer Use 观察

正式操作序列保存在：

- `evidence/edge300-fairness-frames/handoff-sequence.json`
- `evidence/edge300-fairness-frames/fairness-cycle-2.json`
- `evidence/edge300-fairness-frames/edge-strict-*` 与 `cycle-*` 截图

第一段真实 AX 序列为：

```text
Awaiting approval unique-1
Awaiting approval unique-2
Awaiting approval unique-3
Awaiting approval unique-4
Skill edge300-fair-normal-0 created
```

第二段为：

```text
Awaiting approval unique-5
Awaiting approval unique-6
Awaiting approval unique-7
Skill edge300-fair-normal-1 created
```

这里的 `unique-1` 是当时已经在台上的 current；因此公平计数严格按实现法条“候场 promotion”计算，`unique-2 -> unique-3 -> unique-4` 三次后由 normal 接班。第二段重复了同一规则。每张 approval 卡的 `Approve`、`Reject`、`Dismiss` 都保持可操作；普通卡显示 `View`，当前卡外只暴露有限 cue 与 `Clear all N`，没有把 backlog 展成大量 AX 控件。

截图显示的长 synthetic workflow 名出现省略号属于顶带固定最大宽度的预期省略，未遮挡操作控件；真实产品名不依赖内部测试 ID。画面没有白闪、重排、溢出或跳变。

## 产品判断与实现对照

- F2：`ssetap` 观察到三流 durable seq 连续；顶部事件顺序与 App AX 观察的 promotion 顺序一致。`frontend/lib/core/notice/notice_center.dart` 的 `priorityBurstLimit = 3` 在 `_takeNext` 中只对有 normal 候场时计数。
- A4：approval 卡是需要用户处理的交互状态，保持可见而不自动消失是正确的人在环语义；`Dismiss` 后每次都有完整退场/接班过程，不瞬跳。
- C4：顶部 capsule 固定宽度、控制区域未被长文本挤压，cue 仍限制为最多两个，截图中操作控件和视觉层级完整。
- G1：新用户无需读文档即可从 `Awaiting approval`、`Approve`、`Reject`、`Dismiss` 理解下一步；普通事件提供 `View`，积压提供可见的 `Clear all N`。

## 红线与收台

- `rig-check`：five channels physically observing，全部通过
- `rig-down`：录屏正常 finalized，backend、ssetap、llmtap、App 均由台架收回
- frontend 日志：仅有已知 macOS `IMKCFRunLoopWakeUpReliable` 诊断，无应用级 Dart/Flutter/RenderFlex/overflow/Unhandled 红线
- backend 日志：本格未发现未解释 WARN/ERROR、panic；刻意负向 probe 已在上文明示

等级映射：L2=`F2`，L3=`A4`，L4=`C4`，L5=`G1`。
