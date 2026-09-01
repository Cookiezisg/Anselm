# EDGE-348 | 语音双工握手拒绝闭集 | L4 真实 App 证据

## 判定

L4 通过，法典 `C4`：组件几何、圆角、内缩、层级和文本承载必须稳定且符合既定 craft bar。

## 现场

最终 session：`/private/tmp/anselm-rig-formal-20260902-23/sessions/20260902-045413`；录屏为 `3104x1848 / 60fps / 135.975000s`。Computer Use 在全新真实 App 中点击 `Voice input` 后，约 `1912ms` 出现顶部通知 capsule，视觉正文完整显示 `Voice quota. Try later.`，右侧 dismiss affordance 与底部 Composer 保持可用。

首轮真实现场发现通知正文被 340px 容器截断为 `This month's voice input allowance is use...`，因此停止推进。修复不是改成省略号或缩短到失去语义，而是给普通通知独立的 `noticeCapsuleMaxWidth=400`，保留 approval 的 340px 规格；同时增加 `voice quota guidance fits without visual ellipsis` widget 测试。最终现场确认没有省略号、遮挡、重叠、上下跳变或按钮挤压。

## 五通道与测量

- 录屏由窗口绑定 recorder 封口，`rig-check.sh` 五通道检查通过。
- backend 无应用级错误红线；SSE 三流建立并 clean EOF，没有因通知而虚构业务数据。
- frontend console 无 Flutter/Dart/RenderFlex/Unhandled/Exception/overflow 红线。
- LLM wire 保留真实 bootstrap 200 和一次语音 401，拒绝 body 为闭集错误码。
- AX 树与画面都显示完整短文案、dismiss button 和 Voice input；源码回归测试断言该文案没有视觉超行。

## 结论

修复后的拒绝提示在真实 60fps App 画面中完整、均衡、可关闭，且没有牺牲语义来掩盖布局问题。
