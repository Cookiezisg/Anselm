# EDGE-039 账本与统计告警独立复审（2026-08-30）

## 复审对象

- 正式 session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-163538`
- 新增裁决：`EDGE|:retry 编辑重发分支` L2 = `pass / F2`
- 触发告警：`gap-too-fast`、`discovery-collapse`

## 逐项复读

- `gap-too-fast`：近期裁决间隔中位数低于 25 秒，是本次同一真实 session 收台后
  连续执行证据校验与写账的机械节奏，不代表跳过观察。复读该 session 的录屏、
  backend journal、三路 SSE、frontend journal、LLM wire、REST 版本链和 focused
  回归测试，证据文件均存在且内容互相吻合；不修改 25 秒阈值。
- `discovery-collapse`：近期 fail 占比低于 5% 是统计窗口信号，不是产品自动变绿。
  本格此前确实保留了真实红证据；修复后也只判 L2，编辑文本的 AX/controller
  输入桥限制已明确披露，L3-L5 没有被顺带放行；不修改 5% 阈值。

## 复审结论

两项告警均为统计护栏命中，非伪绿证据。保留原标准、法典、锚点与五通道要求，
按原阈值销账；下一格仍须从当前顺序门继续，不因告警复审跳格。
