# EDGE-308 账本警报独立复审

- scope: `EDGE-308 侧幕失败行清除` L2
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-052018`
- review status: `reviewed`

本次统计警报由一条真实 L2 绿格触发。复审确认 EDGE-308 经历了真实 App 首轮红场、代码修复、定向回归和新二进制五通道复验；并非批量补录、静态猜测或降低判定标准。早期错误证据保留在正式证据中，且与修复后的成功路径分开。

复审确认：

- 没有修改 `alarms.py` 阈值、算法或覆盖范围；
- 没有把 baseline journal 当作 live evidence；
- 没有用静态测试或无录屏请求冒充 L2；
- 本次只新增 EDGE-308 L2，L3-L5 仍为 `na`；
- `anchors.py check` 仍为 10/10，法典、锚点和 gate 均未改变。

因此 `pass-burst` 与 `discovery-collapse` 按原规则销账；后续由 `alarms.py check` 继续重新计算，新的统计异常必须重新打开。
