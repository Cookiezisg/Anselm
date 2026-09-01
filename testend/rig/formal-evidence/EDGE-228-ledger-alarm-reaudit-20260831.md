# EDGE-228 · ledger/alarm re-audit

EDGE-228 的新 L2 只写入一格真实现场裁决；随后 L3-L5 是基于同一对象的明确适用性结论，
不是五个产品观察，也不是把缺失证据包装成 `na`。因此本次出现的 `gap-too-fast` 只反映
账本写入节奏，不能反推现场观察过快；`discovery-collapse` 仍按既有算法复核，不能因为
本格 clean 就宣称全局无失败或全产品已清洁。

独立复核了 session=`/private/tmp/anselm-rig-formal-20260831-11-edge228/sessions/20260831-125311`
的录屏、AX 状态、backend、SSE、frontend console 与 LLM wire；`rig-check`/`rig-down` 均通过，
没有修改警报阈值、算法、CODEX、锚点、五级标准或顺序法。ACK 只确认本次证据已经复核，
不改变 EDGE-227 的强制人工后置，也不替代后续真实 ASR 路径。
