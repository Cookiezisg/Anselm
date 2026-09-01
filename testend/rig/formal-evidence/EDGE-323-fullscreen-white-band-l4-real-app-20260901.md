# EDGE-323 进全屏白带：L4 真实 App 视觉 craft 证据

## Session

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-215951`
- data: `/private/tmp/anselm-data-edge323-l4-r2.EwT1xG`
- recording: `screen.mov`, `100.510000s`, `3104x1850`, owned window `14127`
- frame review: `evidence/EDGE-323-recording-contact-sheet.png`
- independent display frame: `evidence/EDGE-323-windowserver-fullscreen-clean.png`
- Computer Use raw comparison: `evidence/EDGE-323-computer-use-fullscreen-capture-artifact.png`

## Product path

真实 App 启动后在稳定的设置页执行原生全屏入口，观察进入全屏后的稳定帧，再用
`super+ctrl+f` 退出并观察恢复后的窗口态。进入、停留、退出均在同一真实 App、同一
owned window 和同一五通道 session 内完成；没有用页面内模拟器或静态图片代替。

## Frame and craft review

绑定窗口的连续录屏 contact sheet 与 WindowServer 独立整屏帧显示：全屏内容从顶边开始
连续铺满，顶部没有白带、彩带、残留 toolbar、旧帧拼接或内容下移；左侧岛、中心
`Settings / General` 内容、控件间距、圆角和底部边界均保持完整。退出后窗口化画面恢复
正常，不出现第二次跳变、空白带或 toolbar 重建残影。

Computer Use 的原生全屏截图返回值另存为 raw artifact：它在顶部约 30px 稳定出现
彩色噪带；同一时刻的 WindowServer 整屏截图与 `screen.mov` 均无该像素。窗口化
Computer Use 截图也无该条带。因此该差异是 Computer Use 全屏采集适配层的伪影，不是
用户可见窗口内容；证据保留原样，不以删除异常截图的方式通过。`MainFlutterWindow`
的 `willEnterFullScreenNotification` 仍执行动画前撤 toolbar，绑定窗口帧验证了产品面
没有白带。

L4=`C4`：稳定画面的几何连续性、层级、留白、边界和进出全屏过渡均满足法典；没有
因此修改已经正确的 AppKit 全屏实现。

## Five-channel cross-check

- **frames / Computer Use**：AX 树识别全屏入口并完成进入/退出；稳定画面同时由绑定窗口录屏和 WindowServer 独立帧复核，原始 Computer Use 伪影单独保留。
- **backend**：`backend.log` 共 `350` 行；无 `panic`、`fatal`、`WARN` 或 `ERROR` 应用级红线。
- **SSE**：`sse.jsonl` 共 `8` 行；`messages`、`entities`、`notifications` 三流均连接；本格无业务 durable 变化属预期。
- **frontend console**：`frontend.log` 共 `3` 行；无 Flutter/Dart、RenderFlex、RenderBox、Unhandled、Exception 或 overflow 红线。
- **LLM wire**：`llm.jsonl` 共 `1` 行；managed challenge/install/models 握手在线，本格不调用 completion。

`rig-down` 已封口录屏并收台，session 仍保留全部 journal、manifest 和原始对照图片。
