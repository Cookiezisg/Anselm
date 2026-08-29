# EDGE-020 ledger alarm re-audit

`judge.py` 的 EDGE-020 L2 revalidation 写入后，`alarms.py` 按既有阈值打开
`gap-too-fast` 与 `discovery-collapse`。本次不是通过修改阈值、算法、法典或锚点来消警。

- `gap-too-fast` 的 0 秒来自完成真实观察后连续写入单个 L2 账本格；观察阶段使用了
  448.563333 秒封存的真实 App session，而不是在无证据情况下快速盖章。
- `discovery-collapse` 只描述尾窗没有 fail，不被解释为产品无缺陷。复审重新读取了
  `EDGE-020-approve-always-real-app-20260826.md` 的五通道证据、前一轮被排除的错误
  tool-call 输入和静态危险下限边界；红场没有被隐藏或改写。
- 后续重新构建并运行的干净 session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-000103`
  已通过存活态 `rig-check`，并以修复后二进制完成同一路径；模型文本已与
  `danger=dangerous` 和人工批准事实一致。该次 L2 revalidation 的唯一新写账仍是观察
  完成后的串行 ledger action，不构成未观察盖章。
- `anchors.py check` 保持 `10/10`，`alarms.py check` 在 ack 后重新计算；阈值、法条、
  gate 和覆盖序列均未改变。

证据主文件：
`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260826-234717/evidence/EDGE-020-approve-always-real-app-20260826.md`
