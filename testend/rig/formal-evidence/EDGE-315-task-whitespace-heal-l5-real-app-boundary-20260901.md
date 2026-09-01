# EDGE-315 空 task 尾空格腐化：L5 真实 App 可发现性边界

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-204918`
- result: **applicability `na`, not a discovery waiver**
- recording: `screen.mov`, `42.198333s`, 60fps
- final frame: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-204918/evidence/EDGE-315-task-whitespace-l5-final.png`

## Ordinary-user path

以普通用户目标进入 Library，打开 `EDGE-315 task fixture`，查看一个包含两条有内容待办和一条
空待办的清单。真实 App 展示三行 checkbox，空行仍占据正常行位；离开并重新打开后，三行结构和
右侧属性面板保持稳定。用户不需要知道 markdown、尾空格或 `_healTaskShapes` 等内部概念。

## Applicability boundary

CODEX 的 G1 要求用户能在不读文档的情况下找到某项产品能力的入口。`空 task 尾空格腐化` 是保存与
重开过程中的编辑器正确性不变量：产品没有“修复空 task”、专门设置、命令、tooltip、快捷键或独立
任务入口。用户能发现并使用的是 Library 与待办编辑本身，这些表面已由相应旅程和本格 L4 的真实
视觉验收覆盖；不能把一个应当无感工作的内部清理行为虚构成 G1 discoverability pass。

## Five-channel boundary evidence

- **frames / Computer Use**: 真实 App 启动后从 Library 定位并打开 fixture；最终录屏帧显示两条有内容
  待办与一条空行，checkbox 同列、同高，无额外 `[ ]` 文本。
- **backend**: session backend journal `184` 行，无应用级 WARN、ERROR、panic 或 fatal。
- **SSE**: ssetap 记录 `notifications`、`entities`、`messages` 三路连接，共 `9` 行；断开发生在 rig-down。
- **frontend**: frontend journal `3` 行，无 Flutter、RenderFlex、Unhandled 或应用级异常；仅有已分类
  macOS IMK 宿主诊断。
- **LLM wire**: llmtap `1` 行；Library 观察不触发 completion，不把无模型调用误写成发现性证据。
- **durable truth**: 本 session 使用的 fixture 保持 `39` bytes 的三行原文，真实 App 画面与 durable
  结构一致。
- **rig lifecycle**: `rig-check.sh` 五通道通过；`rig-down.sh` 封口录屏并收台所有 owned processes。

## Verdict boundary

L5 记录为合法适用性 `na`，理由是没有独立用户可发现入口。这不是缺少真实 App 证据的临时占位，
也不替代 L4 的 `pass (C4)`；若未来产品增加“修复/恢复空 task”的明确入口，本项必须重新评估 L5。
