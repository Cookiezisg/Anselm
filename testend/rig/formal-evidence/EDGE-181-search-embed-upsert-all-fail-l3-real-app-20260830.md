# EDGE-181 整批 embed upsert 全失败：L3 真实时序

- 结论：`pass`。
- 录屏：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-220606/screen.mov`，时长 `187.156667s`，60fps。

真实 worker 在 `22:06:20.379` 记录首轮写入失败并立即记录 `aborting backfill round, next kick retries`。真实文档 PATCH 在 `22:07:13.955` 产生独立 entity update，第二轮失败在 `22:07:13.980` 发生；随后到收台前 `upsert failed` 和 abort 计数均保持为 `3` 和 `2`，没有持续占用 CPU/模型或反复产生错误。

这条时序满足“失败当轮结束、用户路径仍可用、下一次明确数据变化才重试”，而不是用快速 sleep 或 fixture 计时器代替生产 worker。真实 App 在整个观察窗口保持正常 Chat 空态，未出现索引失败造成的 loading 卡死或错误风暴；frontend console 也没有增长中的应用红线。

独立 ssetap 记录了三路连接和 document update，backend journal、REST 返回和录屏属于同一 session manifest。关闭时 `rig-down.sh` 正常收台，进程组归零。

判定依据：`CODEX B2`。本级只判断时间行为和稳定性，不把 L2 的 SQL/REST 一致性重复计分。
