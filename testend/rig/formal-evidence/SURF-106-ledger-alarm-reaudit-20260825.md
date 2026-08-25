# SURF-106 · 账本与警报独立复审

日期：2026-08-25
对象：`SURF-106 stage/approval`
authority：`RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3`

## 复审范围

本复审只核验门禁输入和统计警报，不重新定义产品标准：

- `SURF-106-stage-approval-investigation-20260825.md` 是否存在且非空；
- L2 session 是否由同一 conductor manifest 产生，三路 SSE、backend、frontend、LLM wire 是否齐全；
- 使用的法条是否存在于 `docs/working/acceptance-loop/CODEX.md`；
- `judge.py` 是否在唯一 formal journal 中串行写入五个 level；
- 警报出现后是否使用独立证据复审并 ack，且未修改阈值、算法、法典、锚点或 gate。

## 结果

- anchors：`10/10`，仍在有效时间窗内；
- `judge.py` 五格：`E2/F2/B2/C4/G1`，每格有对应法条和非空证据；
- `gen_coverage.py --check`：`848 rows / 489 carried judgments / 0 tombstones`；
- formal journal：`2445`（`2300` baseline + `145` live）；
- `alarms.py check`：复审后 clean；
- 本批次四十七：`10/50`，按协议不跑 50 格统一长门禁、不提交。

统计警报 `gap-too-fast` 与 `discovery-collapse` 是五次连续 judge 写入后的既定保护机制触发，不是对产品证据的否定。复审确认本格的独立五通道证据完整，按原阈值记录 resolution note 后 ack；没有为了让警报变绿而改变规则。

## 排除项

首轮 AX 输入桥残缺请求和旧对话上的 edit 重入均保留在 session 原始 journal，但不进入五格证据；它们是观测器输入限制，不是被隐藏的产品成功。手工缺 workspace 的 REST 探针同样不影响 App 路径判定。
