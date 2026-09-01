# EDGE-181 账本警报独立复核

- 警报：`pass-burst`，原因是末 10 条裁决在真实 session 封存后集中写入，速率超过尾窗基线。
- 复核对象：`EDGE|整批 embed upsert 全失败` L2-L5。
- 真实 session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-220606`。

## 复核结论

这四个绿格不是未观察的橡皮章。复核重新读取了同一 manifest 下的 `backend.log`、`sse.jsonl`、`frontend.log`、`llm.jsonl`、`manifest.json`、`screen.mov` 和正式四级证据；并核对了独立 SQLite 写失败 trigger、真实 worker 的两轮失败时间戳、第二次 entity kick 后错误计数停止、lexical search 的真实 REST 命中、Computer Use 稳定画面以及 `rig-down.sh` 的进程归零结果。

首轮失败时间为 `22:06:20.379`，真实文档 PATCH 在 `22:07:13.955` 触发下一次 kick，第二轮失败为 `22:07:13.980`；收台前累计 `upsert failed=3`、abort=`2`，没有热循环。L2 使用 `F2`，L3 使用 `B2`，L4 使用 `C4`，L5 使用 `G1`，每一格均有对应的已存在证据文件，且 L2 载体位于 session `evidence/` 下。

该复核没有把受控 SQLite trigger 改称物理磁盘满，没有将 L2 的数据一致性重复当作 L3-L5，也没有修改阈值、算法、CODEX 法条、锚点集、顺序策略或五级标准。`pass-burst` 因此按真实 stop-and-fix/封存后批量落账解释并销账；后续裁决仍受同一警报曲线约束。
