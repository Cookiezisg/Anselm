# EDGE-179｜首用下载途中关停｜L5 真实 App 可发现性收口（2026-08-30）

## 判定

`L5 通过`，依据 `CODEX.md` 的 `G1`。本格只判断新用户能否发现并理解失联状态与下一步，不把已有 L3/L4 结果重复计分。

## 从零路径

- 正式 session：`/private/tmp/anselm-rig-formal-20260801-6/sessions/20260830-214132`
- 从全新 rig 数据目录启动真实 App，Computer Use 完成 workspace onboarding；没有向用户展示内部错误码、健康探测实现或 `ANSELM_BACKEND_URL` 文档
- 真实文档夹具触发 builtin embedder 首用下载，随后 sidecar 被 SIGTERM 终止
- App 自动从正常 Chat 收敛到全屏错误门，未要求用户刷新、打开设置或查找隐藏通知

## 用户可发现性证据

Computer Use 读取到的真实 AX 树为：

```text
container Can't reach the local engine. The local engine is unavailable. Start it, then try again.
button Retry
```

稳定录屏关键帧 `sessions/20260830-214132/frames-edge179-l4/stable-error-75s.png` 同时显示：

- 标题直接说明“本地引擎无法连接”，不暴露 backend、SSE、Dio 等实现术语
- 提示明确说明引擎当前不可用，并给出用户可执行的“启动后再试一次”路径
- `Retry` 是唯一且清楚的恢复动作，用户无需猜测下一步或回到其它页面
- 正常 Chat 被替换为错误门，不会让用户误以为消息仍会发送或下载仍在后台继续

## 五通道边界

同一 manifest 下 backend、三路 SSE、frontend console、managed gateway wire 和 60fps 录屏均存在。backend 的下载取消与退出、前端 phase 收敛、稳定错误门和有限日志互相一致；frontend console 检测窗口后不再增长，没有应用级 Flutter/Dart/RenderFlex/Unhandled 红线。未执行聊天请求，因此没有伪造业务完成证据。

## 结论

从零用户可以直接发现“本地引擎不可用”、理解原因范围和恢复动作；不依赖内部术语或外部文档。L5 通过，EDGE-179 五级收口。
