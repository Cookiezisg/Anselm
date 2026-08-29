# EDGE-298 · 未读徽标绝不据帧 +1：真实 App L2

## 目的

验证同一 `memory.updated` 类型的两种事件不会被前端混为未读：持久 `Emit` 事件应增加未读数，纯广播 `Broadcast` 回声只触发对账，不能再加一。

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260829-151051`
- data=`/private/tmp/anselm-data-edge298-real-20260829-r1`
- workspace=`ws_1837441baa7435ac`
- App/window=`38111/6202`；录屏=`90.176667s`
- 关键帧=`sessions/20260829-151051/evidence/EDGE-298-unread-badge.jpeg`

## 场景与结果

1. 真实后端先执行 `mark-all-read`，权威 `unread-count=0`。
2. `PUT /memories/edge298-probe` 创建持久通知，`unread-count=1`。
3. 再次 `mark-all-read`，`unread-count=0`；随后更新同一 Memory，持久 `memory.updated` 使 `unread-count=1`。
4. 对同一 Memory 执行 pin；该动作发送同类型 `memory.updated` 的 Broadcast 回声，但 `unread-count` 保持 `1`。
5. 真实 App 的通知中心显示唯一新增的未读 `Memory "edge298-probe" updated`；旧 seed 行保留作审计但已读，左下铃铛只显示一个未读提示点。

## 五通道证据

- **Channel 1 / Computer Use + 录屏**：真实 App 通知中心关键帧显示更新行与已读历史行，界面无重复的第二条 update 未读提示、无错误卡或 loading 残留。
- **Channel 2 / backend journal**：mark-all-read、create、update、pin 均成功；无应用级 WARN/ERROR/panic。
- **Channel 3 / SSE tap**：`memory.created` seq=16 带 `inbox=true`；持久 `memory.updated` seq=17 带 `inbox=true`；pin 的同类型 Broadcast seq=18 不带 `inbox`。durable seq 单调无 gap。
- **Channel 4 / frontend 错误面**：`rig-check` 通过真实 App/window 归属、录屏遮挡、三流连接和 recorder lifecycle；frontend 无 Flutter/Dart/RenderFlex/Unhandled 应用红线，唯一 IMK 文本为已分类的 macOS 宿主诊断。
- **Channel 5 / LLM tap**：本场景不调用 LLM；challenge/install/models 为正常 `200`，没有把后台操作伪装成模型执行。
- **耐久对账**：REST `/notifications` 只出现一条未读的持久 `memory.updated`；REST `/memories/edge298-probe` 返回 `pinned=true`；权威 `unread-count=1` 与 SSE inbox 分流一致；SQLite 完整性检查 `ok`、外键检查为空。

## 判定

本证据支持 L2 `F1`：真实 App、权威 unread COUNT、通知持久行和 SSE 的 Emit/Broadcast 分流一致，广播帧没有造成虚假 +1。L3-L5 不在本次证据中猜测，继续保持 `na`。
