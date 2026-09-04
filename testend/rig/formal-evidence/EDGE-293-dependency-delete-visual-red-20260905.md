# EDGE-293 · 删被依赖实体：窄 rail 文案截断红证据

## 正式 session

- session=`/private/tmp/anselm-rig-formal-20260905-edge293/sessions/20260905-004542`
- screen=`screen.mov`，`3104x1846 / 60fps / 180.550000s`
- frame=`sessions/20260905-004542/evidence/EDGE-293-post-delete.png`

## Finding

真实 App 删除被三个 Agent 挂载的 Function 后，通知中心的首行和依赖者详情均以单行省略：函数 ID、`was deleted` 影响说明和三个 Agent 名称在窄 rail 中不能完整阅读。后端和 SSE 事实正确，但产品层没有把最关键的后果交付给用户，因此 L4/L5 不得判绿。

## Decision

冻结 Edge-293，修复 `NotificationRow`：有影响详情的告警允许主句与详情各自最多两行自然换行；普通生命周期通知继续保持单行紧凑布局。该红证据保留，不覆盖为绿。
