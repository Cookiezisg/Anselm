# EDGE-311 归队重钉贴底：L3 账本与告警复审

- target: `EDGE-311 / 归队重钉贴底 / L3`
- judgment: `pass (B2)`
- primary evidence: `testend/rig/formal-evidence/EDGE-311-back-to-live-reanchor-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-091845`
- anchors: `10/10` calibration passed; judge unlocked

## Ledger re-audit

- `COVERAGE.md` 保留 EDGE-311 既有 L1/L2 裁决，并只新增 `L3:B2`；没有覆盖、削弱或改写旧证据。
- `B2` 仍存在于 `docs/working/acceptance-loop/CODEX.md`；新增证据是非空文件，包含真实 App session、录屏稳定帧、逐帧测量、五通道和 durable truth 交叉核对。
- 两个较大的 diff 均绑定到用户明确点击 `Jump to present` 后的同一归队动作；独立静止窗口从 `000055` 至 `000065` 没有超阈值变化，因此没有把用户动作误报为产品跳变。
- L3 只证明归队后的稳定性，L4/L5 继续保持 `na`。

## Alarm re-audit

写入本格后若 `alarms.py check` 打开 `pass-burst` 或 `discovery-collapse`，其含义仍是统计信号，不是本格自动通过：

- `pass-burst` 以尾部裁决速度相对基线过快为信号；本轮通过独立的真实录屏抽帧和稳定窗口测量复核，不能用批量速度替代观看证据。
- `discovery-collapse` 以尾部 fail 占比低于既定地板为信号；本格明确记录了用户触发的大变化，并保留未测 L4/L5，未把“没有发现跳变”偷换成全产品无缺陷。

按原阈值逐项复审并 ack；不修改阈值、算法、CODEX 法条、锚点答案或正式序列。最终状态必须由 `alarms.py check` 重新确认 clean。
