# EDGE-316 L3 账本与警报独立复审

- subject: `EDGE-316 / 行内代码 CJK 断盒 / L3`
- source evidence: `testend/rig/formal-evidence/EDGE-316-inline-code-cjk-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-231212`
- law: `B2`

## 复审结论

复核了 60fps 录屏、1fps 全屏与内容 ROI 测量、三张稳定帧、五通道 journal 及 L2 真实结果。较大的 diff 只出现在打开、离开和重开文档的用户动作窗口；稳定内容区没有晚到背景、断盒或非用户位移。`notifications seq=16` 与文档创建事实一致，三路 EOF 属正常收台。

`judge.py` 的 `L3 pass (B2)` 有现存法条、真实 evidence 文件和同 session 的五通道证据；anchors 为 `10/10`。本复审不修改 B2 阈值、法典、锚点或 gate；若串行写账触发统计警报，只能按此复审记录和原阈值 ack。
