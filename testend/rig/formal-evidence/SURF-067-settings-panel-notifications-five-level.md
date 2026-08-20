# SURF-067 · settings/panel-notifications

## 判定

`pass`。真实 App 中完成通知设置的产品闭环：三档通知级别、系统通知、应用内通知和失败/审批/需关注三类胶囊登记均可发现、可切换、即时生效并恢复默认。更重要的是，设置不是静态表单：真实 workflow park 在 approval 节点后，通知流驱动顶带显示可操作的 `Awaiting approval` 胶囊；关闭审批胶囊后新 approval 事件不再弹出；切换 `All` 后同一分类即使登记关闭仍会弹出；从胶囊点击 `Approve` 真实决策 flowrun，显示 `Approved` 后沿同一动画线收口。

没有发现需要 stop-and-fix 的功能、数据、视觉或可发现性缺陷。既有胶囊在用户关闭登记后不会被强行抹掉，这是对已经到达的待办保持诚实的行为；本轮另行关闭旧展示副本后验证了后续事件门控。

## 真实 App 路径

- Session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260819-220500`
- Data: `/private/tmp/anselm-data-surf067-20260819-r1`
- Workspace: `ws_b987f930f7df592c` (`Acceptance SURF-067`)
- 全新 workspace onboarding 后进入 Settings → Notifications；所有设置均由 Computer Use 真实点击并在每次动作后重新读取 App state。
- 通知级别真实走 `All → Needs you → Silent`；Silent 的辅助文案明确显示 `Silenced — important items still land in the bell inbox`。
- System notifications、In-app notices、Capsule: failures、Capsule: approvals、Capsule: attention 均完成真实 off/on 往返，最后恢复默认：`Needs you`、系统开、应用内开、失败开、审批开、需关注关。
- 通过 REST 只构造可收束的临时 approval workflow，并由真实 App 接收其 notifications SSE：approval pending 后出现顶带块，标题、问题和 Approve/Reject 均可见。
- 关闭审批胶囊登记并关闭已有展示副本后再起一个 approval run：新事件不弹顶带，但仍进入后端 inbox；这验证了设置只控制展示，不丢失业务真相。
- 切换 `All` 后关闭审批登记，再起第三个 approval run：顶带再次显示，证明 All 绕过分类登记。
- 从第三个真实胶囊点击 `Approve`：胶囊先显示绿色 `Approved` 和禁用中的动作行，随后约 1.8 秒内沿同一线退场；后端 run 进入 `completed`，其余两个临时 run 通过 API 选择 `no` 收束，最终无 parked 残留。

关键帧：

- `evidence/SURF-067-notifications-initial.png`
- `evidence/SURF-067-level-all.png`
- `evidence/SURF-067-level-silent-hint.png`
- `evidence/SURF-067-approval-visible.png`
- `evidence/SURF-067-approval-suppressed.png`
- `evidence/SURF-067-all-bypasses-registry.png`
- `evidence/SURF-067-approved-verdict.png`
- `evidence/SURF-067-default-restored.png`

## 五通道证据

1. **Frame**：`recording-lifecycle.json` 记录同一 App 窗口的录制生命周期；证据帧覆盖设置三档、分类门控、真实 approval 卡、批准判词和恢复默认。
2. **Backend**：`backend.log`=`572` 行；无 WARN / ERROR / panic / FATAL。审批实体、workflow、三次 run、两次 `no` 清理和一次 `yes` 决策均由同一 `ws_b987f930f7df592c` 的后端记录闭合。
3. **SSE**：`sse.jsonl`=`21` 行；独立 witness 同时连接 `messages`、`entities`、`notifications` 三流，真实记录三次 `workflow.approval_pending`、实体 `parked`、`run_terminal`，且 durable seq 单调推进；展示关闭没有伪造或删除通知帧。
4. **Frontend terminal**：`frontend.log`=`4` 行；仅正常启动、Flutter VM 和已知 macOS `IMKCFRunLoopWakeUpReliable` 宿主噪声，无 Dart / Flutter / assertion / overflow / unhandled 红线。
5. **LLM wire**：`llm.jsonl`=`10` 行；managed proof challenge、install、models 均返回 `200`。该路径不需要 LLM completion，不伪造 completion 证据。

`rig-check` 在 App 仍运行时通过五通道归属检查；本轮结束后将由 `rig-down` 收束并审计无进程残留。

## 本地验证

- `mise exec -- flutter test test/features/settings/s1_panels_test.dart test/features/notifications/state/notice_dispatcher_test.dart test/features/notifications/ui/notification_copy_test.dart test/core/ui/an_notice_capsule_test.dart test/core/run/an_approval_capsule_test.dart`：通过，`56 tests`。
- 真实 REST 最终核验：三个 flowrun 均 `completed`；approval `yes/no` 结果、`run_terminal` 和 inbox 收口一致。
- `RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 bash testend/rig/rig-check.sh`：通过，五通道物理观察仍在。

## 法条

- `G1`：Notifications 在 Settings 侧栏可直接发现；三档级别和每类胶囊的作用范围由行文案说明，审批胶囊动作也无需离开当前面板。
- `F1`：真实通知 SSE、backend flowrun/inbox、App 胶囊和批准后的 terminal 状态相互吻合；关闭展示登记没有删掉 inbox 真相。
- `B2`：审批胶囊按圆点→横条→块的连续线进入，批准后沿同一线退出；真实帧与 56 个动画/布局测试均未发现跳变、裁切、溢出或错误颜色。
- `C4`：级别、系统/应用内通道和三类胶囊使用明确的人话边界；`Silent` 明示重要项目仍进入 bell inbox，避免“静音等于丢失”的错误预期。
- `G1`：All、Needs you、Silent 和分类登记的组合行为在真实事件上可复现，用户能够从设置面板和顶带动作理解下一步。
