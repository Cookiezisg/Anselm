# EDGE-322 · 应内缩放到顶：L3 真实 App 逐帧证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-022508`
- data: `/private/tmp/anselm-data-edge322-20260828-r1`
- workspace: `ws_cc83f5e7903c9dec`
- recording: `screen.mov`, `163.741667s`, `2784x1808`, `60fps`
- L2 foundation: `testend/rig/formal-evidence/EDGE-322-in-app-zoom-cap-real-app-20260828.md`
- stable frames: `EDGE-322-l3-default-1-0-stable.png`, `EDGE-322-l3-zoom-1-1-stable.png`, `EDGE-322-l3-reset-stable.png`, `EDGE-322-l3-final-stable.png`

## Product path

在真实 App 的「设置 → 通用」连续执行 `1.0× → 1.1× → 1.25×` 尝试，再恢复 `1.0×`。每一步等待界面停止重排后观察左侧设置导航、中心内容、缩放控件和窗口边界，确认到顶后的状态可继续操作且恢复路径不残留。

## Frame review and measurement

对 `screen.mov` 抽取全程 `1fps`，用 `threshold=0.0005` 对设置内容 ROI `500,100,2200,1200` 复核。代表性变化为：

- `000085→000086=0.06323` 是从快捷键页进入通用设置的用户导航；
- `000097→000098=0.09943` 是点击 `1.1×` 后的预期整体重排，稳定帧明确显示当前值为 `1.1×`，内容仍完整可读；
- `000098→000099=0.00051` 仅为重排后的边缘收敛，随后没有持续位移；
- `000143→000144=0.09944` 是点击恢复 `1.0×` 的预期整体重排；最终 `000144` 至录屏结束保持 `1.0×`，没有二次缩放、白带或布局溢出。

尝试 `1.25×` 没有改变当前值或把控件推入不可容纳状态；到顶档位保持禁用。`1.1×` 和恢复后的稳定帧中，设置标题、说明文本、选择控件和左侧导航均落在窗口内，视觉状态可继续操作。

本格 L3 判断缩放动作后的动态收敛、到顶拒绝和恢复稳定性；L2 已证明档位边界与无溢出结果。L4/L5 不在本格结论内。

## Five-channel cross-check

- **frames / Computer Use**: 真实 App 录屏覆盖默认档、放大档、越界尝试和恢复档；四张稳定帧已封存。
- **backend**: journal `243` 行；该本机偏好路径无应用级 `WARN`、`ERROR`、`panic` 或 `fatal`。
- **SSE**: messages/entities/notifications 三流均连接；本机偏好路径没有 durable 业务帧是预期行为；收台为 conductor 主动关闭后的 EOF。
- **frontend console**: `3` 行；无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow 应用级红线。
- **LLM wire**: llmtap proof challenge/install/models 全部 HTTP `200`；本格是本机设置路径，不伪造 completion 调用。
- **rig lifecycle**: startup gate、`rig-check` 和 `rig-down.sh` 收台通过，App、backend、ssetap、llmtap、录屏归属一致，无残留。

## Judgment boundary

- **L3 `pass (B2)`**：连续缩放、到顶拒绝和恢复均收敛，稳定态没有持续重排、布局溢出、白带或状态卡死。
- L4/L5：`na`。本证据不宣称缩放控件的视觉 craft 已完成，也不宣称用户从零即可发现所有缩放入口。
