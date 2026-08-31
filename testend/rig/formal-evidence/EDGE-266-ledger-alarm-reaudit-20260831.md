# EDGE-266 · 账本与警报复审

## 账本动作

`judge.py` 在录屏尚未封存时第一次拒绝 L2，理由是 session 缺少完整 `screen.mov`。收台架后
录屏封存为 `199.826667s`，再按序写入 L2-L5：

```text
L2 ✓ F2
L3 ✓ B2
L4 ✓ C5
L5 ✓ G1
```

四格均引用 `EDGE-266-workdir-marker-noop-fixed-real-app.md` 与真实 App 截图；没有使用 provisional
`na`，没有借用旧 session，也没有修改 CODEX 法条、阈值或锚点集。

## 警报复审

本次四格写入后，`alarms.py check` 按设计打开：

- `gap-too-fast`：近尾裁决间隔中位数低于 25 秒。
- `discovery-collapse`：近 50 格 fail 占比为 0%。

两条警报均逐条确认。原因是本项已完成现场观察后集中落四级账，而不是跳过证据观看；本轮
没有发现产品失败，也没有橡皮章替代真实证据。警报阈值、法条、锚点和“有未销警报不得新增
pass”的互锁均保留，下一批会拉宽现场观察与落账间隔。

复审后 `alarms.py check` 回到 clean。
