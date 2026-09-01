# EDGE-322 应内缩放到顶：L4 真实 App 视觉 craft 证据

## Session

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-214830`
- data: `/private/tmp/anselm-data-edge322-l4-20260901.jRrMbn`
- workspace: `ws_cc83f5e7903c9dec`
- recording: `screen.mov`, `77.648333s`, owned window `14045`
- frames: `/private/tmp/edge322-l4-frames-20260901.fvJBGW`

## Product path

真实 App 启动后打开底部设置入口和 `General`，观察默认 `1.0×`；点击 `1.1×`，检查整页重排；点击
灰置的 `1.25×` 越界档位；再点击 `1.0×` 恢复。当前屏幕下 `1.25×`、`1.5×` 均不可选。

## Frame and craft review

`1.1×` 稳定帧中左侧设置导航、中心 `General` 标题、UI zoom 说明、档位控件、字体选择和 Language
区域均在窗口内，文本没有截断、重叠或压扁；控件间距、圆角和对齐保持一致。越界点击后当前仍为
`1.1×`，灰置档位没有把内容推过边界；恢复 `1.0×` 后整页回到默认密度，没有白带、溢出、残留
偏移或无法继续操作。

1fps、设置 ROI `500,100,2200,1200`、阈值 `0.0005` 的变化只出现在明确动作窗口：

```text
f0025→f0026  changed=0.04613  设置导航/初始内容出现
f0030→f0031  changed=0.05923  1.1× 选择后的重排
f0037→f0038  changed=0.10010  1.0× 恢复重排
f0061→f0062  changed=0.10013  收尾状态变化
```

静止段没有持续位移、白带或视觉漂移。L4=`C4`。

## Five-channel cross-check

- **frames / Computer Use**：真实 App 覆盖设置入口、General、1.1×、越界档位和恢复；每次操作后重新读取 AX 状态。
- **backend**：`backend.log` 共 `297` 行；本机偏好路径无 `panic`、`fatal`、`WARN` 或 `ERROR` 应用级红线。
- **SSE**：独立 witness `sse.jsonl` 共 `8` 行，messages/entities/notifications 三流均连接；本机偏好路径无业务 durable 帧是预期行为。
- **frontend console**：`frontend.log` 共 `3` 行；无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow 应用级红线。
- **LLM wire**：`llm.jsonl` 共 `1` 行；managed challenge/install/models 握手存在，本格不调用 completion。

## Boundary

本格判定真实界面在缩放、到顶拒绝和恢复过程中的布局完整性、间距、层级、可读性和稳定性；快捷键
桥接行为已由既有 L1/L3 证据覆盖，不因当前 Computer Use 键码没有改变档位而虚构新的快捷键结论。
`rig-check`/`rig-down`、D1、录屏归属和 owned process 收台通过。
