# EDGE-349 ledger/alarm 独立复审

## 复审对象

- 裁决：`EDGE-349` L2=`pass`
- 证据：`testend/rig/formal-evidence/EDGE-349-speech-upstream-closed-20260828.md`
- session：`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-004607`
- 复审前警报：`gap-too-fast`、`discovery-collapse`

## 复审结论

两条警报均为账本统计信号，不是产品绿场证据。EDGE-349 的裁决是在真实 App 断线与准确
重试操作完成、`rig-check` 五通道通过、`rig-down` 封存之后写入；没有用警报检查代替
产品观察，也没有把本次录台期间的快速机械写入误当成用户操作速度。

- `gap-too-fast`：本次 judge 写入发生在同一批台架收尾动作之后，间隔短是 batch bookkeeping
  的时间形状；真实录台持续约 `66.045000s`。
- `discovery-collapse`：本次是针对已知 speech boundary 的 L2 复验，不是连续发现路径的
  采样；红场曾真实出现 recorder 生命周期异常并被修复，红证据仍保留。
- 继续保持 L3-L5=`na`，没有用本次 L2 结果冒充顺滑、视觉 craft 或可发现性通过。

复审后运行 `anchors.py check`=`10/10`、`gen_coverage.py --check`=`848/848/0`；确认后
ack 两条警报，`alarms.py check` 应恢复 clean。

复审人：acceptance loop conductor（同一连续作者，不换 agent）。
