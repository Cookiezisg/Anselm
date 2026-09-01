# EDGE-273 · 账本与警报独立复审

## L2 复审范围

- 触发裁决：`EDGE-273`（`?workDir=` 三态 presence）L2=`F2`。
- 真实证据：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-093314/evidence/EDGE-273-workdir-filter-real-app.md`。
- 锚点：同一 `RIG_HOME` 的有效锚点校准；未改阈值、法典、顺序门或五级标准。

## 两条告警

- `gap-too-fast`：近 50 条 live judgment 的间隔中位数为 `24s`，低于 `25s` 阈值。复审了真实 App
  的三态列表现场、修正后的 API 响应、五通道 journals、录屏终态和 rig-down 回执；本项证据实际
  检查了键缺席、空值、有值三种语义，短间隔不代表可以省略现场观察，也没有用本次速度调整阈值。
- `discovery-collapse`：近 50 条 live judgment 的 fail 占比为 `0.0%`，低于 `5%` 阈值。复审了
  本项的真实 Chat rail 路径和完整 COVERAGE 前线；没有把成功结果当作“产品天然没有问题”，没有
  删除 fail 记录、跳过人工队列或放宽判定。

## 结论

两条告警按原规则独立复审，保留统计曲线和原始证据，不改 `24s`/`25s` 或 `0.0%`/`5%` 阈值；
随后按 `gap-too-fast`、`discovery-collapse` 顺序串行 ack。只有 `alarms.py check` clean 后才继续
写入本项下一个 level。

## L3 复审

L3 `B2` 依据真实 App 中展开/收起驻地组与 Recents 的现场观察和封存录屏，确认每个 section 只改变
自己的 rows，未发生空白、重复、旧计数、spinner 或整 rail 非用户 reflow。两条统计告警在 L3 写账后
重新打开；复审确认未以短间隔代替观察，也未把三态成功结果当成无缺陷证明。阈值和原始 journal 保留，
按原顺序再次串行 ack。

## L4 复审

L4 `C4` 只依据真实 App 稳定画面：命名驻地与 `Recents` 层级清楚，计数贴合各自 header，child rows
没有混入错误 section，且无截断、重叠、异常空隙或 spinner。两条统计告警在 L4 写账后重新打开；复审
确认没有用 L3 的转场结论替代 craft 逐项检查，也没有因 fail 占比为零而降低视觉标准。阈值与原始
journal 保留，按原顺序再次串行 ack。
## L5 复审

L5 `G1` 只判断普通 Chat rail 的入口语义：用户能从文件夹样式的命名驻地组和 `Recents` 直接理解
两类范围，并展开各自的 rows；不需要知道 query-key presence、`workDir` 参数或 conversation id。
本级写账后仅 `discovery-collapse` 重新打开；复审确认没有把 API 正确性冒充可发现性，也没有因连续
成功而删记录或改变 `5%` 阈值。原始 journal 保留，按规则串行 ack。
