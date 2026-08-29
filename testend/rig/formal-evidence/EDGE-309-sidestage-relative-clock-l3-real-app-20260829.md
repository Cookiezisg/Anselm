# EDGE-309 侧幕分档时钟：L3 真实录屏测量证据

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-055857`
- data: `/private/tmp/anselm-data-edge309-20260828-r1`
- recording: `screen.mov`, `891.081667s`, 60fps
- frame samples: `sessions/20260828-055857/evidence/EDGE-309-l3-before.png`, `EDGE-309-l3-after.png`
- primary real-app evidence: `testend/rig/formal-evidence/EDGE-309-sidestage-relative-clock-real-app-20260828.md`

## Product path

1. 真实 App 中完成两条真实 Function 活动，右侧 Activity 形成 `Just now` 与 `Earlier` 两个分组。
2. App 保持前台静置超过 10 分钟，不点击、不切换 ocean、不重载数据；侧幕内部时钟每分钟重新计算相对时间档。
3. 目标活动从 `Just now` 自然迁移为 `Earlier today`，前一天参照保持 `Earlier`；活动计数、活动行和中心 transcript 均保持真实且稳定。

## Pixel measurement

从同一真实 App 录屏在迁移边界附近以 1fps 抽取 `t=688..701s` 的连续样本，并使用验收测量箱 `testend/cmd/measure diff`：

- `000692.png → 000693.png`: full-frame `changedFrac=0.00030`
- changed bounding box: `(2105,288)-(2260,356)`
- Activity ROI `x=2000,y=200,w=550,h=300`: `changedFrac=0.00904`，相同 bounding box
- 其余连续样本没有超过零变化阈值的变化输出；变化只发生在右侧分组标题文字从 `Just now` 到 `Earlier today` 的区域。

这说明跨档不是整侧幕重建：只有语义上必须改变的时间分组标题更新，活动行、中心内容、侧幕边界和计数没有被重排。相邻每分钟静置采样也没有持续累积位移或冻结后突然重绘。

## Five-channel cross-check

- **frames**: 真实窗口专属录屏覆盖 14.8 分钟；`EDGE-309-l3-before.png` 显示迁移前，`EDGE-309-l3-after.png` 显示迁移后；相邻样本量化仅命中标题区域。
- **backend**: `backend.log` 共 `965` 行；没有 `WARN`、`ERROR`、`panic` 或 `FATAL`。
- **SSE**: `sse.jsonl` 共 `82` 行；messages durable seq=`1..16`、entities=`1..2`，连续无 gap，真实 Function tool result 为 `ok:true`。
- **frontend**: `frontend.log` 共 `4` 行；只有启动、Dart VM 和已知 macOS IMK 宿主诊断，没有 Flutter、Dart、RenderFlex 或 Unhandled runtime 红线。
- **LLM wire**: `llm.jsonl` 共 `10` 行；managed proof 与真实 Chat completion 均为 HTTP `200`，不是 fixture 回放。
- **durable truth**: 既有正式证据与录屏中的两个活动、真实 Function 返回值和侧幕分组一致；本次 L3 只增加帧测量，不改写 durable 结果。
- **rig lifecycle**: 原 session 的 `rig-check`、`rig-down`、录屏收尾和进程归属均已通过，录屏可读且五通道 journals 保留。

## Judgment

- **L3 `pass (B2)`**: 跨越 10 分钟相对时间窗时，系统仅更新必须变化的分组标题；连续逐帧/逐秒采样没有非用户触发的整体布局跳变、活动行位移、侧幕重建或冻结后突跳。
- 本证据只判定相对时钟迁移的帧级稳定性，不把时间文案的视觉 craft 或从零盲走可发现性冒充为 L4/L5。
