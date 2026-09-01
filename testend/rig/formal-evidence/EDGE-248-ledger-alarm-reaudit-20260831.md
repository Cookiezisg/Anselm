# EDGE-248 · 账本警报独立复审

`EDGE-248 L2` 写账后，`alarms.py check` 按既有阈值打开 `discovery-collapse`：近 50
条正式裁决的 fail 占比为 `2.0%`，低于 `5%`。没有修改阈值、曲线算法、法典、锚点或顺序
gate。

复审重新读取同一正式 session
`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260831-192329`：真实 App 在
`Setting up your workspace...` 中发起了受控长请求，关闭客户端时 appproxy journal 确实
记录 `canceled=true`；录屏、backend、三路 SSE、frontend 和 managed bootstrap LLM tap
均归属于同一 manifest，`rig-down` 正常收台且无当前台架残留。复审同时确认：该取消发生
在代理向 backend 转发之前，没有伪造 `CLIENT_CLOSED`/499；两种 server-side 映射由既有
focused errmap tests 独立锁定。

这是真实的客户端取消证据，而不是“看见最终绿色页面”或把代理行为冒充后端响应。低 fail
share 只作为裁判漂移保护信号处理，按原机制销账当前 journal 水位；后续新增裁决仍受
三条曲线约束。

L3-L5 随后以具体适用性理由落为 `na`：本 transport 分类不拥有独立的用户操作/动效、
视觉组件或可发现入口；没有用缺少现场证据的借口放弃检查，也没有把上层功能的视觉结论
倒灌到本格。该三格的边界说明已由 `judge.py` 写入清册并纳入本次复审。
