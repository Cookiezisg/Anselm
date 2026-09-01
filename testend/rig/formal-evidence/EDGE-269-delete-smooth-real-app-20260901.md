# EDGE-269 L3 · 驻地分组批量删除范围 · 真实 App

## 现场

- Session: `/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-002025`
- Recording: `screen.mov`, `3104x1844`, `60fps`
- 操作由 Computer Use 在真实 App 完成；确认框等待用户确认的数小时不计入产品延迟。

## 测量

录屏在动作附近 `[31314s,31322s]` 重新以 30fps 抽帧到 `/private/tmp/edge269-measure-frames/`。命令：

```text
go run ./cmd/measure diff -dir /private/tmp/edge269-measure-frames -threshold 0.0005
go run ./cmd/measure latency -dir /private/tmp/edge269-measure-frames -fps 30 -action 96 -threshold 0.0005
```

稳定确认框后的动作反馈为 `f-0096 -> f-0097`，首个可见变化约 `33.3ms`，`changedFrac=0.81095`，覆盖整屏的预期模态退出/落地转场。后续变化仍是同一次确认后的模态框退出和 Chat 收敛，没有检测到后台内容跳动。

## 逐帧判断

确认框在用户等待期间保持稳定，文本没有漂移或重排。点击后只发生一次连贯的“确认框退出 → 目标组消失 → 稳定 Chat”转场；置顶线程没有被重新加载成闪烁或跳位，最终视口没有空白、重复或残留 spinner。

## 判定

`B2` pass：动作后的首个反馈在可接受的 30fps 观测粒度内出现，且所有变化均由用户确认动作触发，没有非预期的现有内容跳变。
