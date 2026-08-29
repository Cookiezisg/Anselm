# EDGE-260 · 前导 `-` 的合法 ref · ledger/alarm re-audit

- `TestBranchActions_EveryRefusalHasItsOwnReason` 普通与 race 回归通过；黑盒 workdir Git 场景通过，前导 `-` 参数返回明确 invalid-branch，不进入 git 命令。
- 本项是分支参数安全校验 seam，没有独立持久状态、交互时延、视觉表面或用户发现入口；其用户可见错误体验归属 EDGE-259 的真实分支操作验收，L2-L5 以适用性理由收口 `na`。
- 如统计告警因连续适用性裁决打开，按既定阈值完成锚点复核并销账；不修改告警阈值、算法、CODEX 或顺序门。
