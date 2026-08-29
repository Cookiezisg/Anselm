# EDGE-312 版本组走 retryOf：L3 账本与告警复审

- target: `EDGE-312 / 版本组走 retryOf / L3`
- judgment: `pass (B2)`
- primary evidence: `testend/rig/formal-evidence/EDGE-312-retry-version-groups-l3-real-app-20260829.md`
- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260828-092651`
- anchors: `10/10` calibration passed; judge unlocked

## Ledger re-audit

- `COVERAGE.md` 保留 EDGE-312 的 L1/L2 裁决并只新增 `L3:B2`；没有替换旧证据，也没有将 L4/L5 的 `na` 改成通过。
- `B2` 存在于 `docs/working/acceptance-loop/CODEX.md`；新增证据为非空文件，含真实 App session、四张稳定帧、逐帧测量、五通道和 durable retryOf 真相。
- 测量中的变化均绑定到打开线程或点击版本箭头的用户动作窗口；切换收敛后的稳定段没有超阈值变化，因此没有将用户导航误判为非用户跳变。

## Alarm re-audit

写账后若 `alarms.py check` 打开 `pass-burst` 或 `discovery-collapse`，按原规则独立处理：

- `pass-burst` 只说明近期裁决速度相对尾部基线偏快，不能替代对四个版本状态和稳定段的逐帧核验。
- `discovery-collapse` 只说明尾部 fail 占比低于既定地板；本格保留 L4/L5 未测边界，未把无 fail 解释成产品整体无缺陷。

按既定阈值逐项复审并 ack；不修改阈值、算法、CODEX、锚点答案或正式序列。最终状态以 `alarms.py check` 的 clean 输出为准。
