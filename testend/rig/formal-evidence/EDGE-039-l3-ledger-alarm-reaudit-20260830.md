# EDGE-039 L3 · 账本告警独立复审

## 复审结论

本文件只复审统计告警，不改变 `B2` 法条、五级标准、锚点答案或告警阈值。`EDGE-039` L3 的裁决已经
由正式 gate 写入；告警反映裁决时序与当前已判样本的分布，不是产品证据本身。

## gap-too-fast

- 告警原因：近 50 条裁决间隔中位数低于 `25s`。
- 独立核对：本格使用新 formal session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-165831`，
  录屏、五路日志、REST 版本链、SSE durable seq 和 managed LLM wire 均在判定前实际读取；录屏为
  `240.328333s`，并完成 `measure latency` 与稳定尾帧 `measure diff`。
- 处置：这是本次真实证据复审完成后立即写账造成的统计告警，保留原阈值并 ack；下一格继续接受
  `judge.py` 的告警闸，不因本次 ack 绕过证据要求。

## discovery-collapse

- 告警原因：近 50 条裁决的 fail 占比低于 `5%`。
- 独立核对：本轮没有将前一轮的失败记录抹掉；`EDGE-039` 首轮红证据仍保留，修复前后证据分别为
  `EDGE-039-edit-resend-normal-send-red-20260830.md` 与
  `EDGE-039-retry-edit-resend-l3-real-app-20260830.md`，最终判定只覆盖修复后真实路径。
- 处置：这是当前批次连续修复后的分布告警，不改写 fail 记录，不调低 `5%` 阈值；按原协议 ack，
  后续仍要求新的独立红线复审或真实缺陷才可关闭分布风险。

## Control checks

- `anchors.py check`：10/10，使用当前 `anchors.json` hash。
- `gen_coverage.py --check`：848 行、848 条既有裁决携带、0 墓碑漂移。
- `rig-check.sh`：五通道均归属当前 session；`rig-down.sh`：所有观察进程归零。
