# EDGE-301 顶带清场水位：真实 App 证据（2026-09-01）

## 结论

通过。正式 session 在真实 App 中制造旧通知队列，点击真实 `Clear all` 后，在退场动画开始约 80ms 注入一个新的 `skill.created`；清场完成后 fresh notice 成为唯一当前卡，旧队列没有回流或误删。

## 现场

- session：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-151411`
- workspace：`ws_172b53a7070d5346`
- App PID：`19757`；录屏 window `12999`，bounds `0,30,1440,810`
- `rig-check`：channel 1 录屏、channel 2 backend、channel 3 三条 SSE、channel 4 真实 Flutter App、channel 5 真实网关 tap 全部通过
- `rig-down`：录屏正常 finalized，owned App/backend/tap/recorder 全部收回

## 构造与观察

1. 通过真实 workspace API 创建 5 个旧 `skill.created` 事件，Computer Use 看到旧 notice 与 `Clear all 4 top notifications`。
2. 保存清场前帧 `evidence/edge301-clear-before.jpg`，用真实 App 点击 `Clear all`。
3. 在点击后约 80ms 内，通过同一隔离 workspace 创建 fresh skill，HTTP `201`；随后等待退场动画完成。
4. 保存结果帧 `evidence/edge301-clear-after-fresh.jpg`，Computer Use AX 树只看到 `Skill “edge301-fresh-during-clear-…” created · View`，没有旧卡回流。

## 五通道事实

- backend journal 对旧事件和 fresh 事件均有真实 HTTP 请求，未出现 WARN/ERROR/panic。
- ssetap 观察到 `messages`、`entities`、`notifications` 三条连接；本格 durable notification seq `16..26` 连续无 gap，11 条均为本场景 skill.created 事件。
- frontend console 只有已知 macOS `IMKCFRunLoopWakeUpReliable` 诊断，无应用级 Dart/Flutter/RenderFlex/overflow/Unhandled 红线。
- llmtap 已连接真实 `https://api.anselm.website`；本格是通知投影路径，不需要 LLM completion，不虚构 completion 证据。

## 产品判断

清场只清除用户主动选择的可见快照；清场动作之后到达的新事件必须保留。fresh notice 在旧卡退场期间没有被旧回调误删，当前胶囊保持固定高度、`View` affordance 和不扩张的布局。实现对照为 `frontend/lib/core/notice/notice_center.dart:317` 的双队列交换及 `frontend/lib/app/app_shell.dart:918` 的清场接线。

等级映射：L2=`F2`，L3=`A4`，L4=`C4`，L5=`G1`。
