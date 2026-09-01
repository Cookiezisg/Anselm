# EDGE-320 skill 双写者竞态：L4 真实 App 视觉 craft 证据

## Session

- session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-213424`
- data: `/private/tmp/anselm-data-edge320-l4-20260901.Xq6Q6Q`
- workspace: `ws_6f16fe1504cd83a4`
- recording: `screen.mov`, `117.596667s`, owned window `13985`
- frames: `/private/tmp/edge320-l4-frames-20260901.q7QCIM`
- representative stable frame: `f0110.png`

## Product path

在真实 App 的 Library 打开 `edge320-race` Skill；在中心 body 末尾键入 `X`，在右侧 Properties 的
Arguments 输入并提交 `racearg`，等待 600ms 防抖写入完成；离开到 `commit-helper`，再返回
`edge320-race`。这是普通用户同时编辑 Skill 正文和配置的真实路径，不把内部竞态术语暴露给用户。

## Frame and craft review

返回后的稳定帧同时显示正文 `BODYCLEANX` 以及 Arguments 下的 `cleanarg`、`racearg` 两个 chip；两个
chip 同高、间距均匀、删除 affordance 对齐，Properties 面板没有重挂、空白或晚到旧值覆盖。中心标题、
正文、右侧 Context、Allowed tools、Arguments、Model can invoke、User-invocable 和 Outline 的层级及
留白保持稳定。离开再返回后未出现跳变、局部恢复旧值、焦点丢失或侧栏重排。

对全程录屏抽取的 1fps 帧，以内容和 Properties ROI `760,250,1850,950`、像素阈值 `0.0005` 测量，
仅得到以下动作窗口变化：

```text
f0001→f0002  changed=0.00052  初始加载
f0020→f0021  changed=0.03457  打开/正文操作
f0089→f0090  changed=0.01036  参数写入收敛
f0103→f0104  changed=0.02840  离开/返回窗口
f0109→f0110  changed=0.02837  返回后的稳定布局确认
```

变化均绑定打开、输入、防抖或用户导航；没有静止段持续漂移。正式 L4=`C4`。

## Five-channel cross-check

- **frames / Computer Use**：真实 App 录屏覆盖中心正文编辑、右侧参数新增、等待防抖、离开与返回；逐次操作后重新读取 AX 状态。
- **backend**：`backend.log` 共 `430` 行；Skill 读取、两次编辑提交和重返读取均有 HTTP 记录，无 `panic`、`fatal`、`WARN`、`ERROR` 或应用级异常。
- **SSE**：独立 witness `sse.jsonl` 共 `11` 行，三条 workspace stream 均连接并收到 durable 更新。
- **frontend console**：`frontend.log` 共 `5` 行；无 Flutter/Dart、RenderFlex、RenderBox、Unhandled 或 Exception 应用级红线，仅保留已分类 macOS IMK 宿主诊断。
- **LLM wire**：`llm.jsonl` 共 `1` 行；llmtap 启动握手存在，本场景是编辑路径，不伪造模型完成证据。

## Durable truth and lifecycle

离开后重新进入由服务端重新读取 Skill，返回界面同时保留中心正文与两个参数 chip；因此结论不是
单帧 UI 缓存。`rig-check` 五通道、D1 端口归属、录屏归属和 `rig-down` 收台均通过，录屏、backend、
SSE、frontend、LLM journal 与 manifest 由同一 session 归属，无残留 owned process。

## Boundary

L4 只判双写窗口在真实界面中的视觉稳定、层级、间距、对齐和返回连续性；已知的 600ms
read-modify-write 竞态取舍由 L2/L3 记录，不在本格偷换成严格事务顺序保证。
