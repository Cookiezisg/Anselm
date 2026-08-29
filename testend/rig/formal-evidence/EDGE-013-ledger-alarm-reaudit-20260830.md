# EDGE-013 · 账本与警报复核

## Review

本次复核逐项检查了 `EDGE-013` 的 focused tests、真实 App 非正式 session 和适用性边界。
真实 session 没有产生 stringified-object wire，且包含 Computer Use 改写输入造成的真实 backend
`WARN`，所以没有被当成 pass。L1 仍由 ObjectMap 的等价解码与错误 shape 拒绝测试证明。

ObjectMap 是 loop 内部编码兼容层，不是独立业务实体、用户交互反馈、视觉表面或可导航入口；对应的
tool call/result 数据真相、等待反馈、工具卡视觉和入口发现性由宿主 function/handler/agent/chat
旅程负责。因此 L2/L3/L4/L5 使用带具体理由的 `na`，不是“缺证据”豁免，也没有改变任何阈值、法条、
锚点或 gate。

## Alarm disposition

`discovery-collapse` 由最近 50 条裁决的 fail-share 低于阈值触发。该窗口包含大量明确不适用的
协议边界等级，没有出现“失败被隐藏”或批量跳过检查的证据；anchors `10/10`，清册
`gen_coverage.py --check` clean，且本条四个新判断均保留了具体适用性理由。按既有机制销账，
不调整阈值，不排除本次判断，不把警报当作产品通过。
