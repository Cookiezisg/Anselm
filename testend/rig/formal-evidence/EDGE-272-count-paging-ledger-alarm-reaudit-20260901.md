# EDGE-272 · 账本与警报独立复审

## L2 复审范围

- 触发裁决：`EDGE|分组计数跨翻页不漂移` L2=`F2`。
- 真实证据：`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-091811/evidence/EDGE-272-count-paging-real-app.md`。
- 锚点：本次写账前使用同一 `RIG_HOME` 的有效锚点校准；未改阈值、法典、顺序门或五级标准。

## 两条告警

- `gap-too-fast`：近 50 条 live judgment 的间隔中位数为 `19s`，低于 `25s` 阈值。复审了本次真实
  App 的 Computer Use 观察、16 页服务端分页闭合、五通道 journals、录屏终态和 rig-down 回执。
  本项是已完成的确定性分页路径，裁决所需证据已实际检查；快不是跳过证据的依据，也没有用本次
  速度调整阈值。
- `discovery-collapse`：近 50 条 live judgment 的 fail 占比为 `0.0%`，低于 `5%` 阈值。复审了
  本项的产品路径和完整 COVERAGE 前线；本项没有用“未发现问题”代替证据，也没有删除 fail 记录、
  把 forced queue 当成自动通过或放宽判定。

## 结论

两条告警均按原规则独立复审，保留统计曲线和原始证据，不改 `19s`/`25s` 或 `0.0%`/`5%` 阈值；
随后按 `gap-too-fast`、`discovery-collapse` 顺序串行 ack。只有 `alarms.py check` 回到 clean 后，
才继续写入本项的下一个 level。

## L3 复审

L3 `B2` 基于真实 App 的可见滚动路径、封存 60fps 录屏和分页前后稳定的 `31` 计数判定；证据还明确
排除了 blank、duplicate、stale count、spinner 和非用户触发的 reflow。两条统计告警在 L3 写账后重新
打开，复审确认没有以短间隔代替观看，也没有把顺滑性 pass 当成产品已经没有 fail 的证明；阈值和原始
journal 均保留。按原顺序再次串行 ack。

## L4 复审

L4 `C4` 只依据同一封存录屏和真实 App 稳定画面判断：组头 `31` 的位置和层级稳定，行间距一致，
没有截断、重叠、空占位、重复成员或遗留 spinner，置顶线程与驻地组保持清晰分层。两条统计告警在
L4 写账后重新打开；复审确认没有把 L3 的状态转场证据当作 craft 证据，也没有用“画面没红线”替代
逐项视觉检查。阈值和 journal 保留，按原顺序再次串行 ack。

## L5 复审

L5 `G1` 只判断普通 Chat rail 的自然入口：用户看到命名驻地组和 `31`，展开并滚动即可继续浏览，
不需要知道 `workDir`、分页参数或 conversation id；置顶和其它驻地组的分层也保持可理解。两条统计
告警在 L5 写账后重新打开；复审确认没有把内部 API 可达性冒充用户可发现性，也没有因连续 pass 而
删除 fail 记录或放宽标准。阈值和 journal 保留，按原顺序串行 ack。
