# EDGE-331 限额面板载入失败：L4 真实 App 视觉 craft 证据

- session: `/private/tmp/anselm-rig-formal-20260901-14/sessions/20260901-233914`
- representative frames: session `evidence/frames-error-60-small/0073.png`,
  `evidence/frames-error-60-small/0075.png`, `evidence/frames-retry-60-small/0088.png`
- law: `C4`（圆角与视觉尺度阶梯）
- verdict: `pass` for L4

## Visual craft review

错误态没有灰屏或残留 skeleton：Advanced limits 标题、警告图标、短标题、面向用户的说明和 Retry
按清晰的垂直层级居中，左侧 Settings 导航仍保持可用。错误文案没有把代理状态码、注入实现或内部
诊断泄露到产品表面。

恢复态保持同一页面标题和导航位置，machine-wide 说明、Reset all to defaults、分组标题和输入框
形成稳定的层级；长页面从空错误态恢复为字段列表时没有重叠、截断、白闪或双面板残留。代表帧和
60fps 分析帧确认按钮、chip、字段行的圆角和间距未因错误恢复发生临时变形。

`measure diff` 在 776px 宽分析帧上记录的变化 bbox 只覆盖中心面板，最后的恢复重排后进入稳定段；
未观察到持续变化或非用户触发的二次 reflow。

## Five-channel cross-check

- **frames / Computer Use**: 同一真实 App 录像包含 Shortcuts → 错误态 → 恢复字段态，逐帧复核层级、间距、圆角和对齐。
- **backend**: `backend.log` `431` 行，无未解释应用红线；一次 503 由代理明确注入，后续请求成功。
- **SSE**: 三条 SSE 流均真实连接并干净断开；设置只读路径没有虚构 durable 更新。
- **frontend console**: `frontend.log` 无 Flutter/Dart/layout/runtime 红线，仅正常 VM 启动信息。
- **LLM wire**: challenge/install/models 为真实 `200`，未把设置页误报为模型调用。
- **durable truth**: proxy journal 的一次失败、一次 forward 与 UI 的错误/恢复顺序一致。
- **rig lifecycle**: 录像、session journals、manifest、收台结果完整，五通道归属在 `rig-check` 中通过。

## Verdict

`L4 pass (C4)`。错误和恢复两种状态都保持同一套视觉尺度与页面结构，恢复过程没有把短暂加载态
暴露成产品级跳变；本格不重复结算 L3 时延或 L5 可发现性。
