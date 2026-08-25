# SURF-096 账本警报复审

## 复审对象

本格 `i18n/startup` 的五级裁决在真实 App 观察、代码修复、两轮重建和两套 session 证据封存后才写入。`gap-too-fast` 与 `discovery-collapse` 是既有 50 格窗口的统计信号，不是本格证据缺失的结论。

## 独立复核

- 第一轮 `20260825-061312` 发现真实缺陷：启动崩溃页泄露 raw backend error；该轮未过账为绿。
- 修复后同轮重新观察：本地化崩溃页不再泄露 URL/内部错误，点击重试恢复到创建工作区。
- 为满足 L2 的 SSE 硬门禁，第二轮 `20260825-061754` 预置 workspace 重跑；三路 SSE 均真实连接，重试后恢复到实体总览，`rig-check.sh` 通过。
- 代码 focused Flutter tests `12` 项通过；两轮 screen/backend/SSE/frontend/LLM 原始 journal 与录屏均保留。
- 锚点答卷按冻结 `anchors.json` 逐题补回理由后，`anchors.py check` 通过 `10/10`；anchor set hash、CODEX、阈值、算法和 gate 均未改动。

## 结论

近 50 格无 fail 仍按机制触发 discovery 警报；五个裁决的零/短间隔来自同一格观察完成后的原子账本串行写入，不据此放宽门禁。两条警报可按既有流程 ack，下一格继续由覆盖清册顺序约束。
