# EDGE-346 · 账本统计警报独立复审

本格 L2 写账后，`alarms.py` 按既定阈值打开 `gap-too-fast` 与 `discovery-collapse`。两项均按机制
复审，不修改阈值、算法、法典或锚点。

- `gap-too-fast`：重新检查有效 session `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-230853/`
  的完整录屏、Computer Use 状态、backend journal、三路 SSE、LLM wire 和 frontend journal。该 session
  实际跨越 onboarding、两次音色登记、库存耗尽、明确强制调用负路径、结果收尾和收台，不是只读账本后
  快速盖章。
- `discovery-collapse`：本次通过只覆盖已真实执行并交叉验证的“2 槽库存拒绝”路径；普通第三次提示没有
  发起必然失败的工具调用，随后使用明确直接调用提示取得后端负路径。没有把未执行的普通提示、未覆盖的
  L3-L5 或任何失败路径改写成 pass，也没有删除红事实。
- 锚点：`RIG_HOME=/private/tmp/anselm-rig-formal-20260801-3 python3 testend/rig/anchors.py check /private/tmp/anselm-rig-formal-20260801-3/anchor-answers.json`
  通过 `10/10`，校准仍绑定当前 `anchors.json`。
- 结论：两项警报均由当前窗口样本组成触发；在这份独立复审证据下按原规则销账，继续保留统计曲线，
  不以 ack 替代产品证据。
